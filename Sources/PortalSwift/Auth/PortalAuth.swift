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
/// **Google and Apple sign-ins are bound to the device** with a PKCE code verifier (RFC 7636).
/// Every `loginWith*` / `signInWith*` call creates a one-time verifier, sends only its hash with
/// `GET /oauth/urls`, keeps it in the Keychain (service
/// `PortalSwift.auth.oauthVerifier.<authEnvironmentId>`) and sends it with the grant exchange, so
/// only the sign-in in progress on this device can complete. The binding has two halves. This SDK
/// refuses a Google or Apple redirect that arrives with no sign-in in progress, before any
/// network call, with `PortalAuthError.oauthFlowNotStarted`. A grant from a different sign-in is
/// sent with this device's verifier and refused by Portal's servers, which check it against the
/// challenge; that half relies on the backend enforcing the code verifier, as Portal's does. Each
/// auth environment has one sign-in in progress (the newest wins), kept for 15 minutes; instances
/// sharing an `authEnvironmentId` share it, while start ordering and cancellation are per instance.
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
/// `grantMutex`; starting a Google or Apple sign-in is serialised by `flowMutex`; the
/// presentation anchor, the ephemeral flag, the sign-in guard and the OAuth generation are guarded
/// by `stateLock`; the verifier storage locks itself. Everything else is immutable after `init`.
public final class PortalAuth: @unchecked Sendable {
  /// Upper bound on an inbound redirect URL, in UTF-16 code units, applied before parsing.
  ///
  /// Deep links are attacker-reachable — any installed app can send one on a custom scheme —
  /// so the string is bounded at the trust boundary rather than inside each parser. A real
  /// redirect is roughly an order of magnitude below this; the grant token dominates it.
  static let maxRedirectUrlLength = 8192

  /// Upper bound, in `Character`s, on an `error` value copied into an error message.
  static let maxErrorLength = 100

  /// How long a Google or Apple sign-in in progress stays completable, in milliseconds.
  ///
  /// The backend's `state` lives 600 s from `/oauth/urls` to the provider callback, and the grant
  /// 900 s from the callback to `/oauth/tokens`. 15 minutes covers a callback that lands just
  /// before the state expires without keeping the verifier for the full theoretical 25. The
  /// Android and React Native SDKs use the same value.
  static let verifierLifetimeMillis: Int64 = 15 * 60 * 1000

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
  private let verifierStorage: OAuthVerifierStorage
  private let magicLink: MagicLinkConfig?
  private let isAccountAbstracted: Bool?
  private let clock: () -> Date
  private let webSessionFactory: () -> AuthWebSessionProviding

  /// Serialises starting a Google or Apple sign-in on this instance — generate the verifier,
  /// fetch the authorize URL, store the verifier — so the stored verifier always belongs to the
  /// URL this instance returned last.
  ///
  /// Per instance, like the replay memo: a start on another `PortalAuth` with the same auth
  /// environment is not serialised against this one. That instance shares the one verifier slot,
  /// so whichever start stores last wins, and only one of two overlapping sign-ins can complete
  /// either way.
  ///
  /// Separate from `grantMutex`, so starting a sign-in never waits on an exchange in flight.
  /// Internal so tests can observe contention.
  let flowMutex = AsyncMutex()

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

