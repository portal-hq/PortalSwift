//
//  PortalAuth.swift
//  PortalSwift
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import AuthenticationServices
import Foundation

/// Drives Portal's Client Auth APIs and resolves a `PortalSession` the host passes to
/// `Portal(credentials:)`.
///
/// `PortalAuth` and `Portal` share no object graph: this class never touches wallet, MPC or
/// signing code, and nothing here constructs a `Portal`. The host owns when authentication
/// starts, all UI, deep-link registration and forwarding, and wallet creation.
///
/// Two browser modes ship side by side. `loginWithGoogle()` / `loginWithApple()` return an
/// authorize URL and nothing else — the host opens it however it likes and later forwards the
/// deep link to `handleRedirect(_:)`. `signInWithGoogle()` / `signInWithApple()` own an
/// `ASWebAuthenticationSession` end to end and return the `AuthResult` directly; they need a
/// presentation anchor (`setAuthPresentationAnchor(_:)`) and a custom-scheme `redirectUrl`.
///
/// **Hold one long-lived instance.** `handleRedirect(_:)` remembers the grant it last
/// exchanged so a re-delivered redirect replays instead of failing the backend's single-use
/// rejection, and that memory lives on the instance — one built per screen is destroyed by
/// the very lifecycle event the memory exists to survive.
///
/// ```swift
/// let auth = try PortalAuth(
///   authEnvironmentId: "fc00aa96-…",
///   redirectUrl: "portalexample://auth/callback",
///   magicLink: MagicLinkConfig(fromEmail: "login@example.com", templateId: "…")
/// )
///
/// try await auth.sendMagicLink("user@example.com")
///
/// // later, in the host's deep-link handler:
/// switch try await auth.handleRedirect(incomingUrl) {
/// case let .authenticated(result)?: let portal = try Portal(credentials: result.session)
/// case let .totpRequired(step)?: showTotpPrompt(step) // then auth.verifyTotp(code, userJwt: step.userJwt)
/// case nil: break // not ours — let another handler try
/// }
/// ```
///
/// Thread-safety: the replay memo and the pending TOTP write are only touched under
/// `grantMutex`; the presentation anchor, the ephemeral flag and the sign-in guard are guarded
/// by `stateLock`. Everything else is immutable after `init`.
public final class PortalAuth: @unchecked Sendable {
  /// Upper bound on an inbound redirect URL, in UTF-16 code units, applied before parsing.
  ///
  /// Deep links are attacker-reachable — any installed app can send one on a custom scheme —
  /// so the string is bounded at the trust boundary rather than inside each parser. A real
  /// redirect is roughly an order of magnitude below this; the grant token dominates it.
  static let maxRedirectUrlLength = 8192

  /// Upper bound, in `Character`s, on an `error` value copied into an error message.
  static let maxErrorLength = 100

  /// The last grant `handleRedirect` exchanged, and what it resolved to.
  ///
  /// One slot rather than a set: a replay is always of the most recent redirect, so remembering
  /// older grants would keep spent tokens — and the short-lived `userJwt` of a TOTP step —
  /// alive for no gain. The key is byte-exact on the token.
  private struct ConsumedGrant {
    let token: String
    let result: AuthResult
    /// The session record that has not yet reached the Keychain, or `nil` once it has (and
    /// always `nil` for `.totpRequired`, which persists nothing by design).
    ///
    /// The backend burns a grant — and retires a TOTP `userJwt` — before it answers, so a
    /// Keychain write failure must not throw the issued session away: the result is memoised
    /// first, and a re-delivered redirect retries the write (see `_replay`) instead of
    /// re-sending a token the backend already spent, which could only fail with 401.
    var pendingPersist: PersistedSession?
  }

  private let redirectUrl: String
  private let api: PortalAuthApi
  private let storage: AuthSessionStorage
  private let magicLink: MagicLinkConfig?
  private let isAccountAbstracted: Bool?
  private let webSessionFactory: () -> AuthWebSessionProviding

  /// Serialises every grant exchange, TOTP verification and persisted-session clear.
  ///
  /// Held from "read the memo" through the network exchange to the Keychain write, so two
  /// deliveries of one grant collapse into a single exchange and a sign-out cannot land
  /// between an exchange and its persist. Internal so tests can observe contention.
  let grantMutex = AsyncMutex()

  /// Guarded by `grantMutex`, never by `stateLock`: the read, the exchange and the write are
  /// one operation, and only a lock held across all three keeps two deliveries of the same
  /// grant from both reaching the backend.
  private var consumedGrant: ConsumedGrant?

  /// A `verifyTotp` whose code the backend accepted but whose Keychain write failed.
  private struct PendingTotpPersist {
    let userJwt: String
    let result: AuthenticatedResult
    let persisted: PersistedSession
  }

  /// The TOTP step `verifyTotp` last completed whose session has not reached the Keychain.
  ///
  /// The backend retires the `userJwt` before it answers, so a Keychain write failure after an
  /// accepted code leaves a live session that no request can re-issue. The redirect memo
  /// (`ConsumedGrant.pendingPersist`) finishes that login when a redirect is re-delivered, but
  /// the host cannot cause a re-delivery — and in the `signInWith*` flow never sees the callback
  /// at all — so the retry the host *can* make, `verifyTotp` again with the same `userJwt`, must
  /// finish the write instead of re-sending a token that can only be rejected. One slot, matched
  /// byte-exact on the JWT; cleared once any session reaches the Keychain (`_markPersisted`) and
  /// by `clearPersistedSession()`. Guarded by `grantMutex`.
  private var pendingTotpPersist: PendingTotpPersist?

