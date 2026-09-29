//
//  EnclaveMobileWrapperTests.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 21/02/2025.
//

@testable import PortalSwift
import XCTest

final class EnclaveMobileWrapperTests: XCTestCase {
  private var enclaveMobileWrapper: EnclaveMobileWrapper!
  private let encoder = JSONEncoder()
  private var recordingLogger = RecordingLogger()

  override func setUpWithError() throws {
    CredentialInvalidationRegistry.shared.resetForTesting()
    // The Idempotency-Key host gate reads this process-wide registry.
    PortalOwnedHosts.resetForTesting()
    recordingLogger = RecordingLogger()
    recordingLogger.install()
  }

  override func tearDownWithError() throws {
    recordingLogger.uninstall()
    CredentialInvalidationRegistry.shared.resetForTesting()
    PortalOwnedHosts.resetForTesting()
    enclaveMobileWrapper = nil
  }
}

// MARK: - Test Helpers

extension EnclaveMobileWrapperTests {
  func initEnclaveMobileWrapper(
    portalRequests: PortalRequestsProtocol = PortalRequestsSpy(),
    enclaveMPCHost: String = ""
  ) {
    enclaveMobileWrapper = EnclaveMobileWrapper(requests: portalRequests, enclaveMPCHost: enclaveMPCHost)
  }
}

// MARK: - MobileSign tests

extension EnclaveMobileWrapperTests {
  func test_MobileSign() async throws {
    // given
    let transactionHash = "dummy-transaction-hash"
    let enclaveSigningResponse = try encoder.encode(EnclaveSignResponse(data: transactionHash))
    let portalRequestMock = PortalRequestsMock()
    portalRequestMock.returnValueData = enclaveSigningResponse
    initEnclaveMobileWrapper(portalRequests: portalRequestMock)
    let expectedReturnValue = "{\"data\":\"\(transactionHash)\"}"

    // and given
    let resultTransactionHash = await enclaveMobileWrapper?.MobileSign("", "", "", "", "", "", "", "", nil, isRaw: false)

    // then
    AssertJSONEqual(resultTransactionHash, expectedReturnValue)
  }

  func test_MobileSign_willCall_executeRequest_onlyOnce() async {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initEnclaveMobileWrapper(portalRequests: portalRequestsSpy)

    // and given
    _ = await enclaveMobileWrapper?.MobileSign("", "", "", "", "", "", "", "", nil, isRaw: false)

    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
  }

  func test_MobileSign_willCall_executeRequest_passingCorrectParams() async {
    // given
    let enclaveMPCHost = "mpc-client.portalhq.io"
    let portalRequestsSpy = PortalRequestsSpy()
    initEnclaveMobileWrapper(portalRequests: portalRequestsSpy, enclaveMPCHost: enclaveMPCHost)

    let apiKey = "apiKey"
    let host = "host"
    let signingShare = "signingShare"
    let method = "method"
    let params = "params"
    let rpcUrl = "rpcUrl"
    let chainId = "chainId"
    let metadata = "metadata"

    // and given
    _ = await enclaveMobileWrapper?.MobileSign(apiKey, host, signingShare, method, params, rpcUrl, chainId, metadata, nil, isRaw: false)

    // then
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.absoluteString ?? "", "https://\(enclaveMPCHost)/v1/sign")
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.payload as? [String: String] ?? [:], [
      "method": method,
      "params": params,
      "share": signingShare,
      "chainId": chainId,
      "rpcUrl": rpcUrl,
      "metadataStr": metadata,
      "clientPlatform": "NATIVE_IOS",
      "clientPlatformVersion": SDK_VERSION
    ])
  }

  func test_MobileSign_willCall_executeRequest_passingCorrectParams_forRawSign() async {
    // given
    let enclaveMPCHost = "mpc-client.portalhq.io"
    let portalRequestsSpy = PortalRequestsSpy()
    initEnclaveMobileWrapper(portalRequests: portalRequestsSpy, enclaveMPCHost: enclaveMPCHost)

    let apiKey = "apiKey"
    let host = "host"
    let signingShare = "signingShare"
    let method = "method"
    let params = "params"
    let rpcUrl = "rpcUrl"
    let chainId = "chainId"
    let metadata = "metadata"
    let curve: PortalCurve = .SECP256K1

    // and given
    _ = await enclaveMobileWrapper?.MobileSign(apiKey, host, signingShare, method, params, rpcUrl, chainId, metadata, curve, isRaw: true)

    // then
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.absoluteString ?? "", "https://\(enclaveMPCHost)/v1/raw/sign/\(curve.rawValue)")
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.payload as? [String: String] ?? [:], [
      "params": params,
      "share": signingShare,
      "metadataStr": metadata,
      "clientPlatform": "NATIVE_IOS",
      "clientPlatformVersion": SDK_VERSION
    ])
  }

  func test_MobileSign_willReturn_correctError_forInvalidParams() async {
    // given
    initEnclaveMobileWrapper()
    let invalidParamsReturnValue = "{\"error\":{\"id\":\"INVALID_PARAMETERS\",\"message\":\"Invalid parameters provided\"}}"

    // and given
    var result = await enclaveMobileWrapper?.MobileSign(nil, "", "", "", "", "", "", "", nil, isRaw: nil)
    // then
    AssertJSONEqual(result, invalidParamsReturnValue)

    // and given
    result = await enclaveMobileWrapper?.MobileSign("", "", nil, "", "", "", "", "", nil, isRaw: nil)
    // then
    AssertJSONEqual(result, invalidParamsReturnValue)

    // and given
    result = await enclaveMobileWrapper?.MobileSign("", "", "", nil, "", "", "", "", nil, isRaw: nil)
    // then
    AssertJSONEqual(result, invalidParamsReturnValue)

    // and given
    result = await enclaveMobileWrapper?.MobileSign("", "", "", "", nil, "", "", "", nil, isRaw: nil)
    // then
    AssertJSONEqual(result, invalidParamsReturnValue)

    // and given
    result = await enclaveMobileWrapper?.MobileSign("", "", "", "", "", nil, "", "", nil, isRaw: nil)
    // then
    AssertJSONEqual(result, invalidParamsReturnValue)

    // and given
    result = await enclaveMobileWrapper?.MobileSign("", "", "", "", "", "", nil, "", nil, isRaw: nil)
    // then
    AssertJSONEqual(result, invalidParamsReturnValue)

    // and given
    result = await enclaveMobileWrapper?.MobileSign("", "", "", "", "", "", "", nil, nil, isRaw: nil)
    // then
    AssertJSONEqual(result, invalidParamsReturnValue)
  }

  func test_MobileSign_willReturn_correctError_whenExecuteRequestThrowError() async {
    // given
    let portalRequestsFailMock = PortalRequestsFailMock()
    initEnclaveMobileWrapper(portalRequests: portalRequestsFailMock)
    let expectedReturnValue = "{\"error\":{\"id\":\"SIGNING_NETWORK_ERROR\",\"message\":\"\(portalRequestsFailMock.errorToThrow.localizedDescription)\"}}"

    // and given
    let result = await enclaveMobileWrapper?.MobileSign("", "", "", "", "", "", "", "", nil, isRaw: nil)

    // then
    AssertJSONEqual(result, expectedReturnValue)
  }
}

// MARK: - MobilePresign tests

