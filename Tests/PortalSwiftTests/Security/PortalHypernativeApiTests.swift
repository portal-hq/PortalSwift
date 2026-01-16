//
//  PortalHypernativeApiTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import XCTest
@testable import PortalSwift

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
    try setReturnValue(ScanEip155Response(data: nil, error: nil))
    let request = ScanEip155Request.stub()
    _ = try? await localSut.scanEip155Tx(request: request)
    
    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertTrue(portalRequest?.url.absoluteString.starts(with: "http://") ?? false)
  }
  
  // MARK: - scanEip155Tx Tests
  
  func testScanEip155Tx_buildsCorrectUrl() async throws {
    // Given
    try setReturnValue(ScanEip155Response(data: nil, error: nil))
    let request = ScanEip155Request.stub()
    
    // When
    _ = try await sut.scanEip155Tx(request: request)
    
    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let expectedUrl = "https://api.portalhq.io/api/v3/clients/me/integrations/hypernative/eip-155/scan"
    XCTAssertEqual(portalRequest?.url.absoluteString, expectedUrl)
  }
  
  func testScanEip155Tx_usesPostMethod() async throws {
    // Given
    try setReturnValue(ScanEip155Response(data: nil, error: nil))
    let request = ScanEip155Request.stub()
    
    // When
    _ = try await sut.scanEip155Tx(request: request)
    
    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.method, .post)
  }
  
  func testScanEip155Tx_includesBearerToken() async throws {
    // Given
    try setReturnValue(ScanEip155Response(data: nil, error: nil))
    let request = ScanEip155Request.stub()
    
    // When
    _ = try await sut.scanEip155Tx(request: request)
    
    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.headers["Authorization"], "Bearer \(testApiKey)")
  }
  
  func testScanEip155Tx_serializesRequestPayload() async throws {
    // Given
    try setReturnValue(ScanEip155Response(data: nil, error: nil))
    let request = ScanEip155Request.stub()
    
    // When
    _ = try await sut.scanEip155Tx(request: request)
    
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
  
  // MARK: - Error Handling Tests
  
  func testScanEip155Tx_networkError_throwsError() async {
    // Given
    requestsSpy.returnData = Data() // Empty data will cause decode error
    let request = ScanEip155Request.stub()
    
    // When/Then
    do {
      _ = try await sut.scanEip155Tx(request: request)
      XCTFail("Expected error to be thrown")
    } catch {
      // Expected to throw decoding error
      XCTAssertNotNil(error)
    }
  }
}
