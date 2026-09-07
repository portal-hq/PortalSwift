//
//  PasskeyStorageTests.swift
//
//
//  Created by Blake Williams on 3/31/24.
//

import AuthenticationServices
@testable import PortalSwift
import XCTest

// TODO: - To test the integration with `PasskeyAuth`, but we need to refactor some code for that to not expose more public functions.
// TODO: - To test the integration with `PortalRequests`, in order to do that we need to refactor the functions to be each function doing only one thing and to enable controlling the functions that depends on the `sessionId`

@available(iOS 16, *)
final class PasskeyStorageTests: XCTestCase {
  var storage: PasskeyStorage?

  /// The passkey ceremony double the credentials cases build the storage with, so a case can
  /// prove that a local credential failure short-circuits *before* the user is ever prompted.
  var passkeyAuth: RecordingPasskeyAuth?

  /// Captures every line the SDK logs, so the security cases can prove the bearer is never
  /// written to a log.
  var recordingLogger: RecordingLogger?

  override func setUpWithError() throws {
    // The registry's once-ever "reported" flags are process-wide; without this reset a credential
    // reported by an earlier case could silently suppress the report a later case asserts on.
    CredentialInvalidationRegistry.shared.resetForTesting()
    let logger = RecordingLogger()
    logger.install()
    recordingLogger = logger
    initPasskeyStorage()
  }

  override func tearDownWithError() throws {
    storage = nil
    passkeyAuth = nil
    recordingLogger?.uninstall()
    recordingLogger = nil
    CredentialInvalidationRegistry.shared.resetForTesting()
  }
}

// MARK: - Credentials test doubles

/// `MockPasskeyAuth` that also counts the ceremonies it was asked to start.
///
/// The credential cases need more than "no request was sent": a token that cannot be resolved must
/// stop the operation before the system passkey sheet is presented, and the only way to observe
/// that is to count `signInWith`/`signUpWith`. Lock-guarded because the storage starts ceremonies
/// from the main queue while the test asserts from its own.
@available(iOS 16, *)
final class RecordingPasskeyAuth: MockPasskeyAuth {
  private let lock = NSLock()
  private var _signInCalls = 0
  private var _signUpCalls = 0

  /// How many authentication ceremonies were started.
  var signInCalls: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._signInCalls
  }

  /// How many registration ceremonies were started.
  var signUpCalls: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._signUpCalls
  }

  /// Ceremonies of either kind, which is what the "nothing user-facing happened" cases assert on.
  var ceremonyCalls: Int {
    self.signInCalls + self.signUpCalls
  }

  override func signInWith(_ options: AuthenticationOptions, preferImmediatelyAvailableCredentials: Bool) {
    self.lock.lock()
    self._signInCalls += 1
    self.lock.unlock()
    super.signInWith(options, preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials)
  }

  override func signUpWith(_ options: RegistrationOptions) {
    self.lock.lock()
    self._signUpCalls += 1
    self.lock.unlock()
    super.signUpWith(options)
  }
}

/// A counter a preset transport hook bumps, so a case can prove the hook it installed itself is
/// the one that still runs after the storage was given a credential.
final class PasskeyCallMarker {
  private let lock = NSLock()
  private var _count = 0

  /// How many times the marker closure ran.
  var count: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._count
  }

  /// Records one invocation.
  func fire() {
    self.lock.lock()
    self._count += 1
    self.lock.unlock()
  }
}

/// The error a failing host credential provider throws, with a description that deliberately
/// carries no token so the "never leaks a secret" cases cannot pass by accident.
enum PasskeyCredentialProviderError: LocalizedError {
  case boom

  var errorDescription: String? {
    "The host credential provider failed."
  }
}

// MARK: - Test Helpers

@available(iOS 16, *)
extension PasskeyStorageTests {
  func initPasskeyStorage(
    requests: PortalRequestsProtocol? = nil
  ) {
    let portalRequests = requests ?? MockPortalRequests()
    storage = PasskeyStorage(auth: MockPasskeyAuth(), encryption: MockPortalEncryption(), requests: portalRequests)
    storage?.apiKey = MockConstants.mockApiKey
    storage?.api = PortalApi(apiKey: MockConstants.mockApiKey, requests: MockPortalRequests())
    DispatchQueue.main.async {
      self.storage?.anchor = MockAuthenticationAnchor()
    }
  }
}

// MARK: - decrypt  tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func testDecrypt() async throws {
    let expectation = XCTestExpectation(description: "PasswordStorage.write(value)")
    let mockGenerateResponse = try MockConstants.mockGenerateResponse
    let decryptResult = try await storage?.decrypt(MockConstants.mockCiphertext, withKey: MockConstants.mockEncryptionKey)
    guard let decryptedData = decryptResult?.data(using: .utf8) else {
      throw PasswordStorageError.unableToEncodeData
    }
    let generateResponse = try JSONDecoder().decode(PortalMpcGenerateResponse.self, from: decryptedData)
    XCTAssertEqual(generateResponse["ED25519"]?.id, mockGenerateResponse["ED25519"]?.id)
    XCTAssertEqual(generateResponse["SECP256K1"]?.id, mockGenerateResponse["SECP256K1"]?.id)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }
}