  private let stateLock = NSLock()
  private weak var presentationAnchor: ASPresentationAnchor?
  private var _prefersEphemeralWebBrowserSession = false
  private var isSignInInFlight = false

  // MARK: - Init

  /// Creates an instance for one auth environment. Performs no Keychain or network I/O.
  ///
  /// - Parameters:
  ///   - authEnvironmentId: The auth environment these logins belong to. Also the session's
  ///     storage key, so two instances sharing one share the persisted session.
  ///   - redirectUrl: Where the Portal backend sends the user once the magic link (or a
  ///     provider) is done. Must be allow-listed for the auth environment and must match the
  ///     URL scheme (or Universal Link) the host app registers. `signInWith*` additionally
  ///     requires a custom scheme.
  ///   - apiHost: Optional API host override; `localhost`/`127.0.0.1` get `http://`.
  ///   - magicLink: Required only by `sendMagicLink(_:)`; OAuth-only apps never need it.
  ///   - isAccountAbstracted: When set, requests an account-abstracted client. Omitted from
  ///     every request when `nil`.
  /// - Throws: `PortalAuthError.invalidArgument(name:)` when `authEnvironmentId` or
  ///   `redirectUrl` is blank — `authEnvironmentId` is reported first, matching the other SDKs.
  public convenience init(
    authEnvironmentId: String,
    redirectUrl: String,
    apiHost: String = "api.portalhq.io",
    magicLink: MagicLinkConfig? = nil,
    isAccountAbstracted: Bool? = nil
  ) throws {
    guard !Self.isBlank(authEnvironmentId) else {
      throw PortalAuthError.invalidArgument(name: "authEnvironmentId")
    }
    guard !Self.isBlank(redirectUrl) else {
      throw PortalAuthError.invalidArgument(name: "redirectUrl")
    }

    // The configured host is Portal-owned for the 401 and trace gates (see `PortalOwnedHosts`).
    PortalOwnedHosts.register(apiHost)

    self.init(
      // Stored trimmed: the blank check above trims, and the backend's allow-list match is exact,
      // so surrounding whitespace would pass every local check and fail only server-side.
      redirectUrl: redirectUrl.trimmingCharacters(in: .whitespacesAndNewlines),
      api: PortalAuthApi(authEnvironmentId: authEnvironmentId, apiHost: apiHost, requests: PortalRequests()),
      // Keyed by `authEnvironmentId`: instances sharing one share the session.
      storage: KeychainAuthSessionStorage(authEnvironmentId: authEnvironmentId),
      magicLink: magicLink,
      isAccountAbstracted: isAccountAbstracted
    )
  }

  /// Designated initializer and test seam: injects the transport, the storage and the web
  /// session factory. Performs no I/O.
  init(
    redirectUrl: String,
    api: PortalAuthApi,
    storage: AuthSessionStorage,
    magicLink: MagicLinkConfig? = nil,
    isAccountAbstracted: Bool? = nil,
    webSessionFactory: @escaping () -> AuthWebSessionProviding = { ASWebAuthenticationSessionAdapter() }
  ) {
    self.redirectUrl = redirectUrl
    self.api = api
    self.storage = storage
    self.magicLink = magicLink
    self.isAccountAbstracted = isAccountAbstracted
    self.webSessionFactory = webSessionFactory
  }

  // MARK: - Browser presentation

  /// Whether `signInWith*` asks for an ephemeral browser session (no shared cookies, so an
  /// already-signed-in Google or Apple account is not reused). Defaults to `false` so users
  /// get the one-tap experience; read at the start of each sign-in.
  ///
  /// The SDK cannot clear the system browser's cookies, so with the default a sign-out followed
  /// by a sign-in reuses the same Google or Apple account. A host whose sign-out must allow
  /// switching accounts should set this to `true` before the next `signInWith*`.
  public var prefersEphemeralWebBrowserSession: Bool {
    get {
      self.stateLock.lock()
      defer { self.stateLock.unlock() }
      return self._prefersEphemeralWebBrowserSession
    }
    set {
      self.stateLock.lock()
      defer { self.stateLock.unlock() }
      self._prefersEphemeralWebBrowserSession = newValue
    }
  }

  /// The window `signInWith*` presents the browser sheet from. Held weakly — the host owns its
  /// windows — so a sign-in started after the window is gone fails with
  /// `PortalAuthSignInError.unavailable` rather than presenting from nowhere.
  public func setAuthPresentationAnchor(_ anchor: ASPresentationAnchor) {
    self.stateLock.lock()
    defer { self.stateLock.unlock() }
    self.presentationAnchor = anchor
  }

  // MARK: - Methods

  /// The auth methods enabled for this environment, plus whether it expects a wallet.
  /// Idempotent and side-effect free, so safe to retry. A TOTP requirement is *not*
  /// observable here — it only shows up in a grant-exchange response.
  public func getMethods() async throws -> AuthMethodsResult {
    try await self.api.getMethods()
  }

  // MARK: - Magic link