extension EnclaveMobileWrapperTests {
  func test_MobilePresign_returnsPresignResponse() async throws {
    let encoder = JSONEncoder()
    let presignResponse = EnclavePresignResponse(id: "presig-id", expiresAt: "2099-01-01T00:00:00Z", data: "presig-data")
    let portalRequestMock = PortalRequestsMock()
    portalRequestMock.returnValueData = try encoder.encode(presignResponse)
    initEnclaveMobileWrapper(portalRequests: portalRequestMock)

    let result = await enclaveMobileWrapper.MobilePresign("apiKey", "host", "share", "metadata", .SECP256K1)

    let resultData = result.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(PresignResponse.self, from: resultData)
    XCTAssertEqual(decoded.id, "presig-id")
    XCTAssertEqual(decoded.expiresAt, "2099-01-01T00:00:00Z")
    XCTAssertEqual(decoded.data, "presig-data")
  }

  func test_MobilePresign_callsCorrectEndpoint() async {
    let enclaveMPCHost = "mpc-client.portalhq.io"
    let portalRequestsSpy = PortalRequestsSpy()
    initEnclaveMobileWrapper(portalRequests: portalRequestsSpy, enclaveMPCHost: enclaveMPCHost)

    _ = await enclaveMobileWrapper.MobilePresign("apiKey", "host", "share", "metadata", .SECP256K1)

    XCTAssertEqual(
      portalRequestsSpy.executeRequestParam?.url.absoluteString ?? "",
      "https://\(enclaveMPCHost)/v1/presign/SECP256K1"
    )
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.payload as? [String: String] ?? [:], [
      "share": "share",
      "clientPlatform": "NATIVE_IOS",
      "clientPlatformVersion": SDK_VERSION
    ])
  }

  func test_MobilePresign_returnsError_forMissingCurve() async {
    initEnclaveMobileWrapper()

    let result = await enclaveMobileWrapper.MobilePresign("apiKey", "host", "share", "metadata", nil)
    let resultData = result.data(using: .utf8)!
    let decoded = try? JSONDecoder().decode(PresignResponse.self, from: resultData)
    XCTAssertNotNil(decoded?.error)
  }

  func test_MobilePresign_returnsError_whenRequestFails() async {
    let portalRequestsFailMock = PortalRequestsFailMock()
    initEnclaveMobileWrapper(portalRequests: portalRequestsFailMock)

    let result = await enclaveMobileWrapper.MobilePresign("apiKey", "host", "share", "metadata", .SECP256K1)
    let resultData = result.data(using: .utf8)!
    let decoded = try? JSONDecoder().decode(PresignResponse.self, from: resultData)
    XCTAssertNil(decoded?.id)
  }
}

// MARK: - MobileSignWithPresignature tests

extension EnclaveMobileWrapperTests {
  func test_MobileSignWithPresignature_returnsSignResponse() async throws {
    let encoder = JSONEncoder()
    let signResponse = EnclaveSignResponse(data: "tx-hash")
    let portalRequestMock = PortalRequestsMock()
    portalRequestMock.returnValueData = try encoder.encode(signResponse)
    initEnclaveMobileWrapper(portalRequests: portalRequestMock)

    let result = await enclaveMobileWrapper.MobileSignWithPresignature(
      "apiKey", "host", "share", "presig-data", "eth_sendTransaction", "{}", "https://rpc.test", "1", "metadata", nil, isRaw: false
    )

    let expectedReturnValue = "{\"data\":\"tx-hash\"}"
    AssertJSONEqual(result, expectedReturnValue)
  }

  func test_MobileSignWithPresignature_callsCorrectEndpoint_nonRaw() async {
    let enclaveMPCHost = "mpc-client.portalhq.io"
    let portalRequestsSpy = PortalRequestsSpy()
    initEnclaveMobileWrapper(portalRequests: portalRequestsSpy, enclaveMPCHost: enclaveMPCHost)

    _ = await enclaveMobileWrapper.MobileSignWithPresignature(
      "apiKey", "host", "share", "presig-data", "method", "params", "rpcUrl", "chainId", "metadata", nil, isRaw: false
    )

    XCTAssertEqual(
      portalRequestsSpy.executeRequestParam?.url.absoluteString ?? "",
      "https://\(enclaveMPCHost)/v1/sign"
    )
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.payload as? [String: String] ?? [:], [
      "method": "method",
      "params": "params",
      "share": "share",
      "presignature": "presig-data",
      "chainId": "chainId",
      "rpcUrl": "rpcUrl",
      "metadataStr": "metadata",
      "clientPlatform": "NATIVE_IOS",
      "clientPlatformVersion": SDK_VERSION
    ])
  }

  func test_MobileSignWithPresignature_callsCorrectEndpoint_raw() async {
    let enclaveMPCHost = "mpc-client.portalhq.io"
    let portalRequestsSpy = PortalRequestsSpy()
    initEnclaveMobileWrapper(portalRequests: portalRequestsSpy, enclaveMPCHost: enclaveMPCHost)

    _ = await enclaveMobileWrapper.MobileSignWithPresignature(
      "apiKey", "host", "share", "presig-data", "method", "params", "rpcUrl", "chainId", "metadata", .SECP256K1, isRaw: true
    )

    XCTAssertEqual(
      portalRequestsSpy.executeRequestParam?.url.absoluteString ?? "",
      "https://\(enclaveMPCHost)/v1/raw/sign/SECP256K1"
    )
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.payload as? [String: String] ?? [:], [
      "params": "params",
      "share": "share",
      "presignature": "presig-data",
      "metadataStr": "metadata",
      "clientPlatform": "NATIVE_IOS",
      "clientPlatformVersion": SDK_VERSION
    ])
  }

  func test_MobileSignWithPresignature_returnsError_forInvalidParams() async {
    initEnclaveMobileWrapper()

    let result = await enclaveMobileWrapper.MobileSignWithPresignature(
      nil, "host", "share", "presig", "method", "params", "rpc", "1", "meta", nil, isRaw: false
    )

    let resultData = result.data(using: .utf8)!
    let decoded = try? JSONDecoder().decode(SignResult.self, from: resultData)
    XCTAssertNotNil(decoded?.error)
  }

  func test_MobileSignWithPresignature_returnsError_whenRequestFails() async {
    let portalRequestsFailMock = PortalRequestsFailMock()
    initEnclaveMobileWrapper(portalRequests: portalRequestsFailMock)

    let result = await enclaveMobileWrapper.MobileSignWithPresignature(
      "apiKey", "host", "share", "presig", "method", "params", "rpc", "1", "meta", nil, isRaw: false
    )

    let resultData = result.data(using: .utf8)!
    let decoded = try? JSONDecoder().decode(SignResult.self, from: resultData)
    XCTAssertNotNil(decoded?.error)
  }
}

// MARK: - Raw sign metadata (SDK-194)

extension EnclaveMobileWrapperTests {
  private var invalidParamsResult: String {
    "{\"error\":{\"id\":\"INVALID_PARAMETERS\",\"message\":\"Invalid parameters provided\"}}"
  }

  private func rawMetadata(memo: String) throws -> String {
    var metadata = MpcMetadata(clientPlatform: "NATIVE_IOS", mpcServerVersion: "v6")
    metadata.isRaw = true
    metadata.signatureApprovalMemo = memo
    metadata.reqId = "trace-123"
    return try metadata.jsonString()
  }

  func test_MobileSign_rawSign_returnsInvalidParameters_whenMetadataIsNil() async {
    let portalRequestsSpy = PortalRequestsSpy()
    initEnclaveMobileWrapper(portalRequests: portalRequestsSpy)

    let result = await enclaveMobileWrapper.MobileSign(
      "apiKey", "host", "share", nil, "74657374", "", "", nil, .SECP256K1, isRaw: true
    )

    AssertJSONEqual(result, invalidParamsResult)
    XCTAssertNil(portalRequestsSpy.executeRequestParam)
  }