// MARK: - encrypt tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func testEncrypt() async throws {
    let expectation = XCTestExpectation(description: "PasswordStorage.write(value)")
    let shareData = try JSONEncoder().encode(MockConstants.mockWalletSigningShare)
    guard let shareString = String(data: shareData, encoding: .utf8) else {
      throw PasswordStorageError.unableToEncodeData
    }
    let encryptedData = try await storage?.encrypt(shareString)
    XCTAssertEqual(encryptedData, MockConstants.mockEncryptData)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }
}

// MARK: - read tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func testRead() async throws {
    let expectation = XCTestExpectation(description: "PasskeyStorage.write(value)")
    let result = try await storage?.read()
    XCTAssertEqual(result, MockConstants.mockEncryptionKey)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func test_read_willCall_executeRequest_twice() async throws {
    // given
    let portalRequestsSpy = MockPortalRequests()
    initPasskeyStorage(requests: portalRequestsSpy)

    // and given
    _ = try await storage?.read()

    let executeCallsCount = await portalRequestsSpy.executeCallsCount

    // then
    XCTAssertEqual(executeCallsCount, 2)
  }
}

// MARK: - write tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func testWrite() async throws {
    let expectation = XCTestExpectation(description: "PasskeyStorage.write(value)")
    let success = try await storage?.write(MockConstants.mockEncryptionKey) ?? false
    XCTAssertTrue(success)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func test_write_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = MockPortalRequests()
    initPasskeyStorage(requests: portalRequestsSpy)

    // and given
    _ = try await storage?.write("")

    let getCallsCount = await portalRequestsSpy.getCallsCount
    let executeCallsCount = await portalRequestsSpy.executeCallsCount

    // then
    XCTAssertEqual(executeCallsCount, 3)
    XCTAssertEqual(getCallsCount, 1)
  }
}

// MARK: - delete tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_delete_willThrowCorrectError() async throws {
    do {
      // given
      _ = try await storage?.delete()
      XCTFail("Expected error not thrown when calling PasskeyStorage.delete().")
    } catch {
      XCTAssertEqual(error as? StorageError, StorageError.mustExtendStorageClass)
    }
  }
}

// MARK: - validateOperations tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_validateOperation_willReturnTrueAlways() async throws {
    // given
    let isValid = try await storage?.validateOperations() ?? false

    // then
    XCTAssertTrue(isValid)
  }
}

// MARK: - beginLogin tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_beginLogin_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try JSONEncoder().encode(MockConstants.mockPasskeyAuthenticationOptions)
    initPasskeyStorage(requests: portalRequestsSpy)

    // and given
    _ = try await storage?.beginLogin()

    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
  }

  func test_beginLogin_willCall_executeRequest_passingCorrectUrlPathAndPayloadAndMethod() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try JSONEncoder().encode(MockConstants.mockPasskeyAuthenticationOptions)
    initPasskeyStorage(requests: portalRequestsSpy)

    // and given
    _ = try await storage?.beginLogin()

    // then
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .post)
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path(), "/passkeys/begin-login")
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.payload as? [String: String], ["relyingParty": "portalhq.io"])
  }
}

// MARK: - beginRegistration tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_beginRegistration_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try JSONEncoder().encode(MockConstants.mockPasskeyRegistrationOptions)
    initPasskeyStorage(requests: portalRequestsSpy)

    // and given
    _ = try await storage?.beginRegistration()

    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
  }

  func test_beginRegistration_willCall_executeRequest_passingCorrectUrlPathAndPayloadAndMethod() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try JSONEncoder().encode(MockConstants.mockPasskeyRegistrationOptions)
    initPasskeyStorage(requests: portalRequestsSpy)

    // and given
    _ = try await storage?.beginRegistration()

    // then
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .post)
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path(), "/passkeys/begin-registration")
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.payload as? [String: String], ["relyingParty": "portalhq.io"])
  }
}

// MARK: - getPasskeyStatus tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_getPasskeyStatus_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try JSONEncoder().encode(MockConstants.mockPasskeyStatus)
    initPasskeyStorage(requests: portalRequestsSpy)

    // and given
    _ = try await storage?.getPasskeyStatus()

    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
  }

  func test_getPasskeyStatus_willCall_exeuteRequest_passingCorrectUrlPathAndMethod() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try JSONEncoder().encode(MockConstants.mockPasskeyStatus)
    initPasskeyStorage(requests: portalRequestsSpy)

    // and given
    _ = try await storage?.getPasskeyStatus()

    // then
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .get)
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path(), "/passkeys/status")
  }
}

// MARK: - handleFinishLoginRead tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_handleFinishLoginRead_willThrowCorrectError_whenThereIsNoSessionId() async throws {
    do {
      // given
      _ = try await storage?.handleFinishLoginRead("")
      XCTFail("Expected error not thrown when calling PasskeyStorage.handleFinishLoginRead() when there is no sessionId.")
    } catch {
      // then
      XCTAssertEqual(error as? PasskeyStorageError, PasskeyStorageError.readError)
    }
  }
}

// MARK: - handleFinishLoginWrite tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_handleFinishLoginWrite_willThrowCorrectError_whenThereIsNoSessionId() async throws {
    do {
      // given
      _ = try await storage?.handleFinishLoginWrite("", withValue: "")
      XCTFail("Expected error not thrown when calling PasskeyStorage.handleFinishLoginWrite() when there is no sessionId.")
    } catch {
      // then
      XCTAssertEqual(error as? PasskeyStorageError, PasskeyStorageError.writeError)
    }
  }
}

