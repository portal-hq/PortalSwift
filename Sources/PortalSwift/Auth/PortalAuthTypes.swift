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
public enum AuthMethod: String, Codable, CaseIterable, Sendable {
  /// Email magic link: `sendMagicLink(_:)`, then `parseRedirect(_:)`, `getMagicLinkDetails(_:)`
  /// and, once the user confirms the email, `confirmMagicLink(_:)`.
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

/// The email address a magic link signs in to, read by `PortalAuth.getMagicLinkDetails(_:)`
/// without using up the link.
///
/// Show it on your own confirmation screen and call `PortalAuth.confirmMagicLink(_:)` only once
/// the user confirms it is theirs. `email` is the full address, never masked: masking, if any,
/// is up to that screen. It is personal data, so show it but do not log it.
public struct MagicLinkDetails: Hashable, Sendable {
  /// The full email address the magic link signs in to.
  public let email: String

  /// Memberwise initializer, public so host test bundles can construct one.
  public init(email: String) {
    self.email = email
  }
}

/// A completed sign-in.
///
/// `session` is already persisted by the time a host sees this value — a Keychain write
/// failure rejects the login instead of handing back a session that would not survive a
/// restart — so the host can pass it straight to `Portal(credentials:)`. Not `Equatable`:
/// `session` is a protocol existential, and two results are meaningfully the same only when
/// they carry the same session instance, which callers compare with `===`.
public struct AuthenticatedResult: Sendable {
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
public struct TotpRequiredResult: Equatable, Sendable {
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

/// Redacted rendering, mirroring `KeychainPortalSession`.
///
/// The synthesized description of a struct prints every stored property, so a `"\(step)"` in a
/// log line, an `XCTAssertEqual` failure message or a crash reporter's breadcrumb would carry
/// the `userJwt` and the `otpauth://` URI with the shared secret in full. Both are replaced
/// here; `endUserId` is not secret and stays.
extension TotpRequiredResult: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
  private static let redacted = "<redacted>"

  public var description: String {
    "TotpRequiredResult(endUserId: \(self.endUserId), userJwt: \(Self.redacted), totpLink: \(self.totpLink == nil ? "nil" : Self.redacted))"
  }

  public var debugDescription: String {
    self.description
  }

  public var customMirror: Mirror {
    Mirror(
      self,
      children: [
        "endUserId": self.endUserId,
        "userJwt": Self.redacted,
        "totpLink": self.totpLink == nil ? "nil" : Self.redacted
      ],
      displayStyle: .struct
    )
  }
}

// MARK: - Redirects

/// What an inbound redirect URL completes, as read by `PortalAuth.parseRedirect(_:)`.
///
/// Reading a redirect is local and spends nothing. Completing it is a separate call, chosen by
/// the case:
/// - `.magicLink`: show the user the email from `getMagicLinkDetails(_:)` and call
///   `confirmMagicLink(_:)` only once they confirm it. A magic link signs in whoever opens it,
///   to the account it was sent for, so the confirmation is what lets the user notice a link
///   someone else sent them.
/// - `.oauth`: complete a `loginWithGoogle()` / `loginWithApple()` redirect with
///   `completeOAuthLogin(_:)`.
/// - `.failed`: the sign-in ended without a grant, for example `oauth_failed`. Nothing was sent
///   to Portal; offer to start again.
///
/// Only `parseRedirect(_:)` can build a `.magicLink` or `.oauth` value — the payload
/// initializers are internal — so a `completeOAuthLogin(_:)` argument always comes from a parsed
/// redirect. Printing a value never shows its grant token — `description`, `debugDescription` and
/// `customMirror` replace it with `<redacted>` — because a redirect is exactly the kind of value
/// that ends up in a log line. `Equatable` and `Hashable` still use the real token.
public enum AuthRedirect: Hashable, Sendable {
  /// A magic-link redirect, not yet exchanged.
  case magicLink(MagicLink)
  /// A Google or Apple redirect, not yet exchanged.
  case oauth(OAuth)
  /// The redirect carried `?error=…` instead of a grant. Bounded to 100 characters, but it comes
  /// from an inbound URL that any app or website can open, so treat it as untrusted: map the
  /// codes you know, such as `oauth_failed`, to your own text rather than showing it raw.
  case failed(error: String)

  /// The grant of a magic-link redirect.
  public struct MagicLink: Hashable, Sendable {
    /// The single-use grant token. Pass it to `getMagicLinkDetails(_:)` and
    /// `confirmMagicLink(_:)`, and keep it only while the user decides; never log or persist it.
    /// Hold on to this `MagicLink` rather than the bare `String` where you can: the wrapper
    /// redacts the token when printed, the string does not.
    public let token: String

