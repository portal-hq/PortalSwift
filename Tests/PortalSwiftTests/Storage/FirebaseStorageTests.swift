//
//  FirebaseStorageTests.swift
//
//
//  Created by Portal Labs, Inc.
//

@testable import PortalSwift
import XCTest

final class FirebaseStorageTests: XCTestCase {
  var storage: FirebaseStorage?

  /// The Firebase ID tokens the injected `getToken` callback hands out, and the counter behind
  /// `firebaseTokenCalls`. Rebuilt in `setUp` so one case's call count never leaks into the next.
  var firebaseTokens = FirebaseTokenProvider()

  /// Captures every line the SDK logs, so the security cases can prove that no Portal bearer or
  /// Firebase ID token was ever written to a log.
  var recordingLogger: RecordingLogger?

  override func setUpWithError() throws {
    // The registry's once-ever "reported" flags are process-wide; without this reset a credential
    // reported by an earlier case could silently suppress the report a later case asserts on.
    CredentialInvalidationRegistry.shared.resetForTesting()
    firebaseTokens = FirebaseTokenProvider()
    let logger = RecordingLogger()
    logger.install()
    recordingLogger = logger
    initFirebaseStorage()
  }

  override func tearDownWithError() throws {
    storage = nil
    recordingLogger?.uninstall()
    recordingLogger = nil
    CredentialInvalidationRegistry.shared.resetForTesting()
  }
}

// MARK: - Credentials test doubles

/// A counting stand-in for the host's Firebase `getIDToken(forcingRefresh:)` callback.
///
/// `FirebaseStorage` asks for a Firebase token once per attempt, so both the number of calls and
/// their position relative to the Portal bearer resolution are part of the contract: the bearer is
/// resolved first (a dead session must not cost a round trip to the host's auth SDK), and the 401
/// retry must ask for a *fresh* token rather than reuse the one captured before the first attempt.
/// Values are handed out in order and the last one repeats, so a case that only needs the happy
/// path arranges nothing. Lock-guarded because the storage calls back from whichever thread the
/// asynchronous operation resumed on.
final class FirebaseTokenProvider: @unchecked Sendable {
  private let lock = NSLock()
  private var _calls = 0
  private var _values: [String?]
  private var _onCall: ((Int) -> Void)?

  /// Creates a provider handing out `values` in order; the final value repeats afterwards.
  init(values: [String?] = ["fb-1", "fb-2"]) {
    self._values = values
  }

  /// How many times the callback ran, including the call that returned `nil`.
  var calls: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._calls
  }

  /// The values still to hand out. Assign before the operation under test to script a refresh
  /// that fails (`["fb-1", nil]`).
  var values: [String?] {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._values
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._values = newValue
    }
  }

  /// Runs inside the callback with the 1-based call number, after it has been counted and outside
  /// the lock. This is the seam a case uses to change the world *between* the two attempts — for
  /// example invalidating the session just before the retry re-resolves the bearer.
  var onCall: ((Int) -> Void)? {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._onCall
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._onCall = newValue
    }
  }

  /// Counts the call, runs `onCall`, and returns the value for this position.
  func next() -> String? {
    self.lock.lock()
    self._calls += 1
    let index = self._calls
    let value: String?
    if self._values.isEmpty {
      value = nil
    } else if index <= self._values.count {
      value = self._values[index - 1]
    } else {
      value = self._values[self._values.count - 1]
    }
    let hook = self._onCall
    self.lock.unlock()

    hook?(index)
    return value
  }
}

/// The error a failing host credential provider throws, with a description that deliberately
/// carries no token so the "never leaks a secret" cases cannot pass by accident.
enum FirebaseCredentialProviderError: LocalizedError {
  case boom

  var errorDescription: String? {
    "The host credential provider failed."
  }
}

/// The error a credential raises when its persisted copy cannot be deleted, used to prove the
/// original `401` still reaches the caller.
enum FirebaseInvalidationError: LocalizedError {
  case couldNotDelete

  var errorDescription: String? {
    "The persisted credential could not be deleted."
  }
}

// MARK: - Test Helpers

extension FirebaseStorageTests {
  func initFirebaseStorage(
    getToken: (() async throws -> String?)? = nil,
    requests: PortalRequestsProtocol? = nil
  ) {
    let portalRequests = requests ?? MockPortalRequests()
    let tokenProvider = getToken ?? { "mock-firebase-token" }

    storage = FirebaseStorage(
      getToken: tokenProvider,
      tbsHost: "backup.web.portalhq.io",
      encryption: MockPortalEncryption(),
      requests: portalRequests
    )
    storage?.apiKey = MockConstants.mockApiKey
    storage?.api = PortalApi(apiKey: MockConstants.mockApiKey, requests: MockPortalRequests())
  }

  func initFirebaseStorageWithSpy(
    getToken: (() async throws -> String?)? = nil
  ) -> PortalRequestsSpy {
    let spy = PortalRequestsSpy()
    let tokenProvider = getToken ?? { "mock-firebase-token" }

    storage = FirebaseStorage(
      getToken: tokenProvider,
      tbsHost: "backup.web.portalhq.io",
      encryption: MockPortalEncryption(),
      requests: spy
    )
    storage?.apiKey = MockConstants.mockApiKey
    storage?.api = PortalApi(apiKey: MockConstants.mockApiKey, requests: MockPortalRequests())

    return spy
  }
}

// MARK: - decrypt tests

