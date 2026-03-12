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

  override func setUpWithError() throws {}

  override func tearDownWithError() throws {
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
