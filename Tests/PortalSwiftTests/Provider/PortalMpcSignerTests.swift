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
