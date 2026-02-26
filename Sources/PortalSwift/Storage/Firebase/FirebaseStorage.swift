//
//  FirebaseStorage.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// Responsible for CRUD actions for backup encryption keys stored via Firebase authentication.
///
/// FirebaseStorage uses a customer-provided `getToken` callback to obtain a fresh Firebase ID token
/// and communicates with TBS (Trustless Backup Service) to store/retrieve encryption keys.
///
/// ## Usage
/// ```swift
/// let portal = try Portal(clientApiKey, withRpcConfig: rpcConfig)
///
/// portal.registerBackupMethod(.Firebase, withStorage: FirebaseStorage(
///   getToken: {
///     return try await Auth.auth().currentUser?.getIDToken()
///   }
/// ))
/// ```
public class FirebaseStorage: Storage, PortalStorage {
  public weak var api: PortalApiProtocol?
  public let encryption: PortalEncryptionProtocol

  /// The client API key used for Authorization header.
  var apiKey: String?

  /// The TBS host URL for Firebase backup endpoints.
  var tbsHost: String

  /// Customer-provided callback that returns a fresh Firebase ID token.
  private let getToken: () async throws -> String?

  /// HTTP request executor.
  private let requests: PortalRequestsProtocol

  /// Creates a new FirebaseStorage instance.
  ///
  /// - Parameters:
  ///   - getToken: A callback that returns a fresh Firebase ID token. This is called
  ///     before each TBS request to ensure the token is valid. The callback should
  ///     call Firebase's `getIDToken()` method internally.
  ///   - tbsHost: The TBS host URL. Defaults to Portal's production TBS.
  ///   - encryption: The encryption implementation. Defaults to `PortalEncryption()`.
  ///   - requests: The HTTP request executor. Defaults to `PortalRequests()`.
  public init(
    getToken: @escaping () async throws -> String?,
    tbsHost: String = "backup.web.portalhq.io",
    encryption: PortalEncryptionProtocol? = nil,
    requests: PortalRequestsProtocol? = nil
  ) {
    self.getToken = getToken
    self.tbsHost = "https://" + tbsHost
    self.encryption = encryption ?? PortalEncryption()
    self.requests = requests ?? PortalRequests()
  }

  // MARK: - PortalStorage Protocol

  public func decrypt(_ value: String, withKey: String) async throws -> String {
    return try await encryption.decrypt(value, withPrivateKey: withKey)
  }

  public func delete() async throws -> Bool {
    return true
  }

  public func encrypt(_ value: String) async throws -> EncryptData {
    return try await encryption.encrypt(value)
  }

  /// Reads the encryption key from TBS via GET /v1/backup/encrypt-key.
  ///
  /// Sends both `Authorization: Bearer {client_api_key}` and `X-Firebase-Token: {firebase_id_token}`
  /// headers. On 401 response, retries once with a fresh token.
  ///
  /// - Returns: The encryption key string.
  public func read() async throws -> String {
    guard let apiKey = self.apiKey else {
      throw FirebaseStorageError.noApiKey
    }

    let firebaseToken = try await obtainFirebaseToken()

    do {
      return try await fetchEncryptionKey(apiKey: apiKey, firebaseToken: firebaseToken)
    } catch PortalRequestsError.unauthorized {
      // Token may have expired; retry once with a fresh token
      let refreshedToken = try await obtainFirebaseToken()
      return try await fetchEncryptionKey(apiKey: apiKey, firebaseToken: refreshedToken)
    }
  }

  public func validateOperations() async throws -> Bool {
    return true
  }

  /// Writes the encryption key to TBS via PUT /v1/backup/encrypt-key.
  ///
  /// Sends both `Authorization: Bearer {client_api_key}` and `X-Firebase-Token: {firebase_id_token}`
  /// headers. On 401 response, retries once with a fresh token.
  ///
  /// - Parameter value: The encryption key to store.
  /// - Returns: `true` if the write succeeded.
  public func write(_ value: String) async throws -> Bool {
    guard let apiKey = self.apiKey else {
      throw FirebaseStorageError.noApiKey
    }

    let firebaseToken = try await obtainFirebaseToken()

    do {
      return try await storeEncryptionKey(value, apiKey: apiKey, firebaseToken: firebaseToken)
    } catch PortalRequestsError.unauthorized {
      // Token may have expired; retry once with a fresh token
      let refreshedToken = try await obtainFirebaseToken()
      return try await storeEncryptionKey(value, apiKey: apiKey, firebaseToken: refreshedToken)
    }
  }

  // MARK: - Private Helpers

  /// Obtains a Firebase ID token from the customer's callback.
  private func obtainFirebaseToken() async throws -> String {
    guard let token = try await getToken() else {
      throw FirebaseStorageError.tokenUnavailable
    }
    return token
  }

  /// Fetches the encryption key from TBS.
  private func fetchEncryptionKey(apiKey: String, firebaseToken: String) async throws -> String {
    guard let url = URL(string: "\(tbsHost)/v1/backup/encrypt-key") else {
      throw URLError(.badURL)
    }

    let request = PortalAPIRequest(url: url, method: .get, bearerToken: apiKey)
    request.headers["X-Firebase-Token"] = firebaseToken

    let response = try await requests.execute(
      request: request,
      mappingInResponse: FirebaseEncryptionKeyResponse.self
    )

    return response.encryptionKey
  }

  /// Stores the encryption key to TBS.
  private func storeEncryptionKey(_ key: String, apiKey: String, firebaseToken: String) async throws -> Bool {
    guard let url = URL(string: "\(tbsHost)/v1/backup/encrypt-key") else {
      throw URLError(.badURL)
    }

    let payload = FirebaseStoreEncryptionKeyRequest(encryptionKey: key)
    let request = PortalAPIRequest(url: url, method: .put, payload: payload, bearerToken: apiKey)
    request.headers["X-Firebase-Token"] = firebaseToken

    try await requests.execute(request: request, mappingInResponse: Data.self)

    return true
  }
}