  /// Sends a magic-link email.
  ///
  /// Returns once the email is **sent**; the eventual login arrives as a deep link and
  /// completes through `handleRedirect(_:)`. That deep link is delivered by the OS URL handler,
  /// so the redirect-hijacking note on `loginWithGoogle()` applies to it as well: an app that
  /// registered your scheme can deliver a grant of its own. The address is trimmed and lowercased first (the
  /// backend requires lowercase and does not trim). Every call delivers a real email and sends
  /// are rate limited, so **never retry automatically** — a resend is an explicit user action.
  ///
  /// - Throws: `PortalAuthError.magicLinkNotConfigured` when the instance has no `magicLink`;
  ///   `.invalidArgument(name: "email")` for a blank address — both before any network call;
  ///   `.rateLimited` on `429`; `.accountAbstractionUnavailable` on the account-abstraction
  ///   `400`; other transport errors unchanged.
  public func sendMagicLink(_ email: String) async throws {
    // `fromEmail` and `templateId` are backend-required, so reject locally rather than
    // spending a round trip to be told so.
    guard let config = self.magicLink else {
      throw PortalAuthError.magicLinkNotConfigured
    }

    let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !normalizedEmail.isEmpty else {
      throw PortalAuthError.invalidArgument(name: "email")
    }

    try await self.api.sendMagicLink(
      email: normalizedEmail,
      redirectUrl: self.redirectUrl,
      magicLink: config,
      isAccountAbstracted: self.isAccountAbstracted
    )
    PortalLogger.shared.debug("PortalAuth.sendMagicLink() - Magic link sent.")
  }

  // MARK: - OAuth (URL only)

  /// The Google authorize URL to open in a browser. Does **not** open one: the host owns that,
  /// and how it does it decides whether the login survives being backgrounded.
  ///
  /// Fetched fresh on every call and **must not be cached**: one single-use `state` is shared
  /// by both provider URLs in a single backend response, so a stale one fails at the provider
  /// with no useful message. For a flow that also owns the browser, see `signInWithGoogle()`.
  ///
  /// **Redirect hijacking.** The callback this URL ends in comes back through the OS URL
  /// handler, which delivers it to whichever installed app registered your URL scheme — and
  /// `handleRedirect(_:)` cannot tell a grant from *your* flow from one another app started,
  /// because the redirect carries no app-side `state` (the backend's `state` binds the provider
  /// to Portal, not the app to Portal). An app that claims the same scheme can therefore hand
  /// your user a grant *it* obtained and sign them into *its* end-user account. Prefer
  /// `signInWithGoogle()`: its `ASWebAuthenticationSession` returns the callback to the SDK
  /// directly and never routes it through the OS. If you must open the URL yourself, treat this
  /// as a known exposure shared by every Portal SDK; binding an app-side state is tracked as a
  /// cross-platform backend change.
  ///
  /// - Throws: `PortalAuthError.authMethodUnavailable(.google)` when Google is not enabled for
  ///   this environment. Not retryable — check `getMethods()`.
  public func loginWithGoogle() async throws -> AuthorizeUrlResult {
    try await self.getAuthorizeUrl(.google)
  }

  /// The Apple authorize URL to open in a browser. See `loginWithGoogle()` for how to open it,
  /// why the result must not be cached, and the redirect-hijacking exposure of opening the URL
  /// yourself rather than through `signInWithApple()`.
  ///
  /// Sign in with Apple identifies end users differently: Portal identifies an end user by
  /// email, and a user who chooses *Hide My Email* becomes a distinct end user (with a distinct
  /// client and wallet) from the same person signing in with Google or a magic link. Apple also
  /// supplies the email only on the user's first consent for a given Service ID, so changing
  /// the Service ID is a breaking change for existing users.
  ///
  /// - Throws: `PortalAuthError.authMethodUnavailable(.apple)` when Apple is not enabled.
  public func loginWithApple() async throws -> AuthorizeUrlResult {
    try await self.getAuthorizeUrl(.apple)
  }

  // MARK: - Redirect

  /// The single completion path for every flow.
  ///
  /// Returns `nil` when the URL does not target this instance's `redirectUrl` or carries no
  /// Client Auth grant, so it is safe to call on every instance and safe for the app's router
  /// to try other handlers afterwards. Throws when the URL matches but carries `?error=…`. It
  /// trusts any grant that arrives on your redirect URL — see the redirect-hijacking note on
  /// `loginWithGoogle()` for what that means when the URL is delivered by the OS.
  ///
  /// Safe to call twice with the same grant: the first exchange's result is remembered and
  /// replayed, so a redirect the system re-delivers resolves to the same `AuthResult` — and
  /// the same `PortalSession` instance — rather than failing the backend's single-use
  /// rejection. A redirect that failed on a dropped connection or a rejected grant is not
  /// remembered and stays retryable. A successful exchange whose Keychain write failed *is*
  /// remembered — the backend has already spent the grant — and the replay retries the write
  /// instead of re-sending the token. A remembered session the backend has since rejected is
  /// not replayed: the redirect fails with `PortalRequestsError.unauthorized`, like a spent
  /// grant. The memory belongs to this instance and this process: `clearPersistedSession()`
  /// drops it, and after a process death the recovery is `restoreSession()`.
  ///
  /// On success the session is persisted **before** it is returned, so a Keychain write
  /// failure rejects the login rather than handing back a session that will not survive a
  /// restart. URLs longer than 8192 UTF-16 units return `nil` without being parsed.
  ///
  /// Cancellation is honoured only *before* the exchange starts: a call made from an already
  /// cancelled task throws `CancellationError` and sends nothing. Once the exchange has begun it
  /// runs to completion even if the calling task is cancelled meanwhile — the backend burns the
  /// grant before it answers, so aborting the request would strand a session that exists
  /// everywhere except on this device — and the result is still returned.
  ///
  /// Returns `.totpRequired` when the grant carries a `userJwt` instead of a session token.
  /// Nothing is persisted on that path; complete it with `verifyTotp(_:userJwt:)`. A grant left
  /// on that step replays as the same step; once `verifyTotp` accepts the code the same grant
  /// replays as the `.authenticated` it resolved to.
  ///
  /// - Throws: `PortalAuthError.authenticationFailed(error:)` when the redirect reports an
  ///   error; `.invalidGrantResponse` when the exchange returns neither a session token nor a
  ///   `userJwt`; `.malformedResponse` / `.sessionStorageFailure`; a rejected grant surfaces
  ///   as `PortalRequestsError.unauthorized`, unmapped.
  public func handleRedirect(_ url: String) async throws -> AuthResult? {
    try await self._handleRedirect(url)
  }

