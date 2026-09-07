//
//  PortalAuthTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// A signed-in end user's session, as produced by `PortalAuth` and consumed by
/// `Portal(credentials:)`.
///
/// A session is a `PortalCredentials` first: `getToken()` hands out the client session
/// token for as long as the session is valid and throws
/// `PortalCredentialError.sessionInvalidated` once it has been cleared, and `invalidate()`
/// drops both the in-memory token and the persisted copy. The one thing a session knows
/// that a bare credential does not is *who* it belongs to, which is why `endUserId` is the
/// only addition: hosts key their own per-user state (wallet cache, backup share storage,
/// analytics identity) on it, and it is safe to log where the token never is.
public protocol PortalSession: PortalCredentials {
  /// The Portal end-user id this session was issued for. Stable across token rotation and
  /// across sign-ins by the same user, and never secret, so it is the identifier to log
  /// and to key host-side state on.
  var endUserId: String { get }
}

// MARK: - Configuration

/// The authentication methods an auth environment can enable.
///
/// The raw values are the backend's wire strings, and they do double duty: they appear in
/// `allowedAuthMethods` and as the auth-method marker on an inbound redirect
/// (`authMethod=EMAIL_MAGIC_LINK`, `login_type=GOOGLE|APPLE`), so both are matched exactly
/// through `AuthMethod(rawValue:)`. A value this SDK version does not know is dropped by the
/// caller rather than surfaced, because the backend can enable a method before the SDK
/// learns its name and that must never be a crash.
public enum AuthMethod: String, Codable, CaseIterable {
  /// Email magic link: `sendMagicLink(_:)` followed by `handleRedirect(_:)`.
  case emailMagicLink = "EMAIL_MAGIC_LINK"
  /// Sign in with Google through the Portal-hosted OAuth flow.
  case google = "GOOGLE"
  /// Sign in with Apple through the Portal-hosted OAuth flow.
  case apple = "APPLE"
}

/// The backend-required magic-link fields, supplied once to the `PortalAuth` initializer.
///
/// Both are validated server-side against the auth environment (`fromEmail` must belong to
/// an enabled sending domain, `templateId` must exist), so the SDK only forwards them.
/// Keeping them on the instance rather than on every `sendMagicLink(_:)` call means an
/// OAuth-only app never has to think about them at all.
public struct MagicLinkConfig: Equatable {
  /// The sender address. Must belong to a domain enabled for the auth environment.
  public let fromEmail: String
  /// The email template to send. Must exist for the auth environment.
  public let templateId: String

  /// Memberwise initializer, public so hosts and their tests can build one.
  public init(fromEmail: String, templateId: String) {
    self.fromEmail = fromEmail
    self.templateId = templateId
  }
}

// MARK: - Results

/// The methods enabled for an auth environment, as reported by `PortalAuth.getMethods()`.
///
/// `autoCreateWallet` is a hint for the host: the backend never creates a wallet, so the SDK
/// does not branch on it. A TOTP requirement is deliberately *not* observable here — it only
/// shows up in a grant-exchange response, which is why the sign-in flow branches per call.
public struct AuthMethodsResult: Equatable {
  /// The enabled methods. Values this SDK version does not recognise are dropped, never
  /// surfaced as `nil`.
  public let allowedAuthMethods: [AuthMethod]
  /// Whether the environment expects the host to create a wallet after sign-in.
  public let autoCreateWallet: Bool

  /// Memberwise initializer, public so host test bundles (which cannot `@testable import`)
  /// can construct one.
  public init(allowedAuthMethods: [AuthMethod], autoCreateWallet: Bool) {
    self.allowedAuthMethods = allowedAuthMethods
    self.autoCreateWallet = autoCreateWallet
  }
}

/// The provider URL a host opens to start an OAuth login, from `loginWithGoogle()` /
/// `loginWithApple()`.
///
/// Wrapped in a struct rather than returned as a bare `String` for parity with the other
/// SDKs and so the type can grow without breaking call sites. The URL embeds a single-use
/// `state` shared by both providers in one backend response, so it must be opened promptly
/// and never cached.
public struct AuthorizeUrlResult: Equatable {
  /// The URL to open in a browser. Already trimmed of surrounding whitespace.
  public let authorizeUrl: String

  /// Memberwise initializer, public so host test bundles can construct one.
  public init(authorizeUrl: String) {
    self.authorizeUrl = authorizeUrl
  }
}

