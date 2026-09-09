//
//  Credentials.swift
//  PortalSwift
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// The SDK-internal helpers behind the credential boundary: resolution, invalidation, 401
/// reporting, hook wiring and host notification.
///
/// One namespace rather than eight module-scope free functions, so hot-path helpers are not
/// competing with host code for names, and `internal` because every operation a host can
/// legitimately need has a public wrapper — `Portal.clearSession()` over `invalidate(_:)`,
/// `Portal.onSessionInvalidated(_:)` over `onInvalidated(_:listener:)` — and nothing outside the
/// module calls the rest. A public entry point can be added later without breaking anyone;
/// withdrawing a public function could not.
enum PortalCredentialSupport {}

// MARK: - Resolution

extension PortalCredentialSupport {
  /// Resolves the single credential source a component was constructed with.
  ///
  /// `credentials` wins whenever it is supplied: the public `Portal` initializers make the
  /// "both supplied" case unrepresentable, so there is nothing to reject at runtime. A
  /// blank `apiKey` (empty or whitespace-only) is treated as absent rather than wrapped,
  /// because whitespace can only ever be sent as a malformed bearer; a non-blank key is
  /// wrapped verbatim — no trimming — so the server, not the SDK, decides what a valid key
  /// looks like.
  ///
  /// - Throws: `PortalCredentialError.invalidApiKey` when neither source is usable.
  static func resolve(apiKey: String?, credentials: PortalCredentials?) throws -> PortalCredentials {
    if let credentials = credentials {
      return credentials
    }

    guard let apiKey = apiKey, !isBlankCredentialValue(apiKey) else {
      throw PortalCredentialError.invalidApiKey
    }

    return StaticCredentials(apiKey)
  }
}

extension PortalCredentialSupport {
  /// The SDK's credential boundary: resolves a token from `credentials`, normalising every
  /// failure to `PortalCredentialError` since a host-supplied provider can throw anything.
  ///
  /// A `PortalCredentialError` raised by the provider passes through untouched, so a precise
  /// reason such as `.sessionInvalidated` is never downgraded to `.providerFailure`. Any
  /// other error becomes `.providerFailure(underlying:)`, and a blank token becomes
  /// `.unavailable`. The value is never cached: every call goes back to the provider, which
  /// is what lets a session rotate or be invalidated underneath a long-lived `Portal`.
  static func resolveToken(_ credentials: PortalCredentials) throws -> String {
    let token: String
    do {
      token = try credentials.getToken()
    } catch let error as PortalCredentialError {
      throw error
    } catch {
      throw PortalCredentialError.providerFailure(underlying: error)
    }

    guard !isBlankCredentialValue(token) else {
      throw PortalCredentialError.unavailable
    }

    return token
  }
}

extension PortalCredentialSupport {
  /// The raw Client API Key behind `credentials`, or `""` when it is not a static key —
  /// never a wrong or stale token.
  ///
  /// A bridge for the subsystems that still expose a synchronous, deprecated `apiKey` on
  /// their public surface. It reports the absence of a static key rather than resolving
  /// one, so a session-backed credential reads as `""` instead of leaking a session token
  /// through a property hosts may log, and it never calls `getToken()` as a side effect.
  static func staticApiKey(of credentials: PortalCredentials) -> String {
    (credentials as? StaticCredentials)?.value ?? ""
  }
}

