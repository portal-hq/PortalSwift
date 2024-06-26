//
//  PortalTests.swift
//
//
//  Created by Blake Williams on 3/30/24.
//

@testable import PortalSwift
import XCTest

class PortalTests: XCTestCase {
  var portal: Portal!
  override func setUpWithError() throws {
    let api = PortalApi(apiKey: MockConstants.mockApiKey, requests: MockPortalRequests())
    let binary = MockMobileWrapper()
    let keychain = MockPortalKeychain()

    self.portal = try Portal(
      MockConstants.mockApiKey,
      withRpcConfig: ["eip155:11155111": "https://\(MockConstants.mockHost)/test-rpc"],
      api: api,
      binary: binary,
      gDrive: MockGDriveStorage(),
      iCloud: MockICloudStorage(),
      keychain: keychain,
      mpc: MockPortalMpc(apiKey: MockConstants.mockApiKey, api: api, keychain: keychain, mobile: binary),
      passwords: MockPasswordStorage()
    )
  }

  override func tearDownWithError() throws {}

  func testBackupWallet() async throws {
    let expectation = XCTestExpectation(description: "Portal.backupWallet(backupMethod)")
    var statusUpdates: Set<MpcStatuses> = Set()
    try portal.setPassword(MockConstants.mockEncryptionKey)
    let (cipherText, storageCallback) = try await portal.backupWallet(.Password) { status in
      statusUpdates.insert(status.status)
    }
    XCTAssertEqual(cipherText, MockConstants.mockCiphertext)
    XCTAssertNotNil(storageCallback)
    XCTAssertTrue(statusUpdates.count > 0)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testCreateWallet() async throws {
    let expectation = XCTestExpectation(description: "Portal.createWallet()")
    var statusUpdates: Set<MpcStatuses> = Set()
    let (ethereum, solana) = try await portal.createWallet { status in
      statusUpdates.insert(status.status)
    }
    XCTAssertEqual(ethereum, MockConstants.mockEip155Address)
    XCTAssertEqual(solana, MockConstants.mockSolanaAddress)
    XCTAssertTrue(statusUpdates.count > 0)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testRecoverWallet() async throws {
    let expectation = XCTestExpectation(description: "Portal.backupWallet(backupMethod, cipherText)")
    var statusUpdates: Set<MpcStatuses> = Set()
    try portal.setPassword(MockConstants.mockEncryptionKey)
    let (ethereum, solana) = try await portal.recoverWallet(
      .Password,
      withCipherText: MockConstants.mockCiphertext
    ) { status in
      statusUpdates.insert(status.status)
    }
    XCTAssertEqual(ethereum, MockConstants.mockEip155Address)
    XCTAssertEqual(solana, MockConstants.mockSolanaAddress)
    XCTAssertTrue(statusUpdates.count > 0)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }
}
