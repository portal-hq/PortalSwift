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
  private var mobileSpy: MobileSpy!
  private var keychainSpy: PortalKeychainSpy!

  private func makeManager(
    maxPresignaturesPerCurve: [PresignatureSupportedCurve: Int] = [.SECP256K1: 3],
    featureFlags: FeatureFlags? = FeatureFlags(usePresignatures: true),
    retryConfig: PresignRetryConfig = .fast
  ) -> PresignatureManager {
    PresignatureManager(
      apiKey: "test-api-key",
      mpcHost: "mpc.test.io",
      binary: mobileSpy,
      keychain: keychainSpy,
      maxPresignaturesPerCurve: maxPresignaturesPerCurve,
      featureFlags: featureFlags,
      retryConfig: retryConfig
    )
  }

  private func mockPresignResponse(id: String = "presig-1") -> String {
    let response = PresignResponse(
      id: id,
      expiresAt: "2099-01-01T00:00:00Z",
      data: "mock-presig-data-\(id)",
      error: nil
    )
    let data = try! JSONEncoder().encode(response)
    return String(data: data, encoding: .utf8)!
  }

  override func setUpWithError() throws {
    mobileSpy = MobileSpy()
    keychainSpy = PortalKeychainSpy()
    keychainSpy.getSharesReturnValue = [
      "SECP256K1": PortalMpcGeneratedShare(id: "mock-share-id", share: "mock-share-data")
    ]
  }

  override func tearDownWithError() throws {
    mobileSpy = nil
    keychainSpy = nil
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
    XCTAssertEqual(config.maxAttempts, 6)
    XCTAssertEqual(config.baseDelayNs, 2_000_000_000)
    XCTAssertEqual(config.multiplier, 2.0)
    XCTAssertEqual(config.maxDelayNs, 3_600_000_000_000)
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
