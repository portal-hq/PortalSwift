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

  /// Captures every message the signer logs, so the credential cases can prove a bearer token
  /// never reaches a log line. The sink sees all levels regardless of the configured `logLevel`,
  /// so those assertions cannot pass merely because the SDK was quiet.
  var logger = RecordingLogger()

  var signer: PortalMpcSigner = .init(
    apiKey: MockConstants.mockApiKey,
    keychain: MockPortalKeychain(),
    binary: MockMobileWrapper()
  )

  override func setUpWithError() throws {
    self.blockchain = try PortalBlockchain(fromChainId: "eip155:11155111")
    self.logger = RecordingLogger()
    self.logger.install()
  }

  override func tearDownWithError() throws {
    self.logger.uninstall()
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

  // Raw sign + presignature is the path MPC commit 2cb4559 fixed: the binary only forwards the
  // memo it finds in `metadataStr`, so the SDK must put it there. Pins the Swift half of that contract.
  func test_sign_withPresignature_rawSign_forwardsSignatureApprovalMemoInMetadata() async throws {
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
    // Same shape PortalProvider.getPortalRawSignRequest builds for `raw_sign`.
    let rawSignRequest = PortalSignRequest(method: nil, params: "74657374", isRaw: true)

    let response = try await signer.sign(
      "eip155:11155111",
      withPayload: rawSignRequest,
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain,
      signatureApprovalMemo: "approve-this"
    )

    XCTAssertEqual(response, MockConstants.mockSignature)
    XCTAssertEqual(mobileSpy.mobileSignWithPresignatureCallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileSignCallsCount, 0)
    XCTAssertEqual(mobileSpy.mobileSignWithPresignatureIsRawParam, true)

    let metadataStr = try XCTUnwrap(mobileSpy.mobileSignWithPresignatureMetadataStrParam)
    let metadata = try JSONDecoder().decode(MpcMetadata.self, from: Data(metadataStr.utf8))
    XCTAssertEqual(metadata.signatureApprovalMemo, "approve-this")
    XCTAssertEqual(metadata.isRaw, true)
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

  func test_sign_withPresignature_forSendTransaction() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignWithPresignatureReturnValue = MockConstants.mockSignatureResponse
    let keychainSpy = PortalKeychainSpy()
    let source = MockPresignatureSource(entry: PresignatureEntry(
      id: "presig-tx", expiresAt: "2099-01-01T00:00:00Z", data: "presig-data-tx"
    ))

    let signer = PortalMpcSigner(
      apiKey: MockConstants.mockApiKey,
      keychain: keychainSpy,
      featureFlags: FeatureFlags(usePresignatures: true),
      binary: mobileSpy,
      presignatureSource: source
    )

    let blockchain = try XCTUnwrap(blockchain)
    let signRequest = PortalSignRequest(method: .eth_sendTransaction, params: "test-transaction")

    let response = try await signer.sign(
      "eip155:11155111",
      withPayload: signRequest,
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain
    )

    XCTAssertEqual(mobileSpy.mobileSignWithPresignatureCallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileSignCallsCount, 0)
    XCTAssertEqual(response, MockConstants.mockSignature)
  }

  func test_sign_withNilFeatureFlags_usesNormalSign() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignReturnValue = MockConstants.mockSignatureResponse
    let source = MockPresignatureSource(entry: PresignatureEntry(
      id: "presig-1", expiresAt: "2099-01-01T00:00:00Z", data: "mock-presig-data"
    ))

    let signer = PortalMpcSigner(
      apiKey: MockConstants.mockApiKey,
      keychain: MockPortalKeychain(),
      featureFlags: nil,
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

    XCTAssertEqual(mobileSpy.mobileSignWithPresignatureCallsCount, 0, "Should not use presignature with nil flags")
    XCTAssertEqual(mobileSpy.mobileSignCallsCount, 1)
  }

  func test_sign_withPresignature_passesCorrectPresignatureDataToSpy() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignWithPresignatureReturnValue = MockConstants.mockSignatureResponse
    let keychainSpy = PortalKeychainSpy()
    let source = MockPresignatureSource(entry: PresignatureEntry(
      id: "presig-verify", expiresAt: "2099-01-01T00:00:00Z", data: "specific-presig-blob"
    ))

    let signer = PortalMpcSigner(
      apiKey: MockConstants.mockApiKey,
      keychain: keychainSpy,
      featureFlags: FeatureFlags(usePresignatures: true),
      binary: mobileSpy,
      presignatureSource: source
    )

    let blockchain = try XCTUnwrap(blockchain)
    let signRequest = PortalSignRequest(method: .eth_signTransaction, params: "test-params")

    _ = try await signer.sign(
      "eip155:11155111",
      withPayload: signRequest,
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain
    )

    XCTAssertEqual(mobileSpy.mobileSignWithPresignaturePresignatureDataParam, "specific-presig-blob")
    XCTAssertEqual(mobileSpy.mobileSignWithPresignatureApiKeyParam, MockConstants.mockApiKey)
  }

  func test_sign_withPresignature_consumeCallCountIsOne() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignWithPresignatureReturnValue = MockConstants.mockSignatureResponse
    let keychainSpy = PortalKeychainSpy()
    let source = MockPresignatureSource(entry: PresignatureEntry(
      id: "presig-count", expiresAt: "2099-01-01T00:00:00Z", data: "data"
    ))

    let signer = PortalMpcSigner(
      apiKey: MockConstants.mockApiKey,
      keychain: keychainSpy,
      featureFlags: FeatureFlags(usePresignatures: true),
      binary: mobileSpy,
      presignatureSource: source
    )

    let blockchain = try XCTUnwrap(blockchain)
    let signRequest = PortalSignRequest(method: .eth_signTransaction, params: "test")

    _ = try await signer.sign(
      "eip155:11155111",
      withPayload: signRequest,
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain
    )

    XCTAssertEqual(source.consumeCallCount, 1, "Should consume exactly one presignature per sign")
  }

  func test_sign_whenBothPresignAndNormalFail_throws() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignWithPresignatureReturnValue = "{\"data\":null,\"error\":{\"id\":\"FAIL\",\"message\":\"presig fail\"}}"
    mobileSpy.mobileSignReturnValue = "{\"data\":null,\"error\":{\"id\":\"SIGN_FAIL\",\"message\":\"sign fail\"}}"

    let source = MockPresignatureSource(entry: PresignatureEntry(
      id: "presig-1", expiresAt: "2099-01-01T00:00:00Z", data: "data"
    ))

    let signer = PortalMpcSigner(
      apiKey: MockConstants.mockApiKey,
      keychain: MockPortalKeychain(),
      featureFlags: FeatureFlags(usePresignatures: true),
      binary: mobileSpy,
      presignatureSource: source
    )

    let blockchain = try XCTUnwrap(blockchain)
    let signRequest = PortalSignRequest(method: .eth_signTransaction, params: "test")

    do {
      _ = try await signer.sign(
        "eip155:11155111",
        withPayload: signRequest,
        andRpcUrl: MockConstants.mockHost,
        usingBlockchain: blockchain
      )
      XCTFail("Should have thrown when both presign and normal sign fail")
    } catch {
      XCTAssertEqual(mobileSpy.mobileSignWithPresignatureCallsCount, 1)
      XCTAssertEqual(mobileSpy.mobileSignCallsCount, 1)
    }
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

// MARK: - eth_signUserOperation Tests

