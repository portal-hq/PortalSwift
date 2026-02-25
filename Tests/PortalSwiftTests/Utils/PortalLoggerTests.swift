//
//  PortalLoggerTests.swift
//
//  Created by Portal Labs, Inc.
//

@testable import PortalSwift
import XCTest

final class PortalLoggerTests: XCTestCase {
  override func setUp() {
    super.setUp()
    PortalLogger.shared.setLogLevel(.none)
  }

  override func tearDown() {
    PortalLogger.shared.setLogLevel(.none)
    super.tearDown()
  }

  // MARK: - Singleton

  func testSharedReturnsSameInstance() {
    let a = PortalLogger.shared
    let b = PortalLogger.shared
    XCTAssertTrue(a === b)
  }

  // MARK: - Default level

  func testDefaultLogLevelIsNone() {
    PortalLogger.shared.setLogLevel(.none)
    XCTAssertEqual(PortalLogger.shared.logLevel, .none)
  }

  // MARK: - setLogLevel persists

  func testSetLogLevelChangesLevel() {
    PortalLogger.shared.setLogLevel(.debug)
    XCTAssertEqual(PortalLogger.shared.logLevel, .debug)

    PortalLogger.shared.setLogLevel(.error)
    XCTAssertEqual(PortalLogger.shared.logLevel, .error)

    PortalLogger.shared.setLogLevel(.none)
    XCTAssertEqual(PortalLogger.shared.logLevel, .none)
  }

  // MARK: - Hierarchical ordering (Comparable)

  func testLogLevelHierarchy() {
    XCTAssertTrue(PortalLogLevel.none < .error)
    XCTAssertTrue(PortalLogLevel.error < .warn)
    XCTAssertTrue(PortalLogLevel.warn < .info)
    XCTAssertTrue(PortalLogLevel.info < .debug)
  }

  func testLogLevelComparableTransitive() {
    XCTAssertTrue(PortalLogLevel.none < .debug)
    XCTAssertTrue(PortalLogLevel.error < .info)
    XCTAssertTrue(PortalLogLevel.warn < .debug)
  }

  func testLogLevelEquality() {
    XCTAssertEqual(PortalLogLevel.info, .info)
    XCTAssertNotEqual(PortalLogLevel.info, .debug)
  }

  // MARK: - Level includes everything above

  func testDebugLevelIncludesAllLevels() {
    XCTAssertTrue(PortalLogLevel.debug >= .debug)
    XCTAssertTrue(PortalLogLevel.debug >= .info)
    XCTAssertTrue(PortalLogLevel.debug >= .warn)
    XCTAssertTrue(PortalLogLevel.debug >= .error)
    XCTAssertTrue(PortalLogLevel.debug >= .none)
  }

  func testInfoLevelExcludesDebug() {
    XCTAssertTrue(PortalLogLevel.info >= .info)
    XCTAssertTrue(PortalLogLevel.info >= .warn)
    XCTAssertTrue(PortalLogLevel.info >= .error)
    XCTAssertFalse(PortalLogLevel.info >= .debug)
  }

  func testWarnLevelExcludesInfoAndDebug() {
    XCTAssertTrue(PortalLogLevel.warn >= .warn)
    XCTAssertTrue(PortalLogLevel.warn >= .error)
    XCTAssertFalse(PortalLogLevel.warn >= .info)
    XCTAssertFalse(PortalLogLevel.warn >= .debug)
  }

  func testErrorLevelExcludesWarnInfoDebug() {
    XCTAssertTrue(PortalLogLevel.error >= .error)
    XCTAssertFalse(PortalLogLevel.error >= .warn)
    XCTAssertFalse(PortalLogLevel.error >= .info)
    XCTAssertFalse(PortalLogLevel.error >= .debug)
  }

  func testNoneLevelExcludesEverything() {
    XCTAssertFalse(PortalLogLevel.none >= .error)
    XCTAssertFalse(PortalLogLevel.none >= .warn)
    XCTAssertFalse(PortalLogLevel.none >= .info)
    XCTAssertFalse(PortalLogLevel.none >= .debug)
  }

  // MARK: - Thread safety

  func testConcurrentSetAndGetLogLevel() {
    let iterations = 1000
    let expectation = XCTestExpectation(description: "Concurrent log level access completes without crash")
    expectation.expectedFulfillmentCount = iterations * 2

    let levels: [PortalLogLevel] = [.none, .error, .warn, .info, .debug]

    for _ in 0 ..< iterations {
      DispatchQueue.global().async {
        PortalLogger.shared.setLogLevel(levels.randomElement()!)
        expectation.fulfill()
      }
      DispatchQueue.global().async {
        _ = PortalLogger.shared.logLevel
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 10.0)
  }

  // MARK: - Log methods don't crash at any level

  func testLogMethodsDoNotCrashWhenLevelIsNone() {
    PortalLogger.shared.setLogLevel(.none)
    PortalLogger.shared.debug("debug message")
    PortalLogger.shared.info("info message")
    PortalLogger.shared.warn("warn message")
    PortalLogger.shared.error("error message")
  }

  func testLogMethodsDoNotCrashWhenLevelIsDebug() {
    PortalLogger.shared.setLogLevel(.debug)
    PortalLogger.shared.debug("debug message")
    PortalLogger.shared.info("info message")
    PortalLogger.shared.warn("warn message")
    PortalLogger.shared.error("error message")
  }

  // MARK: - Raw values

  func testRawValues() {
    XCTAssertEqual(PortalLogLevel.none.rawValue, 0)
    XCTAssertEqual(PortalLogLevel.error.rawValue, 1)
    XCTAssertEqual(PortalLogLevel.warn.rawValue, 2)
    XCTAssertEqual(PortalLogLevel.info.rawValue, 3)
    XCTAssertEqual(PortalLogLevel.debug.rawValue, 4)
  }
}
