//
//  FirebaseStorageTypes.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// Errors specific to FirebaseStorage operations.
public enum FirebaseStorageError: LocalizedError {
  /// The client API key has not been set on the FirebaseStorage instance.
  case noApiKey
  /// The getToken callback returned nil, meaning no Firebase user is signed in.
  case tokenUnavailable
  /// The TBS endpoint returned an unexpected response.
  case unexpectedResponse(String)

  public var errorDescription: String? {
    switch self {
    case .noApiKey:
      return "FirebaseStorage: No API key set. Ensure FirebaseStorage is registered via portal.registerBackupMethod()."
    case .tokenUnavailable:
      return "FirebaseStorage: Firebase token unavailable. Ensure the user is signed in to Firebase before performing backup operations."
    case .unexpectedResponse(let message):
      return "FirebaseStorage: Unexpected response from TBS - \(message)"
    }
  }
}

/// Response from GET /v1/backup/encrypt-key.
struct FirebaseEncryptionKeyResponse: Codable {
  let encryptionKey: String
}

/// Request body for PUT /v1/backup/encrypt-key.
struct FirebaseStoreEncryptionKeyRequest: Codable {
  let encryptionKey: String
}
