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

  override func setUpWithError() throws {}

  override func tearDownWithError() throws {
    enclaveMobileWrapper = nil
  }
}

// MARK: - Test Helpers

extension EnclaveMobileWrapperTests {
  func initEnclaveMobileWrapper(
    portalRequests: PortalRequestsProtocol = PortalRequestsSpy()
  ) {
    enclaveMobileWrapper = EnclaveMobileWrapper(requests: portalRequests)
  }
}

// MARK: - MobileSign tests

extension EnclaveMobileWrapperTests {
  func test_MobileSign_willCall_requestPost_onlyOnce() async {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initEnclaveMobileWrapper(portalRequests: portalRequestsSpy)

    // and given
    _ = await enclaveMobileWrapper?.MobileSign("", "", "", "", "", "", "", "")

    // then
    XCTAssertEqual(portalRequestsSpy.postCallsCount, 1)
  }

  func test_MobileSign_willCall_requestPost_passingCorrectParams() async {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initEnclaveMobileWrapper(portalRequests: portalRequestsSpy)

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
    XCTAssertEqual(portalRequestsSpy.postFromParam?.absoluteString ?? "", "https://mpc-client.portalhq.io/v1/sign")
    XCTAssertEqual(portalRequestsSpy.postAndPayloadParam as? [String: String] ?? [:], [
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
    AssertJSONEQual(result, invalidParamsReturnValue)

    // and given
    result = await enclaveMobileWrapper?.MobileSign("", "", nil, "", "", "", "", "")
    // then
    AssertJSONEQual(result, invalidParamsReturnValue)

    // and given
    result = await enclaveMobileWrapper?.MobileSign("", "", "", nil, "", "", "", "")
    // then
    AssertJSONEQual(result, invalidParamsReturnValue)

    // and given
    result = await enclaveMobileWrapper?.MobileSign("", "", "", "", nil, "", "", "")
    // then
    AssertJSONEQual(result, invalidParamsReturnValue)

    // and given
    result = await enclaveMobileWrapper?.MobileSign("", "", "", "", "", nil, "", "")
    // then
    AssertJSONEQual(result, invalidParamsReturnValue)

    // and given
    result = await enclaveMobileWrapper?.MobileSign("", "", "", "", "", "", nil, "")
    // then
    AssertJSONEQual(result, invalidParamsReturnValue)

    // and given
    result = await enclaveMobileWrapper?.MobileSign("", "", "", "", "", "", "", nil)
    // then
    AssertJSONEQual(result, invalidParamsReturnValue)
  }

  func test_MobileSign_willReturn_correctError_whenRequestPostThrowError() async {
    // given
    let portalRequestsFailMock = PortalRequestsFailMock()
    initEnclaveMobileWrapper(portalRequests: portalRequestsFailMock)
    let expectedReturnValue = "{\"error\":{\"id\":\"SIGNING_NETWORK_ERROR\",\"message\":\"\(portalRequestsFailMock.errorToThrow.localizedDescription)\"}}"

    // and given
    let result = await enclaveMobileWrapper?.MobileSign("", "", "", "", "", "", "", "")

    // then
    AssertJSONEQual(result, expectedReturnValue)
  }
}
