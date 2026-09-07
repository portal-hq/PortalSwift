//
//  PresignatureManagerTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

@testable import PortalSwift
import XCTest

final class PresignatureManagerTests: XCTestCase {
  private var mobileSpy = MobileSpy()
  private var keychainSpy = PortalKeychainSpy()
  private var recordingLogger = RecordingLogger()

  /// A retry policy that exhausts in exactly three attempts with negligible backoff, for the
  /// cases that count attempts rather than measure them.
  private static let threeAttempts = PresignRetryConfig(
    maxAttempts: 3,
    baseDelayNs: 1_000_000,
    multiplier: 2.0,
    maxDelayNs: 10_000_000
  )

  /// A three-attempt policy whose two backoff sleeps (50 ms then 100 ms) are long enough to be
  /// observed in wall-clock time, which is how the growing-backoff case is asserted without a
  /// sleep seam on `PresignatureManager`.
  private static let observableBackoff = PresignRetryConfig(
    maxAttempts: 3,
    baseDelayNs: 50_000_000,
    multiplier: 2.0,
    maxDelayNs: 10_000_000_000
  )

  private func makeManager(
    credentials: PortalCredentials = MockCredentials(tokenValue: "test-api-key"),
    maxPresignaturesPerCurve: [PresignatureSupportedCurve: Int] = [.SECP256K1: 3],
    featureFlags: FeatureFlags? = FeatureFlags(usePresignatures: true),
    retryConfig: PresignRetryConfig = .fast
  ) -> PresignatureManager {
    PresignatureManager(
      credentials: credentials,
      mpcHost: "mpc.test.io",
      binary: mobileSpy,
      keychain: keychainSpy,
      maxPresignaturesPerCurve: maxPresignaturesPerCurve,
      featureFlags: featureFlags,
      retryConfig: retryConfig
    )
  }

  private func mockPresignResponse(id: String = "presig-1") -> String {
    MpcJSON.presignSuccess(
      id: id,
      expiresAt: "2099-01-01T00:00:00Z",
      data: "mock-presig-data-\(id)"
    )
  }

  override func setUpWithError() throws {
    CredentialInvalidationRegistry.shared.resetForTesting()
    recordingLogger = RecordingLogger()
    recordingLogger.install()
    mobileSpy = MobileSpy()
    keychainSpy = PortalKeychainSpy()
    keychainSpy.getSharesReturnValue = [
      "SECP256K1": PortalMpcGeneratedShare(id: "mock-share-id", share: "mock-share-data")
    ]
  }

  override func tearDownWithError() throws {
    recordingLogger.uninstall()
    CredentialInvalidationRegistry.shared.resetForTesting()
  }
}

// MARK: - consumePresignature Tests

extension PresignatureManagerTests {
  func test_consumePresignature_returnsEntry_whenAvailable() async {
    let entry = PresignatureEntry(id: "presig-1", expiresAt: "2099-01-01T00:00:00Z", data: "data")
    try? await keychainSpy.insertPresignature("SECP256K1", entry)

    mobileSpy.mobilePresignReturnValue = mockPresignResponse()
    let manager = makeManager()

    let result = await manager.consumePresignature(forCurve: .SECP256K1)

    XCTAssertEqual(result, entry)
    XCTAssertEqual(keychainSpy.popOldestPresignatureCallCount, 1)
  }

  func test_consumePresignature_returnsNil_whenEmpty() async {
    let manager = makeManager()

    let result = await manager.consumePresignature(forCurve: .SECP256K1)
    XCTAssertNil(result)
  }

  func test_consumePresignature_returnsNil_forUnsupportedCurve() async {
    let manager = makeManager()

    let result = await manager.consumePresignature(forCurve: .ED25519)
    XCTAssertNil(result)
    XCTAssertEqual(keychainSpy.popOldestPresignatureCallCount, 0)
  }
}

// MARK: - initializeBuffers Tests

extension PresignatureManagerTests {
  func test_initializeBuffers_callsPresign_upToMax() async throws {
    mobileSpy.mobilePresignReturnValue = mockPresignResponse()
    let manager = makeManager(maxPresignaturesPerCurve: [.SECP256K1: 2])

    manager.initializeBuffers()

    try await Task.sleep(nanoseconds: 2_000_000_000)

    XCTAssertEqual(mobileSpy.mobilePresignCallsCount, 2)
    XCTAssertEqual(keychainSpy.insertPresignatureCallCount, 2)
  }

  func test_initializeBuffers_doesNothing_whenFeatureDisabled() async throws {
    mobileSpy.mobilePresignReturnValue = mockPresignResponse()
    let manager = makeManager(featureFlags: FeatureFlags(usePresignatures: false))

    manager.initializeBuffers()

    try await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertEqual(mobileSpy.mobilePresignCallsCount, 0)
  }

  func test_initializeBuffers_doesNothing_whenMaxIsZero() async throws {
    mobileSpy.mobilePresignReturnValue = mockPresignResponse()
    let manager = makeManager(maxPresignaturesPerCurve: [.SECP256K1: 0])

    manager.initializeBuffers()

    try await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertEqual(mobileSpy.mobilePresignCallsCount, 0)
  }