// MARK: - handleFinishRegistration tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_handleFinishRegistration_willThrowCorrectError_whenThereIsNoSessionId() async throws {
    do {
      // given
      _ = try await storage?.handleFinishRegistration("", withPrivateKey: "")
      XCTFail("Expected error not thrown when calling PasskeyStorage.handleFinishLoginWrite() when there is no sessionId.")
    } catch {
      // then
      XCTAssertEqual(error as? PasskeyStorageError, PasskeyStorageError.writeError)
    }
  }
}

// MARK: -  tests

@available(iOS 16, *)
extension PasskeyStorageTests {}

// MARK: - Credentials test helpers

@available(iOS 16, *)
extension PasskeyStorageTests {
  /// Builds the storage every credentials case uses: the transport under test, a ceremony double
  /// that counts what it was asked to present, and `credentials` injected the way
  /// `PortalMpc.registerBackupMethod(_:withStorage:)` injects it.
  func initPasskeyStorage(requests: PortalRequestsProtocol, credentials: PortalCredentials?) {
    let auth = RecordingPasskeyAuth()
    let storage = PasskeyStorage(auth: auth, encryption: MockPortalEncryption(), requests: requests)
    // Assigning the credential is what installs the transport's 401 hook, so it happens once the
    // transport under test is already in place.
    storage.credentials = credentials
    self.passkeyAuth = auth
    self.storage = storage
    // The ceremony only starts once an anchor is present. Captured weakly so the retain-cycle
    // case can drop the storage without a queued block holding it alive.
    DispatchQueue.main.async { [weak storage] in
      storage?.anchor = MockAuthenticationAnchor()
    }
  }

  /// The body of `POST /passkeys/begin-login`.
  func encodedAuthenticationOptions() throws -> Data {
    try JSONEncoder().encode(MockConstants.mockPasskeyAuthenticationOptions)
  }

  /// The body of `POST /passkeys/begin-registration`.
  func encodedRegistrationOptions() throws -> Data {
    try JSONEncoder().encode(MockConstants.mockPasskeyRegistrationOptions)
  }

  /// The body of `POST /passkeys/finish-login/read`.
  func encodedReadResponse() throws -> Data {
    try JSONEncoder().encode(MockConstants.mockPasskeyReadResponse)
  }

  /// The body of `GET /passkeys/status` for `status`.
  func encodedStatus(_ status: PasskeyStatus) throws -> Data {
    try JSONEncoder().encode(PasskeyStatusResponse(status: status))
  }

  /// The paths of every request the transport recorded, in call order.
  func recordedPaths(_ spy: PortalRequestsSpy) -> [String] {
    spy.executeRequestHistory.map { $0.url.path() }
  }
}

// MARK: - credentials didSet tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_credentials_didSet_willInstallUnauthorizedHookOnce() throws {
    // given
    let spy = PortalRequestsSpy()
    initPasskeyStorage(requests: spy, credentials: nil)
    let storage = try XCTUnwrap(self.storage)
    XCTAssertNil(spy.onUnauthorized)

    // and given
    let credentials = MockCredentials(tokenValue: "pk-tok-1")
    storage.credentials = credentials
    storage.credentials = credentials

    // then: the first owner wins, so a second assignment must not re-install
    XCTAssertNotNil(spy.onUnauthorized)
    XCTAssertEqual(spy.onUnauthorizedSetCount, 1)
  }

  func test_credentials_didSet_willNotReplaceExistingHook() throws {
    // given
    let spy = PortalRequestsSpy()
    let marker = PasskeyCallMarker()
    spy.onUnauthorized = { marker.fire() }
    let credentials = MockCredentials(tokenValue: "pk-tok-1")

    // and given
    initPasskeyStorage(requests: spy, credentials: credentials)

    // then: the hook the host already wired is left alone
    XCTAssertEqual(spy.onUnauthorizedSetCount, 1)
    spy.onUnauthorized?()
    XCTAssertEqual(marker.count, 1)
    XCTAssertEqual(credentials.invalidateCalls, 0)
  }

  func test_credentials_didSet_willNotCrash_onNonReportingTransport() async throws {
    // given
    let spy = NonReportingPortalRequestsSpy()
    spy.returnData = try encodedStatus(.RegisteredWithCredential)
    initPasskeyStorage(requests: spy, credentials: MockCredentials(tokenValue: "pk-tok-1"))
    let storage = try XCTUnwrap(self.storage)

    // and given
    let status = try await storage.getPasskeyStatus()

    // then: a transport that cannot report 401s makes installation a silent no-op
    XCTAssertEqual(status, .RegisteredWithCredential)
    XCTAssertEqual(spy.executeCallsCount, 1)
    XCTAssertEqual(spy.bearerTokensSent.first ?? nil, "pk-tok-1")
  }

  func test_credentials_didSet_willNotInstallHook_whenSetToNil() throws {
    // given
    let spy = PortalRequestsSpy()
    initPasskeyStorage(requests: spy, credentials: nil)
    let storage = try XCTUnwrap(self.storage)

    // and given
    storage.credentials = nil

    // then
    XCTAssertNil(spy.onUnauthorized)
    XCTAssertEqual(spy.onUnauthorizedSetCount, 0)
  }

  func test_installedHook_willReportCredentialOnce() async throws {
    // given
    let spy = PortalRequestsSpy()
    let credentials = MockCredentials(tokenValue: "pk-tok-1")
    let recorder = InvalidationListenerRecorder(credentials: credentials)
    initPasskeyStorage(requests: spy, credentials: credentials)

    // and given
    spy.onUnauthorized?()
    spy.onUnauthorized?()

    // then: the host hears about the dead session exactly once, however many 401s arrive.
    // Invalidation itself is idempotent rather than guarded, so it runs per rejection.
    let notified = await waitUntil { recorder.count == 1 }
    XCTAssertTrue(notified)
    let notifiedTwice = await waitUntil(timeout: 0.3) { recorder.count > 1 }
    XCTAssertFalse(notifiedTwice, "The host must be told the session ended only once.")
    XCTAssertEqual(credentials.invalidateCalls, 2)
  }

  func test_installedHook_willNotRetainStorage() async throws {
    // given
    let spy = PortalRequestsSpy()
    let credentials = MockCredentials(tokenValue: "pk-tok-1")
    let recorder = InvalidationListenerRecorder(credentials: credentials)
    initPasskeyStorage(requests: spy, credentials: credentials)
    weak var weakStorage = self.storage

    // and given
    self.storage = nil
    self.passkeyAuth = nil

    // then: the closure captured the credential, never the storage
    let released = await waitUntil { weakStorage == nil }
    XCTAssertTrue(released, "The installed hook must not keep the storage alive.")
    spy.onUnauthorized?()
    XCTAssertEqual(credentials.invalidateCalls, 1)
    let notified = await waitUntil { recorder.count == 1 }
    XCTAssertTrue(notified)
  }
}