/// A completed sign-in.
///
/// `session` is already persisted by the time a host sees this value — a Keychain write
/// failure rejects the login instead of handing back a session that would not survive a
/// restart — so the host can pass it straight to `Portal(credentials:)`. Not `Equatable`:
/// `session` is a protocol existential, and two results are meaningfully the same only when
/// they carry the same session instance, which callers compare with `===`.
public struct AuthenticatedResult {
  /// The credential to hand to `Portal(credentials:)`. Already persisted.
  public let session: PortalSession
  /// The Portal Client this session belongs to, when the backend reported one.
  public let clientId: String?
  /// Whether the client is account-abstracted, when the backend reported it.
  public let isAccountAbstracted: Bool?

  /// Memberwise initializer, public so host test bundles can construct one around their own
  /// `PortalSession` test double.
  public init(session: PortalSession, clientId: String?, isAccountAbstracted: Bool?) {
    self.session = session
    self.clientId = clientId
    self.isAccountAbstracted = isAccountAbstracted
  }
}

/// A sign-in that needs a TOTP code before it can complete. Nothing has been persisted.
///
/// `userJwt` is short-lived and scoped to submitting a code; pass it back verbatim to
/// `PortalAuth.verifyTotp(_:userJwt:)` and never persist it. `totpLink` is present only on
/// first-time enrollment and embeds the TOTP secret, so it must never be logged (see
/// `totpSecret` / `qrCodeImage(scale:)` for the supported ways to show it).
public struct TotpRequiredResult: Equatable {
  /// The short-lived token that authorises the TOTP step. Never persisted; pass back verbatim.
  public let userJwt: String
  /// An `otpauth://` URI (RFC 6238) on first-time enrollment, or `nil` when the user is already
  /// enrolled and reads the code from whatever authenticator they set up before.
  public let totpLink: String?
  /// The end user this login belongs to — a label for the host's UI. It degrades to `""` when
  /// the grant omits it; the persisted session's `endUserId` is read from the JWT instead.
  public let endUserId: String

  /// Memberwise initializer, public so host test bundles can construct one.
  public init(userJwt: String, totpLink: String?, endUserId: String) {
    self.userJwt = userJwt
    self.totpLink = totpLink
    self.endUserId = endUserId
  }
}

/// The outcome of a completed grant exchange.
///
/// A two-case sum so a `switch` is exhaustive: either the login is done and a session exists,
/// or a TOTP code is still required and nothing has been persisted. Mirrors the Android,
/// React Native and Web SDKs.
public enum AuthResult {
  /// The login is complete; `session` is persisted and ready for `Portal(credentials:)`.
  case authenticated(AuthenticatedResult)
  /// A TOTP code is required; complete the login with `PortalAuth.verifyTotp(_:userJwt:)`.
  case totpRequired(TotpRequiredResult)
}

// MARK: - Errors

/// Every way the Client Auth flow itself can fail.
///
/// These describe the *authentication* flow — sending a magic link, completing a redirect,
/// reading a persisted session. Once a session exists, failures to turn it into a bearer token
/// are `PortalCredentialError`s instead. Transport failures are deliberately not remapped
/// here: a rejected grant exchange surfaces as `PortalRequestsError.unauthorized`, unchanged,
/// so the backend's own signal reaches the host (Android parity). The two exceptions —
/// `accountAbstractionUnavailable` and `rateLimited` — exist because the backend's status
/// codes there carry an actionable meaning the host would otherwise have to parse out of a
/// message string.
///
/// No message ever embeds a token, JWT, session token, URL, `totpLink` or email; the
/// associated values carry only server text (bounded), field names and fixed literals.
public enum PortalAuthError: LocalizedError, Equatable {
  /// A required argument was empty or blank. `name` is the parameter (`authEnvironmentId`,
  /// `redirectUrl`, `email`, `apiHost`).
  case invalidArgument(name: String)
  /// `sendMagicLink(_:)` was called on an instance constructed without `magicLink`. Raised
  /// locally before any network call.
  case magicLinkNotConfigured
  /// An OAuth login was started for a provider the auth environment has not enabled. Not
  /// retryable; check `getMethods()` and present the method as unavailable.
  case authMethodUnavailable(AuthMethod)
  /// A redirect targeting this instance carried `?error=…`. The value comes from an inbound
  /// deep link and is bounded to 100 characters because apps surface it straight to the user.
  case authenticationFailed(error: String)
  /// A Client Auth response did not carry what its endpoint documents: the `{ "data": … }`
  /// envelope itself (`missing == nil`) or a named field inside it.
  case malformedResponse(path: String, missing: String?)
  /// A grant exchange returned neither a `clientSessionToken` nor a `userJwt`.
  case invalidGrantResponse
  /// The `userJwt` handed to `verifyTotp(_:userJwt:)` cannot be read. Raised before any
  /// network call so a bad JWT never costs the user a live code.
  case invalidUserJwt(detail: String)
  /// Device storage could not be read, written or deleted *this time*. Distinct from "no
  /// usable session", which `restoreSession()` reports as `nil`. The message names the
  /// operation and, where available, the `OSStatus` — never the stored value.
  case sessionStorageFailure(message: String)
  /// A `400` from `POST /magic-links` or `GET /oauth/urls` whose body carried an `error`:
  /// `isAccountAbstracted: true` was requested against a custodian or environment without
  /// account abstraction. Server text, bounded to 200 characters.
  case accountAbstractionUnavailable(message: String)
  /// A `429` from `POST /magic-links`: the address hit the per-minute send limit. The backend
  /// sends no `Retry-After`; the SDK never retries on the host's behalf.
  case rateLimited
  /// A TOTP QR code could not be generated: the `totpLink` is missing, is not an
  /// `otpauth://` URL, or CoreImage produced no output.
  case totpQrUnavailable

