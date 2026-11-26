//
//  PasskeyPrfStorageTests.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import AuthenticationServices
import CryptoKit
@testable import PortalSwift
import XCTest

// MARK: - Fixtures

enum PasskeyPrfFixtures {
  static let createdOutput = Data(repeating: 0xAB, count: 32)
  static let assertedOutput = Data((0 ..< 32).map { UInt8($0) })
  static let createdCredentialId = Data([0x01, 0x02, 0x03, 0xFB, 0xFF])
  static let serverCredentialId = Data([0x09, 0x08, 0x07])
}

// MARK: - Doubles

/// Records the ceremonies `PasskeyPrfStorage` asks for and answers them from queued results.
final class PasskeyPrfWebAuthnClientFake: PasskeyPrfWebAuthnClient {
  var anchor: ASPresentationAnchor?

  var createRequests: [PasskeyPrfCreateRequest] = []
  var createResults: [Swift.Result<PasskeyPrfCreateResult, Error>] = []
  var getRequests: [PasskeyPrfGetRequest] = []
  var getResults: [Swift.Result<PasskeyPrfGetResult, Error>] = []

  func createCredential(_ request: PasskeyPrfCreateRequest) async throws -> PasskeyPrfCreateResult {
    createRequests.append(request)
    return try createResults.removeFirst().get()
  }

  func getCredential(_ request: PasskeyPrfGetRequest) async throws -> PasskeyPrfGetResult {
    getRequests.append(request)
    guard !getResults.isEmpty else {
      // Answer with the requested credential by default.
      return PasskeyPrfGetResult(credentialId: request.allowCredentialId, prfOutput: PasskeyPrfFixtures.assertedOutput)
    }
    return try getResults.removeFirst().get()
  }
}

/// A WebAuthn client whose assertion stays "on screen", like the system prompt, until the calling
/// task is cancelled or the test answers it.
final class PasskeyPrfPendingPromptClient: PasskeyPrfWebAuthnClient, @unchecked Sendable {
  var anchor: ASPresentationAnchor?

  /// Fulfilled when the prompt is up.
  let shown = XCTestExpectation(description: "The passkey prompt is shown")
  /// Fulfilled when cancelling the calling task reaches the prompt.
  let cancelled = XCTestExpectation(description: "Task cancellation reached the passkey prompt")

  private let lock = NSLock()
  private var isCancelled = false
  private var isAnswered = false
  private var pending: CheckedContinuation<Void, Never>?

  func createCredential(_: PasskeyPrfCreateRequest) async throws -> PasskeyPrfCreateResult {
    throw PasskeyPrfCeremonyError.failed(nil)
  }

  func getCredential(_ request: PasskeyPrfGetRequest) async throws -> PasskeyPrfGetResult {
    shown.fulfill()
    await withTaskCancellationHandler {
      await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        self.lock.lock()
        let isDone = self.isCancelled || self.isAnswered
        if !isDone {
          self.pending = continuation
        }
        self.lock.unlock()
        if isDone {
          continuation.resume()
        }
      }
    } onCancel: {
      self.lock.lock()
      self.isCancelled = true
      let continuation = self.pending
      self.pending = nil
      self.lock.unlock()
      self.cancelled.fulfill()
      continuation?.resume()
    }

    if lock.withLock({ isCancelled }) {
      throw CancellationError()
    }
    return PasskeyPrfGetResult(credentialId: request.allowCredentialId, prfOutput: PasskeyPrfFixtures.assertedOutput)
  }

  /// The "user" answers the prompt. Does nothing once the prompt was cancelled.
  func answer() {
    lock.lock()
    isAnswered = true
    let continuation = pending
    pending = nil
    lock.unlock()
    continuation?.resume()
  }
}

/// Stands in for `ASAuthorizationController`: records what a ceremony asks of it, and keeps the
/// delegate weakly, as the system's controller does, so a test can report an outcome to it.
final class PasskeyPrfControllerFake: PasskeyPrfAuthorizationControlling {
  weak var delegate: PasskeyPrfAuthorizationDelegate?
  var performRequestsCallsCount = 0
  var cancelCallsCount = 0
  let performed = XCTestExpectation(description: "The ceremony started the prompt")

  func performRequests() {
    performRequestsCallsCount += 1
    performed.fulfill()
  }

  func cancel() {
    cancelCallsCount += 1
  }
}

/// Waits for `task` for at most `timeout` seconds and returns its result, or `nil` if it never
/// finished. A continuation nobody resumes then fails the test instead of hanging the run.
func passkeyPrfResult<T>(of task: Task<T, Error>, timeout: TimeInterval = 5) async -> Swift.Result<T, Error>? {
  let box = PasskeyPrfResultBox<T>()
  let finished = XCTestExpectation(description: "The task finished")
  Task {
    box.set(await task.result)
    finished.fulfill()
  }
  guard await XCTWaiter().fulfillment(of: [finished], timeout: timeout) == .completed else {
    return nil
  }
  return box.get()
}

/// Holds a task's result between the task that awaits it and the test that reads it.
final class PasskeyPrfResultBox<T>: @unchecked Sendable {
  private let lock = NSLock()
  private var result: Swift.Result<T, Error>?

  func set(_ result: Swift.Result<T, Error>) {
    lock.withLock { self.result = result }
  }

  func get() -> Swift.Result<T, Error>? {
    lock.withLock { result }
  }
}

/// Fails unless `task` ends with `CancellationError` within the timeout.
func assertPasskeyPrfCancelled<T>(_ task: Task<T, Error>, file: StaticString = #filePath, line: UInt = #line) async {
  switch await passkeyPrfResult(of: task) {
  case .none:
    XCTFail("The task did not finish", file: file, line: line)
  case .success:
    XCTFail("Expected CancellationError", file: file, line: line)
  case let .failure(error) where error is CancellationError:
    break
  case let .failure(error):
    XCTFail("Expected CancellationError, got \(error)", file: file, line: line)
  }
}