// MARK: - read credentials tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_read_willSendResolvedToken_onBeginLogin() async throws {
    // given
    let spy = PortalRequestsSpy()
    spy.executeReturnDataSequence = try [encodedAuthenticationOptions(), encodedReadResponse()]
    initPasskeyStorage(requests: spy, credentials: MockCredentials(tokenValue: "pk-tok-1"))
    let storage = try XCTUnwrap(self.storage)

    // and given
    let key = try await storage.read()

    // then
    XCTAssertEqual(key, MockConstants.mockEncryptionKey)
    XCTAssertEqual(spy.executeRequestHistory.first?.headers["Authorization"], "Bearer pk-tok-1")
    XCTAssertEqual(spy.executeRequestHistory.first?.url.path(), "/passkeys/begin-login")
  }

  func test_read_willSendFreshToken_onFinishLoginRead() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "pk-tok-1")
    credentials.onGetToken = { [weak credentials] in
      guard let credentials, credentials.getTokenCalls == 2 else {
        return
      }
      // `MockCredentials` reads `tokenValue` after the hook, so this rotates the second
      // resolution only -- which is the one the finish-login call must pick up.
      credentials.tokenValue = "pk-tok-2"
    }
    let spy = PortalRequestsSpy()
    spy.executeReturnDataSequence = try [encodedAuthenticationOptions(), encodedReadResponse()]
    initPasskeyStorage(requests: spy, credentials: credentials)
    let storage = try XCTUnwrap(self.storage)

    // and given
    _ = try await storage.read()

    // then
    XCTAssertEqual(credentials.getTokenCalls, 2)
    XCTAssertEqual(spy.executeRequestHistory.count, 2)
    XCTAssertEqual(spy.executeRequestHistory.last?.headers["Authorization"], "Bearer pk-tok-2")
    XCTAssertEqual(spy.executeRequestHistory.last?.url.path(), "/passkeys/finish-login/read")
  }

  func test_read_willThrowUnavailable_beforeRequest_whenTokenBlank() async throws {
    // given
    let spy = PortalRequestsSpy()
    initPasskeyStorage(requests: spy, credentials: MockCredentials(tokenValue: ""))
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(try await storage.read(), expected: PortalCredentialError.unavailable)

    // then: nothing was sent and the user was never prompted
    XCTAssertEqual(spy.executeCallsCount, 0)
    XCTAssertEqual(passkeyAuth?.ceremonyCalls, 0)
  }

  func test_read_willThrowProviderFailure_beforeRequest() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "pk-tok-1")
    credentials.onGetToken = { throw PasskeyCredentialProviderError.boom }
    let spy = PortalRequestsSpy()
    initPasskeyStorage(requests: spy, credentials: credentials)
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(
      try await storage.read(),
      expected: PortalCredentialError.providerFailure(underlying: PasskeyCredentialProviderError.boom)
    )

    // then
    XCTAssertEqual(spy.executeCallsCount, 0)
    XCTAssertEqual(passkeyAuth?.ceremonyCalls, 0)
  }

  func test_read_willThrowSessionInvalidated_beforeRequest() async throws {
    // given
    let session = MockPortalSession(tokenValue: "pk-tok-1")
    try session.invalidate()
    let spy = PortalRequestsSpy()
    initPasskeyStorage(requests: spy, credentials: session)
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(try await storage.read(), expected: PortalCredentialError.sessionInvalidated)

    // then
    XCTAssertEqual(spy.executeCallsCount, 0)
    XCTAssertEqual(passkeyAuth?.ceremonyCalls, 0)
  }

  func test_read_willThrowNoApiKey_whenCredentialsNil() async throws {
    // given
    let spy = PortalRequestsSpy()
    initPasskeyStorage(requests: spy, credentials: nil)
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(try await storage.read()) { error in
      // then: the historical error is kept so hosts matching on it keep working
      XCTAssertEqual(error as? PasskeyStorageError, PasskeyStorageError.noApiKey)
    }

    XCTAssertEqual(spy.executeCallsCount, 0)
  }
}

