//
//  PortalProviderTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import AnyCodable
@testable import PortalSwift
import XCTest

final class PortalProviderTests: XCTestCase {
  var provider: PortalProvider!
  private var keychain: PortalKeychainProtocol!

  override func setUpWithError() throws {
    keychain = MockPortalKeychain()
    self.provider = try PortalProvider(
      apiKey: MockConstants.mockApiKey,
      rpcConfig: ["eip155:11155111": "https://\(MockConstants.mockHost)/test-rpc"],
      keychain: keychain,
      autoApprove: true,
      requests: MockPortalRequests(),
      signer: MockPortalMpcSigner(apiKey: MockConstants.mockApiKey, keychain: MockPortalKeychain())
    )

    self.provider.on(event: Events.PortalSigningRequested.rawValue) { data in
      self.provider.emit(event: Events.PortalSigningApproved.rawValue, data: data)
    }
  }

  override func tearDownWithError() throws {
    self.provider = nil
  }

  func testAddress() throws {
    let expectation = XCTestExpectation(description: "PortalProvider.address")
    let address = self.provider.address
    XCTAssertEqual(address, MockConstants.mockEip155Address)
    expectation.fulfill()
  }

  func testEmit() throws {
    let expectation = XCTestExpectation(description: "PortalProvider.emit(event, data)")
    var timesCalled = 0
    let _ = self.provider!.on(event: "test") { data in
      XCTAssertEqual(data as! String, "test")
      timesCalled += 1

      if timesCalled == 3 {
        expectation.fulfill()
      }
    }
    let _ = self.provider!.emit(event: "test", data: "test")
    let _ = self.provider!.emit(event: "test", data: "test")
    let _ = self.provider!.emit(event: "test", data: "test")
    wait(for: [expectation], timeout: 5.0)
  }

  func testOn() throws {
    let expectation = XCTestExpectation(description: "PortalProvider.on(event, callback)")
    var timesCalled = 0
    let _ = self.provider!.on(event: "test") { data in
      XCTAssertEqual(data as! String, "test")
      timesCalled += 1

      if timesCalled == 3 {
        expectation.fulfill()
      }
    }
    let _ = self.provider!.emit(event: "test", data: "test")
    let _ = self.provider!.emit(event: "test", data: "test")
    let _ = self.provider!.emit(event: "test", data: "test")
    wait(for: [expectation], timeout: 5.0)
  }

  func testOnce() throws {
    let expectation = XCTestExpectation(description: "PortalProvider.once(event, callback)")
    let _ = self.provider!.once(event: "test") { data in
      XCTAssertEqual(data as! String, "test")
      expectation.fulfill()
    }
    let _ = self.provider!.emit(event: "test", data: "test")
    wait(for: [expectation], timeout: 5.0)
  }