    init(token: String) {
      self.token = token
    }
  }

  /// The grant of a Google or Apple redirect.
  public struct OAuth: Hashable, Sendable {
    /// The provider that issued the grant: `.google` or `.apple`.
    public let provider: AuthMethod
    /// The single-use grant token. Internal: `completeOAuthLogin(_:)` is the only reader.
    let token: String

    init(provider: AuthMethod, token: String) {
      self.provider = provider
      self.token = token
    }
  }
}

/// Redacted rendering. The synthesized description of an enum walks its payloads, so without
/// these a `"\(redirect)"` would print the grant token in full.
extension AuthRedirect: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
  public var description: String {
    switch self {
    case let .magicLink(link):
      return "AuthRedirect.magicLink(\(link))"
    case let .oauth(oauth):
      return "AuthRedirect.oauth(\(oauth))"
    case let .failed(error):
      return "AuthRedirect.failed(error: \(error))"
    }
  }

  public var debugDescription: String {
    self.description
  }

  public var customMirror: Mirror {
    switch self {
    case let .magicLink(link):
      return Mirror(self, children: ["magicLink": link], displayStyle: .enum)
    case let .oauth(oauth):
      return Mirror(self, children: ["oauth": oauth], displayStyle: .enum)
    case let .failed(error):
      return Mirror(self, children: ["failed": error], displayStyle: .enum)
    }
  }
}

extension AuthRedirect.MagicLink: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
  private static let redacted = "<redacted>"

  public var description: String {
    "MagicLink(token: \(Self.redacted))"
  }

  public var debugDescription: String {
    self.description
  }

  public var customMirror: Mirror {
    Mirror(self, children: ["token": Self.redacted], displayStyle: .struct)
  }
}

extension AuthRedirect.OAuth: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
  private static let redacted = "<redacted>"

  public var description: String {
    "OAuth(provider: \(self.provider.rawValue), token: \(Self.redacted))"
  }

  public var debugDescription: String {
    self.description
  }

  public var customMirror: Mirror {
    Mirror(self, children: ["provider": self.provider.rawValue, "token": Self.redacted], displayStyle: .struct)
  }
}

/// The outcome of a completed grant exchange.
///
/// A two-case sum so a `switch` is exhaustive: either the login is done and a session exists,
/// or a TOTP code is still required and nothing has been persisted. Mirrors the Android,
/// React Native and Web SDKs.
public enum AuthResult: Sendable {
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
/// here, so the backend's own signal reaches the host (Android parity): a refused grant outside
/// the two-step magic link — a Google or Apple grant, a magic link completed through the
/// deprecated `handleRedirect(_:)`, or a TOTP code — surfaces as
/// `PortalRequestsError.unauthorized`, unchanged. Three exceptions:
/// `accountAbstractionUnavailable` and `rateLimited` exist because the backend's status codes
/// there carry an actionable meaning the host would otherwise have to parse out of a message
/// string, and `grantRejected` exists because the two-step magic link's `401` has one meaning —
/// this link can no longer be used, request a new one — that a confirmation screen must be able
/// to tell apart from a rejected session anywhere else in the SDK.
///
/// No message ever embeds a token, JWT, session token, URL, `totpLink` or email; the
/// associated values carry only server text (bounded), field names and fixed literals.
public enum PortalAuthError: LocalizedError, Equatable {
  /// A required argument was empty or blank. `name` is the parameter (`authEnvironmentId`,
  /// `redirectUrl`, `email`, `apiHost`, `token`).
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
  /// Portal refused a magic link: it has expired, was already used, or is otherwise unusable.
  /// Thrown by `getMagicLinkDetails(_:)` and `confirmMagicLink(_:)` for the backend's `401`. Not
  /// retryable: ask the user to request a new link. `completeOAuthLogin(_:)`, `signInWith*` and
  /// the deprecated `handleRedirect(_:)` keep reporting a refused grant as
  /// `PortalRequestsError.unauthorized`.
  case grantRejected
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
    case .grantRejected:
      return "[PortalAuth] The authentication grant was rejected. It may already have been used, expired, or been issued for a different auth environment. Start a new sign-in."
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
  /// The browser returned a callback URL that carried no Google or Apple sign-in result for this
  /// instance (wrong target, no grant token, no auth-method marker, oversized, or another kind of
  /// sign-in such as a magic link, which completes only through the app's confirmation step).
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