// MARK: - write credentials tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_write_willSendResolvedToken_onStatusBeginLoginAndFinishLoginWrite() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "pk-tok-1")
    let spy = PortalRequestsSpy()
    spy.executeReturnDataSequence = try [
      encodedStatus(.RegisteredWithCredential),
      encodedAuthenticationOptions(),
      Data()
    ]
    initPasskeyStorage(requests: spy, credentials: credentials)
    let storage = try XCTUnwrap(self.storage)

    // and given
    let didWrite = try await storage.write(MockConstants.mockEncryptionKey)

    // then
    XCTAssertTrue(didWrite)
    XCTAssertEqual(credentials.getTokenCalls, 3)
    XCTAssertEqual(spy.executeCallsCount, 3)
    XCTAssertEqual(spy.bearerTokensSent, ["pk-tok-1", "pk-tok-1", "pk-tok-1"] as [String?])
    XCTAssertEqual(recordedPaths(spy), ["/passkeys/status", "/passkeys/begin-login", "/passkeys/finish-login/write"])
  }

  func test_write_willSendResolvedToken_onBeginRegistrationAndFinishRegistration() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "pk-tok-1")
    let spy = PortalRequestsSpy()
    spy.executeReturnDataSequence = try [
      encodedStatus(.NotRegistered),
      encodedRegistrationOptions(),
      Data()
    ]
    initPasskeyStorage(requests: spy, credentials: credentials)
    let storage = try XCTUnwrap(self.storage)

    // and given
    let didWrite = try await storage.write(MockConstants.mockEncryptionKey)

    // then
    XCTAssertTrue(didWrite)
    XCTAssertEqual(recordedPaths(spy), ["/passkeys/status", "/passkeys/begin-registration", "/passkeys/finish-registration"])
    XCTAssertEqual(spy.bearerTokensSent, ["pk-tok-1", "pk-tok-1", "pk-tok-1"] as [String?])
    XCTAssertEqual(passkeyAuth?.signUpCalls, 1)
  }

  func test_write_willThrowUnavailable_beforeStatusRequest_whenTokenBlank() async throws {
    // given
    let spy = PortalRequestsSpy()
    initPasskeyStorage(requests: spy, credentials: MockCredentials(tokenValue: ""))
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(
      try await storage.write(MockConstants.mockEncryptionKey),
      expected: PortalCredentialError.unavailable
    )

    // then
    XCTAssertEqual(spy.executeCallsCount, 0)
    XCTAssertEqual(passkeyAuth?.ceremonyCalls, 0)
  }

  func test_write_willThrowProviderFailure_beforeStatusRequest() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "pk-tok-1")
    credentials.onGetToken = { throw PasskeyCredentialProviderError.boom }
    let spy = PortalRequestsSpy()
    initPasskeyStorage(requests: spy, credentials: credentials)
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(
      try await storage.write(MockConstants.mockEncryptionKey),
      expected: PortalCredentialError.providerFailure(underlying: PasskeyCredentialProviderError.boom)
    )

    // then
    XCTAssertEqual(spy.executeCallsCount, 0)
    XCTAssertEqual(passkeyAuth?.ceremonyCalls, 0)
  }
}

// MARK: - getPasskeyStatus credentials tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_getPasskeyStatus_willSendResolvedToken() async throws {
    // given
    let spy = PortalRequestsSpy()
    spy.returnData = try encodedStatus(.RegisteredWithCredential)
    initPasskeyStorage(requests: spy, credentials: MockCredentials(tokenValue: "pk-tok-1"))
    let storage = try XCTUnwrap(self.storage)

    // and given
    let status = try await storage.getPasskeyStatus()

    // then
    XCTAssertEqual(status, .RegisteredWithCredential)
    XCTAssertEqual(spy.executeRequestHistory.first?.headers["Authorization"], "Bearer pk-tok-1")
    XCTAssertEqual(spy.executeRequestHistory.first?.method, .get)
    XCTAssertEqual(spy.executeRequestHistory.first?.url.path(), "/passkeys/status")
  }

  func test_getPasskeyStatus_willThrowUnavailable_beforeRequest_whenTokenBlank() async throws {
    // given
    let spy = PortalRequestsSpy()
    initPasskeyStorage(requests: spy, credentials: MockCredentials(tokenValue: ""))
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(try await storage.getPasskeyStatus(), expected: PortalCredentialError.unavailable)

    // then
    XCTAssertEqual(spy.executeCallsCount, 0)
  }

  func test_getPasskeyStatus_willThrowNoApiKey_whenCredentialsNil() async throws {
    // given
    let spy = PortalRequestsSpy()
    initPasskeyStorage(requests: spy, credentials: nil)
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(try await storage.getPasskeyStatus()) { error in
      // then
      XCTAssertEqual(error as? PasskeyStorageError, PasskeyStorageError.noApiKey)
    }

    XCTAssertEqual(spy.executeCallsCount, 0)
  }
}

