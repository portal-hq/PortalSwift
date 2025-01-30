//
//  PortalTests.swift
//
//
//  Created by Blake Williams on 3/30/24.
//

import AnyCodable
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

// MARK: - Default RPC config tests

extension PortalTests {
  func test_buildDefaultRpcConfig() async throws {
    let apiHost = "api.portalhq.io"
    let newPortal = try Portal(
      MockConstants.mockApiKey,
      withRpcConfig: [:],
      apiHost: apiHost,
      api: api ?? self.api,
      binary: binary,
      gDrive: MockGDriveStorage(),
      iCloud: MockICloudStorage(),
      keychain: keychain,
      mpc: MockPortalMpc(),
      passwords: MockPasswordStorage()
    )

    XCTAssertEqual(
      newPortal.rpcConfig,
      [
        "eip155:1": "https://\(apiHost)/rpc/v1/eip155/1", // Ethereum Mainnet
        "eip155:137": "https://\(apiHost)/rpc/v1/eip155/137", // Polygon Mainnet
        "eip155:8453": "https://\(apiHost)/rpc/v1/eip155/8453", // Base Mainnet
        "eip155:80002": "https://\(apiHost)/rpc/v1/eip155/80002", // Polygon Amoy
        "eip155:84532": "https://\(apiHost)/rpc/v1/eip155/84532", // Base Testnet
        "eip155:11155111": "https://\(apiHost)/rpc/v1/eip155/11155111", // Ethereum Sepolia
        "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp": "https://\(apiHost)/rpc/v1/solana/5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp", // Solana Mainnet
        "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1": "https://\(apiHost)/rpc/v1/solana/EtWTRABZaYq6iMfeYKouRu166VU2xqa1" // Solana Testnet
      ]
    )
  }

  func test_createPortalConnectInstance() async throws {
    let portalConnect = try portal.createPortalConnectInstance()
    XCTAssertNotNil(portalConnect)
  }
}

// MARK: - Create Wallet tests

extension PortalTests {
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
    try initPortalWithSpy(portalMpc: portalMpcSpy)

    // and given
    _ = try await portal.createWallet()