extension FirebaseStorageTests {
  func testDecrypt() async throws {
    let mockGenerateResponse = try MockConstants.mockGenerateResponse
    let decryptResult = try await storage?.decrypt(MockConstants.mockCiphertext, withKey: MockConstants.mockEncryptionKey)
    guard let decryptedData = decryptResult?.data(using: .utf8) else {
      throw FirebaseStorageError.unexpectedResponse("Unable to decode data")
    }
    let generateResponse = try JSONDecoder().decode(PortalMpcGenerateResponse.self, from: decryptedData)
    XCTAssertEqual(generateResponse["ED25519"]?.id, mockGenerateResponse["ED25519"]?.id)
    XCTAssertEqual(generateResponse["SECP256K1"]?.id, mockGenerateResponse["SECP256K1"]?.id)
  }
}

// MARK: - encrypt tests

extension FirebaseStorageTests {
  func testEncrypt() async throws {
    let shareData = try JSONEncoder().encode(MockConstants.mockWalletSigningShare)
    guard let shareString = String(data: shareData, encoding: .utf8) else {
      throw FirebaseStorageError.unexpectedResponse("Unable to encode data")
    }
    let encryptedData = try await storage?.encrypt(shareString)
    XCTAssertEqual(encryptedData, MockConstants.mockEncryptData)
  }
}

// MARK: - read tests

extension FirebaseStorageTests {
  func testRead() async throws {
    let spy = initFirebaseStorageWithSpy()

    // Set up return data for the GET request
    let mockResponse = FirebaseEncryptionKeyResponse(encryptionKey: MockConstants.mockEncryptionKey)
    spy.returnData = try JSONEncoder().encode(mockResponse)

    let result = try await storage?.read()
    XCTAssertEqual(result, MockConstants.mockEncryptionKey)
  }

  func test_read_willCall_executeRequest_once() async throws {
    let spy = initFirebaseStorageWithSpy()

    let mockResponse = FirebaseEncryptionKeyResponse(encryptionKey: MockConstants.mockEncryptionKey)
    spy.returnData = try JSONEncoder().encode(mockResponse)

    _ = try await storage?.read()

    XCTAssertEqual(spy.executeCallsCount, 1)
  }

  func test_read_sendsCorrectURLPathAndMethod() async throws {
    let spy = initFirebaseStorageWithSpy()

    let mockResponse = FirebaseEncryptionKeyResponse(encryptionKey: MockConstants.mockEncryptionKey)
    spy.returnData = try JSONEncoder().encode(mockResponse)

    _ = try await storage?.read()

    XCTAssertEqual(spy.executeRequestParam?.method, .get)
    XCTAssertTrue(spy.executeRequestParam?.url.absoluteString.contains("/v1/backup/encrypt-key") ?? false)
  }

  func test_read_includesFirebaseTokenHeader() async throws {
    let spy = initFirebaseStorageWithSpy()

    let mockResponse = FirebaseEncryptionKeyResponse(encryptionKey: MockConstants.mockEncryptionKey)
    spy.returnData = try JSONEncoder().encode(mockResponse)

    _ = try await storage?.read()

    XCTAssertEqual(spy.executeRequestParam?.headers["X-Firebase-Token"], "mock-firebase-token")
  }

  func test_read_includesAuthorizationHeader() async throws {
    let spy = initFirebaseStorageWithSpy()

    let mockResponse = FirebaseEncryptionKeyResponse(encryptionKey: MockConstants.mockEncryptionKey)
    spy.returnData = try JSONEncoder().encode(mockResponse)

    _ = try await storage?.read()

    XCTAssertEqual(spy.executeRequestParam?.headers["Authorization"], "Bearer \(MockConstants.mockApiKey)")
  }

  func test_read_throwsError_whenNoApiKey() async throws {
    storage?.apiKey = nil

    do {
      _ = try await storage?.read()
      XCTFail("Expected FirebaseStorageError.noApiKey to be thrown")
    } catch {
      XCTAssertTrue(error is FirebaseStorageError)
    }
  }

  func test_read_throwsError_whenTokenCallbackReturnsNil() async throws {
    initFirebaseStorage(getToken: { nil })
    storage?.apiKey = MockConstants.mockApiKey

    do {
      _ = try await storage?.read()
      XCTFail("Expected FirebaseStorageError.tokenUnavailable to be thrown")
    } catch {
      XCTAssertTrue(error is FirebaseStorageError)
    }
  }
}

// MARK: - write tests

extension FirebaseStorageTests {
  func testWrite() async throws {
    let spy = initFirebaseStorageWithSpy()

    // For PUT, the response is Data type
    spy.returnData = Data()

    let success = try await storage?.write(MockConstants.mockEncryptionKey) ?? false
    XCTAssertTrue(success)
  }

  func test_write_willCall_executeRequest_once() async throws {
    let spy = initFirebaseStorageWithSpy()
    spy.returnData = Data()

    _ = try await storage?.write(MockConstants.mockEncryptionKey)

    XCTAssertEqual(spy.executeCallsCount, 1)
  }

  func test_write_sendsCorrectURLPathAndMethod() async throws {
    let spy = initFirebaseStorageWithSpy()
    spy.returnData = Data()

    _ = try await storage?.write(MockConstants.mockEncryptionKey)

    XCTAssertEqual(spy.executeRequestParam?.method, .put)
    XCTAssertTrue(spy.executeRequestParam?.url.absoluteString.contains("/v1/backup/encrypt-key") ?? false)
  }