  /// `handleRedirect(_ url: String)` for a `URL` (the type `UIApplicationDelegate` and
  /// `onOpenURL` hand out). Forwards `absoluteString`, which keeps the percent-encoding intact
  /// so the grant is decoded exactly once.
  public func handleRedirect(_ url: URL) async throws -> AuthResult? {
    try await self._handleRedirect(url.absoluteString)
  }

  // MARK: - TOTP

  /// Submits a TOTP code for a login that returned `.totpRequired`.
  ///
  /// Pass `userJwt` back exactly as received; the code is posted verbatim (no trimming or
  /// length check — the host gates what it submits). A wrong code does **not** consume the JWT,
  /// so re-prompting is the normal path; if it expires, or the process dies first, the login
  /// restarts from the beginning.
  ///
  /// On success the session is persisted before it is returned, on the same terms as
  /// `handleRedirect(_:)`, and the grant that opened the TOTP step stops replaying as a step:
  /// a redirect re-delivered afterwards resolves to this same `AuthenticatedResult`'s session.
  ///
  /// A Keychain write failure *after* the code was accepted is retryable with the **same**
  /// `userJwt`: the backend has already retired the JWT, so the next `verifyTotp` for it finishes
  /// the write and returns the session that was issued, without a network call (`code` is not
  /// consulted on that path). A different `userJwt` starts a new verification.
  ///
  /// Cancellation is honoured only before the request is sent, on the same terms as
  /// `handleRedirect(_:)`: the JWT is retired by the backend before it answers, so a verification
  /// that has begun runs to completion and returns even to a cancelled caller.
  ///
  /// - Throws: `PortalAuthError.invalidUserJwt(detail:)` when `userJwt` cannot be read — raised
  ///   **before** the network call, so a bad JWT never costs the user a live code;
  ///   `.malformedResponse(path, "clientSessionToken")` when the response carries no session
  ///   token; `.sessionStorageFailure`; a rejected code surfaces as the transport error.
  public func verifyTotp(_ code: String, userJwt: String) async throws -> AuthenticatedResult {
    // Read first, outside the lock: this is the session's only source of an `endUserId`, since
    // the TOTP endpoint returns none. Failing here costs nothing; failing after the call would
    // have spent a code the user physically typed.
    let endUserId = try UserJwt.readEndUserId(from: userJwt)

    // A caller that is already cancelled must not spend a code it no longer wants. Past this
    // point cancellation no longer reaches the verification — see `_shieldedFromCancellation`.
    try Task.checkCancellation()

    // Held from before the request through the persist, on the same terms as `handleRedirect`:
    // it keeps `clearPersistedSession()` from landing between the two and leaving a signed-out
    // user with a session that outlived the sign-out.
    return try await self._shieldedFromCancellation { try await self.grantMutex.withLock {
      // The code for this JWT was already accepted and only the write is outstanding: finish it.
      // Re-sending the JWT could only come back 401 — the backend retired it when it answered.
      if let pending = self.pendingTotpPersist, pending.userJwt == userJwt {
        return try self._finishPendingTotp(pending)
      }

      let validation = try await self.api.validateTotp(code: code, userJwt: userJwt)

      let persisted = PersistedSession(clientSessionToken: validation.clientSessionToken, endUserId: endUserId)
      let result = self._makeAuthenticated(persisted, clientId: validation.clientId, isAccountAbstracted: validation.isAccountAbstracted)
      // Memoised before the write for the same reason as `_exchangeGrant`: the backend retires
      // the `userJwt` before it answers, so a persist failure must leave a re-delivered redirect
      // able to finish the login rather than replaying a TOTP step that can never be accepted —
      // and remembered against the JWT as well, so the host's own retry (the only retry it can
      // make in the `signInWith*` flow) finishes the write rather than re-sending the spent JWT.
      self._completeTotpStep(userJwt: userJwt, result: result, pendingPersist: persisted)
      self.pendingTotpPersist = PendingTotpPersist(userJwt: userJwt, result: result, persisted: persisted)
      try self._persist(persisted)
      self._markPersisted()
      PortalLogger.shared.debug("PortalAuth.verifyTotp() - TOTP accepted; session persisted for endUserId: \(endUserId).")
      return result
    } }
  }

  // MARK: - Persistence