  func test_initializeBuffers_skipsUnconfiguredCurves() async throws {
    mobileSpy.mobilePresignReturnValue = mockPresignResponse()
    let manager = makeManager(maxPresignaturesPerCurve: [:])

    manager.initializeBuffers()

    try await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertEqual(mobileSpy.mobilePresignCallsCount, 0)
  }
}

// MARK: - deleteAll Tests

extension PresignatureManagerTests {
  func test_deleteAll_deletesPresignaturesForAllCurves() async {
    let entry = PresignatureEntry(id: "presig-1", expiresAt: "2099-01-01T00:00:00Z", data: "data")
    try? await keychainSpy.insertPresignature("SECP256K1", entry)

    let manager = makeManager()
    await manager.deleteAll()

    XCTAssertEqual(keychainSpy.deletePresignaturesCallCount, 1)
  }

  func test_deleteAll_cancelsRunningFillTasks() async throws {
    mobileSpy.mobilePresignReturnValue = mockPresignResponse()
    let manager = makeManager(maxPresignaturesPerCurve: [.SECP256K1: 10])

    manager.initializeBuffers()
    try await Task.sleep(nanoseconds: 200_000_000)

    let insertsBefore = keychainSpy.insertPresignatureCallCount
    await manager.deleteAll()
    try await Task.sleep(nanoseconds: 1_000_000_000)
    let insertsAfter = keychainSpy.insertPresignatureCallCount

    XCTAssertEqual(insertsBefore, insertsAfter, "No new inserts should occur after deleteAll cancels tasks")
  }
}

// MARK: - Retry Logic Tests

extension PresignatureManagerTests {
  func test_presign_retriesOnFailure() async throws {
    mobileSpy.mobilePresignReturnValue = "{\"error\":{\"id\":\"FAIL\",\"message\":\"test failure\"}}"

    let manager = makeManager(maxPresignaturesPerCurve: [.SECP256K1: 1])
    manager.initializeBuffers()

    try await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertGreaterThan(mobileSpy.mobilePresignCallsCount, 1, "Should have retried")
    XCTAssertEqual(keychainSpy.insertPresignatureCallCount, 0, "Should not have inserted any presignatures on failure")
  }
}

// MARK: - Consume triggers refill Tests

extension PresignatureManagerTests {
  func test_consumePresignature_triggersRefill_andReplenishesBuffer() async throws {
    mobileSpy.mobilePresignReturnValue = mockPresignResponse(id: "refill-1")

    let entry = PresignatureEntry(id: "presig-1", expiresAt: "2099-01-01T00:00:00Z", data: "data")
    try await keychainSpy.insertPresignature("SECP256K1", entry)

    let manager = makeManager(maxPresignaturesPerCurve: [.SECP256K1: 3])

    let consumed = await manager.consumePresignature(forCurve: .SECP256K1)
    XCTAssertEqual(consumed, entry)

    try await Task.sleep(nanoseconds: 3_000_000_000)

    XCTAssertGreaterThan(mobileSpy.mobilePresignCallsCount, 0, "Should have triggered a refill")

    let remaining = try await keychainSpy.getPresignatures("SECP256K1")
    XCTAssertGreaterThan(remaining.count, 0, "Buffer should have been replenished after consume")
  }
}

// MARK: - Concurrent fill deduplication Tests

extension PresignatureManagerTests {
  func test_concurrentFills_areDeduplicated() async throws {
    let e1 = PresignatureEntry(id: "p1", expiresAt: "2099-01-01T00:00:00Z", data: "d1")
    let e2 = PresignatureEntry(id: "p2", expiresAt: "2099-01-01T00:00:00Z", data: "d2")
    try await keychainSpy.insertPresignature("SECP256K1", e1)
    try await keychainSpy.insertPresignature("SECP256K1", e2)

    mobileSpy.mobilePresignReturnValue = mockPresignResponse()
    let manager = makeManager(maxPresignaturesPerCurve: [.SECP256K1: 3])

    _ = await manager.consumePresignature(forCurve: .SECP256K1)
    _ = await manager.consumePresignature(forCurve: .SECP256K1)

    try await Task.sleep(nanoseconds: 3_000_000_000)

    XCTAssertEqual(mobileSpy.mobilePresignCallsCount, 3,
                   "Only one fill should have run, generating exactly max presignatures")
  }
}

// MARK: - Cleanup expired presignatures Tests

extension PresignatureManagerTests {
  func test_fillBuffer_cleansUpExpiredPresignatures() async throws {
    let expired = PresignatureEntry(id: "expired", expiresAt: "2020-01-01T00:00:00Z", data: "old-data")
    try await keychainSpy.insertPresignature("SECP256K1", expired)

    mobileSpy.mobilePresignReturnValue = mockPresignResponse()
    let manager = makeManager(maxPresignaturesPerCurve: [.SECP256K1: 1])

    manager.initializeBuffers()

    try await Task.sleep(nanoseconds: 2_000_000_000)

    XCTAssertGreaterThanOrEqual(keychainSpy.cleanupExpiredPresignaturesCallCount, 1, "Should have cleaned up expired entries")
  }
}

// MARK: - preSign edge cases (tested via initializeBuffers)