  func test_write_includesFirebaseTokenHeader() async throws {
    let spy = initFirebaseStorageWithSpy()
    spy.returnData = Data()

    _ = try await storage?.write(MockConstants.mockEncryptionKey)

    XCTAssertEqual(spy.executeRequestParam?.headers["X-Firebase-Token"], "mock-firebase-token")
  }

  func test_write_includesAuthorizationHeader() async throws {
    let spy = initFirebaseStorageWithSpy()
    spy.returnData = Data()

    _ = try await storage?.write(MockConstants.mockEncryptionKey)

    XCTAssertEqual(spy.executeRequestParam?.headers["Authorization"], "Bearer \(MockConstants.mockApiKey)")
  }

  func test_write_throwsError_whenNoApiKey() async throws {
    storage?.apiKey = nil

    do {
      _ = try await storage?.write(MockConstants.mockEncryptionKey)
      XCTFail("Expected FirebaseStorageError.noApiKey to be thrown")
    } catch {
      XCTAssertTrue(error is FirebaseStorageError)
    }
  }

  func test_write_throwsError_whenTokenCallbackReturnsNil() async throws {
    initFirebaseStorage(getToken: { nil })
    storage?.apiKey = MockConstants.mockApiKey

    do {
      _ = try await storage?.write(MockConstants.mockEncryptionKey)
      XCTFail("Expected FirebaseStorageError.tokenUnavailable to be thrown")
    } catch {
      XCTAssertTrue(error is FirebaseStorageError)
    }
  }
}

// MARK: - delete tests

extension FirebaseStorageTests {
  func test_delete_throwsDeleteNotSupported() async throws {
    do {
      _ = try await storage?.delete()
      XCTFail("Expected FirebaseStorageError.deleteNotSupported to be thrown")
    } catch {
      XCTAssertTrue(error is FirebaseStorageError)
      XCTAssertEqual(error as? FirebaseStorageError, .deleteNotSupported)
    }
  }
}

// MARK: - validateOperations tests

extension FirebaseStorageTests {
  func test_validateOperations_returnsTrue() async throws {
    let isValid = try await storage?.validateOperations() ?? false
    XCTAssertTrue(isValid)
  }
}

// MARK: - BackupMethods.Firebase tests

extension FirebaseStorageTests {
  func test_firebaseBackupMethod_hasCorrectRawValue() {
    XCTAssertEqual(BackupMethods.Firebase.rawValue, "FIREBASE")
  }

  func test_firebaseBackupMethod_isDecodable() throws {
    let json = "\"FIREBASE\""
    let data = json.data(using: .utf8)!
    let method = try JSONDecoder().decode(BackupMethods.self, from: data)
    XCTAssertEqual(method, .Firebase)
  }

  func test_firebaseBackupMethod_isEncodable() throws {
    let method = BackupMethods.Firebase
    let data = try JSONEncoder().encode(method)
    let string = String(data: data, encoding: .utf8)
    XCTAssertEqual(string, "\"FIREBASE\"")
  }

  func test_firebaseBackupMethod_initFromString() {
    let method = BackupMethods(fromString: "FIREBASE")
    XCTAssertEqual(method, .Firebase)
  }

  func test_firebaseBackupMethod_coexistsWithOtherMethods() {
    // Verify Firebase doesn't conflict with other backup method raw values
    let allMethods: [BackupMethods] = [.GoogleDrive, .iCloud, .local, .Password, .Passkey, .Firebase, .Unknown]
    let rawValues = allMethods.map(\.rawValue)
    let uniqueRawValues = Set(rawValues)
    XCTAssertEqual(rawValues.count, uniqueRawValues.count, "All backup method raw values should be unique")
  }
}

// MARK: - TBS host configuration tests

extension FirebaseStorageTests {
  func test_tbsHost_defaultsToPortalProduction() {
    let storage = FirebaseStorage(getToken: { "token" })
    XCTAssertEqual(storage.tbsHost, "https://backup.web.portalhq.io")
  }

  func test_tbsHost_canBeCustomized() {
    let storage = FirebaseStorage(
      getToken: { "token" },
      tbsHost: "custom-tbs.example.com"
    )
    XCTAssertEqual(storage.tbsHost, "https://custom-tbs.example.com")
  }
}

// MARK: - Error description tests

extension FirebaseStorageTests {
  func test_noApiKeyError_hasDescription() {
    let error = FirebaseStorageError.noApiKey
    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription?.contains("API key") ?? false)
  }

  func test_tokenUnavailableError_hasDescription() {
    let error = FirebaseStorageError.tokenUnavailable
    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription?.contains("token unavailable") ?? false)
  }

  func test_unexpectedResponseError_hasDescription() {
    let error = FirebaseStorageError.unexpectedResponse("test message")
    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription?.contains("test message") ?? false)
  }
}

// MARK: - Credentials test helpers

extension FirebaseStorageTests {
  /// How many times the injected Firebase `getToken` callback ran.
  var firebaseTokenCalls: Int {
    self.firebaseTokens.calls
  }