    // then
    XCTAssertEqual(portalMpcSpy.generateCallsCount, 1)
  }

  func test_createWallet_willThrowCorrectError_whenFailToGenerateWallets() async throws {
    // given
    let portalMpcSpy = PortalMpcSpy()
    portalMpcSpy.generateResponse = [:]
    try initPortalWithSpy(portalMpc: portalMpcSpy)

    do {
      // and given
      _ = try await portal.createWallet()
      XCTFail("Expected error not thrown when calling Portal.createWallet when mpc return no wallets.")
    } catch {
      // then
      XCTAssertEqual(error as? PortalClassError, PortalClassError.cannotCreateWallet)
    }
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
    portal.provisionWallet(cipherText: "", method: "ICLOUD", completion: { _ in })

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
      XCTFail("Expected error not thrown when calling Portal.request passing invalid method.")
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
      XCTFail("Expected error not thrown when calling Portal.request passing invalid method.")
    } catch {
      // then
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

// MARK: - Balance, SigningShare & NFT Tests

extension PortalTests {
  func test_getBalance_willCall_api_getBalance_onlyOnce() async throws {
    // given
    let portalApiSpy = PortalApiSpy()
    try initPortalWithSpy(api: portalApiSpy)

    // and given
    _ = try await portal.getBalances("")

    // then
    XCTAssertEqual(portalApiSpy.getBalancesCallsCount, 1)
  }

  func test_getBalance_willCall_api_getBalance_passingCorrectParams() async throws {
    // given
    let portalApiSpy = PortalApiSpy()
    try initPortalWithSpy(api: portalApiSpy)

    // and given
    _ = try await portal.getBalances("123")

    // then
    XCTAssertEqual(portalApiSpy.getBalancesChainIdParam, "123")
  }

//  func test_getNFTs_willCall_api_getNFTs_onlyOnce() async throws {
//    // given
//    let portalApiSpy = PortalApiSpy()
//    try initPortalWithSpy(api: portalApiSpy)
//
//    // and given
//    _ = try await portal.getNFTs("")
//
//    // then
//    XCTAssertEqual(portalApiSpy.getNFTsCallsCount, 1)
//  }
//
//  func test_getNFTs_willCall_api_getNFTs_passingCorrectParams() async throws {
//    // given
//    let portalApiSpy = PortalApiSpy()
//    try initPortalWithSpy(api: portalApiSpy)
//
//    // and given
//    _ = try await portal.getNFTs("12345")
//
//    // then
//    XCTAssertEqual(portalApiSpy.getNFTsChainIdParam, "12345")
//  }

  func test_getSigningShares_willReturn_correctResult_forNilChainId() async throws {
    // given
    let signingShare = try await portal.getSigningShares()

    // then
    XCTAssertEqual(signingShare.count, 2)
  }

  func test_getSigningShares_willThrowError_forEIP255ChainId_whenItIsNotExist() async throws {
    // given
    let chainId = "eip155:11155111"
    do {
      _ = try await portal.getSigningShares(chainId)
      XCTFail("Expected error not thrown when calling Portal.getSigningShares for unsupported chain.")
    } catch {
      // then
      XCTAssertEqual(error as? PortalClassError, PortalClassError.unsupportedChainId(chainId))
    }
  }

  // TODO: - to fix mocking the PortalKeychain.metadata
//  func test_getSigningShares_willReturn_correctResult_forEIP255ChainId_whenItExists() async throws {
//    // given
//    PortalKeychain.metadata = PortalKeychainMetadata(namespaces: [.eip155: .SECP256K1])
//
//    // and given
//    let backupShares = try await portal.getSigningShares("eip155:11155111")
//
//    // then
//    XCTAssertEqual(backupShares.count, 1)
//  }
}

// MARK: - Wallet Lifecycle helpers

extension PortalTests {
  func test_availableRecoveryMethods_willReturn_correctResult_forNilChainId() async throws {
    // given
    let availableRecoveryMethods = try await portal.availableRecoveryMethods()

    // then
    XCTAssertEqual(availableRecoveryMethods, [.Password, .Password])
  }

  // TODO: - to fix mocking the PortalKeychain.metadata
//  func test_availableRecoveryMethods_willReturn_correctResult_forEIP255ChainId() async throws {
//    // given
//    PortalKeychain.metadata = PortalKeychainMetadata(namespaces: [.eip155: .SECP256K1])
//
//    // and given
//    let availableRecoveryMethods = try await portal.availableRecoveryMethods("eip155:11155111")
//
//    // then
//    XCTAssertEqual(availableRecoveryMethods, [.Password])
//  }

  func test_availableRecoveryMethods_willThrowError_forUnSupportedChain() async throws {
    // given
//    PortalKeychain.metadata = PortalKeychainMetadata(namespaces: [.eip155: .SECP256K1])

    // and given
    let chainId = "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1"
    do {
      _ = try await portal.availableRecoveryMethods(chainId)
      XCTFail("Expected error not thrown when calling Portal.availableRecoveryMethods for unsupported chain.")
    } catch {
      // then
      XCTAssertEqual(error as? PortalClassError, PortalClassError.unsupportedChainId(chainId))
    }
  }

  func test_doesWalletExist_willReturn_correctResult_forNilChainId() async throws {
    // given
    let doseWalletExist = try await portal.doesWalletExist()

    // then
    XCTAssertTrue(doseWalletExist)
  }

  func test_doesWalletExist_willReturn_correctResult_forEIP255ChainId_whenItIsNotExist() async throws {
    // given
    let doseWalletExist = try await portal.doesWalletExist("eip155:11155111")

    // then
    XCTAssertFalse(doseWalletExist)
  }

  // TODO: - to fix mocking the PortalKeychain.metadata
//  func test_doesWalletExist_willReturn_correctResult_forEIP255ChainId_whenItExists() async throws {
//    // given
//    PortalKeychain.metadata = PortalKeychainMetadata(namespaces: [.eip155: .SECP256K1])
//
//    // and given
//    let doseWalletExist = try await portal.doesWalletExist("eip155:11155111")
//
//    // then
//    XCTAssertTrue(doseWalletExist)
//  }

  func test_isWalletBackedUp_willReturn_correctResult_forNilChainId() async throws {
    // given
    let isWalletBackedUp = try await portal.isWalletBackedUp()

    // then
    XCTAssertTrue(isWalletBackedUp)
  }

  func test_isWalletBackedUp_willReturn_false_forNilChainId_andClientWalletsBackupSharesIsNil() async throws {
    // given
    let portalApiMock = PortalApiMock()
    portalApiMock.client = MockConstants.mockNotBackedUpClient
    try initPortalWithSpy(api: portalApiMock)

    // and given
    let isWalletBackedUp = try await portal.isWalletBackedUp()

    // then
    XCTAssertFalse(isWalletBackedUp)
  }

  func test_isWalletBackedUp_willReturn_correctResult_forEIP255ChainId_whenItIsNotExist() async throws {
    // given
    let isWalletBackedUp = try await portal.isWalletBackedUp("eip155:11155111")

    // then
    XCTAssertFalse(isWalletBackedUp)
  }

  // TODO: - to fix mocking the PortalKeychain.metadata
//  func test_isWalletBackedUp_willReturn_correctResult_forEIP255ChainId_whenItExists() async throws {
//    // given
//    PortalKeychain.metadata = PortalKeychainMetadata(namespaces: [.eip155: .SECP256K1])
//
//    // and given
//    let isWalletBackedUp = try await portal.isWalletBackedUp("eip155:11155111")
//
//    // then
//    XCTAssertTrue(isWalletBackedUp)
//  }

  func test_isWalletOnDevice_willReturn_correctResult_forNilChainId() async throws {
    // given
    let isWalletOnDevice = try await portal.isWalletOnDevice()

    // then
    XCTAssertTrue(isWalletOnDevice)
  }

  func test_isWalletOnDevice_willReturn_correctResult_forEIP155ChainId_whenItIsNotExist() async throws {
    // given
    keychain.metadata = PortalKeychainMetadata(namespaces: [.eip155: .SECP256K1])
    keychain.getSharesReturnValue = [:]
    let isWalletOnDevice = try await portal.isWalletOnDevice("eip155:11155111")

    // then
    XCTAssertFalse(isWalletOnDevice)
  }

  // TODO: - to fix mocking the PortalKeychain.metadata
//  func test_isWalletOnDevice_willReturn_correctResult_forEIP255ChainId_whenItExists() async throws {
//    // given
//    PortalKeychain.metadata = PortalKeychainMetadata(namespaces: [.eip155: .SECP256K1])
//
//    // and given
//    let isWalletOnDevice = try await portal.isWalletOnDevice("eip155:11155111")
//
//    // then
//    XCTAssertTrue(isWalletOnDevice)
//  }

  // TODO: - test the isWalletOnDevice function with mock keychain

  func test_isWalletRecoverable_willReturn_correctResult_forNilChainId() async throws {
    // given
    let isWalletRecoverable = try await portal.isWalletRecoverable()

    // then
    XCTAssertTrue(isWalletRecoverable)
  }

  func test_isWalletRecoverable_willThrowError_forEIP255ChainId_whenItIsNotExist() async throws {
    // given
    let chainId = "eip155:11155111"
    do {
      _ = try await portal.isWalletRecoverable(chainId)
      XCTFail("Expected error not thrown when calling Portal.isWalletRecoverable for unsupported chain.")
    } catch {
      // then
      XCTAssertEqual(error as? PortalClassError, PortalClassError.unsupportedChainId(chainId))
    }
  }

  // TODO: - to fix mocking the PortalKeychain.metadata
//  func test_isWalletRecoverable_willReturn_correctResult_forEIP255ChainId_whenItExists() async throws {
//    // given
//    PortalKeychain.metadata = PortalKeychainMetadata(namespaces: [.eip155: .SECP256K1])
//
//    // and given
//    let isWalletRecoverable = try await portal.isWalletRecoverable("eip155:11155111")
//
//    // then
//    XCTAssertTrue(isWalletRecoverable)
//  }

  func test_getBackupShares_willReturn_correctResult_forNilChainId() async throws {
    // given
    let backupShares = try await portal.getBackupShares()

    // then
    XCTAssertEqual(backupShares.count, 2)
  }

  func test_getBackupShares_willThrowError_forEIP255ChainId_whenItIsNotExist() async throws {
    // given
    let chainId = "eip155:11155111"
    do {
      _ = try await portal.getBackupShares(chainId)
      XCTFail("Expected error not thrown when calling Portal.getBackupShares for unsupported chain.")
    } catch {
      // then
      XCTAssertEqual(error as? PortalClassError, PortalClassError.unsupportedChainId(chainId))
    }
  }

  // TODO: - to fix mocking the PortalKeychain.metadata
//  func test_getBackupShares_willReturn_correctResult_forEIP255ChainId_whenItExists() async throws {
//    // given
//    PortalKeychain.metadata = PortalKeychainMetadata(namespaces: [.eip155: .SECP256K1])
//
//    // and given
//    let backupShares = try await portal.getBackupShares("eip155:11155111")
//
//    // then
//    XCTAssertEqual(backupShares.count, 1)
//  }
}

// MARK: - eth tests

extension PortalTests {
  func test_ethEstimateGas_willCall_providerRequest_onlyOnce() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.ethEstimateGas(transaction: ETHTransactionParam.stub(), completion: { _ in })

    // then
    XCTAssertEqual(portalProviderSpy.requestPayloadCompletionCallsCount, 1)
  }

  func test_ethEstimateGas_willCall_providerRequest_passingCorrectMethodParams() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.ethEstimateGas(transaction: ETHTransactionParam.stub(), completion: { _ in })

    // then
    XCTAssertEqual(portalProviderSpy.requestPayloadCompletionPayloadParam?.method, ETHRequestMethods.EstimateGas.rawValue)
  }

  func test_ethGasPrice_willCall_providerRequest_onlyOnce() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.ethGasPrice(completion: { _ in })

    // then
    XCTAssertEqual(portalProviderSpy.requestPayloadCompletionCallsCount, 1)
  }

  func test_ethGasPrice_willCall_providerRequest_passingCorrectParams() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.ethGasPrice(completion: { _ in })

    // then
    XCTAssertEqual(portalProviderSpy.requestPayloadCompletionPayloadParam?.method, ETHRequestMethods.GasPrice.rawValue)
    XCTAssertEqual(portalProviderSpy.requestPayloadCompletionPayloadParam?.params as? [String], [])
  }

  func test_ethGetBalance_willCall_providerRequest_onlyOnce() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    portalProviderSpy.address = "dummy_address"
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.ethGetBalance(completion: { _ in })

    // then
    XCTAssertEqual(portalProviderSpy.requestPayloadCompletionCallsCount, 1)
  }

  func test_ethGetBalance_willCall_providerRequest_passingCorrectParams() async throws {
    // given
    let address = "dummy_address"
    let portalProviderSpy = PortalProviderSpy()
    portalProviderSpy.address = address
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.ethGetBalance(completion: { _ in })

    // then
    XCTAssertEqual(portalProviderSpy.requestPayloadCompletionPayloadParam?.method, ETHRequestMethods.GetBalance.rawValue)
    XCTAssertEqual(portalProviderSpy.requestPayloadCompletionPayloadParam?.params as? [String], [address, "latest"])
  }

  func test_ethGetBalance_willComplete_withCorrectError() async throws {
    // given
    let expectation = XCTestExpectation(description: "Completion handler invoked")
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)
    var result: Result<RequestCompletionResult>?

    // and given
    portal.ethGetBalance { response in
      result = response
      expectation.fulfill()
    }

    // then
    await fulfillment(of: [expectation], timeout: 5.0)
    XCTAssertEqual(result?.error as? PortalProviderError, PortalProviderError.noAddress)
  }

  func test_ethSendTransaction_willCall_providerRequest_onlyOnce() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.ethSendTransaction(transaction: ETHTransactionParam.stub(), completion: { _ in })

    // then
    XCTAssertEqual(portalProviderSpy.requestTransactionCompletionCallsCount, 1)
  }

  func test_ethSendTransaction_willCall_providerRequest_passingCorrectParams() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.ethSendTransaction(transaction: ETHTransactionParam.stub(), completion: { _ in })

    // then
    XCTAssertEqual(portalProviderSpy.requestTransactionCompletionPayloadParam?.method, ETHRequestMethods.SendTransaction.rawValue)
  }

  func test_ethSign_willCall_providerRequest_onlyOnce() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    portalProviderSpy.address = "dummy_address"
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.ethSign(message: "", completion: { _ in })

    // then
    XCTAssertEqual(portalProviderSpy.requestPayloadCompletionCallsCount, 1)
  }

  func test_ethSign_willCall_providerRequest_passingCorrectParams() async throws {
    // given
    let address = "dummy_address"
    let portalProviderSpy = PortalProviderSpy()
    portalProviderSpy.address = address
    setToPortal(portalProvider: portalProviderSpy)
    let message = "dummy_message"

    // and given
    portal.ethSign(message: message, completion: { _ in })

    // then
    XCTAssertEqual(portalProviderSpy.requestPayloadCompletionPayloadParam?.method, ETHRequestMethods.Sign.rawValue)
    XCTAssertEqual(portalProviderSpy.requestPayloadCompletionPayloadParam?.params as? [String], [address, message])
  }

  func test_ethSign_willComplete_withCorrectError() async throws {
    // given
    let expectation = XCTestExpectation(description: "Completion handler invoked")
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)
    var result: Result<RequestCompletionResult>?

    // and given
    portal.ethSign(message: "") { response in
      result = response
      expectation.fulfill()
    }

    // then
    await fulfillment(of: [expectation], timeout: 5.0)
    XCTAssertEqual(result?.error as? PortalProviderError, PortalProviderError.noAddress)
  }

  func test_ethSignTransaction_willCall_providerRequest_onlyOnce() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.ethSignTransaction(transaction: ETHTransactionParam.stub(), completion: { _ in })

    // then
    XCTAssertEqual(portalProviderSpy.requestTransactionCompletionCallsCount, 1)
  }

  func test_ethSignTransaction_willCall_providerRequest_passingCorrectParams() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.ethSignTransaction(transaction: ETHTransactionParam.stub(), completion: { _ in })

    // then
    XCTAssertEqual(portalProviderSpy.requestTransactionCompletionPayloadParam?.method, ETHRequestMethods.SignTransaction.rawValue)
  }

  func test_ethSignTypedDataV3_willCall_providerRequest_onlyOnce() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    portalProviderSpy.address = "dummy_address"
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.ethSignTypedDataV3(message: "", completion: { _ in })

    // then
    XCTAssertEqual(portalProviderSpy.requestPayloadCompletionCallsCount, 1)
  }

  func test_ethSignTypedDataV3_willCall_providerRequest_passingCorrectParams() async throws {
    // given
    let address = "dummy_address"
    let portalProviderSpy = PortalProviderSpy()
    portalProviderSpy.address = address
    setToPortal(portalProvider: portalProviderSpy)
    let message = "dummy_message"

    // and given
    portal.ethSignTypedDataV3(message: message, completion: { _ in })

    // then
    XCTAssertEqual(portalProviderSpy.requestPayloadCompletionPayloadParam?.method, ETHRequestMethods.SignTypedDataV3.rawValue)
    XCTAssertEqual(portalProviderSpy.requestPayloadCompletionPayloadParam?.params as? [String], [address, message])
  }

  func test_ethSignTypedDataV3_willComplete_withCorrectError() async throws {
    // given
    let expectation = XCTestExpectation(description: "Completion handler invoked")
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)
    var result: Result<RequestCompletionResult>?

    // and given
    portal.ethSignTypedDataV3(message: "") { response in
      result = response
      expectation.fulfill()
    }

    // then
    await fulfillment(of: [expectation], timeout: 5.0)
    XCTAssertEqual(result?.error as? PortalProviderError, PortalProviderError.noAddress)
  }

  func test_ethSignTypedData_willCall_providerRequest_onlyOnce() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    portalProviderSpy.address = "dummy_address"
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.ethSignTypedData(message: "", completion: { _ in })

    // then
    XCTAssertEqual(portalProviderSpy.requestPayloadCompletionCallsCount, 1)
  }

  func test_ethSignTypedData_willCall_providerRequest_passingCorrectParams() async throws {
    // given
    let address = "dummy_address"
    let portalProviderSpy = PortalProviderSpy()
    portalProviderSpy.address = address
    setToPortal(portalProvider: portalProviderSpy)
    let message = "dummy_message"

    // and given
    portal.ethSignTypedData(message: message, completion: { _ in })

    // then
    XCTAssertEqual(portalProviderSpy.requestPayloadCompletionPayloadParam?.method, ETHRequestMethods.SignTypedDataV4.rawValue)
    XCTAssertEqual(portalProviderSpy.requestPayloadCompletionPayloadParam?.params as? [String], [address, message])
  }

  func test_ethSignTypedData_willComplete_withCorrectError() async throws {
    // given
    let expectation = XCTestExpectation(description: "Completion handler invoked")
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)
    var result: Result<RequestCompletionResult>?

    // and given
    portal.ethSignTypedData(message: "") { response in
      result = response
      expectation.fulfill()
    }

    // then
    await fulfillment(of: [expectation], timeout: 5.0)
    XCTAssertEqual(result?.error as? PortalProviderError, PortalProviderError.noAddress)
  }

  func test_personalSign_willCall_providerRequest_onlyOnce() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    portalProviderSpy.address = "dummy_address"
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.personalSign(message: "", completion: { _ in })

    // then
    XCTAssertEqual(portalProviderSpy.requestPayloadCompletionCallsCount, 1)
  }

  func test_personalSign_willCall_providerRequest_passingCorrectParams() async throws {
    // given
    let address = "dummy_address"
    let portalProviderSpy = PortalProviderSpy()
    portalProviderSpy.address = address
    setToPortal(portalProvider: portalProviderSpy)
    let message = "dummy_message"

    // and given
    portal.personalSign(message: message, completion: { _ in })

    // then
    XCTAssertEqual(portalProviderSpy.requestPayloadCompletionPayloadParam?.method, ETHRequestMethods.PersonalSign.rawValue)
    XCTAssertEqual(portalProviderSpy.requestPayloadCompletionPayloadParam?.params as? [String], [message, address])
  }

  func test_personalSign_willComplete_withCorrectError() async throws {
    // given
    let expectation = XCTestExpectation(description: "Completion handler invoked")
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)
    var result: Result<RequestCompletionResult>?

    // and given
    portal.personalSign(message: "") { response in
      result = response
      expectation.fulfill()
    }

    // then
    await fulfillment(of: [expectation], timeout: 5.0)
    XCTAssertEqual(result?.error as? PortalProviderError, PortalProviderError.noAddress)
  }

  func test_request_willCall_providerRequest_onlyOnce() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.request(method: "eth_getCode", params: [], completion: { _ in })

    // then
    XCTAssertEqual(portalProviderSpy.requestPayloadCompletionCallsCount, 1)
  }

  func test_request_willCall_providerRequest_passingCorrectParams() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    let method = ETHRequestMethods.SendRawTransaction.rawValue
    // and given
    portal.request(method: method, params: [], completion: { _ in })

    // then
    XCTAssertEqual(portalProviderSpy.requestPayloadCompletionPayloadParam?.method, method)
  }
}