/// `true` for an empty or whitespace-only value, which is unusable as a bearer either way.
private func isBlankCredentialValue(_ value: String) -> Bool {
  value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

// MARK: - Invalidation

extension PortalCredentialSupport {
  /// Invalidates `credentials` without telling the host.
  ///
  /// This is the plain operation behind a host-initiated sign-out (`Portal.clearSession()`),
  /// and a sign-out is not news to whoever asked for it; a backend rejection goes through
  /// `reportUnauthorized(_:)` instead. The call is serialised on a per-credential monitor
  /// owned by `CredentialInvalidationRegistry`, so several subsystems reacting to the same
  /// 401 cannot run `invalidate()` concurrently — combined with the idempotence the protocol
  /// requires, the second caller finds an already-cleared credential and performs no second
  /// storage delete. The monitor is the registry's own `NSRecursiveLock`, never
  /// `objc_sync_enter` on the credential: `PortalCredentials` is implemented by host code,
  /// and taking a monitor on a host-owned object could contend or deadlock with the host's
  /// own synchronisation.
  ///
  /// - Throws: whatever `invalidate()` throws, unchanged, so a failed persisted delete
  ///   reaches the caller.
  static func invalidate(_ credentials: PortalCredentials) throws {
    let monitor = CredentialInvalidationRegistry.shared.monitor(for: credentials)
    monitor.lock()
    defer { monitor.unlock() }
    try credentials.invalidate()
  }
}

extension PortalCredentialSupport {
  /// The 401 path every Portal-authenticated requester routes through: invalidate the
  /// credential, then tell the host its session ended.
  ///
  /// Kept separate from `invalidate(_:)`, which stays the silent operation a host-initiated
  /// sign-out uses — only a backend rejection is news to the host. The host is notified even
  /// when the invalidation throws: the in-memory token is dropped first by every conforming
  /// session, so the session is over either way and hiding that behind a storage failure would
  /// leave the UI signed in against a dead credential. The failure still propagates, and every
  /// call site treats it as bookkeeping that must not replace the original transport error.
  /// Reporting is once-ever per credential and never happens for a `StaticCredentials`, which
  /// has no session for a 401 to have ended.
  static func reportUnauthorized(_ credentials: PortalCredentials) throws {
    defer { CredentialInvalidationRegistry.shared.notifyInvalidated(credentials) }
    try invalidate(credentials)
  }
}

extension PortalCredentialSupport {
  /// `reportUnauthorized(_:)` for call sites that cannot throw (transport hooks, refill tasks,
  /// error-mapping branches): swallows the failure and logs it.
  ///
  /// The log line carries only the caller's `context` and fixed literals. It never includes
  /// the error itself, because a session's storage error or a host provider's message can
  /// echo the token, and this line is emitted at the exact moment the token was rejected.
  static func reportUnauthorizedAndLog(_ credentials: PortalCredentials, context: String) {
    do {
      try reportUnauthorized(credentials)
    } catch {
      PortalLogger.shared.error("\(context) - reportUnauthorized() could not invalidate the credential after an unauthorized response; the host was still notified.")
    }
  }

  /// `reportUnauthorizedAndLog(_:context:)` for a rejection whose bearer is known.
  ///
  /// A 401 or `AUTH_FAILED` says the token that was *sent* is dead. When the credential has since
  /// rotated in place — a host-written `PortalCredentials` that fetches a fresh token underneath a
  /// long-lived `Portal`, the case `resolveToken(_:)` exists for — the replacement was never
  /// rejected, and invalidating it would sign the user out for a stale response. So the report is
  /// skipped unless the credential still holds `rejectedToken`. This is the rule
  /// `UnauthorizedHookRegistry.report(bearerToken:from:)` applies on the transport path, brought
  /// to the call sites that bypass the transport hook: the MPC binary, the WebSocket upgrade, the
  /// Firebase retry and the legacy `storedClientBackupShare` request.
  ///
  /// A credential that can no longer resolve (already invalidated, or a failing provider) counts
  /// as not matching: there is nothing left to invalidate, and reporting is once-ever anyway. The
  /// log line names the context only; neither token is logged.
  ///
  /// The compare and the invalidation are two calls, not one atomic step: a host credential that
  /// rotates in the gap between them is still invalidated for the old token's rejection. That
  /// window is accepted rather than closed. The rotation runs in host code the SDK cannot lock,
  /// so closing it would need a host-implemented compare-and-invalidate — a new `PortalCredentials`
  /// requirement that no Portal SDK exposes and that would break parity with Android's two-method
  /// contract and every existing conformer. What the check buys is shrinking the exposure from the
  /// whole request duration to the gap between two calls; neither built-in credential can rotate
  /// (`KeychainPortalSession` holds one token for life, `StaticCredentials` is never reported).
  static func reportUnauthorizedAndLog(_ credentials: PortalCredentials, rejectedToken: String, context: String) {
    guard (try? credentials.getToken()) == rejectedToken else {
      PortalLogger.shared.debug("\(context) - The rejected bearer is no longer the one this credential holds (rotated or already invalidated); not invalidating.")
      return
    }
    reportUnauthorizedAndLog(credentials, context: context)
  }
}

extension PortalCredentialSupport {
  /// Wires a transport's 401 hook to `credentials`.
  ///
  /// A host may share one `PortalRequests` between several SDK objects, and those objects may
  /// hold different credentials, so the transport's single closure cannot simply belong to
  /// whoever installed it first: a 401 for the second owner's request would then invalidate the
  /// first owner's session and leave the rejected one usable. Instead the closure is installed
  /// once per transport and every owner is recorded in `UnauthorizedHookRegistry`; on a 401 the
  /// transport hands over the rejected bearer and the registry reports the owner whose credential
  /// presented it (see `UnauthorizedHookRegistry.report(bearerToken:from:)` for the fallbacks).
  /// A hook the SDK did not install is never replaced. The installed closure captures the
  /// transport weakly and nothing else — never the installing object — so installing a hook
  /// cannot create a retain cycle or keep a `Portal` alive through its own transport. A transport
  /// that does not conform to `PortalUnauthorizedReporting` (test doubles, custom hosts) makes
  /// this a logged no-op.
  static func installUnauthorizedHook(on requests: PortalRequestsProtocol, for credentials: PortalCredentials, context: String) {
    guard let reporting = requests as? PortalUnauthorizedReporting else {
      // A host-supplied transport that cannot report 401s: session invalidation will never fire
      // through it. Say so once at wiring time rather than staying silent until a dead session
      // goes unnoticed.
      PortalLogger.shared.warn("\(context) - The transport does not conform to PortalUnauthorizedReporting; a 401 through it will not invalidate the session or notify onSessionInvalidated.")
      return
    }
    UnauthorizedHookRegistry.shared.install(on: reporting, for: credentials, context: context)
  }
}

extension PortalCredentialSupport {
  /// Subscribes `listener` to the backend invalidating `credentials`; the host-facing contract
  /// is documented on `Portal.onSessionInvalidated(_:)`.
  ///
  /// The listener runs at most once, on the main actor, and only for a rejection reported
  /// through `reportUnauthorized(_:)` — a host-initiated `invalidate(_:)` is silent. A
  /// `StaticCredentials` can never be reported, so it returns the shared `.spent` handle rather
  /// than retaining a listener (and whatever it captured) that will never fire. A credential that
  /// was already reported has that rejection replayed: the listener runs once, on the main actor,
  /// as if it had been subscribed in time, so a host that subscribes a moment after `Portal`'s
  /// eager client fetch came back 401 still learns its session ended. The returned handle cancels
  /// that pending delivery like any other.
  static func onInvalidated(
    _ credentials: PortalCredentials,
    listener: @escaping @MainActor () -> Void
  ) -> PortalSessionInvalidationHandle {
    CredentialInvalidationRegistry.shared.subscribe(credentials, listener: listener)
  }
}

// MARK: - PortalSessionInvalidationHandle

/// One host subscription to `Portal.onSessionInvalidated(_:)`.
///
/// `cancel()` removes the listener and is idempotent, so a host can call it defensively from
/// `deinit`, from a SwiftUI `onDisappear`, or from inside the listener itself. The handle
/// does **not** cancel automatically when it is deallocated — parity with the React Native
/// and Android SDKs, where the unsubscribe is an explicit call — so a host that discards the
/// handle keeps receiving the notification. The initializer is public so host-written
/// `PortalProtocol` conformers and test doubles can hand back a real handle.
public final class PortalSessionInvalidationHandle {
  /// The handle returned for a subscription that can never fire (a Client API Key, or a
  /// credential the SDK has already reported). Shared so nothing is retained on its behalf;
  /// `cancel()` on it is a no-op.
  public static let spent = PortalSessionInvalidationHandle(onCancel: nil)

  private let lock = NSLock()
  private var onCancel: (() -> Void)?

  /// Creates a handle whose `cancel()` runs `onCancel` exactly once. Pass `nil` for a handle
  /// that has nothing to undo.
  public init(onCancel: (() -> Void)? = nil) {
    self.onCancel = onCancel
  }

  /// Removes the subscription. Safe to call any number of times, from any thread, and from
  /// inside the listener: the cancellation closure is taken under the handle's own lock and
  /// invoked outside it, so it can re-enter the registry without deadlocking.
  public func cancel() {
    self.lock.lock()
    let action = self.onCancel
    self.onCancel = nil
    self.lock.unlock()

    action?()
  }
}

// MARK: - CredentialInvalidationRegistry

/// Process-wide bookkeeping for credential invalidation, keyed by credential identity so it
/// is reachable from the 401 call sites — which see a credential and nothing else.
///
/// Three maps live here, all guarded by one `NSLock` and all keyed by `ObjectIdentifier`:
/// the per-credential monitors `PortalCredentialSupport.invalidate(_:)` serialises on, the host listener
/// entries `PortalCredentialSupport.onInvalidated(_:listener:)` appends to, and the once-ever "reported"
/// set `reportUnauthorized(_:)` consults. `ObjectIdentifier` is only unique while the object
/// is alive, so every entry also holds the credential weakly and every lookup re-checks
/// identity with `===`: a credential that died and had its address reused can never inherit
/// a stale monitor, listener list or reported flag. Dead entries are pruned under the lock on
/// every operation. The registry lock is never held while calling into host code — not
/// `invalidate()`, not a listener — which is what makes re-entrant and cross-credential
/// invalidation safe.
final class CredentialInvalidationRegistry {
  /// The registry every free function in this file uses. Tests reset it between cases with
  /// `resetForTesting()` so the once-ever reported flags cannot leak from one test to the next.
  static let shared = CredentialInvalidationRegistry()

  /// A weak reference to a credential, used for the reported set so a dead credential does
  /// not pin its flag onto whichever object next occupies its address.
  private final class WeakCredential {
    weak var credential: PortalCredentials?

    init(_ credential: PortalCredentials) {
      self.credential = credential
    }
  }

  /// One subscription. Wrapped with a unique id rather than stored as a bare closure so
  /// subscribing the same closure twice yields two subscriptions, each cancellable alone.
  private struct Subscription {
    let id: UInt64
    let listener: @MainActor () -> Void
  }

  private final class ListenerEntry {
    weak var credential: PortalCredentials?
    var subscriptions: [Subscription] = []

    init(_ credential: PortalCredentials) {
      self.credential = credential
    }
  }

  private final class MonitorEntry {
    weak var credential: PortalCredentials?
    let monitor = NSRecursiveLock()

    init(_ credential: PortalCredentials) {
      self.credential = credential
    }
  }

  private let lock = NSLock()
  private var monitors: [ObjectIdentifier: MonitorEntry] = [:]
  private var entries: [ObjectIdentifier: ListenerEntry] = [:]
  private var reported: [ObjectIdentifier: WeakCredential] = [:]
  private var nextSubscriptionId: UInt64 = 0

  init() {}

  /// Number of credentials that currently have at least one live listener. A test seam for
  /// asserting that entries are pruned when a credential deallocates.
  var entryCount: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self.entries.count
  }

  /// Number of per-credential monitors currently retained. A test seam for asserting that
  /// monitors do not grow without bound as credentials come and go.
  var monitorCount: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self.monitors.count
  }

  /// Forgets every monitor, listener and reported flag. Only for tests: in production a
  /// reported credential must stay reported for the life of the process.
  func resetForTesting() {
    self.lock.lock()
    defer { self.lock.unlock() }
    self.monitors.removeAll()
    self.entries.removeAll()
    self.reported.removeAll()
  }

  /// The monitor `PortalCredentialSupport.invalidate(_:)` serialises on for `credentials`, created on
  /// first use. Recursive so a credential whose `invalidate()` routes back through the SDK
  /// for the same credential does not deadlock on itself. Returned, not held: the caller
  /// takes it after this method has released the registry lock.
  func monitor(for credentials: PortalCredentials) -> NSRecursiveLock {
    self.lock.lock()
    defer { self.lock.unlock() }
    self.pruneStaleEntries()

    let key = ObjectIdentifier(credentials)
    if let existing = self.monitors[key], existing.credential === credentials {
      return existing.monitor
    }

    let entry = MonitorEntry(credentials)
    self.monitors[key] = entry
    return entry.monitor
  }

  /// Registers `listener` for `credentials`; see `PortalCredentialSupport.onInvalidated(_:listener:)`.
  func subscribe(
    _ credentials: PortalCredentials,
    listener: @escaping @MainActor () -> Void
  ) -> PortalSessionInvalidationHandle {
    // A Client API Key is never reported, so registering would only hold the listener, and
    // whatever it captured, for as long as the credential lives.
    if credentials is StaticCredentials {
      return .spent
    }

    self.lock.lock()
    self.pruneStaleEntries()

    let key = ObjectIdentifier(credentials)
    // A credential this process has already reported: the rejection happened before this
    // listener existed, which is exactly what a host that subscribed a moment after `Portal`'s
    // eager client fetch was rejected needs to hear. Replay it — once, on the main actor, and
    // cancellable until it runs — instead of dropping the listener silently.
    if self.isReported(credentials, key: key) {
      self.lock.unlock()
      return Self.replay(listener)
    }

    let entry: ListenerEntry
    if let existing = self.entries[key], existing.credential === credentials {
      entry = existing
    } else {
      entry = ListenerEntry(credentials)
      self.entries[key] = entry
    }

    self.nextSubscriptionId += 1
    let subscriptionId = self.nextSubscriptionId
    entry.subscriptions.append(Subscription(id: subscriptionId, listener: listener))
    self.lock.unlock()

    return PortalSessionInvalidationHandle(onCancel: { [weak self] in
      self?.unsubscribe(key: key, id: subscriptionId)
    })
  }

  /// Tells the host the session behind `credentials` ended — at most once per credential,
  /// and never for a `StaticCredentials`.
  ///
  /// Listeners are snapshotted under the lock and dispatched outside it, each on the main
  /// actor via its own `Task`, so a listener is free to cancel itself, subscribe another
  /// listener or report another credential from inside the callback. The entry is dropped
  /// rather than kept: this fires once per credential, so the list can never be read again
  /// and would otherwise go on holding whatever the listeners captured.
  func notifyInvalidated(_ credentials: PortalCredentials) {
    // A host-supplied credential is not necessarily a session, but only a static key is known
    // not to be one — anything else is treated as a session and reported.
    if credentials is StaticCredentials {
      return
    }

    self.lock.lock()
    self.pruneStaleEntries()

    let key = ObjectIdentifier(credentials)
    if self.isReported(credentials, key: key) {
      self.lock.unlock()
      return
    }
    self.reported[key] = WeakCredential(credentials)

    var snapshot: [Subscription] = []
    if let entry = self.entries[key], entry.credential === credentials {
      snapshot = entry.subscriptions
      self.entries.removeValue(forKey: key)
    }
    self.lock.unlock()

    for subscription in snapshot {
      Task { @MainActor in
        subscription.listener()
      }
    }
  }

  /// Delivers `listener` once, on the main actor, for a credential that was reported before the
  /// subscription was made. The handle's `cancel()` suppresses the delivery if it has not run.
  private static func replay(_ listener: @escaping @MainActor () -> Void) -> PortalSessionInvalidationHandle {
    let gate = ReplayGate()
    Task { @MainActor in
      if gate.claim() {
        listener()
      }
    }
    return PortalSessionInvalidationHandle(onCancel: { gate.cancel() })
  }

  /// One-shot flag shared by a replayed delivery and its handle: whichever of `claim()` and
  /// `cancel()` runs first settles it.
  private final class ReplayGate: @unchecked Sendable {
    private let lock = NSLock()
    private var settled = false

    /// `true` exactly once, and never after `cancel()`.
    func claim() -> Bool {
      self.lock.lock()
      defer { self.lock.unlock() }
      if self.settled {
        return false
      }
      self.settled = true
      return true
    }

    func cancel() {
      self.lock.lock()
      self.settled = true
      self.lock.unlock()
    }
  }

  private func unsubscribe(key: ObjectIdentifier, id: UInt64) {
    self.lock.lock()
    defer { self.lock.unlock() }

    guard let entry = self.entries[key] else {
      return
    }
    entry.subscriptions.removeAll { $0.id == id }
    if entry.subscriptions.isEmpty {
      self.entries.removeValue(forKey: key)
    }
  }

  /// Must be called with `lock` held. A stale flag (dead credential, or a live one that is
  /// not `===` the caller's) is treated as absent so a reused address never reads as reported.
  private func isReported(_ credentials: PortalCredentials, key: ObjectIdentifier) -> Bool {
    guard let box = self.reported[key] else {
      return false
    }
    return box.credential === credentials
  }

  /// Must be called with `lock` held. Drops every entry whose credential has deallocated.
  private func pruneStaleEntries() {
    self.monitors = self.monitors.filter { $0.value.credential != nil }
    self.entries = self.entries.filter { $0.value.credential != nil }
    self.reported = self.reported.filter { $0.value.credential != nil }
  }
}

