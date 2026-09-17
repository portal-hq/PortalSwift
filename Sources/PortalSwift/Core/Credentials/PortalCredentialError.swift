//
//  PortalCredentialError.swift
//  PortalSwift
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// The cross-SDK wire value of a credential failure.
///
/// These strings are frozen and shared with the Android, React Native and Web SDKs so a
/// host can branch on the same constants regardless of platform, and so the value it
/// forwards to its own backend or analytics means the same thing everywhere. Add a new
/// reason only in lock-step with the other SDKs.
public enum PortalCredentialErrorReason: String, Codable, Equatable {
  /// The provider returned no usable credential (an empty or whitespace-only token).
  case unavailable = "CREDENTIAL_UNAVAILABLE"
  /// The provider's `getToken()` threw something other than a `PortalCredentialError`.
  case providerFailure = "CREDENTIAL_PROVIDER_FAILURE"
  /// The credential was invalidated — by a backend 401 or by the host signing out — and
  /// the user must authenticate again before the SDK can do anything on their behalf.
  case sessionInvalidated = "SESSION_INVALIDATED"
}

/// Every way the SDK's credential boundary can fail.
///
/// `PortalCredentialSupport.resolveToken(_:)` normalises whatever a host-supplied `PortalCredentials`
/// throws into this one family, so call sites catch a single type and hosts can key
/// their recovery on `reason` / `requiresReauthentication` instead of on the shape of
/// an arbitrary provider error. The underlying cause of a `providerFailure` is kept on
/// the value for `catch let .providerFailure(underlying)` but deliberately kept out of
/// every rendering: a provider's own message may echo a token, a keystore path or an
/// account identifier. `errorDescription` never includes it, and the
/// `CustomStringConvertible` / `CustomDebugStringConvertible` / `CustomReflectable`
/// extension below replaces the synthesized enum rendering — which would otherwise print
/// the associated value in full through `"\(error)"`, `String(reflecting:)`, the `NSError`
/// bridge and the `Mirror` that `dump` and crash reporters walk — with the cause's type
/// name alone.
///
/// `Equatable` is hand-written because `Error` is not `Equatable`, so synthesis fails on
/// `.providerFailure`. Two errors are equal when they are the same case; the cause is
/// ignored on purpose, since tests and hosts pin the reason, never the cause.
public enum PortalCredentialError: LocalizedError, Equatable {
  /// The provider returned an empty or whitespace-only token.
  case unavailable
  /// The provider threw. The cause is kept for diagnostics via pattern matching but is
  /// never rendered: every textual and reflective rendering shows only its type name.
  case providerFailure(underlying: Error)
  /// The session behind the credential has ended; the user must authenticate again.
  case sessionInvalidated
  /// Neither an `apiKey` nor `credentials` was supplied when constructing `Portal`.
  /// This is a construction-time programming error, so it carries no wire `reason`.
  case invalidApiKey

  /// The cross-SDK reason, or `nil` for `.invalidApiKey`, which is not a runtime
  /// credential failure and has no wire equivalent on the other SDKs.
  public var reason: PortalCredentialErrorReason? {
    switch self {
    case .unavailable:
      return .unavailable
    case .providerFailure:
      return .providerFailure
    case .sessionInvalidated:
      return .sessionInvalidated
    case .invalidApiKey:
      return nil
    }
  }

  /// `true` only when the session has ended and a fresh sign-in is the only way
  /// forward. Hosts branch on this rather than on the case so the check keeps working
  /// if more session-ending reasons are ever added.
  public var requiresReauthentication: Bool {
    self.reason == .sessionInvalidated
  }

  /// The user-facing text agreed across the SDKs, prefixed with `[Portal]` so it is
  /// attributable when it surfaces through a generic `localizedDescription`. Never
  /// includes the underlying cause (see the type documentation).
  public var errorDescription: String? {
    switch self {
    case .unavailable:
      return "[Portal] No credential was available. Provide an apiKey or credentials when constructing Portal."
    case .providerFailure:
      return "[Portal] The credential provider failed to supply a credential."
    case .sessionInvalidated:
      return "[Portal] The session is no longer valid. Authenticate again to obtain a new one."
    case .invalidApiKey:
      return "[Portal] No API key provided. Provide `apiKey` or `credentials` when constructing Portal."
    }
  }

  public static func == (lhs: PortalCredentialError, rhs: PortalCredentialError) -> Bool {
    switch (lhs, rhs) {
    case (.unavailable, .unavailable),
         (.providerFailure, .providerFailure),
         (.sessionInvalidated, .sessionInvalidated),
         (.invalidApiKey, .invalidApiKey):
      return true
    default:
      return false
    }
  }
}

/// Rendering that never carries the provider's error.
///
/// `errorDescription` keeps the cause out of `localizedDescription`, but that is the only string
/// it controls. String interpolation, `String(describing:)`, `String(reflecting:)`, an
/// `XCTAssertEqual` failure message and the `NSError` bridge all fall back to the synthesized enum
/// rendering, which prints the associated value in full, and `dump` and reflection-based crash
/// reporters walk the synthesized `Mirror`, which exposes it as a child. A host `getToken()` error
/// that echoes the token it failed to refresh would leak through every one of them. Each path is
/// replaced here so the only thing a `providerFailure` reveals about its cause is the error's
/// dynamic type name — a compile-time identifier, not data, and enough to tell a keystore failure
/// from a network one in a log line. The cause itself stays on the value for
/// `catch let .providerFailure(underlying)`.
extension PortalCredentialError: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
  /// The case name for a payload-less error, or `providerFailure(underlying: <redacted TypeName>)`.
  public var description: String {
    switch self {
    case .unavailable:
      return "unavailable"
    case let .providerFailure(underlying):
      return "providerFailure(underlying: \(Self.redactedCause(of: underlying)))"
    case .sessionInvalidated:
      return "sessionInvalidated"
    case .invalidApiKey:
      return "invalidApiKey"
    }
  }

  public var debugDescription: String {
    self.description
  }

  /// The enum's own shape — one `underlying` child for `providerFailure`, none otherwise — with
  /// the redacted placeholder in place of the cause, so `dump` and reflection-based crash
  /// reporters see the same string as `description`.
  public var customMirror: Mirror {
    switch self {
    case let .providerFailure(underlying):
      return Mirror(self, children: ["underlying": Self.redactedCause(of: underlying)], displayStyle: .enum)
    case .unavailable, .sessionInvalidated, .invalidApiKey:
      return Mirror(self, children: [], displayStyle: .enum)
    }
  }

  /// `<redacted TypeName>`: the dynamic type of the cause and nothing else.
  private static func redactedCause(of underlying: Error) -> String {
    "<redacted \(type(of: underlying))>"
  }
}