  /// Rebuilds a session from the locally persisted token, or `nil` if storage holds nothing
  /// usable.
  ///
  /// A restored token is a credential worth trying, not proof of validity — validity is
  /// discovered through the first authenticated `Portal` call, which invalidates the credential
  /// on a `401`. No network call is made here.
  ///
  /// **A session that cannot be recovered reads as `nil`, not as a failure.** An entry that
  /// will not parse is cleared by the storage layer and reported as "signed out": no caller
  /// action makes it readable, so failing the launch would only strand the app. Treat `nil` as
  /// "show the sign-in screen". Note that Keychain items survive app deletion, so a
  /// delete-and-reinstall can restore a still-live session from the previous install; hosts
  /// that want a clean slate call `clearPersistedSession()` on first launch after install.
  ///
  /// Deliberately outside `grantMutex`. The read is atomic on its own — the storage serialises
  /// read, parse and self-heal under one lock — so it never observes a torn write. Ordering
  /// against a concurrent `clearPersistedSession()` is not something the mutex could add: a
  /// restore that acquires first returns the session and the clear then deletes the persisted
  /// copy, which is the same end state as the unlocked race, because clearing never revokes a
  /// session already handed out (there is no server-side revoke). The guarantee documented on
  /// `clearPersistedSession()` is only that a restore *started after* it returns finds nothing,
  /// and the storage lock already provides that. Taking the mutex here would instead make this
  /// launch-time, network-free read block behind an in-flight grant exchange. Android's
  /// `restoreSession` is likewise outside `grantLock`.
  ///
  /// - Throws: `PortalAuthError.sessionStorageFailure` when the session could not be read
  ///   *this time* (a transient Keychain fault), or an unusable entry could not be cleared.
  public func restoreSession() async throws -> PortalSession? {
    let persisted: PersistedSession?
    do {
      persisted = try self.storage.getSession()
    } catch {
      throw Self.storageFailure(error, context: "PortalAuth.restoreSession()", message: "The persisted session could not be read.")
    }

    guard let persisted = persisted else {
      PortalLogger.shared.debug("PortalAuth.restoreSession() - No persisted session.")
      return nil
    }

    PortalLogger.shared.debug("PortalAuth.restoreSession() - Restored the persisted session for endUserId: \(persisted.endUserId).")
    return KeychainPortalSession(
      clientSessionToken: persisted.clientSessionToken,
      endUserId: persisted.endUserId,
      storage: self.storage
    )
  }

  /// Removes the locally persisted session and forgets the grant `handleRedirect(_:)` last
  /// exchanged and any TOTP write still pending, so neither a redirect re-delivered after a
  /// sign-out nor a repeated `verifyTotp` can bring back the session that was just cleared.
  ///
  /// No server-side revoke endpoint exists, so this does not affect a `Portal` already holding
  /// the credential; it prevents a future `restoreSession()` from returning it. Waits for an
  /// in-flight `handleRedirect` / `verifyTotp` to finish persisting before deleting, so a login
  /// cannot write a session back into storage after the delete.
  ///
  /// - Throws: `PortalAuthError.sessionStorageFailure` when the delete fails.
  public func clearPersistedSession() async throws {
    try await self.grantMutex.withLock {
      do {
        try self.storage.delete()
      } catch {
        throw Self.storageFailure(error, context: "PortalAuth.clearPersistedSession()", message: "The persisted session could not be deleted.")
      }
      self.consumedGrant = nil
      self.pendingTotpPersist = nil
      PortalLogger.shared.debug("PortalAuth.clearPersistedSession() - Persisted session cleared.")
    }
  }

  // MARK: - Sign in (browser owned by the SDK)

  /// Completes a Google sign-in end to end using `ASWebAuthenticationSession`.
  ///
  /// Fetches a fresh authorize URL, presents the system browser sheet from the anchor set with
  /// `setAuthPresentationAnchor(_:)`, and hands the callback URL to the same code path as
  /// `handleRedirect(_:)` — so replay, persist-before-return and the TOTP branch behave
  /// identically. Requires a custom-scheme `redirectUrl` (Universal Links are not supported by
  /// `ASWebAuthenticationSession`'s callback matching in this version). One sign-in at a time:
  /// both provider URLs share a single-use `state`, so a concurrent attempt throws
  /// `.signInInProgress` rather than invalidating the first. Cancelling the calling task
  /// dismisses the sheet and throws; the grant is never exchanged.
  ///
  /// - Throws: `PortalAuthSignInError` (`.unavailable`, `.signInInProgress`, `.closed`,
  ///   `.callbackIncomplete`), any `PortalAuthError` `handleRedirect(_:)` can throw, or the
  ///   transport error unchanged.
  public func signInWithGoogle() async throws -> AuthResult {
    try await self.signIn(.google)
  }

  /// Completes an Apple sign-in end to end. See `signInWithGoogle()` for the mechanics and
  /// `loginWithApple()` for how Apple identifies end users.
  public func signInWithApple() async throws -> AuthResult {
    try await self.signIn(.apple)
  }

  // MARK: - Private: redirect (the only caller of `grantMutex` on this path)