/// Holds a call until the test opens it, and tells the test when a call got there.
final class PasskeyPrfGate: @unchecked Sendable {
  let reached: XCTestExpectation = {
    let expectation = XCTestExpectation(description: "A call reached the gate")
    expectation.assertForOverFulfill = false
    return expectation
  }()

  private let lock = NSLock()
  private var isOpen = false
  private var waiting: CheckedContinuation<Void, Never>?

  func wait() async {
    reached.fulfill()
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      let resumeNow: Bool = lock.withLock {
        if isOpen {
          return true
        }
        waiting = continuation
        return false
      }
      if resumeNow {
        continuation.resume()
      }
    }
  }

  func open() {
    let continuation: CheckedContinuation<Void, Never>? = lock.withLock {
      isOpen = true
      let continuation = waiting
      waiting = nil
      return continuation
    }
    continuation?.resume()
  }
}

/// A password cipher that records how it was keyed and can fail decryption like the binary.
final class PasskeyPrfEncryptionFake: PortalEncryptionProtocol {
  var encryptWithPasswordParams: [(value: String, password: String)] = []
  var decryptWithPasswordParams: [(value: String, password: String)] = []
  var decryptWithPasswordError: Error?
  var decryptWithPasswordResult = "plaintext"
  var privateKeyCallsCount = 0

  func decrypt(_: String, withPrivateKey _: String) async throws -> String {
    privateKeyCallsCount += 1
    return ""
  }

  func decrypt(_ value: String, withPassword: String) async throws -> String {
    decryptWithPasswordParams.append((value, withPassword))
    if let error = decryptWithPasswordError {
      throw error
    }
    return decryptWithPasswordResult
  }

  func encrypt(_: String) async throws -> EncryptData {
    privateKeyCallsCount += 1
    return EncryptData(key: "random-key", cipherText: "random-cipher-text")
  }

  func encrypt(_ value: String, withPassword: String) async throws -> String {
    encryptWithPasswordParams.append((value, withPassword))
    return "password-cipher-text"
  }
}

// MARK: - Tests

@available(iOS 18.4, *)
final class PasskeyPrfStorageTests: XCTestCase {
  static let createdOutput = PasskeyPrfFixtures.createdOutput
  static let assertedOutput = PasskeyPrfFixtures.assertedOutput
  static let createdCredentialId = PasskeyPrfFixtures.createdCredentialId
  static let serverCredentialId = PasskeyPrfFixtures.serverCredentialId

  var api: PortalApiMock!
  var client: PasskeyPrfWebAuthnClientFake!
  var encryption: PasskeyPrfEncryptionFake!
  var storage: PasskeyPrfStorage!
  /// The store retry waits the storage asked for, in milliseconds. Tests never wait for real.
  var sleeps: [UInt64] = []

  override func setUpWithError() throws {
    api = PortalApiMock(client: ClientResponse.stub(custodian: .stub(name: "Acme")))
    client = PasskeyPrfWebAuthnClientFake()
    encryption = PasskeyPrfEncryptionFake()
    sleeps = []
    storage = makeStorage()
  }

  override func tearDownWithError() throws {
    storage = nil
    client = nil
    encryption = nil
    api = nil
  }

  private func makeStorage(
    relyingParty: String? = nil,
    relyingPartyName: String? = nil,
    user: PasskeyPrfUser? = nil,
    isPlatformSupported: Bool = true
  ) -> PasskeyPrfStorage {
    let storage = PasskeyPrfStorage(
      relyingParty: relyingParty,
      relyingPartyName: relyingPartyName,
      user: user,
      encryption: encryption,
      webAuthnClient: client,
      isPlatformSupported: { isPlatformSupported },
      sleep: { [weak self] milliseconds in self?.sleeps.append(milliseconds) }
    )
    storage.api = api
    return storage
  }

  private func record(_ id: Data, rpId: String = "portalhq.io", transports: [String]? = nil) -> PasskeyPrfCredential {
    PasskeyPrfCredential(credentialId: PasskeyPrfEncoding.base64Url(id), rpId: rpId, transports: transports)
  }

  private func queueCreation(prfEnabled: Bool = true, prfOutput: Data? = PasskeyPrfStorageTests.createdOutput) {
    client.createResults.append(.success(PasskeyPrfCreateResult(
      credentialId: Self.createdCredentialId,
      transports: nil,
      prfEnabled: prfEnabled,
      prfOutput: prfOutput
    )))
  }

  private func assertPasskeyPrfError(
    _ reason: PortalPasskeyPrfError.Reason,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ body: () async throws -> some Any
  ) async {
    do {
      _ = try await body()
      XCTFail("Expected \(reason.rawValue)", file: file, line: line)
    } catch let error as PortalPasskeyPrfError {
      XCTAssertEqual(error.reason, reason, file: file, line: line)
    } catch {
      XCTFail("Expected PortalPasskeyPrfError, got \(error)", file: file, line: line)
    }
  }

  // MARK: - Contract constants

  func test_salt_isSha256OfPortalLabel() {
    let expected = Data(SHA256.hash(data: Data("portal.backup.prf.v1".utf8)))
    XCTAssertEqual(PasskeyPrfConstants.salt, expected)
    XCTAssertEqual(PasskeyPrfConstants.saltHex, "e8cdf823f6ba01756590c8a09d9da3777b2ade5e40129a2f8ad8097d2945ce0f")
    XCTAssertEqual(PasskeyPrfConstants.salt.count, 32)
  }