extension PresignatureManagerTests {
  func test_presign_returnsNil_whenNoShareFound() async throws {
    keychainSpy.getSharesReturnValue = [:]
    mobileSpy.mobilePresignReturnValue = mockPresignResponse()

    let manager = makeManager(maxPresignaturesPerCurve: [.SECP256K1: 1])
    manager.initializeBuffers()

    try await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertEqual(mobileSpy.mobilePresignCallsCount, 0, "Should not call presign when no share exists")
    XCTAssertEqual(keychainSpy.insertPresignatureCallCount, 0)
  }

  func test_presign_returnsNil_whenShareIsEmpty() async throws {
    keychainSpy.getSharesReturnValue = [
      "SECP256K1": PortalMpcGeneratedShare(id: "mock-id", share: "")
    ]
    mobileSpy.mobilePresignReturnValue = mockPresignResponse()

    let manager = makeManager(maxPresignaturesPerCurve: [.SECP256K1: 1])
    manager.initializeBuffers()

    try await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertEqual(mobileSpy.mobilePresignCallsCount, 0, "Should not call presign when share is empty")
    XCTAssertEqual(keychainSpy.insertPresignatureCallCount, 0)
  }

  func test_presign_handlesIncompleteResponse_missingId() async throws {
    let incomplete = "{\"id\":null,\"expiresAt\":\"2099-01-01T00:00:00Z\",\"data\":\"blob\"}"
    mobileSpy.mobilePresignReturnValue = incomplete

    let manager = makeManager(maxPresignaturesPerCurve: [.SECP256K1: 1])
    manager.initializeBuffers()

    try await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertEqual(mobileSpy.mobilePresignCallsCount, 6, "Should retry all attempts for incomplete response")
    XCTAssertEqual(keychainSpy.insertPresignatureCallCount, 0, "Should not insert incomplete presignature")
  }

  func test_presign_handlesIncompleteResponse_missingData() async throws {
    let incomplete = "{\"id\":\"abc\",\"expiresAt\":\"2099-01-01T00:00:00Z\",\"data\":null}"
    mobileSpy.mobilePresignReturnValue = incomplete

    let manager = makeManager(maxPresignaturesPerCurve: [.SECP256K1: 1])
    manager.initializeBuffers()

    try await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertEqual(mobileSpy.mobilePresignCallsCount, 6, "Should retry all attempts for incomplete response")
    XCTAssertEqual(keychainSpy.insertPresignatureCallCount, 0)
  }

  func test_presign_handlesInvalidJson() async throws {
    mobileSpy.mobilePresignReturnValue = "not-valid-json"

    let manager = makeManager(maxPresignaturesPerCurve: [.SECP256K1: 1])
    manager.initializeBuffers()

    try await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertEqual(mobileSpy.mobilePresignCallsCount, 6, "Should retry all attempts for invalid JSON")
    XCTAssertEqual(keychainSpy.insertPresignatureCallCount, 0)
  }

  func test_presign_exhaustsExactlyMaxRetryAttempts() async throws {
    mobileSpy.mobilePresignReturnValue = "{\"error\":{\"id\":\"ERR\",\"message\":\"fail\"}}"

    let config = PresignRetryConfig(maxAttempts: 3, baseDelayNs: 1_000_000, multiplier: 2.0, maxDelayNs: 10_000_000)
    let manager = makeManager(maxPresignaturesPerCurve: [.SECP256K1: 1], retryConfig: config)
    manager.initializeBuffers()

    try await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertEqual(mobileSpy.mobilePresignCallsCount, 3, "Should call presign exactly maxAttempts times")
  }

  func test_presign_succeedsOnFirstAttempt() async throws {
    mobileSpy.mobilePresignReturnValue = mockPresignResponse(id: "first-try")

    let manager = makeManager(maxPresignaturesPerCurve: [.SECP256K1: 1])
    manager.initializeBuffers()

    try await Task.sleep(nanoseconds: 1_000_000_000)

    XCTAssertEqual(mobileSpy.mobilePresignCallsCount, 1, "Should succeed on first attempt without retries")
    XCTAssertEqual(keychainSpy.insertPresignatureCallCount, 1)
  }

  func test_presign_handlesGetSharesThrows() async throws {
    keychainSpy.getSharesShouldThrow = true
    mobileSpy.mobilePresignReturnValue = mockPresignResponse()

    let manager = makeManager(maxPresignaturesPerCurve: [.SECP256K1: 1])
    manager.initializeBuffers()

    try await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertEqual(mobileSpy.mobilePresignCallsCount, 0, "Should not call binary when getShares throws")
    XCTAssertEqual(keychainSpy.insertPresignatureCallCount, 0)
  }

  func test_presign_handlesBinaryErrorResponse() async throws {
    mobileSpy.mobilePresignReturnValue = "{\"error\":{\"id\":\"BINARY_ERR\",\"message\":\"binary failed\"}}"

    let manager = makeManager(maxPresignaturesPerCurve: [.SECP256K1: 1])
    manager.initializeBuffers()

    try await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertEqual(mobileSpy.mobilePresignCallsCount, 6, "Should retry on binary error response")
    XCTAssertEqual(keychainSpy.insertPresignatureCallCount, 0, "Should not insert when binary returns error")
  }
}

// MARK: - initializeBuffers edge cases

