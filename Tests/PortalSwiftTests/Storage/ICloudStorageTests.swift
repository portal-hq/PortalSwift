//
//  ICloudStorageTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

@testable import PortalSwift
import XCTest

final class ICloudStorageTests: XCTestCase {
  var storage = ICloudStorage(isMocked: true)

  override func setUpWithError() throws {
    self.storage.api = PortalApi(apiKey: MockConstants.mockApiKey, isMocked: true)
  }

  override func tearDownWithError() throws {}

  func testDelete() async throws {
    let expectation = XCTestExpectation(description: "ICloudStorage.delete()")
    let success = try await storage.delete()
    XCTAssertTrue(success)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testRead() async throws {
    let expectation = XCTestExpectation(description: "ICloudStorage.read()")
    let result = try await storage.read()
    XCTAssertEqual(result, MockConstants.mockEncryptionKey)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testValidateOperations() async throws {
    let expectation = XCTestExpectation(description: "ICloudStorage.write()")
    let success = try await storage.validateOperations()
    XCTAssertTrue(success)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testWrite() async throws {
    let expectation = XCTestExpectation(description: "ICloudStorage.write()")
    let success = try await storage.write(MockConstants.mockEncryptionKey)
    XCTAssertTrue(success)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }
}