  func test_backupMethod_wireValue() {
    XCTAssertEqual(BackupMethods.PasskeyPrf.rawValue, "PASSKEY_PRF")
  }

  func test_errorReasons_matchTheOtherSdks() {
    XCTAssertEqual(
      PortalPasskeyPrfError.Reason.allCases.map(\.rawValue),
      [
        "PRF_CEREMONY_FAILED",
        "PRF_USER_CANCELLED",
        "PRF_PASSKEY_UNAVAILABLE",
        "PRF_CREDENTIAL_NOT_FOUND",
        "PRF_DECRYPT_FAILED",
        "PRF_NOT_SUPPORTED",
        "PRF_RP_ID_MISMATCH"
      ]
    )
    XCTAssertTrue(PortalPasskeyPrfError(.userCancelled).isUserCancelled)
    XCTAssertEqual(
      PortalPasskeyPrfError(.rpIdMismatch, context: "ctx").errorDescription,
      "[Portal] The passkey was enrolled under a different relying party. ctx"
    )
    XCTAssertEqual(
      PortalPasskeyPrfError(.decryptFailed).errorDescription,
      "[Portal] The backup could not be decrypted with the secret from this passkey (wrong passkey or wrong ciphertext)."
    )
  }

  func test_storeRetryDelays_matchTheOtherSdks() {
    XCTAssertEqual(PasskeyPrfConstants.storeRetryDelaysMs, [250, 1000])
    XCTAssertEqual(PasskeyPrfStorage.storeAttempts, 3)
  }

  /// 18.4, not 18.0: before it a passkey used from another device returned a different PRF
  /// output than the same passkey used on the device.
  func test_minimumIOSVersion_is18_4() {
    let minimum = PasskeyPrfConstants.minimumIOSVersion
    XCTAssertEqual([minimum.majorVersion, minimum.minorVersion, minimum.patchVersion], [18, 4, 0])
  }

  func test_relyingParty_isTrimmedAndLowercased_withDefaults() {
    XCTAssertEqual(makeStorage(relyingParty: "  Example.COM \n").relyingParty, "example.com")
    XCTAssertEqual(makeStorage(relyingParty: "   ").relyingParty, "portalhq.io")
    XCTAssertEqual(makeStorage().relyingParty, "portalhq.io")
    XCTAssertEqual(makeStorage().relyingPartyName, "Portal")
  }

  func test_encoding_hexIsLowercase_andBase64UrlIsCanonical() {
    XCTAssertEqual(PasskeyPrfEncoding.hex([0x00, 0xAB, 0xFF]), "00abff")
    XCTAssertEqual(PasskeyPrfEncoding.base64Url(Data([0xFB, 0xFF])), "-_8")
    XCTAssertEqual(PasskeyPrfEncoding.data(fromBase64Url: "-_8"), Data([0xFB, 0xFF]))
    XCTAssertNil(PasskeyPrfEncoding.data(fromBase64Url: "-_8="))
    XCTAssertNil(PasskeyPrfEncoding.data(fromBase64Url: "+/8"))
    XCTAssertNil(PasskeyPrfEncoding.data(fromBase64Url: ""))
    // Non-canonical trailing bits alias another ID.
    XCTAssertNil(PasskeyPrfEncoding.data(fromBase64Url: "-_9"))
  }

  // MARK: - enroll() with an existing record

  func test_enroll_withExistingRecord_assertsWithIt_andReturnsHexOfPrfOutput() async throws {
    let existing = record(Self.serverCredentialId)
    api.getPasskeyPrfCredentialResults = [.success(existing)]

    let secret = try await storage.enroll()

    XCTAssertEqual(secret, PasskeyPrfEncoding.hex(Self.assertedOutput))
    XCTAssertEqual(secret.count, 64)
    XCTAssertEqual(client.createRequests.count, 0)
    XCTAssertEqual(api.storePasskeyPrfCredentialParams.count, 0)
    XCTAssertEqual(client.getRequests.count, 1)
    XCTAssertEqual(client.getRequests.first?.allowCredentialId, Self.serverCredentialId)
    XCTAssertEqual(client.getRequests.first?.rpId, "portalhq.io")
    XCTAssertEqual(client.getRequests.first?.prfSalt, PasskeyPrfConstants.salt)
    XCTAssertEqual(client.getRequests.first?.challenge.count, 32)
  }

  func test_enroll_withExistingRecord_whenAnotherPasskeyAnswers_throwsPasskeyUnavailable() async {
    // A re-backup must fail rather than encrypt with the wrong passkey.
    api.getPasskeyPrfCredentialResults = [.success(record(Self.serverCredentialId))]
    client.getResults = [.success(PasskeyPrfGetResult(credentialId: Data([0xEE]), prfOutput: Self.assertedOutput))]

    await assertPasskeyPrfError(.passkeyUnavailable) { try await self.storage.enroll() }
    XCTAssertTrue(client.createRequests.isEmpty)
    XCTAssertTrue(encryption.encryptWithPasswordParams.isEmpty)
  }

  func test_enroll_withExistingRecordUnderAnotherRelyingParty_throwsRpIdMismatch_withoutACeremony() async {
    api.getPasskeyPrfCredentialResults = [.success(record(Self.serverCredentialId, rpId: "other.example"))]

    await assertPasskeyPrfError(.rpIdMismatch) { try await self.storage.enroll() }
    XCTAssertTrue(client.getRequests.isEmpty)
    XCTAssertTrue(client.createRequests.isEmpty)
  }

  // MARK: - enroll() without a record