extension PresignatureManagerTests {
  func test_initializeBuffers_doesNothing_whenFeatureFlagsNil() async throws {
    mobileSpy.mobilePresignReturnValue = mockPresignResponse()
    let manager = makeManager(featureFlags: nil)

    manager.initializeBuffers()

    try await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertEqual(mobileSpy.mobilePresignCallsCount, 0, "Should not presign when featureFlags is nil")
  }

  func test_initializeBuffers_cancelsPreviousFills_whenCalledAgain() async throws {
    mobileSpy.mobilePresignReturnValue = mockPresignResponse()
    let manager = makeManager(maxPresignaturesPerCurve: [.SECP256K1: 10])

    manager.initializeBuffers()
    try await Task.sleep(nanoseconds: 100_000_000)

    let countAfterFirstInit = keychainSpy.insertPresignatureCallCount

    manager.initializeBuffers()
    try await Task.sleep(nanoseconds: 2_000_000_000)

    let finalCount = keychainSpy.insertPresignatureCallCount
    XCTAssertLessThanOrEqual(finalCount, countAfterFirstInit + 10,
                             "Second init should have cancelled first and started fresh")
  }
}

// MARK: - fillBuffer edge cases

extension PresignatureManagerTests {
  func test_fillBuffer_skipsWhenBufferAlreadyFull() async throws {
    for i in 0 ..< 3 {
      let e = PresignatureEntry(id: "pre-\(i)", expiresAt: "2099-01-01T00:00:00Z", data: "data-\(i)")
      try await keychainSpy.insertPresignature("SECP256K1", e)
    }

    mobileSpy.mobilePresignReturnValue = mockPresignResponse()
    let manager = makeManager(maxPresignaturesPerCurve: [.SECP256K1: 3])

    manager.initializeBuffers()

    try await Task.sleep(nanoseconds: 1_000_000_000)

    XCTAssertEqual(mobileSpy.mobilePresignCallsCount, 0, "Should not generate presignatures when buffer is full")
  }

  func test_fillBuffer_handlesInsertFailure_gracefully() async throws {
    keychainSpy.insertPresignatureShouldThrow = true
    mobileSpy.mobilePresignReturnValue = mockPresignResponse()

    let manager = makeManager(maxPresignaturesPerCurve: [.SECP256K1: 2])
    manager.initializeBuffers()

    try await Task.sleep(nanoseconds: 1_000_000_000)

    XCTAssertEqual(mobileSpy.mobilePresignCallsCount, 2, "Should still attempt all presigns")
    let stored = try await keychainSpy.getPresignatures("SECP256K1")
    XCTAssertEqual(stored.count, 0, "No entries should be stored when insert throws")
  }

  func test_fillBuffer_generatesOnlyNeededCount() async throws {
    let existing = PresignatureEntry(id: "existing-1", expiresAt: "2099-01-01T00:00:00Z", data: "data")
    try await keychainSpy.insertPresignature("SECP256K1", existing)

    mobileSpy.mobilePresignReturnValue = mockPresignResponse()
    let manager = makeManager(maxPresignaturesPerCurve: [.SECP256K1: 3])

    manager.initializeBuffers()

    try await Task.sleep(nanoseconds: 2_000_000_000)

    XCTAssertEqual(mobileSpy.mobilePresignCallsCount, 2, "Should generate only the needed count (max - existing)")
  }

  func test_fillBuffer_stopsOnPresignFailure() async throws {
    mobileSpy.mobilePresignReturnValue = "{\"id\":null,\"expiresAt\":null,\"data\":null}"

    let config = PresignRetryConfig(maxAttempts: 1, baseDelayNs: 1_000_000, multiplier: 2.0, maxDelayNs: 10_000_000)
    let manager = makeManager(maxPresignaturesPerCurve: [.SECP256K1: 5], retryConfig: config)
    manager.initializeBuffers()

    try await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertEqual(mobileSpy.mobilePresignCallsCount, 1, "Should stop filling after first presign failure (1 attempt, no retry)")
    XCTAssertEqual(keychainSpy.insertPresignatureCallCount, 0)
  }
}

// MARK: - deleteAll edge cases

extension PresignatureManagerTests {
  func test_deleteAll_handlesDeleteError_gracefully() async {
    let entry = PresignatureEntry(id: "presig-1", expiresAt: "2099-01-01T00:00:00Z", data: "data")
    try? await keychainSpy.insertPresignature("SECP256K1", entry)
    keychainSpy.deletePresignaturesShouldThrow = true

    let manager = makeManager()
    await manager.deleteAll()

    XCTAssertEqual(keychainSpy.deletePresignaturesCallCount, 1, "Should attempt deletion even if it throws")
  }

  func test_deleteAll_withEmptyStore_doesNotCrash() async {
    let manager = makeManager()
    await manager.deleteAll()

    XCTAssertEqual(keychainSpy.deletePresignaturesCallCount, 1, "Should call delete for each supported curve")
  }
}

// MARK: - PresignatureManagerError Tests

extension PresignatureManagerTests {
  func test_presignatureManagerError_unableToParsePresignResponse_description() {
    let error = PresignatureManagerError.unableToParsePresignResponse
    XCTAssertEqual(error.errorDescription, "Unable to parse presign response as UTF-8 data")
  }

