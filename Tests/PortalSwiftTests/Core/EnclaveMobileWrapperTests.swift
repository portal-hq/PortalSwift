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
    recordingLogger = RecordingLogger()
    recordingLogger.install()
  }

  override func tearDownWithError() throws {
    recordingLogger.uninstall()
    CredentialInvalidationRegistry.shared.resetForTesting()
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

// MARK: - Non-401 failures keep their existing behaviour

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
    XCTAssertEqual(decoded.error?.id, "BAD_SHARE", "Only a 401 is remapped; every other body is still decoded as-is.")
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

  func test_MobileSign_willReturnNullError_when500WithoutParsableBody() async throws {
    // given
    let spy = PortalRequestsSpy()
    spy.executeThrowableErrorSequence = [
      PortalRequestsError.internalServerError("500 - oops", url: EnclaveFixtures.signUrl)
    ]
    let wrapper = makeWrapper(requests: spy)

    // and given
    let result = await wrapper.MobileSign(
      EnclaveFixtures.token, "host", "share", "method", "params", "rpcUrl", "chainId", "metadata", nil, isRaw: false
    )

    // then
    let decoded = try decodeSign(result)
    XCTAssertNil(decoded.data, "Today's behaviour for an unparsable non-401 body is retained.")
    XCTAssertNil(decoded.error, "Today's behaviour for an unparsable non-401 body is retained.")
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