  func testRemoveListener() throws {
    let expectation = XCTestExpectation(description: "PortalProvider.removeListener(event)")
    let _ = self.provider!.on(event: "test-remove") { _ in
      XCTFail()
    }
    let _ = self.provider!.removeListener(event: "test-remove")
    let _ = self.provider!.emit(event: "test-remove", data: "test")
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
      expectation.fulfill()
    }
  }

  func testAccountsRequest() async throws {
    let expectation = XCTestExpectation(description: "PortalProvider.request(.eth_accounts)")
    let result = try await provider.request("eip155:11155111", withMethod: .eth_accounts)
    guard let accounts = result.result as? [String] else {
      throw PortalProviderError.invalidRpcResponse
    }
    XCTAssertEqual(accounts, [MockConstants.mockEip155Address])
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testRpcRequest() async throws {
    let expectation = XCTestExpectation(description: "PortalProvider.request(.eth_accounts)")
    let result = try await provider.request("eip155:11155111", withMethod: .eth_gasPrice)
    guard let response = result.result as? PortalProviderRpcResponse else {
      throw PortalProviderError.invalidRpcResponse
    }
    XCTAssertEqual(response.result, MockConstants.mockRpcResponse.result)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testSendTransactionRequest() async throws {
    let expectation = XCTestExpectation(description: "PortalProvider.request(.eth_sendTransaction)")
    let transaction = AnyCodable([:] as [String: String])
    let result = try await provider.request("eip155:11155111", withMethod: .eth_sendTransaction, andParams: [transaction])
    guard let transactionHash = result.result as? String else {
      throw PortalProviderError.invalidRpcResponse
    }
    XCTAssertEqual(transactionHash, MockConstants.mockTransactionHash)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testSendTransactionWithStringMethod() async throws {
    let expectation = XCTestExpectation(description: "PortalProvider.request(.eth_sendTransaction)")
    let transaction = AnyCodable([:] as [String: String])
    let result = try await provider.request(
      "eip155:11155111",
      withMethod: PortalRequestMethod.eth_sendTransaction.rawValue,
      andParams: [transaction]
    )
    guard let transactionHash = result.result as? String else {
      throw PortalProviderError.invalidRpcResponse
    }
    XCTAssertEqual(transactionHash, MockConstants.mockTransactionHash)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testSignAddressRequestCompletion() throws {
    let expectation = XCTestExpectation(description: "PortalProvider.request(pauload, completion)")
    let payload = ETHAddressPayload(
      method: PortalRequestMethod.eth_getBalance.rawValue,
      params: [ETHAddressParam(address: MockConstants.mockEip155Address)]
    )
    self.provider.request(payload: payload) { result in
      guard let transactionResult = result.data else {
        XCTFail()
        return
      }
      guard let response = transactionResult.result as? PortalProviderRpcResponse else {
        XCTFail()
        return
      }
      XCTAssertEqual(response, MockConstants.mockRpcResponse)
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 5.0)
  }

  func testSignMessageRequest() async throws {
    let expectation = XCTestExpectation(description: "PortalProvider.request(.eth_sign)")
    let params = [MockConstants.mockEip155Address, "test"].map { AnyCodable($0) }
    let result = try await provider.request("eip155:11155111", withMethod: .eth_sign, andParams: params)
    guard let signature = result.result as? String else {
      throw PortalProviderError.invalidRpcResponse
    }
    XCTAssertEqual(signature, MockConstants.mockSignature)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testSignMessageRequestWithApproval() async throws {
    let expectation = XCTestExpectation(description: "PortalProvider.request(.eth_sign)")
    self.provider.autoApprove = false
    let params = [MockConstants.mockEip155Address, "test"].map { AnyCodable($0) }
    let result = try await provider.request("eip155:11155111", withMethod: .eth_sign, andParams: params)
    guard let signature = result.result as? String else {
      throw PortalProviderError.invalidRpcResponse
    }
    XCTAssertEqual(signature, MockConstants.mockSignature)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
    self.provider.autoApprove = true
  }

  func testSignTransactionRequest() async throws {
    let expectation = XCTestExpectation(description: "PortalProvider.request(.eth_signTransaction)")
    let transaction = AnyCodable([:] as [String: String])
    let result = try await provider.request("eip155:11155111", withMethod: .eth_signTransaction, andParams: [transaction])
    guard let signature = result.result as? String else {
      throw PortalProviderError.invalidRpcResponse
    }
    XCTAssertEqual(signature, MockConstants.mockSignature)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testSignTransactionRequestCompletion() throws {
    let expectation = XCTestExpectation(description: "PortalProvider.request(pauload, completion)")
    let payload = ETHTransactionPayload(
      method: PortalRequestMethod.eth_signTransaction.rawValue,
      params: [ETHTransactionParam(from: MockConstants.mockEip155Address, to: MockConstants.mockEip155Address, gas: "test-gas", gasPrice: "test-gas-price", value: "test-transaction-value", data: "")]
    )
    self.provider.request(payload: payload) { result in
      guard let transactionResult = result.data else {
        XCTFail()
        return
      }
      guard let signature = transactionResult.result as? String else {
        XCTFail()
        return
      }
      XCTAssertEqual(signature, MockConstants.mockSignature)
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 5.0)
  }

  func testSignTransactionRequestCompletionWithApproval() throws {
    let expectation = XCTestExpectation(description: "PortalProvider.request(pauload, completion)")
    self.provider.autoApprove = false
    let payload = ETHTransactionPayload(
      method: PortalRequestMethod.eth_signTransaction.rawValue,
      params: [ETHTransactionParam(from: MockConstants.mockEip155Address, to: MockConstants.mockEip155Address, gas: "test-gas", gasPrice: "test-gas-price", value: "test-transaction-value", data: "")]
    )
    self.provider.request(payload: payload) { result in
      guard let transactionResult = result.data else {
        XCTFail()
        return
      }
      guard let signature = transactionResult.result as? String else {
        XCTFail()
        return
      }
      XCTAssertEqual(signature, MockConstants.mockSignature)
      expectation.fulfill()
      self.provider.autoApprove = true
    }
    wait(for: [expectation], timeout: 5.0)
  }
}

// MARK: - Request with chainId, method, params, connect, options Tests

extension PortalProviderTests {
  // MARK: - eth_accounts / eth_requestAccounts Tests

  func testRequest_ethAccounts_returnsAddressArray() async throws {
    let result = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_accounts,
      params: [],
      connect: nil,
      options: nil
    )
    guard let accounts = result.result as? [String?] else {
      XCTFail("Expected result to be [String?]")
      return
    }
    XCTAssertEqual(accounts.count, 1)
    XCTAssertEqual(accounts[0], MockConstants.mockEip155Address)
  }

  func testRequest_ethRequestAccounts_returnsAddressArray() async throws {
    let result = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_requestAccounts,
      params: [],
      connect: nil,
      options: nil
    )
    guard let accounts = result.result as? [String?] else {
      XCTFail("Expected result to be [String?]")
      return
    }
    XCTAssertEqual(accounts.count, 1)
    XCTAssertEqual(accounts[0], MockConstants.mockEip155Address)
  }

  func testRequest_ethAccounts_returnsValidId() async throws {
    let result = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_accounts,
      params: [],
      connect: nil,
      options: nil
    )
    XCTAssertFalse(result.id.isEmpty)
  }

  // MARK: - wallet_* Methods Tests

  func testRequest_walletSwitchEthereumChain_returnsNull() async throws {
    let result = try await provider.request(
      chainId: "eip155:11155111",
      method: .wallet_switchEthereumChain,
      params: [],
      connect: nil,
      options: nil
    )
    guard let resultValue = result.result as? String else {
      XCTFail("Expected result to be String")
      return
    }
    XCTAssertEqual(resultValue, "null")
  }

  func testRequest_walletRevokePermissions_returnsNull() async throws {
    let result = try await provider.request(
      chainId: "eip155:11155111",
      method: .wallet_revokePermissions,
      params: [],
      connect: nil,
      options: nil
    )
    guard let resultValue = result.result as? String else {
      XCTFail("Expected result to be String")
      return
    }
    XCTAssertEqual(resultValue, "null")
  }

  func testRequest_walletRequestPermissions_returnsNull() async throws {
    let result = try await provider.request(
      chainId: "eip155:11155111",
      method: .wallet_requestPermissions,
      params: [],
      connect: nil,
      options: nil
    )
    guard let resultValue = result.result as? String else {
      XCTFail("Expected result to be String")
      return
    }
    XCTAssertEqual(resultValue, "null")
  }

  // MARK: - RPC Request Tests

  func testRequest_ethGasPrice_returnsRpcResponse() async throws {
    let result = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_gasPrice,
      params: [],
      connect: nil,
      options: nil
    )
    guard let response = result.result as? PortalProviderRpcResponse else {
      XCTFail("Expected result to be PortalProviderRpcResponse")
      return
    }
    XCTAssertEqual(response.result, MockConstants.mockRpcResponse.result)
  }

  func testRequest_ethBlockNumber_returnsRpcResponse() async throws {
    let result = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_blockNumber,
      params: [],
      connect: nil,
      options: nil
    )
    guard let response = result.result as? PortalProviderRpcResponse else {
      XCTFail("Expected result to be PortalProviderRpcResponse")
      return
    }
    XCTAssertNotNil(response)
  }

  func testRequest_ethChainId_returnsRpcResponse() async throws {
    let result = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_chainId,
      params: [],
      connect: nil,
      options: nil
    )
    guard let response = result.result as? PortalProviderRpcResponse else {
      XCTFail("Expected result to be PortalProviderRpcResponse")
      return
    }
    XCTAssertNotNil(response)
  }

  // MARK: - Signing Request Tests

  func testRequest_ethSign_returnsSignature() async throws {
    let params = [MockConstants.mockEip155Address, "test"].map { AnyCodable($0) }
    let result = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_sign,
      params: params,
      connect: nil,
      options: nil
    )
    guard let signature = result.result as? String else {
      XCTFail("Expected result to be String signature")
      return
    }
    XCTAssertEqual(signature, MockConstants.mockSignature)
  }

  func testRequest_personalSign_returnsSignature() async throws {
    let params = ["test", MockConstants.mockEip155Address].map { AnyCodable($0) }
    let result = try await provider.request(
      chainId: "eip155:11155111",
      method: .personal_sign,
      params: params,
      connect: nil,
      options: nil
    )
    guard let signature = result.result as? String else {
      XCTFail("Expected result to be String signature")
      return
    }
    XCTAssertEqual(signature, MockConstants.mockSignature)
  }

  func testRequest_ethSignTransaction_returnsSignature() async throws {
    let transaction = AnyCodable([:] as [String: String])
    let result = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_signTransaction,
      params: [transaction],
      connect: nil,
      options: nil
    )
    guard let signature = result.result as? String else {
      XCTFail("Expected result to be String signature")
      return
    }
    XCTAssertEqual(signature, MockConstants.mockSignature)
  }

  func testRequest_ethSendTransaction_returnsTransactionHash() async throws {
    let transaction = AnyCodable([:] as [String: String])
    let result = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_sendTransaction,
      params: [transaction],
      connect: nil,
      options: nil
    )
    guard let transactionHash = result.result as? String else {
      XCTFail("Expected result to be String transaction hash")
      return
    }
    XCTAssertEqual(transactionHash, MockConstants.mockTransactionHash)
  }

  func testRequest_ethSignTypedData_v4_returnsSignature() async throws {
    let params = [MockConstants.mockEip155Address, MockConstants.mockSignTypedDataMessage].map { AnyCodable($0) }
    let result = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_signTypedData_v4,
      params: params,
      connect: nil,
      options: nil
    )
    guard let signature = result.result as? String else {
      XCTFail("Expected result to be String signature")
      return
    }
    XCTAssertEqual(signature, MockConstants.mockSignature)
  }

  // MARK: - Options Parameter Tests

  func testRequest_withSignatureApprovalMemo_succeeds() async throws {
    let params = [MockConstants.mockEip155Address, "test"].map { AnyCodable($0) }
    let options = RequestOptions(signatureApprovalMemo: "Please approve this signature")
    let result = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_sign,
      params: params,
      connect: nil,
      options: options
    )
    guard let signature = result.result as? String else {
      XCTFail("Expected result to be String signature")
      return
    }
    XCTAssertEqual(signature, MockConstants.mockSignature)
  }

  func testRequest_withSponsorGasTrue_succeeds() async throws {
    let transaction = AnyCodable([:] as [String: String])
    let options = RequestOptions(sponsorGas: true)
    let result = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_sendTransaction,
      params: [transaction],
      connect: nil,
      options: options
    )
    guard let transactionHash = result.result as? String else {
      XCTFail("Expected result to be String transaction hash")
      return
    }
    XCTAssertEqual(transactionHash, MockConstants.mockTransactionHash)
  }

  func testRequest_withSponsorGasFalse_succeeds() async throws {
    let transaction = AnyCodable([:] as [String: String])
    let options = RequestOptions(sponsorGas: false)
    let result = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_sendTransaction,
      params: [transaction],
      connect: nil,
      options: options
    )
    guard let transactionHash = result.result as? String else {
      XCTFail("Expected result to be String transaction hash")
      return
    }
    XCTAssertEqual(transactionHash, MockConstants.mockTransactionHash)
  }

  func testRequest_withBothMemoAndSponsorGas_succeeds() async throws {
    let transaction = AnyCodable([:] as [String: String])
    let options = RequestOptions(signatureApprovalMemo: "Confirm transaction", sponsorGas: true)
    let result = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_sendTransaction,
      params: [transaction],
      connect: nil,
      options: options
    )
    guard let transactionHash = result.result as? String else {
      XCTFail("Expected result to be String transaction hash")
      return
    }
    XCTAssertEqual(transactionHash, MockConstants.mockTransactionHash)
  }

  func testRequest_withEmptyOptions_succeeds() async throws {
    let options = RequestOptions()
    let result = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_accounts,
      params: [],
      connect: nil,
      options: options
    )
    guard let accounts = result.result as? [String?] else {
      XCTFail("Expected result to be [String?]")
      return
    }
    XCTAssertEqual(accounts.count, 1)
  }

  // MARK: - Params Parameter Tests

  func testRequest_withEmptyParams_succeeds() async throws {
    let result = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_accounts,
      params: [],
      connect: nil,
      options: nil
    )
    XCTAssertNotNil(result)
  }

  func testRequest_withNilParams_succeeds() async throws {
    let result = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_accounts,
      params: nil,
      connect: nil,
      options: nil
    )
    XCTAssertNotNil(result)
  }

  func testRequest_withStringParams_succeeds() async throws {
    let params = ["param1", "param2"].map { AnyCodable($0) }
    let result = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_gasPrice,
      params: params,
      connect: nil,
      options: nil
    )
    XCTAssertNotNil(result)
  }

  func testRequest_withDictionaryParams_succeeds() async throws {
    let transactionDict: [String: Any] = [
      "from": MockConstants.mockEip155Address,
      "to": "0xd46e8dd67c5d32be8058bb8eb970870f07244567",
      "value": "0x9184e72a"
    ]
    let params = [AnyCodable(transactionDict)]
    let result = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_sendTransaction,
      params: params,
      connect: nil,
      options: nil
    )
    guard let transactionHash = result.result as? String else {
      XCTFail("Expected result to be String transaction hash")
      return
    }
    XCTAssertEqual(transactionHash, MockConstants.mockTransactionHash)
  }

  // MARK: - Error Handling Tests

  func testRequest_withInvalidChainId_throwsError() async {
    do {
      _ = try await provider.request(
        chainId: "invalid_chain_id",
        method: .eth_accounts,
        params: [],
        connect: nil,
        options: nil
      )
      XCTFail("Expected error to be thrown for invalid chain ID")
    } catch {
      XCTAssertTrue(error is PortalBlockchainError)
    }
  }

  func testRequest_withEmptyChainId_throwsError() async {
    do {
      _ = try await provider.request(
        chainId: "",
        method: .eth_accounts,
        params: [],
        connect: nil,
        options: nil
      )
      XCTFail("Expected error to be thrown for empty chain ID")
    } catch {
      XCTAssertTrue(error is PortalBlockchainError)
    }
  }

  func testRequest_withMissingReference_throwsError() async {
    do {
      _ = try await provider.request(
        chainId: "eip155:",
        method: .eth_accounts,
        params: [],
        connect: nil,
        options: nil
      )
      XCTFail("Expected error to be thrown for missing reference")
    } catch {
      XCTAssertTrue(error is PortalBlockchainError)
    }
  }

  func testRequest_withUnsupportedNamespace_throwsError() async {
    do {
      _ = try await provider.request(
        chainId: "unsupported:12345",
        method: .eth_accounts,
        params: [],
        connect: nil,
        options: nil
      )
      XCTFail("Expected error to be thrown for unsupported namespace")
    } catch {
      XCTAssertTrue(error is PortalBlockchainError)
    }
  }

  // MARK: - Multiple Chain ID Tests

  func testRequest_withDifferentEip155ChainIds_succeeds() async throws {
    // Test with Ethereum mainnet chain ID format
    let result1 = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_accounts,
      params: [],
      connect: nil,
      options: nil
    )
    XCTAssertNotNil(result1)

    guard let accounts = result1.result as? [String?] else {
      XCTFail("Expected result to be [String?]")
      return
    }
    XCTAssertEqual(accounts[0], MockConstants.mockEip155Address)
  }

  // MARK: - Result ID Tests

  func testRequest_returnsUniqueIdForEachCall() async throws {
    let result1 = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_accounts,
      params: [],
      connect: nil,
      options: nil
    )
    let result2 = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_accounts,
      params: [],
      connect: nil,
      options: nil
    )
    XCTAssertNotEqual(result1.id, result2.id)
  }

  func testRequest_idIsValidUUID() async throws {
    let result = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_accounts,
      params: [],
      connect: nil,
      options: nil
    )
    // UUID strings are typically 36 characters (32 hex + 4 hyphens)
    XCTAssertFalse(result.id.isEmpty)
    XCTAssertNotNil(UUID(uuidString: result.id))
  }

  // MARK: - Connect Parameter Tests

  func testRequest_withNilConnect_succeeds() async throws {
    let result = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_accounts,
      params: [],
      connect: nil,
      options: nil
    )
    XCTAssertNotNil(result)
  }

  // MARK: - Multiple Requests Tests

  func testRequest_multipleSequentialRequests_succeed() async throws {
    let result1 = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_accounts,
      params: [],
      connect: nil,
      options: nil
    )
    XCTAssertNotNil(result1)

    let result2 = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_gasPrice,
      params: [],
      connect: nil,
      options: nil
    )
    XCTAssertNotNil(result2)

    let params = [MockConstants.mockEip155Address, "test"].map { AnyCodable($0) }
    let result3 = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_sign,
      params: params,
      connect: nil,
      options: nil
    )
    XCTAssertNotNil(result3)
  }

  func testRequest_differentMethodTypes_returnCorrectResults() async throws {
    // Account request
    let accountResult = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_accounts,
      params: [],
      connect: nil,
      options: nil
    )
    XCTAssertTrue(accountResult.result is [String?])

    // Wallet request
    let walletResult = try await provider.request(
      chainId: "eip155:11155111",
      method: .wallet_switchEthereumChain,
      params: [],
      connect: nil,
      options: nil
    )
    XCTAssertEqual(walletResult.result as? String, "null")

    // RPC request
    let rpcResult = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_gasPrice,
      params: [],
      connect: nil,
      options: nil
    )
    XCTAssertTrue(rpcResult.result is PortalProviderRpcResponse)

    // Sign request
    let params = [MockConstants.mockEip155Address, "test"].map { AnyCodable($0) }
    let signResult = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_sign,
      params: params,
      connect: nil,
      options: nil
    )
    XCTAssertEqual(signResult.result as? String, MockConstants.mockSignature)
  }
}