extension PortalMpcSignerTests {
  func testSignUserOperation() async throws {
    guard let blockchain = blockchain else {
      throw PortalMpcSignerError.noCurveFoundForNamespace("eip155:11155111")
    }
    let signRequest = PortalSignRequest(method: .eth_signUserOperation, params: "{\"sender\":\"\(MockConstants.mockEip155Address)\",\"nonce\":\"0x0\",\"callData\":\"0x\"}")
    let response = try await signer.sign(
      "eip155:11155111",
      withPayload: signRequest,
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain
    )
    XCTAssertEqual(response, MockConstants.mockSignature)
  }

  func testSignUserOperation_withSponsorGas_succeeds() async throws {
    guard let blockchain = blockchain else {
      throw PortalMpcSignerError.noCurveFoundForNamespace("eip155:11155111")
    }
    let signRequest = PortalSignRequest(method: .eth_signUserOperation, params: "{\"sender\":\"\(MockConstants.mockEip155Address)\",\"nonce\":\"0x0\",\"callData\":\"0x\"}")
    let response = try await signer.sign(
      "eip155:11155111",
      withPayload: signRequest,
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain,
      signatureApprovalMemo: "Approve UserOp",
      sponsorGas: true
    )
    XCTAssertEqual(response, MockConstants.mockSignature)
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

// MARK: - Credential token overload

/// The signer no longer owns a credential. `PortalProvider` resolves the bearer per request —
/// after the user has approved the signature — and hands it to
/// `sign(_:withPayload:andRpcUrl:usingBlockchain:signatureApprovalMemo:sponsorGas:reqId:token:)`,
/// which is the real body; the token-less overload is a deprecated forwarder that resolves the
/// key captured by `init(apiKey:)`.
///
/// These cases pin what that move must guarantee: the caller's token is what reaches the native
/// boundary on both the normal and the presignature path, nothing is cached on the instance so a
/// rotated session takes effect on the very next signature, an `AUTH_FAILED` from the presignature
/// path is surfaced instead of being retried with the same dead credential (the fallback is for
/// presignature problems, not for authentication), and a signer built without legacy credentials
/// fails the deprecated overload loudly rather than calling the binary with an empty bearer.
extension PortalMpcSignerTests {
  // MARK: Helpers

  /// Builds the signer under test through the designated initializer — the one that holds no
  /// credential at all, which is how the SDK builds it.
  private func makeSigner(
    binary: MobileSpy,
    featureFlags: FeatureFlags? = FeatureFlags(usePresignatures: true),
    source: MockPresignatureSource? = nil,
    legacyCredentials: PortalCredentials? = nil
  ) -> PortalMpcSigner {
    PortalMpcSigner(
      keychain: PortalKeychainSpy(),
      featureFlags: featureFlags,
      binary: binary,
      presignatureSource: source,
      legacyCredentials: legacyCredentials
    )
  }

  /// Builds the signer through the deprecated Client-API-Key initializer, which is the only way
  /// the token-less `sign(...)` can still authenticate.
  private func makeLegacySigner(
    apiKey: String,
    binary: MobileSpy,
    featureFlags: FeatureFlags? = FeatureFlags(usePresignatures: true),
    source: MockPresignatureSource? = nil
  ) -> PortalMpcSigner {
    PortalMpcSigner(
      apiKey: apiKey,
      keychain: PortalKeychainSpy(),
      featureFlags: featureFlags,
      binary: binary,
      presignatureSource: source
    )
  }

  /// A presignature source holding exactly one entry, so "consumed exactly once" is observable.
  private func makePresignatureSource() -> MockPresignatureSource {
    MockPresignatureSource(entry: PresignatureEntry(
      id: "presig-token",
      expiresAt: "2099-01-01T00:00:00Z",
      data: "presig-data"
    ))
  }

  /// The request every credential case signs; the payload is irrelevant to the credential rules.
  private var tokenSignRequest: PortalSignRequest {
    PortalSignRequest(method: .eth_signTransaction, params: "tx")
  }

  /// Signs through the `token:` overload the SDK uses.
  @discardableResult
  private func signWithToken(
    _ signer: PortalMpcSigner,
    token: String,
    request: PortalSignRequest? = nil
  ) async throws -> String {
    let blockchain = try XCTUnwrap(self.blockchain)
    return try await signer.sign(
      "eip155:11155111",
      withPayload: request ?? self.tokenSignRequest,
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain,
      token: token
    )
  }

  /// Signs through the deprecated token-less overload, which resolves `legacyCredentials`.
  @discardableResult
  private func signWithoutToken(_ signer: PortalMpcSigner) async throws -> String {
    let blockchain = try XCTUnwrap(self.blockchain)
    return try await signer.sign(
      "eip155:11155111",
      withPayload: self.tokenSignRequest,
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain
    )
  }

  /// Runs `operation`, failing the test if it does not throw, and returns the error it threw.
  private func captureError<T>(
    file: StaticString = #filePath,
    line: UInt = #line,
    _ operation: () async throws -> T
  ) async -> Error? {
    do {
      _ = try await operation()
      XCTFail("Expected the call to throw, but it returned a value.", file: file, line: line)
      return nil
    } catch {
      return error
    }
  }

  // MARK: sign(..., token:)

  func test_sign_token_willPassTokenToMobileSign() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignReturnValue = MockConstants.mockSignatureResponse
    let signer = self.makeSigner(binary: mobileSpy)

    let signature = try await self.signWithToken(signer, token: "tok-A")

    XCTAssertEqual(mobileSpy.mobileSignApiKeyParam, "tok-A")
    XCTAssertEqual(mobileSpy.mobileSignCallsCount, 1)
    XCTAssertEqual(signature, MockConstants.mockSignature)
  }

  func test_sign_token_willPassTokenToMobileSignWithPresignature() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignWithPresignatureReturnValue = MockConstants.mockSignatureResponse
    let source = self.makePresignatureSource()
    let signer = self.makeSigner(binary: mobileSpy, source: source)

    try await self.signWithToken(signer, token: "tok-A")

    XCTAssertEqual(mobileSpy.mobileSignWithPresignatureApiKeyParam, "tok-A")
    XCTAssertEqual(mobileSpy.mobileSignCallsCount, 0)
  }

  func test_sign_token_willUseCallerToken_notLegacyCredential() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignReturnValue = MockConstants.mockSignatureResponse
    // A counting credential rather than a plain `StaticCredentials`, so "the legacy credential is
    // never consulted" is asserted directly instead of inferred from the token that was sent.
    let legacyCredentials = MockCredentials(tokenValue: "legacy")
    let signer = self.makeSigner(binary: mobileSpy, legacyCredentials: legacyCredentials)

    try await self.signWithToken(signer, token: "tok-A")