// MARK: - Solana tests

extension PortalTests {
  func test_sendSol_passingWrongChainId_willThroughCorrectError() async throws {
    // given
    let chainId = "qqq"

    do {
      // and given
      _ = try await portal.sendSol(1, to: "", withChainId: chainId)
      XCTFail("Expected error not thrown when calling Portal.sendSol passing invalid to address format.")
    } catch {
      // then
      XCTAssertEqual(error as? PortalClassError, PortalClassError.unsupportedChainId(chainId))
    }
  }

  func test_sendSol() async throws {
    // given
    let portalApiMock = PortalApiMock()
    portalApiMock.buildSolanaTransactionReturnValue = BuildSolanaTransactionResponse.stub()
    try initPortalWithSpy(api: portalApiMock)

    setToPortal(portalProvider: PortalProviderMock())

    // and given
    let chainId = "solana:11155111"
    let transactionHash = try await portal.sendSol(1, to: "6LmSRCiu3z6NCSpF19oz1pHXkYkN4jWbj9K1nVELpDkT", withChainId: chainId)

    // then
    XCTAssertTrue(!transactionHash.isEmpty)
  }

  func test_sendSol_withEmptyStringChainId_willThroughCorrectError() async throws {
    // given
    let chainId = ""

    do {
      // and given
      _ = try await portal.sendSol(1, to: "6LmSRCiu3z6NCSpF19oz1pHXkYkN4jWbj9K1nVELpDkT", withChainId: chainId)
      XCTFail("Expected error not thrown when calling Portal.sendSol passing empty string chain id.")

    } catch {
      // then
      XCTAssertEqual(error as? PortalClassError, PortalClassError.invalidChainId(chainId))
    }
  }

