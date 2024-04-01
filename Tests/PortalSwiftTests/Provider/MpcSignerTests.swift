//
//  MpcSignerTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

@testable import PortalSwift
import XCTest

final class MpcSignerTests: XCTestCase {
  var blockchain: PortalBlockchain?
  var signer: PortalMpcSigner = .init(
    apiKey: MockConstants.mockApiKey,
    keychain: MockPortalKeychain(),
    binary: MockMobileWrapper()
  )

  override func setUpWithError() throws {
    self.blockchain = try PortalBlockchain(fromChainId: "eip155:11155111")
  }

  override func tearDownWithError() throws {
    self.blockchain = nil
  }

  func testSendTransaction() async throws {
    let expectation = XCTestExpectation(description: "PortalMpcSigner.sign(.eth_sendTransaction)")
    guard let blockchain = blockchain else {
      throw PortalMpcSignerError.noCurveFoundForNamespace("eip155:11155111")
    }
    let signRequest = PortalSignRequest(method: .eth_sendTransaction, params: [AnyEncodable("test-transaction")])
    let response = try await signer.sign(
      "eip155:11155111",
      withPayload: signRequest,
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain
    )
    XCTAssert(response == MockConstants.mockTransactionHash)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testSignMessage() async throws {
    let expectation = XCTestExpectation(description: "PortalMpcSigner.sign(.eth_sign)")
    guard let blockchain = blockchain else {
      throw PortalMpcSignerError.noCurveFoundForNamespace("eip155:11155111")
    }
    let signRequest = PortalSignRequest(
      method: .eth_sign,
      params: [
        AnyEncodable(MockConstants.mockEip155Address),
        AnyEncodable("test-message"),
      ]
    )
    let response = try await signer.sign(
      "eip155:11155111",
      withPayload: signRequest,
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain
    )
    XCTAssert(response == MockConstants.mockSignature)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testSignTransaction() async throws {
    let expectation = XCTestExpectation(description: "PortalMpcSigner.sign(.eth_signTransaction)")
    guard let blockchain = blockchain else {
      throw PortalMpcSignerError.noCurveFoundForNamespace("eip155:11155111")
    }
    let signRequest = PortalSignRequest(method: .eth_signTransaction, params: [AnyEncodable("test-transaction")])
    let response = try await signer.sign(
      "eip155:11155111",
      withPayload: signRequest,
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain
    )
    XCTAssert(response == MockConstants.mockSignature)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }
}
