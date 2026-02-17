//
//  BlockaidTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

@testable import PortalSwift
import XCTest

final class BlockaidTests: XCTestCase {
  private var mockApi: PortalBlockaidApiMock!
  private var sut: Blockaid!

  // MARK: - Setup & Teardown

  override func setUpWithError() throws {
    try super.setUpWithError()
    mockApi = PortalBlockaidApiMock()
    sut = Blockaid(api: mockApi)
  }

  override func tearDownWithError() throws {
    mockApi = nil
    sut = nil
    try super.tearDownWithError()
  }

  // MARK: - Initialization Tests

  func testInit_createsInstance() {
    XCTAssertNotNil(sut)
  }

  // MARK: - scanEVMTx Tests

  func testScanEVMTx_success_returnsResponse() async throws {
    let expectedResponse = BlockaidScanEVMResponse.stub()
    mockApi.scanEVMTxReturnValue = expectedResponse
    let request = BlockaidScanEVMRequest.stub()

    let response = try await sut.scanEVMTx(request: request)

    XCTAssertNotNil(response.data)
  }

  func testScanEVMTx_error_throwsError() async {
    mockApi.scanEVMTxError = URLError(.badServerResponse)
    let request = BlockaidScanEVMRequest.stub()

    do {
      _ = try await sut.scanEVMTx(request: request)
      XCTFail("Expected error")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  func testScanEVMTx_maliciousResult_returnsCorrectResultType() async throws {
    let maliciousResponse = BlockaidScanEVMResponse.stub(
      data: .stub(rawResponse: .stub(
        validation: .stub(resultType: "Malicious")
      ))
    )
    mockApi.scanEVMTxReturnValue = maliciousResponse
    let request = BlockaidScanEVMRequest.stub()

    let response = try await sut.scanEVMTx(request: request)

    XCTAssertEqual(response.data?.rawResponse.validation?.resultType, "Malicious")
  }

  // MARK: - scanSolanaTx Tests

  func testScanSolanaTx_success_returnsResponse() async throws {
    let expectedResponse = BlockaidScanSolanaResponse.stub()
    mockApi.scanSolanaTxReturnValue = expectedResponse
    let request = BlockaidScanSolanaRequest.stub()

    let response = try await sut.scanSolanaTx(request: request)

    XCTAssertNotNil(response.data)
  }

  func testScanSolanaTx_error_throwsError() async {
    mockApi.scanSolanaTxError = URLError(.timedOut)
    let request = BlockaidScanSolanaRequest.stub()

    do {
      _ = try await sut.scanSolanaTx(request: request)
      XCTFail("Expected error")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  // MARK: - scanAddress Tests

  func testScanAddress_evmAddress_success() async throws {
    let expectedResponse = BlockaidScanAddressResponse.stub()
    mockApi.scanAddressReturnValue = expectedResponse
    let request = BlockaidScanAddressRequest.stub(chain: "eip155:1")

    let response = try await sut.scanAddress(request: request)

    XCTAssertNotNil(response.data)
  }

  func testScanAddress_solanaAddress_success() async throws {
    let expectedResponse = BlockaidScanAddressResponse.stub()
    mockApi.scanAddressReturnValue = expectedResponse
    let request = BlockaidScanAddressRequest.stub(chain: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp")

    let response = try await sut.scanAddress(request: request)

    XCTAssertNotNil(response.data)
  }

  func testScanAddress_error_throwsError() async {
    mockApi.scanAddressError = URLError(.networkConnectionLost)
    let request = BlockaidScanAddressRequest.stub()

    do {
      _ = try await sut.scanAddress(request: request)
      XCTFail("Expected error")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  // MARK: - scanTokens Tests

  func testScanTokens_success_returnsResponse() async throws {
    let expectedResponse = BlockaidScanTokensResponse.stub()
    mockApi.scanTokensReturnValue = expectedResponse
    let request = BlockaidScanTokensRequest.stub()

    let response = try await sut.scanTokens(request: request)

    XCTAssertNotNil(response.data)
  }

  func testScanTokens_multipleTokens_returnsAllResults() async throws {
    let multiTokenResponse = BlockaidScanTokensResponse.stub(
      data: .stub(rawResponse: .stub(results: [
        "0xtoken1": .stub(resultType: "Benign"),
        "0xtoken2": .stub(resultType: "Malicious")
      ]))
    )
    mockApi.scanTokensReturnValue = multiTokenResponse
    let request = BlockaidScanTokensRequest.stub(tokens: ["0xtoken1", "0xtoken2"])

    let response = try await sut.scanTokens(request: request)

    XCTAssertEqual(response.data?.rawResponse.results.count, 2)
    XCTAssertEqual(response.data?.rawResponse.results["0xtoken1"]?.resultType, "Benign")
    XCTAssertEqual(response.data?.rawResponse.results["0xtoken2"]?.resultType, "Malicious")
  }

  func testScanTokens_error_throwsError() async {
    mockApi.scanTokensError = URLError(.badURL)
    let request = BlockaidScanTokensRequest.stub()

    do {
      _ = try await sut.scanTokens(request: request)
      XCTFail("Expected error")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  // MARK: - scanURL Tests

  func testScanURL_hitStatus_returnsFullDetails() async throws {
    let hitResponse = BlockaidScanURLResponse.stub(
      data: .stub(rawResponse: .stub(status: "hit", isMalicious: false))
    )
    mockApi.scanURLReturnValue = hitResponse
    let request = BlockaidScanURLRequest.stub()

    let response = try await sut.scanURL(request: request)

    XCTAssertEqual(response.data?.rawResponse.status, "hit")
    XCTAssertEqual(response.data?.rawResponse.isMalicious, false)
  }

  func testScanURL_missStatus_returnsMinimalResponse() async throws {
    let missResponse = BlockaidScanURLResponse.stub(
      data: .stub(rawResponse: .stub(status: "miss"))
    )
    mockApi.scanURLReturnValue = missResponse
    let request = BlockaidScanURLRequest.stub()

    let response = try await sut.scanURL(request: request)

    XCTAssertEqual(response.data?.rawResponse.status, "miss")
  }

  func testScanURL_error_throwsError() async {
    mockApi.scanURLError = URLError(.cannotConnectToHost)
    let request = BlockaidScanURLRequest.stub()

    do {
      _ = try await sut.scanURL(request: request)
      XCTFail("Expected error")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  // MARK: - Thread Safety Tests

  func testConcurrentCalls_multipleRequests_allSucceed() async throws {
    mockApi.scanEVMTxReturnValue = .stub()
    mockApi.scanSolanaTxReturnValue = .stub()
    mockApi.scanAddressReturnValue = .stub()

    async let evmResult = sut.scanEVMTx(request: .stub())
    async let solanaResult = sut.scanSolanaTx(request: .stub())
    async let addressResult = sut.scanAddress(request: .stub())

    let results = try await (evmResult, solanaResult, addressResult)

    XCTAssertNotNil(results.0.data)
    XCTAssertNotNil(results.1.data)
    XCTAssertNotNil(results.2.data)
  }
}