  func test_MobileSign_rawSign_forwardsSignatureApprovalMemo_insideMetadataStr() async throws {
    let portalRequestsSpy = PortalRequestsSpy()
    initEnclaveMobileWrapper(portalRequests: portalRequestsSpy, enclaveMPCHost: "mpc-client.portalhq.io")
    let metadata = try rawMetadata(memo: "approve-this")

    _ = await enclaveMobileWrapper.MobileSign(
      "apiKey", "host", "share", nil, "74657374", "", "", metadata, .SECP256K1, isRaw: true
    )

    let payload = portalRequestsSpy.executeRequestParam?.payload as? [String: String]
    let sentMetadata = try XCTUnwrap(payload?["metadataStr"])
    let decoded = try JSONDecoder().decode(MpcMetadata.self, from: Data(sentMetadata.utf8))
    XCTAssertEqual(decoded.signatureApprovalMemo, "approve-this")
    XCTAssertEqual(decoded.isRaw, true)
    XCTAssertEqual(decoded.reqId, "trace-123")
  }

  func test_MobileSignWithPresignature_raw_returnsInvalidParameters_whenMetadataIsNil() async {
    let portalRequestsSpy = PortalRequestsSpy()
    initEnclaveMobileWrapper(portalRequests: portalRequestsSpy)

    let result = await enclaveMobileWrapper.MobileSignWithPresignature(
      "apiKey", "host", "share", "presig-data", nil, "74657374", "", "", nil, .SECP256K1, isRaw: true
    )

    AssertJSONEqual(result, invalidParamsResult)
    XCTAssertNil(portalRequestsSpy.executeRequestParam)
  }

  func test_MobileSignWithPresignature_raw_forwardsSignatureApprovalMemo_insideMetadataStr() async throws {
    let portalRequestsSpy = PortalRequestsSpy()
    initEnclaveMobileWrapper(portalRequests: portalRequestsSpy, enclaveMPCHost: "mpc-client.portalhq.io")
    let metadata = try rawMetadata(memo: "approve-this")

    _ = await enclaveMobileWrapper.MobileSignWithPresignature(
      "apiKey", "host", "share", "presig-data", nil, "74657374", "", "", metadata, .SECP256K1, isRaw: true
    )

    XCTAssertEqual(
      portalRequestsSpy.executeRequestParam?.url.absoluteString ?? "",
      "https://mpc-client.portalhq.io/v1/raw/sign/SECP256K1"
    )
    let payload = portalRequestsSpy.executeRequestParam?.payload as? [String: String]
    XCTAssertEqual(payload?["presignature"], "presig-data")
    let sentMetadata = try XCTUnwrap(payload?["metadataStr"])
    let decoded = try JSONDecoder().decode(MpcMetadata.self, from: Data(sentMetadata.utf8))
    XCTAssertEqual(decoded.signatureApprovalMemo, "approve-this")
    XCTAssertEqual(decoded.isRaw, true)
  }
}

// MARK: - Credentials test helpers

/// Fixtures for the credential-aware enclave cases, kept in one place so the token asserted on
/// the `Authorization` header and the token searched for in the log are literally the same value.
private enum EnclaveFixtures {
  static let token = "enclave-tok"
  static let host = "mpc-client.portalhq.io"
  static let curve: PortalCurve = .SECP256K1
  static let signUrl = "https://\(host)/v1/sign"
}

extension EnclaveMobileWrapperTests {
  /// A wrapper over a transport of the test's choosing. Returned rather than assigned to the
  /// shared property so each credential case owns its own spy and wrapper.
  func makeWrapper(
    requests: PortalRequestsProtocol,
    enclaveMPCHost: String = EnclaveFixtures.host
  ) -> EnclaveMobileWrapper {
    EnclaveMobileWrapper(requests: requests, enclaveMPCHost: enclaveMPCHost)
  }

  /// A transport that answers the next `execute` with the transport-level 401 the credentials
  /// layer defines, which is what every enclave catch block has to remap to `AUTH_FAILED`.
  func unauthorizedSpy() -> PortalRequestsSpy {
    let spy = PortalRequestsSpy()
    spy.executeThrowableErrorSequence = [PortalRequestsError.unauthorized]
    return spy
  }

  /// A transport that answers `execute` with a successful enclave sign body.
  func signingSpy(signature: String = "0xsignature") throws -> PortalRequestsSpy {
    let spy = PortalRequestsSpy()
    spy.returnData = try encoder.encode(EnclaveSignResponse(data: signature))
    return spy
  }

  /// A transport that answers `execute` with a successful enclave presign body.
  func presigningSpy() throws -> PortalRequestsSpy {
    let spy = PortalRequestsSpy()
    spy.returnData = try encoder.encode(
      EnclavePresignResponse(id: "presig-id", expiresAt: "2099-01-01T00:00:00Z", data: "presig-data")
    )
    return spy
  }

  func decodeSign(_ result: String) throws -> SignResult {
    let data = try XCTUnwrap(result.data(using: .utf8), "The wrapper must always return UTF-8 JSON.")
    return try JSONDecoder().decode(SignResult.self, from: data)
  }

  func decodePresign(_ result: String) throws -> PresignResponse {
    let data = try XCTUnwrap(result.data(using: .utf8), "The wrapper must always return UTF-8 JSON.")
    return try JSONDecoder().decode(PresignResponse.self, from: data)
  }

  /// The `Authorization` header the wrapper put on its single request.
  func authorizationHeader(of spy: PortalRequestsSpy) throws -> String {
    let request = try XCTUnwrap(spy.executeRequestParam, "The wrapper should have issued a request.")
    return try XCTUnwrap(request.headers["Authorization"], "Portal-authenticated requests must carry a bearer.")
  }
}

// MARK: - 401 is remapped to AUTH_FAILED

extension EnclaveMobileWrapperTests {
  func test_MobileSign_willNotRetry_on401() async throws {
    // given
    let spy = unauthorizedSpy()
    let wrapper = makeWrapper(requests: spy)

    // and given
    _ = await wrapper.MobileSign(
      EnclaveFixtures.token, "host", "share", "method", "params", "rpcUrl", "chainId", "metadata", nil, isRaw: false
    )

    // then
    XCTAssertEqual(spy.executeCallsCount, 1, "A rejected credential is not retried at the transport.")
  }

  func test_MobilePresign_willNotRetry_on401() async throws {
    // given
    let spy = unauthorizedSpy()
    let wrapper = makeWrapper(requests: spy)

    // and given
    _ = await wrapper.MobilePresign(EnclaveFixtures.token, "host", "share", "metadata", EnclaveFixtures.curve)

    // then
    XCTAssertEqual(spy.executeCallsCount, 1, "A rejected credential is not retried at the transport.")
  }
}

// MARK: - Non-401 failures: a body with an error id is decoded as-is

extension EnclaveMobileWrapperTests {
  func test_MobileSign_willKeepDecodedPortalError_when400WithBody() async throws {
    // given
    let spy = PortalRequestsSpy()
    spy.executeThrowableErrorSequence = [
      PortalRequestsError.clientError("400 - {\"id\":\"BAD_SHARE\",\"message\":\"m\"}", url: EnclaveFixtures.signUrl)
    ]
    let wrapper = makeWrapper(requests: spy)

    // and given
    let result = await wrapper.MobileSign(
      EnclaveFixtures.token, "host", "share", "method", "params", "rpcUrl", "chainId", "metadata", nil, isRaw: false
    )

    // then
    let decoded = try decodeSign(result)
    XCTAssertEqual(decoded.error?.id, "BAD_SHARE", "A body carrying an error id is decoded as-is.")
    XCTAssertEqual(decoded.error?.message, "m")
  }