  func test_enroll_withoutRecord_createsPasskey_storesRecord_andReusesCreationOutput() async throws {
    queueCreation()

    let secret = try await storage.enroll()

    XCTAssertEqual(secret, PasskeyPrfEncoding.hex(Self.createdOutput))
    XCTAssertEqual(client.createRequests.count, 1)
    let request = try XCTUnwrap(client.createRequests.first)
    XCTAssertEqual(request.rpId, "portalhq.io")
    XCTAssertEqual(request.userName, "Acme Backup (PRF)")
    XCTAssertEqual(request.userDisplayName, "Acme Backup (PRF)")
    XCTAssertEqual(request.prfSalt, PasskeyPrfConstants.salt)
    XCTAssertEqual(request.userId.count, 32)
    XCTAssertEqual(request.challenge.count, 32)
    XCTAssertEqual(api.storePasskeyPrfCredentialParams, [
      PasskeyPrfCredential(credentialId: "AQID-_8", rpId: "portalhq.io", transports: nil)
    ])
    // No second prompt when creation returned the output.
    XCTAssertEqual(client.getRequests.count, 0)
  }

  func test_enroll_userName_fallsBackToRelyingPartyName_whenCustodianHasNoName() async throws {
    api.client = ClientResponse.stub(custodian: .stub(name: ""))
    storage = makeStorage(relyingPartyName: "Wallet Co")
    queueCreation()

    _ = try await storage.enroll()

    XCTAssertEqual(client.createRequests.first?.userName, "Wallet Co Backup (PRF)")
  }

  func test_enroll_usesConfiguredUser() async throws {
    storage = makeStorage(user: PasskeyPrfUser(name: "alice", displayName: "Alice"))
    queueCreation()

    _ = try await storage.enroll()

    XCTAssertEqual(client.createRequests.first?.userName, "alice")
    XCTAssertEqual(client.createRequests.first?.userDisplayName, "Alice")
  }

  func test_enroll_createsUnderConfiguredRelyingParty() async throws {
    storage = makeStorage(relyingParty: "Wallet.Example")
    queueCreation()

    _ = try await storage.enroll()

    XCTAssertEqual(client.createRequests.first?.rpId, "wallet.example")
    XCTAssertEqual(api.storePasskeyPrfCredentialParams.first?.rpId, "wallet.example")
  }

  func test_enroll_whenCreationEnablesPrfWithoutOutput_assertsWithTheNewCredential() async throws {
    queueCreation(prfEnabled: true, prfOutput: nil)

    let secret = try await storage.enroll()

    XCTAssertEqual(client.getRequests.count, 1)
    XCTAssertEqual(client.getRequests.first?.allowCredentialId, Self.createdCredentialId)
    XCTAssertEqual(secret, PasskeyPrfEncoding.hex(Self.assertedOutput))
  }

  func test_enroll_whenAnotherPasskeyAnswersTheAssertionAfterCreation_throwsPasskeyUnavailable_beforeStoring() async {
    queueCreation(prfEnabled: true, prfOutput: nil)
    client.getResults = [.success(PasskeyPrfGetResult(credentialId: Self.serverCredentialId, prfOutput: Self.assertedOutput))]

    await assertPasskeyPrfError(.passkeyUnavailable) { try await self.storage.enroll() }
    XCTAssertTrue(api.storePasskeyPrfCredentialParams.isEmpty)
  }

  func test_enroll_whenCreationReportsNoPrf_throwsNotSupported_beforeStoring() async {
    queueCreation(prfEnabled: false, prfOutput: nil)

    await assertPasskeyPrfError(.notSupported) { try await self.storage.enroll() }
    XCTAssertTrue(api.storePasskeyPrfCredentialParams.isEmpty)
  }

  func test_enroll_whenCreationOutputIsNot32Bytes_throwsNotSupported() async {
    queueCreation(prfOutput: Data(repeating: 1, count: 16))

    await assertPasskeyPrfError(.notSupported) { try await self.storage.enroll() }
  }

  func test_enroll_on409_discardsCreationOutput_andReadsTheWinningRecord() async throws {
    queueCreation()
    api.storePasskeyPrfCredentialResults = [.failure(PortalRequestsError.clientError("409 - conflict", url: "u"))]
    api.getPasskeyPrfCredentialResults = [.success(nil), .success(record(Self.serverCredentialId))]

    let secret = try await storage.enroll()

    XCTAssertEqual(secret, PasskeyPrfEncoding.hex(Self.assertedOutput))
    XCTAssertNotEqual(secret, PasskeyPrfEncoding.hex(Self.createdOutput))
    XCTAssertEqual(client.getRequests.map(\.allowCredentialId), [Self.serverCredentialId])
    XCTAssertEqual(api.storePasskeyPrfCredentialParams.count, 1)
  }

  func test_enroll_on409_withNoRecordToRead_throwsCredentialNotFound() async {
    queueCreation()
    api.storePasskeyPrfCredentialResults = [.failure(PortalRequestsError.clientError("409 - conflict", url: "u"))]

    await assertPasskeyPrfError(.credentialNotFound) { try await self.storage.enroll() }
  }

  func test_enroll_whenServerReturnsAnotherCredential_assertsWithTheServersOne() async throws {
    queueCreation()
    api.storePasskeyPrfCredentialResults = [.success(record(Self.serverCredentialId))]

    let secret = try await storage.enroll()

    XCTAssertEqual(client.getRequests.map(\.allowCredentialId), [Self.serverCredentialId])
    XCTAssertEqual(secret, PasskeyPrfEncoding.hex(Self.assertedOutput))
  }

  func test_enroll_whenServerReturnsAnotherRelyingParty_throwsRpIdMismatch() async {
    queueCreation()
    api.storePasskeyPrfCredentialResults = [.success(record(Self.createdCredentialId, rpId: "other.example"))]

    await assertPasskeyPrfError(.rpIdMismatch) { try await self.storage.enroll() }
  }

