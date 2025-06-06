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
    let resultTransactionHash = await enclaveMobileWrapper?.MobileSign("", "", "", "", "", "", "", "")

    // then
    AssertJSONEqual(resultTransactionHash, expectedReturnValue)
  }

  func test_MobileSign_willCall_executeRequest_onlyOnce() async {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initEnclaveMobileWrapper(portalRequests: portalRequestsSpy)

    // and given
    _ = await enclaveMobileWrapper?.MobileSign("", "", "", "", "", "", "", "")

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
    _ = await enclaveMobileWrapper?.MobileSign(apiKey, host, signingShare, method, params, rpcUrl, chainId, metadata)

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

  func test_MobileSign_willReturn_correctError_forInvalidParams() async {
    // given
    initEnclaveMobileWrapper()
    let invalidParamsReturnValue = "{\"error\":{\"id\":\"INVALID_PARAMETERS\",\"message\":\"Invalid parameters provided\"}}"

    // and given
    var result = await enclaveMobileWrapper?.MobileSign(nil, "", "", "", "", "", "", "")
    // then
    AssertJSONEqual(result, invalidParamsReturnValue)

    // and given
    result = await enclaveMobileWrapper?.MobileSign("", "", nil, "", "", "", "", "")
    // then
    AssertJSONEqual(result, invalidParamsReturnValue)

    // and given
    result = await enclaveMobileWrapper?.MobileSign("", "", "", nil, "", "", "", "")
    // then
    AssertJSONEqual(result, invalidParamsReturnValue)

    // and given
    result = await enclaveMobileWrapper?.MobileSign("", "", "", "", nil, "", "", "")
    // then
    AssertJSONEqual(result, invalidParamsReturnValue)

    // and given
    result = await enclaveMobileWrapper?.MobileSign("", "", "", "", "", nil, "", "")
    // then
    AssertJSONEqual(result, invalidParamsReturnValue)

    // and given
    result = await enclaveMobileWrapper?.MobileSign("", "", "", "", "", "", nil, "")
    // then
    AssertJSONEqual(result, invalidParamsReturnValue)

    // and given
    result = await enclaveMobileWrapper?.MobileSign("", "", "", "", "", "", "", nil)
    // then
    AssertJSONEqual(result, invalidParamsReturnValue)
  }

  func test_MobileSign_willReturn_correctError_whenExecuteRequestThrowError() async {
    // given
    let portalRequestsFailMock = PortalRequestsFailMock()
    initEnclaveMobileWrapper(portalRequests: portalRequestsFailMock)
    let expectedReturnValue = "{\"error\":{\"id\":\"SIGNING_NETWORK_ERROR\",\"message\":\"\(portalRequestsFailMock.errorToThrow.localizedDescription)\"}}"

    // and given
    let result = await enclaveMobileWrapper?.MobileSign("", "", "", "", "", "", "", "")

    // then
    AssertJSONEqual(result, expectedReturnValue)
  }
}
