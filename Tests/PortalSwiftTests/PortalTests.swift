//
//  PortalTests.swift
//
//
//  Created by Blake Williams on 3/30/24.
//

@testable import PortalSwift
import AnyCodable
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

    func setToPortal(portalProvider: PortalProviderProtocol) {
        self.portal.provider = portalProvider
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

// MARK: - Backup tests
extension PortalTests {
    func test_registerBackupMethod_willCall_mpc_registerBackupMethod_onlyOnce() async throws {
        // given
        let portalMpcSpy = PortalMpcSpy()
        try initPortalWithSpy(portalMpc: portalMpcSpy)

        // and given
        // reset the `registerBackupMethodCallsCount` since the Portal init is calling registerBackupMethod to register the default backup methods
        portalMpcSpy.registerBackupMethodCallsCount = 0
        
        // and given
        portal.registerBackupMethod(.iCloud, withStorage: ICloudStorage())

        // then
        XCTAssertEqual(portalMpcSpy.registerBackupMethodCallsCount, 1)
    }

    func test_setGDriveConfiguration_willCall_mpc_setGDriveConfiguration_onlyOnce() async throws {
        // given
        let portalMpcSpy = PortalMpcSpy()
        try initPortalWithSpy(portalMpc: portalMpcSpy)

        // and given
        try portal.setGDriveConfiguration(clientId: MockConstants.mockClientId)

        // then
        XCTAssertEqual(portalMpcSpy.setGDriveConfigurationCallsCount, 1)
    }

    func test_setGDriveView_willCall_mpc_setGDriveView_onlyOnce() async throws {
        // given
        let portalMpcSpy = PortalMpcSpy()
        try initPortalWithSpy(portalMpc: portalMpcSpy)

        // and given
        try await portal.setGDriveView(UIViewController())

        // then
        XCTAssertEqual(portalMpcSpy.setGDriveViewCallsCount, 1)
    }

    @available(iOS 16, *)
    func test_setPasskeyAuthenticationAnchor_willCall_mpc_setPasskeyAuthenticationAnchor_onlyOnce() async throws {
        // given
        let portalMpcSpy = PortalMpcSpy()
        try initPortalWithSpy(portalMpc: portalMpcSpy)

        // and given
        try await portal.setPasskeyAuthenticationAnchor(UIWindow())

        // then
        XCTAssertEqual(portalMpcSpy.setPasskeyAuthenticationAnchorCallsCount, 1)
    }

    @available(iOS 16, *)
    func test_setPasskeyConfiguration_willCall_mpc_setPasskeyConfiguration_onlyOnce() async throws {
        // given
        let portalMpcSpy = PortalMpcSpy()
        try initPortalWithSpy(portalMpc: portalMpcSpy)

        // and given
        try portal.setPasskeyConfiguration(relyingParty: "", webAuthnHost: "")

        // then
        XCTAssertEqual(portalMpcSpy.setPasskeyConfigurationCallsCount, 1)
    }

    func test_setPassword_willCall_mpc_setPassword_onlyOnce() async throws {
        // given
        let portalMpcSpy = PortalMpcSpy()
        try initPortalWithSpy(portalMpc: portalMpcSpy)

        // and given
        try portal.setPassword("")

        // then
        XCTAssertEqual(portalMpcSpy.setPasswordCallsCount, 1)
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

    func test_backupWallet_calling_storageCallback_willCall_api_updateShareStatus() async throws {
        // given
        let portalApiSpy = PortalApiSpy()
        try initPortalWithSpy(api: portalApiSpy)
        
        // and given
        let (_, storageCallback) = try await portal.backupWallet(.Password)

        // and given
        try await storageCallback()

        // then
        XCTAssertEqual(portalApiSpy.updateShareStatusCallsCount, 1)
        
    }
}

// MARK: - Recover tests
extension PortalTests {
    func testRecoverWallet() async throws {
      let expectation = XCTestExpectation(description: "Portal.recoverWallet(backupMethod, cipherText)")
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

    func test_recoverWallet_willCall_mpc_recover_onlyOnce() async throws {
        // given
        let portalMpcSpy = PortalMpcSpy()
        try initPortalWithSpy(portalMpc: portalMpcSpy)

        // and given
        _ = try await portal.recoverWallet(.iCloud)
        
        // then
        XCTAssertEqual(portalMpcSpy.recoverCallsCount, 1)
    }

    func test_recoverWallet_willCall_mpc_recover_passingCorrectParams() async throws {
        // given
        let portalMpcSpy = PortalMpcSpy()
        try initPortalWithSpy(portalMpc: portalMpcSpy)

        // and given
        _ = try await portal.recoverWallet(.Password, withCipherText: "123")
        
        // then
        XCTAssertEqual(portalMpcSpy.recoverMethodParam, .Password)
        XCTAssertEqual(portalMpcSpy.recoverCipherTextParam, "123")
    }

    func test_provisionWallet_willCall_mpc_recover_onlyOnce() async throws {
        // given
        let portalMpcSpy = PortalMpcSpy()
        try initPortalWithSpy(portalMpc: portalMpcSpy)

        // and given
        _ = portal.provisionWallet(cipherText: "", method: "ICLOUD", completion: { _ in })
        
        // then
        XCTAssertEqual(portalMpcSpy.recoverWithCompletionCallsCount, 1)
    }
}

// MARK: - Eject tests
extension PortalTests {
    func test_eject_willCall_mpc_eject_onlyOnce() async throws {
        // given
        let portalMpcSpy = PortalMpcSpy()
        try initPortalWithSpy(portalMpc: portalMpcSpy)

        // and given
        _ = try await portal.eject(.iCloud)

        // then
        XCTAssertEqual(portalMpcSpy.ejectCallsCount, 1)
    }

    func test_eject_willCall_mpc_eject_passingCorrectParams() async throws {
        // given
        let portalMpcSpy = PortalMpcSpy()
        try initPortalWithSpy(portalMpc: portalMpcSpy)

        // and given
        _ = try await portal.eject(
            .iCloud,
            withCipherText: MockConstants.mockCiphertext,
            andOrganizationBackupShare: ""
        )

        // then
        XCTAssertEqual(portalMpcSpy.ejectMethodParam, .iCloud)
        XCTAssertEqual(portalMpcSpy.ejectCipherTextParam, MockConstants.mockCiphertext)
        XCTAssertEqual(portalMpcSpy.ejectOrganizationBackupShareParam, "")
        XCTAssertNil(portalMpcSpy.ejectOrganizationSolanaBackupShareParam)
    }

    func test_ejectPrivateKeys_willCall_mpc_eject_onlyOnce() async throws {
        // given
        let portalMpcSpy = PortalMpcSpy()
        try initPortalWithSpy(portalMpc: portalMpcSpy)

        // and given
        _ = try await portal.ejectPrivateKeys(.iCloud)

        // then
        XCTAssertEqual(portalMpcSpy.ejectCallsCount, 1)
    }

    func test_ejectPrivateKeys_willCall_mpc_eject_passingCorrectParams() async throws {
        // given
        let portalMpcSpy = PortalMpcSpy()
        try initPortalWithSpy(portalMpc: portalMpcSpy)

        // and given
        _ = try await portal.ejectPrivateKeys(
            .Passkey,
            withCipherText: MockConstants.mockCiphertext,
            andOrganizationBackupShare: "123",
            andOrganizationSolanaBackupShare: "456"
        )

        // then
        XCTAssertEqual(portalMpcSpy.ejectMethodParam, .Passkey)
        XCTAssertEqual(portalMpcSpy.ejectCipherTextParam, MockConstants.mockCiphertext)
        XCTAssertEqual(portalMpcSpy.ejectOrganizationBackupShareParam, "123")
        XCTAssertEqual(portalMpcSpy.ejectOrganizationSolanaBackupShareParam, "456")
    }
}

// MARK: - Transaction tests
extension PortalTests {
    func test_getTransaction_willCall_api_getTransaction_onlyOnce() async throws {
        // given
        let portalApiSpy = PortalApiSpy()
        try initPortalWithSpy(api: portalApiSpy)
        
        // and given
        _ = try await portal.getTransactions("")
        
        // then
        XCTAssertEqual(portalApiSpy.getTransactionsCallsCount, 1)
    }

    func test_getTransaction_willCall_api_getTransaction_passingCorrectParams() async throws {
        // given
        let portalApiSpy = PortalApiSpy()
        try initPortalWithSpy(api: portalApiSpy)
        
        // and given
        _ = try await portal.getTransactions("12345", limit: 1, offset: 2, order: .ASC)
        
        // then
        XCTAssertEqual(portalApiSpy.getTransactionsChainIdParam, "12345")
        XCTAssertEqual(portalApiSpy.getTransactionsLimitParam, 1)
        XCTAssertEqual(portalApiSpy.getTransactionsOffsetParam, 2)
        XCTAssertEqual(portalApiSpy.getTransactionsOrderParam, .ASC)
    }

    func test_simulateTransaction_willCall_api_simulateTransaction_onlyOnce() async throws {
        // given
        let portalApiSpy = PortalApiSpy()
        try initPortalWithSpy(api: portalApiSpy)
        
        // and given
        _ = try await portal.simulateTransaction("54321", from: TransactionOrder.DESC)
        
        // then
        XCTAssertEqual(portalApiSpy.simulateTransactionCallsCount, 1)
    }

    func test_simulateTransaction_willCall_api_simulateTransaction_passingCorrectParams() async throws {
        // given
        let portalApiSpy = PortalApiSpy()
        try initPortalWithSpy(api: portalApiSpy)
        
        // and given
        _ = try await portal.simulateTransaction("54321", from: TransactionOrder.DESC)
        // then
        XCTAssertEqual(portalApiSpy.simulateTransactionWithChainIdParam, "54321")
        XCTAssertEqual((portalApiSpy.simulateTransactionTransactionParam as? AnyCodable)?.value as? TransactionOrder, AnyCodable(TransactionOrder.DESC).value as? TransactionOrder)
    }
}

// MARK: - Provider helpers tests
extension PortalTests {
    func test_emit_willCall_provider_emit_onlyOnce() async throws {
        // given
        let portalProviderSpy = PortalProviderSpy()
        setToPortal(portalProvider: portalProviderSpy)

        // and given
        portal.emit(Events.Connect.rawValue, data: "")

        XCTAssertEqual(portalProviderSpy.emitCallsCount, 1)
    }

    func test_emit_willCall_provider_emit_passingCorrectParams() async throws {
        // given
        let portalProviderSpy = PortalProviderSpy()
        setToPortal(portalProvider: portalProviderSpy)

        // and given
        portal.emit(Events.ChainChanged.rawValue, data: "123")

        XCTAssertEqual(portalProviderSpy.emitEventParam, Events.ChainChanged.rawValue)
        XCTAssertEqual(portalProviderSpy.emitDataParam as? String, "123")
    }

    func test_on_willCall_provider_on_onlyOnce() async throws {
        // given
        let portalProviderSpy = PortalProviderSpy()
        setToPortal(portalProvider: portalProviderSpy)

        // and given
        portal.on(event: Events.PortalSigningRequested.rawValue, callback: { _ in })

        XCTAssertEqual(portalProviderSpy.onCallsCount, 1)
    }

    func test_on_willCall_provider_on_passingCorrectParams() async throws {
        // given
        let portalProviderSpy = PortalProviderSpy()
        setToPortal(portalProvider: portalProviderSpy)

        // and given
        portal.on(event: Events.PortalConnectSigningRequested.rawValue, callback: { _ in })

        XCTAssertEqual(portalProviderSpy.onEventParam, Events.PortalConnectSigningRequested.rawValue)
    }

    func test_once_willCall_provider_once_onlyOnce() async throws {
        // given
        let portalProviderSpy = PortalProviderSpy()
        setToPortal(portalProvider: portalProviderSpy)

        // and given
        portal.once(event: Events.PortalSignatureReceived.rawValue, callback: { _ in })

        XCTAssertEqual(portalProviderSpy.onceCallsCount, 1)
    }

    func test_once_willCall_provider_once_passingCorrectParams() async throws {
        // given
        let portalProviderSpy = PortalProviderSpy()
        setToPortal(portalProvider: portalProviderSpy)

        // and given
        portal.once(event: Events.PortalSigningApproved.rawValue, callback: { _ in })

        XCTAssertEqual(portalProviderSpy.onceEventParam, Events.PortalSigningApproved.rawValue)
    }

    func test_request_willCall_provider_request_onlyOnce() async throws {
        // given
        let portalProviderSpy = PortalProviderSpy()
        setToPortal(portalProvider: portalProviderSpy)

        // and given
        _ = try await portal.request("", withMethod: "eth_accounts", andParams: [])

        XCTAssertEqual(portalProviderSpy.requestAsyncMethodCallsCount, 1)
    }

    func test_request_willThrowCorrectError_WhenPassingWrongMethod() async throws {
        // given
        let portalProviderSpy = PortalProviderSpy()
        setToPortal(portalProvider: portalProviderSpy)

        // and given
        let method = "wrong method"
        // and given
        do {
            _ = try await portal.request("", withMethod: method, andParams: [])
            XCTFail("Expected error not thrown when calling Poetal.request passing invalid method.")
        } catch {
            XCTAssertEqual(error as? PortalProviderError, PortalProviderError.unsupportedRequestMethod(method))
        }
    }

    func test_request_willThrowCorrectError_WhenPassingNilParams() async throws {
        // given
        let portalProviderSpy = PortalProviderSpy()
        setToPortal(portalProvider: portalProviderSpy)

        // and given
        do {
            _ = try await portal.request("", withMethod: .eth_call, andParams: nil)
            XCTFail("Expected error not thrown when calling Poetal.request passing invalid method.")
        } catch {
            XCTAssertEqual(error as? PortalProviderError, PortalProviderError.invalidRequestParams)
        }
    }

    func test_request_willCall_provider_request_passingCorrectParams() async throws {
        // given
        let portalProviderSpy = PortalProviderSpy()
        setToPortal(portalProvider: portalProviderSpy)

        // and given
        let method = "eth_accounts"
        _ = try await portal.request("123", withMethod: method, andParams: ["123", "321"])

        XCTAssertEqual(portalProviderSpy.requestAsyncMethodChainIdParam, "123")
        XCTAssertEqual(portalProviderSpy.requestAsyncMethodMethodParam, PortalRequestMethod(rawValue: method))
        XCTAssertEqual(portalProviderSpy.requestAsyncMethodParamsParam, ["123", "321"])
    }
}
