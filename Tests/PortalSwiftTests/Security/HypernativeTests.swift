//
//  HypernativeTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import XCTest
@testable import PortalSwift

final class HypernativeTests: XCTestCase {
  
  private var apiMock: PortalHypernativeApiMock!
  private var sut: Hypernative!
  
  // MARK: - Setup & Teardown
  
  override func setUpWithError() throws {
    try super.setUpWithError()
    apiMock = PortalHypernativeApiMock()
    sut = Hypernative(api: apiMock)
  }
  
  override func tearDownWithError() throws {
    apiMock = nil
    sut = nil
    try super.tearDownWithError()
  }
  
  // MARK: - Initialization Tests
  
  func testInit_createsInstanceWithApi() {
    XCTAssertNotNil(sut)
  }
  
  // MARK: - scanEVMTx Tests
  
  func testScanEVMTx_success_returnsResponse() async throws {
    // Given
    let expectedResponse = ScanEVMResponse.stub()
    apiMock.scanEVMTxReturnValue = expectedResponse
    let request = ScanEVMRequest.stub()
    
    // When
    let response = try await sut.scanEVMTx(request: request)
    
    // Then
    XCTAssertEqual(apiMock.scanEVMTxCallCount, 1)
    XCTAssertNotNil(apiMock.lastScanEVMRequest)
    XCTAssertEqual(apiMock.lastScanEVMRequest?.transaction.chain, "eip155:1")
    XCTAssertNotNil(response.data)
  }
  