  /// Builds the storage every credentials case uses: a recording transport, the Firebase token
  /// callback backed by `firebaseTokens`, and `credentials` injected the way
  /// `PortalMpc.registerBackupMethod(_:withStorage:)` injects it. Nothing else is stubbed, so the
  /// real resolve -> request -> 401-retry -> report path runs.
  @discardableResult
  func initFirebaseStorageWithSpy(credentials: PortalCredentials?) -> PortalRequestsSpy {
    let spy = PortalRequestsSpy()
    let provider = self.firebaseTokens

    let storage = FirebaseStorage(
      getToken: { provider.next() },
      tbsHost: "backup.web.portalhq.io",
      encryption: MockPortalEncryption(),
      requests: spy
    )
    storage.credentials = credentials
    self.storage = storage

    return spy
  }

  /// A credential that hands out `token` and rotates to `rotatedTo` on its second resolution,
  /// which is how the retry cases prove the bearer is resolved again rather than reused.
  func makeRotatingCredentials(token: String, rotatedTo: String) -> MockCredentials {
    let credentials = MockCredentials(tokenValue: token)
    credentials.onGetToken = { [weak credentials] in
      guard let credentials, credentials.getTokenCalls == 2 else {
        return
      }
      // `MockCredentials` reads `tokenValue` after the hook, so rotating on the second call is
      // what makes the second resolution -- and only the second -- hand back the new value.
      credentials.tokenValue = rotatedTo
    }
    return credentials
  }

  /// The TBS body for a successful `GET /v1/backup/encrypt-key`.
  func encodedEncryptionKeyResponse() throws -> Data {
    try JSONEncoder().encode(FirebaseEncryptionKeyResponse(encryptionKey: MockConstants.mockEncryptionKey))
  }
}

// MARK: - read credentials tests