  // MARK: - enroll() store retries

  func test_enroll_retriesTransientStoreFailures_upToThreeTimes() async throws {
    queueCreation()
    api.storePasskeyPrfCredentialResults = [
      .failure(PortalRequestsError.internalServerError("503 - unavailable", url: "u")),
      .failure(PortalRequestsError.clientError("429 - slow down", url: "u")),
      .success(record(Self.createdCredentialId))
    ]

    let secret = try await storage.enroll()

    XCTAssertEqual(api.storePasskeyPrfCredentialParams.count, 3)
    XCTAssertEqual(secret, PasskeyPrfEncoding.hex(Self.createdOutput))
    XCTAssertEqual(sleeps, [250, 1000])
    XCTAssertEqual(client.createRequests.count, 1)
  }

  func test_enroll_retriesNetworkFailures() async throws {
    queueCreation()
    api.storePasskeyPrfCredentialResults = [.failure(URLError(.networkConnectionLost)), .success(record(Self.createdCredentialId))]

    _ = try await storage.enroll()

    XCTAssertEqual(api.storePasskeyPrfCredentialParams.count, 2)
    XCTAssertEqual(sleeps, [250])
  }

  func test_enroll_whenEveryStoreAttemptFails_readsOnceAndUsesARecordThatLanded() async throws {
    queueCreation()
    let failure = PortalRequestsError.internalServerError("500 - boom", url: "u")
    api.storePasskeyPrfCredentialResults = [.failure(failure), .failure(failure), .failure(failure)]
    api.getPasskeyPrfCredentialResults = [.success(nil), .success(record(Self.createdCredentialId))]

    let secret = try await storage.enroll()

    XCTAssertEqual(api.storePasskeyPrfCredentialParams.count, 3)
    XCTAssertEqual(api.getPasskeyPrfCredentialCallsCount, 2)
    XCTAssertEqual(secret, PasskeyPrfEncoding.hex(Self.createdOutput))
    XCTAssertTrue(client.getRequests.isEmpty)
  }

  func test_enroll_withATraceId_sendsItOnEveryCall_includingRetriesAndTheReadBack() async throws {
    queueCreation()
    let failure = PortalRequestsError.internalServerError("500 - boom", url: "u")
    api.storePasskeyPrfCredentialResults = [.failure(failure), .failure(failure), .failure(failure)]
    api.getPasskeyPrfCredentialResults = [.success(nil), .success(record(Self.createdCredentialId))]

    _ = try await storage.enroll(traceId: "trace-backup")

    XCTAssertEqual(api.getPasskeyPrfCredentialTraceIds, ["trace-backup", "trace-backup"])
    XCTAssertEqual(api.storePasskeyPrfCredentialTraceIds, ["trace-backup", "trace-backup", "trace-backup"])
  }

  func test_enroll_on409_readsTheWinningRecord_withTheSameTraceId() async throws {
    queueCreation()
    api.storePasskeyPrfCredentialResults = [.failure(PortalRequestsError.clientError("409 - conflict", url: "u"))]
    api.getPasskeyPrfCredentialResults = [.success(nil), .success(record(Self.serverCredentialId))]

    _ = try await storage.enroll(traceId: "trace-backup")

    XCTAssertEqual(api.getPasskeyPrfCredentialTraceIds, ["trace-backup", "trace-backup"])
    XCTAssertEqual(api.storePasskeyPrfCredentialTraceIds, ["trace-backup"])
  }

  func test_enroll_withoutATraceId_givesAllItsCallsOneGeneratedTraceId() async throws {
    queueCreation()

    _ = try await storage.enroll()

    let traceIds = api.getPasskeyPrfCredentialTraceIds + api.storePasskeyPrfCredentialTraceIds
    XCTAssertEqual(traceIds.count, 2)
    XCTAssertNotNil(traceIds.first ?? nil)
    XCTAssertEqual(Set(traceIds).count, 1)
  }

  func test_read_withATraceId_sendsIt() async throws {
    api.getPasskeyPrfCredentialResults = [.success(record(Self.serverCredentialId))]

    _ = try await storage.read(traceId: "trace-recover")

    XCTAssertEqual(api.getPasskeyPrfCredentialTraceIds, ["trace-recover"])
  }

  func test_enroll_whenEveryStoreAttemptFails_andNothingLanded_throwsTheLastError() async {
    queueCreation()
    let failure = PortalRequestsError.internalServerError("500 - boom", url: "u")
    api.storePasskeyPrfCredentialResults = [.failure(failure), .failure(failure), .failure(failure)]

    do {
      _ = try await storage.enroll()
      XCTFail("Expected the store failure")
    } catch {
      XCTAssertEqual(error as? PortalRequestsError, failure)
    }
    XCTAssertEqual(api.storePasskeyPrfCredentialParams.count, 3)
    XCTAssertEqual(api.getPasskeyPrfCredentialCallsCount, 2)
    XCTAssertEqual(sleeps, [250, 1000])
  }