  /// The one body that takes `grantMutex` for a redirect. Both public overloads forward here.
  ///
  /// Order is contractual: empty / oversized → `nil`; not our target → `nil`; parse; `error`
  /// → throw (even when a token is present, and before any request); empty token → `nil`;
  /// then, under the lock, memo hit → replay, else exchange.
  private func _handleRedirect(_ url: String) async throws -> AuthResult? {
    guard !url.isEmpty, url.utf16.count <= Self.maxRedirectUrlLength else {
      return nil
    }
    guard RedirectUrl.matchesRedirectUrl(url, self.redirectUrl) else {
      return nil
    }

    let params = RedirectUrl.parseQueryParams(url.trimmingCharacters(in: .whitespacesAndNewlines))

    if let error = params["error"] {
      // Bounded: the backend only ever sends `oauth_failed`, but this string arrives from an
      // inbound URL and apps routinely surface error messages straight to the user.
      PortalLogger.shared.error("PortalAuth.handleRedirect() - The redirect reported an authentication error.")
      throw PortalAuthError.authenticationFailed(error: String(error.prefix(Self.maxErrorLength)))
    }

    guard let token = params["token"], !token.isEmpty else {
      return nil
    }

    // A caller that is already cancelled must not exchange a grant it no longer wants: the grant
    // is single-use, and a session minted for nobody is worse than one never minted. Past this
    // point cancellation no longer reaches the exchange — see `_shieldedFromCancellation`.
    try Task.checkCancellation()

    return try await self._shieldedFromCancellation { try await self.grantMutex.withLock {
      if let memo = self.consumedGrant, memo.token == token {
        return try self._replay(memo)
      }
      return try await self._exchangeGrant(token: token, params: params)
    } }
  }

  /// Runs `body` in a task of its own and awaits it, so a cancellation of the calling task that
  /// lands after `body` has started cannot abort it.
  ///
  /// `AsyncMutex` ignores cancellation while *waiting*, but the body it then runs is still the
  /// caller's task, and the production transport (`URLSession.data(for:)`) is cancellation-aware:
  /// a cancel arriving after the request left the device aborts it client-side while the backend,
  /// which burns the grant (and retires a TOTP `userJwt`) before answering, has already minted a
  /// session nobody will ever receive — and a redelivered redirect can only fail. An unstructured
  /// `Task` does not inherit the caller's cancellation, and awaiting its `value` is not itself a
  /// cancellation point, so the exchange completes and its result reaches even a cancelled caller.
  /// Callers check cancellation *before* entering, so nothing is started for a caller that is
  /// already gone.
  private func _shieldedFromCancellation<T: Sendable>(_ body: @escaping @Sendable () async throws -> T) async throws -> T {
    let task = Task { try await body() }
    return try await task.value
  }

  /// Serves a re-delivered redirect from the memo. Called only with `grantMutex` held.
  ///
  /// Two things a plain "return the memo" would get wrong. A session the backend has since
  /// rejected — `getToken()` throws `.sessionInvalidated` — must not be handed back as
  /// `.authenticated`: the memo is evicted and the redirect fails with
  /// `PortalRequestsError.unauthorized`, the same error a burned grant produces, so the host
  /// handles both the same way. And a session whose first Keychain write failed is written now:
  /// the grant is spent server-side, so this retry is the only way that login can still finish.
  private func _replay(_ memo: ConsumedGrant) throws -> AuthResult {
    guard case let .authenticated(result) = memo.result else {
      PortalLogger.shared.debug("PortalAuth.handleRedirect() - Replaying the TOTP step of an already-exchanged grant.")
      return memo.result
    }

    guard (try? result.session.getToken()) != nil else {
      PortalLogger.shared.error("PortalAuth.handleRedirect() - The replayed session has been invalidated; evicting the memo.")
      self.consumedGrant = nil
      throw PortalRequestsError.unauthorized
    }

    if let pending = memo.pendingPersist {
      PortalLogger.shared.debug("PortalAuth.handleRedirect() - Retrying the persist of an already-exchanged grant.")
      try self._persist(pending)
      self._markPersisted()
    } else {
      PortalLogger.shared.debug("PortalAuth.handleRedirect() - Replaying the result of an already-exchanged grant.")
    }
    return memo.result
  }

  /// Exchanges a grant that has not been seen before and remembers what it resolved to.
  ///
  /// A rejected grant or a dropped connection records nothing, so the redirect stays retryable.
  /// A failed persist is different: the backend has already burned the grant by the time it
  /// answers, so the issued session is memoised *before* the Keychain write and a re-delivered
  /// redirect retries the write (`ConsumedGrant.pendingPersist`, `_replay`) instead of re-sending
  /// a spent token. Called only with `grantMutex` held.
  private func _exchangeGrant(token: String, params: [String: String]) async throws -> AuthResult? {
    guard let grant = try await self.exchangeGrantToken(token, params: params) else {
      return nil
    }

    // Blank counts as absent. `PersistedSessionCodec` and `resolveCredentialToken` both reject a
    // whitespace-only token, so persisting one would only hand back a session that fails its
    // first request with `.unavailable` and is cleared by the next restore.
    if let clientSessionToken = grant.clientSessionToken, !Self.isBlank(clientSessionToken) {
      let endUserId = grant.endUserId ?? ""
      let persisted = PersistedSession(clientSessionToken: clientSessionToken, endUserId: endUserId)
      let result = AuthResult.authenticated(
        self._makeAuthenticated(persisted, clientId: grant.clientId, isAccountAbstracted: grant.isAccountAbstracted)
      )
      // Memoised before the write: the grant is already spent, so a persist failure must leave
      // a re-delivered redirect able to finish this login (see `ConsumedGrant.pendingPersist`).
      self.consumedGrant = ConsumedGrant(token: token, result: result, pendingPersist: persisted)
      try self._persist(persisted)
      self._markPersisted()
      PortalLogger.shared.debug("PortalAuth.handleRedirect() - Exchanged the grant and persisted the session for endUserId: \(endUserId).")
      return result
    }

    // A `userJwt` instead of a session token means a TOTP step is required. Nothing is
    // persisted on this path — the login is not complete until `verifyTotp` resolves a session.
    // Blank counts as absent here too, matching the session-token check above.
    guard let userJwt = grant.userJwt, !Self.isBlank(userJwt) else {
      PortalLogger.shared.error("PortalAuth.handleRedirect() - The grant response carried neither a session token nor a userJwt.")
      throw PortalAuthError.invalidGrantResponse
    }

    let step = TotpRequiredResult(
      userJwt: userJwt,
      // Present only on first-time enrollment. `nil` means the user is already enrolled.
      totpLink: grant.totpLink,
      // A label for the host's UI. The `endUserId` that identifies the persisted session is read
      // from the JWT's claims in `verifyTotp`, which does not depend on this.
      endUserId: grant.endUserId ?? ""
    )
    let result = AuthResult.totpRequired(step)
    self.consumedGrant = ConsumedGrant(token: token, result: result, pendingPersist: nil)
    PortalLogger.shared.debug("PortalAuth.handleRedirect() - The grant requires a TOTP step; nothing persisted.")
    return result
  }

