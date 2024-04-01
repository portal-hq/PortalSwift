//
//  PasskeyStorageTests.swift
//
//
//  Created by Blake Williams on 3/31/24.
//

@testable import PortalSwift
import XCTest

@available(iOS 16, *)
final class PasskeyStorageTests: XCTestCase {
  let storage = PasskeyStorage(isMocked: true)

  override func setUpWithError() throws {
    self.storage.apiKey = MockConstants.mockApiKey
    self.storage.api = PortalApi(apiKey: MockConstants.mockApiKey, isMocked: true)
  }

  override func tearDownWithError() throws {}

  func testRead() async throws {
    let expectation = XCTestExpectation(description: "PasskeyStorage.write(value)")
    let result = try await storage.read()
    XCTAssertEqual(result, MockConstants.mockEncryptionKey)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testSignIn() async throws {
    let expectation = XCTestExpectation(description: "PasskeyStorage.write(value)")

    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testValidateOperations() async throws {}

  func testWrite() async throws {
    let expectation = XCTestExpectation(description: "PasskeyStorage.write(value)")
    let success = try await storage.write(MockConstants.mockEncryptionKey)
    XCTAssertTrue(success)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }
}
