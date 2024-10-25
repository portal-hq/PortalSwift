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