    XCTAssertEqual(mobileSpy.mobileSignApiKeyParam, "tok-A")
    XCTAssertEqual(legacyCredentials.getTokenCalls, 0)
  }

  func test_sign_token_willUseFreshTokenPerCall() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignReturnValue = MockConstants.mockSignatureResponse
    let signer = self.makeSigner(binary: mobileSpy)

    try await self.signWithToken(signer, token: "tok-A")
    try await self.signWithToken(signer, token: "tok-B")

    XCTAssertEqual(mobileSpy.mobileSignApiKeyParam, "tok-B", "The signer must not retain the first token.")
    XCTAssertEqual(mobileSpy.mobileSignCallsCount, 2)
  }

  func test_sign_token_willNotFallBackToNormalSign_whenPresignatureReturnsAuthFailed() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignWithPresignatureReturnValue = MpcJSON.authFailed
    mobileSpy.mobileSignReturnValue = MockConstants.mockSignatureResponse
    let source = self.makePresignatureSource()
    let signer = self.makeSigner(binary: mobileSpy, source: source)

    let error = await self.captureError { try await self.signWithToken(signer, token: "tok-A") }

    let mpcError = try XCTUnwrap(error as? PortalMpcError)
    XCTAssertTrue(mpcError.isAuthFailure)
    XCTAssertEqual(mobileSpy.mobileSignWithPresignatureCallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileSignCallsCount, 0, "A dead credential must not be retried.")
  }

  func test_sign_token_willFallBackToNormalSign_whenPresignatureFailsWithOtherError() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignWithPresignatureReturnValue = MpcJSON.error(id: "PRESIG_FAIL")
    mobileSpy.mobileSignReturnValue = MockConstants.mockSignatureResponse
    let source = self.makePresignatureSource()
    let signer = self.makeSigner(binary: mobileSpy, source: source)

    let signature = try await self.signWithToken(signer, token: "tok-A")

    XCTAssertEqual(signature, MockConstants.mockSignature)
    XCTAssertEqual(mobileSpy.mobileSignWithPresignatureCallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileSignCallsCount, 1, "Presignature problems still fall back.")
  }

  func test_sign_token_willThrowAuthFailed_fromNormalSign() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignReturnValue = MpcJSON.authFailed
    let signer = self.makeSigner(binary: mobileSpy)

    let error = await self.captureError { try await self.signWithToken(signer, token: "tok-A") }

    let mpcError = try XCTUnwrap(error as? PortalMpcError)
    XCTAssertEqual(mpcError.id, MpcJSON.authFailedId)
    XCTAssertTrue(mpcError.isAuthFailure)
  }

  func test_sign_token_willConsumeExactlyOnePresignature_evenWhenAuthFailed() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignWithPresignatureReturnValue = MpcJSON.authFailed
    let source = self.makePresignatureSource()
    let signer = self.makeSigner(binary: mobileSpy, source: source)

    _ = await self.captureError { try await self.signWithToken(signer, token: "tok-A") }

    XCTAssertEqual(source.consumeCallCount, 1, "The stopped sign must not consume a second entry.")
  }

  func test_sign_token_willThrowUnableToParse_whenBinaryReturnsNonUtf8() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignReturnValue = ""
    let signer = self.makeSigner(binary: mobileSpy)

    let error = await self.captureError { try await self.signWithToken(signer, token: "tok-A") }

    let thrown = try XCTUnwrap(error)
    XCTAssertNil(thrown as? PortalMpcError, "An undecodable body is not an MPC error, so nothing is reported.")
    XCTAssertTrue(
      thrown is DecodingError || thrown as? PortalMpcSignerError == .unableToParseSignResponse,
      "Unexpected error for an undecodable sign response: \(type(of: thrown))"
    )
    XCTAssertEqual(mobileSpy.mobileSignCallsCount, 1)
  }

  // MARK: Deprecated token-less sign(...)

  func test_sign_deprecated_willResolveFromLegacyApiKey() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignReturnValue = MockConstants.mockSignatureResponse
    let signer = self.makeLegacySigner(apiKey: "legacy-key", binary: mobileSpy, featureFlags: nil)

    try await self.signWithoutToken(signer)

    XCTAssertEqual(mobileSpy.mobileSignApiKeyParam, "legacy-key")
    XCTAssertEqual(mobileSpy.mobileSignCallsCount, 1)
  }

  func test_sign_deprecated_willThrowUnavailable_whenNoLegacyCredentials() async throws {
    let mobileSpy = MobileSpy()
    let source = self.makePresignatureSource()
    let signer = self.makeSigner(binary: mobileSpy, source: source, legacyCredentials: nil)

    let error = await self.captureError { try await self.signWithoutToken(signer) }

    XCTAssertEqual(error as? PortalCredentialError, .unavailable)
    XCTAssertEqual(mobileSpy.mobileSignCallsCount, 0)
    XCTAssertEqual(source.consumeCallCount, 0, "The buffer must not be spent by a call that cannot authenticate.")
  }

  func test_sign_deprecated_willThrowUnavailable_whenLegacyApiKeyBlank() async throws {
    let mobileSpy = MobileSpy()
    let signer = self.makeLegacySigner(apiKey: "", binary: mobileSpy, featureFlags: nil)

    let error = await self.captureError { try await self.signWithoutToken(signer) }

    XCTAssertEqual(error as? PortalCredentialError, .unavailable)
    XCTAssertEqual(mobileSpy.mobileSignCallsCount, 0)
  }

  func test_sign_deprecated_willForwardLegacyToken_toPresignaturePath() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignWithPresignatureReturnValue = MockConstants.mockSignatureResponse
    let source = self.makePresignatureSource()
    let signer = self.makeLegacySigner(apiKey: "legacy-key", binary: mobileSpy, source: source)

    try await self.signWithoutToken(signer)

    XCTAssertEqual(mobileSpy.mobileSignWithPresignatureApiKeyParam, "legacy-key")
    XCTAssertEqual(mobileSpy.mobileSignCallsCount, 0)
  }

  // MARK: Secrets never leak

  func test_sign_token_errorDescription_willNotContainToken() async throws {
    let token = "tok-secret"

    let authSpy = MobileSpy()
    authSpy.mobileSignReturnValue = MpcJSON.authFailed
    let authSigner = self.makeSigner(binary: authSpy)
    let thrownAuthError = await self.captureError { try await self.signWithToken(authSigner, token: token) }
    let authError = try XCTUnwrap(thrownAuthError)
    XCTAssertFalse("\(authError)".contains(token))
    XCTAssertFalse(authError.localizedDescription.contains(token))

    let failingSpy = MobileSpy()
    failingSpy.mobileSignWithPresignatureReturnValue = MpcJSON.error(id: "PRESIG_FAIL")
    failingSpy.mobileSignReturnValue = MpcJSON.error(id: "SIGN_FAIL")
    let failingSigner = self.makeSigner(binary: failingSpy, source: self.makePresignatureSource())
    let thrownSignError = await self.captureError { try await self.signWithToken(failingSigner, token: token) }
    let signError = try XCTUnwrap(thrownSignError)
    XCTAssertEqual((signError as? PortalMpcError)?.id, "SIGN_FAIL")
    XCTAssertFalse("\(signError)".contains(token))
    XCTAssertFalse(signError.localizedDescription.contains(token))
  }

  func test_sign_token_willNotLogToken() async throws {
    let token = "tok-secret"
    let mobileSpy = MobileSpy()
    // The presignature failure exercises the `warn` fallback line, which is the one that
    // interpolates an error, and the retry then succeeds so the `debug` lines are emitted too.
    mobileSpy.mobileSignWithPresignatureReturnValue = MpcJSON.error(id: "PRESIG_FAIL")
    mobileSpy.mobileSignReturnValue = MockConstants.mockSignatureResponse
    let signer = self.makeSigner(binary: mobileSpy, source: self.makePresignatureSource())

    try await self.signWithToken(signer, token: token)

    XCTAssertFalse(self.logger.messages.isEmpty, "Nothing was logged; the assertion would be vacuous.")
    self.logger.assertNoSecret(token)
  }

  // MARK: PortalMpcError.isAuthFailure

  func test_isAuthFailure_willBeTrue_forAuthFailedId() {
    let error = PortalMpcError(PortalError(id: "AUTH_FAILED", message: nil))

    XCTAssertTrue(error.isAuthFailure)
  }

  func test_isAuthFailure_willBeFalse_forOtherId_andNilId_andLowercase() {
    // The id is a protocol constant shared with the Go binary, so the match is exact: a different
    // id, a missing id, a different case or stray whitespace must never end a session.
    let ids: [String?] = ["SIGN_FAIL", nil, "auth_failed", "AUTH_FAILED "]

    for id in ids {
      let error = PortalMpcError(PortalError(id: id, message: nil))
      XCTAssertFalse(error.isAuthFailure, "id \(id ?? "nil") must not read as an auth failure")
    }
  }

  // MARK: MockPortalMpcSigner

  func test_mockPortalMpcSigner_tokenOverload_willReturnMockValues() async throws {
    let signer = MockPortalMpcSigner(
      credentials: MockConstants.mockCredentials,
      keychain: MockPortalKeychain()
    )

    let transactionHash = try await self.signWithToken(
      signer,
      token: "x",
      request: PortalSignRequest(method: .eth_sendTransaction, params: "tx")
    )
    let signature = try await self.signWithToken(
      signer,
      token: "x",
      request: PortalSignRequest(method: .eth_sign, params: "[]")
    )

    XCTAssertEqual(transactionHash, MockConstants.mockTransactionHash)
    XCTAssertEqual(signature, MockConstants.mockSignature)
  }
}