  func test_MobilePresign_willKeepDecodedPortalError_when400WithBody() async throws {
    // given
    let spy = PortalRequestsSpy()
    spy.executeThrowableErrorSequence = [
      PortalRequestsError.clientError("400 - {\"id\":\"BAD_SHARE\",\"message\":\"m\"}", url: EnclaveFixtures.signUrl)
    ]
    let wrapper = makeWrapper(requests: spy)

    // and given
    let result = await wrapper.MobilePresign(EnclaveFixtures.token, "host", "share", "metadata", EnclaveFixtures.curve)

    // then
    let decoded = try decodePresign(result)
    XCTAssertEqual(decoded.error?.id, "BAD_SHARE")
    XCTAssertNil(decoded.id)
  }

  func test_MobileSign_willReturnSigningNetworkError_whenTransportThrowsURLError() async throws {
    // given
    let failing = PortalRequestsFailMock()
    let wrapper = makeWrapper(requests: failing)

    // and given
    let result = await wrapper.MobileSign(
      EnclaveFixtures.token, "host", "share", "method", "params", "rpcUrl", "chainId", "metadata", nil, isRaw: false
    )

    // then
    let decoded = try decodeSign(result)
    XCTAssertEqual(decoded.error?.id, "SIGNING_NETWORK_ERROR")
  }

  func test_MobileSign_willReturnInvalidParameters_beforeRequest_whenTokenNil() async throws {
    // given
    let spy = PortalRequestsSpy()
    let wrapper = makeWrapper(requests: spy)

    // and given
    let result = await wrapper.MobileSign(
      nil, "host", "share", "method", "params", "rpcUrl", "chainId", "metadata", nil, isRaw: false
    )

    // then
    let decoded = try decodeSign(result)
    XCTAssertEqual(decoded.error?.id, "INVALID_PARAMETERS")
    XCTAssertEqual(spy.executeCallsCount, 0, "Local validation must run before any network call.")
  }
}

// MARK: - The resolved token is forwarded as the bearer

extension EnclaveMobileWrapperTests {
  func test_MobileSign_willSendBearerHeader() async throws {
    // given
    let spy = try signingSpy()
    let wrapper = makeWrapper(requests: spy)

    // and given
    _ = await wrapper.MobileSign(
      EnclaveFixtures.token, "host", "share", "method", "params", "rpcUrl", "chainId", "metadata", nil, isRaw: false
    )

    // then
    XCTAssertEqual(try authorizationHeader(of: spy), "Bearer \(EnclaveFixtures.token)")
  }

  func test_MobileSign_raw_willSendBearerHeader() async throws {
    // given
    let spy = try signingSpy()
    let wrapper = makeWrapper(requests: spy)

    // and given
    _ = await wrapper.MobileSign(
      EnclaveFixtures.token, "host", "share", "method", "params", "rpcUrl", "chainId", "metadata",
      EnclaveFixtures.curve, isRaw: true
    )

    // then
    XCTAssertEqual(try authorizationHeader(of: spy), "Bearer \(EnclaveFixtures.token)")
  }

  func test_MobilePresign_willSendBearerHeader() async throws {
    // given
    let spy = try presigningSpy()
    let wrapper = makeWrapper(requests: spy)

    // and given
    _ = await wrapper.MobilePresign(EnclaveFixtures.token, "host", "share", "metadata", EnclaveFixtures.curve)

    // then
    XCTAssertEqual(try authorizationHeader(of: spy), "Bearer \(EnclaveFixtures.token)")
  }

  func test_MobileSignWithPresignature_willSendBearerHeader() async throws {
    // given
    let spy = try signingSpy()
    let wrapper = makeWrapper(requests: spy)

    // and given
    _ = await wrapper.MobileSignWithPresignature(
      EnclaveFixtures.token, "host", "share", "presig-data", "method", "params", "rpcUrl", "chainId", "metadata",
      nil, isRaw: false
    )

    // then
    XCTAssertEqual(try authorizationHeader(of: spy), "Bearer \(EnclaveFixtures.token)")
  }

  func test_MobileSignWithPresignature_raw_willSendBearerHeader() async throws {
    // given
    let spy = try signingSpy()
    let wrapper = makeWrapper(requests: spy)

    // and given
    _ = await wrapper.MobileSignWithPresignature(
      EnclaveFixtures.token, "host", "share", "presig-data", "method", "params", "rpcUrl", "chainId", "metadata",
      EnclaveFixtures.curve, isRaw: true
    )

    // then
    XCTAssertEqual(try authorizationHeader(of: spy), "Bearer \(EnclaveFixtures.token)")
  }

  func test_MobileSign_authFailedMessage_willNotContainToken() async throws {
    // given
    let secret = "enclave-secret"
    let spy = unauthorizedSpy()
    let wrapper = makeWrapper(requests: spy)

    // and given
    let result = await wrapper.MobileSign(
      secret, "host", "share", "method", "params", "rpcUrl", "chainId", "metadata", nil, isRaw: false
    )

    // then
    XCTAssertFalse(result.contains(secret), "The synthesised 401 result must never echo the bearer.")
    recordingLogger.assertNoSecret(secret)
  }
}

// MARK: - Idempotency-Key header

/// The enclave reads the idempotency key from the `Idempotency-Key` header on `POST /v1/sign`,
/// while `PortalMpcSigner` hands it over inside the signing metadata. These cases pin the
/// wrapper's half: the header is sent on both `/v1/sign` requests (normal and presignature) for
/// the three protected broadcasts only, to whichever Enclave host the wrapper was configured with,
/// never on a raw sign or a presign, never in place of `Authorization`, and the key never reaches
/// a log line.
/// They also pin that the enclave's bare idempotency error bodies decode into the server's id.
private enum IdempotencyFixtures {
  static let key = "idem-key-5b1c"
  static let protectedMethods = ["eth_sendTransaction", "sol_signAndSendTransaction", "sol_signAndConfirmTransaction"]
  /// Includes `sendTransaction` (`sol_sendTransaction`'s wire name, easily confused with a
  /// protected method) and a string that is no `PortalRequestMethod` at all.
  static let unprotectedMethods = [
    "personal_sign", "eth_signTransaction", "eth_signTypedData_v4", "sol_signMessage", "sol_signTransaction", "eth_sendRawTransaction",
    "sendTransaction", "unknown_sendTransaction"
  ]
  static let thirdPartyHost = "enclave.idempotency-third-party.example"
  static let customEnclaveHost = "enclave.custodian-idempotency.example"
  /// An IPv6 literal, which `PortalOwnedHosts.register(_:)` ignores, so it is never Portal-owned.
  static let unregistrableEnclaveHost = "[2001:db8::1]"
}

extension EnclaveMobileWrapperTests {
  /// Signing metadata as `PortalMpcSigner` serializes it, with `key` in `idempotencyKey`.
  private func idempotencyMetadata(key: String? = IdempotencyFixtures.key, isRaw: Bool? = nil) throws -> String {
    var metadata = MpcMetadata(clientPlatform: "NATIVE_IOS", mpcServerVersion: "v6")
    metadata.isRaw = isRaw
    metadata.reqId = "trace-123"
    metadata.idempotencyKey = key
    return try metadata.jsonString()
  }

  private func enclaveSign(_ wrapper: EnclaveMobileWrapper, method: String, metadata: String) async -> String {
    await wrapper.MobileSign(
      EnclaveFixtures.token, "host", "share", method, "params", "rpcUrl", "eip155:1", metadata, nil, isRaw: false
    )
  }

  private func enclaveSignWithPresignature(_ wrapper: EnclaveMobileWrapper, method: String, metadata: String) async -> String {
    await wrapper.MobileSignWithPresignature(
      EnclaveFixtures.token, "host", "share", "presig-data", method, "params", "rpcUrl", "eip155:1", metadata, nil, isRaw: false
    )
  }