  func test_enroll_whenCancelledWhileStoringTheRecord_stillStoresIt_includingRetries_thenStops() async {
    queueCreation()
    var retryWaitSawCancellation: [Bool] = []
    storage = PasskeyPrfStorage(
      encryption: encryption,
      webAuthnClient: client,
      isPlatformSupported: { true },
      sleep: { _ in retryWaitSawCancellation.append(Task.isCancelled) }
    )
    storage.api = api
    let gate = PasskeyPrfGate()
    api.storePasskeyPrfCredentialHook = { await gate.wait() }
    // The first attempt fails transiently, so the store also has to wait and retry.
    api.storePasskeyPrfCredentialResults = [.failure(PortalRequestsError.internalServerError("503 - unavailable", url: "u"))]

    let storage = self.storage!
    let task = Task { try await storage.enroll() }
    await fulfillment(of: [gate.reached], timeout: 5)
    task.cancel()
    gate.open()

    // The passkey is bound before the backup stops, so the next backup reuses it.
    await assertPasskeyPrfCancelled(task)
    XCTAssertEqual(client.createRequests.count, 1)
    XCTAssertEqual(api.storePasskeyPrfCredentialParams.count, 2)
    XCTAssertEqual(api.storePasskeyPrfCredentialSawCancellation, [false, false])
    XCTAssertEqual(retryWaitSawCancellation, [false])
  }

  func test_enroll_doesNotRetryOtherClientErrors() async {
    queueCreation()
    let failure = PortalRequestsError.clientError("400 - bad request", url: "u")
    api.storePasskeyPrfCredentialResults = [.failure(failure)]

    do {
      _ = try await storage.enroll()
      XCTFail("Expected the store failure")
    } catch {
      XCTAssertEqual(error as? PortalRequestsError, failure)
    }
    XCTAssertEqual(api.storePasskeyPrfCredentialParams.count, 1)
    XCTAssertEqual(sleeps, [])
  }

  func test_enroll_doesNotRetryAnUnauthorizedOrInvalidatedSession() async {
    for failure: Error in [PortalRequestsError.unauthorized, PortalCredentialError.sessionInvalidated] {
      try? setUpWithError()
      queueCreation()
      api.storePasskeyPrfCredentialResults = [.failure(failure)]

      do {
        _ = try await storage.enroll()
        XCTFail("Expected the store failure")
      } catch {}
      XCTAssertEqual(api.storePasskeyPrfCredentialParams.count, 1, "\(failure)")
    }
  }

  func test_isTransient() {
    XCTAssertTrue(PasskeyPrfStorage.isTransient(PortalRequestsError.internalServerError("500 - x", url: "")))
    XCTAssertTrue(PasskeyPrfStorage.isTransient(PortalRequestsError.clientError("429 - x", url: "")))
    XCTAssertTrue(PasskeyPrfStorage.isTransient(URLError(.timedOut)))
    XCTAssertFalse(PasskeyPrfStorage.isTransient(PortalRequestsError.clientError("409 - x", url: "")))
    XCTAssertFalse(PasskeyPrfStorage.isTransient(PortalRequestsError.clientError("404 - x", url: "")))
    XCTAssertFalse(PasskeyPrfStorage.isTransient(PortalRequestsError.unauthorized))
    XCTAssertFalse(PasskeyPrfStorage.isTransient(PortalCredentialError.unavailable))
  }

  // MARK: - read()

  func test_read_withoutRecord_throwsCredentialNotFound_andNeverCreatesAPasskey() async {
    await assertPasskeyPrfError(.credentialNotFound) { try await self.storage.read() }
    XCTAssertTrue(client.createRequests.isEmpty)
    XCTAssertTrue(client.getRequests.isEmpty)
  }

  func test_read_withRecord_returnsTheSecret() async throws {
    api.getPasskeyPrfCredentialResults = [.success(record(Self.serverCredentialId))]

    let secret = try await storage.read()

    XCTAssertEqual(secret, "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")
    XCTAssertTrue(client.createRequests.isEmpty)
  }

  func test_read_withRecordUnderAnotherRelyingParty_throwsRpIdMismatch() async {
    api.getPasskeyPrfCredentialResults = [.success(record(Self.serverCredentialId, rpId: "other.example"))]

    await assertPasskeyPrfError(.rpIdMismatch) { try await self.storage.read() }
  }

  func test_read_whenThePlatformAnswersWithAnotherPasskey_throwsPasskeyUnavailable() async {
    api.getPasskeyPrfCredentialResults = [.success(record(Self.serverCredentialId))]
    client.getResults = [.success(PasskeyPrfGetResult(credentialId: Data([0xEE]), prfOutput: Self.assertedOutput))]

    do {
      _ = try await storage.read()
      XCTFail("Expected an error")
    } catch let error as PortalPasskeyPrfError {
      XCTAssertEqual(error, PortalPasskeyPrfError(.passkeyUnavailable, context: "A passkey other than this client's enrolled passkey answered."))
      XCTAssertEqual(
        error.errorDescription,
        "[Portal] The enrolled passkey is not available on this device. A passkey other than this client's enrolled passkey answered."
      )
    } catch {
      XCTFail("Expected PortalPasskeyPrfError, got \(error)")
    }
  }

  func test_read_whenAssertionHasNoPrfOutput_throwsNotSupported() async {
    api.getPasskeyPrfCredentialResults = [.success(record(Self.serverCredentialId))]
    client.getResults = [.success(PasskeyPrfGetResult(credentialId: Self.serverCredentialId, prfOutput: nil))]

    await assertPasskeyPrfError(.notSupported) { try await self.storage.read() }
  }

  func test_read_withNonCanonicalStoredCredentialId_throwsCeremonyFailed() async {
    api.getPasskeyPrfCredentialResults = [.success(PasskeyPrfCredential(credentialId: "AQID+/8=", rpId: "portalhq.io"))]

    await assertPasskeyPrfError(.ceremonyFailed) { try await self.storage.read() }
    XCTAssertTrue(client.getRequests.isEmpty)
  }

  func test_read_whenNotAttachedToPortal_throws() async {
    storage.api = nil
    do {
      _ = try await storage.read()
      XCTFail("Expected an error")
    } catch {
      XCTAssertEqual(error as? PasskeyPrfStorageError, .notAttachedToPortal)
    }
  }

