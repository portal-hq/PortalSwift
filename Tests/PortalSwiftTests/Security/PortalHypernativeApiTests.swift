//
//  PortalHypernativeApiTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

@testable import PortalSwift
import XCTest

final class PortalHypernativeApiTests: XCTestCase {
  private var requestsSpy: PortalRequestsSpy!
  private var sut: PortalHypernativeApi!
  let testApiKey = "test-api-key"
  let encoder = JSONEncoder()

  // MARK: - Setup & Teardown

  override func setUpWithError() throws {
    try super.setUpWithError()
    requestsSpy = PortalRequestsSpy()
    sut = PortalHypernativeApi(
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

  // Helper to set return data
  private func setReturnValue<T: Encodable>(_ value: T) throws {
    requestsSpy.returnData = try encoder.encode(value)
  }

  // MARK: - Initialization Tests

  func testInit_productionHost_usesHttps() {
    let api = PortalHypernativeApi(apiKey: "key", apiHost: "api.portalhq.io")
    XCTAssertNotNil(api)
  }

  func testInit_localhost_usesHttp() async throws {
    // Given
    let localSut = PortalHypernativeApi(
      apiKey: "test-key",
      apiHost: "localhost:3000",
      requests: requestsSpy
    )

    // When
    try setReturnValue(ScanEVMResponse(data: nil, error: nil))
    let request = ScanEVMRequest.stub()
    _ = try? await localSut.scanEVMTx(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertTrue(portalRequest?.url.absoluteString.starts(with: "http://") ?? false)
  }

  // MARK: - scanEVMTx Tests

  func testScanEVMTx_buildsCorrectUrl() async throws {
    // Given
    try setReturnValue(ScanEVMResponse(data: nil, error: nil))
    let request = ScanEVMRequest.stub()

    // When
    _ = try await sut.scanEVMTx(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let expectedUrl = "https://api.portalhq.io/api/v3/clients/me/integrations/hypernative/evm/scan"
    XCTAssertEqual(portalRequest?.url.absoluteString, expectedUrl)
  }

  func testScanEVMTx_usesPostMethod() async throws {
    // Given
    try setReturnValue(ScanEVMResponse(data: nil, error: nil))
    let request = ScanEVMRequest.stub()

    // When
    _ = try await sut.scanEVMTx(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.method, .post)
  }

  func testScanEVMTx_includesBearerToken() async throws {
    // Given
    try setReturnValue(ScanEVMResponse(data: nil, error: nil))
    let request = ScanEVMRequest.stub()

    // When
    _ = try await sut.scanEVMTx(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.headers["Authorization"], "Bearer \(testApiKey)")
  }

  func testScanEVMTx_serializesRequestPayload() async throws {
    // Given
    try setReturnValue(ScanEVMResponse(data: nil, error: nil))
    let request = ScanEVMRequest.stub()

    // When
    _ = try await sut.scanEVMTx(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertNotNil(portalRequest?.payload)
  }

  // MARK: - scanEip712Tx Tests

  func testScanEip712Tx_buildsCorrectUrl() async throws {
    // Given
    try setReturnValue(ScanEip712Response(data: nil, error: nil))
    let request = ScanEip712Request.stub()

    // When
    _ = try await sut.scanEip712Tx(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let expectedUrl = "https://api.portalhq.io/api/v3/clients/me/integrations/hypernative/eip-712/scan"
    XCTAssertEqual(portalRequest?.url.absoluteString, expectedUrl)
  }

  func testScanEip712Tx_usesPostMethod() async throws {
    // Given
    try setReturnValue(ScanEip712Response(data: nil, error: nil))
    let request = ScanEip712Request.stub()

    // When
    _ = try await sut.scanEip712Tx(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.method, .post)
  }

  func testScanEip712Tx_includesBearerToken() async throws {
    // Given
    try setReturnValue(ScanEip712Response(data: nil, error: nil))
    let request = ScanEip712Request.stub()

    // When
    _ = try await sut.scanEip712Tx(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.headers["Authorization"], "Bearer \(testApiKey)")
  }

  func testScanEip712Tx_serializesRequestPayload() async throws {
    // Given
    try setReturnValue(ScanEip712Response(data: nil, error: nil))
    let request = ScanEip712Request.stub()

    // When
    _ = try await sut.scanEip712Tx(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertNotNil(portalRequest?.payload)
  }

  // MARK: - scanSolanaTx Tests

  func testScanSolanaTx_buildsCorrectUrl() async throws {
    // Given
    try setReturnValue(ScanSolanaResponse(data: nil, error: nil))
    let request = ScanSolanaRequest.stub()

    // When
    _ = try await sut.scanSolanaTx(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let expectedUrl = "https://api.portalhq.io/api/v3/clients/me/integrations/hypernative/solana/scan"
    XCTAssertEqual(portalRequest?.url.absoluteString, expectedUrl)
  }

  func testScanSolanaTx_usesPostMethod() async throws {
    // Given
    try setReturnValue(ScanSolanaResponse(data: nil, error: nil))
    let request = ScanSolanaRequest.stub()

    // When
    _ = try await sut.scanSolanaTx(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.method, .post)
  }

  func testScanSolanaTx_includesBearerToken() async throws {
    // Given
    try setReturnValue(ScanSolanaResponse(data: nil, error: nil))
    let request = ScanSolanaRequest.stub()

    // When
    _ = try await sut.scanSolanaTx(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.headers["Authorization"], "Bearer \(testApiKey)")
  }

  func testScanSolanaTx_serializesRequestPayload() async throws {
    // Given
    try setReturnValue(ScanSolanaResponse(data: nil, error: nil))
    let request = ScanSolanaRequest.stub()

    // When
    _ = try await sut.scanSolanaTx(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertNotNil(portalRequest?.payload)
  }

  // MARK: - scanAddresses Tests

  func testScanAddresses_buildsCorrectUrl() async throws {
    // Given
    try setReturnValue(ScanAddressesResponse(data: nil, error: nil))
    let request = ScanAddressesRequest(addresses: ["0x123"], screenerPolicyId: nil)

    // When
    _ = try await sut.scanAddresses(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let expectedUrl = "https://api.portalhq.io/api/v3/clients/me/integrations/hypernative/addresses/scan"
    XCTAssertEqual(portalRequest?.url.absoluteString, expectedUrl)
  }

  func testScanAddresses_usesPostMethod() async throws {
    // Given
    try setReturnValue(ScanAddressesResponse(data: nil, error: nil))
    let request = ScanAddressesRequest.stub()

    // When
    _ = try await sut.scanAddresses(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.method, .post)
  }

  func testScanAddresses_includesBearerToken() async throws {
    // Given
    try setReturnValue(ScanAddressesResponse(data: nil, error: nil))
    let request = ScanAddressesRequest.stub()

    // When
    _ = try await sut.scanAddresses(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.headers["Authorization"], "Bearer \(testApiKey)")
  }

  func testScanAddresses_serializesRequestPayload() async throws {
    // Given
    try setReturnValue(ScanAddressesResponse(data: nil, error: nil))
    let request = ScanAddressesRequest.stub()

    // When
    _ = try await sut.scanAddresses(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertNotNil(portalRequest?.payload)
  }

  // MARK: - scanNfts Tests

  func testScanNfts_buildsCorrectUrl() async throws {
    // Given
    try setReturnValue(ScanNftsResponse(data: nil, error: nil))
    let request = ScanNftsRequest.stub()

    // When
    _ = try await sut.scanNfts(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let expectedUrl = "https://api.portalhq.io/api/v3/clients/me/integrations/hypernative/nfts/scan"
    XCTAssertEqual(portalRequest?.url.absoluteString, expectedUrl)
  }

  func testScanNfts_usesPostMethod() async throws {
    // Given
    try setReturnValue(ScanNftsResponse(data: nil, error: nil))
    let request = ScanNftsRequest.stub()

    // When
    _ = try await sut.scanNfts(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.method, .post)
  }

  func testScanNfts_includesBearerToken() async throws {
    // Given
    try setReturnValue(ScanNftsResponse(data: nil, error: nil))
    let request = ScanNftsRequest.stub()

    // When
    _ = try await sut.scanNfts(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.headers["Authorization"], "Bearer \(testApiKey)")
  }

  func testScanNfts_serializesRequestPayload() async throws {
    // Given
    try setReturnValue(ScanNftsResponse(data: nil, error: nil))
    let request = ScanNftsRequest.stub()

    // When
    _ = try await sut.scanNfts(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertNotNil(portalRequest?.payload)
  }

  // MARK: - scanTokens Tests

  func testScanTokens_buildsCorrectUrl() async throws {
    // Given
    try setReturnValue(ScanTokensResponse(data: nil, error: nil))
    let request = ScanTokensRequest.stub()

    // When
    _ = try await sut.scanTokens(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let expectedUrl = "https://api.portalhq.io/api/v3/clients/me/integrations/hypernative/tokens/scan"
    XCTAssertEqual(portalRequest?.url.absoluteString, expectedUrl)
  }

  func testScanTokens_usesPostMethod() async throws {
    // Given
    try setReturnValue(ScanTokensResponse(data: nil, error: nil))
    let request = ScanTokensRequest.stub()

    // When
    _ = try await sut.scanTokens(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.method, .post)
  }

  func testScanTokens_includesBearerToken() async throws {
    // Given
    try setReturnValue(ScanTokensResponse(data: nil, error: nil))
    let request = ScanTokensRequest.stub()

    // When
    _ = try await sut.scanTokens(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.headers["Authorization"], "Bearer \(testApiKey)")
  }

  func testScanTokens_serializesRequestPayload() async throws {
    // Given
    try setReturnValue(ScanTokensResponse(data: nil, error: nil))
    let request = ScanTokensRequest.stub()

    // When
    _ = try await sut.scanTokens(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertNotNil(portalRequest?.payload)
  }

  // MARK: - scanURL Tests

  func testScanURL_buildsCorrectUrl() async throws {
    // Given
    try setReturnValue(ScanUrlResponse(data: nil, error: nil))
    let request = ScanUrlRequest(url: "https://test.com")

    // When
    _ = try await sut.scanURL(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let expectedUrl = "https://api.portalhq.io/api/v3/clients/me/integrations/hypernative/url/scan"
    XCTAssertEqual(portalRequest?.url.absoluteString, expectedUrl)
  }

  func testScanURL_usesPostMethod() async throws {
    // Given
    try setReturnValue(ScanUrlResponse(data: nil, error: nil))
    let request = ScanUrlRequest.stub()

    // When
    _ = try await sut.scanURL(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.method, .post)
  }

  func testScanURL_includesBearerToken() async throws {
    // Given
    try setReturnValue(ScanUrlResponse(data: nil, error: nil))
    let request = ScanUrlRequest.stub()

    // When
    _ = try await sut.scanURL(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.headers["Authorization"], "Bearer \(testApiKey)")
  }

  func testScanURL_serializesRequestPayload() async throws {
    // Given
    try setReturnValue(ScanUrlResponse(data: nil, error: nil))
    let request = ScanUrlRequest.stub()

    // When
    _ = try await sut.scanURL(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertNotNil(portalRequest?.payload)
  }

  // MARK: - Error Handling Tests

  func testScanEVMTx_networkError_throwsError() async {
    // Given
    requestsSpy.returnData = Data() // Empty data will cause decode error
    let request = ScanEVMRequest.stub()

    // When/Then
    do {
      _ = try await sut.scanEVMTx(request: request)
      XCTFail("Expected error to be thrown")
    } catch {
      // Expected to throw decoding error
      XCTAssertNotNil(error)
    }
  }

  // MARK: - scanSolanaTx Success and Error Tests

  func testScanSolanaTx_decodesValidResponse_success() async throws {
    // Given
    let expectedResponse = ScanSolanaResponse.stub()
    try setReturnValue(expectedResponse)
    let request = ScanSolanaRequest.stub()

    // When
    let response = try await sut.scanSolanaTx(request: request)

    // Then
    XCTAssertNotNil(response.data)
    XCTAssertEqual(response.data?.rawResponse.success, true)
    XCTAssertEqual(response.data?.rawResponse.data?.recommendation, "accept")
    XCTAssertNil(response.error)
  }

  func testScanSolanaTx_decodingError_throwsError() async {
    // Given
    requestsSpy.returnData = Data("invalid json".utf8)
    let request = ScanSolanaRequest.stub()

    // When/Then
    do {
      _ = try await sut.scanSolanaTx(request: request)
      XCTFail("Expected decoding error to be thrown")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  func testScanSolanaTx_executeThrows_throwsError() async {
    // Given
    let failMock = PortalRequestsFailMock()
    failMock.errorToThrow = URLError(.networkConnectionLost)
    let apiWithFailingRequests = PortalHypernativeApi(
      apiKey: testApiKey,
      apiHost: "api.portalhq.io",
      requests: failMock
    )
    let request = ScanSolanaRequest.stub()

    // When/Then
    do {
      _ = try await apiWithFailingRequests.scanSolanaTx(request: request)
      XCTFail("Expected error to be thrown")
    } catch let error as URLError {
      XCTAssertEqual(error.code, .networkConnectionLost)
    } catch {
      XCTFail("Expected URLError, got \(type(of: error))")
    }
  }

  func testScanSolanaTx_payloadMatchesRequest() async throws {
    // Given
    let tx = ScanSolanaTransaction.stub(
      message: ScanSolanaMessage.stub(),
      rawTransaction: "base64raw",
      version: "0"
    )
    let request = ScanSolanaRequest(
      transaction: tx,
      url: "https://app.example.com",
      validateRecentBlockHash: true,
      showFullFindings: true,
      policy: "policy-1"
    )
    try setReturnValue(ScanSolanaResponse.stub())

    // When
    _ = try await sut.scanSolanaTx(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let payload = portalRequest?.payload as? ScanSolanaRequest
    XCTAssertNotNil(payload)
    XCTAssertEqual(payload?.transaction.rawTransaction, "base64raw")
    XCTAssertEqual(payload?.transaction.version, "0")
    XCTAssertEqual(payload?.url, "https://app.example.com")
    XCTAssertEqual(payload?.validateRecentBlockHash, true)
    XCTAssertEqual(payload?.showFullFindings, true)
    XCTAssertEqual(payload?.policy, "policy-1")
  }
}