  /// The `Idempotency-Key` header of the spy's last request under any casing, or `nil`.
  private func idempotencyKeyHeader(of spy: PortalRequestsSpy) -> String? {
    spy.executeRequestParam?.headers.first { $0.key.caseInsensitiveCompare(PORTAL_IDEMPOTENCY_KEY_HEADER) == .orderedSame }?.value
  }

  private func idempotencyWarnings() -> [String] {
    recordingLogger.messages(at: .warn).filter { $0.contains("idempotencyKey not sent") }
  }

  // MARK: Header sent

  func test_MobileSign_protectedMethods_willSendIdempotencyKeyHeader_nextToAuthorizationAndTrace() async throws {
    for method in IdempotencyFixtures.protectedMethods {
      let spy = try signingSpy()
      let wrapper = makeWrapper(requests: spy)

      let result = try await enclaveSign(wrapper, method: method, metadata: idempotencyMetadata())

      XCTAssertEqual(try decodeSign(result).data, "0xsignature", method)
      let request = try XCTUnwrap(spy.executeRequestParam, method)
      XCTAssertEqual(request.url.absoluteString, EnclaveFixtures.signUrl, method)
      XCTAssertEqual(request.headers[PORTAL_IDEMPOTENCY_KEY_HEADER], IdempotencyFixtures.key, method)
      XCTAssertEqual(request.headers["Authorization"], "Bearer \(EnclaveFixtures.token)", method)
      XCTAssertNotNil(request.headers[PORTAL_TRACE_ID_HEADER], method)
      XCTAssertNil((request.payload as? [String: String])?["presignature"], method)
    }
    XCTAssertTrue(idempotencyWarnings().isEmpty)
    recordingLogger.assertNoSecret(IdempotencyFixtures.key)
  }

  func test_MobileSignWithPresignature_protectedMethods_willSendIdempotencyKeyHeader_nextToAuthorizationAndTrace() async throws {
    for method in IdempotencyFixtures.protectedMethods {
      let spy = try signingSpy()
      let wrapper = makeWrapper(requests: spy)

      let result = try await enclaveSignWithPresignature(wrapper, method: method, metadata: idempotencyMetadata())

      XCTAssertEqual(try decodeSign(result).data, "0xsignature", method)
      let request = try XCTUnwrap(spy.executeRequestParam, method)
      XCTAssertEqual(request.url.absoluteString, EnclaveFixtures.signUrl, method)
      XCTAssertEqual(request.headers[PORTAL_IDEMPOTENCY_KEY_HEADER], IdempotencyFixtures.key, method)
      XCTAssertEqual(request.headers["Authorization"], "Bearer \(EnclaveFixtures.token)", method)
      XCTAssertNotNil(request.headers[PORTAL_TRACE_ID_HEADER], method)
      XCTAssertEqual((request.payload as? [String: String])?["presignature"], "presig-data", method)
    }
    recordingLogger.assertNoSecret(IdempotencyFixtures.key)
  }

  func test_MobileSign_idempotencyKeyHeader_willKeepTheKeyInMetadataStr() async throws {
    // The enclave ignores the unknown metadata field; the key travels in both places.
    let spy = try signingSpy()
    let metadata = try idempotencyMetadata()

    _ = await enclaveSign(makeWrapper(requests: spy), method: "eth_sendTransaction", metadata: metadata)

    XCTAssertEqual((spy.executeRequestParam?.payload as? [String: String])?["metadataStr"], metadata)
  }

  func test_MobileSign_keyWithSurroundingWhitespace_willSendTheTrimmedKey() async throws {
    let spy = try signingSpy()

    _ = try await enclaveSign(makeWrapper(requests: spy), method: "eth_sendTransaction", metadata: idempotencyMetadata(key: " \t\(IdempotencyFixtures.key)\n "))

    XCTAssertEqual(idempotencyKeyHeader(of: spy), IdempotencyFixtures.key)
  }

  func test_MobileSign_idempotencyKeyHeader_cannotDisplaceAuthorization() async throws {
    let spy = try signingSpy()

    _ = try await enclaveSign(makeWrapper(requests: spy), method: "eth_sendTransaction", metadata: idempotencyMetadata())

    let headers = try XCTUnwrap(spy.executeRequestParam?.headers)
    let authorizationHeaders = headers.filter { $0.key.caseInsensitiveCompare("Authorization") == .orderedSame }
    XCTAssertEqual(authorizationHeaders, ["Authorization": "Bearer \(EnclaveFixtures.token)"])
    XCTAssertEqual(headers["Content-Type"], "application/json")
    XCTAssertEqual(spy.bearerTokensSent, [EnclaveFixtures.token])
  }

  // MARK: Header not sent

  func test_MobileSign_andMobileSignWithPresignature_withoutKey_willNotSendHeader() async throws {
    for metadata in try [idempotencyMetadata(key: nil), "{}", "{\"idempotencyKey\":null}"] {
      let signSpy = try signingSpy()
      _ = await enclaveSign(makeWrapper(requests: signSpy), method: "eth_sendTransaction", metadata: metadata)
      XCTAssertNil(idempotencyKeyHeader(of: signSpy), metadata)

      let presignatureSpy = try signingSpy()
      _ = await enclaveSignWithPresignature(makeWrapper(requests: presignatureSpy), method: "eth_sendTransaction", metadata: metadata)
      XCTAssertNil(idempotencyKeyHeader(of: presignatureSpy), metadata)
    }
    XCTAssertTrue(idempotencyWarnings().isEmpty, "Nothing was dropped, so nothing is reported.")
  }

  func test_MobileSign_andMobileSignWithPresignature_withNonJsonMetadata_willNotSendHeader() async throws {
    for metadata in ["metadata", "", "[\"idempotencyKey\"]", "{\"idempotencyKey\":42}"] {
      let signSpy = try signingSpy()
      let signResult = await enclaveSign(makeWrapper(requests: signSpy), method: "eth_sendTransaction", metadata: metadata)
      XCTAssertEqual(signSpy.executeCallsCount, 1, "Unreadable metadata must not stop the request: \(metadata)")
      XCTAssertEqual(try decodeSign(signResult).data, "0xsignature", metadata)
      XCTAssertNil(idempotencyKeyHeader(of: signSpy), metadata)

      let presignatureSpy = try signingSpy()
      _ = await enclaveSignWithPresignature(makeWrapper(requests: presignatureSpy), method: "eth_sendTransaction", metadata: metadata)
      XCTAssertEqual(presignatureSpy.executeCallsCount, 1, metadata)
      XCTAssertNil(idempotencyKeyHeader(of: presignatureSpy), metadata)
    }
  }

  func test_MobileSign_whitespaceOnlyKey_willNotSendHeader() async throws {
    let spy = try signingSpy()

    _ = try await enclaveSign(makeWrapper(requests: spy), method: "eth_sendTransaction", metadata: idempotencyMetadata(key: " \u{00A0}\t"))

    XCTAssertNil(idempotencyKeyHeader(of: spy))
    XCTAssertTrue(idempotencyWarnings().isEmpty)
  }

  func test_rawSign_withKeyInMetadata_willNotSendHeader_onEitherRawEndpoint() async throws {
    let metadata = try idempotencyMetadata(isRaw: true)

    let rawSpy = try signingSpy()
    _ = await makeWrapper(requests: rawSpy).MobileSign(
      EnclaveFixtures.token, "host", "share", "eth_sendTransaction", "74657374", "", "", metadata, EnclaveFixtures.curve, isRaw: true
    )
    XCTAssertEqual(rawSpy.executeRequestParam?.url.absoluteString, "https://\(EnclaveFixtures.host)/v1/raw/sign/SECP256K1")
    XCTAssertNil(idempotencyKeyHeader(of: rawSpy))

    let rawPresignatureSpy = try signingSpy()
    _ = await makeWrapper(requests: rawPresignatureSpy).MobileSignWithPresignature(
      EnclaveFixtures.token, "host", "share", "presig-data", "eth_sendTransaction", "74657374", "", "", metadata, EnclaveFixtures.curve, isRaw: true
    )
    XCTAssertEqual(rawPresignatureSpy.executeRequestParam?.url.absoluteString, "https://\(EnclaveFixtures.host)/v1/raw/sign/SECP256K1")
    XCTAssertNil(idempotencyKeyHeader(of: rawPresignatureSpy))

    XCTAssertTrue(idempotencyWarnings().isEmpty)
    recordingLogger.assertNoSecret(IdempotencyFixtures.key)
  }

