//
//  FirebaseStorageTypes.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// Errors specific to FirebaseStorage operations.
public enum FirebaseStorageError: LocalizedError, Equatable {
  /// The client API key has not been set on the FirebaseStorage instance.
  case noApiKey
  /// The getToken callback returned nil, meaning no Firebase user is signed in.
  case tokenUnavailable
  /// The TBS endpoint returned an unexpected response.
  case unexpectedResponse(String)
  /// A non-401 request to TBS failed with the given underlying error.
  case requestFailed(underlying: Error)
  /// Delete is not supported for Firebase backup storage.
  case deleteNotSupported
  /// TBS answered 401 twice, but the `getToken` callback returned the same Firebase ID token on
  /// the retry, so the second 401 cannot be attributed to the Portal credential. Make the
  /// callback force a refresh (`getIDToken(forcingRefresh: true)`).
  case tokenNotRefreshed

  public static func == (lhs: FirebaseStorageError, rhs: FirebaseStorageError) -> Bool {
    switch (lhs, rhs) {
    case (.noApiKey, .noApiKey),
      (.tokenUnavailable, .tokenUnavailable),
      (.deleteNotSupported, .deleteNotSupported),
      (.tokenNotRefreshed, .tokenNotRefreshed):
      return true
    case (.unexpectedResponse(let l), .unexpectedResponse(let r)):
      return l == r
    case (.requestFailed(let l), .requestFailed(let r)):
      return l.localizedDescription == r.localizedDescription
    default:
      return false
    }
  }

  public var errorDescription: String? {
    switch self {
    case .noApiKey:
      return "FirebaseStorage: No API key set. Ensure FirebaseStorage is registered via portal.registerBackupMethod()."
    case .tokenUnavailable:
      return "FirebaseStorage: Firebase token unavailable. Ensure the user is signed in to Firebase before performing backup operations."
    case .unexpectedResponse(let message):
      return "FirebaseStorage: Unexpected response from TBS - \(message)"
    case .requestFailed(let underlying):
      return "FirebaseStorage: Request to TBS failed - \(underlying.localizedDescription)"
    case .deleteNotSupported:
      return "FirebaseStorage: Delete is not supported for Firebase backup storage."
    case .tokenNotRefreshed:
      return "FirebaseStorage: TBS rejected the request twice, but getToken() returned the same Firebase ID token on retry. Force a refresh (getIDToken(forcingRefresh: true)) so a stale Firebase token is not mistaken for a rejected Portal session."
    }
  }
}

/// Response from GET /v1/backup/encrypt-key.
public struct FirebaseEncryptionKeyResponse: Codable {
  public let encryptionKey: String
}

/// Request body for PUT /v1/backup/encrypt-key.
public struct FirebaseStoreEncryptionKeyRequest: Codable {
  public let encryptionKey: String
}