// MARK: - beginLogin credentials tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_beginLogin_willSendResolvedToken() async throws {
    // given
    let spy = PortalRequestsSpy()
    spy.returnData = try encodedAuthenticationOptions()
    initPasskeyStorage(requests: spy, credentials: MockCredentials(tokenValue: "pk-tok-1"))
    let storage = try XCTUnwrap(self.storage)

    // and given
    _ = try await storage.beginLogin()

    // then
    XCTAssertEqual(spy.executeRequestHistory.first?.headers["Authorization"], "Bearer pk-tok-1")
    XCTAssertEqual(spy.executeRequestHistory.first?.url.path(), "/passkeys/begin-login")
  }

  func test_beginLogin_willThrowUnavailable_beforeRequest_whenTokenBlank() async throws {
    // given
    let spy = PortalRequestsSpy()
    initPasskeyStorage(requests: spy, credentials: MockCredentials(tokenValue: ""))
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(try await storage.beginLogin(), expected: PortalCredentialError.unavailable)

    // then
    XCTAssertEqual(spy.executeCallsCount, 0)
  }
}

// MARK: - beginRegistration credentials tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_beginRegistration_willSendResolvedToken() async throws {
    // given
    let spy = PortalRequestsSpy()
    spy.returnData = try encodedRegistrationOptions()
    initPasskeyStorage(requests: spy, credentials: MockCredentials(tokenValue: "pk-tok-1"))
    let storage = try XCTUnwrap(self.storage)

    // and given
    _ = try await storage.beginRegistration()

    // then
    XCTAssertEqual(spy.executeRequestHistory.first?.headers["Authorization"], "Bearer pk-tok-1")
    XCTAssertEqual(spy.executeRequestHistory.first?.url.path(), "/passkeys/begin-registration")
  }

  func test_beginRegistration_willThrowUnavailable_beforeRequest_whenTokenBlank() async throws {
    // given
    let spy = PortalRequestsSpy()
    initPasskeyStorage(requests: spy, credentials: MockCredentials(tokenValue: ""))
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(try await storage.beginRegistration(), expected: PortalCredentialError.unavailable)

    // then
    XCTAssertEqual(spy.executeCallsCount, 0)
  }
}

// MARK: - handleFinishLoginRead credentials tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_handleFinishLoginRead_willSendResolvedToken() async throws {
    // given: `sessionId` is private and only a full ceremony sets it, so one `read()` seeds it
    let spy = PortalRequestsSpy()
    spy.executeReturnDataSequence = try [
      encodedAuthenticationOptions(),
      encodedReadResponse(),
      encodedReadResponse()
    ]
    initPasskeyStorage(requests: spy, credentials: MockCredentials(tokenValue: "pk-tok-1"))
    let storage = try XCTUnwrap(self.storage)
    _ = try await storage.read()

    // and given
    let key = try await storage.handleFinishLoginRead(MockConstants.mockPasskeyAssertion)

    // then
    XCTAssertEqual(key, MockConstants.mockEncryptionKey)
    XCTAssertEqual(spy.executeRequestHistory.last?.headers["Authorization"], "Bearer pk-tok-1")
    XCTAssertEqual(spy.executeRequestHistory.last?.url.path(), "/passkeys/finish-login/read")
    XCTAssertEqual(spy.executeRequestHistory.last?.payload as? [String: String], [
      "assertion": MockConstants.mockPasskeyAssertion,
      "sessionId": "test-session-id",
      "relyingParty": "portalhq.io"
    ])
  }

  func test_handleFinishLoginRead_willThrowUnavailable_beforeRequest_whenTokenBlank() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "pk-tok-1")
    let spy = PortalRequestsSpy()
    spy.executeReturnDataSequence = try [encodedAuthenticationOptions(), encodedReadResponse()]
    initPasskeyStorage(requests: spy, credentials: credentials)
    let storage = try XCTUnwrap(self.storage)
    _ = try await storage.read()
    let requestsBefore = spy.executeCallsCount
    credentials.tokenValue = ""

    // and given
    await XCTAssertThrowsAsync(
      try await storage.handleFinishLoginRead(MockConstants.mockPasskeyAssertion),
      expected: PortalCredentialError.unavailable
    )

    // then
    XCTAssertEqual(spy.executeCallsCount, requestsBefore)
  }

  func test_handleFinishLoginRead_willThrowReadError_whenNoSessionId() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "pk-tok-1")
    let spy = PortalRequestsSpy()
    initPasskeyStorage(requests: spy, credentials: credentials)
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(try await storage.handleFinishLoginRead(MockConstants.mockPasskeyAssertion)) { error in
      // then
      XCTAssertEqual(error as? PasskeyStorageError, PasskeyStorageError.readError)
    }

    // and then: local validation runs before the credential is touched at all
    XCTAssertEqual(spy.executeCallsCount, 0)
    XCTAssertEqual(credentials.getTokenCalls, 0)
  }
}

