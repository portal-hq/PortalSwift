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
