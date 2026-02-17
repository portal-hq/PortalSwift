//
//  SecurityTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

@testable import PortalSwift
import XCTest

final class SecurityTests: XCTestCase {
  // MARK: - Initialization Tests

  func testInit_createsHypernativeInstance() {
    // Given
    let apiMock = PortalApiMock()

    // When
    let security = Security(api: apiMock)

    // Then
    XCTAssertNotNil(security.hypernative)
  }

  func testHypernative_isAccessibleAfterInit() {
    // Given
    let apiMock = PortalApiMock()
    let security = Security(api: apiMock)

    // When/Then
    XCTAssertNotNil(security.hypernative)
  }
}
