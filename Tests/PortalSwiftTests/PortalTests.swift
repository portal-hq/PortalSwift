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
  func test_deprecated_emit_willCall_provider_emit_onlyOnce() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.emit(Events.Connect.rawValue, data: "")

    XCTAssertEqual(portalProviderSpy.emitCallsCount, 1)
  }

  func test_deprecated_emit_willCall_provider_emit_passingCorrectParams() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.emit(Events.ChainChanged.rawValue, data: "123")

    XCTAssertEqual(portalProviderSpy.emitEventParam, Events.ChainChanged.rawValue)
    XCTAssertEqual(portalProviderSpy.emitDataParam as? String, "123")
  }

  func test_emit_willCall_provider_emit_onlyOnce() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.emit(Events.Connect, data: "")

    XCTAssertEqual(portalProviderSpy.emitCallsCount, 1)
  }

  func test_emit_willCall_provider_emit_passingCorrectParams() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.emit(Events.ChainChanged, data: "123")

    XCTAssertEqual(portalProviderSpy.emitEventParam, Events.ChainChanged.rawValue)
    XCTAssertEqual(portalProviderSpy.emitDataParam as? String, "123")
  }

  func test_deprecated_on_willCall_provider_on_onlyOnce() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.on(event: Events.PortalSigningRequested.rawValue, callback: { _ in })

    XCTAssertEqual(portalProviderSpy.onCallsCount, 1)
  }

  func test_deprecated_on_willCall_provider_on_passingCorrectParams() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.on(event: Events.PortalConnectSigningRequested.rawValue, callback: { _ in })

    XCTAssertEqual(portalProviderSpy.onEventParam, Events.PortalConnectSigningRequested.rawValue)
  }

  func test_on_willCall_provider_on_onlyOnce() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.on(event: Events.PortalSigningRequested, callback: { _ in })

    XCTAssertEqual(portalProviderSpy.onCallsCount, 1)
  }

  func test_on_willCall_provider_on_passingCorrectParams() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.on(event: Events.PortalConnectSigningRequested, callback: { _ in })

    XCTAssertEqual(portalProviderSpy.onEventParam, Events.PortalConnectSigningRequested.rawValue)
  }

  func test_deprecated_once_willCall_provider_once_onlyOnce() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.once(event: Events.PortalSignatureReceived.rawValue, callback: { _ in })

    XCTAssertEqual(portalProviderSpy.onceCallsCount, 1)
  }

  func test_deprecated_once_willCall_provider_once_passingCorrectParams() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.once(event: Events.PortalSigningApproved.rawValue, callback: { _ in })

    XCTAssertEqual(portalProviderSpy.onceEventParam, Events.PortalSigningApproved.rawValue)
  }

  func test_once_willCall_provider_once_onlyOnce() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.once(event: Events.PortalSignatureReceived, callback: { _ in })

    XCTAssertEqual(portalProviderSpy.onceCallsCount, 1)
  }

  func test_once_willCall_provider_once_passingCorrectParams() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.once(event: Events.PortalSigningApproved, callback: { _ in })

    XCTAssertEqual(portalProviderSpy.onceEventParam, Events.PortalSigningApproved.rawValue)
  }
}

// MARK: - Request Tests

extension PortalTests {
  func test_request_willCall_provider_request_onlyOnce() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    _ = try await portal.request("", withMethod: .eth_accounts, andParams: [])

    XCTAssertEqual(portalProviderSpy.requestOptionsCallsCount, 1)
  }

  func test_request_willCall_provider_request_passingCorrectParams() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    let method = PortalRequestMethod.eth_accounts
    let signatureApprovalMemo: String? = "signature approval memo"
    _ = try await portal.request("123", withMethod: method, andParams: ["123", "321"], signatureApprovalMemo: signatureApprovalMemo)

    XCTAssertEqual(portalProviderSpy.requestOptionsChainIdParam, "123")
    XCTAssertEqual(portalProviderSpy.requestOptionsMethodParam, method)
    XCTAssertEqual(portalProviderSpy.requestOptionsParamsParam, ["123", "321"])
    XCTAssertEqual(portalProviderSpy.requestOptionsOptionsParam?.signatureApprovalMemo, signatureApprovalMemo)
    XCTAssertEqual(portalProviderSpy.requestOptionsOptionsParam?.sponsorGas, nil)
  }

  func test_request_withStringMethod_willCall_provider_request_onlyOnce() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    _ = try await portal.request("", withMethod: "eth_accounts", andParams: [])

    XCTAssertEqual(portalProviderSpy.requestOptionsCallsCount, 1)
  }

  func test_request_withStringMethod_willThrowCorrectError_WhenPassingWrongMethod() async throws {
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

  func test_request_withStringMethod_willThrowCorrectError_WhenPassingNilParams() async throws {
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

  func test_request_withStringMethod_willCall_provider_request_passingCorrectParams() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    let method = "eth_accounts"
    _ = try await portal.request("123", withMethod: method, andParams: ["123", "321"])

    XCTAssertEqual(portalProviderSpy.requestOptionsChainIdParam, "123")
    XCTAssertEqual(portalProviderSpy.requestOptionsMethodParam, PortalRequestMethod(rawValue: method))
    XCTAssertEqual(portalProviderSpy.requestOptionsParamsParam, ["123", "321"])
  }
}

// MARK: - Request with chainId, method, params, options Tests

extension PortalTests {
  // MARK: - Basic Call Tests

  func test_requestWithChainIdMethodParams_willCall_provider_request_onlyOnce() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // when
    _ = try await portal.request(chainId: "eip155:1", method: .eth_accounts, params: [])