  func test_sendSol_withInvalidChainId_willThroughCorrectError() async throws {
    // given
    let chainId = "eip155:"

    do {
      // and given
      _ = try await portal.sendSol(1, to: "6LmSRCiu3z6NCSpF19oz1pHXkYkN4jWbj9K1nVELpDkT", withChainId: chainId)
      XCTFail("Expected error not thrown when calling Portal.sendSol passing empty string chain id.")

    } catch {
      // then
      XCTAssertEqual(error as? PortalClassError, PortalClassError.unsupportedChainId(chainId))
    }
  }

  func test_sendSol_withInvalidNameSpace_willThroughCorrectError() async throws {
    // given
    let chainId = ":11155111"

    do {
      // and given
      _ = try await portal.sendSol(1, to: "6LmSRCiu3z6NCSpF19oz1pHXkYkN4jWbj9K1nVELpDkT", withChainId: chainId)
      XCTFail("Expected error not thrown when calling Portal.sendSol passing empty string chain id.")

    } catch {
      // then
      XCTAssertEqual(error as? PortalClassError, PortalClassError.unsupportedChainId(chainId))
    }
  }
  // TODO: - to send the `sendSol` function all cases.
}

// MARK: - getWalletCapabilities tests

extension PortalTests {
  func test_getWalletCapabilities_willCall_api_getWalletCapabilities_onlyOnce() async throws {
    // given
    let portalApiSpy = PortalApiSpy()
    try initPortalWithSpy(api: portalApiSpy)

    // and given
    _ = try await portal.getWalletCapabilities()

    // then
    XCTAssertEqual(portalApiSpy.getWalletCapabilitiesCallsCount, 1)
  }
}