  func test_presignatureManagerError_incompletePresignResponse_description() {
    let error = PresignatureManagerError.incompletePresignResponse
    XCTAssertEqual(error.errorDescription, "Presign response missing required fields (id, expiresAt, or data)")
  }
}

// MARK: - PresignRetryConfig Tests

extension PresignatureManagerTests {
  func test_presignRetryConfig_defaultValues() {
    let config = PresignRetryConfig.default
    XCTAssertEqual(config.maxAttempts, 3)
    XCTAssertEqual(config.baseDelayNs, 2_000_000_000)
    XCTAssertEqual(config.multiplier, 2.0)
    XCTAssertEqual(config.maxDelayNs, 300_000_000_000)
  }

  func test_presignRetryConfig_fastValues() {
    let config = PresignRetryConfig.fast
    XCTAssertEqual(config.maxAttempts, 6)
    XCTAssertEqual(config.baseDelayNs, 1_000_000)
    XCTAssertEqual(config.multiplier, 2.0)
    XCTAssertEqual(config.maxDelayNs, 10_000_000)
  }

  func test_presignRetryConfig_customValues() {
    let config = PresignRetryConfig(maxAttempts: 10, baseDelayNs: 500, multiplier: 3.0, maxDelayNs: 999)
    XCTAssertEqual(config.maxAttempts, 10)
    XCTAssertEqual(config.baseDelayNs, 500)
    XCTAssertEqual(config.multiplier, 3.0)
    XCTAssertEqual(config.maxDelayNs, 999)
  }
}

// MARK: - Credentials: per-attempt token resolution

extension PresignatureManagerTests {
  func test_preSign_willPassResolvedTokenToBinary() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "test-api-key")
    mobileSpy.mobilePresignReturnValue = mockPresignResponse()
    let manager = makeManager(credentials: credentials, maxPresignaturesPerCurve: [.SECP256K1: 1])

    // and given
    manager.initializeBuffers()

    // then
    let stored = await waitUntil { self.keychainSpy.insertPresignatureCallCount == 1 }
    XCTAssertTrue(stored, "The refill should have generated and stored exactly one presignature.")
    XCTAssertEqual(mobileSpy.mobilePresignApiKeyParam, "test-api-key")
    XCTAssertEqual(mobileSpy.mobilePresignMpcAddrParam, "mpc.test.io")
    XCTAssertEqual(keychainSpy.insertPresignatureCallCount, 1)
    withExtendedLifetime(manager) {}
  }

  func test_preSign_willResolveTokenPerAttempt() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "test-api-key")
    mobileSpy.mobilePresignReturnValue = MpcJSON.presignError(id: "ERR")
    let manager = makeManager(
      credentials: credentials,
      maxPresignaturesPerCurve: [.SECP256K1: 1],
      retryConfig: Self.threeAttempts
    )

    // and given
    manager.initializeBuffers()

    // then
    let exhausted = await waitUntil { self.mobileSpy.mobilePresignCallsCount == 3 }
    XCTAssertTrue(exhausted, "Every attempt should have reached the binary.")
    XCTAssertEqual(credentials.getTokenCalls, 3, "The token must be resolved inside every attempt, not once per preSign.")
    withExtendedLifetime(manager) {}
  }

  func test_preSign_willPickUpRotatedToken_betweenAttempts() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "initial")
    mobileSpy.mobilePresignReturnValue = MpcJSON.presignError(id: "ERR")
    credentials.onGetToken = { [weak credentials, weak self] in
      guard let self, let credentials else {
        return
      }
      // The hook runs after the call has been counted and before `tokenValue` is read, so the
      // second attempt both sees the rotated token and gets a successful binary response.
      if credentials.getTokenCalls >= 2 {
        credentials.tokenValue = "rotated"
        self.mobileSpy.mobilePresignReturnValue = self.mockPresignResponse()
      }
    }
    let manager = makeManager(
      credentials: credentials,
      maxPresignaturesPerCurve: [.SECP256K1: 1],
      retryConfig: Self.threeAttempts
    )

    // and given
    manager.initializeBuffers()

    // then
    let stored = await waitUntil { self.keychainSpy.insertPresignatureCallCount == 1 }
    XCTAssertTrue(stored, "The second attempt should have succeeded with the rotated token.")
    XCTAssertEqual(mobileSpy.mobilePresignApiKeyParam, "rotated")
    XCTAssertEqual(mobileSpy.mobilePresignCallsCount, 2)
    withExtendedLifetime(manager) {}
  }
}

// MARK: - Credentials: failures that stop the refill without retrying