// MARK: - Idempotency key

/// `PortalProvider` hands the signer an already-validated key for the three broadcast methods.
/// These cases pin the signer's half: the key reaches the binary inside the signing metadata on
/// both the normal and the presignature path, an unkeyed call serializes exactly as before (the
/// field is omitted), an idempotency rejection from the presignature path is surfaced instead of
/// being retried with the same key, and neither the key nor the token ever reaches a log line.
extension PortalMpcSignerTests {
  private static let idempotencyKey = "key-123"
  private static let idempotencyToken = "tok-idem-secret"

  /// Signs through the `idempotencyKey:` overload, the one `PortalProvider` calls.
  @discardableResult
  private func signWithKey(
    _ signer: PortalMpcSigner,
    idempotencyKey: String?,
    token: String = PortalMpcSignerTests.idempotencyToken,
    request: PortalSignRequest = PortalSignRequest(method: .eth_sendTransaction, params: "{\"to\":\"0xabc\"}")
  ) async throws -> String {
    let blockchain = try XCTUnwrap(self.blockchain)
    return try await signer.sign(
      "eip155:11155111",
      withPayload: request,
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain,
      signatureApprovalMemo: nil,
      sponsorGas: nil,
      reqId: "trace-1",
      idempotencyKey: idempotencyKey,
      token: token
    )
  }

  private func decodeMetadata(_ metadata: String?, file: StaticString = #filePath, line: UInt = #line) throws -> MpcMetadata {
    let metadata = try XCTUnwrap(metadata, "The binary was not handed any metadata.", file: file, line: line)
    return try JSONDecoder().decode(MpcMetadata.self, from: Data(metadata.utf8))
  }

  // MARK: Metadata

  func test_sign_idempotencyKey_willBeInMobileSignMetadata() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignReturnValue = MockConstants.mockSignatureResponse
    let signer = self.makeSigner(binary: mobileSpy)

    let signature = try await self.signWithKey(signer, idempotencyKey: Self.idempotencyKey)