  /// Routes a grant to the endpoint that can exchange it, or returns `nil` when the URL carries
  /// no recognisable auth-method marker.
  ///
  /// Magic-link redirects carry `authMethod`; OAuth callbacks carry `login_type`. Magic link is
  /// checked first (Android order); the two only disagree on a URL carrying both markers, which
  /// no healthy backend sends. Matching is exact on the wire value.
  private func exchangeGrantToken(_ token: String, params: [String: String]) async throws -> AuthGrantValidationResponse? {
    let authMethod = params["authMethod"].flatMap { AuthMethod(rawValue: $0) }
    let loginType = params["login_type"].flatMap { AuthMethod(rawValue: $0) }

    if authMethod == .emailMagicLink {
      return try await self.api.validateMagicLink(token: token)
    }
    // `/oauth/tokens` does not care which provider issued the grant, so both share it.
    if loginType == .google || loginType == .apple {
      return try await self.api.validateOAuthToken(token: token)
    }
    return nil
  }

  /// Advances the remembered grant from its TOTP step to the session that step resolved to.
  ///
  /// Without this the grant keeps replaying as `.totpRequired` for the life of the instance,
  /// sending an already-authenticated user back to the code prompt with a `userJwt` the
  /// backend has since spent. Matched on `userJwt` because that is the only thing tying the
  /// two halves together — the grant token is never passed back to `verifyTotp`. A JWT
  /// matching nothing leaves the memo alone rather than inventing an entry no redirect can
  /// replay. Called only with `grantMutex` held.
  private func _completeTotpStep(userJwt: String, result: AuthenticatedResult, pendingPersist: PersistedSession?) {
    guard let pending = self.consumedGrant,
          case let .totpRequired(step) = pending.result,
          step.userJwt == userJwt
    else {
      return
    }
    self.consumedGrant = ConsumedGrant(token: pending.token, result: .authenticated(result), pendingPersist: pendingPersist)
  }

  /// Finishes a `verifyTotp` whose code the backend already accepted but whose Keychain write
  /// failed: retries the write and returns the same result, with no network call. A session the
  /// backend has since rejected is not handed back — the slot is dropped and the call fails with
  /// `PortalRequestsError.unauthorized`, as `_replay` does for a redirect. Called only with
  /// `grantMutex` held.
  private func _finishPendingTotp(_ pending: PendingTotpPersist) throws -> AuthenticatedResult {
    guard (try? pending.result.session.getToken()) != nil else {
      PortalLogger.shared.error("PortalAuth.verifyTotp() - The session issued for the already-accepted code has been invalidated; dropping it.")
      self.pendingTotpPersist = nil
      throw PortalRequestsError.unauthorized
    }
    PortalLogger.shared.debug("PortalAuth.verifyTotp() - The code was already accepted; retrying the persist instead of re-sending the userJwt.")
    try self._persist(pending.persisted)
    self._markPersisted()
    return pending.result
  }

  /// Records that a session has reached the Keychain: the memo's pending write, if any, is done,
  /// and a TOTP step still waiting on a write is dropped — either it is this very session, or a
  /// newer login has since been persisted and a stale retry must not overwrite it.
  private func _markPersisted() {
    self.pendingTotpPersist = nil
    guard let memo = self.consumedGrant, memo.pendingPersist != nil else {
      return
    }
    self.consumedGrant = ConsumedGrant(token: memo.token, result: memo.result, pendingPersist: nil)
  }

  /// Builds the result for `persisted` without touching storage; `_persist(_:)` writes it. Split
  /// from the write so the result can be memoised before the write is attempted.
  private func _makeAuthenticated(
    _ persisted: PersistedSession,
    clientId: String?,
    isAccountAbstracted: Bool?
  ) -> AuthenticatedResult {
    let session = KeychainPortalSession(
      clientSessionToken: persisted.clientSessionToken,
      endUserId: persisted.endUserId,
      storage: self.storage
    )
    return AuthenticatedResult(session: session, clientId: clientId, isAccountAbstracted: isAccountAbstracted)
  }

  /// Writes `persisted` to the Keychain, wrapping any failure as `sessionStorageFailure`.
  private func _persist(_ persisted: PersistedSession) throws {
    do {
      let raw = try PersistedSessionCodec.encode(persisted)
      try self.storage.set(raw)
    } catch {
      throw Self.storageFailure(error, context: "PortalAuth.persistSession()", message: "The session could not be persisted.")
    }
  }

