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
/// the value but deliberately off `errorDescription`: a provider's own message may
/// echo a token, a keystore path or an account identifier, and the description is the
/// string that ends up in logs and crash reports.
///
/// `Equatable` is hand-written because `Error` is not `Equatable`, so synthesis fails on
/// `.providerFailure`. Two errors are equal when they are the same case; the cause is
/// ignored on purpose, since tests and hosts pin the reason, never the cause.
public enum PortalCredentialError: LocalizedError, Equatable {
  /// The provider returned an empty or whitespace-only token.
  case unavailable
  /// The provider threw. The cause is kept for diagnostics via pattern matching but is
  /// never rendered into the message.
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
