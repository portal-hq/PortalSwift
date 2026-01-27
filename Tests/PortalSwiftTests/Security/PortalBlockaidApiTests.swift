//
//  PortalBlockaidApiTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import XCTest
@testable import PortalSwift

final class PortalBlockaidApiTests: XCTestCase {

  private var requestsSpy: PortalRequestsSpy!
  private var sut: PortalBlockaidApi!
  let testApiKey = "test-api-key"
  let encoder = JSONEncoder()

  // MARK: - Setup & Teardown

  override func setUpWithError() throws {
    try super.setUpWithError()
    requestsSpy = PortalRequestsSpy()
    sut = PortalBlockaidApi(
      apiKey: testApiKey,
      apiHost: "api.portalhq.io",
      requests: requestsSpy
    )
  }

  override func tearDownWithError() throws {
    requestsSpy = nil
    sut = nil
    try super.tearDownWithError()
  }

  private func setReturnValue<T: Encodable>(_ value: T) throws {
    requestsSpy.returnData = try encoder.encode(value)
  }

  // MARK: - Initialization Tests

  func testInit_productionHost_usesHttps() {
    let api = PortalBlockaidApi(apiKey: "key", apiHost: "api.portalhq.io")
    XCTAssertNotNil(api)
  }

  func testInit_localhost_usesHttp() async throws {
    let localSut = PortalBlockaidApi(
      apiKey: "test-key",
      apiHost: "localhost:3000",
      requests: requestsSpy
    )

    try setReturnValue(BlockaidScanEVMResponse(data: nil, error: nil))
    let request = BlockaidScanEVMRequest.stub()
    _ = try? await localSut.scanEVMTx(request: request)

    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertTrue(portalRequest?.url.absoluteString.starts(with: "http://") ?? false)
  }

  // MARK: - scanEVMTx Tests

  func testScanEVMTx_buildsCorrectUrl() async throws {
    try setReturnValue(BlockaidScanEVMResponse(data: nil, error: nil))
    let request = BlockaidScanEVMRequest.stub()

    _ = try await sut.scanEVMTx(request: request)

    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let expectedUrl = "https://api.portalhq.io/api/v3/clients/me/integrations/blockaid/evm/scan"
    XCTAssertEqual(portalRequest?.url.absoluteString, expectedUrl)
  }