  /// Advanced by `clearPersistedSession()` *before* it waits for `grantMutex`, so a Google or Apple
  /// exchange already holding that lock can see it was cancelled. `_handleRedirect` reads it before
  /// waiting for the lock and fails with `oauthFlowNotStarted` once it has moved, rather than
  /// handing back a session the clear is about to delete. Per instance, like the replay memo.
  /// Guarded by `stateLock`.
  private var oauthGeneration = 0

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
      // Keyed the same way: instances sharing one share the sign-in in progress.
      verifierStorage: KeychainOAuthVerifierStorage(authEnvironmentId: authEnvironmentId),
      magicLink: magicLink,
      isAccountAbstracted: isAccountAbstracted
    )
  }

  /// Designated initializer and test seam: injects the transport, both storages, the clock the
  /// verifier lifetime is measured with and the web session factory. Performs no I/O.
  init(
    redirectUrl: String,
    api: PortalAuthApi,
    storage: AuthSessionStorage,
    verifierStorage: OAuthVerifierStorage,
    magicLink: MagicLinkConfig? = nil,
    isAccountAbstracted: Bool? = nil,
    clock: @escaping () -> Date = { Date() },
    webSessionFactory: @escaping () -> AuthWebSessionProviding = { ASWebAuthenticationSessionAdapter() }
  ) {
    self.redirectUrl = redirectUrl
    self.api = api
    self.storage = storage
    self.verifierStorage = verifierStorage
    self.magicLink = magicLink
    self.isAccountAbstracted = isAccountAbstracted
    self.clock = clock
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
  /// and unlike a Google or Apple grant a magic-link grant is not bound to this device: an app
  /// that registered your scheme can deliver a grant of its own. The address is trimmed and
  /// lowercased first (the backend requires lowercase and does not trim). Every call delivers a
  /// real email and sends are rate limited, so **never retry automatically** — a resend is an
  /// explicit user action.
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
  /// **Bound to this device.** Each call creates a one-time code verifier (PKCE, RFC 7636),
  /// stores it in the Keychain before returning the URL, and sends Portal only its hash. The
  /// grant this URL ends in can then only be exchanged by this device's `handleRedirect(_:)`,
  /// which sends the verifier with it — so a redirect another app intercepts is useless to it,
  /// and a Google or Apple grant another app crafts cannot sign your user in (a magic-link grant
  /// is not bound this way; see `sendMagicLink(_:)`). With no sign-in in progress, this SDK
  /// refuses such a grant itself; while one is in progress, it is Portal's servers that refuse
  /// it, by checking the verifier against the challenge. The sign-in survives your app being
  /// terminated while the browser is open, and stays completable for 15 minutes.
  ///
  /// **One sign-in in progress.** Each call replaces the verifier stored by any earlier
  /// `loginWith*` / `signInWith*` call for this auth environment, so only the URL whose verifier
  /// was stored last can complete: on one instance, the URL returned last; across instances
  /// sharing the auth environment, whichever start stored its verifier last, which is not
  /// necessarily the order callers received their URLs. Request the URL when the user taps, not
  /// ahead of time.
  /// `clearPersistedSession()` cancels the sign-in in progress, so call it before this method,
  /// not after.
  ///
  /// - Throws: `PortalAuthError.authMethodUnavailable(.google)` when Google is not enabled for
  ///   this environment. Not retryable — check `getMethods()`.
  ///   `PortalAuthError.sessionStorageFailure` when the verifier cannot be created or stored;
  ///   no URL is returned and no sign-in is started, and a retry may succeed.
  public func loginWithGoogle() async throws -> AuthorizeUrlResult {
    try await self.startOAuthFlow(.google).authorizeUrl
  }

  /// The Apple authorize URL to open in a browser. See `loginWithGoogle()` for how to open it,
  /// why the result must not be cached, and how the sign-in is bound to this device.
  ///
  /// Sign in with Apple identifies end users differently: Portal identifies an end user by
  /// email, and a user who chooses *Hide My Email* becomes a distinct end user (with a distinct
  /// client and wallet) from the same person signing in with Google or a magic link. Apple also
  /// supplies the email only on the user's first consent for a given Service ID, so changing
  /// the Service ID is a breaking change for existing users.
  ///
  /// - Throws: `PortalAuthError.authMethodUnavailable(.apple)` when Apple is not enabled;
  ///   `PortalAuthError.sessionStorageFailure` when the verifier cannot be created or stored.
  public func loginWithApple() async throws -> AuthorizeUrlResult {
    try await self.startOAuthFlow(.apple).authorizeUrl
  }

  // MARK: - Redirect

  /// The single completion path for every flow.
  ///
  /// Returns `nil` when the URL does not target this instance's `redirectUrl` or carries no
  /// Client Auth grant, so it is safe to call on every instance and safe for the app's router
  /// to try other handlers afterwards. Throws when the URL matches but carries `?error=…`.
  ///
  /// A Google or Apple grant is exchanged only with the code verifier of the sign-in this device
  /// started (see `loginWithGoogle()`). With no sign-in in progress — never started here,
  /// already completed outside this instance's replay memory, older than 15 minutes, or cancelled
  /// by `clearPersistedSession()` — the redirect is refused with
  /// `PortalAuthError.oauthFlowNotStarted` before any network call. A redirect from a sign-in
  /// other than the one in progress is sent with this device's verifier and refused by Portal as
  /// `PortalRequestsError.unauthorized`. A magic-link grant is not bound to the device: it is
  /// exchanged from any redirect that reaches your URL.
  ///
  /// Safe to call twice with the same grant: the first exchange's result is remembered and
  /// replayed, so a redirect the system re-delivers resolves to the same `AuthResult` — and
  /// the same `PortalSession` instance — rather than failing the backend's single-use
  /// rejection. A redirect that failed on a dropped connection or a rejected grant is not
  /// remembered and stays retryable. A successful exchange whose Keychain write failed *is*
  /// remembered — the backend has already spent the grant — and the replay retries the write
  /// instead of re-sending the token. A remembered session the backend has since rejected is
  /// not replayed when it was rejected through the session this redirect returned: the redirect
  /// fails with `PortalRequestsError.unauthorized`, like a spent grant. A session rebuilt by
  /// `restoreSession()` is a separate instance, so call `clearPersistedSession()` from your
  /// `onSessionInvalidated` listener to drop the memory as well. The memory belongs to this instance and this process: `clearPersistedSession()`
  /// drops it, and after a process death the recovery is `restoreSession()` — a Google or Apple
  /// redirect re-delivered to a new process then fails, usually with `oauthFlowNotStarted`
  /// because the completed sign-in no longer exists.
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
  ///   error; `.oauthFlowNotStarted` for a Google or Apple redirect with no sign-in in progress
  ///   on this device — never started here, already completed outside this instance's replay
  ///   memory, expired or cancelled (nothing sent; start a new sign-in) — or when
  ///   `clearPersistedSession()` is called while it is being exchanged; `.invalidGrantResponse`
  ///   when the exchange returns neither a session token nor a `userJwt`; `.malformedResponse`;
  ///   `.sessionStorageFailure` when the sign-in in progress could not be read (nothing sent) or
  ///   the session could not be written — pass the same URL again in both cases; a rejected
  ///   grant surfaces as `PortalRequestsError.unauthorized`, unmapped. A Google or Apple sign-in
  ///   stays in progress when its exchange fails with an HTTP error or a dropped connection, so
  ///   the same URL can be passed again (Portal refuses it if the first attempt spent the grant).
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
  /// that want a clean slate call `clearPersistedSession()` on first launch after install, before
  /// starting any sign-in.
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
  /// **Also cancels a Google or Apple sign-in in progress**: its redirect then fails with
  /// `PortalAuthError.oauthFlowNotStarted` — including one `handleRedirect(_:)` is already
  /// exchanging, which throws that instead of returning a session this call is about to delete.
  /// Await this before `loginWithGoogle()` / `loginWithApple()` / `signInWith*`, not after, and do
  /// not call it in your redirect handler before `handleRedirect(_:)`. A sign-in whose verifier is
  /// stored after this call has deleted the previous one — for example one whose authorize URL was
  /// still being fetched — counts as started after it. A sign-in already at its two-factor step
  /// is not cancelled: its grant is spent, and `verifyTotp(_:userJwt:)` can still complete it. In
  /// an `onSessionInvalidated` listener, call this before routing to sign-in. A
  /// magic-link exchange in flight is not cancelled: this call waits for it, then deletes what it
  /// persisted. Cancelling an exchange already in flight reaches this instance only; on another
  /// instance with the same auth environment it completes, and its session survives until any
  /// instance for that auth environment is cleared again.
  ///
  /// No server-side revoke endpoint exists, so this does not affect a `Portal` already holding
  /// the credential; it prevents a future `restoreSession()` from returning it. Waits for an
  /// in-flight `handleRedirect` / `verifyTotp` to finish persisting before deleting, so a login
  /// cannot write a session back into storage after the delete.
  ///
  /// - Throws: `PortalAuthError.sessionStorageFailure` when either delete fails. Both are always
  ///   attempted; when both fail, the session's failure is the one thrown.
  public func clearPersistedSession() async throws {
    // Before the lock: a Google or Apple exchange in flight holds it until it returns, and must be
    // able to see it was cancelled. Advanced even if the deletes below then fail.
    self.advanceOAuthGeneration()

    try await self.grantMutex.withLock {
      // `flowMutex` is deliberately not taken: it is held across `GET /oauth/urls`, so waiting on
      // it would stall sign-out — and every redirect and TOTP call queued behind this lock — on a
      // slow request. The verifier storage's own lock already orders this delete against a
      // concurrent start's write: a start that writes after it counts as started after the clear.
      var verifierFailure: Error?
      do {
        try self.verifierStorage.delete()
      } catch {
        verifierFailure = error
      }

      do {
        try self.storage.delete()
      } catch {
        if let verifierFailure = verifierFailure {
          PortalLogger.shared.error("PortalAuth.clearPersistedSession() - The sign-in in progress could not be deleted either (\(type(of: verifierFailure))).")
        }
        throw Self.storageFailure(error, context: "PortalAuth.clearPersistedSession()", message: "The persisted session could not be deleted.")
      }
      self.consumedGrant = nil
      self.pendingTotpPersist = nil

      if let verifierFailure = verifierFailure {
        throw Self.storageFailure(
          verifierFailure,
          context: "PortalAuth.clearPersistedSession()",
          message: "The sign-in in progress could not be deleted."
        )
      }
      PortalLogger.shared.debug("PortalAuth.clearPersistedSession() - Persisted session and any sign-in in progress cleared.")
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
  /// Bound to this device like `loginWithGoogle()`, and sharing its one-sign-in-in-progress
  /// slot: a `loginWith*` call made while the sheet is open replaces this sign-in, which then
  /// fails with `PortalAuthError.oauthFlowNotStarted` without sending its grant. Whatever the
  /// outcome, the sign-in's verifier is removed when this call returns, since the host can never
  /// resume a sheet.
  ///
  /// - Throws: `PortalAuthSignInError` (`.unavailable`, `.signInInProgress`, `.closed`,
  ///   `.callbackIncomplete`); `PortalAuthError.sessionStorageFailure` when the verifier cannot
  ///   be created or stored (no sheet is shown); any `PortalAuthError` `handleRedirect(_:)` can
  ///   throw, including `.oauthFlowNotStarted`; or the transport error unchanged.
  public func signInWithGoogle() async throws -> AuthResult {
    try await self.signIn(.google)
  }

  /// Completes an Apple sign-in end to end. See `signInWithGoogle()` for the mechanics and
  /// `loginWithApple()` for how Apple identifies end users.
  public func signInWithApple() async throws -> AuthResult {
    try await self.signIn(.apple)
  }

  // MARK: - Private: redirect (the only caller of `grantMutex` on this path)

  /// The one body that takes `grantMutex` for a redirect. Both public overloads forward here,
  /// and so does `signIn` with the verifier of the sheet's own sign-in (`sheetVerifier`).
  ///
  /// Order is contractual: empty / oversized → `nil`; not our target → `nil`; parse; `error`
  /// → throw (even when a token is present, and before any request); empty token → `nil`;
  /// then, under the lock, memo hit → replay (before any verifier read), else exchange.
  private func _handleRedirect(_ url: String, sheetVerifier: String? = nil) async throws -> AuthResult? {
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

    // Read before waiting for the lock, so a clear that arrives while this redirect waits is seen
    // too. `nil` for a magic link: `clearPersistedSession()` does not cancel one, it waits for it.
    let oauthGeneration = Self.isOAuthRedirect(params) ? self.currentOAuthGeneration() : nil

    return try await self._shieldedFromCancellation { try await self.grantMutex.withLock {
      try self.throwIfClearedSince(oauthGeneration)
      if let memo = self.consumedGrant, memo.token == token {
        let replayed: AuthResult
        do {
          replayed = try self._replay(memo)
        } catch {
          if self.isClearedSince(oauthGeneration) {
            throw self._abandonCancelledLogin(wroteSessionToken: nil)
          }
          throw error
        }
        // A clear that landed while the memo was served gets nothing back, and the write this
        // replay just made (if it had one pending) is removed.
        if self.isClearedSince(oauthGeneration) {
          throw self._abandonCancelledLogin(wroteSessionToken: memo.pendingPersist?.clientSessionToken)
        }
        return replayed
      }
      return try await self._exchangeGrant(
        token: token,
        params: params,
        sheetVerifier: sheetVerifier,
        oauthGeneration: oauthGeneration
      )
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
  /// a spent token.
  ///
  /// A Google or Apple login cancelled by `clearPersistedSession()` (`oauthGeneration` moved) is
  /// refused before anything is recorded; one cancelled while its session was being written drops
  /// the memo and undoes the write (best effort) before throwing (`_abandonCancelledLogin`), so the
  /// clear's own delete is not the only thing removing it. A replay gets the same treatment in
  /// `_handleRedirect`. Called only with `grantMutex` held.
  private func _exchangeGrant(
    token: String,
    params: [String: String],
    sheetVerifier: String?,
    oauthGeneration: Int?
  ) async throws -> AuthResult? {
    guard let grant = try await self.exchangeGrantToken(
      token,
      params: params,
      sheetVerifier: sheetVerifier,
      oauthGeneration: oauthGeneration
    ) else {
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
      try self.throwIfClearedSince(oauthGeneration)
      // Memoised before the write: the grant is already spent, so a persist failure must leave
      // a re-delivered redirect able to finish this login (see `ConsumedGrant.pendingPersist`).
      self.consumedGrant = ConsumedGrant(token: token, result: result, pendingPersist: persisted)
      do {
        try self._persist(persisted)
      } catch {
        // A cancelled login whose write failed keeps nothing to retry.
        if self.isClearedSince(oauthGeneration) {
          throw self._abandonCancelledLogin(wroteSessionToken: nil)
        }
        throw error
      }
      self._markPersisted()
      if self.isClearedSince(oauthGeneration) {
        throw self._abandonCancelledLogin(wroteSessionToken: clientSessionToken)
      }
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
    try self.throwIfClearedSince(oauthGeneration)
    self.consumedGrant = ConsumedGrant(token: token, result: result, pendingPersist: nil)
    PortalLogger.shared.debug("PortalAuth.handleRedirect() - The grant requires a TOTP step; nothing persisted.")
    return result
  }

  /// Routes a grant to the endpoint that can exchange it, or returns `nil` when the URL carries
  /// no recognisable auth-method marker.
  ///
  /// Magic-link redirects carry `authMethod`; OAuth callbacks carry `login_type`. Magic link is
  /// checked first (Android order); the two only disagree on a URL carrying both markers, which
  /// no healthy backend sends. Matching is exact on the wire value. Called only with
  /// `grantMutex` held.
  private func exchangeGrantToken(
    _ token: String,
    params: [String: String],
    sheetVerifier: String?,
    oauthGeneration: Int?
  ) async throws -> AuthGrantValidationResponse? {
    let authMethod = params["authMethod"].flatMap { AuthMethod(rawValue: $0) }

    if authMethod == .emailMagicLink {
      return try await self.api.validateMagicLink(token: token)
    }
    // `/oauth/tokens` does not care which provider issued the grant, so both share it.
    if Self.isOAuthRedirect(params) {
      return try await self._exchangeOAuthGrant(token: token, sheetVerifier: sheetVerifier, oauthGeneration: oauthGeneration)
    }
    return nil
  }

  /// Whether `exchangeGrantToken` routes these redirect parameters to the Google or Apple
  /// exchange: a `login_type` of `GOOGLE` or `APPLE`, and no magic-link marker (which wins).
  private static func isOAuthRedirect(_ params: [String: String]) -> Bool {
    if params["authMethod"].flatMap({ AuthMethod(rawValue: $0) }) == .emailMagicLink {
      return false
    }
    let loginType = params["login_type"].flatMap { AuthMethod(rawValue: $0) }
    return loginType == .google || loginType == .apple
  }

  /// Exchanges a Google or Apple grant with the code verifier of the sign-in this device started,
  /// or refuses it without a request.
  ///
  /// No verifier means this device never asked for this grant — exactly what a crafted redirect
  /// looks like — so nothing is sent. An expired one is refused the same way; see
  /// `verifierLifetimeMillis` for why 15 minutes covers the realistic window. A sheet sign-in
  /// (`sheetVerifier` set) whose verifier is no longer the stored one
  /// was replaced by a newer sign-in; sending its grant with the newer verifier could only burn
  /// it, so it is refused too.
  ///
  /// Only a response Portal actually accepted spends the verifier. A rejection (401 or another
  /// HTTP error) can be a crafted redirect sent with this device's verifier, and deleting on it
  /// would fail the user's own redirect arriving next; a dropped connection may have left the
  /// grant unspent, so the same redirect can be retried. A 2xx whose body is unusable
  /// (`malformedResponse`, the only error raised after a 2xx) did spend the grant, so the verifier
  /// goes with it.
  ///
  /// A login cancelled by `clearPersistedSession()` while the request was in flight is refused
  /// once it returns, and its spent verifier forgotten. Called only with `grantMutex` held.
  private func _exchangeOAuthGrant(
    token: String,
    sheetVerifier: String?,
    oauthGeneration: Int?
  ) async throws -> AuthGrantValidationResponse {
    let stored: PendingOAuthVerifier?
    do {
      stored = try self.verifierStorage.get()
    } catch {
      throw Self.storageFailure(error, context: "PortalAuth.handleRedirect()", message: "The sign-in in progress could not be read.")
    }

    guard let pending = stored, !self.isExpired(pending) else {
      if let expired = stored {
        PortalLogger.shared.debug("PortalAuth.handleRedirect() - OAuth redirect refused: the sign-in in progress has expired.")
        self.forgetVerifier(expired.verifier)
      } else {
        PortalLogger.shared.debug("PortalAuth.handleRedirect() - OAuth redirect refused: no sign-in in progress on this device.")
      }
      throw PortalAuthError.oauthFlowNotStarted
    }

    if let sheetVerifier = sheetVerifier, sheetVerifier != pending.verifier {
      PortalLogger.shared.debug("PortalAuth.signIn() - The sign-in was replaced by a newer one before its callback arrived; refusing it.")
      throw PortalAuthError.oauthFlowNotStarted
    }

    let grant: AuthGrantValidationResponse
    do {
      grant = try await self.api.validateOAuthToken(token: token, codeVerifier: pending.verifier)
    } catch {
      if case .malformedResponse? = error as? PortalAuthError {
        self.forgetVerifier(pending.verifier)
      }
      throw error
    }

    if self.isClearedSince(oauthGeneration) {
      // Portal accepted the grant, so the verifier is spent either way: forget it (compare-and-
      // delete, so a sign-in started after the clear keeps its own) rather than leave it to a
      // clear whose delete could fail and let a re-delivered redirect re-send a spent grant.
      self.forgetVerifier(pending.verifier)
      throw self.cancelledByClear()
    }
    self.forgetVerifier(pending.verifier)
    return grant
  }

  /// Compare-and-deletes `verifier`, so a sign-in started meanwhile keeps its own.
  ///
  /// Best effort: a failure is logged (type only) rather than thrown. The exchange it follows has
  /// already been decided, and failing a completed sign-in over a secret that expires on its own
  /// would cost the user a session.
  private func forgetVerifier(_ verifier: String) {
    do {
      try self.verifierStorage.deleteIfCurrent(verifier)
    } catch {
      PortalLogger.shared.warn("PortalAuth - The sign-in in progress could not be deleted; it expires on its own (\(type(of: error))).")
    }
  }

  /// Removes the session a cancelled login has just written, best effort. Compare-and-delete, so
  /// a newer login's session is never touched; a failure is logged (type only), and the pending
  /// `clearPersistedSession()` deletes the session anyway when it can.
  private func _undoPersist(of clientSessionToken: String) {
    do {
      try self.storage.deleteIfCurrent(clientSessionToken)
    } catch {
      PortalLogger.shared.warn("PortalAuth.handleRedirect() - The cancelled login's session could not be removed (\(type(of: error))).")
    }
  }

  /// `true` once `pending` is 15 minutes old, or dated in the future (the device clock moved
  /// back, which says nothing trustworthy about its age). The subtraction cannot trap: an
  /// overflowing age counts as expired.
  private func isExpired(_ pending: PendingOAuthVerifier) -> Bool {
    let (age, overflow) = self.nowMillis().subtractingReportingOverflow(pending.createdAt)
    return overflow || age < 0 || age >= Self.verifierLifetimeMillis
  }

  /// The clock's reading in milliseconds since 1970, the unit `PendingOAuthVerifier.createdAt`
  /// is stored in.
  private func nowMillis() -> Int64 {
    Int64((self.clock().timeIntervalSince1970 * 1000).rounded())
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

  /// A started Google or Apple sign-in: the URL to open, and the verifier stored for it. Its
  /// description is redacted, like `PendingOAuthVerifier`'s.
  private struct StartedOAuthFlow: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    let authorizeUrl: AuthorizeUrlResult
    /// Never logged; kept only so `signIn` can tell its own sign-in from a newer one.
    let codeVerifier: String

    var description: String {
      "StartedOAuthFlow(codeVerifier: <redacted>)"
    }

    var debugDescription: String {
      self.description
    }

    var customMirror: Mirror {
      Mirror(self, children: ["codeVerifier": "<redacted>"], displayStyle: .struct)
    }
  }

  /// Starts a Google or Apple sign-in: creates a code verifier, fetches the authorize URLs with
  /// its challenge, picks the provider's URL and stores the verifier — in that order, under
  /// `flowMutex`, so the stored verifier always belongs to the URL this instance returned last.
  ///
  /// Shared by `loginWith*` and `signInWith*`: the response carries one key per enabled provider,
  /// and picking a different key is the whole difference between them. Absent or blank means the
  /// provider is switched off for this environment, which a retry cannot change. The verifier is
  /// stored only once there is a URL to return, and before returning it: nothing is stored when
  /// the request fails or the provider is off, and a URL whose verifier could not be stored is
  /// never returned, since its redirect could only be refused.
  private func startOAuthFlow(_ method: AuthMethod) async throws -> StartedOAuthFlow {
    try await self.flowMutex.withLock {
      // `AsyncMutex` is not cancellation-aware, so a caller cancelled while waiting still gets
      // here; it must not replace the verifier of a sign-in someone else is completing.
      try Task.checkCancellation()

      let codeVerifier = try PkceCodeVerifier.generate()
      let urls = try await self.api.getOAuthUrls(
        redirectUrl: self.redirectUrl,
        isAccountAbstracted: self.isAccountAbstracted,
        codeChallenge: PkceCodeVerifier.challenge(for: codeVerifier)
      )

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
        PortalLogger.shared.error("PortalAuth.startOAuthFlow() - \(method.rawValue) is not an enabled auth method for this auth environment.")
        throw PortalAuthError.authMethodUnavailable(method)
      }

      // Checked again now that the URL is in hand: a caller cancelled while the request was in
      // flight wants no sign-in, and storing its verifier would still replace the one in progress.
      try Task.checkCancellation()

      do {
        try self.verifierStorage.set(PendingOAuthVerifier(verifier: codeVerifier, createdAt: self.nowMillis()))
      } catch {
        throw Self.storageFailure(error, context: "PortalAuth.startOAuthFlow()", message: "The sign-in in progress could not be stored.")
      }

      return StartedOAuthFlow(authorizeUrl: AuthorizeUrlResult(authorizeUrl: authorizeUrl), codeVerifier: codeVerifier)
    }
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

    let flow = try await self.startOAuthFlow(method)
    // The host never sees the callback of a sheet, so it can never resume this sign-in: whatever
    // happens next, its verifier goes when this call returns. Compare-and-delete, so a sign-in
    // that replaced this one keeps its own. Registered before anything below can throw.
    defer { self.forgetVerifier(flow.codeVerifier) }

    guard let url = URL(string: flow.authorizeUrl.authorizeUrl) else {
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

    guard let result = try await self._handleRedirect(callback.absoluteString, sheetVerifier: flow.codeVerifier) else {
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

  // MARK: - OAuth generation

  /// The current OAuth generation. Internal so tests can observe it.
  func currentOAuthGeneration() -> Int {
    self.stateLock.lock()
    defer { self.stateLock.unlock() }
    return self.oauthGeneration
  }

  /// Cancels every Google or Apple login this instance is completing. Called by
  /// `clearPersistedSession()`; internal so tests can land a clear at an exact point.
  func advanceOAuthGeneration() {
    self.stateLock.lock()
    defer { self.stateLock.unlock() }
    self.oauthGeneration += 1
  }

  /// `true` when `generation` is a Google or Apple login's (non-`nil`) and a clear has moved past it.
  private func isClearedSince(_ generation: Int?) -> Bool {
    guard let generation = generation else {
      return false
    }
    return self.currentOAuthGeneration() != generation
  }

  /// Throws `oauthFlowNotStarted` once `clearPersistedSession()` has cancelled this login.
  private func throwIfClearedSince(_ generation: Int?) throws {
    if self.isClearedSince(generation) {
      throw self.cancelledByClear()
    }
  }

  /// The error a login cancelled by `clearPersistedSession()` ends with, logged once.
  private func cancelledByClear() -> PortalAuthError {
    PortalLogger.shared.debug("PortalAuth.handleRedirect() - The sign-in in progress was cancelled by clearPersistedSession().")
    return PortalAuthError.oauthFlowNotStarted
  }

  /// Ends a Google or Apple login that `clearPersistedSession()` cancelled after it had recorded or
  /// written something: drops the replay memo and, when `token` names the session this call just
  /// wrote, removes that write (best effort), so the clear's own delete is not the only thing
  /// removing it. If the Keychain refuses both, the session remains and the clear throws. Returns
  /// the error to throw. Called only with `grantMutex` held.
  private func _abandonCancelledLogin(wroteSessionToken token: String?) -> PortalAuthError {
    self.consumedGrant = nil
    if let token = token {
      self._undoPersist(of: token)
    }
    return self.cancelledByClear()
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