  // MARK: - Private: OAuth

  /// Resolves a provider's authorize URL, fetched fresh on every call and trimmed.
  ///
  /// Shared by `loginWith*` and `signInWith*`: the response carries one key per enabled
  /// provider, and picking a different key is the whole difference between them. Absent or
  /// blank means the provider is switched off for this environment, which a retry cannot change.
  private func getAuthorizeUrl(_ method: AuthMethod) async throws -> AuthorizeUrlResult {
    let urls = try await self.api.getOAuthUrls(redirectUrl: self.redirectUrl, isAccountAbstracted: self.isAccountAbstracted)

    // Exhaustive on purpose: a provider added to `AuthMethod` later is a compile error here
    // rather than a silent "unavailable".
    let rawUrl: String?
    switch method {
    case .google:
      rawUrl = urls.google
    case .apple:
      rawUrl = urls.apple
    case .emailMagicLink:
      rawUrl = nil
    }

    let authorizeUrl = (rawUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !authorizeUrl.isEmpty else {
      PortalLogger.shared.error("PortalAuth.getAuthorizeUrl() - \(method.rawValue) is not an enabled auth method for this auth environment.")
      throw PortalAuthError.authMethodUnavailable(method)
    }

    return AuthorizeUrlResult(authorizeUrl: authorizeUrl)
  }

  // MARK: - Private: sign in

  /// The shared body of `signInWithGoogle()` / `signInWithApple()`.
  ///
  /// Preconditions (anchor, custom scheme) are checked before the in-flight guard so a
  /// misconfigured call never leaves the guard held; the guard is released by `defer` on every
  /// exit. `grantMutex` is **not** held while the browser is open — only `_handleRedirect`
  /// takes it — so a magic-link redirect arriving mid-sign-in is still processed.
  private func signIn(_ method: AuthMethod) async throws -> AuthResult {
    let (anchor, prefersEphemeral) = self.readSignInPreconditions()

    guard let anchor = anchor else {
      PortalLogger.shared.error("PortalAuth.signIn() - No presentation anchor is set. Call setAuthPresentationAnchor(_:) before signing in.")
      throw PortalAuthSignInError.unavailable
    }
    guard let callbackScheme = RedirectUrl.customScheme(of: self.redirectUrl) else {
      PortalLogger.shared.error("PortalAuth.signIn() - The redirectUrl is not a custom URL scheme; signInWith* requires one.")
      throw PortalAuthSignInError.unavailable
    }

    try self.beginSignIn()
    defer { self.endSignIn() }

    let authorizeUrl = try await self.getAuthorizeUrl(method)
    guard let url = URL(string: authorizeUrl.authorizeUrl) else {
      PortalLogger.shared.error("PortalAuth.signIn() - The \(method.rawValue) authorize URL could not be parsed.")
      throw PortalAuthError.malformedResponse(path: PortalAuthApi.oauthUrlsPath, missing: method.rawValue.lowercased())
    }

    let session = self.webSessionFactory()
    let callback = try await withTaskCancellationHandler {
      try await session.authenticate(
        url: url,
        callbackURLScheme: callbackScheme,
        anchor: anchor,
        prefersEphemeralWebBrowserSession: prefersEphemeral
      )
    } onCancel: {
      session.cancel()
    }

    // A cancelled caller must never exchange a grant it no longer wants: the session is a
    // single-use credential and persisting one nobody will use is worse than dropping it.
    try Task.checkCancellation()

    guard let result = try await self._handleRedirect(callback.absoluteString) else {
      PortalLogger.shared.error("PortalAuth.signIn() - The callback did not carry a sign-in result for this instance.")
      throw PortalAuthSignInError.callbackIncomplete
    }

    PortalLogger.shared.debug("PortalAuth.signIn() - \(method.rawValue) sign-in completed.")
    return result
  }

  /// Snapshots the anchor and the ephemeral flag together, so a sign-in uses the values that
  /// were current when it started even if the host flips them mid-flight. A synchronous helper
  /// because `NSLock` may not be taken directly inside an `async` function.
  private func readSignInPreconditions() -> (anchor: ASPresentationAnchor?, prefersEphemeral: Bool) {
    self.stateLock.lock()
    defer { self.stateLock.unlock() }
    return (self.presentationAnchor, self._prefersEphemeralWebBrowserSession)
  }

  private func beginSignIn() throws {
    self.stateLock.lock()
    defer { self.stateLock.unlock() }
    guard !self.isSignInInFlight else {
      throw PortalAuthSignInError.signInInProgress
    }
    self.isSignInInFlight = true
  }

  private func endSignIn() {
    self.stateLock.lock()
    defer { self.stateLock.unlock() }
    self.isSignInInFlight = false
  }

  // MARK: - Private: helpers

  private static func isBlank(_ value: String) -> Bool {
    value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  /// Normalises a storage error: a `PortalAuthError` (the storage layer's own
  /// `sessionStorageFailure`) passes through; anything else becomes `sessionStorageFailure`
  /// with a fixed message. Only the error's type is logged — never its description, which
  /// could echo the stored value.
  private static func storageFailure(_ error: Error, context: String, message: String) -> Error {
    if let authError = error as? PortalAuthError {
      return authError
    }
    PortalLogger.shared.error("\(context) - Session storage failed (\(type(of: error))).")
    return PortalAuthError.sessionStorageFailure(message: message)
  }
}
