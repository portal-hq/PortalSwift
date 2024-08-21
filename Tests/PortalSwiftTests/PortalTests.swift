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
    var api: PortalApi!
    var binary: MockMobileWrapper!
    var keychain: MockPortalKeychain!

  override func setUpWithError() throws {
      api = PortalApi(apiKey: MockConstants.mockApiKey, requests: MockPortalRequests())
      binary = MockMobileWrapper()
      keychain = MockPortalKeychain()
      
    self.portal = try Portal(
      MockConstants.mockApiKey,
      withRpcConfig: ["eip155:11155111": "https://\(MockConstants.mockHost)/test-rpc"],
      api: api,
      binary: binary,
      gDrive: MockGDriveStorage(),
      iCloud: MockICloudStorage(),
      keychain: keychain,
      mpc: MockPortalMpc(),
      passwords: MockPasswordStorage()
    )
  }

  override func tearDownWithError() throws {
    self.portal = nil
  }

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

    func test_createWallet_will_call_mpc_generate_onlyOneTime() async throws {
        // given
        let portalMpcSpy = PortalMpcSpy()
        self.portal = try Portal(
          MockConstants.mockApiKey,
          withRpcConfig: ["eip155:11155111": "https://\(MockConstants.mockHost)/test-rpc"],
          api: api,
          binary: binary,
          gDrive: MockGDriveStorage(),
          iCloud: MockICloudStorage(),
          keychain: keychain,
          mpc: portalMpcSpy,
          passwords: MockPasswordStorage()
        )

        // and given
        _ = try await portal.createWallet()

        // then
        XCTAssertEqual(portalMpcSpy.generateCallsCount, 1)
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