    XCTAssertEqual(signature, MockConstants.mockSignature)
    XCTAssertEqual(mobileSpy.mobileSignCallsCount, 1)
    let metadataString = try XCTUnwrap(mobileSpy.mobileSignMetadataParam)
    XCTAssertTrue(metadataString.contains("\"idempotencyKey\":\"key-123\""), metadataString)
    let metadata = try self.decodeMetadata(metadataString)
    XCTAssertEqual(metadata.idempotencyKey, Self.idempotencyKey)
    XCTAssertEqual(metadata.reqId, "trace-1", "The key must not displace the other metadata fields.")
    XCTAssertEqual(metadata.chainId, "eip155:11155111")
  }

  func test_sign_idempotencyKey_willBeInMobileSignWithPresignatureMetadata() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignWithPresignatureReturnValue = MockConstants.mockSignatureResponse
    let signer = self.makeSigner(binary: mobileSpy, source: self.makePresignatureSource())

    try await self.signWithKey(signer, idempotencyKey: Self.idempotencyKey)

    XCTAssertEqual(mobileSpy.mobileSignWithPresignatureCallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileSignCallsCount, 0)
    let metadataString = try XCTUnwrap(mobileSpy.mobileSignWithPresignatureMetadataStrParam)
    XCTAssertTrue(metadataString.contains("\"idempotencyKey\":\"key-123\""), metadataString)
    XCTAssertEqual(try self.decodeMetadata(metadataString).idempotencyKey, Self.idempotencyKey)
  }

  func test_sign_withoutIdempotencyKey_willOmitTheField_andMatchTheTokenOverload() async throws {
    let keylessSpy = MobileSpy()
    keylessSpy.mobileSignReturnValue = MockConstants.mockSignatureResponse
    try await self.signWithKey(self.makeSigner(binary: keylessSpy), idempotencyKey: nil)

    let tokenSpy = MobileSpy()
    tokenSpy.mobileSignReturnValue = MockConstants.mockSignatureResponse
    let blockchain = try XCTUnwrap(self.blockchain)
    _ = try await self.makeSigner(binary: tokenSpy).sign(
      "eip155:11155111",
      withPayload: PortalSignRequest(method: .eth_sendTransaction, params: "{\"to\":\"0xabc\"}"),
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain,
      signatureApprovalMemo: nil,
      sponsorGas: nil,
      reqId: "trace-1",
      token: Self.idempotencyToken
    )

    let keyless = try XCTUnwrap(keylessSpy.mobileSignMetadataParam)
    let viaToken = try XCTUnwrap(tokenSpy.mobileSignMetadataParam)
    XCTAssertFalse(keyless.contains("idempotencyKey"), keyless)
    // `JSONEncoder` does not fix the key order of the metadata object, so the two strings are
    // compared as parsed objects: the same keys with the same values, and nothing extra.
    let keylessObject = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(keyless.utf8)) as? NSDictionary)
    let viaTokenObject = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(viaToken.utf8)) as? NSDictionary)
    XCTAssertEqual(keylessObject, viaTokenObject, "An unkeyed call must serialize exactly like the token: overload.")
    XCTAssertNil(try self.decodeMetadata(keyless).idempotencyKey)
  }

  func test_sign_withoutIdempotencyKey_willOmitTheField_onThePresignaturePath() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignWithPresignatureReturnValue = MockConstants.mockSignatureResponse
    let signer = self.makeSigner(binary: mobileSpy, source: self.makePresignatureSource())

    try await self.signWithKey(signer, idempotencyKey: nil)

    let metadataString = try XCTUnwrap(mobileSpy.mobileSignWithPresignatureMetadataStrParam)
    XCTAssertFalse(metadataString.contains("idempotencyKey"), metadataString)
  }

  func test_sign_keyedThenUnkeyed_willNotCarryTheKeyIntoTheNextCall() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignReturnValue = MockConstants.mockSignatureResponse
    let signer = self.makeSigner(binary: mobileSpy)

    try await self.signWithKey(signer, idempotencyKey: Self.idempotencyKey)
    try await self.signWithKey(signer, idempotencyKey: nil)

    XCTAssertEqual(mobileSpy.mobileSignCallsCount, 2)
    let second = try XCTUnwrap(mobileSpy.mobileSignMetadataParam)
    XCTAssertFalse(second.contains("idempotencyKey"), "The signer must not retain the first call's key: \(second)")
  }

  func test_sign_rawPayload_withIdempotencyKey_willOmitTheField() async throws {
    // A raw sign is never broadcast, so Portal could never settle a key sent with one.
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignReturnValue = MockConstants.mockSignatureResponse
    let signer = self.makeSigner(binary: mobileSpy)

    try await self.signWithKey(signer, idempotencyKey: Self.idempotencyKey, request: PortalSignRequest(method: nil, params: "deadbeef", isRaw: true))

    XCTAssertEqual(mobileSpy.mobileSignIsRawParam, true)
    let metadataString = try XCTUnwrap(mobileSpy.mobileSignMetadataParam)
    XCTAssertFalse(metadataString.contains("idempotencyKey"), metadataString)
    XCTAssertEqual(try self.decodeMetadata(metadataString).isRaw, true)
  }

  func test_sign_rawPayload_withIdempotencyKey_willOmitTheField_onThePresignaturePath() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignWithPresignatureReturnValue = MockConstants.mockSignatureResponse
    let signer = self.makeSigner(binary: mobileSpy, source: self.makePresignatureSource())

    try await self.signWithKey(signer, idempotencyKey: Self.idempotencyKey, request: PortalSignRequest(method: nil, params: "deadbeef", isRaw: true))

    XCTAssertEqual(mobileSpy.mobileSignWithPresignatureCallsCount, 1)
    let metadataString = try XCTUnwrap(mobileSpy.mobileSignWithPresignatureMetadataStrParam)
    XCTAssertFalse(metadataString.contains("idempotencyKey"), metadataString)
  }

  func test_sign_nonRawPayload_withIsRawFalse_keepsTheKey() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignReturnValue = MockConstants.mockSignatureResponse
    let signer = self.makeSigner(binary: mobileSpy)

    try await self.signWithKey(
      signer,
      idempotencyKey: Self.idempotencyKey,
      request: PortalSignRequest(method: .eth_sendTransaction, params: "{\"to\":\"0xabc\"}", isRaw: false)
    )

    XCTAssertEqual(try self.decodeMetadata(mobileSpy.mobileSignMetadataParam).idempotencyKey, Self.idempotencyKey)
  }

  // MARK: Dispatch through the protocol

  func test_sign_throughTheProtocolExistential_reachesTheClassImplementation() async throws {
    // `PortalProvider.signer` is a `PortalSignerProtocol`. If the class method stopped being the
    // witness for the requirement, the extension default would silently drop the key.
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignReturnValue = MockConstants.mockSignatureResponse
    let signer: PortalSignerProtocol = self.makeSigner(binary: mobileSpy)
    let blockchain = try XCTUnwrap(self.blockchain)

    _ = try await signer.sign(
      "eip155:11155111",
      withPayload: PortalSignRequest(method: .eth_sendTransaction, params: "{\"to\":\"0xabc\"}"),
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain,
      signatureApprovalMemo: nil,
      sponsorGas: nil,
      reqId: nil,
      idempotencyKey: Self.idempotencyKey,
      token: Self.idempotencyToken
    )

    XCTAssertEqual(try self.decodeMetadata(mobileSpy.mobileSignMetadataParam).idempotencyKey, Self.idempotencyKey)
    XCTAssertFalse(self.logger.contains("does not accept idempotencyKey"))
  }

  func test_mockPortalMpcSigner_throughTheProtocolExistential_returnsMockValues_withoutWarning() async throws {
    let signer: PortalSignerProtocol = MockPortalMpcSigner(
      credentials: MockConstants.mockCredentials,
      keychain: MockPortalKeychain()
    )
    let blockchain = try XCTUnwrap(self.blockchain)

    let transactionHash = try await signer.sign(
      "eip155:11155111",
      withPayload: PortalSignRequest(method: .eth_sendTransaction, params: "tx"),
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain,
      signatureApprovalMemo: nil,
      sponsorGas: nil,
      reqId: nil,
      idempotencyKey: Self.idempotencyKey,
      token: Self.idempotencyToken
    )

    XCTAssertEqual(transactionHash, MockConstants.mockTransactionHash)
    XCTAssertFalse(self.logger.contains("does not accept idempotencyKey"))
  }

  // MARK: Binary error shape

  func test_sign_idempotencyRejection_inTheGoBindingsErrorShape_isSurfacedWithItsIdAndMessage() async throws {
    // The Go binding's `createErrorResponse` output: no `data` key, and `code` only on its
    // marshal-failure fallback. Both shapes must decode into the server's id.
    let shapes = [
      #"{"error":{"id":"IDEMPOTENT_REQUEST_IN_PROGRESS","message":"Idempotent request already in progress"}}"#,
      #"{"error":{"id":"IDEMPOTENT_REQUEST_IN_PROGRESS", "message":"Idempotent request already in progress", "code": 216}}"#
    ]

    for shape in shapes {
      let mobileSpy = MobileSpy()
      mobileSpy.mobileSignReturnValue = shape
      let signer = self.makeSigner(binary: mobileSpy)

      let error = await self.captureError { try await self.signWithKey(signer, idempotencyKey: Self.idempotencyKey) }

      let mpcError = try XCTUnwrap(error as? PortalMpcError, shape)
      XCTAssertEqual(mpcError.id, PortalIdempotencyErrorId.requestInProgress, shape)
      XCTAssertEqual(mpcError.message, "Idempotent request already in progress", shape)
      XCTAssertTrue(mpcError.isIdempotencyRejection, shape)
      XCTAssertFalse(mpcError.isIdempotencyKeyReused, shape)
    }
  }

  // MARK: Presignature fallback

  func test_sign_presignatureRejectedWithIdempotencyId_willNotFallBack() async throws {
    for id in PortalIdempotencyErrorId.all.sorted() {
      let mobileSpy = MobileSpy()
      mobileSpy.mobileSignWithPresignatureReturnValue = MpcJSON.error(id: id, message: "rejected")
      mobileSpy.mobileSignReturnValue = MockConstants.mockSignatureResponse
      let source = self.makePresignatureSource()
      let signer = self.makeSigner(binary: mobileSpy, source: source)

      let error = await self.captureError { try await self.signWithKey(signer, idempotencyKey: Self.idempotencyKey) }

      let mpcError = try XCTUnwrap(error as? PortalMpcError, id)
      XCTAssertEqual(mpcError.id, id)
      XCTAssertTrue(mpcError.isIdempotencyRejection, id)
      XCTAssertEqual(mobileSpy.mobileSignWithPresignatureCallsCount, 1, id)
      XCTAssertEqual(mobileSpy.mobileSignCallsCount, 0, "\(id) must not be retried through the normal sign.")
      XCTAssertEqual(source.consumeCallCount, 1, id)
    }
  }

  func test_sign_presignatureRejectedWithIdempotencyId_willLogTheIdButNotTheKeyOrToken() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignWithPresignatureReturnValue = MpcJSON.error(id: PortalIdempotencyErrorId.requestInProgress, message: "in progress")
    let signer = self.makeSigner(binary: mobileSpy, source: self.makePresignatureSource())

    _ = await self.captureError { try await self.signWithKey(signer, idempotencyKey: Self.idempotencyKey) }

    let errors = self.logger.messages(at: .error)
    XCTAssertTrue(
      errors.contains { $0.contains("idempotency key") && $0.contains("IDEMPOTENT_REQUEST_IN_PROGRESS") && $0.contains("not falling back") },
      "Unexpected error logs: \(errors)"
    )
    self.logger.assertNoSecret(Self.idempotencyKey)
    self.logger.assertNoSecret(Self.idempotencyToken)
  }

  func test_sign_presignatureFailsWithOtherError_withKey_willStillFallBack_withTheKey() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignWithPresignatureReturnValue = MpcJSON.error(id: "PRESIGNATURE_EXPIRED")
    mobileSpy.mobileSignReturnValue = MockConstants.mockSignatureResponse
    let signer = self.makeSigner(binary: mobileSpy, source: self.makePresignatureSource())

    let signature = try await self.signWithKey(signer, idempotencyKey: Self.idempotencyKey)

    XCTAssertEqual(signature, MockConstants.mockSignature)
    XCTAssertEqual(mobileSpy.mobileSignWithPresignatureCallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileSignCallsCount, 1, "Presignature problems still fall back when a key is present.")
    XCTAssertEqual(try self.decodeMetadata(mobileSpy.mobileSignMetadataParam).idempotencyKey, Self.idempotencyKey)
  }

  func test_sign_fallbackRejectedWithKeyReused_willWarnWithTheFirstAttempt_withoutLoggingTheKey() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignWithPresignatureReturnValue = MpcJSON.error(id: "PRESIGNATURE_EXPIRED", message: "presignature expired")
    mobileSpy.mobileSignReturnValue = MpcJSON.error(id: PortalIdempotencyErrorId.keyReused, message: "Idempotency key reused for different request payload")
    let signer = self.makeSigner(binary: mobileSpy, source: self.makePresignatureSource())

    let error = await self.captureError { try await self.signWithKey(signer, idempotencyKey: Self.idempotencyKey) }

    let mpcError = try XCTUnwrap(error as? PortalMpcError)
    XCTAssertTrue(mpcError.isIdempotencyKeyReused)
    XCTAssertEqual(mobileSpy.mobileSignCallsCount, 1)
    let warning = try XCTUnwrap(
      self.logger.messages(at: .warn).first { $0.contains("fallback sign was rejected") },
      "Expected a warning naming the presignature attempt: \(self.logger.messages(at: .warn))"
    )
    XCTAssertTrue(warning.contains("IDEMPOTENCY_KEY_REUSED"), warning)
    XCTAssertTrue(warning.contains("id=PRESIGNATURE_EXPIRED"), warning)
    XCTAssertTrue(warning.contains("message=presignature expired"), warning)
    self.logger.assertNoSecret(Self.idempotencyKey)
    self.logger.assertNoSecret(Self.idempotencyToken)
  }

  func test_sign_fallbackRejectedWithIdempotencyId_afterANonMpcPresignatureFailure_willDescribeThatFailure() async throws {
    let mobileSpy = MobileSpy()
    // Not JSON, so the presignature path throws a DecodingError rather than a PortalMpcError.
    mobileSpy.mobileSignWithPresignatureReturnValue = "not-json"
    mobileSpy.mobileSignReturnValue = MpcJSON.error(id: PortalIdempotencyErrorId.requestPreviouslyFailed)
    let signer = self.makeSigner(binary: mobileSpy, source: self.makePresignatureSource())

    let error = await self.captureError { try await self.signWithKey(signer, idempotencyKey: Self.idempotencyKey) }

    XCTAssertEqual((error as? PortalMpcError)?.id, PortalIdempotencyErrorId.requestPreviouslyFailed)
    let warning = try XCTUnwrap(self.logger.messages(at: .warn).first { $0.contains("fallback sign was rejected") })
    XCTAssertTrue(warning.contains("DecodingError"), warning)
    self.logger.assertNoSecret(Self.idempotencyKey)
  }

  func test_sign_normalSignRejectedWithIdempotencyId_withoutAPresignatureAttempt_willNotWarn() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignReturnValue = MpcJSON.error(id: PortalIdempotencyErrorId.requestAlreadyCompleted)
    let signer = self.makeSigner(binary: mobileSpy)

    let error = await self.captureError { try await self.signWithKey(signer, idempotencyKey: Self.idempotencyKey) }

    XCTAssertTrue((error as? PortalMpcError)?.isIdempotencyRejection == true)
    XCTAssertFalse(self.logger.contains("fallback sign was rejected"), "There was no presignature attempt to report.")
  }

  func test_sign_fallbackRejectedWithOtherError_willNotEmitTheIdempotencyWarning() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignWithPresignatureReturnValue = MpcJSON.error(id: "PRESIG_FAIL")
    mobileSpy.mobileSignReturnValue = MpcJSON.error(id: "SIGN_FAIL")
    let signer = self.makeSigner(binary: mobileSpy, source: self.makePresignatureSource())

    let error = await self.captureError { try await self.signWithKey(signer, idempotencyKey: Self.idempotencyKey) }

    XCTAssertEqual((error as? PortalMpcError)?.id, "SIGN_FAIL")
    XCTAssertFalse(self.logger.contains("fallback sign was rejected"))
    self.logger.assertNoSecret(Self.idempotencyKey)
  }

  func test_sign_presignatureAuthFailed_withKey_isStillSurfacedAsAuthFailure() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignWithPresignatureReturnValue = MpcJSON.authFailed
    let signer = self.makeSigner(binary: mobileSpy, source: self.makePresignatureSource())

    let error = await self.captureError { try await self.signWithKey(signer, idempotencyKey: Self.idempotencyKey) }

    let mpcError = try XCTUnwrap(error as? PortalMpcError)
    XCTAssertTrue(mpcError.isAuthFailure)
    XCTAssertFalse(mpcError.isIdempotencyRejection)
    XCTAssertEqual(mobileSpy.mobileSignCallsCount, 0)
  }

  // MARK: MockPortalMpcSigner

  func test_mockPortalMpcSigner_idempotencyKeyOverload_willReturnMockValues_withoutTheBinary() async throws {
    // The mock's default binary is the real `MobileWrapper`; reaching it would sign for real.
    let signer = MockPortalMpcSigner(
      credentials: MockConstants.mockCredentials,
      keychain: MockPortalKeychain()
    )

    let transactionHash = try await self.signWithKey(
      signer,
      idempotencyKey: Self.idempotencyKey,
      request: PortalSignRequest(method: .eth_sendTransaction, params: "tx")
    )
    let signature = try await self.signWithKey(
      signer,
      idempotencyKey: nil,
      request: PortalSignRequest(method: .eth_sign, params: "[]")
    )

    XCTAssertEqual(transactionHash, MockConstants.mockTransactionHash)
    XCTAssertEqual(signature, MockConstants.mockSignature)
  }
}