// MARK: - receiveTestnetAsset tests

extension PortalTests {
  func test_receiveTestnetAsset_willCall_api_fund_onlyOnce() async throws {
    // given
    let portalApiSpy = PortalApiSpy()
    try initPortalWithSpy(api: portalApiSpy)

    // and given
    _ = try await portal.receiveTestnetAsset(chainId: "", params: FundParams(amount: "", token: ""))

    // then
    XCTAssertEqual(portalApiSpy.fundCallsCount, 1)
  }

  func test_receiveTestnetAsset_willCall_api_fund_passingCorrectParams() async throws {
    // given
    let portalApiSpy = PortalApiSpy()
    try initPortalWithSpy(api: portalApiSpy)

    // and given
    let chainId = "eip155:11155111"
    let amount = "0.01"
    let token = "ETH"

    // and given
    _ = try await portal.receiveTestnetAsset(chainId: chainId, params: FundParams(amount: amount, token: token))

    // then
    XCTAssertEqual(portalApiSpy.fundChainIdParam, chainId)
    XCTAssertEqual(portalApiSpy.fundParams?.amount, amount)
    XCTAssertEqual(portalApiSpy.fundParams?.token, token)
  }
}

// MARK: - sendAsset tests

extension PortalTests {
  func test_sendAsset_willCall_portalProvider_request_onlyOnce_for_eip115Chain() async throws {
    // given
    let portalApiSpy = PortalApiMock()
    portalApiSpy.buildEip115TransactionReturnValue = BuildEip115TransactionResponse.stub()
    try initPortalWithSpy(api: portalApiSpy)
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    _ = try await portal.sendAsset(chainId: "eip155:11155111", params: SendAssetParams.stub())

    // then
    XCTAssertEqual(portalProviderSpy.requestAsyncMethodCallsCount, 1)
  }