  /// The user-facing text agreed with the Android SDK, prefixed with `[PortalAuth]` so it is
  /// attributable when it surfaces through a generic `localizedDescription`.
  public var errorDescription: String? {
    switch self {
    case let .invalidArgument(name):
      return "[PortalAuth] `\(name)` is required."
    case .magicLinkNotConfigured:
      return "[PortalAuth] sendMagicLink() requires `magicLink` (fromEmail, templateId) to be passed to the PortalAuth constructor."
    case let .authMethodUnavailable(method):
      return "[PortalAuth] \(method.rawValue) is not an enabled auth method for this auth environment."
    case let .authenticationFailed(error):
      return "[PortalAuth] Authentication failed: \(error)"
    case let .malformedResponse(path, missing):
      return "[PortalAuth] Malformed response from \(path): missing \"\(missing ?? "data")\"."
    case .invalidGrantResponse:
      return "[PortalAuth] The auth grant response carried neither a session token nor a userJwt."
    case let .invalidUserJwt(detail):
      return "[PortalAuth] \(detail)"
    case let .sessionStorageFailure(message):
      return "[PortalAuth] \(message)"
    case let .accountAbstractionUnavailable(message):
      return "[PortalAuth] Account abstraction is not available for this auth environment: \(message)"
    case .rateLimited:
      return "[PortalAuth] Too many magic links were sent to this address. Wait a minute before trying again."
    case .totpQrUnavailable:
      return "[PortalAuth] A TOTP QR code could not be generated: the totpLink is missing or is not an otpauth:// URL."
    }
  }
}

/// Failures specific to the browser-owning `signInWithGoogle()` / `signInWithApple()` flow.
///
/// The raw values are the Web SDK's popup error codes (minus `POPUP_BLOCKED`, which has no
/// `ASWebAuthenticationSession` analogue) so a host that already branches on those codes on
/// the web can reuse the same strings. Descriptions are fixed literals: they never include
/// the callback URL, the authorize URL or any token.
public enum PortalAuthSignInError: String, LocalizedError, Equatable {
  /// The user dismissed the sign-in sheet, or the task that started the sign-in was cancelled.
  case closed = "POPUP_CLOSED"
  /// The sheet could not be presented: no presentation anchor was set (or it deallocated), the
  /// `redirectUrl` is not a custom URL scheme, or the system refused to start the session.
  case unavailable = "POPUP_UNAVAILABLE"
  /// Another `signInWith*` call is still in flight. Both provider URLs share one single-use
  /// `state`, so a second concurrent attempt could only invalidate the first.
  case signInInProgress = "SIGN_IN_ALREADY_IN_PROGRESS"
  /// The browser returned a callback URL that carried no sign-in result for this instance
  /// (wrong target, no grant token, no auth-method marker, or oversized).
  case callbackIncomplete = "CALLBACK_INCOMPLETE"

  /// Fixed, secret-free text for each code.
  public var errorDescription: String? {
    switch self {
    case .closed:
      return "[PortalAuth] The sign-in window was closed before the sign-in completed."
    case .unavailable:
      return "[PortalAuth] The sign-in window could not be presented. Set a presentation anchor with setAuthPresentationAnchor(_:) and use a custom URL scheme as the redirectUrl."
    case .signInInProgress:
      return "[PortalAuth] A sign-in is already in progress."
    case .callbackIncomplete:
      return "[PortalAuth] The sign-in callback did not carry a sign-in result."
    }
  }
}