    // then
    XCTAssertEqual(portalProviderSpy.requestOptionsCallsCount, 1)
  }

  func test_requestWithChainIdMethodParams_willCall_provider_request_onlyOnce_withOptions() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // when
    let options = RequestOptions(signatureApprovalMemo: "test memo")
    _ = try await portal.request(chainId: "eip155:1", method: .eth_accounts, params: [], options: options)

    // then
    XCTAssertEqual(portalProviderSpy.requestOptionsCallsCount, 1)
  }

  // MARK: - ChainId Parameter Tests

  func test_requestWithChainIdMethodParams_willPass_correctChainId() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)
    let expectedChainId = "eip155:11155111"

    // when
    _ = try await portal.request(chainId: expectedChainId, method: .eth_accounts, params: [])

    // then
    XCTAssertEqual(portalProviderSpy.requestOptionsChainIdParam, expectedChainId)
  }

  func test_requestWithChainIdMethodParams_willPass_correctChainId_forSolana() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)
    let expectedChainId = "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp"

    // when
    _ = try await portal.request(chainId: expectedChainId, method: .sol_signMessage, params: [])

    // then
    XCTAssertEqual(portalProviderSpy.requestOptionsChainIdParam, expectedChainId)
  }

  func test_requestWithChainIdMethodParams_willPass_emptyChainId() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // when
    _ = try await portal.request(chainId: "", method: .eth_accounts, params: [])

    // then
    XCTAssertEqual(portalProviderSpy.requestOptionsChainIdParam, "")
  }

  // MARK: - Method Parameter Tests

  func test_requestWithChainIdMethodParams_willPass_correctMethod_ethAccounts() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)
    let expectedMethod = PortalRequestMethod.eth_accounts

    // when
    _ = try await portal.request(chainId: "eip155:1", method: expectedMethod, params: [])

    // then
    XCTAssertEqual(portalProviderSpy.requestOptionsMethodParam, expectedMethod)
  }

  func test_requestWithChainIdMethodParams_willPass_correctMethod_ethCall() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)
    let expectedMethod = PortalRequestMethod.eth_call

    // when
    _ = try await portal.request(chainId: "eip155:1", method: expectedMethod, params: [])

    // then
    XCTAssertEqual(portalProviderSpy.requestOptionsMethodParam, expectedMethod)
  }

  func test_requestWithChainIdMethodParams_willPass_correctMethod_ethSendTransaction() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)
    let expectedMethod = PortalRequestMethod.eth_sendTransaction

    // when
    _ = try await portal.request(chainId: "eip155:1", method: expectedMethod, params: [])

    // then
    XCTAssertEqual(portalProviderSpy.requestOptionsMethodParam, expectedMethod)
  }

  func test_requestWithChainIdMethodParams_willPass_correctMethod_personalSign() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)
    let expectedMethod = PortalRequestMethod.personal_sign

    // when
    _ = try await portal.request(chainId: "eip155:1", method: expectedMethod, params: [])

    // then
    XCTAssertEqual(portalProviderSpy.requestOptionsMethodParam, expectedMethod)
  }

  func test_requestWithChainIdMethodParams_willPass_correctMethod_solSignMessage() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)
    let expectedMethod = PortalRequestMethod.sol_signMessage

    // when
    _ = try await portal.request(chainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp", method: expectedMethod, params: [])

    // then
    XCTAssertEqual(portalProviderSpy.requestOptionsMethodParam, expectedMethod)
  }

  // MARK: - Params Parameter Tests

  func test_requestWithChainIdMethodParams_willPass_emptyParams() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // when
    _ = try await portal.request(chainId: "eip155:1", method: .eth_accounts, params: [])

    // then
    XCTAssertEqual(portalProviderSpy.requestOptionsParamsParam, [])
  }

  func test_requestWithChainIdMethodParams_willPass_stringParams() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // when
    _ = try await portal.request(chainId: "eip155:1", method: .eth_call, params: ["param1", "param2", "param3"])

    // then
    XCTAssertEqual(portalProviderSpy.requestOptionsParamsParam, ["param1", "param2", "param3"])
  }

  func test_requestWithChainIdMethodParams_willPass_intParams() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // when
    _ = try await portal.request(chainId: "eip155:1", method: .eth_call, params: [1, 2, 3])

    // then
    XCTAssertEqual(portalProviderSpy.requestOptionsParamsParam, [1, 2, 3])
  }

  func test_requestWithChainIdMethodParams_willPass_boolParams() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // when
    _ = try await portal.request(chainId: "eip155:1", method: .eth_call, params: [true, false, true])

    // then
    XCTAssertEqual(portalProviderSpy.requestOptionsParamsParam, [true, false, true])
  }

  func test_requestWithChainIdMethodParams_willPass_mixedTypeParams() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // when
    _ = try await portal.request(chainId: "eip155:1", method: .eth_call, params: ["string", 123, true])

    // then
    XCTAssertEqual(portalProviderSpy.requestOptionsParamsParam, ["string", 123, true])
  }

  func test_requestWithChainIdMethodParams_willPass_dictionaryParams() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)
    let transactionParam: [String: Any] = [
      "from": "0x1234567890abcdef",
      "to": "0xabcdef1234567890",
      "value": "0x1000"
    ]

    // when
    _ = try await portal.request(chainId: "eip155:1", method: .eth_sendTransaction, params: [transactionParam])

    // then
    XCTAssertNotNil(portalProviderSpy.requestOptionsParamsParam)
    XCTAssertEqual(portalProviderSpy.requestOptionsParamsParam?.count, 1)
  }

  func test_requestWithChainIdMethodParams_willPass_nestedArrayParams() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)
    let nestedArray = ["inner1", "inner2"]

    // when
    _ = try await portal.request(chainId: "eip155:1", method: .eth_call, params: [nestedArray, "outer"])

    // then
    XCTAssertNotNil(portalProviderSpy.requestOptionsParamsParam)
    XCTAssertEqual(portalProviderSpy.requestOptionsParamsParam?.count, 2)
  }

  // MARK: - Options Parameter Tests

  func test_requestWithChainIdMethodParams_willPass_nilOptions() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // when
    _ = try await portal.request(chainId: "eip155:1", method: .eth_accounts, params: [])

    // then
    XCTAssertNil(portalProviderSpy.requestOptionsOptionsParam)
  }

  func test_requestWithChainIdMethodParams_willPass_optionsWithSignatureApprovalMemo() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)
    let expectedMemo = "Please approve this signature"
    let options = RequestOptions(signatureApprovalMemo: expectedMemo)

    // when
    _ = try await portal.request(chainId: "eip155:1", method: .personal_sign, params: [], options: options)

    // then
    XCTAssertEqual(portalProviderSpy.requestOptionsOptionsParam?.signatureApprovalMemo, expectedMemo)
  }

  func test_requestWithChainIdMethodParams_willPass_optionsWithSponsorGasTrue() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)
    let options = RequestOptions(sponsorGas: true)

    // when
    _ = try await portal.request(chainId: "eip155:1", method: .eth_sendTransaction, params: [], options: options)

    // then
    XCTAssertEqual(portalProviderSpy.requestOptionsOptionsParam?.sponsorGas, true)
  }

  func test_requestWithChainIdMethodParams_willPass_optionsWithSponsorGasFalse() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)
    let options = RequestOptions(sponsorGas: false)

    // when
    _ = try await portal.request(chainId: "eip155:1", method: .eth_sendTransaction, params: [], options: options)

    // then
    XCTAssertEqual(portalProviderSpy.requestOptionsOptionsParam?.sponsorGas, false)
  }

  func test_requestWithChainIdMethodParams_willPass_optionsWithBothMemoAndSponsorGas() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)
    let expectedMemo = "Sign this transaction"
    let options = RequestOptions(signatureApprovalMemo: expectedMemo, sponsorGas: true)

    // when
    _ = try await portal.request(chainId: "eip155:1", method: .eth_sendTransaction, params: [], options: options)

    // then
    XCTAssertEqual(portalProviderSpy.requestOptionsOptionsParam?.signatureApprovalMemo, expectedMemo)
    XCTAssertEqual(portalProviderSpy.requestOptionsOptionsParam?.sponsorGas, true)
  }

  func test_requestWithChainIdMethodParams_willPass_emptyOptions() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)
    let options = RequestOptions()

    // when
    _ = try await portal.request(chainId: "eip155:1", method: .eth_accounts, params: [], options: options)

    // then
    XCTAssertNotNil(portalProviderSpy.requestOptionsOptionsParam)
    XCTAssertNil(portalProviderSpy.requestOptionsOptionsParam?.signatureApprovalMemo)
    XCTAssertNil(portalProviderSpy.requestOptionsOptionsParam?.sponsorGas)
  }

  // MARK: - Connect Parameter Tests

  func test_requestWithChainIdMethodParams_willPass_nilConnect() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // when
    _ = try await portal.request(chainId: "eip155:1", method: .eth_accounts, params: [])

    // then
    XCTAssertNil(portalProviderSpy.requestOptionsConnectParam)
  }

  // MARK: - Full Integration Tests

  func test_requestWithChainIdMethodParams_willPass_allParametersCorrectly() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)
    let expectedChainId = "eip155:137"
    let expectedMethod = PortalRequestMethod.eth_sendTransaction
    let expectedMemo = "Confirm transaction"
    let options = RequestOptions(signatureApprovalMemo: expectedMemo, sponsorGas: true)

    // when
    _ = try await portal.request(chainId: expectedChainId, method: expectedMethod, params: ["0xabc", "0x123"], options: options)

    // then
    XCTAssertEqual(portalProviderSpy.requestOptionsCallsCount, 1)
    XCTAssertEqual(portalProviderSpy.requestOptionsChainIdParam, expectedChainId)
    XCTAssertEqual(portalProviderSpy.requestOptionsMethodParam, expectedMethod)
    XCTAssertEqual(portalProviderSpy.requestOptionsParamsParam, ["0xabc", "0x123"])
    XCTAssertEqual(portalProviderSpy.requestOptionsOptionsParam?.signatureApprovalMemo, expectedMemo)
    XCTAssertEqual(portalProviderSpy.requestOptionsOptionsParam?.sponsorGas, true)
    XCTAssertNil(portalProviderSpy.requestOptionsConnectParam)
  }

  func test_requestWithChainIdMethodParams_willConvertParamsToAnyCodable() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // when
    _ = try await portal.request(chainId: "eip155:1", method: .eth_call, params: ["test", 42, true])

    // then - verify that the params were converted to AnyCodable
    XCTAssertNotNil(portalProviderSpy.requestOptionsParamsParam)
    XCTAssertEqual(portalProviderSpy.requestOptionsParamsParam?.count, 3)
    // AnyCodable comparison should work with the underlying values
    XCTAssertEqual(portalProviderSpy.requestOptionsParamsParam?[0], AnyCodable("test"))
    XCTAssertEqual(portalProviderSpy.requestOptionsParamsParam?[1], AnyCodable(42))
    XCTAssertEqual(portalProviderSpy.requestOptionsParamsParam?[2], AnyCodable(true))
  }

  // MARK: - Multiple Calls Tests

  func test_requestWithChainIdMethodParams_multipleCallsWillIncrementCallCount() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // when
    _ = try await portal.request(chainId: "eip155:1", method: .eth_accounts, params: [])
    _ = try await portal.request(chainId: "eip155:1", method: .eth_accounts, params: [])
    _ = try await portal.request(chainId: "eip155:1", method: .eth_accounts, params: [])

    // then
    XCTAssertEqual(portalProviderSpy.requestOptionsCallsCount, 3)
  }

  func test_requestWithChainIdMethodParams_lastCallParamsAreRetained() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // when
    _ = try await portal.request(chainId: "eip155:1", method: .eth_accounts, params: ["first"])
    _ = try await portal.request(chainId: "eip155:137", method: .eth_call, params: ["second"])

    // then - verify last call params are retained
    XCTAssertEqual(portalProviderSpy.requestOptionsChainIdParam, "eip155:137")
    XCTAssertEqual(portalProviderSpy.requestOptionsMethodParam, .eth_call)
    XCTAssertEqual(portalProviderSpy.requestOptionsParamsParam, ["second"])
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
    XCTAssertEqual(portalProviderSpy.requestOptionsCallsCount, 1)
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
    XCTAssertEqual(portalProviderSpy.requestOptionsCallsCount, 1)
  }

  func test_sendAsset_willCall_portalProvider_request_onlyOnce_for_bip122Chain() async throws {
    // given
    let portalApiMock = PortalApiMock()
    portalApiMock.buildBitcoinP2wpkhTransactionReturnValue = BuildBitcoinP2wpkhTransactionResponse.stub()
    try initPortalWithSpy(api: portalApiMock)
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    _ = try await portal.sendAsset(chainId: "bip122:000000000019d6689c085ae165831e93-p2wpkh", params: SendAssetParams.stub())

    // then
    XCTAssertEqual(portalProviderSpy.requestOptionsCallsCount, 1)
  }

  func test_sendAsset_willCall_portalProvider_request_correctTimes_whenHavingMoreThanSingatureHash_for_bip122Chain() async throws {
    // given
    let numberOfHashes = Int.random(in: 1 ... 100)
    let signatureHashes: [String] = Array(1 ... numberOfHashes).map { number in "SignatureHash-\(number)" }
    let portalApiMock = PortalApiMock()
    portalApiMock.buildBitcoinP2wpkhTransactionReturnValue = BuildBitcoinP2wpkhTransactionResponse.stub(transaction: BitcoinP2wpkhTransaction.stub(signatureHashes: signatureHashes, rawTxHex: "rawTxHex"))
    try initPortalWithSpy(api: portalApiMock)

    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    let params = SendAssetParams.stub(signatureApprovalMemo: "signatureApprovalMemo")
    let chainId = "bip122:000000000019d6689c085ae165831e93-p2wpkh"

    // and given
    _ = try await portal.sendAsset(chainId: chainId, params: params)

    // then
    XCTAssertEqual(portalProviderSpy.requestOptionsCallsCount, numberOfHashes)
  }

  func test_sendAsset_willCall_portalApi_buildBitcoinP2wpkhTransaction_onlyOnce_for_bip122Chain() async throws {
    // given
    let portalApiSpy = PortalApiSpy()
    portalApiSpy.buildBitcoinP2wpkhTransactionReturnValue = BuildBitcoinP2wpkhTransactionResponse.stub()
    try initPortalWithSpy(api: portalApiSpy)
    let portalProviderMock = PortalProviderMock()
    setToPortal(portalProvider: portalProviderMock)

    // and given
    _ = try await portal.sendAsset(chainId: "bip122:000000000019d6689c085ae165831e93-p2wpkh", params: SendAssetParams.stub())

    // then
    XCTAssertEqual(portalApiSpy.buildBitcoinP2wpkhTransactionCallsCount, 1)
  }

  func test_sendAsset_willCall_portalApi_broadcastBitcoinP2wpkhTransaction_onlyOnce_for_bip122Chain() async throws {
    // given
    let portalApiSpy = PortalApiSpy()
    portalApiSpy.buildBitcoinP2wpkhTransactionReturnValue = BuildBitcoinP2wpkhTransactionResponse.stub()
    try initPortalWithSpy(api: portalApiSpy)
    let portalProviderMock = PortalProviderMock()
    setToPortal(portalProvider: portalProviderMock)

    // and given
    _ = try await portal.sendAsset(chainId: "bip122:000000000019d6689c085ae165831e93-p2wpkh", params: SendAssetParams.stub())

    // then
    XCTAssertEqual(portalApiSpy.broadcastBitcoinP2wpkhTransactionCallsCount, 1)
  }

  func test_sendAsset_willCall_portalProvider_request_passingCorrectParams_for_eip115Chain() async throws {
    // given
    let portalApiSpy = PortalApiMock()
    try initPortalWithSpy(api: portalApiSpy)
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)
    let params = SendAssetParams.stub(signatureApprovalMemo: "signatureApprovalMemo")
    let chainId = "eip155:11155111"

    // and given
    _ = try await portal.sendAsset(chainId: chainId, params: params)

    // then
    XCTAssertEqual(portalProviderSpy.requestOptionsChainIdParam, chainId)
    XCTAssertEqual(portalProviderSpy.requestOptionsMethodParam, .eth_sendTransaction)
    XCTAssertEqual(portalProviderSpy.requestOptionsOptionsParam?.signatureApprovalMemo, params.signatureApprovalMemo)
  }

  func test_sendAsset_willCall_portalProvider_request_passingCorrectParams_for_SolanaChain() async throws {
    // given
    let portalApiSpy = PortalApiMock()
    try initPortalWithSpy(api: portalApiSpy)
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)
    let params = SendAssetParams.stub(signatureApprovalMemo: "signatureApprovalMemo")
    let chainId = "solana:11155111"

    // and given
    _ = try await portal.sendAsset(chainId: chainId, params: params)

    // then
    XCTAssertEqual(portalProviderSpy.requestOptionsChainIdParam, chainId)
    XCTAssertEqual(portalProviderSpy.requestOptionsMethodParam, .sol_signAndSendTransaction)
    XCTAssertEqual(portalProviderSpy.requestOptionsOptionsParam?.signatureApprovalMemo, params.signatureApprovalMemo)
  }

  func test_sendAsset_willCall_portalAPI_buildBitcoinP2wpkhTransaction_passingCorrectParams_for_bip122Chain() async throws {
    // given
    let portalApiSpy = PortalApiSpy()
    try initPortalWithSpy(api: portalApiSpy)
    let portalProviderMock = PortalProviderMock()
    setToPortal(portalProvider: portalProviderMock)
    let params = SendAssetParams.stub(signatureApprovalMemo: "signatureApprovalMemo")
    let chainId = "bip122:000000000019d6689c085ae165831e93-p2wpkh"

    let buildTransactionParams = BuildTransactionParam(
      to: params.to,
      token: params.token,
      amount: params.amount
    )

    // and given
    _ = try await portal.sendAsset(chainId: chainId, params: params)

    // then
    XCTAssertEqual(portalApiSpy.buildBitcoinP2wpkhTransactionChainIdParam, chainId)
    XCTAssertEqual(portalApiSpy.buildBitcoinP2wpkhTransactionParams, buildTransactionParams)
  }

  func test_sendAsset_willCall_portalAPI_broadcastBitcoinP2wpkhTransaction_passingCorrectParams_for_bip122Chain() async throws {
    // given
    let rawTxHex = "rawTxHex"
    let portalApiSpy = PortalApiSpy()
    portalApiSpy.buildBitcoinP2wpkhTransactionReturnValue = BuildBitcoinP2wpkhTransactionResponse.stub(transaction: BitcoinP2wpkhTransaction.stub(signatureHashes: ["SignatureHash"], rawTxHex: rawTxHex))
    try initPortalWithSpy(api: portalApiSpy)

    let portalProviderMock = PortalProviderMock()
    let mockSignature = MockConstants.mockSignature
    portalProviderMock.requestReturnValue = PortalProviderResult(
      id: MockConstants.mockProviderRequestId,
      result: mockSignature
    )
    setToPortal(portalProvider: portalProviderMock)

    let params = SendAssetParams.stub(signatureApprovalMemo: "signatureApprovalMemo")
    let chainId = "bip122:000000000019d6689c085ae165831e93-p2wpkh"

    let broadcastParamParams = BroadcastParam(signatures: [mockSignature], rawTxHex: rawTxHex)

    // and given
    _ = try await portal.sendAsset(chainId: chainId, params: params)

    // then
    XCTAssertEqual(portalApiSpy.broadcastBitcoinP2wpkhTransactionChainIdParam, chainId)
    XCTAssertEqual(portalApiSpy.broadcastBitcoinP2wpkhTransactionParams, broadcastParamParams)
  }

  func test_sendAsset_willCall_portalAPI_broadcastBitcoinP2wpkhTransaction_passingCorrectParams_whenHavingMoreThanSingatureHash_for_bip122Chain() async throws {
    // given
    let rawTxHex = "rawTxHex"
    let portalApiSpy = PortalApiSpy()
    portalApiSpy.buildBitcoinP2wpkhTransactionReturnValue = BuildBitcoinP2wpkhTransactionResponse.stub(transaction: BitcoinP2wpkhTransaction.stub(signatureHashes: ["SignatureHash-1", "SignatureHash-2", "SignatureHash-3"], rawTxHex: rawTxHex))
    try initPortalWithSpy(api: portalApiSpy)

    let portalProviderMock = PortalProviderMock()
    let mockSignature = MockConstants.mockSignature
    portalProviderMock.requestReturnValue = PortalProviderResult(
      id: MockConstants.mockProviderRequestId,
      result: mockSignature
    )
    setToPortal(portalProvider: portalProviderMock)

    let params = SendAssetParams.stub(signatureApprovalMemo: "signatureApprovalMemo")
    let chainId = "bip122:000000000019d6689c085ae165831e93-p2wpkh"

    let broadcastParamParams = BroadcastParam(signatures: [mockSignature, mockSignature, mockSignature], rawTxHex: rawTxHex) // Should have 3 signatures one per signature hash

    // and given
    _ = try await portal.sendAsset(chainId: chainId, params: params)

    // then
    XCTAssertEqual(portalApiSpy.broadcastBitcoinP2wpkhTransactionChainIdParam, chainId)
    XCTAssertEqual(portalApiSpy.broadcastBitcoinP2wpkhTransactionParams, broadcastParamParams)
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

  func test_sendAsset_withUnsupportedBitCoinChainId_willThroughCorrectError() async throws {
    // given
    let unsupportedBitcoinChainIds: [String] = [
      "bip122:000000000019d6689c085ae165831e93-p2pkh", // mainnet legacy (1-prefix)
      "bip122:000000000019d6689c085ae165831e93-p2sh", // mainnet script hash (3-prefix)
      "bip122:000000000019d6689c085ae165831e93-p2tr", // mainnet taproot (bc1p-prefix)
      "bip122:000000000933ea01ad0ee984209779ba-p2pkh", // testnet legacy
      "bip122:000000000933ea01ad0ee984209779ba-p2sh", // testnet script hash
      "bip122:000000000933ea01ad0ee984209779ba-p2tr", // testnet taproot
      "bip122:0f9188f13cb7b2c71f2a335e3a4fc328-p2pkh", // regtest legacy
      "bip122:0f9188f13cb7b2c71f2a335e3a4fc328-p2sh", // regtest script hash
      "bip122:0f9188f13cb7b2c71f2a335e3a4fc328-p2tr" // regtest taproot
    ]

    for chainId in unsupportedBitcoinChainIds {
      do {
        // and given
        _ = try await portal.sendAsset(chainId: chainId, params: SendAssetParams.stub())
        XCTFail("Expected error not thrown when calling Portal.sendAsset passing unsupported Bitcoin chain id.")

      } catch {
        // then
        XCTAssertEqual(error as? PortalClassError, PortalClassError.unsupportedChainId(chainId))
      }
    }
  }

  func test_sendAsset_withSupportedBitCoinChainId_willNotThroughCorrectError() async throws {
    // given
    let portalApiMock = PortalApiMock()
    try initPortalWithSpy(api: portalApiMock)
    let portalProviderMock = PortalProviderMock()
    setToPortal(portalProvider: portalProviderMock)

    // and given
    let supportedBitcoinChainIds: [String] = [
      "bip122:000000000019d6689c085ae165831e93-p2wpkh",
      "bip122:000000000933ea01ad0ee984209779ba-p2wpkh"
    ]

    for chainId in supportedBitcoinChainIds {
      do {
        // and given
        _ = try await portal.sendAsset(chainId: chainId, params: SendAssetParams.stub())

      } catch {
        // then
        XCTFail("Calling Portal.sendAsset passing p2wpkh supported Bitcoin chain id should not throw error.")
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

// MARK: - updateChain tests

extension PortalTests {
  func test_updateChain_willCall_provider_updateChain_onlyOnce() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    portal.updateChain(newChainId: "")

    XCTAssertEqual(portalProviderSpy.updateChainCount, 1)
  }

  func test_updateChain_willCall_provider_updateChain_passingCorrectParams() async throws {
    // given
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    let chainId = "eip155:11155111"

    // and given
    portal.updateChain(newChainId: chainId)

    XCTAssertEqual(portalProviderSpy.updateChainNewChainIdParam, chainId)
  }
}

// MARK: - rawSign tests

extension PortalTests {
  func test_rawSign_willCall_portalProvider_request_onlyOnce() async throws {
    // given
    let portalApiSpy = PortalApiMock()
    portalApiSpy.buildSolanaTransactionReturnValue = BuildSolanaTransactionResponse.stub()
    try initPortalWithSpy(api: portalApiSpy)
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)

    // and given
    _ = try await portal.rawSign(message: "", chainId: "")

    // then
    XCTAssertEqual(portalProviderSpy.requestOptionsCallsCount, 1)
  }

  func test_rawSign_willCall_portalProvider_request_passingCorrectParams() async throws {
    // given
    let portalApiSpy = PortalApiMock()
    try initPortalWithSpy(api: portalApiSpy)
    let portalProviderSpy = PortalProviderSpy()
    setToPortal(portalProvider: portalProviderSpy)
    let message = "message to sign"
    let chainId = "eip155:11155111"
    let signatureApprovalMemo = "signature approval memo"

    // and given
    _ = try await portal.rawSign(message: message, chainId: chainId, signatureApprovalMemo: signatureApprovalMemo)

    // then
    XCTAssertEqual(portalProviderSpy.requestOptionsChainIdParam, chainId)
    XCTAssertEqual(portalProviderSpy.requestOptionsMethodParam, .rawSign)
    XCTAssertEqual(portalProviderSpy.requestOptionsParamsParam, [AnyCodable(message)])
    XCTAssertEqual(portalProviderSpy.requestOptionsOptionsParam?.signatureApprovalMemo, signatureApprovalMemo)
  }
}

// MARK: - yield property tests

extension PortalTests {
  func test_yield_propertyExists() {
    // given & when
    let yieldProperty = portal.yield

    // then
    XCTAssertNotNil(yieldProperty)
  }

  func test_yield_isOfCorrectType() {
    // given & when
    let yieldProperty = portal.yield

    // then
    XCTAssertTrue(yieldProperty is Yield)
  }

  func test_yield_returnsSameInstanceOnMultipleAccesses() {
    // given
    let firstAccess = portal.yield

    // when
    let secondAccess = portal.yield

    // then - lazy var should return the same instance
    XCTAssertTrue(firstAccess === secondAccess)
  }

  func test_yield_hasYieldxyzProperty() {
    // given & when
    let yieldxyz = portal.yield.yieldxyz

    // then
    XCTAssertNotNil(yieldxyz)
    XCTAssertTrue(yieldxyz is YieldXyzProtocol)
  }

  func test_yield_yieldxyz_canCallDiscover() async throws {
    // given
    let mockResponse = YieldXyzGetYieldsResponse.stub()
    let yieldXyzApiMock = PortalYieldXyzApiMock()
    yieldXyzApiMock.getYieldsReturnValue = mockResponse
    let portalApiMock = PortalApiMock(yieldxyz: yieldXyzApiMock)
    try initPortalWithSpy(api: portalApiMock)

    // when
    let response = try await portal.yield.yieldxyz.discover(request: nil)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(yieldXyzApiMock.getYieldsCalls, 1)
  }

  func test_yield_yieldxyz_canCallDiscoverWithRequest() async throws {
    // given
    let mockResponse = YieldXyzGetYieldsResponse.stub()
    let yieldXyzApiMock = PortalYieldXyzApiMock()
    yieldXyzApiMock.getYieldsReturnValue = mockResponse
    let portalApiMock = PortalApiMock(yieldxyz: yieldXyzApiMock)
    try initPortalWithSpy(api: portalApiMock)

    let request = YieldXyzGetYieldsRequest(
      offset: 0,
      yieldId: "yield-1",
      network: "eip155:1",
      limit: 10
    )

    // when
    let response = try await portal.yield.yieldxyz.discover(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(yieldXyzApiMock.getYieldsCalls, 1)
  }

  func test_yield_yieldxyz_canCallEnter() async throws {
    // given
    let mockResponse = YieldXyzEnterYieldResponse.stub()
    let yieldXyzApiMock = PortalYieldXyzApiMock()
    yieldXyzApiMock.enterYieldReturnValue = mockResponse
    let portalApiMock = PortalApiMock(yieldxyz: yieldXyzApiMock)
    try initPortalWithSpy(api: portalApiMock)

    let request = YieldXyzEnterRequest(
      yieldId: "yield-1",
      address: "0x1234567890abcdef1234567890abcdef12345678"
    )

    // when
    let response = try await portal.yield.yieldxyz.enter(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(response.data?.rawResponse.intent, .enter)
    XCTAssertEqual(yieldXyzApiMock.enterYieldCalls, 1)
  }

  func test_yield_yieldxyz_canCallExit() async throws {
    // given
    let mockResponse = YieldXyzExitResponse.stub()
    let yieldXyzApiMock = PortalYieldXyzApiMock()
    yieldXyzApiMock.exitYieldReturnValue = mockResponse
    let portalApiMock = PortalApiMock(yieldxyz: yieldXyzApiMock)
    try initPortalWithSpy(api: portalApiMock)

    let request = YieldXyzExitRequest(
      yieldId: "yield-1",
      address: "0x1234567890abcdef1234567890abcdef12345678"
    )

    // when
    let response = try await portal.yield.yieldxyz.exit(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(response.data?.rawResponse.intent, .exit)
    XCTAssertEqual(yieldXyzApiMock.exitYieldCalls, 1)
  }

  func test_yield_yieldxyz_canCallManage() async throws {
    // given
    let mockResponse = YieldXyzManageYieldResponse.stub()
    let yieldXyzApiMock = PortalYieldXyzApiMock()
    yieldXyzApiMock.manageYieldReturnValue = mockResponse
    let portalApiMock = PortalApiMock(yieldxyz: yieldXyzApiMock)
    try initPortalWithSpy(api: portalApiMock)

    let request = YieldXyzManageYieldRequest(
      yieldId: "yield-1",
      address: "0x1234567890abcdef1234567890abcdef12345678",
      arguments: YieldXyzEnterArguments(),
      action: .CLAIM_REWARDS,
      passthrough: "passthrough-data"
    )

    // when
    let response = try await portal.yield.yieldxyz.manage(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(response.data?.rawResponse.intent, .manage)
    XCTAssertEqual(yieldXyzApiMock.manageYieldCalls, 1)
  }

  func test_yield_yieldxyz_canCallGetBalances() async throws {
    // given
    let mockResponse = YieldXyzGetBalancesResponse.stub()
    let yieldXyzApiMock = PortalYieldXyzApiMock()
    yieldXyzApiMock.getYieldBalancesReturnValue = mockResponse
    let portalApiMock = PortalApiMock(yieldxyz: yieldXyzApiMock)
    try initPortalWithSpy(api: portalApiMock)

    let query = YieldXyzBalanceQuery(
      address: "0x1234567890abcdef1234567890abcdef12345678",
      network: "eip155:1",
      yieldId: "yield-1"
    )
    let request = YieldXyzGetBalancesRequest(queries: [query])

    // when
    let response = try await portal.yield.yieldxyz.getBalances(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(yieldXyzApiMock.getYieldBalancesCalls, 1)
  }

  func test_yield_yieldxyz_canCallGetHistoricalActions() async throws {
    // given
    let mockResponse = YieldXyzGetHistoricalActionsResponse.stub()
    let yieldXyzApiMock = PortalYieldXyzApiMock()
    yieldXyzApiMock.getHistoricalYieldActionsReturnValue = mockResponse
    let portalApiMock = PortalApiMock(yieldxyz: yieldXyzApiMock)
    try initPortalWithSpy(api: portalApiMock)

    let request = YieldXyzGetHistoricalActionsRequest(
      address: "0x1234567890abcdef1234567890abcdef12345678"
    )

    // when
    let response = try await portal.yield.yieldxyz.getHistoricalActions(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(yieldXyzApiMock.getHistoricalYieldActionsCalls, 1)
  }

  func test_yield_yieldxyz_canCallGetTransaction() async throws {
    // given
    let mockResponse = YieldXyzGetTransactionResponse.stub()
    let yieldXyzApiMock = PortalYieldXyzApiMock()
    yieldXyzApiMock.getYieldTransactionReturnValue = mockResponse
    let portalApiMock = PortalApiMock(yieldxyz: yieldXyzApiMock)
    try initPortalWithSpy(api: portalApiMock)

    let transactionId = "tx-123"

    // when
    let response = try await portal.yield.yieldxyz.getTransaction(transactionId: transactionId)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(yieldXyzApiMock.getYieldTransactionCalls, 1)
  }

  func test_yield_yieldxyz_canCallTrack() async throws {
    // given
    let mockResponse = YieldXyzTrackTransactionResponse.stub()
    let yieldXyzApiMock = PortalYieldXyzApiMock()
    yieldXyzApiMock.submitTransactionHashReturnValue = mockResponse
    let portalApiMock = PortalApiMock(yieldxyz: yieldXyzApiMock)
    try initPortalWithSpy(api: portalApiMock)

    let transactionId = "tx-123"
    let txHash = "0xhash123"

    // when
    let response = try await portal.yield.yieldxyz.track(transactionId: transactionId, txHash: txHash)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(yieldXyzApiMock.submitTransactionHashCalls, 1)
  }

  func test_yield_usesPortalApiInstance() {
    // given
    let yieldProperty = portal.yield

    // when - access yieldxyz which uses portal.api.yieldxyz internally
    let yieldxyz = yieldProperty.yieldxyz

    // then - should not be nil and should be properly initialized
    XCTAssertNotNil(yieldxyz)
  }

  func test_yield_multipleAccessesSameInstance() {
    // given
    let firstYield = portal.yield
    let firstYieldxyz = firstYield.yieldxyz

    // when
    let secondYield = portal.yield
    let secondYieldxyz = secondYield.yieldxyz

    // then - yield should be same instance (lazy var)
    XCTAssertTrue(firstYield === secondYield)
    // yieldxyz should also be same instance (let property in Yield)
    XCTAssertTrue(firstYieldxyz as AnyObject === secondYieldxyz as AnyObject)
  }

  func test_yield_errorPropagation() async throws {
    // given
    let mockError = "Mock error"
    let yieldXyzApiMock = PortalYieldXyzApiMock()
    // Force yieldXyzApiMock to throw by not setting return value and making it fail
    yieldXyzApiMock.getYieldsReturnValue = YieldXyzGetYieldsResponse(data: nil, error: mockError)
    let portalApiMock = PortalApiMock(yieldxyz: yieldXyzApiMock)
    try initPortalWithSpy(api: portalApiMock)

    // when
    let response = try await portal.yield.yieldxyz.discover(request: nil)

    // then - error should be returned in response
    XCTAssertNotNil(response)
    XCTAssertEqual(response.error, mockError)
    XCTAssertNil(response.data)
  }

  func test_yield_differentPortalsHaveDifferentYieldInstances() throws {
    // given
    let portal2 = try Portal(
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

    let yield1 = portal.yield
    let yield2 = portal2.yield

    // then - different Portal instances should have different Yield instances
    XCTAssertFalse(yield1 === yield2)
  }

  func test_yield_withCustomApi() async throws {
    // given
    let customApiKey = "custom-yield-api-key"
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzGetYieldsResponse.stub()
    portalRequestsSpy.returnData = try JSONEncoder().encode(mockResponse)

    let customApi = PortalApi(
      apiKey: customApiKey,
      apiHost: MockConstants.mockHost,
      requests: portalRequestsSpy
    )

    let customPortal = try Portal(
      MockConstants.mockApiKey,
      withRpcConfig: ["eip155:11155111": "https://\(MockConstants.mockHost)/test-rpc"],
      api: customApi,
      binary: binary,
      gDrive: MockGDriveStorage(),
      iCloud: MockICloudStorage(),
      keychain: keychain,
      mpc: MockPortalMpc(),
      passwords: MockPasswordStorage()
    )

    // when
    _ = try await customPortal.yield.yieldxyz.discover(request: nil)

    // then - should use custom API key
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.headers["Authorization"], "Bearer \(customApiKey)")
  }
}

// MARK: - trading property tests

extension PortalTests {
  func test_trading_propertyExists() {
    // given & when
    let tradingProperty = portal.trading

    // then
    XCTAssertNotNil(tradingProperty)
  }

  func test_trading_isOfCorrectType() {
    // given & when
    let tradingProperty = portal.trading

    // then
    XCTAssertTrue(tradingProperty is Trading)
  }

  func test_trading_returnsSameInstanceOnMultipleAccesses() {
    // given
    let firstAccess = portal.trading

    // when
    let secondAccess = portal.trading

    // then - lazy var should return the same instance
    XCTAssertTrue(firstAccess === secondAccess)
  }

  func test_trading_hasLifiProperty() {
    // given & when
    let lifi = portal.trading.lifi

    // then
    XCTAssertNotNil(lifi)
    XCTAssertTrue(lifi is LifiProtocol)
  }

  func test_trading_lifi_canCallGetRoutes() async throws {
    // given
    let mockResponse = LifiRoutesResponse.stub()
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getRoutesReturnValue = mockResponse
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    let request = LifiRoutesRequest.stub()

    // when
    let response = try await portal.trading.lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(lifiApiMock.getRoutesCalls, 1)
  }

  func test_trading_lifi_canCallGetRoutesWithFullRequest() async throws {
    // given
    let mockResponse = LifiRoutesResponse.stub()
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getRoutesReturnValue = mockResponse
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    let options = LifiRoutesRequestOptions.stub(
      slippage: 0.01,
      order: .cheapest,
      allowSwitchChain: true
    )
    let request = LifiRoutesRequest(
      fromChainId: "1",
      fromAmount: "1000000000000000000",
      fromTokenAddress: "0x0000000000000000000000000000000000000000",
      toChainId: "137",
      toTokenAddress: "0x0000000000000000000000000000000000001010",
      options: options,
      fromAddress: "0x1234567890abcdef1234567890abcdef12345678",
      toAddress: "0x1234567890abcdef1234567890abcdef12345678"
    )

    // when
    let response = try await portal.trading.lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(lifiApiMock.getRoutesCalls, 1)
  }

  func test_trading_lifi_canCallGetQuote() async throws {
    // given
    let mockResponse = LifiQuoteResponse.stub()
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getQuoteReturnValue = mockResponse
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    let request = LifiQuoteRequest.stub()

    // when
    let response = try await portal.trading.lifi.getQuote(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(lifiApiMock.getQuoteCalls, 1)
  }

  func test_trading_lifi_canCallGetQuoteWithFullRequest() async throws {
    // given
    let mockResponse = LifiQuoteResponse.stub()
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getQuoteReturnValue = mockResponse
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    let request = LifiQuoteRequest(
      fromChain: "1",
      toChain: "137",
      fromToken: "ETH",
      toToken: "MATIC",
      fromAddress: "0x1234567890abcdef1234567890abcdef12345678",
      fromAmount: "1000000000000000000",
      toAddress: "0xabcdef1234567890abcdef1234567890abcdef12",
      order: .fastest,
      slippage: 0.005,
      integrator: "portal",
      allowBridges: ["hop", "across"],
      allowExchanges: ["uniswap"],
      allowDestinationCall: true
    )

    // when
    let response = try await portal.trading.lifi.getQuote(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(lifiApiMock.getQuoteCalls, 1)
  }

  func test_trading_lifi_canCallGetStatus() async throws {
    // given
    let mockResponse = LifiStatusResponse.stub()
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getStatusReturnValue = mockResponse
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    let request = LifiStatusRequest.stub()

    // when
    let response = try await portal.trading.lifi.getStatus(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(response.data?.rawResponse.status, .done)
    XCTAssertEqual(lifiApiMock.getStatusCalls, 1)
  }

  func test_trading_lifi_canCallGetStatusWithFullRequest() async throws {
    // given
    let mockResponse = LifiStatusResponse.stub()
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getStatusReturnValue = mockResponse
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    let request = LifiStatusRequest(
      txHash: "0xabc123def456789",
      bridge: .relay,
      fromChain: "1",
      toChain: "137"
    )

    // when
    let response = try await portal.trading.lifi.getStatus(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(lifiApiMock.getStatusCalls, 1)
  }

  func test_trading_lifi_canCallGetRouteStep() async throws {
    // given
    let mockResponse = LifiStepTransactionResponse.stub()
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getRouteStepReturnValue = mockResponse
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    let request = LifiStep.stub()

    // when
    let response = try await portal.trading.lifi.getRouteStep(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(lifiApiMock.getRouteStepCalls, 1)
  }

  func test_trading_lifi_canCallGetRouteStepWithSwapStep() async throws {
    // given
    let mockResponse = LifiStepTransactionResponse.stub()
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getRouteStepReturnValue = mockResponse
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    let request = LifiStep.stub(type: .swap, tool: "uniswap")

    // when
    let response = try await portal.trading.lifi.getRouteStep(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(lifiApiMock.getRouteStepCalls, 1)
  }

  func test_trading_lifi_canCallGetRouteStepWithCrossChainStep() async throws {
    // given
    let mockResponse = LifiStepTransactionResponse.stub()
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getRouteStepReturnValue = mockResponse
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    let request = LifiStep.stub(type: .cross, tool: "relay")

    // when
    let response = try await portal.trading.lifi.getRouteStep(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(lifiApiMock.getRouteStepCalls, 1)
  }

  func test_trading_usesPortalApiInstance() {
    // given
    let tradingProperty = portal.trading

    // when - access lifi which uses portal.api.lifi internally
    let lifi = tradingProperty.lifi

    // then - should not be nil and should be properly initialized
    XCTAssertNotNil(lifi)
  }

  func test_trading_multipleAccessesSameInstance() {
    // given
    let firstTrading = portal.trading
    let firstLifi = firstTrading.lifi

    // when
    let secondTrading = portal.trading
    let secondLifi = secondTrading.lifi

    // then - trading should be same instance (lazy var)
    XCTAssertTrue(firstTrading === secondTrading)
    // lifi should also be same instance (var property in Trading)
    XCTAssertTrue(firstLifi as AnyObject === secondLifi as AnyObject)
  }

  func test_trading_lifi_errorPropagation_getRoutes() async throws {
    // given
    let mockError = "No routes found"
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getRoutesReturnValue = LifiRoutesResponse(data: nil, error: mockError)
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    // when
    let response = try await portal.trading.lifi.getRoutes(request: LifiRoutesRequest.stub())

    // then - error should be returned in response
    XCTAssertNotNil(response)
    XCTAssertEqual(response.error, mockError)
    XCTAssertNil(response.data)
  }

  func test_trading_lifi_errorPropagation_getQuote() async throws {
    // given
    let mockError = "Unable to find quote"
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getQuoteReturnValue = LifiQuoteResponse(data: nil, error: mockError)
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    // when
    let response = try await portal.trading.lifi.getQuote(request: LifiQuoteRequest.stub())

    // then - error should be returned in response
    XCTAssertNotNil(response)
    XCTAssertEqual(response.error, mockError)
    XCTAssertNil(response.data)
  }

  func test_trading_lifi_errorPropagation_getStatus() async throws {
    // given
    let mockError = "Transaction not found"
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getStatusReturnValue = LifiStatusResponse(data: nil, error: mockError)
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    // when
    let response = try await portal.trading.lifi.getStatus(request: LifiStatusRequest.stub())

    // then - error should be returned in response
    XCTAssertNotNil(response)
    XCTAssertEqual(response.error, mockError)
    XCTAssertNil(response.data)
  }

  func test_trading_lifi_errorPropagation_getRouteStep() async throws {
    // given
    let mockError = "Step execution failed"
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getRouteStepReturnValue = LifiStepTransactionResponse(data: nil, error: mockError)
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    // when
    let response = try await portal.trading.lifi.getRouteStep(request: LifiStep.stub())

    // then - error should be returned in response
    XCTAssertNotNil(response)
    XCTAssertEqual(response.error, mockError)
    XCTAssertNil(response.data)
  }

  func test_trading_differentPortalsHaveDifferentTradingInstances() throws {
    // given
    let portal2 = try Portal(
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

    let trading1 = portal.trading
    let trading2 = portal2.trading

    // then - different Portal instances should have different Trading instances
    XCTAssertFalse(trading1 === trading2)
  }

  func test_trading_lifi_withCustomApi() async throws {
    // given
    let customApiKey = "custom-trading-api-key"
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = LifiRoutesResponse.stub()
    portalRequestsSpy.returnData = try JSONEncoder().encode(mockResponse)

    let customApi = PortalApi(
      apiKey: customApiKey,
      apiHost: MockConstants.mockHost,
      requests: portalRequestsSpy
    )

    let customPortal = try Portal(
      MockConstants.mockApiKey,
      withRpcConfig: ["eip155:11155111": "https://\(MockConstants.mockHost)/test-rpc"],
      api: customApi,
      binary: binary,
      gDrive: MockGDriveStorage(),
      iCloud: MockICloudStorage(),
      keychain: keychain,
      mpc: MockPortalMpc(),
      passwords: MockPasswordStorage()
    )

    // when
    _ = try await customPortal.trading.lifi.getRoutes(request: LifiRoutesRequest.stub())

    // then - should use custom API key
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.headers["Authorization"], "Bearer \(customApiKey)")
  }

  func test_trading_lifi_getRoutesWithMultipleRoutes() async throws {
    // given
    let routes = [
      LifiRoute.stub(id: "route-1", tags: ["FASTEST"]),
      LifiRoute.stub(id: "route-2", tags: ["CHEAPEST"]),
      LifiRoute.stub(id: "route-3", tags: ["RECOMMENDED"])
    ]
    let rawResponse = LifiRoutesRawResponse.stub(routes: routes)
    let mockResponse = LifiRoutesResponse.stub(data: LifiRoutesData(rawResponse: rawResponse))
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getRoutesReturnValue = mockResponse
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    // when
    let response = try await portal.trading.lifi.getRoutes(request: LifiRoutesRequest.stub())

    // then
    XCTAssertEqual(response.data?.rawResponse.routes.count, 3)
    XCTAssertEqual(response.data?.rawResponse.routes[0].tags, ["FASTEST"])
    XCTAssertEqual(response.data?.rawResponse.routes[1].tags, ["CHEAPEST"])
    XCTAssertEqual(response.data?.rawResponse.routes[2].tags, ["RECOMMENDED"])
  }

  func test_trading_lifi_getRoutesWithEmptyRoutes() async throws {
    // given
    let rawResponse = LifiRoutesRawResponse.stub(routes: [])
    let mockResponse = LifiRoutesResponse.stub(data: LifiRoutesData(rawResponse: rawResponse))
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getRoutesReturnValue = mockResponse
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    // when
    let response = try await portal.trading.lifi.getRoutes(request: LifiRoutesRequest.stub())

    // then
    XCTAssertEqual(response.data?.rawResponse.routes.count, 0)
  }

  func test_trading_lifi_getRoutesWithUnavailableRoutes() async throws {
    // given
    let unavailableRoutes = LifiUnavailableRoutes.stub(
      filteredOut: [LifiFilteredRoute.stub(reason: "Amount too low")],
      failed: [LifiFailedRoute.stub(overallPath: "1:ETH-hop-137:MATIC")]
    )
    let rawResponse = LifiRoutesRawResponse.stub(routes: [], unavailableRoutes: unavailableRoutes)
    let mockResponse = LifiRoutesResponse.stub(data: LifiRoutesData(rawResponse: rawResponse))
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getRoutesReturnValue = mockResponse
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    // when
    let response = try await portal.trading.lifi.getRoutes(request: LifiRoutesRequest.stub())

    // then
    XCTAssertNotNil(response.data?.rawResponse.unavailableRoutes)
    XCTAssertEqual(response.data?.rawResponse.unavailableRoutes?.filteredOut?.count, 1)
    XCTAssertEqual(response.data?.rawResponse.unavailableRoutes?.failed?.count, 1)
  }

  func test_trading_lifi_getStatusWithPendingStatus() async throws {
    // given
    let rawResponse = LifiStatusRawResponse.stub(
      status: .pending,
      substatus: .waitSourceConfirmations,
      substatusMessage: "Waiting for confirmations"
    )
    let mockResponse = LifiStatusResponse.stub(data: LifiStatusData(rawResponse: rawResponse))
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getStatusReturnValue = mockResponse
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    // when
    let response = try await portal.trading.lifi.getStatus(request: LifiStatusRequest.stub())

    // then
    XCTAssertEqual(response.data?.rawResponse.status, .pending)
    XCTAssertEqual(response.data?.rawResponse.substatus, .waitSourceConfirmations)
    XCTAssertEqual(response.data?.rawResponse.substatusMessage, "Waiting for confirmations")
  }

  func test_trading_lifi_getStatusWithFailedStatus() async throws {
    // given
    let rawResponse = LifiStatusRawResponse.stub(
      status: .failed,
      substatus: .unknownError,
      substatusMessage: "Transaction reverted"
    )
    let mockResponse = LifiStatusResponse.stub(data: LifiStatusData(rawResponse: rawResponse))
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getStatusReturnValue = mockResponse
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    // when
    let response = try await portal.trading.lifi.getStatus(request: LifiStatusRequest.stub())

    // then
    XCTAssertEqual(response.data?.rawResponse.status, .failed)
    XCTAssertEqual(response.data?.rawResponse.substatus, .unknownError)
  }

  func test_trading_lifi_getStatusWithNotFoundStatus() async throws {
    // given
    let rawResponse = LifiStatusRawResponse.stub(status: .notFound)
    let mockResponse = LifiStatusResponse.stub(data: LifiStatusData(rawResponse: rawResponse))
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getStatusReturnValue = mockResponse
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    // when
    let response = try await portal.trading.lifi.getStatus(request: LifiStatusRequest.stub())

    // then
    XCTAssertEqual(response.data?.rawResponse.status, .notFound)
  }

  func test_trading_lifi_getStatusWithReceivingInfo() async throws {
    // given
    let receiving = LifiReceivingInfo.stub(
      chainId: "137",
      txHash: "0xdef789",
      amount: "950000000000000000"
    )
    let rawResponse = LifiStatusRawResponse.stub(receiving: receiving)
    let mockResponse = LifiStatusResponse.stub(data: LifiStatusData(rawResponse: rawResponse))
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getStatusReturnValue = mockResponse
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    // when
    let response = try await portal.trading.lifi.getStatus(request: LifiStatusRequest.stub())

    // then
    XCTAssertNotNil(response.data?.rawResponse.receiving)
    XCTAssertEqual(response.data?.rawResponse.receiving?.chainId, "137")
    XCTAssertEqual(response.data?.rawResponse.receiving?.txHash, "0xdef789")
  }

  func test_trading_lifi_getQuoteWithEstimate() async throws {
    // given
    let estimate = LifiEstimate.stub(
      fromAmount: "1000000000000000000",
      toAmount: "950000000000000000",
      toAmountMin: "940000000000000000",
      executionDuration: 120.0,
      feeCosts: [LifiFeeCost.stub()],
      gasCosts: [LifiGasCost.stub()]
    )
    let step = LifiStep.stub(estimate: estimate)
    let mockResponse = LifiQuoteResponse(data: LifiQuoteData(rawResponse: step), error: nil)
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getQuoteReturnValue = mockResponse
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    // when
    let response = try await portal.trading.lifi.getQuote(request: LifiQuoteRequest.stub())

    // then
    XCTAssertNotNil(response.data?.rawResponse.estimate)
    XCTAssertEqual(response.data?.rawResponse.estimate?.executionDuration, 120.0)
    XCTAssertNotNil(response.data?.rawResponse.estimate?.feeCosts)
    XCTAssertNotNil(response.data?.rawResponse.estimate?.gasCosts)
  }

  func test_trading_lifi_getQuoteWithIncludedSteps() async throws {
    // given
    let step = LifiStep.stub(
      includedSteps: [
        LifiInternalStep.stub(id: "swap-1", type: .swap),
        LifiInternalStep.stub(id: "bridge-1", type: .cross)
      ]
    )
    let mockResponse = LifiQuoteResponse(data: LifiQuoteData(rawResponse: step), error: nil)
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getQuoteReturnValue = mockResponse
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    // when
    let response = try await portal.trading.lifi.getQuote(request: LifiQuoteRequest.stub())

    // then
    XCTAssertEqual(response.data?.rawResponse.includedSteps?.count, 2)
    XCTAssertEqual(response.data?.rawResponse.includedSteps?[0].type, .swap)
    XCTAssertEqual(response.data?.rawResponse.includedSteps?[1].type, .cross)
  }

  func test_trading_lifi_crossChainSwapFlow() async throws {
    // given
    let lifiApiMock = PortalLifiTradingApiMock()
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    // Step 1: Get routes
    let routes = [
      LifiRoute.stub(id: "route-1", tags: ["FASTEST"]),
      LifiRoute.stub(id: "route-2", tags: ["CHEAPEST"])
    ]
    lifiApiMock.getRoutesReturnValue = LifiRoutesResponse.stub(
      data: LifiRoutesData(rawResponse: LifiRoutesRawResponse(routes: routes, unavailableRoutes: nil))
    )

    let routesRequest = LifiRoutesRequest.stub()
    let routesResponse = try await portal.trading.lifi.getRoutes(request: routesRequest)

    // Step 2: Get quote for selected route
    lifiApiMock.getQuoteReturnValue = LifiQuoteResponse.stub()
    let quoteRequest = LifiQuoteRequest.stub()
    let quoteResponse = try await portal.trading.lifi.getQuote(request: quoteRequest)

    // Step 3: Get route step (transaction details)
    lifiApiMock.getRouteStepReturnValue = LifiStepTransactionResponse.stub()
    let stepRequest = LifiStep.stub()
    let stepResponse = try await portal.trading.lifi.getRouteStep(request: stepRequest)

    // Step 4: Check status
    lifiApiMock.getStatusReturnValue = LifiStatusResponse.stub(
      data: LifiStatusData(rawResponse: LifiStatusRawResponse.stub(status: .done, substatus: .completed))
    )
    let statusRequest = LifiStatusRequest.stub()
    let statusResponse = try await portal.trading.lifi.getStatus(request: statusRequest)

    // then
    XCTAssertEqual(routesResponse.data?.rawResponse.routes.count, 2)
    XCTAssertNotNil(quoteResponse.data)
    XCTAssertNotNil(stepResponse.data)
    XCTAssertEqual(statusResponse.data?.rawResponse.status, .done)
    XCTAssertEqual(statusResponse.data?.rawResponse.substatus, .completed)

    XCTAssertEqual(lifiApiMock.getRoutesCalls, 1)
    XCTAssertEqual(lifiApiMock.getQuoteCalls, 1)
    XCTAssertEqual(lifiApiMock.getRouteStepCalls, 1)
    XCTAssertEqual(lifiApiMock.getStatusCalls, 1)
  }

  func test_trading_lifi_apiCallsAreTrackedCorrectly() async throws {
    // given
    let lifiApiMock = PortalLifiTradingApiMock()
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    // when - make multiple calls
    _ = try await portal.trading.lifi.getRoutes(request: LifiRoutesRequest.stub())
    _ = try await portal.trading.lifi.getRoutes(request: LifiRoutesRequest.stub())
    _ = try await portal.trading.lifi.getQuote(request: LifiQuoteRequest.stub())
    _ = try await portal.trading.lifi.getStatus(request: LifiStatusRequest.stub())
    _ = try await portal.trading.lifi.getRouteStep(request: LifiStep.stub())

    // then
    XCTAssertEqual(lifiApiMock.getRoutesCalls, 2)
    XCTAssertEqual(lifiApiMock.getQuoteCalls, 1)
    XCTAssertEqual(lifiApiMock.getStatusCalls, 1)
    XCTAssertEqual(lifiApiMock.getRouteStepCalls, 1)
  }

  func test_trading_lifi_requestParametersAreCaptured() async throws {
    // given
    let lifiApiMock = PortalLifiTradingApiMock()
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    let routesRequest = LifiRoutesRequest(
      fromChainId: "1",
      fromAmount: "1000000000000000000",
      fromTokenAddress: "0xETH",
      toChainId: "137",
      toTokenAddress: "0xMATIC",
      options: LifiRoutesRequestOptions.stub(slippage: 0.02)
    )

    // when
    _ = try await portal.trading.lifi.getRoutes(request: routesRequest)

    // then
    XCTAssertNotNil(lifiApiMock.getRoutesRequestParam)
    XCTAssertEqual(lifiApiMock.getRoutesRequestParam?.fromChainId, "1")
    XCTAssertEqual(lifiApiMock.getRoutesRequestParam?.toChainId, "137")
    XCTAssertEqual(lifiApiMock.getRoutesRequestParam?.options?.slippage, 0.02)
  }

  func test_trading_lifi_getStatusWithDifferentBridges() async throws {
    // given
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getStatusReturnValue = LifiStatusResponse.stub()
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    let bridges: [LifiStatusBridge] = [.hop, .across, .relay, .symbiosis]

    for bridge in bridges {
      let request = LifiStatusRequest(txHash: "0xtest", bridge: bridge)

      // when
      let response = try await portal.trading.lifi.getStatus(request: request)

      // then
      XCTAssertNotNil(response)
    }

    XCTAssertEqual(lifiApiMock.getStatusCalls, bridges.count)
  }

  func test_trading_lifi_getStatusAllStatuses() async throws {
    // given
    let lifiApiMock = PortalLifiTradingApiMock()
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    let statuses: [LifiTransferStatus] = [.notFound, .invalid, .pending, .done, .failed]

    for status in statuses {
      lifiApiMock.getStatusReturnValue = LifiStatusResponse.stub(
        data: LifiStatusData(rawResponse: LifiStatusRawResponse.stub(status: status))
      )
      let request = LifiStatusRequest.stub()

      // when
      let response = try await portal.trading.lifi.getStatus(request: request)

      // then
      XCTAssertEqual(response.data?.rawResponse.status, status)
    }
  }

  func test_trading_lifi_getStatusAllSubstatuses() async throws {
    // given
    let lifiApiMock = PortalLifiTradingApiMock()
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    let substatuses: [LifiTransferSubstatus] = [
      .waitSourceConfirmations, .waitDestinationTransaction,
      .bridgeNotAvailable, .chainNotAvailable, .refundInProgress,
      .unknownError, .completed, .partial, .refunded
    ]

    for substatus in substatuses {
      lifiApiMock.getStatusReturnValue = LifiStatusResponse.stub(
        data: LifiStatusData(rawResponse: LifiStatusRawResponse.stub(substatus: substatus))
      )
      let request = LifiStatusRequest.stub()

      // when
      let response = try await portal.trading.lifi.getStatus(request: request)

      // then
      XCTAssertEqual(response.data?.rawResponse.substatus, substatus)
    }
  }

  func test_trading_lifi_getRoutesWithAllOptions() async throws {
    // given
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getRoutesReturnValue = LifiRoutesResponse.stub()
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    let bridges = LifiToolsConfiguration(
      allow: ["hop", "across", "relay"],
      deny: ["cbridge"],
      prefer: ["relay"]
    )
    let exchanges = LifiToolsConfiguration(
      allow: ["uniswap", "sushiswap"],
      deny: nil,
      prefer: ["1inch"]
    )
    let timing = LifiTimingOptions(
      swapStepTimingStrategies: [LifiTimingStrategy(strategy: .minWaitTime, minWaitTimeMs: 1000)],
      routeTimingStrategies: nil
    )
    let options = LifiRoutesRequestOptions(
      insurance: false,
      integrator: "portal",
      slippage: 0.01,
      bridges: bridges,
      exchanges: exchanges,
      order: .cheapest,
      allowSwitchChain: true,
      allowDestinationCall: true,
      referrer: "0xRef",
      fee: 0.003,
      maxPriceImpact: 0.15,
      timing: timing
    )
    let request = LifiRoutesRequest(
      fromChainId: "1",
      fromAmount: "1000000000000000000",
      fromTokenAddress: "0xETH",
      toChainId: "137",
      toTokenAddress: "0xMATIC",
      options: options,
      fromAddress: "0xSender",
      toAddress: "0xReceiver",
      fromAmountForGas: "50000000000000000"
    )

    // when
    let response = try await portal.trading.lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(lifiApiMock.getRoutesCalls, 1)
    XCTAssertEqual(lifiApiMock.getRoutesRequestParam?.options?.slippage, 0.01)
    XCTAssertEqual(lifiApiMock.getRoutesRequestParam?.options?.order, .cheapest)
    XCTAssertEqual(lifiApiMock.getRoutesRequestParam?.options?.bridges?.allow?.count, 3)
  }

  func test_trading_lifi_getQuoteWithAllOptions() async throws {
    // given
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getQuoteReturnValue = LifiQuoteResponse.stub()
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    let request = LifiQuoteRequest(
      fromChain: "1",
      toChain: "137",
      fromToken: "ETH",
      toToken: "MATIC",
      fromAddress: "0xSender",
      fromAmount: "1000000000000000000",
      toAddress: "0xReceiver",
      order: .fastest,
      slippage: 0.005,
      integrator: "portal",
      fee: 0.003,
      referrer: "0xRef",
      allowBridges: ["hop", "across"],
      allowExchanges: ["uniswap"],
      denyBridges: ["cbridge"],
      denyExchanges: nil,
      preferBridges: ["relay"],
      preferExchanges: ["1inch"],
      allowDestinationCall: true,
      fromAmountForGas: "50000000000000000",
      maxPriceImpact: 0.15,
      swapStepTimingStrategies: ["minWaitTime-1000"],
      routeTimingStrategies: nil,
      skipSimulation: true
    )

    // when
    let response = try await portal.trading.lifi.getQuote(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(lifiApiMock.getQuoteCalls, 1)
    XCTAssertEqual(lifiApiMock.getQuoteRequestParam?.order, .fastest)
    XCTAssertEqual(lifiApiMock.getQuoteRequestParam?.slippage, 0.005)
    XCTAssertEqual(lifiApiMock.getQuoteRequestParam?.skipSimulation, true)
  }

  func test_trading_lifi_handlesRouteError() async throws {
    // given
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getRoutesReturnValue = LifiRoutesResponse(data: nil, error: "No routes available")
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    // when
    let response = try await portal.trading.lifi.getRoutes(request: LifiRoutesRequest.stub())

    // then
    XCTAssertNil(response.data)
    XCTAssertEqual(response.error, "No routes available")
  }

  func test_trading_lifi_handlesQuoteError() async throws {
    // given
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getQuoteReturnValue = LifiQuoteResponse(data: nil, error: "Quote not available")
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    // when
    let response = try await portal.trading.lifi.getQuote(request: LifiQuoteRequest.stub())

    // then
    XCTAssertNil(response.data)
    XCTAssertEqual(response.error, "Quote not available")
  }

  func test_trading_lifi_handlesStatusError() async throws {
    // given
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getStatusReturnValue = LifiStatusResponse(data: nil, error: "Transaction not found")
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    // when
    let response = try await portal.trading.lifi.getStatus(request: LifiStatusRequest.stub())

    // then
    XCTAssertNil(response.data)
    XCTAssertEqual(response.error, "Transaction not found")
  }

  func test_trading_lifi_handlesStepError() async throws {
    // given
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getRouteStepReturnValue = LifiStepTransactionResponse(data: nil, error: "Step execution failed")
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    // when
    let response = try await portal.trading.lifi.getRouteStep(request: LifiStep.stub())

    // then
    XCTAssertNil(response.data)
    XCTAssertEqual(response.error, "Step execution failed")
  }

  func test_trading_lifi_throwsApiError() async throws {
    // given
    let lifiApiMock = PortalLifiTradingApiMock()
    let expectedError = NSError(domain: "TestError", code: 500, userInfo: nil)
    lifiApiMock.getRoutesError = expectedError
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    // when/then
    do {
      _ = try await portal.trading.lifi.getRoutes(request: LifiRoutesRequest.stub())
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual((error as NSError).code, 500)
    }
  }

  func test_trading_lifi_edgeCaseVeryLargeAmount() async throws {
    // given
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getRoutesReturnValue = LifiRoutesResponse.stub()
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    let request = LifiRoutesRequest(
      fromChainId: "1",
      fromAmount: "999999999999999999999999999999999999",
      fromTokenAddress: "0x0",
      toChainId: "137",
      toTokenAddress: "0x0"
    )

    // when
    let response = try await portal.trading.lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(lifiApiMock.getRoutesRequestParam?.fromAmount, "999999999999999999999999999999999999")
  }

  func test_trading_lifi_edgeCaseZeroSlippage() async throws {
    // given
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getRoutesReturnValue = LifiRoutesResponse.stub()
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    let options = LifiRoutesRequestOptions(slippage: 0.0)
    let request = LifiRoutesRequest.stub(options: options)

    // when
    let response = try await portal.trading.lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(lifiApiMock.getRoutesRequestParam?.options?.slippage, 0.0)
  }

  func test_trading_lifi_edgeCaseMaxSlippage() async throws {
    // given
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getRoutesReturnValue = LifiRoutesResponse.stub()
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    let options = LifiRoutesRequestOptions(slippage: 1.0)
    let request = LifiRoutesRequest.stub(options: options)

    // when
    let response = try await portal.trading.lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(lifiApiMock.getRoutesRequestParam?.options?.slippage, 1.0)
  }

  func test_trading_lifi_multipleDifferentPortals() async throws {
    // given
    let lifiApiMock1 = PortalLifiTradingApiMock()
    lifiApiMock1.getRoutesReturnValue = LifiRoutesResponse.stub()
    let portalApiMock1 = PortalApiMock(lifi: lifiApiMock1)

    let lifiApiMock2 = PortalLifiTradingApiMock()
    lifiApiMock2.getRoutesReturnValue = LifiRoutesResponse.stub()
    let portalApiMock2 = PortalApiMock(lifi: lifiApiMock2)

    try initPortalWithSpy(api: portalApiMock1)
    let portal1 = portal

    try initPortalWithSpy(api: portalApiMock2)
    let portal2 = portal

    // when
    _ = try await portal1?.trading.lifi.getRoutes(request: LifiRoutesRequest.stub())
    _ = try await portal2?.trading.lifi.getRoutes(request: LifiRoutesRequest.stub())
    _ = try await portal1?.trading.lifi.getRoutes(request: LifiRoutesRequest.stub())

    // then
    XCTAssertEqual(lifiApiMock1.getRoutesCalls, 2)
    XCTAssertEqual(lifiApiMock2.getRoutesCalls, 1)
  }

  func test_trading_lifi_concurrentCalls() async throws {
    // given
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getRoutesReturnValue = LifiRoutesResponse.stub()
    let portalApiMock = PortalApiMock(lifi: lifiApiMock)
    try initPortalWithSpy(api: portalApiMock)

    let callCount = 5

    // when
    await withTaskGroup(of: LifiRoutesResponse.self) { group in
      for _ in 0 ..< callCount {
        group.addTask {
          try! await self.portal.trading.lifi.getRoutes(request: LifiRoutesRequest.stub())
        }
      }

      var responses: [LifiRoutesResponse] = []
      for await response in group {
        responses.append(response)
      }

      // then
      XCTAssertEqual(responses.count, callCount)
    }

    XCTAssertEqual(lifiApiMock.getRoutesCalls, callCount)
  }
}
