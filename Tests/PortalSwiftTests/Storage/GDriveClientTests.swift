//
//  GDriveClientTests.swift
//
//
//  Created by Blake Williams on 3/31/24.
//

import GoogleSignIn
@testable import PortalSwift
import XCTest

final class GDriveClientTests: XCTestCase {
  var client: GDriveClient = .init(requests: MockPortalRequests())

  override func setUpWithError() throws {
    self.client.auth = MockGoogleAuth(config: GIDConfiguration(clientID: MockConstants.mockGDriveClientId))
  }

  override func tearDownWithError() throws {}

  func testDelete() async throws {
    let expectation = XCTestExpectation(description: "GDriveClient.delete(id)")
    let success = try await client.delete(MockConstants.mockGDriveFileId)
    XCTAssertTrue(success)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testGetIdForFilename() async throws {
    let expectation = XCTestExpectation(description: "GDriveClient.getIdForFilename(filename)")
    let fileId = try await client.getIdForFilename(MockConstants.mockGDriveFileName)
    XCTAssertEqual(fileId, MockConstants.mockGDriveFileId)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testRead() async throws {
    let expectation = XCTestExpectation(description: "GDriveClient.read(id)")
    let response = try await client.read(MockConstants.mockGDriveFileId)
    XCTAssertEqual(response, MockConstants.mockEncryptionKey)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testWrite() async throws {
    let expectation = XCTestExpectation(description: "GDriveClient.write()")
    let success = try await client.write(MockConstants.mockEncryptionKey, withContent: MockConstants.mockEncryptionKey)
    XCTAssertTrue(success)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }
}