  func test_unsupportedPlatform_throwsNotSupported() async {
    storage = makeStorage(isPlatformSupported: false)
    await assertPasskeyPrfError(.notSupported) { try await self.storage.enroll() }
    await assertPasskeyPrfError(.notSupported) { try await self.storage.read() }
    await assertPasskeyPrfError(.notSupported) { try await self.storage.validateOperations() }
  }

  // MARK: - Ceremony error mapping

  func test_ceremonyErrors_mapToReasons() async {
    let cases: [(PasskeyPrfCeremonyError, PortalPasskeyPrfError.Reason)] = [
      (.cancelled(nil), .userCancelled),
      (.noCredentials(nil), .passkeyUnavailable),
      (.noPresentationAnchor, .ceremonyFailed),
      (.failed(NSError(domain: "x", code: 1)), .ceremonyFailed)
    ]
    for (ceremonyError, reason) in cases {
      api.getPasskeyPrfCredentialResults = [.success(record(Self.serverCredentialId))]
      client.getResults = [.failure(ceremonyError)]
      await assertPasskeyPrfError(reason) { try await self.storage.read() }
    }

    queueCreation()
    client.createResults = [.failure(PasskeyPrfCeremonyError.cancelled(nil))]
    await assertPasskeyPrfError(.userCancelled) { try await self.storage.enroll() }
  }

  func test_failedCeremony_logsThePlatformError_soASetupProblemIsVisible() async {
    let logger = RecordingLogger()
    logger.install()
    defer { logger.uninstall() }
    let platformError = NSError(
      domain: ASAuthorizationError.errorDomain,
      code: ASAuthorizationError.Code.failed.rawValue,
      userInfo: [NSLocalizedFailureReasonErrorKey: "Application with identifier X is not associated with domain portalhq.io"]
    )
    api.getPasskeyPrfCredentialResults = [.success(record(Self.serverCredentialId))]
    client.getResults = [.failure(PasskeyPrfCeremonyError.failed(platformError))]

    await assertPasskeyPrfError(.ceremonyFailed) { try await self.storage.read() }

    let errors = logger.messages(at: .error)
    XCTAssertEqual(errors.count, 1)
    XCTAssertTrue(errors.first?.contains("PRF_CEREMONY_FAILED") ?? false)
    XCTAssertTrue(errors.first?.contains("is not associated with domain portalhq.io") ?? false)
  }

  func test_cancelledCeremony_logsAtInfo_notAsAnError() async {
    let logger = RecordingLogger()
    logger.install()
    defer { logger.uninstall() }
    api.getPasskeyPrfCredentialResults = [.success(record(Self.serverCredentialId))]
    client.getResults = [.failure(PasskeyPrfCeremonyError.cancelled(ASAuthorizationError(.canceled)))]

    await assertPasskeyPrfError(.userCancelled) { try await self.storage.read() }

    XCTAssertTrue(logger.messages(at: .error).isEmpty)
    XCTAssertTrue(logger.messages(at: .info).contains { $0.contains("PRF_USER_CANCELLED") })
  }

  func test_failedCeremony_reportsAStableCode_andKeepsThePlatformMessageInTheCause() {
    let platformError = NSError(domain: "x", code: 7, userInfo: [NSLocalizedDescriptionKey: "internal detail"])
    let error = PasskeyPrfStorage.portalError(from: .failed(platformError))

    XCTAssertEqual(error.reason, .ceremonyFailed)
    XCTAssertEqual(error.context, "The passkey ceremony failed (x 7).")
    XCTAssertFalse(error.errorDescription?.contains("internal detail") ?? true)
    XCTAssertEqual((error.cause as? NSError)?.code, 7)

    XCTAssertEqual(
      PasskeyPrfStorage.portalError(from: .failed(ASAuthorizationError(.failed))).context,
      "The passkey ceremony failed (ASAuthorizationError 1004)."
    )
    XCTAssertEqual(
      PasskeyPrfStorage.portalError(from: .failed(nil)).context,
      "The passkey ceremony failed (UNEXPECTED_CREDENTIAL)."
    )
  }

  func test_authorizationErrors_mapToCeremonyErrors() {
    func map(_ error: Error) -> String {
      switch PasskeyPrfAuthorizationClient.ceremonyError(from: error) {
      case .cancelled: return "cancelled"
      case .noCredentials: return "noCredentials"
      case .noPresentationAnchor: return "noPresentationAnchor"
      case .failed: return "failed"
      }
    }
    XCTAssertEqual(map(ASAuthorizationError(.canceled)), "cancelled")
    XCTAssertEqual(map(ASAuthorizationError(.notInteractive)), "noCredentials")
    XCTAssertEqual(map(ASAuthorizationError(.failed)), "failed")
    XCTAssertEqual(map(ASAuthorizationError(.invalidResponse)), "failed")
    XCTAssertEqual(map(NSError(domain: "other", code: 1001)), "failed")
  }

  func test_authorizationClient_withoutAnchor_failsBeforePresenting() async {
    let client = PasskeyPrfAuthorizationClient()
    do {
      _ = try await client.getCredential(PasskeyPrfGetRequest(rpId: "portalhq.io", challenge: Data(count: 32), allowCredentialId: Data([1]), prfSalt: PasskeyPrfConstants.salt))
      XCTFail("Expected an error")
    } catch PasskeyPrfCeremonyError.noPresentationAnchor {
      // expected
    } catch {
      XCTFail("Unexpected error \(error)")
    }
  }