// MARK: - UnauthorizedHookRegistry

/// Which credentials own each transport's 401 hook, keyed by transport identity.
///
/// A transport carries one `onUnauthorized` closure but may serve several SDK objects holding
/// different credentials, so the closure the SDK installs looks its owners up here and reports
/// only the one that presented the rejected bearer. Entries hold the transport and every owner
/// weakly and are pruned on each operation, so a transport or credential that deallocates never
/// pins a stale attribution onto whichever object next occupies its address. The lock is never
/// held while calling into host code: `getToken()` and `reportUnauthorized(_:)` run on a
/// snapshot taken under it.
final class UnauthorizedHookRegistry {
  static let shared = UnauthorizedHookRegistry()

  private final class Owner {
    weak var credentials: PortalCredentials?
    let context: String

    init(_ credentials: PortalCredentials, context: String) {
      self.credentials = credentials
      self.context = context
    }
  }

  private final class TransportEntry {
    weak var transport: PortalUnauthorizedReporting?
    var owners: [Owner] = []

    init(_ transport: PortalUnauthorizedReporting) {
      self.transport = transport
    }
  }

  private let lock = NSLock()
  private var entries: [ObjectIdentifier: TransportEntry] = [:]

  /// Test seam: how many live transports currently carry a hook.
  var transportCount: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    self.pruneStaleEntries()
    return self.entries.count
  }

  /// Test seam: forgets every transport, so a case can count the hooks one construction installs.
  func resetForTesting() {
    self.lock.lock()
    defer { self.lock.unlock() }
    self.entries.removeAll()
  }

  init() {}

  /// Records `credentials` as an owner of `transport`'s hook, installing the hook when the
  /// transport has none. A hook the SDK did not install is left alone and nothing is recorded.
  /// Registering the same credential twice is a no-op.
  func install(on transport: PortalUnauthorizedReporting, for credentials: PortalCredentials, context: String) {
    self.lock.lock()
    defer { self.lock.unlock() }
    self.pruneStaleEntries()

    let key = ObjectIdentifier(transport)
    if let entry = self.entries[key], entry.transport === transport {
      if !entry.owners.contains(where: { $0.credentials === credentials }) {
        entry.owners.append(Owner(credentials, context: context))
      }
      return
    }

    // Not a hook of ours: whatever is installed came from somewhere else and is never replaced.
    guard transport.onUnauthorized == nil else {
      return
    }

    let entry = TransportEntry(transport)
    entry.owners = [Owner(credentials, context: context)]
    self.entries[key] = entry
    transport.onUnauthorized = { [weak transport] rejectedBearerToken in
      guard let transport = transport else {
        return
      }
      UnauthorizedHookRegistry.shared.report(bearerToken: rejectedBearerToken, from: transport)
    }
  }

  /// Reports the owner(s) of `transport` whose credential presented `bearerToken`.
  ///
  /// Every owner whose current `getToken()` equals the rejected bearer is reported — normally
  /// exactly one. When the header used a non-Bearer scheme no token is known, and a lone owner is
  /// reported anyway, because its credential is the only one the transport could have sent. A
  /// bearer that *is* known but matches no owner's current token is left alone, however many
  /// owners there are: the token rotated (or was invalidated) between request and response, so
  /// the rejection was for a value nobody holds any more, and invalidating the value that
  /// replaced it would sign the user out for a stale token's 401 — the very rotation
  /// `resolveToken` exists to support. With several owners and no token nothing is reported and
  /// the ambiguity is logged: invalidating the wrong session is worse than leaving the caller with
  /// the `PortalRequestsError.unauthorized` it is about to receive anyway. The token is compared,
  /// never logged.
  ///
  /// The match and the invalidation are separate calls, so a host credential that rotates in the
  /// gap between them is still invalidated for the old bearer's 401. Accepted, not closed: the
  /// rotation happens in host code the SDK cannot lock, and an atomic compare-and-invalidate would
  /// be a new `PortalCredentials` requirement that breaks parity with Android's two-method
  /// contract. The comparison narrows the exposure from the request's full duration to that gap;
  /// see `PortalCredentialSupport.reportUnauthorizedAndLog(_:rejectedToken:context:)`, which
  /// applies the same rule and accepts the same window on the non-transport paths.
  func report(bearerToken: String?, from transport: PortalUnauthorizedReporting) {
    self.lock.lock()
    self.pruneStaleEntries()
    let key = ObjectIdentifier(transport)
    guard let entry = self.entries[key], entry.transport === transport else {
      self.lock.unlock()
      PortalLogger.shared.debug("UnauthorizedHookRegistry.report() - Received a 401 from a transport with no registered owners; nothing to report.")
      return
    }
    let owners: [(credentials: PortalCredentials, context: String)] = entry.owners.compactMap { owner in
      owner.credentials.map { ($0, owner.context) }
    }
    self.lock.unlock()

    let matches = owners.filter { owner in
      guard let bearerToken = bearerToken else {
        return false
      }
      return (try? owner.credentials.getToken()) == bearerToken
    }

    let targets: [(credentials: PortalCredentials, context: String)]
    if !matches.isEmpty {
      targets = matches
    } else if bearerToken != nil {
      PortalLogger.shared.debug("UnauthorizedHookRegistry.report() - A 401 rejected a bearer that no registered credential currently holds (rotated or already invalidated); no credential was invalidated.")
      return
    } else if owners.count == 1 {
      targets = owners
    } else {
      PortalLogger.shared.error("UnauthorizedHookRegistry.report() - A 401 with no bearer token on a transport shared by \(owners.count) credentials could not be attributed to any of them; no credential was invalidated.")
      return
    }

    for owner in targets {
      PortalCredentialSupport.reportUnauthorizedAndLog(owner.credentials, context: owner.context)
    }
  }

  /// Must be called with `lock` held. Drops owners whose credential deallocated and entries whose
  /// transport did. An entry whose transport is alive is kept even with no owners left: the
  /// transport still carries our closure, and the next `install` on it must add to that entry
  /// rather than mistake the closure for someone else's.
  private func pruneStaleEntries() {
    for (key, entry) in self.entries {
      entry.owners.removeAll { $0.credentials == nil }
      if entry.transport == nil {
        self.entries.removeValue(forKey: key)
      }
    }
  }
}