// MARK: - Idempotency key over the MPC Enclave API

/// `PortalMpcSigner` over a real `EnclaveMobileWrapper` over a recording transport: the whole
/// enclave path short of the network. These cases pin that a keyed request sends the key on the
/// presignature `/v1/sign` and on its normal-sign fallback, that a raw sign never sends it, and
/// that the enclave's HTTP 409 / 422 / 400 idempotency bodies surface from the signer exactly like
/// the device path: a `PortalMpcError` with the server's id, with no fallback or retry.
extension PortalMpcSignerTests {
  private static let enclaveKey = "enclave-idem-key-9d2e"
  private static let enclaveToken = "tok-enclave-idem-secret"
  private static let enclaveHost = "mpc-client.portalhq.io"

  /// A signer over a real `EnclaveMobileWrapper` on `requests`. The keychain is returned so the
  /// test keeps it alive: the signer holds it weakly, and without a share the wrapper refuses to
  /// send anything.
  private func makeEnclaveSigner(
    requests: PortalRequestsProtocol,
    featureFlags: FeatureFlags? = FeatureFlags(usePresignatures: true),
    source: MockPresignatureSource? = nil
  ) -> (signer: PortalMpcSigner, keychain: PortalKeychainSpy) {
    let keychain = PortalKeychainSpy()
    let signer = PortalMpcSigner(
      keychain: keychain,
      featureFlags: featureFlags,
      binary: EnclaveMobileWrapper(requests: requests, enclaveMPCHost: Self.enclaveHost),
      presignatureSource: source
    )
    return (signer, keychain)
  }