  func test_MobilePresign_willNotSendHeader_evenWhenMetadataCarriesAKey() async throws {
    let spy = try presigningSpy()

    _ = try await makeWrapper(requests: spy).MobilePresign(EnclaveFixtures.token, "host", "share", idempotencyMetadata(), EnclaveFixtures.curve)

    XCTAssertEqual(spy.executeRequestParam?.url.absoluteString, "https://\(EnclaveFixtures.host)/v1/presign/SECP256K1")
    XCTAssertNil(idempotencyKeyHeader(of: spy))
  }

  func test_unprotectedMethods_withKey_willNotSendHeader_andWarnWithoutTheKey() async throws {
    for method in IdempotencyFixtures.unprotectedMethods {
      recordingLogger.reset()

      let signSpy = try signingSpy()
      _ = try await enclaveSign(makeWrapper(requests: signSpy), method: method, metadata: idempotencyMetadata())
      XCTAssertEqual(signSpy.executeCallsCount, 1, method)
      XCTAssertNil(idempotencyKeyHeader(of: signSpy), "The enclave rejects a key on \(method) with HTTP 400.")

      let presignatureSpy = try signingSpy()
      _ = try await enclaveSignWithPresignature(makeWrapper(requests: presignatureSpy), method: method, metadata: idempotencyMetadata())
      XCTAssertNil(idempotencyKeyHeader(of: presignatureSpy), method)

      let warnings = idempotencyWarnings()
      XCTAssertEqual(warnings.count, 2, "One warning per request: \(warnings)")
      XCTAssertTrue(warnings.allSatisfy { $0.hasSuffix("not \(method)") }, "\(warnings)")
      recordingLogger.assertNoSecret(IdempotencyFixtures.key)
    }
  }

  func test_anyConfiguredEnclaveHost_withKey_willSendHeader_onBothSignRequests_andNotWarn() async throws {
    // The configured Enclave host already receives the bearer credential, so the key goes there
    // whether or not the host is Portal-owned, the same rule as Android.
    PortalOwnedHosts.register(IdempotencyFixtures.customEnclaveHost)
    XCTAssertFalse(isPortalOwnedUrl("https://\(IdempotencyFixtures.thirdPartyHost)/v1/sign"))
    XCTAssertTrue(isPortalOwnedUrl("https://\(IdempotencyFixtures.customEnclaveHost)/v1/sign"))

    for host in [IdempotencyFixtures.thirdPartyHost, IdempotencyFixtures.customEnclaveHost] {
      let signSpy = try signingSpy()
      _ = try await enclaveSign(
        makeWrapper(requests: signSpy, enclaveMPCHost: host),
        method: "eth_sendTransaction",
        metadata: idempotencyMetadata()
      )
      XCTAssertEqual(signSpy.executeRequestParam?.url.absoluteString, "https://\(host)/v1/sign", host)
      XCTAssertEqual(idempotencyKeyHeader(of: signSpy), IdempotencyFixtures.key, host)
      XCTAssertEqual(signSpy.bearerTokensSent, [EnclaveFixtures.token], host)

      let presignatureSpy = try signingSpy()
      _ = try await enclaveSignWithPresignature(
        makeWrapper(requests: presignatureSpy, enclaveMPCHost: host),
        method: "sol_signAndSendTransaction",
        metadata: idempotencyMetadata()
      )
      XCTAssertEqual(idempotencyKeyHeader(of: presignatureSpy), IdempotencyFixtures.key, host)
    }

    XCTAssertTrue(idempotencyWarnings().isEmpty, "\(idempotencyWarnings())")
    recordingLogger.assertNoSecret(IdempotencyFixtures.key)
  }

