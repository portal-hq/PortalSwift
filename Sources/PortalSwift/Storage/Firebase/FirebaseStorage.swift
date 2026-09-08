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
/// Every TBS call carries two credentials: the Portal bearer, resolved from `credentials` per call,
/// and the Firebase ID token. A single 401 is ambiguous — either token may have expired — so the
/// first one refreshes the Firebase token, re-resolves the Portal bearer and retries once; only a
/// 401 that survives that retry implicates the Portal credential and is reported through the
/// credentials layer. This storage deliberately installs no 401 hook on its transport: the hook
/// would fire on the first, ambiguous 401 and invalidate a session that a Firebase refresh would
/// have rescued.
///
/// ## Usage
/// ```swift
/// let portal = try Portal(clientApiKey, withRpcConfig: rpcConfig)
///
/// portal.registerBackupMethod(.Firebase, withStorage: FirebaseStorage(
///   getToken: {
///     return try await Auth.auth().currentUser?.getIDToken(forcingRefresh: true)
///   }
/// ))
/// ```
public class FirebaseStorage: Storage, PortalStorage {
  public weak var api: PortalApiProtocol?
  public let encryption: PortalEncryptionProtocol

  /// The Portal credential the TBS calls are authenticated with.
  ///
  /// Injected by `PortalMpc.registerBackupMethod(_:withStorage:)`; `nil` until then, which every
  /// operation reports as `FirebaseStorageError.noApiKey`. Resolved per call and again before the
  /// 401 retry, never cached, so a session rotated between the two attempts is honoured and one
  /// invalidated in between fails with `.sessionInvalidated` instead of resending a dead bearer.
  var credentials: PortalCredentials?

  /// The raw Client API Key behind `credentials`, for callers that still assign one.
  ///
  /// The getter returns `""` for a session-backed credential rather than the session token, and
  /// `nil` when no credential is set. The setter wraps the key in `StaticCredentials` (or clears
  /// the credential for `nil`), so the historical `firebaseStorage.apiKey = key` keeps working.
  @available(*, deprecated, message: "Not a reliable source of authentication — returns \"\" when Portal was constructed with credentials. Supply credentials to the SDK instead of reading this.")
  var apiKey: String? {
    get {
      self.credentials.map { PortalCredentialSupport.staticApiKey(of: $0) }
    }
    set {
      self.credentials = newValue.map { StaticCredentials($0) }
    }
  }

  /// The TBS host URL for Firebase backup endpoints.
  let tbsHost: String

  /// Customer-provided callback that returns a fresh Firebase ID token.
  private let getToken: () async throws -> String?

  private let logger = PortalLogger.shared

  /// HTTP request executor.
  private let requests: PortalRequestsProtocol