  func test_sendAsset_willCall_portalProvider_request_onlyOnce_for_SolanaChain() async throws {
    // given
    let portalApiSpy = PortalApiMock()
    portalApiSpy.buildSolanaTransactionReturnValue = BuildSolanaTransactionResponse.stub()
    try initPortalWithSpy(api: portalApiSpy)
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    _ = try await portal.sendAsset(chainId: "solana:11155111", params: SendAssetParams.stub())

    // then
    XCTAssertEqual(portalProviderSpy.requestAsyncMethodCallsCount, 1)
  }

  func test_sendAsset_withInvalidNameSpace_willThroughCorrectError() async throws {
    // given
    let chainId = ":11155111"

    do {
      // and given
      _ = try await portal.sendAsset(chainId: chainId, params: SendAssetParams.stub())
      XCTFail("Expected error not thrown when calling Portal.sendAsset passing invalid chain id.")

    } catch {
      // then
      XCTAssertEqual(error as? PortalClassError, PortalClassError.invalidChainId(chainId))
    }
  }

  func test_sendAsset_withInvalidChaninId_willThroughCorrectError() async throws {
    // given
    for chainId in ["eip155:", ":", ""] {
      do {
        // and given
        _ = try await portal.sendAsset(chainId: chainId, params: SendAssetParams.stub())
        XCTFail("Expected error not thrown when calling Portal.sendAsset passing invalid chain id.")

      } catch {
        // then
        XCTAssertEqual(error as? PortalClassError, PortalClassError.invalidChainId(chainId))
      }
    }
  }

  func test_sendAsset_withInvalidParams_willThroughCorrectError() async throws {
    // given
    do {
      // and given
      _ = try await portal.sendAsset(chainId: "eip155:11155111", params: SendAssetParams.stub(to: ""))
      _ = try await portal.sendAsset(chainId: "eip155:11155111", params: SendAssetParams.stub(amount: ""))
      _ = try await portal.sendAsset(chainId: "eip155:11155111", params: SendAssetParams.stub(token: ""))
      _ = try await portal.sendAsset(chainId: "eip155:11155111", params: SendAssetParams.stub(to: "", amount: "", token: ""))
      XCTFail("Expected error not thrown when calling Portal.sendAsset passing invalid params.")

    } catch {
      // then
      XCTAssertEqual(error as? PortalClassError, PortalClassError.invalidParameters("Missing required parameters: to, token, or amount"))
    }
  }
}