  @MainActor
  func test_authorizationClient_inACancelledTask_throwsCancellationError_withoutStartingThePrompt() async {
    var controllersMade = 0
    let client = PasskeyPrfAuthorizationClient(anchor: UIWindow()) { _, _ in
      controllersMade += 1
      return PasskeyPrfControllerFake()
    }
    // Cancelled before it runs: the test holds the main actor until it awaits the task.
    let task = Task { @MainActor in
      try await client.getCredential(Self.assertionRequest)
    }
    task.cancel()

    await assertPasskeyPrfCancelled(task)
    XCTAssertEqual(controllersMade, 0)
  }

  @MainActor
  func test_authorizationClient_whenTheTaskIsCancelledWhileThePromptIsUp_cancelsIt_andIgnoresItsLateReport() async {
    let controller = PasskeyPrfControllerFake()
    let client = PasskeyPrfAuthorizationClient(anchor: UIWindow()) { _, delegate in
      controller.delegate = delegate
      return controller
    }
    let task = Task { @MainActor in
      try await client.getCredential(Self.assertionRequest)
    }
    await fulfillment(of: [controller.performed], timeout: 5)

    task.cancel()
    await assertPasskeyPrfCancelled(task)

    XCTAssertEqual(controller.performRequestsCallsCount, 1)
    XCTAssertEqual(controller.cancelCallsCount, 1)
    // The session stays alive until the controller reports its own cancel...
    XCTAssertNotNil(controller.delegate)
    // ...and that late report resumes nothing (a second resume would trap) and releases it.
    controller.delegate?.authorizationController?(controller: Self.makeSystemController(), didCompleteWithError: ASAuthorizationError(.canceled))
    await Task.yield()
    XCTAssertNil(controller.delegate)
  }

  @MainActor
  func test_authorizationClient_whenTheControllerReportsAnError_throwsIt_andReleasesTheSession() async {
    let controller = PasskeyPrfControllerFake()
    let client = PasskeyPrfAuthorizationClient(anchor: UIWindow()) { _, delegate in
      controller.delegate = delegate
      return controller
    }
    let task = Task { @MainActor in
      try await client.getCredential(Self.assertionRequest)
    }
    await fulfillment(of: [controller.performed], timeout: 5)

    controller.delegate?.authorizationController?(controller: Self.makeSystemController(), didCompleteWithError: ASAuthorizationError(.canceled))

    switch await passkeyPrfResult(of: task) {
    case .failure(PasskeyPrfCeremonyError.cancelled):
      break // The user dismissed the prompt: a ceremony error, not a task cancellation.
    case let result:
      XCTFail("Expected PasskeyPrfCeremonyError.cancelled, got \(String(describing: result))")
    }
    XCTAssertEqual(controller.cancelCallsCount, 0)
    await Task.yield()
    XCTAssertNil(controller.delegate)
  }

  private static let assertionRequest = PasskeyPrfGetRequest(
    rpId: "portalhq.io",
    challenge: Data(count: 32),
    allowCredentialId: Data([1]),
    prfSalt: PasskeyPrfConstants.salt
  )

  /// A system controller that is never performed, only passed where the delegate methods take one.
  @MainActor
  private static func makeSystemController() -> ASAuthorizationController {
    let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: "portalhq.io")
    return ASAuthorizationController(authorizationRequests: [provider.createCredentialAssertionRequest(challenge: Data(count: 32))])
  }

  // MARK: - Cipher

  func test_encryptWithSecret_usesThePasswordCipher() async throws {
    let cipherText = try await storage.encrypt("shares", withSecret: "abcd")

    XCTAssertEqual(cipherText, "password-cipher-text")
    XCTAssertEqual(encryption.encryptWithPasswordParams.first?.value, "shares")
    XCTAssertEqual(encryption.encryptWithPasswordParams.first?.password, "abcd")
    XCTAssertEqual(encryption.privateKeyCallsCount, 0)
  }

  func test_encrypt_enrollsAndUsesThePasswordCipher() async throws {
    api.getPasskeyPrfCredentialResults = [.success(record(Self.serverCredentialId))]

    let result = try await storage.encrypt("shares")

    XCTAssertEqual(result.cipherText, "password-cipher-text")
    XCTAssertEqual(encryption.encryptWithPasswordParams.first?.password, PasskeyPrfEncoding.hex(Self.assertedOutput))
  }

  func test_decrypt_usesThePasswordCipher() async throws {
    let plaintext = try await storage.decrypt("cipher", withKey: "abcd")

    XCTAssertEqual(plaintext, "plaintext")
    XCTAssertEqual(encryption.decryptWithPasswordParams.first?.password, "abcd")
    XCTAssertEqual(encryption.privateKeyCallsCount, 0)
  }

  func test_decrypt_withTheWrongPasskey_throwsDecryptFailed() async {
    encryption.decryptWithPasswordError = PortalMpcError(PortalError(id: "DECRYPT_FAILED", message: "Failed to decrypt"))

    await assertPasskeyPrfError(.decryptFailed) { try await self.storage.decrypt("cipher", withKey: "wrong") }
  }

  func test_decrypt_withUnusableCipherText_throwsDecryptFailed() async {
    encryption.decryptWithPasswordError = MpcError.unexpectedErrorOnDecrypt("bad cipher text")

    await assertPasskeyPrfError(.decryptFailed) { try await self.storage.decrypt("not-a-cipher", withKey: "abcd") }
  }

  func test_write_isANoOp_andDeleteIsUnsupported() async throws {
    let written = try await storage.write("anything")
    XCTAssertTrue(written)
    do {
      _ = try await storage.delete()
      XCTFail("Expected delete to throw")
    } catch {
      XCTAssertEqual(error as? PasskeyPrfStorageError, .deleteNotSupported)
    }
  }

  func test_zero_clearsTheBuffer() {
    var data: Data? = Data(repeating: 0xFF, count: 32)
    PasskeyPrfStorage.zero(&data)
    XCTAssertNil(data)
  }
}