  func testScanEVMTx_usesPostMethod() async throws {
    try setReturnValue(BlockaidScanEVMResponse(data: nil, error: nil))
    let request = BlockaidScanEVMRequest.stub()

    _ = try await sut.scanEVMTx(request: request)

    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.method, .post)
  }

  func testScanEVMTx_includesBearerToken() async throws {
    try setReturnValue(BlockaidScanEVMResponse(data: nil, error: nil))
    let request = BlockaidScanEVMRequest.stub()

    _ = try await sut.scanEVMTx(request: request)

    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.headers["Authorization"], "Bearer \(testApiKey)")
  }

  func testScanEVMTx_serializesRequestPayload() async throws {
    try setReturnValue(BlockaidScanEVMResponse(data: nil, error: nil))
    let request = BlockaidScanEVMRequest.stub()

    _ = try await sut.scanEVMTx(request: request)

    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertNotNil(portalRequest?.payload)
  }

  func testScanEVMTx_decodesValidResponse_success() async throws {
    let expectedResponse = BlockaidScanEVMResponse.stub()
    try setReturnValue(expectedResponse)
    let request = BlockaidScanEVMRequest.stub()

    let response = try await sut.scanEVMTx(request: request)

    XCTAssertNotNil(response.data)
    XCTAssertNil(response.error)
  }

  func testScanEVMTx_networkError_throwsError() async {
    requestsSpy.returnData = Data()
    let request = BlockaidScanEVMRequest.stub()

    do {
      _ = try await sut.scanEVMTx(request: request)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  // MARK: - scanSolanaTx Tests

  func testScanSolanaTx_buildsCorrectUrl() async throws {
    try setReturnValue(BlockaidScanSolanaResponse(data: nil, error: nil))
    let request = BlockaidScanSolanaRequest.stub()

    _ = try await sut.scanSolanaTx(request: request)

    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let expectedUrl = "https://api.portalhq.io/api/v3/clients/me/integrations/blockaid/solana/scan"
    XCTAssertEqual(portalRequest?.url.absoluteString, expectedUrl)
  }

  func testScanSolanaTx_usesPostMethod() async throws {
    try setReturnValue(BlockaidScanSolanaResponse(data: nil, error: nil))
    let request = BlockaidScanSolanaRequest.stub()

    _ = try await sut.scanSolanaTx(request: request)

    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.method, .post)
  }

  func testScanSolanaTx_includesBearerToken() async throws {
    try setReturnValue(BlockaidScanSolanaResponse(data: nil, error: nil))
    let request = BlockaidScanSolanaRequest.stub()

    _ = try await sut.scanSolanaTx(request: request)

    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.headers["Authorization"], "Bearer \(testApiKey)")
  }

  func testScanSolanaTx_serializesRequestPayload() async throws {
    try setReturnValue(BlockaidScanSolanaResponse(data: nil, error: nil))
    let request = BlockaidScanSolanaRequest.stub()

    _ = try await sut.scanSolanaTx(request: request)

    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertNotNil(portalRequest?.payload)
  }

  func testScanSolanaTx_decodesValidResponse_success() async throws {
    let expectedResponse = BlockaidScanSolanaResponse.stub()
    try setReturnValue(expectedResponse)
    let request = BlockaidScanSolanaRequest.stub()

    let response = try await sut.scanSolanaTx(request: request)

    XCTAssertNotNil(response.data)
    XCTAssertNil(response.error)
  }

  func testScanSolanaTx_networkError_throwsError() async {
    let failMock = PortalRequestsFailMock()
    failMock.errorToThrow = URLError(.networkConnectionLost)
    let apiWithFailingRequests = PortalBlockaidApi(
      apiKey: testApiKey,
      apiHost: "api.portalhq.io",
      requests: failMock
    )
    let request = BlockaidScanSolanaRequest.stub()

    do {
      _ = try await apiWithFailingRequests.scanSolanaTx(request: request)
      XCTFail("Expected error to be thrown")
    } catch let error as URLError {
      XCTAssertEqual(error.code, .networkConnectionLost)
    } catch {
      XCTFail("Expected URLError, got \(type(of: error))")
    }
  }

  // MARK: - scanAddress Tests

  func testScanAddress_buildsCorrectUrl() async throws {
    try setReturnValue(BlockaidScanAddressResponse(data: nil, error: nil))
    let request = BlockaidScanAddressRequest.stub()

    _ = try await sut.scanAddress(request: request)

    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let expectedUrl = "https://api.portalhq.io/api/v3/clients/me/integrations/blockaid/address/scan"
    XCTAssertEqual(portalRequest?.url.absoluteString, expectedUrl)
  }

  func testScanAddress_usesPostMethod() async throws {
    try setReturnValue(BlockaidScanAddressResponse(data: nil, error: nil))
    let request = BlockaidScanAddressRequest.stub()

    _ = try await sut.scanAddress(request: request)

    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.method, .post)
  }

  func testScanAddress_includesBearerToken() async throws {
    try setReturnValue(BlockaidScanAddressResponse(data: nil, error: nil))
    let request = BlockaidScanAddressRequest.stub()

    _ = try await sut.scanAddress(request: request)

    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.headers["Authorization"], "Bearer \(testApiKey)")
  }

  func testScanAddress_serializesRequestPayload() async throws {
    try setReturnValue(BlockaidScanAddressResponse(data: nil, error: nil))
    let request = BlockaidScanAddressRequest.stub()

    _ = try await sut.scanAddress(request: request)

    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertNotNil(portalRequest?.payload)
  }

  // MARK: - scanTokens Tests

  func testScanTokens_buildsCorrectUrl() async throws {
    try setReturnValue(BlockaidScanTokensResponse(data: nil, error: nil))
    let request = BlockaidScanTokensRequest.stub()

    _ = try await sut.scanTokens(request: request)

    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let expectedUrl = "https://api.portalhq.io/api/v3/clients/me/integrations/blockaid/tokens/scan"
    XCTAssertEqual(portalRequest?.url.absoluteString, expectedUrl)
  }

  func testScanTokens_usesPostMethod() async throws {
    try setReturnValue(BlockaidScanTokensResponse(data: nil, error: nil))
    let request = BlockaidScanTokensRequest.stub()

    _ = try await sut.scanTokens(request: request)

    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.method, .post)
  }

  func testScanTokens_includesBearerToken() async throws {
    try setReturnValue(BlockaidScanTokensResponse(data: nil, error: nil))
    let request = BlockaidScanTokensRequest.stub()

    _ = try await sut.scanTokens(request: request)

    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.headers["Authorization"], "Bearer \(testApiKey)")
  }

  func testScanTokens_serializesRequestPayload() async throws {
    try setReturnValue(BlockaidScanTokensResponse(data: nil, error: nil))
    let request = BlockaidScanTokensRequest.stub()

    _ = try await sut.scanTokens(request: request)

    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertNotNil(portalRequest?.payload)
  }

  // MARK: - scanURL Tests

  func testScanURL_buildsCorrectUrl() async throws {
    try setReturnValue(BlockaidScanURLResponse(data: nil, error: nil))
    let request = BlockaidScanURLRequest.stub()

    _ = try await sut.scanURL(request: request)

    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let expectedUrl = "https://api.portalhq.io/api/v3/clients/me/integrations/blockaid/url/scan"
    XCTAssertEqual(portalRequest?.url.absoluteString, expectedUrl)
  }

  func testScanURL_usesPostMethod() async throws {
    try setReturnValue(BlockaidScanURLResponse(data: nil, error: nil))
    let request = BlockaidScanURLRequest.stub()

    _ = try await sut.scanURL(request: request)

    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.method, .post)
  }

  func testScanURL_includesBearerToken() async throws {
    try setReturnValue(BlockaidScanURLResponse(data: nil, error: nil))
    let request = BlockaidScanURLRequest.stub()

    _ = try await sut.scanURL(request: request)

    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.headers["Authorization"], "Bearer \(testApiKey)")
  }

  func testScanURL_serializesRequestPayload() async throws {
    try setReturnValue(BlockaidScanURLResponse(data: nil, error: nil))
    let request = BlockaidScanURLRequest.stub()

    _ = try await sut.scanURL(request: request)

    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertNotNil(portalRequest?.payload)
  }
}