  private func enclaveSigningSpy() throws -> PortalRequestsSpy {
    let spy = PortalRequestsSpy()
    spy.returnData = try JSONEncoder().encode(EnclaveSignResponse(data: "0xenclave-tx-hash"))
    return spy
  }

  private func enclaveKeyHeader(of request: PortalBaseRequestProtocol?) -> String? {
    request?.headers.first { $0.key.caseInsensitiveCompare(PORTAL_IDEMPOTENCY_KEY_HEADER) == .orderedSame }?.value
  }

  /// Signs through the `idempotencyKey:` overload, the one `PortalProvider` calls.
  @discardableResult
  private func signBroadcast(
    _ signer: PortalMpcSigner,
    method: PortalRequestMethod = .eth_sendTransaction,
    idempotencyKey: String? = PortalMpcSignerTests.enclaveKey,
    isRaw: Bool? = nil
  ) async throws -> String {
    let blockchain = try XCTUnwrap(self.blockchain)
    return try await signer.sign(
      "eip155:11155111",
      withPayload: PortalSignRequest(method: method, params: "{\"to\":\"0xabc\"}", isRaw: isRaw),
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain,
      signatureApprovalMemo: nil,
      sponsorGas: nil,
      reqId: "trace-1",
      idempotencyKey: idempotencyKey,
      token: Self.enclaveToken
    )
  }

  // MARK: Presignature path

  func test_enclave_keyedRequest_usesThePresignature_andSendsOneProtectedSign() async throws {
    for method in [PortalRequestMethod.eth_sendTransaction, .sol_signAndSendTransaction, .sol_signAndConfirmTransaction] {
      self.logger.reset()
      let spy = try self.enclaveSigningSpy()
      let source = self.makePresignatureSource()
      let (signer, keychain) = self.makeEnclaveSigner(requests: spy, source: source)

      let signature = try await self.signBroadcast(signer, method: method)

      withExtendedLifetime(keychain) {}
      XCTAssertEqual(signature, "0xenclave-tx-hash", method.rawValue)
      XCTAssertEqual(source.consumeCallCount, 1, method.rawValue)
      XCTAssertEqual(spy.executeCallsCount, 1, method.rawValue)
      let request = try XCTUnwrap(spy.executeRequestParam, method.rawValue)
      XCTAssertEqual(request.url.absoluteString, "https://\(Self.enclaveHost)/v1/sign", method.rawValue)
      XCTAssertEqual(self.enclaveKeyHeader(of: request), Self.enclaveKey, method.rawValue)
      let payload = try XCTUnwrap(request.payload as? [String: String], method.rawValue)
      XCTAssertEqual(payload["presignature"], "presig-data", method.rawValue)
      XCTAssertEqual(payload["method"], method.rawValue)
      XCTAssertEqual(try self.decodeMetadata(payload["metadataStr"]).idempotencyKey, Self.enclaveKey, method.rawValue)
      self.logger.assertNoSecret(Self.enclaveKey)
      self.logger.assertNoSecret(Self.enclaveToken)
    }
  }

  func test_enclave_keyedPresignatureFailsWithoutAnIdempotencyId_fallsBackToOneNormalSign_withTheSameKey() async throws {
    let spy = try self.enclaveSigningSpy()
    spy.executeThrowableErrorSequence = [
      PortalRequestsError.internalServerError("502 - Bad Gateway", url: "https://\(Self.enclaveHost)/v1/sign")
    ]
    let source = self.makePresignatureSource()
    let (signer, keychain) = self.makeEnclaveSigner(requests: spy, source: source)

    let signature = try await self.signBroadcast(signer)

    withExtendedLifetime(keychain) {}
    XCTAssertEqual(signature, "0xenclave-tx-hash")
    XCTAssertEqual(source.consumeCallCount, 1)
    let requests = spy.executeRequestHistory
    XCTAssertEqual(requests.count, 2, "The presignature failure falls back to one normal sign.")
    XCTAssertEqual((requests.first?.payload as? [String: String])?["presignature"], "presig-data")
    XCTAssertNil((requests.last?.payload as? [String: String])?["presignature"])
    XCTAssertEqual(requests.map { self.enclaveKeyHeader(of: $0) }, [Self.enclaveKey, Self.enclaveKey])
    self.logger.assertNoSecret(Self.enclaveKey)
    self.logger.assertNoSecret(Self.enclaveToken)
  }

  func test_enclave_unkeyedRequest_keepsThePresignaturePath() async throws {
    let spy = try self.enclaveSigningSpy()
    let source = self.makePresignatureSource()
    let (signer, keychain) = self.makeEnclaveSigner(requests: spy, source: source)

    let signature = try await self.signBroadcast(signer, idempotencyKey: nil)

    withExtendedLifetime(keychain) {}
    XCTAssertEqual(signature, "0xenclave-tx-hash")
    XCTAssertEqual(source.consumeCallCount, 1)
    XCTAssertEqual(spy.executeCallsCount, 1)
    let request = try XCTUnwrap(spy.executeRequestParam)
    XCTAssertEqual(request.url.absoluteString, "https://\(Self.enclaveHost)/v1/sign")
    XCTAssertEqual((request.payload as? [String: String])?["presignature"], "presig-data")
    XCTAssertNil(self.enclaveKeyHeader(of: request))
  }

  func test_enclave_rawSign_withKey_keepsThePresignaturePath_withoutTheHeader() async throws {
    // A raw sign is never broadcast, so it never carries the key.
    let spy = try self.enclaveSigningSpy()
    let source = self.makePresignatureSource()
    let (signer, keychain) = self.makeEnclaveSigner(requests: spy, source: source)

    try await self.signBroadcast(signer, method: .eth_sendTransaction, isRaw: true)

    withExtendedLifetime(keychain) {}
    XCTAssertEqual(source.consumeCallCount, 1)
    let request = try XCTUnwrap(spy.executeRequestParam)
    XCTAssertTrue(request.url.absoluteString.contains("/v1/raw/sign/"), request.url.absoluteString)
    XCTAssertNil(self.enclaveKeyHeader(of: request))
  }

  func test_enclave_keyedRequest_withPresignaturesDisabled_signsNormally_withTheKey() async throws {
    let spy = try self.enclaveSigningSpy()
    let source = self.makePresignatureSource()
    let (signer, keychain) = self.makeEnclaveSigner(requests: spy, featureFlags: nil, source: source)

    try await self.signBroadcast(signer)

    withExtendedLifetime(keychain) {}
    XCTAssertEqual(source.consumeCallCount, 0)
    XCTAssertEqual(self.enclaveKeyHeader(of: spy.executeRequestParam), Self.enclaveKey)
  }

  func test_device_keyedRequest_keepsThePresignaturePath_withTheKeyInMetadata() async throws {
    // The gateway enforces the key on `/v6/sign?presignatureId=`.
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignWithPresignatureReturnValue = MockConstants.mockSignatureResponse
    let source = self.makePresignatureSource()
    let signer = self.makeSigner(binary: mobileSpy, source: source)

    try await self.signBroadcast(signer)

    XCTAssertEqual(source.consumeCallCount, 1)
    XCTAssertEqual(mobileSpy.mobileSignWithPresignatureCallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileSignCallsCount, 0)
    XCTAssertEqual(try self.decodeMetadata(mobileSpy.mobileSignWithPresignatureMetadataStrParam).idempotencyKey, Self.enclaveKey)
  }

  // MARK: Enclave idempotency errors, end to end