  func test_enclaveHostTheRegistryIgnores_withKey_keepsTheHeaderOnTheWire_butNotTheTraceHeader() async throws {
    // `Portal.init` registers `enclaveMPCHost`, but the registry ignores an IPv6 literal. The
    // request still carries the key there; only the trace header stays Portal-only.
    PortalOwnedHosts.register(IdempotencyFixtures.unregistrableEnclaveHost)
    XCTAssertFalse(isPortalOwnedUrl("https://\(IdempotencyFixtures.unregistrableEnclaveHost)/v1/sign"))
    MockURLProtocol.reset()
    let session = MockURLProtocol.makeSession()
    defer {
      session.invalidateAndCancel()
      MockURLProtocol.reset()
    }
    MockURLProtocol.respond(status: 200, body: #"{"data":"0xsignature"}"#)
    let wrapper = makeWrapper(requests: PortalRequests(urlSession: session), enclaveMPCHost: IdempotencyFixtures.unregistrableEnclaveHost)

    let result = try await enclaveSign(wrapper, method: "eth_sendTransaction", metadata: idempotencyMetadata())

    XCTAssertEqual(try decodeSign(result).data, "0xsignature")
    let recorded = try XCTUnwrap(MockURLProtocol.lastRequest)
    XCTAssertEqual(recorded.url?.absoluteString, "https://\(IdempotencyFixtures.unregistrableEnclaveHost)/v1/sign")
    XCTAssertEqual(recorded.value(forHTTPHeaderField: PORTAL_IDEMPOTENCY_KEY_HEADER), IdempotencyFixtures.key)
    XCTAssertEqual(recorded.value(forHTTPHeaderField: "Authorization"), "Bearer \(EnclaveFixtures.token)")
    XCTAssertNil(recorded.value(forHTTPHeaderField: PORTAL_TRACE_ID_HEADER))
    XCTAssertTrue(idempotencyWarnings().isEmpty, "\(idempotencyWarnings())")
    recordingLogger.assertNoSecret(IdempotencyFixtures.key)
  }

  func test_registeredCustomEnclaveHost_overTheRealTransport_keepsTheHeaderOnTheWire() async throws {
    PortalOwnedHosts.register(IdempotencyFixtures.customEnclaveHost)
    MockURLProtocol.reset()
    let session = MockURLProtocol.makeSession()
    defer {
      session.invalidateAndCancel()
      MockURLProtocol.reset()
    }
    MockURLProtocol.respond(status: 200, body: #"{"data":"0xsignature"}"#)
    let wrapper = makeWrapper(requests: PortalRequests(urlSession: session), enclaveMPCHost: IdempotencyFixtures.customEnclaveHost)

    let result = try await enclaveSign(wrapper, method: "eth_sendTransaction", metadata: idempotencyMetadata())

    XCTAssertEqual(try decodeSign(result).data, "0xsignature")
    let recorded = try XCTUnwrap(MockURLProtocol.lastRequest)
    XCTAssertEqual(recorded.url?.host, IdempotencyFixtures.customEnclaveHost)
    XCTAssertEqual(recorded.value(forHTTPHeaderField: PORTAL_IDEMPOTENCY_KEY_HEADER), IdempotencyFixtures.key)
    recordingLogger.assertNoSecret(IdempotencyFixtures.key)
  }

  func test_nonPortalHost_withoutKey_willNotWarn() async throws {
    let spy = try signingSpy()

    _ = try await enclaveSign(
      makeWrapper(requests: spy, enclaveMPCHost: IdempotencyFixtures.thirdPartyHost),
      method: "eth_sendTransaction",
      metadata: idempotencyMetadata(key: nil)
    )

    XCTAssertTrue(idempotencyWarnings().isEmpty)
  }

  // MARK: Idempotency error bodies

  /// The bare body the enclave answers an idempotency conflict with, and the status it uses.
  private static let idempotencyErrorResponses: [(status: Int, id: String)] = [
    (409, PortalIdempotencyErrorId.requestInProgress),
    (409, PortalIdempotencyErrorId.requestAlreadyCompleted),
    (409, PortalIdempotencyErrorId.requestPreviouslyFailed),
    (409, PortalIdempotencyErrorId.requestUnexpectedState),
    (422, PortalIdempotencyErrorId.keyReused),
    (400, PortalIdempotencyErrorId.txMissing)
  ]

  private func enclaveErrorSpy(status: Int, id: String, message: String) -> PortalRequestsSpy {
    let spy = PortalRequestsSpy()
    let body = #"{"id":"\#(id)","message":"\#(message)","code":216}"#
    spy.executeThrowableErrorSequence = [PortalRequestsError.clientError("\(status) - \(body)", url: EnclaveFixtures.signUrl)]
    return spy
  }

  func test_MobileSign_idempotencyErrorBodies_willDecodeIntoTheServerIdAndFullMessage() async throws {
    for (status, id) in Self.idempotencyErrorResponses {
      let message = "Idempotent request - \(id) - rejected"
      let spy = enclaveErrorSpy(status: status, id: id, message: message)

      let result = try await enclaveSign(makeWrapper(requests: spy), method: "eth_sendTransaction", metadata: idempotencyMetadata())

      let decoded = try decodeSign(result)
      XCTAssertEqual(decoded.error?.id, id, "\(status)")
      XCTAssertEqual(decoded.error?.message, message, "A message containing ' - ' must survive whole (\(status)).")
      XCTAssertNil(decoded.data)
      XCTAssertEqual(spy.executeCallsCount, 1)
      XCTAssertFalse(result.contains(IdempotencyFixtures.key))
    }
    recordingLogger.assertNoSecret(IdempotencyFixtures.key)
  }

  func test_MobileSignWithPresignature_idempotencyErrorBodies_willDecodeIntoTheServerId() async throws {
    for (status, id) in Self.idempotencyErrorResponses {
      let spy = enclaveErrorSpy(status: status, id: id, message: "a - b")

      let result = try await enclaveSignWithPresignature(makeWrapper(requests: spy), method: "eth_sendTransaction", metadata: idempotencyMetadata())

      let decoded = try decodeSign(result)
      XCTAssertEqual(decoded.error?.id, id, "\(status)")
      XCTAssertEqual(decoded.error?.message, "a - b", "\(status)")
    }
  }

  func test_MobileSign_badRequestBody_withSeparatorInMessage_willDecodeIntoBadRequest() async throws {
    let message = #"Idempotency-Key is not supported for method \"personal_sign\"; only transaction-broadcasting methods support idempotency - see docs"#
    let spy = PortalRequestsSpy()
    spy.executeThrowableErrorSequence = [
      PortalRequestsError.clientError(#"400 - {"id":"BAD_REQUEST","message":"\#(message)","code":201}"#, url: EnclaveFixtures.signUrl)
    ]

    let result = try await enclaveSign(makeWrapper(requests: spy), method: "eth_sendTransaction", metadata: idempotencyMetadata())

    let decoded = try decodeSign(result)
    XCTAssertEqual(decoded.error?.id, "BAD_REQUEST")
    XCTAssertTrue(decoded.error?.message?.hasSuffix(" - see docs") == true, decoded.error?.message ?? "nil")
  }

  func test_MobileSign_overTheRealTransport_sendsTheHeaderOnTheWire_andDecodesA409Body() async throws {
    MockURLProtocol.reset()
    let session = MockURLProtocol.makeSession()
    defer {
      session.invalidateAndCancel()
      MockURLProtocol.reset()
    }
    let body = #"{"id":"IDEMPOTENT_REQUEST_ALREADY_COMPLETED","message":"Idempotent request - already completed successfully","code":216}"#
    MockURLProtocol.respond(status: 409, body: body)
    let wrapper = makeWrapper(requests: PortalRequests(urlSession: session))

    let result = try await enclaveSign(wrapper, method: "eth_sendTransaction", metadata: idempotencyMetadata())

    let recorded = try XCTUnwrap(MockURLProtocol.lastRequest)
    XCTAssertEqual(recorded.url?.absoluteString, EnclaveFixtures.signUrl)
    XCTAssertEqual(recorded.value(forHTTPHeaderField: PORTAL_IDEMPOTENCY_KEY_HEADER), IdempotencyFixtures.key)
    XCTAssertEqual(recorded.value(forHTTPHeaderField: "Authorization"), "Bearer \(EnclaveFixtures.token)")
    XCTAssertNotNil(recorded.value(forHTTPHeaderField: PORTAL_TRACE_ID_HEADER))
    let decoded = try decodeSign(result)
    XCTAssertEqual(decoded.error?.id, PortalIdempotencyErrorId.requestAlreadyCompleted)
    XCTAssertEqual(decoded.error?.message, "Idempotent request - already completed successfully")
    recordingLogger.assertNoSecret(IdempotencyFixtures.key)
  }

  func test_generatePreGeneratedShares_willNotSendIdempotencyKeyHeader_evenWhenMetadataCarriesAKey() async throws {
    // `/v1/generate` is not a broadcast; only `/v1/sign` may carry the header.
    let spy = PortalRequestsSpy()
    let api = PortalApi(credentials: MockConstants.mockCredentials, requests: spy)
    let metadata = try idempotencyMetadata()

    _ = try? await api.generatePreGeneratedShares(metadataStr: metadata)

    let request = try XCTUnwrap(spy.executeRequestParam)
    XCTAssertTrue(request.url.absoluteString.hasSuffix("/v1/generate"), request.url.absoluteString)
    XCTAssertFalse(request.headers.keys.contains { $0.caseInsensitiveCompare(PORTAL_IDEMPOTENCY_KEY_HEADER) == .orderedSame })
  }
}

// MARK: - Error responses without an error id

/// An error response whose body carries no error `id`, such as a page from a proxy in front of the
/// enclave, becomes a `SIGNING_NETWORK_ERROR` that keeps the HTTP status in its message on all four
/// sign requests, so the signer throws a `PortalMpcError` instead of reporting a missing signature.
/// The 409 / 422 bodies are the ones Android's `MpcSignerEnclaveIdempotencyTest` pins.
extension EnclaveMobileWrapperTests {
  private static let errorBodiesWithoutAnId: [(status: Int, body: String)] = [
    (409, "<html><body>409 Conflict</body></html>"),
    (409, "Conflict"),
    (422, ""),
    (422, #"{"message":"Unprocessable"}"#),
    (500, "oops"),
    (503, #"{"message":"down","code":500}"#)
  ]

  /// The error `PortalRequests` throws for `status` and `body`.
  private func transportError(status: Int, body: String) -> PortalRequestsError {
    status < 500
      ? .clientError("\(status) - \(body)", url: EnclaveFixtures.signUrl)
      : .internalServerError("\(status) - \(body)", url: EnclaveFixtures.signUrl)
  }

  /// The four sign requests, each with valid parameters.
  private func signRequests() throws -> [(name: String, sign: (EnclaveMobileWrapper) async -> String)] {
    let metadata = try idempotencyMetadata()
    let rawMetadata = try idempotencyMetadata(key: nil, isRaw: true)
    return [
      ("MobileSign", { await $0.MobileSign(EnclaveFixtures.token, "host", "share", "eth_sendTransaction", "params", "rpcUrl", "eip155:1", metadata, nil, isRaw: false) }),
      ("MobileSign raw", { await $0.MobileSign(EnclaveFixtures.token, "host", "share", nil, "74657374", "", "", rawMetadata, EnclaveFixtures.curve, isRaw: true) }),
      ("MobileSignWithPresignature", { await $0.MobileSignWithPresignature(EnclaveFixtures.token, "host", "share", "presig-data", "eth_sendTransaction", "params", "rpcUrl", "eip155:1", metadata, nil, isRaw: false) }),
      ("MobileSignWithPresignature raw", { await $0.MobileSignWithPresignature(EnclaveFixtures.token, "host", "share", "presig-data", nil, "74657374", "", "", rawMetadata, EnclaveFixtures.curve, isRaw: true) })
    ]
  }

  func test_signRequests_errorBodyWithoutAnId_willReturnSigningNetworkError_withTheStatusAndBody() async throws {
    for (name, sign) in try signRequests() {
      for (status, body) in Self.errorBodiesWithoutAnId {
        let spy = PortalRequestsSpy()
        spy.executeThrowableErrorSequence = [transportError(status: status, body: body)]

        let result = await sign(makeWrapper(requests: spy))

        let decoded = try decodeSign(result)
        XCTAssertEqual(decoded.error?.id, "SIGNING_NETWORK_ERROR", "\(name) \(status) [\(body)]")
        XCTAssertEqual(decoded.error?.message, "\(status) - \(body)", "\(name) \(status)")
        XCTAssertNil(decoded.data, "\(name) \(status)")
        XCTAssertEqual(spy.executeCallsCount, 1, "\(name) \(status)")
        XCTAssertFalse(result.contains(IdempotencyFixtures.key), "\(name) \(status)")
      }
    }
    recordingLogger.assertNoSecret(IdempotencyFixtures.key)
  }

  func test_signRequests_401_keepTheirResultWithNoError() async throws {
    // A 401's body is discarded by the transport; see `PortalMpcError.isAuthFailure`.
    for (name, sign) in try signRequests() {
      let result = await sign(makeWrapper(requests: unauthorizedSpy()))

      let decoded = try decodeSign(result)
      XCTAssertNil(decoded.error, name)
      XCTAssertNil(decoded.data, name)
    }
  }

  func test_MobileSign_overTheRealTransport_a409HtmlBodyAndA422EmptyBody_returnSigningNetworkError_withTheStatus() async throws {
    for (status, body) in [(409, "<html><body>409 Conflict</body></html>"), (422, "")] {
      MockURLProtocol.reset()
      let session = MockURLProtocol.makeSession()
      defer {
        session.invalidateAndCancel()
        MockURLProtocol.reset()
      }
      MockURLProtocol.respond(status: status, body: body)
      let wrapper = makeWrapper(requests: PortalRequests(urlSession: session))

      let result = try await enclaveSign(wrapper, method: "eth_sendTransaction", metadata: idempotencyMetadata())

      let decoded = try decodeSign(result)
      XCTAssertEqual(decoded.error?.id, "SIGNING_NETWORK_ERROR", "\(status)")
      XCTAssertEqual(decoded.error?.message, "\(status) - \(body)", "\(status)")
      XCTAssertEqual(MockURLProtocol.recordedRequests.count, 1, "\(status)")
      XCTAssertEqual(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: PORTAL_IDEMPOTENCY_KEY_HEADER), IdempotencyFixtures.key, "\(status)")
      XCTAssertFalse(result.contains(IdempotencyFixtures.key), "\(status)")
    }
    recordingLogger.assertNoSecret(IdempotencyFixtures.key)
  }

  func test_MobileSign_overTheRealTransport_aNonHttpResponse_returnsSigningNetworkError() async throws {
    MockURLProtocol.reset()
    let session = MockURLProtocol.makeSession()
    defer {
      session.invalidateAndCancel()
      MockURLProtocol.reset()
    }
    MockURLProtocol.respondWithNonHttpResponse()
    let wrapper = makeWrapper(requests: PortalRequests(urlSession: session))

    let result = try await enclaveSign(wrapper, method: "eth_sendTransaction", metadata: idempotencyMetadata())

    let decoded = try decodeSign(result)
    XCTAssertEqual(decoded.error?.id, "SIGNING_NETWORK_ERROR")
    XCTAssertEqual(decoded.error?.message, PortalRequestsError.couldNotParseHttpResponse.localizedDescription)
    XCTAssertFalse(decoded.error?.message?.isEmpty ?? true)
    XCTAssertNil(decoded.data)
  }

  func test_signRequests_redirectErrorWithoutAnId_willReturnSigningNetworkError_withTheStatusAndBody() async throws {
    // A 3xx that URLSession does not follow (a 304, or no Location) reaches the wrapper as a
    // redirect error.
    for (name, sign) in try signRequests() {
      let spy = PortalRequestsSpy()
      spy.executeThrowableErrorSequence = [PortalRequestsError.redirectError("304 - <html/>")]

      let result = await sign(makeWrapper(requests: spy))

      let decoded = try decodeSign(result)
      XCTAssertEqual(decoded.error?.id, "SIGNING_NETWORK_ERROR", name)
      XCTAssertEqual(decoded.error?.message, "304 - <html/>", name)
      XCTAssertNil(decoded.data, name)
      XCTAssertEqual(spy.executeCallsCount, 1, name)
    }
  }

  func test_signRequests_redirectErrorWithAnId_willPassTheIdThrough() async throws {
    for (name, sign) in try signRequests() {
      let spy = PortalRequestsSpy()
      spy.executeThrowableErrorSequence = [
        PortalRequestsError.redirectError(#"302 - {"id":"IDEMPOTENT_REQUEST_IN_PROGRESS","message":"m"}"#)
      ]

      let result = await sign(makeWrapper(requests: spy))

      let decoded = try decodeSign(result)
      XCTAssertEqual(decoded.error?.id, PortalIdempotencyErrorId.requestInProgress, name)
      XCTAssertEqual(decoded.error?.message, "m", name)
      XCTAssertNil(decoded.data, name)
    }
  }

  func test_signRequests_longErrorBodyWithoutAnId_willKeepOnlyTheStartOfTheMessage() async throws {
    // A proxy page can run to several KB, and the signer logs this message when a presignature
    // sign fails, so only its start is kept.
    let limit = EnclaveMobileWrapper.signingNetworkErrorMessageLimit
    let longBody = "<html>" + String(repeating: "x", count: 10000) + "TAIL-MARKER</html>"
    let bodyAtTheLimit = String(repeating: "y", count: limit - "502 - ".count)
    let bodyOverTheLimit = bodyAtTheLimit + "z"
    for (name, sign) in try signRequests() {
      for (body, expectedMessage) in [
        (longBody, String("502 - \(longBody)".prefix(limit)) + "… (truncated)"),
        (bodyAtTheLimit, "502 - \(bodyAtTheLimit)"),
        (bodyOverTheLimit, "502 - \(bodyAtTheLimit)… (truncated)")
      ] {
        let spy = PortalRequestsSpy()
        spy.executeThrowableErrorSequence = [transportError(status: 502, body: body)]

        let result = await sign(makeWrapper(requests: spy))

        let decoded = try decodeSign(result)
        XCTAssertEqual(decoded.error?.id, "SIGNING_NETWORK_ERROR", "\(name) \(body.count)")
        XCTAssertEqual(decoded.error?.message, expectedMessage, "\(name) \(body.count)")
        XCTAssertFalse(result.contains("TAIL-MARKER"), "\(name) \(body.count)")
      }
    }
  }
}