extension FirebaseStorageTests {
  func test_read_willSendResolvedPortalBearer() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "portal-tok-1")
    let spy = initFirebaseStorageWithSpy(credentials: credentials)
    spy.returnData = try encodedEncryptionKeyResponse()
    let storage = try XCTUnwrap(self.storage)

    // and given
    let key = try await storage.read()

    // then
    XCTAssertEqual(key, MockConstants.mockEncryptionKey)
    XCTAssertEqual(spy.executeCallsCount, 1)
    XCTAssertEqual(spy.executeRequestHistory.first?.headers["Authorization"], "Bearer portal-tok-1")
    XCTAssertEqual(spy.executeRequestHistory.first?.headers["X-Firebase-Token"], "fb-1")
  }

  func test_read_willResolvePortalBearer_beforeFirebaseToken() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "portal-tok-1")
    credentials.onGetToken = { throw FirebaseCredentialProviderError.boom }
    let spy = initFirebaseStorageWithSpy(credentials: credentials)
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(
      try await storage.read(),
      expected: PortalCredentialError.providerFailure(underlying: FirebaseCredentialProviderError.boom)
    )

    // then: a dead credential costs neither a Firebase round trip nor a TBS request
    XCTAssertEqual(firebaseTokenCalls, 0)
    XCTAssertEqual(spy.executeCallsCount, 0)
  }

  func test_read_willResolveTokenPerCall_andPickUpRotation() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "portal-tok-1")
    let spy = initFirebaseStorageWithSpy(credentials: credentials)
    spy.returnData = try encodedEncryptionKeyResponse()
    let storage = try XCTUnwrap(self.storage)

    // and given
    _ = try await storage.read()
    credentials.tokenValue = "portal-tok-2"
    _ = try await storage.read()

    // then
    XCTAssertEqual(credentials.getTokenCalls, 2)
    XCTAssertEqual(spy.executeCallsCount, 2)
    XCTAssertEqual(spy.executeRequestHistory.last?.headers["Authorization"], "Bearer portal-tok-2")
  }

  func test_read_willThrowUnavailable_withoutRequest_whenTokenBlank() async throws {
    // given
    let spy = initFirebaseStorageWithSpy(credentials: MockCredentials(tokenValue: ""))
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(try await storage.read(), expected: PortalCredentialError.unavailable)

    // then
    XCTAssertEqual(spy.executeCallsCount, 0)
    XCTAssertEqual(firebaseTokenCalls, 0)
  }

  func test_read_willThrowSessionInvalidated_withoutRequest() async throws {
    // given
    let session = MockPortalSession(tokenValue: "portal-tok-1")
    try session.invalidate()
    let spy = initFirebaseStorageWithSpy(credentials: session)
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(try await storage.read(), expected: PortalCredentialError.sessionInvalidated)

    // then
    XCTAssertEqual(spy.executeCallsCount, 0)
    XCTAssertEqual(firebaseTokenCalls, 0)
  }

  func test_read_willThrowNoApiKey_whenCredentialsNil() async throws {
    // given
    let spy = initFirebaseStorageWithSpy(credentials: nil)
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(try await storage.read(), expected: FirebaseStorageError.noApiKey)

    // then
    XCTAssertEqual(spy.executeCallsCount, 0)
    XCTAssertEqual(firebaseTokenCalls, 0)
  }

  func test_read_willRefreshFirebaseToken_andReResolveBearer_thenRetry_onFirst401() async throws {
    // given
    let credentials = makeRotatingCredentials(token: "portal-tok-1", rotatedTo: "portal-tok-2")
    let spy = initFirebaseStorageWithSpy(credentials: credentials)
    spy.returnData = try encodedEncryptionKeyResponse()
    spy.executeThrowableErrorSequence = [PortalRequestsError.unauthorized, nil]
    let storage = try XCTUnwrap(self.storage)

    // and given
    let key = try await storage.read()

    // then
    XCTAssertEqual(key, MockConstants.mockEncryptionKey)
    XCTAssertEqual(spy.executeCallsCount, 2)
    XCTAssertEqual(firebaseTokenCalls, 2)
    XCTAssertEqual(credentials.getTokenCalls, 2)
    XCTAssertEqual(spy.executeRequestHistory.count, 2)
    XCTAssertEqual(spy.executeRequestHistory.last?.headers["Authorization"], "Bearer portal-tok-2")
    XCTAssertEqual(spy.executeRequestHistory.last?.headers["X-Firebase-Token"], "fb-2")
  }

  func test_read_willNotReport_whenRetrySucceeds() async throws {
    // given
    let credentials = makeRotatingCredentials(token: "portal-tok-1", rotatedTo: "portal-tok-2")
    let recorder = InvalidationListenerRecorder(credentials: credentials)
    let spy = initFirebaseStorageWithSpy(credentials: credentials)
    spy.returnData = try encodedEncryptionKeyResponse()
    spy.executeThrowableErrorSequence = [PortalRequestsError.unauthorized, nil]
    let storage = try XCTUnwrap(self.storage)

    // and given
    _ = try await storage.read()

    // then: the first 401 is ambiguous, so nothing about the Portal credential is concluded
    XCTAssertEqual(credentials.invalidateCalls, 0)
    let notified = await waitUntil(timeout: 0.3) { recorder.count > 0 }
    XCTAssertFalse(notified, "A retry that succeeded must not tell the host the session ended.")
  }

  func test_read_willReportOnce_andRethrowUnauthorized_onSecond401() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "portal-tok-1")
    let recorder = InvalidationListenerRecorder(credentials: credentials)
    let spy = initFirebaseStorageWithSpy(credentials: credentials)
    spy.returnData = try encodedEncryptionKeyResponse()
    spy.executeThrowableErrorSequence = [PortalRequestsError.unauthorized, PortalRequestsError.unauthorized]
    let storage = try XCTUnwrap(self.storage)

    // and given
    let thrown = await XCTAssertThrowsAsync(try await storage.read(), expected: PortalRequestsError.unauthorized)

    // then: the raw transport error surfaces, not a `.requestFailed` wrapper
    XCTAssertNil(thrown as? FirebaseStorageError)
    XCTAssertEqual(spy.executeCallsCount, 2)
    XCTAssertEqual(firebaseTokenCalls, 2)
    XCTAssertEqual(credentials.invalidateCalls, 1)
    let notified = await waitUntil { recorder.count == 1 }
    XCTAssertTrue(notified, "A 401 that survived the Firebase refresh must report the credential.")
  }

  func test_read_willThrowSessionInvalidated_whenCredentialInvalidatedBetweenAttempts() async throws {
    // given: the session dies while the retry is refreshing the Firebase token, which is the
    // window between the two attempts the storage re-resolves the bearer in.
    let session = MockPortalSession(tokenValue: "portal-tok-1")
    firebaseTokens.onCall = { call in
      guard call == 2 else {
        return
      }
      try? session.invalidate()
    }
    let recorder = InvalidationListenerRecorder(credentials: session)
    let spy = initFirebaseStorageWithSpy(credentials: session)
    spy.returnData = try encodedEncryptionKeyResponse()
    spy.executeThrowableErrorSequence = [PortalRequestsError.unauthorized]
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(try await storage.read(), expected: PortalCredentialError.sessionInvalidated)

    // then
    XCTAssertEqual(spy.executeCallsCount, 1)
    XCTAssertEqual(session.invalidateCalls, 1)
    let notified = await waitUntil(timeout: 0.3) { recorder.count > 0 }
    XCTAssertFalse(notified, "A credential error is not a backend rejection and must not be reported.")
  }

  func test_read_willNotRewrapCredentialError_intoRequestFailed() async throws {
    // given
    let session = MockPortalSession(tokenValue: "portal-tok-1")
    firebaseTokens.onCall = { call in
      guard call == 2 else {
        return
      }
      try? session.invalidate()
    }
    let spy = initFirebaseStorageWithSpy(credentials: session)
    spy.returnData = try encodedEncryptionKeyResponse()
    spy.executeThrowableErrorSequence = [PortalRequestsError.unauthorized]
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(try await storage.read()) { error in
      // then
      XCTAssertTrue(error is PortalCredentialError, "Expected a PortalCredentialError, got \(type(of: error)).")
      XCTAssertNil(error as? FirebaseStorageError)
    }
  }

  func test_read_willThrowTokenUnavailable_whenRefreshReturnsNil() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "portal-tok-1")
    firebaseTokens.values = ["fb-1", nil]
    let spy = initFirebaseStorageWithSpy(credentials: credentials)
    spy.returnData = try encodedEncryptionKeyResponse()
    spy.executeThrowableErrorSequence = [PortalRequestsError.unauthorized]
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(try await storage.read(), expected: FirebaseStorageError.tokenUnavailable)

    // then
    XCTAssertEqual(spy.executeCallsCount, 1)
    XCTAssertEqual(credentials.invalidateCalls, 0)
  }

  func test_read_willWrapNon401_intoRequestFailed_withoutRetry() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "portal-tok-1")
    let spy = initFirebaseStorageWithSpy(credentials: credentials)
    let serverError = PortalRequestsError.internalServerError("500 - x", url: "https://backup.web.portalhq.io/v1/backup/encrypt-key")
    spy.returnData = try encodedEncryptionKeyResponse()
    spy.executeThrowableErrorSequence = [serverError]
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(try await storage.read()) { error in
      // then
      guard case .requestFailed(let underlying)? = error as? FirebaseStorageError else {
        XCTFail("Expected FirebaseStorageError.requestFailed, got \(type(of: error)).")
        return
      }
      XCTAssertEqual(underlying as? PortalRequestsError, serverError)
    }

    XCTAssertEqual(spy.executeCallsCount, 1)
    XCTAssertEqual(firebaseTokenCalls, 1)
    XCTAssertEqual(credentials.invalidateCalls, 0)
  }

  func test_read_willStillThrowUnauthorized_whenInvalidateThrows() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "portal-tok-1")
    credentials.onInvalidate = { throw FirebaseInvalidationError.couldNotDelete }
    let recorder = InvalidationListenerRecorder(credentials: credentials)
    let spy = initFirebaseStorageWithSpy(credentials: credentials)
    spy.returnData = try encodedEncryptionKeyResponse()
    spy.executeThrowableErrorSequence = [PortalRequestsError.unauthorized, PortalRequestsError.unauthorized]
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(try await storage.read(), expected: PortalRequestsError.unauthorized)

    // then: a failed invalidation is bookkeeping and never replaces the transport error
    let notified = await waitUntil { recorder.count == 1 }
    XCTAssertTrue(notified, "The host is told the session ended even when the credential could not clear itself.")
    let logger = try XCTUnwrap(recordingLogger)
    XCTAssertTrue(logger.contains("FirebaseStorage.read"))
  }
}

