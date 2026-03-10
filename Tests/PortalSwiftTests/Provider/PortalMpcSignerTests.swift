//
//  PortalMpcSignerTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import AnyCodable
@testable import PortalSwift
import XCTest

final class PortalMpcSignerTests: XCTestCase {
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
    let signRequest = PortalSignRequest(method: .eth_sendTransaction, params: "test-transaction")
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
    let params = [
      AnyCodable(MockConstants.mockEip155Address),
      AnyCodable("test-message")
    ]
    let paramsJson = try JSONEncoder().encode(params)
    let paramsStr = String(data: paramsJson, encoding: .utf8)!
    let signRequest = PortalSignRequest(
      method: .eth_sign,
      params: paramsStr
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
    let signRequest = PortalSignRequest(method: .eth_signTransaction, params: "test-transaction")
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

// MARK: - Presignature Tests

extension PortalMpcSignerTests {
  func test_sign_withPresignatureAvailable_usesSignWithPresignature() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignWithPresignatureReturnValue = MockConstants.mockSignatureResponse
    let keychainSpy = PortalKeychainSpy()
    let source = MockPresignatureSource(entry: PresignatureEntry(
      id: "presig-1", expiresAt: "2099-01-01T00:00:00Z", data: "mock-presig-data"
    ))

    let signer = PortalMpcSigner(
      apiKey: MockConstants.mockApiKey,
      keychain: keychainSpy,
      featureFlags: FeatureFlags(usePresignatures: true),
      binary: mobileSpy,
      presignatureSource: source
    )

    let blockchain = try XCTUnwrap(blockchain)
    let signRequest = PortalSignRequest(method: .eth_signTransaction, params: "test-transaction")

    let response = try await signer.sign(
      "eip155:11155111",
      withPayload: signRequest,
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain
    )

    XCTAssertEqual(mobileSpy.mobileSignWithPresignatureCallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileSignCallsCount, 0)
    XCTAssertEqual(mobileSpy.mobileSignWithPresignaturePresignatureDataParam, "mock-presig-data")
    XCTAssertEqual(response, MockConstants.mockSignature)
  }

  func test_sign_withPresignatureDisabled_usesNormalSign() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignReturnValue = MockConstants.mockSignatureResponse
    let source = MockPresignatureSource(entry: PresignatureEntry(
      id: "presig-1", expiresAt: "2099-01-01T00:00:00Z", data: "mock-presig-data"
    ))

    let signer = PortalMpcSigner(
      apiKey: MockConstants.mockApiKey,
      keychain: MockPortalKeychain(),
      featureFlags: FeatureFlags(usePresignatures: false),
      binary: mobileSpy,
      presignatureSource: source
    )

    let blockchain = try XCTUnwrap(blockchain)
    let signRequest = PortalSignRequest(method: .eth_signTransaction, params: "test-transaction")

    _ = try await signer.sign(
      "eip155:11155111",
      withPayload: signRequest,
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain
    )

    XCTAssertEqual(mobileSpy.mobileSignWithPresignatureCallsCount, 0)
    XCTAssertEqual(mobileSpy.mobileSignCallsCount, 1)
  }

  func test_sign_withNoPresignatureAvailable_fallsBackToNormalSign() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignReturnValue = MockConstants.mockSignatureResponse
    let source = MockPresignatureSource(entry: nil)

    let signer = PortalMpcSigner(
      apiKey: MockConstants.mockApiKey,
      keychain: MockPortalKeychain(),
      featureFlags: FeatureFlags(usePresignatures: true),
      binary: mobileSpy,
      presignatureSource: source
    )

    let blockchain = try XCTUnwrap(blockchain)
    let signRequest = PortalSignRequest(method: .eth_signTransaction, params: "test-transaction")

    _ = try await signer.sign(
      "eip155:11155111",
      withPayload: signRequest,
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain
    )

    XCTAssertEqual(mobileSpy.mobileSignWithPresignatureCallsCount, 0)
    XCTAssertEqual(mobileSpy.mobileSignCallsCount, 1)
  }

  func test_sign_whenSignWithPresignatureFails_fallsBackToNormalSign() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignWithPresignatureReturnValue = "{\"data\":null,\"error\":{\"id\":\"PRESIG_FAIL\",\"message\":\"presig error\"}}"
    mobileSpy.mobileSignReturnValue = MockConstants.mockSignatureResponse

    let source = MockPresignatureSource(entry: PresignatureEntry(
      id: "presig-1", expiresAt: "2099-01-01T00:00:00Z", data: "mock-presig-data"
    ))

    let signer = PortalMpcSigner(
      apiKey: MockConstants.mockApiKey,
      keychain: MockPortalKeychain(),
      featureFlags: FeatureFlags(usePresignatures: true),
      binary: mobileSpy,
      presignatureSource: source
    )

    let blockchain = try XCTUnwrap(blockchain)
    let signRequest = PortalSignRequest(method: .eth_signTransaction, params: "test-transaction")

    let response = try await signer.sign(
      "eip155:11155111",
      withPayload: signRequest,
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain
    )

    XCTAssertEqual(mobileSpy.mobileSignWithPresignatureCallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileSignCallsCount, 1, "Should fall back to normal sign")
    XCTAssertEqual(response, MockConstants.mockSignature)
  }

  func test_sign_withNoPresignatureSource_usesNormalSign() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignReturnValue = MockConstants.mockSignatureResponse

    let signer = PortalMpcSigner(
      apiKey: MockConstants.mockApiKey,
      keychain: MockPortalKeychain(),
      featureFlags: FeatureFlags(usePresignatures: true),
      binary: mobileSpy
    )

    let blockchain = try XCTUnwrap(blockchain)
    let signRequest = PortalSignRequest(method: .eth_signTransaction, params: "test-transaction")

    _ = try await signer.sign(
      "eip155:11155111",
      withPayload: signRequest,
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain
    )

    XCTAssertEqual(mobileSpy.mobileSignCallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileSignWithPresignatureCallsCount, 0)
  }
}