  func test_enclave_idempotencyRejections_surfaceAsPortalMpcError_withTheServerId_andNoRetry() async throws {
    let responses: [(status: Int, id: String)] = [
      (409, PortalIdempotencyErrorId.requestInProgress),
      (409, PortalIdempotencyErrorId.requestAlreadyCompleted),
      (409, PortalIdempotencyErrorId.requestPreviouslyFailed),
      (409, PortalIdempotencyErrorId.requestUnexpectedState),
      (422, PortalIdempotencyErrorId.keyReused),
      (400, PortalIdempotencyErrorId.txMissing)
    ]

    for (status, id) in responses {
      let message = "Idempotent request - \(id)"
      let spy = PortalRequestsSpy()
      spy.executeThrowableErrorSequence = [
        PortalRequestsError.clientError(#"\#(status) - {"id":"\#(id)","message":"\#(message)","code":216}"#, url: "https://\(Self.enclaveHost)/v1/sign")
      ]
      let source = self.makePresignatureSource()
      let (signer, keychain) = self.makeEnclaveSigner(requests: spy, source: source)

      let error = await self.captureError { try await self.signBroadcast(signer) }

      withExtendedLifetime(keychain) {}
      let mpcError = try XCTUnwrap(error as? PortalMpcError, "\(status) \(id): \(String(describing: error))")
      XCTAssertEqual(mpcError.id, id, "\(status)")
      XCTAssertEqual(mpcError.message, message, "\(status)")
      XCTAssertTrue(mpcError.isIdempotencyRejection, "\(status) \(id)")
      XCTAssertEqual(mpcError.isIdempotencyKeyReused, id == PortalIdempotencyErrorId.keyReused, id)
      XCTAssertEqual(spy.executeCallsCount, 1, "\(id) must not be retried through the normal sign.")
      XCTAssertEqual(source.consumeCallCount, 1, id)
      XCTAssertEqual((spy.executeRequestParam?.payload as? [String: String])?["presignature"], "presig-data", id)
      XCTAssertEqual(self.enclaveKeyHeader(of: spy.executeRequestParam), Self.enclaveKey, id)
    }
    self.logger.assertNoSecret(Self.enclaveKey)
    self.logger.assertNoSecret(Self.enclaveToken)
  }

  func test_enclave_badRequest_surfacesAsPortalMpcError_thatIsNotAnIdempotencyRejection() async throws {
    let spy = PortalRequestsSpy()
    spy.executeThrowableErrorSequence = [
      PortalRequestsError.clientError(#"400 - {"id":"BAD_REQUEST","message":"invalid - request","code":201}"#, url: "https://\(Self.enclaveHost)/v1/sign")
    ]
    let (signer, keychain) = self.makeEnclaveSigner(requests: spy)

    let error = await self.captureError { try await self.signBroadcast(signer) }

    withExtendedLifetime(keychain) {}
    let mpcError = try XCTUnwrap(error as? PortalMpcError, String(describing: error))
    XCTAssertEqual(mpcError.id, "BAD_REQUEST")
    XCTAssertEqual(mpcError.message, "invalid - request")
    XCTAssertFalse(mpcError.isIdempotencyRejection)
    XCTAssertEqual(spy.executeCallsCount, 1)
  }

  func test_enclave_unkeyedPresignatureRejectedWithIdempotencyId_willNotFallBack() async throws {
    // The Phase 1 guard also holds over the enclave transport.
    let spy = PortalRequestsSpy()
    spy.executeThrowableErrorSequence = [
      PortalRequestsError.clientError(#"409 - {"id":"IDEMPOTENT_REQUEST_IN_PROGRESS","message":"in - progress","code":216}"#, url: "https://\(Self.enclaveHost)/v1/sign")
    ]
    let source = self.makePresignatureSource()
    let (signer, keychain) = self.makeEnclaveSigner(requests: spy, source: source)

    let error = await self.captureError { try await self.signBroadcast(signer, idempotencyKey: nil) }

    withExtendedLifetime(keychain) {}
    XCTAssertEqual((error as? PortalMpcError)?.id, PortalIdempotencyErrorId.requestInProgress)
    XCTAssertEqual(source.consumeCallCount, 1)
    XCTAssertEqual(spy.executeCallsCount, 1, "The rejection must not be retried through the normal sign.")
  }

  func test_enclave_unkeyedPresignatureFailsWithALongBodyWithoutAnId_willLogOnlyTheStartOfTheBody_andFallBack() async throws {
    // E.g. a proxy answering the presignature sign with a multi-KB page: the signer logs the
    // failure before falling back, and that log line must not carry the whole untrusted body.
    let longBody = "<html>" + String(repeating: "x", count: 10000) + "TAIL-MARKER</html>"
    let spy = try self.enclaveSigningSpy()
    spy.executeThrowableErrorSequence = [
      PortalRequestsError.internalServerError("502 - \(longBody)", url: "https://\(Self.enclaveHost)/v1/sign")
    ]
    let source = self.makePresignatureSource()
    let (signer, keychain) = self.makeEnclaveSigner(requests: spy, source: source)

    let signature = try await self.signBroadcast(signer, idempotencyKey: nil)

    withExtendedLifetime(keychain) {}
    XCTAssertEqual(signature, "0xenclave-tx-hash")
    XCTAssertEqual(source.consumeCallCount, 1)
    XCTAssertEqual(spy.executeCallsCount, 2, "The presignature failure falls back to one normal sign.")
    XCTAssertTrue(
      self.logger.messages(at: .error).contains { $0.contains("signWithPresignature failed: 502 - <html>") },
      "\(self.logger.messages(at: .error))"
    )
    XCTAssertFalse(self.logger.contains("TAIL-MARKER"), "The log must not carry the whole response body.")
    let longestLine = self.logger.messages.map(\.count).max() ?? 0
    XCTAssertLessThan(longestLine, 1000, "No log line may carry a multi-KB response body.")
    self.logger.assertNoSecret(Self.enclaveToken)
  }

  func test_enclave_409HtmlBodyAnd422EmptyBody_overTheRealTransport_surfaceAsSigningNetworkError_withTheStatus() async throws {
    // E.g. a proxy in front of the enclave: the body carries no error id, so the HTTP status is
    // what the caller gets, not a missing-signature error. Without an idempotency id the
    // presignature failure falls back to one normal sign, which carries the same key.
    for (status, body) in [(409, "<html><body>409 Conflict</body></html>"), (422, "")] {
      MockURLProtocol.reset()
      let session = MockURLProtocol.makeSession()
      defer {
        session.invalidateAndCancel()
        MockURLProtocol.reset()
      }
      MockURLProtocol.respond(status: status, body: body)
      let source = self.makePresignatureSource()
      let (signer, keychain) = self.makeEnclaveSigner(requests: PortalRequests(urlSession: session), source: source)

      let error = await self.captureError { try await self.signBroadcast(signer) }

      withExtendedLifetime(keychain) {}
      let mpcError = try XCTUnwrap(error as? PortalMpcError, "\(status): \(String(describing: error))")
      XCTAssertEqual(mpcError.id, "SIGNING_NETWORK_ERROR", "\(status)")
      XCTAssertEqual(mpcError.message, "\(status) - \(body)", "\(status)")
      XCTAssertFalse(mpcError.isIdempotencyRejection, "\(status)")
      XCTAssertEqual(
        MockURLProtocol.recordedRequests.map { $0.value(forHTTPHeaderField: PORTAL_IDEMPOTENCY_KEY_HEADER) },
        [Self.enclaveKey, Self.enclaveKey],
        "\(status)"
      )
      XCTAssertEqual(source.consumeCallCount, 1, "\(status)")
    }
    self.logger.assertNoSecret(Self.enclaveKey)
    self.logger.assertNoSecret(Self.enclaveToken)
  }
}