// MARK: - write credentials tests

extension FirebaseStorageTests {
  func test_write_willSendResolvedPortalBearer() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "portal-tok-1")
    let spy = initFirebaseStorageWithSpy(credentials: credentials)
    spy.returnData = Data()
    let storage = try XCTUnwrap(self.storage)

    // and given
    let didWrite = try await storage.write(MockConstants.mockEncryptionKey)

    // then
    XCTAssertTrue(didWrite)
    XCTAssertEqual(spy.executeCallsCount, 1)
    XCTAssertEqual(spy.executeRequestHistory.first?.method, .put)
    XCTAssertEqual(spy.executeRequestHistory.first?.headers["Authorization"], "Bearer portal-tok-1")
    XCTAssertEqual(spy.executeRequestHistory.first?.headers["X-Firebase-Token"], "fb-1")
  }

  func test_write_willResolvePortalBearer_beforeFirebaseToken() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "portal-tok-1")
    credentials.onGetToken = { throw FirebaseCredentialProviderError.boom }
    let spy = initFirebaseStorageWithSpy(credentials: credentials)
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(
      try await storage.write(MockConstants.mockEncryptionKey),
      expected: PortalCredentialError.providerFailure(underlying: FirebaseCredentialProviderError.boom)
    )

    // then
    XCTAssertEqual(firebaseTokenCalls, 0)
    XCTAssertEqual(spy.executeCallsCount, 0)
  }

  func test_write_willThrowUnavailable_whenTokenBlank() async throws {
    // given
    let spy = initFirebaseStorageWithSpy(credentials: MockCredentials(tokenValue: ""))
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(
      try await storage.write(MockConstants.mockEncryptionKey),
      expected: PortalCredentialError.unavailable
    )

    // then
    XCTAssertEqual(spy.executeCallsCount, 0)
    XCTAssertEqual(firebaseTokenCalls, 0)
  }

  func test_write_willThrowNoApiKey_whenCredentialsNil() async throws {
    // given
    let spy = initFirebaseStorageWithSpy(credentials: nil)
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(
      try await storage.write(MockConstants.mockEncryptionKey),
      expected: FirebaseStorageError.noApiKey
    )

    // then
    XCTAssertEqual(spy.executeCallsCount, 0)
  }

  func test_write_willRefreshFirebaseToken_andReResolveBearer_thenRetry_onFirst401() async throws {
    // given
    let credentials = makeRotatingCredentials(token: "portal-tok-1", rotatedTo: "portal-tok-2")
    let spy = initFirebaseStorageWithSpy(credentials: credentials)
    spy.returnData = Data()
    spy.executeThrowableErrorSequence = [PortalRequestsError.unauthorized, nil]
    let storage = try XCTUnwrap(self.storage)

    // and given
    let didWrite = try await storage.write(MockConstants.mockEncryptionKey)

    // then
    XCTAssertTrue(didWrite)
    XCTAssertEqual(spy.executeCallsCount, 2)
    XCTAssertEqual(firebaseTokenCalls, 2)
    XCTAssertEqual(spy.executeRequestHistory.count, 2)
    XCTAssertEqual(spy.executeRequestHistory.last?.headers["Authorization"], "Bearer portal-tok-2")
    XCTAssertEqual(spy.executeRequestHistory.last?.headers["X-Firebase-Token"], "fb-2")
    XCTAssertEqual(credentials.invalidateCalls, 0)
  }

  func test_write_willReportOnce_andRethrowUnauthorized_onSecond401() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "portal-tok-1")
    let recorder = InvalidationListenerRecorder(credentials: credentials)
    let spy = initFirebaseStorageWithSpy(credentials: credentials)
    spy.returnData = Data()
    spy.executeThrowableErrorSequence = [PortalRequestsError.unauthorized, PortalRequestsError.unauthorized]
    let storage = try XCTUnwrap(self.storage)

    // and given
    let thrown = await XCTAssertThrowsAsync(
      try await storage.write(MockConstants.mockEncryptionKey),
      expected: PortalRequestsError.unauthorized
    )

    // then
    XCTAssertNil(thrown as? FirebaseStorageError)
    XCTAssertEqual(credentials.invalidateCalls, 1)
    let notified = await waitUntil { recorder.count == 1 }
    XCTAssertTrue(notified, "A 401 that survived the Firebase refresh must report the credential.")
  }

  func test_write_willThrowSessionInvalidated_whenCredentialInvalidatedBetweenAttempts() async throws {
    // given
    let session = MockPortalSession(tokenValue: "portal-tok-1")
    firebaseTokens.onCall = { call in
      guard call == 2 else {
        return
      }
      try? session.invalidate()
    }
    let spy = initFirebaseStorageWithSpy(credentials: session)
    spy.returnData = Data()
    spy.executeThrowableErrorSequence = [PortalRequestsError.unauthorized]
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(try await storage.write(MockConstants.mockEncryptionKey)) { error in
      // then
      XCTAssertEqual(error as? PortalCredentialError, PortalCredentialError.sessionInvalidated)
      XCTAssertNil(error as? FirebaseStorageError)
    }

    XCTAssertEqual(spy.executeCallsCount, 1)
  }

  func test_write_willThrowTokenUnavailable_whenRefreshReturnsNil() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "portal-tok-1")
    firebaseTokens.values = ["fb-1", nil]
    let spy = initFirebaseStorageWithSpy(credentials: credentials)
    spy.returnData = Data()
    spy.executeThrowableErrorSequence = [PortalRequestsError.unauthorized]
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(
      try await storage.write(MockConstants.mockEncryptionKey),
      expected: FirebaseStorageError.tokenUnavailable
    )

    // then
    XCTAssertEqual(spy.executeCallsCount, 1)
    XCTAssertEqual(credentials.invalidateCalls, 0)
  }

  func test_write_willWrapNon401_intoRequestFailed_withoutRetry() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "portal-tok-1")
    let spy = initFirebaseStorageWithSpy(credentials: credentials)
    let clientError = PortalRequestsError.clientError("400 - x", url: "https://backup.web.portalhq.io/v1/backup/encrypt-key")
    spy.returnData = Data()
    spy.executeThrowableErrorSequence = [clientError]
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(try await storage.write(MockConstants.mockEncryptionKey)) { error in
      // then
      guard case .requestFailed(let underlying)? = error as? FirebaseStorageError else {
        XCTFail("Expected FirebaseStorageError.requestFailed, got \(type(of: error)).")
        return
      }
      XCTAssertEqual(underlying as? PortalRequestsError, clientError)
    }

    XCTAssertEqual(spy.executeCallsCount, 1)
    XCTAssertEqual(credentials.invalidateCalls, 0)
  }
}

