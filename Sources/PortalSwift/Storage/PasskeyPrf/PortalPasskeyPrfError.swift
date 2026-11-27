//
//  PortalPasskeyPrfError.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// The error a Passkey PRF backup throws when the passkey or the secret it produces is the
/// problem; branch on `reason`.
///
/// The reasons and their raw values match the React Native and web SDKs, so the same failure
/// is reported the same way on every platform. Other failures keep their own types, as they do
/// for every backup method: Portal API and network errors (for example `PortalRequestsError`),
/// setup errors (`PasskeyPrfStorageError`, `MpcError.unsupportedStorageMethod`), and a cancelled
/// task's own error, which is `CancellationError` or `URLError` with the code `.cancelled`
/// depending on what was running: treat both as a cancel.
public struct PortalPasskeyPrfError: LocalizedError, CustomStringConvertible, Equatable {
  /// Why a Passkey PRF backup could not be enrolled, read or decrypted.
  public enum Reason: String, CaseIterable, Equatable {
    /// The passkey ceremony failed before a secret was derived, for a reason other than the two below.
    case ceremonyFailed = "PRF_CEREMONY_FAILED"
    /// The user dismissed the passkey prompt, or it timed out. iOS can also report a passkey
    /// that is no longer available this way, so word the message to cover that too.
    case userCancelled = "PRF_USER_CANCELLED"
    /// The platform reported that it has no passkey to offer for this request, or a passkey
    /// other than the enrolled one answered.
    case passkeyUnavailable = "PRF_PASSKEY_UNAVAILABLE"
    /// No passkey has been enrolled for this client, so there is nothing to recover with.
    case credentialNotFound = "PRF_CREDENTIAL_NOT_FOUND"
    /// The backup could not be decrypted with the secret the passkey produced.
    case decryptFailed = "PRF_DECRYPT_FAILED"
    /// The device or passkey provider cannot evaluate the WebAuthn PRF extension.
    case notSupported = "PRF_NOT_SUPPORTED"
    /// The passkey was enrolled under a different relying party than the one configured.
    case rpIdMismatch = "PRF_RP_ID_MISMATCH"

    var message: String {
      switch self {
      case .ceremonyFailed:
        return "The passkey request could not be completed."
      case .userCancelled:
        return "The passkey request was cancelled."
      case .passkeyUnavailable:
        return "The enrolled passkey is not available on this device."
      case .credentialNotFound:
        return "No passkey has been enrolled for this backup method."
      case .decryptFailed:
        return "The backup could not be decrypted with the secret from this passkey (wrong passkey or wrong ciphertext)."
      case .notSupported:
        return "This device or passkey provider does not support the WebAuthn PRF extension."
      case .rpIdMismatch:
        return "The passkey was enrolled under a different relying party."
      }
    }
  }

  public let reason: Reason
  /// The underlying failure, preserved for debugging. Deliberately kept off the message so
  /// platform internals are not surfaced to callers.
  public let cause: Error?
  /// Extra detail appended to the message, for example the two relying party IDs.
  public let context: String?

  public init(_ reason: Reason, cause: Error? = nil, context: String? = nil) {
    self.reason = reason
    self.cause = cause
    self.context = context
  }

  /// `true` when the user chose not to continue, rather than something failing.
  public var isUserCancelled: Bool {
    self.reason == .userCancelled
  }

  public var errorDescription: String? {
    var message = "[Portal] \(self.reason.message)"
    if let context, !context.isEmpty {
      message += " \(context)"
    }
    return message
  }

  public var description: String {
    "PortalPasskeyPrfError(\(self.reason.rawValue)): \(self.errorDescription ?? "")"
  }

  /// Equal when the reason and context match; the cause is diagnostic only.
  public static func == (lhs: PortalPasskeyPrfError, rhs: PortalPasskeyPrfError) -> Bool {
    lhs.reason == rhs.reason && lhs.context == rhs.context
  }
}
