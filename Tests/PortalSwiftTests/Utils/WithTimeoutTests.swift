//
//  WithTimeoutTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
import XCTest

/// Pins the one property `withTimeout(_:_:)` exists for: the caller resumes at the deadline
/// even when the operation can never be cancelled. A task-group implementation passes the first
/// two cases and hangs on the third, which is how a regression here would show up as a stuck
/// suite rather than a red test.
final class WithTimeoutTests: XCTestCase {
  func test_withTimeout_willReturnValue_whenOperationFinishesFirst() async throws {
    let value = try await withTimeout(2) { 42 }

    XCTAssertEqual(value, 42)
  }

  func test_withTimeout_willPropagateError_whenOperationThrowsFirst() async {
    struct Boom: Error, Equatable {}

    await XCTAssertThrowsAsync(
      try await withTimeout(2) { () -> Int in throw Boom() },
      expected: Boom()
    )
  }

  func test_withTimeout_willReturnNil_whenOperationIgnoresCancellation() async throws {
    // A never-opened gate parks the operation in a non-throwing continuation, exactly the shape
    // `AsyncMutex.acquire` has: cancelling the task does nothing to it.
    let gate = AsyncGate()
    let started = Date()

    let value = try await withTimeout(0.2) { () -> Bool in
      await gate.wait()
      return true
    }

    XCTAssertNil(value, "The deadline, not the operation, decides when the caller resumes")
    XCTAssertLessThan(Date().timeIntervalSince(started), 2, "The caller was not held for longer than the deadline")
    XCTAssertEqual(gate.waiterCount, 1, "The stuck operation is left parked rather than awaited")

    // Release the leaked task so it does not outlive the case.
    gate.open()
  }

  func test_withTimeout_willIgnoreLateResult_afterDeadline() async throws {
    // Once the deadline has resolved the call, the operation finishing later must not resume the
    // caller a second time (a double resume traps in a checked continuation).
    let gate = AsyncGate()

    let value = try await withTimeout(0.1) { () -> Int in
      await gate.wait()
      return 7
    }
    gate.open()
    let released = await waitUntil { gate.waiterCount == 0 }

    XCTAssertNil(value)
    XCTAssertTrue(released, "The late operation ran to completion without affecting the settled call")
  }
}