// MARK: - validateOperations credentials tests

extension FirebaseStorageTests {
  func test_validateOperations_willResolveToken_thenFirebaseToken() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "portal-tok-1")
    let spy = initFirebaseStorageWithSpy(credentials: credentials)
    let storage = try XCTUnwrap(self.storage)

    // and given
    let isValid = try await storage.validateOperations()

    // then
    XCTAssertTrue(isValid)
    XCTAssertEqual(credentials.getTokenCalls, 1)
    XCTAssertEqual(firebaseTokenCalls, 1)
    XCTAssertEqual(spy.executeCallsCount, 0)
  }

  func test_validateOperations_willThrowUnavailable_whenTokenBlank() async throws {
    // given
    initFirebaseStorageWithSpy(credentials: MockCredentials(tokenValue: ""))
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(try await storage.validateOperations(), expected: PortalCredentialError.unavailable)

    // then
    XCTAssertEqual(firebaseTokenCalls, 0)
  }

  func test_validateOperations_willThrowProviderFailure_whenGetTokenThrows() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "portal-tok-1")
    credentials.onGetToken = { throw FirebaseCredentialProviderError.boom }
    initFirebaseStorageWithSpy(credentials: credentials)
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(
      try await storage.validateOperations(),
      expected: PortalCredentialError.providerFailure(underlying: FirebaseCredentialProviderError.boom)
    )

    // then
    XCTAssertEqual(firebaseTokenCalls, 0)
  }

  func test_validateOperations_willThrowNoApiKey_whenCredentialsNil() async throws {
    // given
    initFirebaseStorageWithSpy(credentials: nil)
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(try await storage.validateOperations(), expected: FirebaseStorageError.noApiKey)

    // then
    XCTAssertEqual(firebaseTokenCalls, 0)
  }

  func test_validateOperations_willThrowTokenUnavailable_whenFirebaseTokenNil() async throws {
    // given
    firebaseTokens.values = [nil]
    initFirebaseStorageWithSpy(credentials: MockCredentials(tokenValue: "portal-tok-1"))
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(try await storage.validateOperations(), expected: FirebaseStorageError.tokenUnavailable)

    // then
    XCTAssertEqual(firebaseTokenCalls, 1)
  }
}

// MARK: - apiKey bridge tests