// MARK: - MockPresignatureSource

private class MockPresignatureSource: PresignatureSource {
  private let entry: PresignatureEntry?
  private(set) var consumeCallCount = 0

  init(entry: PresignatureEntry?) {
    self.entry = entry
  }

  func consumePresignature(forCurve _: PortalCurve) async -> PresignatureEntry? {
    consumeCallCount += 1
    return entry
  }
}

// MARK: - SponsorGas Tests

extension PortalMpcSignerTests {
  func test_sign_withSponsorGasTrue_succeeds() async throws {
    // given
    guard let blockchain = blockchain else {
      throw PortalMpcSignerError.noCurveFoundForNamespace("eip155:11155111")
    }
    let signRequest = PortalSignRequest(method: .eth_sendTransaction, params: "test-transaction")

    // when
    let response = try await signer.sign(
      "eip155:11155111",
      withPayload: signRequest,
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain,
      signatureApprovalMemo: nil,
      sponsorGas: true
    )

    // then
    XCTAssertEqual(response, MockConstants.mockTransactionHash)
  }

  func test_sign_withSponsorGasFalse_succeeds() async throws {
    // given
    guard let blockchain = blockchain else {
      throw PortalMpcSignerError.noCurveFoundForNamespace("eip155:11155111")
    }
    let signRequest = PortalSignRequest(method: .eth_sendTransaction, params: "test-transaction")

    // when
    let response = try await signer.sign(
      "eip155:11155111",
      withPayload: signRequest,
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain,
      signatureApprovalMemo: nil,
      sponsorGas: false
    )

    // then
    XCTAssertEqual(response, MockConstants.mockTransactionHash)
  }

  func test_sign_withSponsorGasNil_succeeds() async throws {
    // given
    guard let blockchain = blockchain else {
      throw PortalMpcSignerError.noCurveFoundForNamespace("eip155:11155111")
    }
    let signRequest = PortalSignRequest(method: .eth_sendTransaction, params: "test-transaction")

    // when
    let response = try await signer.sign(
      "eip155:11155111",
      withPayload: signRequest,
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain,
      signatureApprovalMemo: nil,
      sponsorGas: nil
    )

    // then
    XCTAssertEqual(response, MockConstants.mockTransactionHash)
  }

  func test_sign_withSponsorGasAndSignatureApprovalMemo_succeeds() async throws {
    // given
    guard let blockchain = blockchain else {
      throw PortalMpcSignerError.noCurveFoundForNamespace("eip155:11155111")
    }
    let signRequest = PortalSignRequest(method: .eth_sendTransaction, params: "test-transaction")

    // when
    let response = try await signer.sign(
      "eip155:11155111",
      withPayload: signRequest,
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain,
      signatureApprovalMemo: "Confirm sponsored transaction",
      sponsorGas: true
    )

    // then
    XCTAssertEqual(response, MockConstants.mockTransactionHash)
  }

  func test_signTransaction_withSponsorGasTrue_succeeds() async throws {
    // given
    guard let blockchain = blockchain else {
      throw PortalMpcSignerError.noCurveFoundForNamespace("eip155:11155111")
    }
    let signRequest = PortalSignRequest(method: .eth_signTransaction, params: "test-transaction")

    // when
    let response = try await signer.sign(
      "eip155:11155111",
      withPayload: signRequest,
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain,
      signatureApprovalMemo: nil,
      sponsorGas: true
    )

    // then
    XCTAssertEqual(response, MockConstants.mockSignature)
  }

  func test_signMessage_withSponsorGasTrue_succeeds() async throws {
    // given
    guard let blockchain = blockchain else {
      throw PortalMpcSignerError.noCurveFoundForNamespace("eip155:11155111")
    }
    let params = [
      AnyCodable(MockConstants.mockEip155Address),
      AnyCodable("test-message")
    ]
    let paramsJson = try JSONEncoder().encode(params)
    let paramsStr = String(data: paramsJson, encoding: .utf8)!
    let signRequest = PortalSignRequest(method: .eth_sign, params: paramsStr)

    // when
    let response = try await signer.sign(
      "eip155:11155111",
      withPayload: signRequest,
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain,
      signatureApprovalMemo: nil,
      sponsorGas: true
    )

    // then
    XCTAssertEqual(response, MockConstants.mockSignature)
  }
}