// MARK: - handleFinishLoginWrite credentials tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_handleFinishLoginWrite_willSendResolvedToken() async throws {
    // given
    let spy = PortalRequestsSpy()
    spy.executeReturnDataSequence = try [
      encodedAuthenticationOptions(),
      encodedReadResponse(),
      Data()
    ]
    initPasskeyStorage(requests: spy, credentials: MockCredentials(tokenValue: "pk-tok-1"))
    let storage = try XCTUnwrap(self.storage)
    _ = try await storage.read()

    // and given
    let didWrite = try await storage.handleFinishLoginWrite(
      MockConstants.mockPasskeyAssertion,
      withValue: MockConstants.mockEncryptionKey
    )

    // then
    XCTAssertTrue(didWrite)
    XCTAssertEqual(spy.executeRequestHistory.last?.headers["Authorization"], "Bearer pk-tok-1")
    XCTAssertEqual(spy.executeRequestHistory.last?.url.path(), "/passkeys/finish-login/write")
  }

  func test_handleFinishLoginWrite_willThrowUnavailable_beforeRequest_whenTokenBlank() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "pk-tok-1")
    let spy = PortalRequestsSpy()
    spy.executeReturnDataSequence = try [encodedAuthenticationOptions(), encodedReadResponse()]
    initPasskeyStorage(requests: spy, credentials: credentials)
    let storage = try XCTUnwrap(self.storage)
    _ = try await storage.read()
    let requestsBefore = spy.executeCallsCount
    credentials.tokenValue = ""

    // and given
    await XCTAssertThrowsAsync(
      try await storage.handleFinishLoginWrite(MockConstants.mockPasskeyAssertion, withValue: MockConstants.mockEncryptionKey),
      expected: PortalCredentialError.unavailable
    )

    // then
    XCTAssertEqual(spy.executeCallsCount, requestsBefore)
  }

  func test_handleFinishLoginWrite_willThrowWriteError_whenNoSessionId() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "pk-tok-1")
    let spy = PortalRequestsSpy()
    initPasskeyStorage(requests: spy, credentials: credentials)
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(
      try await storage.handleFinishLoginWrite(MockConstants.mockPasskeyAssertion, withValue: MockConstants.mockEncryptionKey)
    ) { error in
      // then
      XCTAssertEqual(error as? PasskeyStorageError, PasskeyStorageError.writeError)
    }

    XCTAssertEqual(spy.executeCallsCount, 0)
    XCTAssertEqual(credentials.getTokenCalls, 0)
  }
}

// MARK: - handleFinishRegistration credentials tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_handleFinishRegistration_willSendResolvedToken() async throws {
    // given
    let spy = PortalRequestsSpy()
    spy.executeReturnDataSequence = try [
      encodedAuthenticationOptions(),
      encodedReadResponse(),
      Data()
    ]
    initPasskeyStorage(requests: spy, credentials: MockCredentials(tokenValue: "pk-tok-1"))
    let storage = try XCTUnwrap(self.storage)
    _ = try await storage.read()

    // and given
    let didWrite = try await storage.handleFinishRegistration(
      MockConstants.mockPasskeyAttestation,
      withPrivateKey: MockConstants.mockEncryptionKey
    )

    // then
    XCTAssertTrue(didWrite)
    XCTAssertEqual(spy.executeRequestHistory.last?.headers["Authorization"], "Bearer pk-tok-1")
    XCTAssertEqual(spy.executeRequestHistory.last?.url.path(), "/passkeys/finish-registration")
  }

  func test_handleFinishRegistration_willThrowUnavailable_beforeRequest_whenTokenBlank() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "pk-tok-1")
    let spy = PortalRequestsSpy()
    spy.executeReturnDataSequence = try [encodedAuthenticationOptions(), encodedReadResponse()]
    initPasskeyStorage(requests: spy, credentials: credentials)
    let storage = try XCTUnwrap(self.storage)
    _ = try await storage.read()
    let requestsBefore = spy.executeCallsCount
    credentials.tokenValue = ""

    // and given
    await XCTAssertThrowsAsync(
      try await storage.handleFinishRegistration(MockConstants.mockPasskeyAttestation, withPrivateKey: MockConstants.mockEncryptionKey),
      expected: PortalCredentialError.unavailable
    )

    // then
    XCTAssertEqual(spy.executeCallsCount, requestsBefore)
  }

  func test_handleFinishRegistration_willThrowWriteError_whenNoSessionId() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "pk-tok-1")
    let spy = PortalRequestsSpy()
    initPasskeyStorage(requests: spy, credentials: credentials)
    let storage = try XCTUnwrap(self.storage)

    // and given
    await XCTAssertThrowsAsync(
      try await storage.handleFinishRegistration(MockConstants.mockPasskeyAttestation, withPrivateKey: MockConstants.mockEncryptionKey)
    ) { error in
      // then
      XCTAssertEqual(error as? PasskeyStorageError, PasskeyStorageError.writeError)
    }

    XCTAssertEqual(spy.executeCallsCount, 0)
    XCTAssertEqual(credentials.getTokenCalls, 0)
  }
}