  func testScanEVMTx_apiError_throwsError() async {
    // Given
    let expectedError = NSError(domain: "Test", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server Error"])
    apiMock.scanEVMTxError = expectedError
    let request = ScanEVMRequest.stub()
    
    // When/Then
    do {
      _ = try await sut.scanEVMTx(request: request)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual((error as NSError).code, 500)
    }
  }
  
  func testScanEVMTx_denyRecommendation_returnsDenyResponse() async throws {
    // Given
    let expectedResponse = ScanEVMResponse.stub(
      data: ScanEVMData.stub(
        rawResponse: ScanEVMRawResponse.stub(
          data: ScanEVMRiskData.stub(recommendation: "deny")
        )
      )
    )
    apiMock.scanEVMTxReturnValue = expectedResponse
    let request = ScanEVMRequest.stub()
    
    // When
    let response = try await sut.scanEVMTx(request: request)
    
    // Then
    XCTAssertEqual(response.data?.rawResponse.data?.recommendation, "deny")
  }
  
  // MARK: - scanEip712Tx Tests
  
  func testScanEip712Tx_success_returnsResponse() async throws {
    // Given
    let expectedResponse = ScanEip712Response.stub()
    apiMock.scanEip712TxReturnValue = expectedResponse
    let request = ScanEip712Request.stub()
    
    // When
    let response = try await sut.scanEip712Tx(request: request)
    
    // Then
    XCTAssertEqual(apiMock.scanEip712TxCallCount, 1)
    XCTAssertNotNil(response.data)
  }
  
  func testScanEip712Tx_apiError_throwsError() async {
    // Given
    apiMock.scanEip712TxError = NSError(domain: "Test", code: 400)
    let request = ScanEip712Request.stub()
    
    // When/Then
    do {
      _ = try await sut.scanEip712Tx(request: request)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual((error as NSError).code, 400)
    }
  }
  
  // MARK: - scanSolanaTx Tests
  
  func testScanSolanaTx_success_returnsResponse() async throws {
    // Given
    let expectedResponse = ScanSolanaResponse.stub()
    apiMock.scanSolanaTxReturnValue = expectedResponse
    let request = ScanSolanaRequest.stub()
    
    // When
    let response = try await sut.scanSolanaTx(request: request)
    
    // Then
    XCTAssertEqual(apiMock.scanSolanaTxCallCount, 1)
    XCTAssertNotNil(response.data)
  }
  
  func testScanSolanaTx_apiError_throwsError() async {
    // Given
    apiMock.scanSolanaTxError = NSError(domain: "Test", code: 403)
    let request = ScanSolanaRequest.stub()
    
    // When/Then
    do {
      _ = try await sut.scanSolanaTx(request: request)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual((error as NSError).code, 403)
    }
  }
  
  // MARK: - scanAddresses Tests
  
  func testScanAddresses_success_returnsResponse() async throws {
    // Given
    let expectedResponse = ScanAddressesResponse.stub()
    apiMock.scanAddressesReturnValue = expectedResponse
    let request = ScanAddressesRequest.stub()
    
    // When
    let response = try await sut.scanAddresses(request: request)
    
    // Then
    XCTAssertEqual(apiMock.scanAddressesCallCount, 1)
    XCTAssertEqual(apiMock.lastScanAddressesRequest?.addresses.count, 2)
  }
  
  func testScanAddresses_apiError_throwsError() async {
    // Given
    apiMock.scanAddressesError = NSError(domain: "Test", code: 429)
    let request = ScanAddressesRequest.stub()
    
    // When/Then
    do {
      _ = try await sut.scanAddresses(request: request)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual((error as NSError).code, 429)
    }
  }
  
  func testScanAddresses_singleAddress_returnsResponse() async throws {
    // Given
    let expectedResponse = ScanAddressesResponse.stub()
    apiMock.scanAddressesReturnValue = expectedResponse
    let request = ScanAddressesRequest.stub(addresses: ["0x123"])
    
    // When
    let response = try await sut.scanAddresses(request: request)
    
    // Then
    XCTAssertEqual(apiMock.lastScanAddressesRequest?.addresses.count, 1)
  }
  
  func testScanAddresses_emptyAddresses_returnsResponse() async throws {
    // Given
    let expectedResponse = ScanAddressesResponse.stub()
    apiMock.scanAddressesReturnValue = expectedResponse
    let request = ScanAddressesRequest.stub(addresses: [])
    
    // When
    let response = try await sut.scanAddresses(request: request)
    
    // Then
    XCTAssertEqual(apiMock.lastScanAddressesRequest?.addresses.count, 0)
  }
  
  // MARK: - scanNfts Tests
  
  func testScanNfts_success_returnsResponse() async throws {
    // Given
    let expectedResponse = ScanNftsResponse.stub()
    apiMock.scanNftsReturnValue = expectedResponse
    let request = ScanNftsRequest.stub()
    
    // When
    let response = try await sut.scanNfts(request: request)
    
    // Then
    XCTAssertEqual(apiMock.scanNftsCallCount, 1)
    XCTAssertNotNil(response.data)
  }
  
  func testScanNfts_apiError_throwsError() async {
    // Given
    apiMock.scanNftsError = NSError(domain: "Test", code: 502)
    let request = ScanNftsRequest.stub()
    
    // When/Then
    do {
      _ = try await sut.scanNfts(request: request)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual((error as NSError).code, 502)
    }
  }
  
  func testScanNfts_multipleNfts_returnsResponse() async throws {
    // Given
    let expectedResponse = ScanNftsResponse.stub()
    apiMock.scanNftsReturnValue = expectedResponse
    let nfts = [
      ScanNftsRequestItem.stub(address: "0x111", evmChainId: "eip155:1"),
      ScanNftsRequestItem.stub(address: "0x222", evmChainId: "eip155:1"),
      ScanNftsRequestItem.stub(address: "0x333", evmChainId: "eip155:137")
    ]
    let request = ScanNftsRequest.stub(nfts: nfts)
    
    // When
    let response = try await sut.scanNfts(request: request)
    
    // Then
    XCTAssertEqual(apiMock.lastScanNftsRequest?.nfts.count, 3)
  }
  
  // MARK: - scanTokens Tests
  
  func testScanTokens_success_returnsResponse() async throws {
    // Given
    let expectedResponse = ScanTokensResponse.stub()
    apiMock.scanTokensReturnValue = expectedResponse
    let request = ScanTokensRequest.stub()
    
    // When
    let response = try await sut.scanTokens(request: request)
    
    // Then
    XCTAssertEqual(apiMock.scanTokensCallCount, 1)
    XCTAssertNotNil(response.data)
  }
  
  func testScanTokens_apiError_throwsError() async {
    // Given
    apiMock.scanTokensError = NSError(domain: "Test", code: 404)
    let request = ScanTokensRequest.stub()
    
    // When/Then
    do {
      _ = try await sut.scanTokens(request: request)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual((error as NSError).code, 404)
    }
  }
  
  // MARK: - scanURL Tests
  
  func testScanURL_success_returnsResponse() async throws {
    // Given
    let expectedResponse = ScanUrlResponse.stub()
    apiMock.scanURLReturnValue = expectedResponse
    let request = ScanUrlRequest.stub()
    
    // When
    let response = try await sut.scanURL(request: request)
    
    // Then
    XCTAssertEqual(apiMock.scanURLCallCount, 1)
    XCTAssertNotNil(response.data)
  }
  
  func testScanURL_apiError_throwsError() async {
    // Given
    apiMock.scanURLError = NSError(domain: "Test", code: 503)
    let request = ScanUrlRequest.stub()
    
    // When/Then
    do {
      _ = try await sut.scanURL(request: request)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual((error as NSError).code, 503)
    }
  }
  
  func testScanURL_maliciousUrl_returnsTrue() async throws {
    // Given
    let expectedResponse = ScanUrlResponse.stub(
      data: ScanUrlData.stub(
        rawResponse: ScanUrlRawResponse.stub(
          data: ScanUrlDataContent.stub(isMalicious: true)
        )
      )
    )
    apiMock.scanURLReturnValue = expectedResponse
    let request = ScanUrlRequest.stub(url: "https://malicious.com")
    
    // When
    let response = try await sut.scanURL(request: request)
    
    // Then
    XCTAssertEqual(response.data?.rawResponse.data?.isMalicious, true)
  }
  
  func testScanURL_safeUrl_returnsFalse() async throws {
    // Given
    let expectedResponse = ScanUrlResponse.stub()
    apiMock.scanURLReturnValue = expectedResponse
    let request = ScanUrlRequest.stub(url: "https://safe.com")
    
    // When
    let response = try await sut.scanURL(request: request)
    
    // Then
    XCTAssertEqual(response.data?.rawResponse.data?.isMalicious, false)
  }
  
  // MARK: - Thread Safety Tests
  
  func testConcurrentCalls_multipleSimultaneousRequests_allSucceed() async throws {
    // Given
    let evmResponse = ScanEVMResponse.stub()
    let addressResponse = ScanAddressesResponse.stub()
    let urlResponse = ScanUrlResponse.stub()
    
    apiMock.scanEVMTxReturnValue = evmResponse
    apiMock.scanAddressesReturnValue = addressResponse
    apiMock.scanURLReturnValue = urlResponse
    
    // When
    async let result1 = sut.scanEVMTx(request: ScanEVMRequest.stub())
    async let result2 = sut.scanAddresses(request: ScanAddressesRequest.stub(addresses: ["0x123"]))
    async let result3 = sut.scanURL(request: ScanUrlRequest.stub(url: "https://test.com"))
    
    let responses = try await [result1, result2, result3] as [Any]
    
    // Then
    XCTAssertEqual(responses.count, 3)
    XCTAssertEqual(apiMock.scanEVMTxCallCount, 1)
    XCTAssertEqual(apiMock.scanAddressesCallCount, 1)
    XCTAssertEqual(apiMock.scanURLCallCount, 1)
  }
}