  /// Creates a new FirebaseStorage instance.
  ///
  /// - Parameters:
  ///   - getToken: A callback that returns a fresh Firebase ID token.
  ///     **Important:** This callback should always force-refresh the token (e.g., call
  ///     `getIDToken(forcingRefresh: true)`) to ensure retry-on-401 works correctly.
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
    if tbsHost.hasPrefix("http://") || tbsHost.hasPrefix("https://") {
      self.tbsHost = tbsHost
    } else if tbsHost.hasPrefix("localhost") || tbsHost.hasPrefix("127.0.0.1") {
      self.tbsHost = "http://" + tbsHost
    } else {
      self.tbsHost = "https://" + tbsHost
    }
    self.encryption = encryption ?? PortalEncryption()
    self.requests = requests ?? PortalRequests()
  }

  // MARK: - PortalStorage Protocol

  public func decrypt(_ value: String, withKey: String) async throws -> String {
    return try await encryption.decrypt(value, withPrivateKey: withKey)
  }

  public func delete() async throws -> Bool {
    // Delete is not supported for Firebase backup storage.
    throw FirebaseStorageError.deleteNotSupported
  }

  public func encrypt(_ value: String) async throws -> EncryptData {
    return try await encryption.encrypt(value)
  }

  /// Reads the encryption key from TBS via GET /v1/backup/encrypt-key.
  ///
  /// Sends both `Authorization: Bearer {portal_token}` and `X-Firebase-Token: {firebase_id_token}`
  /// headers. The Portal bearer is resolved before the Firebase token is requested. On a 401 the
  /// Firebase token is refreshed, the Portal bearer re-resolved, and the request retried once; a
  /// second 401 reports the Portal credential and is rethrown as `PortalRequestsError.unauthorized`.
  /// A `PortalCredentialError` propagates as is; every other transport failure is wrapped in
  /// `FirebaseStorageError.requestFailed`.
  ///
  /// - Returns: The encryption key string.
  public func read() async throws -> String {
    try await self.executeWithUnauthorizedRetry(operation: "read") { bearerToken, firebaseToken in
      try await self.fetchEncryptionKey(bearerToken: bearerToken, firebaseToken: firebaseToken)
    }
  }

  /// Checks that both credentials this storage depends on can be produced, without calling TBS.
  ///
  /// Resolves the Portal bearer first (surfacing `.noApiKey` or a `PortalCredentialError`), then
  /// asks the host for a Firebase token (surfacing `FirebaseStorageError.tokenUnavailable` when no
  /// Firebase user is signed in).
  public func validateOperations() async throws -> Bool {
    let credentials = try self.requireCredentials()
    _ = try PortalCredentialSupport.resolveToken(credentials)
    _ = try await self.obtainFirebaseToken()
    return true
  }

  /// Writes the encryption key to TBS via PUT /v1/backup/encrypt-key.
  ///
  /// Sends both `Authorization: Bearer {portal_token}` and `X-Firebase-Token: {firebase_id_token}`
  /// headers, with the same resolve order, single 401 retry, reporting and error mapping as
  /// `read()`.
  ///
  /// - Parameter value: The encryption key to store.
  /// - Returns: `true` if the write succeeded.
  public func write(_ value: String) async throws -> Bool {
    try await self.executeWithUnauthorizedRetry(operation: "write") { bearerToken, firebaseToken in
      try await self.storeEncryptionKey(value, bearerToken: bearerToken, firebaseToken: firebaseToken)
    }
  }

  // MARK: - Private Helpers

  /// Runs one TBS call with the credential handling every TBS operation shares.
  ///
  /// Order matters and is pinned by tests: the Portal bearer is resolved before the Firebase
  /// token so a dead session fails without a wasted round trip to the host's auth SDK. On the
  /// first 401 both tokens are obtained again — the bearer through a second
  /// `PortalCredentialSupport.resolveToken(_:)`, never the value captured before the first attempt — and the
  /// call is retried once. Only a 401 on that retry is attributed to the Portal credential and
  /// reported; the raw `PortalRequestsError.unauthorized` is rethrown so callers see the same
  /// error `PortalApi` would raise. `PortalCredentialError` and `FirebaseStorageError` propagate
  /// unchanged; any other transport failure, on either attempt, is wrapped in `.requestFailed`.
  private func executeWithUnauthorizedRetry<Response>(
    operation: String,
    _ perform: (_ bearerToken: String, _ firebaseToken: String) async throws -> Response
  ) async throws -> Response {
    let credentials = try self.requireCredentials()
    let bearerToken = try PortalCredentialSupport.resolveToken(credentials)
    let firebaseToken = try await self.obtainFirebaseToken()

    do {
      return try await perform(bearerToken, firebaseToken)
    } catch PortalRequestsError.unauthorized {
      self.logger.info("FirebaseStorage.\(operation)() - TBS rejected the request with 401. Refreshing the Firebase token and retrying once.")
    } catch {
      throw FirebaseStorageError.requestFailed(underlying: error)
    }

    let refreshedFirebaseToken = try await self.obtainFirebaseToken()
    let refreshedBearerToken = try PortalCredentialSupport.resolveToken(credentials)

    do {
      return try await perform(refreshedBearerToken, refreshedFirebaseToken)
    } catch PortalRequestsError.unauthorized {
      // Attribution is only sound when the Firebase half actually changed. A host whose
      // `getToken` callback handed back the same (stale) ID token did not refresh, so this second
      // 401 says nothing about the Portal credential — signing the user out of the wallet for a
      // Firebase misconfiguration is the wrong outcome.
      guard refreshedFirebaseToken != firebaseToken else {
        self.logger.error("FirebaseStorage.\(operation)() - TBS rejected the retried request with 401, but the Firebase token did not change on refresh; not attributing this to the Portal credential. Make getToken() force a refresh (getIDToken(forcingRefresh: true)).")
        throw FirebaseStorageError.tokenNotRefreshed
      }
      self.logger.error("FirebaseStorage.\(operation)() - TBS rejected the retried request with 401. Reporting the Portal credential as unauthorized.")
      PortalCredentialSupport.reportUnauthorizedAndLog(credentials, context: "FirebaseStorage.\(operation)")
      throw PortalRequestsError.unauthorized
    } catch {
      throw FirebaseStorageError.requestFailed(underlying: error)
    }
  }

  /// The injected credential, or the historical `.noApiKey` error when none has been set.
  private func requireCredentials() throws -> PortalCredentials {
    guard let credentials = self.credentials else {
      throw FirebaseStorageError.noApiKey
    }
    return credentials
  }

  /// Obtains a Firebase ID token from the customer's callback.
  private func obtainFirebaseToken() async throws -> String {
    guard let token = try await getToken() else {
      throw FirebaseStorageError.tokenUnavailable
    }
    return token
  }

  /// Fetches the encryption key from TBS.
  private func fetchEncryptionKey(bearerToken: String, firebaseToken: String) async throws -> String {
    guard let url = URL(string: "\(tbsHost)/v1/backup/encrypt-key") else {
      throw URLError(.badURL)
    }

    let request = PortalAPIRequest(url: url, method: .get, bearerToken: bearerToken)
    request.headers["X-Firebase-Token"] = firebaseToken

    let response = try await requests.execute(
      request: request,
      mappingInResponse: FirebaseEncryptionKeyResponse.self
    )

    return response.encryptionKey
  }

  /// Stores the encryption key to TBS.
  private func storeEncryptionKey(_ key: String, bearerToken: String, firebaseToken: String) async throws -> Bool {
    guard let url = URL(string: "\(tbsHost)/v1/backup/encrypt-key") else {
      throw URLError(.badURL)
    }

    let payload = FirebaseStoreEncryptionKeyRequest(encryptionKey: key)
    let request = PortalAPIRequest(url: url, method: .put, payload: payload, bearerToken: bearerToken)
    request.headers["X-Firebase-Token"] = firebaseToken

    try await requests.execute(request: request, mappingInResponse: Data.self)

    return true
  }
}