extension PresignatureManagerTests {
  func test_fillBuffer_willStopWithoutRetry_whenTokenBlank() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "")
    mobileSpy.mobilePresignReturnValue = mockPresignResponse()
    let manager = makeManager(credentials: credentials, maxPresignaturesPerCurve: [.SECP256K1: 3])

    // and given
    manager.initializeBuffers()

    // then
    let resolved = await waitUntil { credentials.getTokenCalls >= 1 }
    XCTAssertTrue(resolved, "The refill should have tried to resolve the credential.")
    let reachedBinary = await waitUntil(timeout: 0.3) { self.mobileSpy.mobilePresignCallsCount > 0 }
    XCTAssertFalse(reachedBinary, "A blank token must fail before any binary round trip.")
    XCTAssertEqual(credentials.getTokenCalls, 1, "A credential failure is not retried.")
    XCTAssertEqual(keychainSpy.insertPresignatureCallCount, 0)
    withExtendedLifetime(manager) {}
  }

  func test_fillBuffer_willStopWithoutRetry_whenProviderThrows() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "test-api-key", onGetToken: { throw PresignProviderFailure() })
    let recorder = InvalidationListenerRecorder(credentials: credentials)
    mobileSpy.mobilePresignReturnValue = mockPresignResponse()
    let manager = makeManager(credentials: credentials, maxPresignaturesPerCurve: [.SECP256K1: 3])

    // and given
    manager.initializeBuffers()

    // then
    let resolved = await waitUntil { credentials.getTokenCalls >= 1 }
    XCTAssertTrue(resolved, "The refill should have tried to resolve the credential.")
    let reachedBinary = await waitUntil(timeout: 0.3) { self.mobileSpy.mobilePresignCallsCount > 0 }
    XCTAssertFalse(reachedBinary, "A throwing provider must fail before any binary round trip.")
    XCTAssertEqual(credentials.getTokenCalls, 1, "A credential failure is not retried.")
    XCTAssertEqual(credentials.invalidateCalls, 0, "A provider failure is not a rejection; nothing is invalidated.")
    XCTAssertEqual(recorder.count, 0, "A provider failure is not reported to the host.")
    withExtendedLifetime(manager) {}
  }

  func test_fillBuffer_willStopWithoutRetry_whenSessionInvalidated() async throws {
    // given
    let session = MockPortalSession()
    try session.invalidate()
    let recorder = InvalidationListenerRecorder(credentials: session)
    mobileSpy.mobilePresignReturnValue = mockPresignResponse()
    let manager = makeManager(credentials: session, maxPresignaturesPerCurve: [.SECP256K1: 3])

    // and given
    manager.initializeBuffers()

    // then
    let resolved = await waitUntil { session.getTokenCalls >= 1 }
    XCTAssertTrue(resolved, "The refill should have tried to resolve the session.")
    let reachedBinary = await waitUntil(timeout: 0.3) { self.mobileSpy.mobilePresignCallsCount > 0 }
    XCTAssertFalse(reachedBinary, "A dead session must fail before any binary round trip.")
    XCTAssertEqual(session.getTokenCalls, 1, "A credential failure is not retried.")
    XCTAssertEqual(session.invalidateCalls, 1, "Only the test's own invalidate(); the SDK must not re-report a dead session.")
    XCTAssertEqual(recorder.count, 0)
    withExtendedLifetime(manager) {}
  }
}

// MARK: - Credentials: AUTH_FAILED from the binary

extension PresignatureManagerTests {
  func test_fillBuffer_willStopAndReportOnce_whenBinaryReturnsAuthFailed() async throws {
    // given
    let session = MockPortalSession()
    let recorder = InvalidationListenerRecorder(credentials: session)
    mobileSpy.mobilePresignReturnValue = MpcJSON.presignAuthFailed
    let manager = makeManager(credentials: session, maxPresignaturesPerCurve: [.SECP256K1: 3], retryConfig: .fast)

    // and given
    manager.initializeBuffers()

    // then
    let reported = await waitUntil { recorder.count == 1 }
    XCTAssertTrue(reported, "The host should have been told the session ended.")
    XCTAssertEqual(mobileSpy.mobilePresignCallsCount, 1, "AUTH_FAILED is not retried.")
    XCTAssertEqual(session.invalidateCalls, 1)
    XCTAssertEqual(keychainSpy.insertPresignatureCallCount, 0)
    withExtendedLifetime(manager) {}
  }

  func test_fillBuffer_willNotContinueNeededLoop_afterAuthFailed() async throws {
    // given
    let session = MockPortalSession()
    let recorder = InvalidationListenerRecorder(credentials: session)
    mobileSpy.mobilePresignReturnValue = MpcJSON.presignAuthFailed
    let manager = makeManager(credentials: session, maxPresignaturesPerCurve: [.SECP256K1: 3], retryConfig: .fast)

    // and given
    manager.initializeBuffers()

    // then
    let reported = await waitUntil { recorder.count == 1 }
    XCTAssertTrue(reported, "The host should have been told the session ended.")
    let secondSlot = await waitUntil(timeout: 0.3) { self.mobileSpy.mobilePresignCallsCount > 1 }
    XCTAssertFalse(secondSlot, "The needed-loop must break, not try the remaining slots.")
    XCTAssertEqual(mobileSpy.mobilePresignCallsCount, 1)
    withExtendedLifetime(manager) {}
  }