extension FirebaseStorageTests {
  func test_apiKey_set_willWrapStaticCredentials() async throws {
    // given
    let spy = initFirebaseStorageWithSpy(credentials: nil)
    let storage = try XCTUnwrap(self.storage)
    storage.apiKey = MockConstants.mockApiKey
    spy.returnData = try encodedEncryptionKeyResponse()

    // and given
    _ = try await storage.read()

    // then
    XCTAssertTrue(storage.credentials is StaticCredentials)
    XCTAssertEqual(spy.executeRequestHistory.first?.headers["Authorization"], "Bearer test-api-key")
  }

  func test_apiKey_get_willReturnEmpty_forSessionCredentials() throws {
    // given
    initFirebaseStorageWithSpy(credentials: MockCredentials(tokenValue: "portal-tok-1"))
    let storage = try XCTUnwrap(self.storage)

    // then: the bridge reports the absence of a static key rather than leaking a session token
    XCTAssertEqual(storage.apiKey, "")
  }

  func test_apiKey_set_nil_willClearCredentials() async throws {
    // given
    let spy = initFirebaseStorageWithSpy(credentials: MockCredentials(tokenValue: "portal-tok-1"))
    let storage = try XCTUnwrap(self.storage)
    storage.apiKey = nil

    // then
    XCTAssertNil(storage.credentials)
    await XCTAssertThrowsAsync(try await storage.read(), expected: FirebaseStorageError.noApiKey)
    XCTAssertEqual(spy.executeCallsCount, 0)
  }
}

// MARK: - transport hook tests

extension FirebaseStorageTests {
  func test_init_willNotInstallUnauthorizedHook_onTransport() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "portal-tok-1")
    let spy = initFirebaseStorageWithSpy(credentials: credentials)
    spy.returnData = try encodedEncryptionKeyResponse()
    let storage = try XCTUnwrap(self.storage)

    // and given
    _ = try await storage.read()

    // then: the hook would fire on the first, ambiguous 401 and kill a session a Firebase
    // refresh would have rescued, so this storage must never install one.
    XCTAssertNil(spy.onUnauthorized)
    XCTAssertEqual(spy.onUnauthorizedSetCount, 0)
  }
}

// MARK: - secret handling tests

extension FirebaseStorageTests {
  func test_read_errorDescriptions_willNotContainTokens() async throws {
    // given: the credential-provider failure path
    let failing = MockCredentials(tokenValue: "portal-tok-1")
    failing.onGetToken = { throw FirebaseCredentialProviderError.boom }
    initFirebaseStorageWithSpy(credentials: failing)
    let failingStorage = try XCTUnwrap(self.storage)

    var descriptions: [String] = []
    await XCTAssertThrowsAsync(try await failingStorage.read()) { error in
      descriptions.append(error.localizedDescription)
      descriptions.append((error as? LocalizedError)?.errorDescription ?? "")
    }

    // and given: the second-401 path
    firebaseTokens = FirebaseTokenProvider()
    let credentials = MockCredentials(tokenValue: "portal-tok-1")
    let spy = initFirebaseStorageWithSpy(credentials: credentials)
    spy.returnData = try encodedEncryptionKeyResponse()
    spy.executeThrowableErrorSequence = [PortalRequestsError.unauthorized, PortalRequestsError.unauthorized]
    let storage = try XCTUnwrap(self.storage)

    await XCTAssertThrowsAsync(try await storage.read()) { error in
      descriptions.append(error.localizedDescription)
      descriptions.append((error as? LocalizedError)?.errorDescription ?? "")
    }

    // then
    XCTAssertFalse(descriptions.isEmpty)
    for description in descriptions {
      XCTAssertFalse(description.contains("portal-tok-1"), "An error description leaked the Portal bearer: \(description)")
      XCTAssertFalse(description.contains("fb-1"), "An error description leaked the Firebase token: \(description)")
    }
  }

  func test_read_willNotLogTokens() async throws {
    // given
    let credentials = makeRotatingCredentials(token: "portal-tok-1", rotatedTo: "portal-tok-2")
    let spy = initFirebaseStorageWithSpy(credentials: credentials)
    spy.returnData = try encodedEncryptionKeyResponse()
    spy.executeThrowableErrorSequence = [PortalRequestsError.unauthorized, nil]
    let storage = try XCTUnwrap(self.storage)

    // and given
    _ = try await storage.read()

    // then: the retry path logs, and none of what it logs is a credential
    let logger = try XCTUnwrap(recordingLogger)
    XCTAssertTrue(logger.contains("FirebaseStorage.read()"), "Expected the retry to log; otherwise this assertion is vacuous.")
    logger.assertNoSecret("portal-tok-1")
    logger.assertNoSecret("portal-tok-2")
    logger.assertNoSecret("fb-1")
    logger.assertNoSecret("fb-2")
  }
}

// MARK: - public mock compatibility tests

extension FirebaseStorageTests {
  func test_mockFirebaseStorage_willStillBuild_andRegister() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "portal-tok-1")
    let api = PortalApi(credentials: credentials, requests: MockPortalRequests())
    let mpc = PortalMpc(
      credentials: credentials,
      api: api,
      keychain: MockPortalKeychain(),
      mobile: MockMobileWrapper()
    )
    let mockStorage = MockFirebaseStorage()

    // and given
    mpc.registerBackupMethod(.Firebase, withStorage: mockStorage)

    // then: registration injects the credential object itself, never a resolved token
    XCTAssertTrue(mockStorage.credentials === credentials)
    XCTAssertEqual(credentials.getTokenCalls, 0)
    let key = try await mockStorage.read()
    XCTAssertEqual(key, MockConstants.mockEncryptionKey)
  }
}
