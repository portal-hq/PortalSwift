//
//  GDriveStorageTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

@testable import PortalSwift
import XCTest

final class GDriveStorageTests: XCTestCase {
  var storage = GDriveStorage(encryption: MockPortalEncryption(), driveClient: MockGDriveClient())

  override func setUpWithError() throws {
    self.storage.api = PortalApi(apiKey: MockConstants.mockApiKey, requests: MockPortalRequests())
  }

  override func tearDownWithError() throws {}

  func testDelete() async throws {
    let expectation = XCTestExpectation(description: "GDriveStorage.write(value)")
    let success = try await storage.delete()
    XCTAssertTrue(success)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testRead() async throws {
    let expectation = XCTestExpectation(description: "GDriveStorage.write(value)")
    let result = try await storage.read()
    XCTAssertEqual(result, MockConstants.mockEncryptionKey)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testSignIn() async throws {
    let expectation = XCTestExpectation(description: "GDriveStorage.write(value)")

    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testValidateOperations() async throws {}

  func testWrite() async throws {
    let expectation = XCTestExpectation(description: "GDriveStorage.write(value)")
    let success = try await storage.write(MockConstants.mockEncryptionKey)
    XCTAssertTrue(success)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }
}