// MARK: - apiKey bridge tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_apiKey_set_willWrapStaticCredentials_andInstallHook() async throws {
    // given
    let spy = PortalRequestsSpy()
    spy.executeReturnDataSequence = try [encodedAuthenticationOptions(), encodedReadResponse()]
    initPasskeyStorage(requests: spy, credentials: nil)
    let storage = try XCTUnwrap(self.storage)

    // and given
    storage.apiKey = MockConstants.mockApiKey

    // then
    XCTAssertTrue(storage.credentials is StaticCredentials)
    XCTAssertEqual(spy.onUnauthorizedSetCount, 1)
    _ = try await storage.read()
    XCTAssertEqual(spy.executeRequestHistory.first?.headers["Authorization"], "Bearer test-api-key")
  }

  func test_apiKey_get_willReturnEmpty_forSessionCredentials() throws {
    // given
    initPasskeyStorage(requests: PortalRequestsSpy(), credentials: MockCredentials(tokenValue: "pk-tok-1"))
    let storage = try XCTUnwrap(self.storage)

    // then: the bridge reports the absence of a static key rather than leaking a session token
    XCTAssertEqual(storage.apiKey, "")
  }

  func test_apiKey_set_nil_willClearCredentials() async throws {
    // given
    let spy = PortalRequestsSpy()
    initPasskeyStorage(requests: spy, credentials: MockCredentials(tokenValue: "pk-tok-1"))
    let storage = try XCTUnwrap(self.storage)

    // and given
    storage.apiKey = nil

    // then
    XCTAssertNil(storage.credentials)
    await XCTAssertThrowsAsync(try await storage.read()) { error in
      XCTAssertEqual(error as? PasskeyStorageError, PasskeyStorageError.noApiKey)
    }
    XCTAssertEqual(spy.executeCallsCount, 0)
  }
}

// MARK: - secret handling tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_read_errorDescription_andPayload_willNotContainToken() async throws {
    var descriptions: [String] = []

    // given: the blank-token path
    initPasskeyStorage(requests: PortalRequestsSpy(), credentials: MockCredentials(tokenValue: "   "))
    let blankStorage = try XCTUnwrap(self.storage)
    await XCTAssertThrowsAsync(try await blankStorage.read()) { error in
      descriptions.append(error.localizedDescription)
      descriptions.append((error as? LocalizedError)?.errorDescription ?? "")
    }

    // and given: the provider-failure path
    let failing = MockCredentials(tokenValue: "pk-tok-1")
    failing.onGetToken = { throw PasskeyCredentialProviderError.boom }
    initPasskeyStorage(requests: PortalRequestsSpy(), credentials: failing)
    let failingStorage = try XCTUnwrap(self.storage)
    await XCTAssertThrowsAsync(try await failingStorage.read()) { error in
      descriptions.append(error.localizedDescription)
      descriptions.append((error as? LocalizedError)?.errorDescription ?? "")
    }

    // and given: a successful read, whose requests must carry the token only as a bearer
    let spy = PortalRequestsSpy()
    spy.executeReturnDataSequence = try [encodedAuthenticationOptions(), encodedReadResponse()]
    initPasskeyStorage(requests: spy, credentials: MockCredentials(tokenValue: "pk-tok-1"))
    let storage = try XCTUnwrap(self.storage)
    _ = try await storage.read()

    // then
    XCTAssertFalse(descriptions.isEmpty)
    for description in descriptions {
      XCTAssertFalse(description.contains("pk-tok-1"), "An error description leaked the bearer: \(description)")
    }
    XCTAssertEqual(spy.executeRequestHistory.count, 2)
    for request in spy.executeRequestHistory {
      XCTAssertFalse(request.url.absoluteString.contains("pk-tok-1"), "The token must never reach the URL.")
      let payload = request.payload as? [String: String] ?? [:]
      for (key, value) in payload {
        XCTAssertNotEqual(value, "pk-tok-1", "The token must never be sent in the payload (key: \(key)).")
      }
    }
  }

  func test_passkeyStorage_willNotLogToken() async throws {
    // given
    let spy = PortalRequestsSpy()
    spy.executeReturnDataSequence = try [encodedAuthenticationOptions(), encodedReadResponse()]
    initPasskeyStorage(requests: spy, credentials: MockCredentials(tokenValue: "pk-tok-1"))
    let logger = try XCTUnwrap(recordingLogger)
    logger.reset()

    // and given: no strong local reference, so the storage can be released below
    _ = try await self.storage?.read()
    self.storage = nil
    self.passkeyAuth = nil

    // then: the sink is proven live by the deinit line, and nothing it saw was the bearer
    let logged = await waitUntil { logger.contains("PasskeyStorage is being deallocated") }
    XCTAssertTrue(logged, "Expected the storage to log on deallocation; otherwise this is vacuous.")
    logger.assertNoSecret("pk-tok-1")
  }
}

// MARK: - public mock compatibility tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_mockPasskeyStorage_willStillBuild_andAcceptCredentials() async throws {
    // given
    let mockStorage = MockPasskeyStorage()
    let credentials = MockCredentials(tokenValue: "pk-tok-1")

    // and given
    mockStorage.credentials = credentials

    // then
    XCTAssertTrue(mockStorage.credentials === credentials)
    let key = try await mockStorage.read()
    XCTAssertEqual(key, MockConstants.mockEncryptionKey)
  }
}
