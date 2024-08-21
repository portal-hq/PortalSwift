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
    var keychain: MockPortalKeychain! // TODO: - abstract the `PortalKeychain`

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

// MARK: - Test Helpers
extension PortalTests {
    func initPortalWithSpy(portalMpc: PortalMpcProtocol? = nil, api: PortalApiProtocol? = nil) throws {
        self.portal = try Portal(
          MockConstants.mockApiKey,
          withRpcConfig: ["eip155:11155111": "https://\(MockConstants.mockHost)/test-rpc"],
          api: api ?? self.api,
          binary: binary,
          gDrive: MockGDriveStorage(),
          iCloud: MockICloudStorage(),
          keychain: keychain,
          mpc: portalMpc ?? MockPortalMpc(),
          passwords: MockPasswordStorage()
        )
    }
}

// MARK: - Create Wallet tests
extension PortalTests {
    func test_createWallet_will_call_mpc_generate_onlyOneTime() async throws {
        // given
        let portalMpcSpy = PortalMpcSpy()
        try initPortalWithSpy(portalMpc: portalMpcSpy)

        // and given
        _ = try await portal.createWallet()

        // then
        XCTAssertEqual(portalMpcSpy.generateCallsCount, 1)
    }

    func test_createWallet_will_return_ethereumAndSolanaAddresses() async throws {
        // given
        let (eth, sol) = try await portal.createWallet()

        // then
        XCTAssertEqual(eth, MockConstants.mockEip155Address)
        XCTAssertEqual(sol, MockConstants.mockSolanaAddress)
    }

    func test_createSolanaWallet_will_call_mpc_generateSolanaWallet_onlyOneTime() async throws {
        // given
        let portalMpcSpy = PortalMpcSpy()
        try initPortalWithSpy(portalMpc: portalMpcSpy)

        // and given
        _ = try await portal.createSolanaWallet()

        // then
        XCTAssertEqual(portalMpcSpy.generateSolanaWalletCallsCount, 1)
    }

    func test_createSolanaWallet_will_return_solanaAddress() async throws {
        // given
        let solanaAddress = try await portal.createSolanaWallet()

        // then
        XCTAssertEqual(solanaAddress, MockConstants.mockSolanaAddress)
    }
}

// MARK: - Generate Solana and backup shares tests
extension PortalTests {
    func test_generateSolanaWalletAndBackupShares_willCall_mpc_generateSolanaWalletAndBackupShares_onlyOneTime() async throws {
        // given
        let portalMpcSpy = PortalMpcSpy()
        try initPortalWithSpy(portalMpc: portalMpcSpy)

        // and given
        _ = try await portal.generateSolanaWalletAndBackupShares(.iCloud)
        
        // then
        XCTAssertEqual(portalMpcSpy.generateSolanaWalletAndBackupSharesCallsCount, 1)
    }

    func test_generateSolanaWalletAndBackupShares_willCall_mpc_generateSolanaWalletAndBackupShares_passingCorrectParams() async throws {
        // given
        let portalMpcSpy = PortalMpcSpy()
        try initPortalWithSpy(portalMpc: portalMpcSpy)

        // and given
        _ = try await portal.generateSolanaWalletAndBackupShares(.iCloud)
        
        // then
        XCTAssertEqual(portalMpcSpy.generateSolanaWalletAndBackupSharesBackupMethodParam, .iCloud)
    }

    func test_generateSolanaWalletAndBackupShares_willReturn_correctValues() async throws {
        // given
        let (solanaAddress, cipherText, _) = try await portal.generateSolanaWalletAndBackupShares(.iCloud)

        // then
        XCTAssertEqual(solanaAddress, MockConstants.mockSolanaAddress)
        XCTAssertEqual(cipherText, MockConstants.mockCiphertext)
    }

    func test_generateSolanaWalletAndBackupShares_calling_storageCallback_willCall_api_updateShareStatus() async throws {
        // given
        let portalApiSpy = PortalApiSpy()
        try initPortalWithSpy(api: portalApiSpy)
        
        // and given
        let (_, _, storageCallback) = try await portal.generateSolanaWalletAndBackupShares(.iCloud)

        // and given
        try await storageCallback()

        // then
        XCTAssertEqual(portalApiSpy.updateShareStatusCallsCount, 1)
        
    }
}