  func test_fillBuffer_willReportOnce_acrossRepeatedFills_afterAuthFailed() async throws {
    // given
    let session = MockPortalSession()
    let recorder = InvalidationListenerRecorder(credentials: session)
    mobileSpy.mobilePresignReturnValue = MpcJSON.presignAuthFailed
    let manager = makeManager(credentials: session, maxPresignaturesPerCurve: [.SECP256K1: 3], retryConfig: .fast)

    manager.initializeBuffers()
    let reported = await waitUntil { recorder.count == 1 }
    XCTAssertTrue(reported, "The first fill should have reported the rejection.")

    // and given: something to consume, so consumePresignature triggers a second fill
    let entry = PresignatureEntry(id: "presig-1", expiresAt: "2099-01-01T00:00:00Z", data: "data")
    try await keychainSpy.insertPresignature("SECP256K1", entry)
    _ = await manager.consumePresignature(forCurve: .SECP256K1)
    manager.initializeBuffers()

    // then
    let secondBinaryCall = await waitUntil(timeout: 0.5) { self.mobileSpy.mobilePresignCallsCount > 1 }
    XCTAssertFalse(secondBinaryCall, "The invalidated session must fail before the binary on every later fill.")
    XCTAssertEqual(recorder.count, 1, "However many fills run, the host is told exactly once.")
    withExtendedLifetime(manager) {}
  }
}

// MARK: - Credentials: generic (non-credential) failures keep the old behaviour

extension PresignatureManagerTests {
  func test_fillBuffer_willRetryWithBackoff_forGenericErrors() async throws {
    // given
    mobileSpy.mobilePresignReturnValue = MpcJSON.presignError(id: "ERR")
    let manager = makeManager(maxPresignaturesPerCurve: [.SECP256K1: 1], retryConfig: Self.observableBackoff)
    let startedAt = Date()

    // and given
    manager.initializeBuffers()

    // then
    let exhausted = await waitUntil { self.mobileSpy.mobilePresignCallsCount == 3 }
    XCTAssertTrue(exhausted, "A generic error is retried up to maxAttempts.")
    XCTAssertGreaterThanOrEqual(
      Date().timeIntervalSince(startedAt),
      0.15,
      "The two backoff sleeps must grow (50 ms then 100 ms), not fire back to back."
    )
    XCTAssertEqual(keychainSpy.insertPresignatureCallCount, 0)
    withExtendedLifetime(manager) {}
  }

  func test_fillBuffer_willNotInvalidate_forGenericErrors() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "test-api-key")
    let recorder = InvalidationListenerRecorder(credentials: credentials)
    mobileSpy.mobilePresignReturnValue = MpcJSON.presignError(id: "ERR")
    let manager = makeManager(
      credentials: credentials,
      maxPresignaturesPerCurve: [.SECP256K1: 1],
      retryConfig: Self.threeAttempts
    )

    // and given
    manager.initializeBuffers()

    // then
    let exhausted = await waitUntil { self.mobileSpy.mobilePresignCallsCount == 3 }
    XCTAssertTrue(exhausted, "A generic error is retried up to maxAttempts.")
    XCTAssertEqual(credentials.invalidateCalls, 0, "A non-401 failure must never invalidate the credential.")
    XCTAssertEqual(recorder.count, 0)
    withExtendedLifetime(manager) {}
  }

  func test_fillBuffer_willLeaveExistingBufferIntact_afterAuthFailedStop() async throws {
    // given
    let entry = PresignatureEntry(id: "presig-1", expiresAt: "2099-01-01T00:00:00Z", data: "data")
    try await keychainSpy.insertPresignature("SECP256K1", entry)

    let session = MockPortalSession()
    let recorder = InvalidationListenerRecorder(credentials: session)
    mobileSpy.mobilePresignReturnValue = MpcJSON.presignAuthFailed
    let manager = makeManager(credentials: session, maxPresignaturesPerCurve: [.SECP256K1: 3], retryConfig: .fast)

    // and given
    manager.initializeBuffers()

    // then
    let reported = await waitUntil { recorder.count == 1 }
    XCTAssertTrue(reported, "The host should have been told the session ended.")
    let remaining = try await keychainSpy.getPresignatures("SECP256K1")
    XCTAssertEqual(remaining.count, 1, "A credential stop must not discard presignatures that are still usable.")
    XCTAssertGreaterThanOrEqual(keychainSpy.cleanupExpiredPresignaturesCallCount, 1)
    XCTAssertEqual(keychainSpy.deletePresignaturesCallCount, 0)
    withExtendedLifetime(manager) {}
  }
}

// MARK: - Credentials: consume, fill-lock and cancellation

extension PresignatureManagerTests {
  func test_consumePresignature_willStillReturnEntry_afterCredentialStop() async throws {
    // given
    let entry = PresignatureEntry(id: "presig-1", expiresAt: "2099-01-01T00:00:00Z", data: "data")
    try await keychainSpy.insertPresignature("SECP256K1", entry)

    let session = MockPortalSession()
    try session.invalidate()
    mobileSpy.mobilePresignReturnValue = mockPresignResponse()
    let manager = makeManager(credentials: session, maxPresignaturesPerCurve: [.SECP256K1: 3])

    // and given
    let consumed = await manager.consumePresignature(forCurve: .SECP256K1)

    // then
    XCTAssertEqual(consumed, entry, "An already-generated presignature is still served; the signer surfaces the rejection later.")
    let refilled = await waitUntil(timeout: 0.3) { self.mobileSpy.mobilePresignCallsCount > 0 }
    XCTAssertFalse(refilled, "The refill triggered by the consume must stop at the dead credential.")
    withExtendedLifetime(manager) {}
  }

  func test_fillBuffer_willReleaseFillLock_afterCredentialStop() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "")
    mobileSpy.mobilePresignReturnValue = mockPresignResponse()
    let manager = makeManager(credentials: credentials, maxPresignaturesPerCurve: [.SECP256K1: 1])

    manager.initializeBuffers()
    let stopped = await waitUntil { credentials.getTokenCalls == 1 }
    XCTAssertTrue(stopped, "The first fill should have stopped on the blank token.")

    // and given
    credentials.tokenValue = "test-api-key"

    // then: a later fill must be able to take the lock the stopped one released
    var presigned = false
    for _ in 0 ..< 5 where !presigned {
      manager.initializeBuffers()
      presigned = await waitUntil(timeout: 0.3) { self.mobileSpy.mobilePresignCallsCount > 0 }
    }
    XCTAssertTrue(presigned, "The fill lock must be released even when the fill returns early on a credential failure.")
    withExtendedLifetime(manager) {}
  }

  func test_fillBuffer_willReturnNil_whenCancelledWhileResolvingToken() async throws {
    // given
    let gate = DispatchSemaphore(value: 0)
    let credentials = MockCredentials(tokenValue: "test-api-key", onGetToken: { gate.wait() })
    mobileSpy.mobilePresignReturnValue = mockPresignResponse()
    let manager = makeManager(credentials: credentials, maxPresignaturesPerCurve: [.SECP256K1: 1])

    manager.initializeBuffers()
    let resolving = await waitUntil { credentials.getTokenCalls == 1 }
    XCTAssertTrue(resolving, "The refill should be parked inside the credential provider.")

    // and given
    await manager.deleteAll()
    gate.signal()

    // then
    let reachedBinary = await waitUntil(timeout: 0.3) { self.mobileSpy.mobilePresignCallsCount > 0 }
    XCTAssertFalse(reachedBinary, "A cancellation observed during credential I/O must not become a network round trip.")
    XCTAssertEqual(credentials.getTokenCalls, 1)
    XCTAssertEqual(keychainSpy.insertPresignatureCallCount, 0)
    withExtendedLifetime(manager) {}
  }

  func test_deleteAll_willNotResolveCredentials() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "test-api-key")
    let manager = makeManager(credentials: credentials)

    // and given
    await manager.deleteAll()

    // then
    XCTAssertEqual(credentials.getTokenCalls, 0, "Deleting presignatures is local work and needs no credential.")
    XCTAssertEqual(keychainSpy.deletePresignaturesCallCount, 1)
  }
}

// MARK: - Credentials: security and the deprecated initializer

extension PresignatureManagerTests {
  func test_fillBuffer_willNotLogToken() async throws {
    // given: the AUTH_FAILED path
    let secret = "tok-secret"
    let session = MockPortalSession(tokenValue: secret)
    let recorder = InvalidationListenerRecorder(credentials: session)
    mobileSpy.mobilePresignReturnValue = MpcJSON.presignAuthFailed
    let authFailedManager = makeManager(credentials: session, maxPresignaturesPerCurve: [.SECP256K1: 3], retryConfig: .fast)

    authFailedManager.initializeBuffers()
    let reported = await waitUntil { recorder.count == 1 }
    XCTAssertTrue(reported, "The host should have been told the session ended.")

    // and given: the generic retry path
    let credentials = MockCredentials(tokenValue: secret)
    mobileSpy.mobilePresignReturnValue = MpcJSON.presignError(id: "ERR")
    let retryManager = makeManager(
      credentials: credentials,
      maxPresignaturesPerCurve: [.SECP256K1: 1],
      retryConfig: Self.threeAttempts
    )

    retryManager.initializeBuffers()
    let exhausted = await waitUntil { self.mobileSpy.mobilePresignCallsCount >= 4 }
    XCTAssertTrue(exhausted, "Both paths should have run before the log is inspected.")

    // then
    recordingLogger.assertNoSecret(secret)
    withExtendedLifetime(authFailedManager) {}
    withExtendedLifetime(retryManager) {}
  }

  func test_init_apiKey_deprecated_willStillPresign() async throws {
    // given
    mobileSpy.mobilePresignReturnValue = mockPresignResponse()
    let manager = PresignatureManager(
      apiKey: "legacy",
      mpcHost: "mpc.test.io",
      binary: mobileSpy,
      keychain: keychainSpy,
      maxPresignaturesPerCurve: [.SECP256K1: 1],
      featureFlags: FeatureFlags(usePresignatures: true),
      retryConfig: .fast
    )

    // and given
    manager.initializeBuffers()

    // then
    let stored = await waitUntil { self.keychainSpy.insertPresignatureCallCount == 1 }
    XCTAssertTrue(stored, "The deprecated Client API Key initializer must keep working.")
    XCTAssertEqual(mobileSpy.mobilePresignApiKeyParam, "legacy")
    withExtendedLifetime(manager) {}
  }
}

// MARK: - Local test doubles

/// A host-provider failure that is not a `PortalCredentialError`, so the SDK has to normalise it
/// to `.providerFailure` at the credential boundary.
private struct PresignProviderFailure: LocalizedError {
  var errorDescription: String? {
    "The host credential provider failed."
  }
}
