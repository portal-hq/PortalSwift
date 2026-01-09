//
//  ZeroXTests.swift
//  PortalSwift
//
//  Created by Portal Labs
//

import Foundation
@testable import PortalSwift
import XCTest

final class ZeroXTests: XCTestCase {
  var apiMock: PortalZeroXTradingApiMock!
  var zeroX: ZeroX!

  override func setUpWithError() throws {
    apiMock = PortalZeroXTradingApiMock()
    zeroX = ZeroX(api: apiMock)
  }

  override func tearDownWithError() throws {
    apiMock = nil
    zeroX = nil
  }
}

// MARK: - Initialization Tests

extension ZeroXTests {
  func test_init_createsInstanceSuccessfully() {
    // given
    let api = PortalZeroXTradingApiMock()

    // when
    let zeroXInstance = ZeroX(api: api)

    // then
    XCTAssertNotNil(zeroXInstance)
  }

  func test_init_conformsToZeroXProtocol() {
    // given
    let api = PortalZeroXTradingApiMock()

    // when
    let zeroXInstance = ZeroX(api: api)

    // then
    XCTAssertTrue(zeroXInstance is ZeroXProtocol)
  }

  func test_init_withMockApi() {
    // given
    let api = PortalZeroXTradingApiMock()

    // when
    let zeroXInstance = ZeroX(api: api)

    // then
    XCTAssertNotNil(zeroXInstance)
  }
}

// MARK: - getSources Tests

extension ZeroXTests {
  func test_getSources_returnsSourcesSuccessfully() async throws {
    // given
    let mockResponse = ZeroXSourcesResponse.stub()
    apiMock.getSourcesReturnValue = mockResponse

    // when
    let response = try await zeroX.getSources(chainId: "eip155:1", zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(apiMock.getSourcesCalls, 1)
  }

  func test_getSources_withMinimalRequest() async throws {
    // given
    let mockResponse = ZeroXSourcesResponse.stub()
    apiMock.getSourcesReturnValue = mockResponse

    // when
    let response = try await zeroX.getSources(chainId: "eip155:1", zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getSourcesCalls, 1)
  }

  func test_getSources_withZeroXApiKey() async throws {
    // given
    let mockResponse = ZeroXSourcesResponse.stub()
    apiMock.getSourcesReturnValue = mockResponse
    let zeroXApiKey = "test-api-key"

    // when
    let response = try await zeroX.getSources(chainId: "eip155:1", zeroXApiKey: zeroXApiKey)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getSourcesZeroXApiKeyParam, "test-api-key")
  }

  func test_getSources_withDifferentChainIds() async throws {
    // given
    let mockResponse = ZeroXSourcesResponse.stub()
    apiMock.getSourcesReturnValue = mockResponse
    let chainIds = ["eip155:1", "eip155:137", "eip155:42161", "eip155:10"]

    // when
    for chainId in chainIds {
      _ = try await zeroX.getSources(chainId: chainId, zeroXApiKey: nil)
    }

    // then
    XCTAssertEqual(apiMock.getSourcesCalls, 4)
  }

  func test_getSources_withEmptySources() async throws {
    // given
    let mockResponse = ZeroXSourcesResponse(data: ZeroXSourcesData(rawResponse: ZeroXSourcesRawResponse(sources: [], zid: "test-zid")))
    apiMock.getSourcesReturnValue = mockResponse

    // when
    let response = try await zeroX.getSources(chainId: "eip155:1", zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response.data)
    XCTAssertEqual(response.data?.rawResponse.sources.count ?? -1, 0)
  }

  func test_getSources_withMultipleSources() async throws {
    // given
    let sources = ["Uniswap", "Sushiswap", "Curve", "Balancer", "1inch"]
    let mockResponse = ZeroXSourcesResponse(data: ZeroXSourcesData(rawResponse: ZeroXSourcesRawResponse(sources: sources, zid: "test-zid")))
    apiMock.getSourcesReturnValue = mockResponse

    // when
    let response = try await zeroX.getSources(chainId: "eip155:1", zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response.data)
    XCTAssertEqual(response.data?.rawResponse.sources.count ?? -1, 5)
    XCTAssertTrue(response.data?.rawResponse.sources.contains("Uniswap") ?? false)
    XCTAssertTrue(response.data?.rawResponse.sources.contains("1inch") ?? false)
  }

  func test_getSources_throwsError() async throws {
    // given
    let expectedError = NSError(domain: "TestError", code: 500, userInfo: nil)
    apiMock.getSourcesError = expectedError

    // when/then
    do {
      _ = try await zeroX.getSources(chainId: "eip155:1", zeroXApiKey: nil)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual((error as NSError).code, 500)
    }
  }

  func test_getSources_callsApiCorrectly() async throws {
    // given
    let mockResponse = ZeroXSourcesResponse.stub()
    apiMock.getSourcesReturnValue = mockResponse
    let zeroXApiKey = "my-api-key"

    // when
    _ = try await zeroX.getSources(chainId: "eip155:137", zeroXApiKey: zeroXApiKey)

    // then
    XCTAssertEqual(apiMock.getSourcesChainIdParam, "eip155:137")
    XCTAssertEqual(apiMock.getSourcesZeroXApiKeyParam, "my-api-key")
  }
}

// MARK: - getQuote Tests

extension ZeroXTests {
  func test_getQuote_returnsQuoteSuccessfully() async throws {
    // given
    let mockResponse = ZeroXQuoteResponse.stub()
    apiMock.getQuoteReturnValue = mockResponse
    let request = ZeroXQuoteRequest.stub()

    // when
    let response = try await zeroX.getQuote(request: request, zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(apiMock.getQuoteCalls, 1)
  }

  func test_getQuote_withMinimalRequest() async throws {
    // given
    let mockResponse = ZeroXQuoteResponse.stub()
    apiMock.getQuoteReturnValue = mockResponse
    let request = ZeroXQuoteRequest(
      chainId: "eip155:1",
      buyToken: "USDC",
      sellToken: "ETH",
      sellAmount: "1000000000000000000"
    )

    // when
    let response = try await zeroX.getQuote(request: request, zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getQuoteCalls, 1)
  }

  func test_getQuote_withFullRequest() async throws {
    // given
    let mockResponse = ZeroXQuoteResponse.stub()
    apiMock.getQuoteReturnValue = mockResponse
    let request = ZeroXQuoteRequest(
      chainId: "eip155:1",
      buyToken: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      sellToken: "0x0000000000000000000000000000000000000000",
      sellAmount: "1000000000000000000",
      txOrigin: "0x1234567890abcdef1234567890abcdef12345678",
      swapFeeRecipient: "0xfee",
      swapFeeBps: 100,
      swapFeeToken: "USDC",
      tradeSurplusRecipient: "0xsurplus",
      gasPrice: "50000000000",
      slippageBps: 50,
      excludedSources: "Uniswap,Sushiswap",
      sellEntireBalance: false
    )

    // when
    let response = try await zeroX.getQuote(request: request, zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertNotNil(response.data?.rawResponse)
  }

  func test_getQuote_withZeroXApiKey() async throws {
    // given
    let mockResponse = ZeroXQuoteResponse.stub()
    apiMock.getQuoteReturnValue = mockResponse
    let request = ZeroXQuoteRequest.stub()
    let zeroXApiKey = "test-api-key"

    // when
    _ = try await zeroX.getQuote(request: request, zeroXApiKey: zeroXApiKey)

    // then
    XCTAssertEqual(apiMock.getQuoteZeroXApiKeyParam, "test-api-key")
  }

  func test_getQuote_withDifferentTokens() async throws {
    // given
    let mockResponse = ZeroXQuoteResponse.stub()
    apiMock.getQuoteReturnValue = mockResponse

    let tokenPairs = [
      ("ETH", "USDC"),
      ("USDC", "USDT"),
      ("WETH", "DAI"),
      ("MATIC", "USDC")
    ]

    // when
    for (sellToken, buyToken) in tokenPairs {
      let request = ZeroXQuoteRequest.stub(buyToken: buyToken, sellToken: sellToken)
      _ = try await zeroX.getQuote(request: request, zeroXApiKey: nil)
    }

    // then
    XCTAssertEqual(apiMock.getQuoteCalls, 4)
  }

  func test_getQuote_returnsTransaction() async throws {
    // given
    let transaction = ZeroXTransaction.stub(
      data: "0xabcdef",
      from: "0xfrom",
      gas: "100000",
      gasPrice: "50000000000",
      to: "0xto",
      value: "1000000000000000000"
    )
    let quoteData = ZeroXQuoteRawResponse.stub(transaction: transaction)
    let mockResponse = ZeroXQuoteResponse(data: ZeroXQuoteResponseData(rawResponse: quoteData))
    apiMock.getQuoteReturnValue = mockResponse
    let request = ZeroXQuoteRequest.stub()

    // when
    let response = try await zeroX.getQuote(request: request, zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response.data)
    XCTAssertEqual(response.data?.rawResponse.transaction.data ?? "", "0xabcdef")
    XCTAssertEqual(response.data?.rawResponse.transaction.from ?? "", "0xfrom")
    XCTAssertEqual(response.data?.rawResponse.transaction.gas ?? "", "100000")
  }

  func test_getQuote_returnsIssues() async throws {
    // given
    let issues = ZeroXIssues.stub(
      allowance: ZeroXAllowanceIssue.stub(),
      balance: nil,
      simulationIncomplete: true,
      invalidSourcesPassed: ["InvalidSource"]
    )
    let quoteData = ZeroXQuoteRawResponse.stub(issues: issues)
    let mockResponse = ZeroXQuoteResponse(data: ZeroXQuoteResponseData(rawResponse: quoteData))
    apiMock.getQuoteReturnValue = mockResponse
    let request = ZeroXQuoteRequest.stub()

    // when
    let response = try await zeroX.getQuote(request: request, zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response.data)
    XCTAssertNotNil(response.data?.rawResponse.issues)
    XCTAssertNotNil(response.data?.rawResponse.issues?.allowance)
    XCTAssertEqual(response.data?.rawResponse.issues?.simulationIncomplete ?? false, true)
    XCTAssertEqual(response.data?.rawResponse.issues?.invalidSourcesPassed ?? [], ["InvalidSource"])
    // Verify optional fields can be nil
    XCTAssertNil(response.data?.rawResponse.issues?.balance)
  }

  func test_getQuote_throwsError() async throws {
    // given
    let expectedError = NSError(domain: "TestError", code: 400, userInfo: nil)
    apiMock.getQuoteError = expectedError
    let request = ZeroXQuoteRequest.stub()

    // when/then
    do {
      _ = try await zeroX.getQuote(request: request, zeroXApiKey: nil)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual((error as NSError).code, 400)
    }
  }

  func test_getQuote_callsApiCorrectly() async throws {
    // given
    let mockResponse = ZeroXQuoteResponse.stub()
    apiMock.getQuoteReturnValue = mockResponse
    let request = ZeroXQuoteRequest.stub(
      chainId: "eip155:137",
      buyToken: "MATIC",
      sellToken: "USDC",
      sellAmount: "5000000"
    )
    let zeroXApiKey = "my-api-key"

    // when
    _ = try await zeroX.getQuote(request: request, zeroXApiKey: zeroXApiKey)

    // then
    XCTAssertEqual(apiMock.getQuoteRequestParam?.chainId, "eip155:137")
    XCTAssertEqual(apiMock.getQuoteRequestParam?.buyToken, "MATIC")
    XCTAssertEqual(apiMock.getQuoteRequestParam?.sellToken, "USDC")
    XCTAssertEqual(apiMock.getQuoteZeroXApiKeyParam, "my-api-key")
  }
}

// MARK: - getPrice Tests

extension ZeroXTests {
  func test_getPrice_returnsPriceSuccessfully() async throws {
    // given
    let mockResponse = ZeroXPriceResponse.stub()
    apiMock.getPriceReturnValue = mockResponse
    let request = ZeroXPriceRequest.stub()

    // when
    let response = try await zeroX.getPrice(request: request, zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(apiMock.getPriceCalls, 1)
  }

  func test_getPrice_withMinimalRequest() async throws {
    // given
    let mockResponse = ZeroXPriceResponse.stub()
    apiMock.getPriceReturnValue = mockResponse
    let request = ZeroXPriceRequest(
      chainId: "eip155:1",
      buyToken: "USDC",
      sellToken: "ETH",
      sellAmount: "1000000000000000000"
    )

    // when
    let response = try await zeroX.getPrice(request: request, zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getPriceCalls, 1)
  }

  func test_getPrice_returnsFees() async throws {
    // given
    let fees = ZeroXFees.stub(
      integratorFee: ZeroXFeeDetail.stub(amount: "100", token: "ETH", type: "integrator"),
      zeroExFee: ZeroXZeroExFeeDetail.stub(),
      gasFee: ZeroXFeeDetail.stub()
    )
    let priceData = ZeroXPriceRawResponse.stub(fees: fees)
    let mockResponse = ZeroXPriceResponse(data: ZeroXPriceResponseData(rawResponse: priceData))
    apiMock.getPriceReturnValue = mockResponse
    let request = ZeroXPriceRequest.stub()

    // when
    let response = try await zeroX.getPrice(request: request, zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response.data)
    XCTAssertNotNil(response.data?.rawResponse.fees)
    XCTAssertNotNil(response.data?.rawResponse.fees?.integratorFee)
    XCTAssertNotNil(response.data?.rawResponse.fees?.zeroExFee)
    XCTAssertNotNil(response.data?.rawResponse.fees?.gasFee)
    // Verify optional fee fields can be accessed
    XCTAssertEqual(response.data?.rawResponse.fees?.integratorFee?.amount ?? "", "100")
    XCTAssertEqual(response.data?.rawResponse.fees?.integratorFee?.token ?? "", "ETH")
  }

  func test_getPrice_returnsIssues() async throws {
    // given
    let issues = ZeroXIssues.stub(simulationIncomplete: true)
    let priceData = ZeroXPriceRawResponse.stub(issues: issues)
    let mockResponse = ZeroXPriceResponse(data: ZeroXPriceResponseData(rawResponse: priceData))
    apiMock.getPriceReturnValue = mockResponse
    let request = ZeroXPriceRequest.stub()

    // when
    let response = try await zeroX.getPrice(request: request, zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response.data)
    XCTAssertNotNil(response.data?.rawResponse.issues)
    XCTAssertEqual(response.data?.rawResponse.issues?.simulationIncomplete ?? false, true)
  }

  func test_getQuote_handlesOptionalFields() async throws {
    // given - quote with minimal fields (optional fields are nil)
    let quoteData = ZeroXQuoteRawResponse(
      blockNumber: nil,
      buyAmount: "3000000000",
      buyToken: nil,
      fees: nil,
      issues: nil,
      liquidityAvailable: nil,
      minBuyAmount: nil,
      route: nil,
      sellAmount: "1000000000000000000",
      sellToken: nil,
      tokenMetadata: nil,
      totalNetworkFee: nil,
      transaction: ZeroXTransaction.stub()
    )
    let mockResponse = ZeroXQuoteResponse(data: ZeroXQuoteResponseData(rawResponse: quoteData))
    apiMock.getQuoteReturnValue = mockResponse
    let request = ZeroXQuoteRequest.stub()

    // when
    let response = try await zeroX.getQuote(request: request, zeroXApiKey: nil)

    // then - verify optional fields can be nil
    XCTAssertNotNil(response.data)
    XCTAssertNotNil(response.data?.rawResponse)
    XCTAssertNil(response.data?.rawResponse.blockNumber)
    XCTAssertNil(response.data?.rawResponse.buyToken)
    XCTAssertNil(response.data?.rawResponse.fees)
    XCTAssertNil(response.data?.rawResponse.issues)
    XCTAssertNil(response.data?.rawResponse.liquidityAvailable)
    XCTAssertNil(response.data?.rawResponse.minBuyAmount)
    XCTAssertNil(response.data?.rawResponse.route)
    XCTAssertNil(response.data?.rawResponse.sellToken)
    XCTAssertNil(response.data?.rawResponse.tokenMetadata)
    XCTAssertNil(response.data?.rawResponse.totalNetworkFee)
    // Required fields should still be present
    XCTAssertEqual(response.data?.rawResponse.buyAmount ?? "", "3000000000")
    XCTAssertEqual(response.data?.rawResponse.sellAmount ?? "", "1000000000000000000")
    XCTAssertNotNil(response.data?.rawResponse.transaction)
  }

  func test_getPrice_handlesOptionalFields() async throws {
    // given - price with minimal fields (optional fields are nil)
    let priceData = ZeroXPriceRawResponse(
      blockNumber: nil,
      buyAmount: "3000000000",
      buyToken: nil,
      fees: nil,
      gas: nil,
      gasPrice: nil,
      issues: nil,
      liquidityAvailable: nil,
      minBuyAmount: nil,
      route: nil,
      sellAmount: "1000000000000000000",
      sellToken: nil,
      tokenMetadata: nil,
      totalNetworkFee: nil
    )
    let mockResponse = ZeroXPriceResponse(data: ZeroXPriceResponseData(rawResponse: priceData))
    apiMock.getPriceReturnValue = mockResponse
    let request = ZeroXPriceRequest.stub()

    // when
    let response = try await zeroX.getPrice(request: request, zeroXApiKey: nil)

    // then - verify optional fields can be nil
    XCTAssertNotNil(response.data)
    XCTAssertNotNil(response.data?.rawResponse)
    XCTAssertNil(response.data?.rawResponse.blockNumber)
    XCTAssertNil(response.data?.rawResponse.buyToken)
    XCTAssertNil(response.data?.rawResponse.fees)
    XCTAssertNil(response.data?.rawResponse.gas)
    XCTAssertNil(response.data?.rawResponse.gasPrice)
    XCTAssertNil(response.data?.rawResponse.issues)
    XCTAssertNil(response.data?.rawResponse.liquidityAvailable)
    XCTAssertNil(response.data?.rawResponse.minBuyAmount)
    XCTAssertNil(response.data?.rawResponse.route)
    XCTAssertNil(response.data?.rawResponse.sellToken)
    XCTAssertNil(response.data?.rawResponse.tokenMetadata)
    XCTAssertNil(response.data?.rawResponse.totalNetworkFee)
    // Required fields should still be present
    XCTAssertEqual(response.data?.rawResponse.buyAmount ?? "", "3000000000")
    XCTAssertEqual(response.data?.rawResponse.sellAmount ?? "", "1000000000000000000")
  }

  func test_getPrice_throwsError() async throws {
    // given
    let expectedError = NSError(domain: "TestError", code: 404, userInfo: nil)
    apiMock.getPriceError = expectedError
    let request = ZeroXPriceRequest.stub()

    // when/then
    do {
      _ = try await zeroX.getPrice(request: request, zeroXApiKey: nil)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual((error as NSError).code, 404)
    }
  }

  func test_getPrice_callsApiCorrectly() async throws {
    // given
    let mockResponse = ZeroXPriceResponse.stub()
    apiMock.getPriceReturnValue = mockResponse
    let request = ZeroXPriceRequest.stub(
      chainId: "eip155:10",
      buyToken: "OP",
      sellToken: "USDC",
      sellAmount: "1000000"
    )
    let zeroXApiKey = "price-api-key"

    // when
    _ = try await zeroX.getPrice(request: request, zeroXApiKey: zeroXApiKey)

    // then
    XCTAssertEqual(apiMock.getPriceRequestParam?.chainId, "eip155:10")
    XCTAssertEqual(apiMock.getPriceRequestParam?.buyToken, "OP")
    XCTAssertEqual(apiMock.getPriceRequestParam?.sellToken, "USDC")
    XCTAssertEqual(apiMock.getPriceZeroXApiKeyParam, "price-api-key")
  }

  func test_getPrice_differenceFromQuote() async throws {
    // given - price has fees but no transaction
    let priceData = ZeroXPriceRawResponse.stub(fees: ZeroXFees.stub())
    let priceResponse = ZeroXPriceResponse(data: ZeroXPriceResponseData(rawResponse: priceData))
    apiMock.getPriceReturnValue = priceResponse

    // when
    let response = try await zeroX.getPrice(request: ZeroXPriceRequest.stub(), zeroXApiKey: nil)

    // then - price response has fees
    XCTAssertNotNil(response.data)
    XCTAssertNotNil(response.data?.rawResponse.fees)
    // Note: price response doesn't have transaction (unlike quote)
  }
}

// MARK: - Convenience Methods Tests (Protocol Extension)

extension ZeroXTests {
  // MARK: - getSources Convenience Method Tests
  
  func test_getSources_convenienceMethod_returnsSourcesSuccessfully() async throws {
    // given
    let mockResponse = ZeroXSourcesResponse.stub()
    apiMock.getSourcesReturnValue = mockResponse

    // when - calling convenience method without zeroXApiKey
    let response = try await zeroX.getSources(chainId: "eip155:1")

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(apiMock.getSourcesCalls, 1)
    XCTAssertEqual(apiMock.getSourcesChainIdParam, "eip155:1")
    // Verify that nil was passed for zeroXApiKey
    XCTAssertNil(apiMock.getSourcesZeroXApiKeyParam)
  }

  func test_getSources_convenienceMethod_callsApiWithNilApiKey() async throws {
    // given
    let mockResponse = ZeroXSourcesResponse.stub()
    apiMock.getSourcesReturnValue = mockResponse

    // when
    _ = try await zeroX.getSources(chainId: "eip155:137")

    // then - verify nil was passed for zeroXApiKey
    XCTAssertEqual(apiMock.getSourcesCalls, 1)
    XCTAssertNil(apiMock.getSourcesZeroXApiKeyParam)
    XCTAssertEqual(apiMock.getSourcesChainIdParam, "eip155:137")
  }

  func test_getSources_convenienceMethod_withDifferentChainIds() async throws {
    // given
    let mockResponse = ZeroXSourcesResponse.stub()
    apiMock.getSourcesReturnValue = mockResponse

    // when
    _ = try await zeroX.getSources(chainId: "eip155:1")
    _ = try await zeroX.getSources(chainId: "eip155:137")
    _ = try await zeroX.getSources(chainId: "eip155:42161")

    // then
    XCTAssertEqual(apiMock.getSourcesCalls, 3)
    XCTAssertNil(apiMock.getSourcesZeroXApiKeyParam)
  }

  func test_getSources_convenienceMethod_throwsError() async throws {
    // given
    let expectedError = URLError(.badURL)
    apiMock.getSourcesError = expectedError

    // when/then
    do {
      _ = try await zeroX.getSources(chainId: "eip155:1")
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual((error as? URLError)?.code, expectedError.code)
      XCTAssertEqual(apiMock.getSourcesCalls, 1)
      XCTAssertNil(apiMock.getSourcesZeroXApiKeyParam)
    }
  }

  func test_getSources_convenienceMethod_worksWithZeroXMock() async throws {
    // given
    let zeroXMock = ZeroXMock()
    let mockResponse = ZeroXSourcesResponse.stub()
    zeroXMock.getSourcesReturnValue = mockResponse

    // when - calling convenience method on mock
    let response = try await zeroXMock.getSources(chainId: "eip155:1")

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(zeroXMock.getSourcesCalls, 1)
    XCTAssertNil(zeroXMock.getSourcesZeroXApiKeyParam)
    XCTAssertEqual(zeroXMock.getSourcesChainIdParam, "eip155:1")
  }

  // MARK: - getQuote Convenience Method Tests

  func test_getQuote_convenienceMethod_returnsQuoteSuccessfully() async throws {
    // given
    let mockResponse = ZeroXQuoteResponse.stub()
    apiMock.getQuoteReturnValue = mockResponse
    let request = ZeroXQuoteRequest.stub()

    // when - calling convenience method without zeroXApiKey
    let response = try await zeroX.getQuote(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(apiMock.getQuoteCalls, 1)
    XCTAssertEqual(apiMock.getQuoteRequestParam?.chainId, request.chainId)
    // Verify that nil was passed for zeroXApiKey
    XCTAssertNil(apiMock.getQuoteZeroXApiKeyParam)
  }

  func test_getQuote_convenienceMethod_callsApiWithNilApiKey() async throws {
    // given
    let mockResponse = ZeroXQuoteResponse.stub()
    apiMock.getQuoteReturnValue = mockResponse
    let request = ZeroXQuoteRequest.stub(
      chainId: "eip155:137",
      buyToken: "USDC",
      sellToken: "ETH",
      sellAmount: "1000000000000000000"
    )

    // when
    _ = try await zeroX.getQuote(request: request)

    // then - verify nil was passed for zeroXApiKey
    XCTAssertEqual(apiMock.getQuoteCalls, 1)
    XCTAssertNil(apiMock.getQuoteZeroXApiKeyParam)
    XCTAssertEqual(apiMock.getQuoteRequestParam?.chainId, "eip155:137")
  }

  func test_getQuote_convenienceMethod_withFullRequest() async throws {
    // given
    let mockResponse = ZeroXQuoteResponse.stub()
    apiMock.getQuoteReturnValue = mockResponse
    let request = ZeroXQuoteRequest.stub(
      chainId: "eip155:1",
      buyToken: "USDC",
      sellToken: "ETH",
      sellAmount: "1000000000000000000",
      slippageBps: 50,
      excludedSources: "Uniswap",
      sellEntireBalance: true
    )

    // when
    let response = try await zeroX.getQuote(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getQuoteCalls, 1)
    XCTAssertNil(apiMock.getQuoteZeroXApiKeyParam)
    XCTAssertEqual(apiMock.getQuoteRequestParam?.buyToken, "USDC")
    XCTAssertEqual(apiMock.getQuoteRequestParam?.sellToken, "ETH")
  }

  func test_getQuote_convenienceMethod_returnsTransaction() async throws {
    // given
    let transaction = ZeroXTransaction.stub()
    let quoteData = ZeroXQuoteRawResponse.stub(transaction: transaction)
    let mockResponse = ZeroXQuoteResponse(data: ZeroXQuoteResponseData(rawResponse: quoteData))
    apiMock.getQuoteReturnValue = mockResponse
    let request = ZeroXQuoteRequest.stub()

    // when
    let response = try await zeroX.getQuote(request: request)

    // then
    XCTAssertNotNil(response.data)
    XCTAssertNotNil(response.data?.rawResponse.transaction)
    XCTAssertEqual(apiMock.getQuoteCalls, 1)
    XCTAssertNil(apiMock.getQuoteZeroXApiKeyParam)
  }

  func test_getQuote_convenienceMethod_throwsError() async throws {
    // given
    let expectedError = URLError(.badURL)
    apiMock.getQuoteError = expectedError
    let request = ZeroXQuoteRequest.stub()

    // when/then
    do {
      _ = try await zeroX.getQuote(request: request)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual((error as? URLError)?.code, expectedError.code)
      XCTAssertEqual(apiMock.getQuoteCalls, 1)
      XCTAssertNil(apiMock.getQuoteZeroXApiKeyParam)
    }
  }

  func test_getQuote_convenienceMethod_worksWithZeroXMock() async throws {
    // given
    let zeroXMock = ZeroXMock()
    let mockResponse = ZeroXQuoteResponse.stub()
    zeroXMock.getQuoteReturnValue = mockResponse
    let request = ZeroXQuoteRequest.stub()

    // when - calling convenience method on mock
    let response = try await zeroXMock.getQuote(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(zeroXMock.getQuoteCalls, 1)
    XCTAssertNil(zeroXMock.getQuoteZeroXApiKeyParam)
    XCTAssertEqual(zeroXMock.getQuoteRequestParam?.chainId, request.chainId)
  }

  // MARK: - getPrice Convenience Method Tests

  func test_getPrice_convenienceMethod_returnsPriceSuccessfully() async throws {
    // given
    let mockResponse = ZeroXPriceResponse.stub()
    apiMock.getPriceReturnValue = mockResponse
    let request = ZeroXPriceRequest.stub()

    // when - calling convenience method without zeroXApiKey
    let response = try await zeroX.getPrice(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(apiMock.getPriceCalls, 1)
    XCTAssertEqual(apiMock.getPriceRequestParam?.chainId, request.chainId)
    // Verify that nil was passed for zeroXApiKey
    XCTAssertNil(apiMock.getPriceZeroXApiKeyParam)
  }

  func test_getPrice_convenienceMethod_callsApiWithNilApiKey() async throws {
    // given
    let mockResponse = ZeroXPriceResponse.stub()
    apiMock.getPriceReturnValue = mockResponse
    let request = ZeroXPriceRequest.stub(
      chainId: "eip155:137",
      buyToken: "USDC",
      sellToken: "USDT",
      sellAmount: "1000000000"
    )

    // when
    _ = try await zeroX.getPrice(request: request)

    // then - verify nil was passed for zeroXApiKey
    XCTAssertEqual(apiMock.getPriceCalls, 1)
    XCTAssertNil(apiMock.getPriceZeroXApiKeyParam)
    XCTAssertEqual(apiMock.getPriceRequestParam?.chainId, "eip155:137")
  }

  func test_getPrice_convenienceMethod_withFullRequest() async throws {
    // given
    let mockResponse = ZeroXPriceResponse.stub()
    apiMock.getPriceReturnValue = mockResponse
    let request = ZeroXPriceRequest.stub(
      chainId: "eip155:1",
      buyToken: "USDC",
      sellToken: "ETH",
      sellAmount: "1000000000000000000",
      slippageBps: 50,
      excludedSources: "Uniswap",
      sellEntireBalance: true
    )

    // when
    let response = try await zeroX.getPrice(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getPriceCalls, 1)
    XCTAssertNil(apiMock.getPriceZeroXApiKeyParam)
    XCTAssertEqual(apiMock.getPriceRequestParam?.buyToken, "USDC")
    XCTAssertEqual(apiMock.getPriceRequestParam?.sellToken, "ETH")
  }

  func test_getPrice_convenienceMethod_returnsFees() async throws {
    // given
    let fees = ZeroXFees.stub()
    let priceData = ZeroXPriceRawResponse.stub(fees: fees)
    let mockResponse = ZeroXPriceResponse(data: ZeroXPriceResponseData(rawResponse: priceData))
    apiMock.getPriceReturnValue = mockResponse
    let request = ZeroXPriceRequest.stub()

    // when
    let response = try await zeroX.getPrice(request: request)

    // then
    XCTAssertNotNil(response.data)
    XCTAssertNotNil(response.data?.rawResponse.fees)
    XCTAssertEqual(apiMock.getPriceCalls, 1)
    XCTAssertNil(apiMock.getPriceZeroXApiKeyParam)
  }

  func test_getPrice_convenienceMethod_throwsError() async throws {
    // given
    let expectedError = URLError(.badURL)
    apiMock.getPriceError = expectedError
    let request = ZeroXPriceRequest.stub()

    // when/then
    do {
      _ = try await zeroX.getPrice(request: request)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual((error as? URLError)?.code, expectedError.code)
      XCTAssertEqual(apiMock.getPriceCalls, 1)
      XCTAssertNil(apiMock.getPriceZeroXApiKeyParam)
    }
  }

  func test_getPrice_convenienceMethod_worksWithZeroXMock() async throws {
    // given
    let zeroXMock = ZeroXMock()
    let mockResponse = ZeroXPriceResponse.stub()
    zeroXMock.getPriceReturnValue = mockResponse
    let request = ZeroXPriceRequest.stub()

    // when - calling convenience method on mock
    let response = try await zeroXMock.getPrice(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(zeroXMock.getPriceCalls, 1)
    XCTAssertNil(zeroXMock.getPriceZeroXApiKeyParam)
    XCTAssertEqual(zeroXMock.getPriceRequestParam?.chainId, request.chainId)
  }

  // MARK: - Convenience Methods Comparison Tests

  func test_convenienceMethods_equivalentToPassingNil() async throws {
    // given
    let sourcesResponse = ZeroXSourcesResponse.stub()
    let quoteResponse = ZeroXQuoteResponse.stub()
    let priceResponse = ZeroXPriceResponse.stub()
    apiMock.getSourcesReturnValue = sourcesResponse
    apiMock.getQuoteReturnValue = quoteResponse
    apiMock.getPriceReturnValue = priceResponse
    let quoteRequest = ZeroXQuoteRequest.stub()
    let priceRequest = ZeroXPriceRequest.stub()

    // when - call both convenience and explicit nil methods
    let sources1 = try await zeroX.getSources(chainId: "eip155:1")
    let sources2 = try await zeroX.getSources(chainId: "eip155:1", zeroXApiKey: nil)
    
    let quote1 = try await zeroX.getQuote(request: quoteRequest)
    let quote2 = try await zeroX.getQuote(request: quoteRequest, zeroXApiKey: nil)
    
    let price1 = try await zeroX.getPrice(request: priceRequest)
    let price2 = try await zeroX.getPrice(request: priceRequest, zeroXApiKey: nil)

    // then - both should produce same results
    XCTAssertNotNil(sources1.data)
    XCTAssertNotNil(sources2.data)
    XCTAssertEqual(sources1.data?.rawResponse.sources ?? [], sources2.data?.rawResponse.sources ?? [])
    XCTAssertNotNil(quote1.data)
    XCTAssertNotNil(quote2.data)
    XCTAssertEqual(quote1.data?.rawResponse.buyAmount ?? "", quote2.data?.rawResponse.buyAmount ?? "")
    XCTAssertNotNil(price1.data)
    XCTAssertNotNil(price2.data)
    XCTAssertEqual(price1.data?.rawResponse.buyAmount ?? "", price2.data?.rawResponse.buyAmount ?? "")
    
    // Verify all calls passed nil for zeroXApiKey
    XCTAssertNil(apiMock.getSourcesZeroXApiKeyParam)
    XCTAssertNil(apiMock.getQuoteZeroXApiKeyParam)
    XCTAssertNil(apiMock.getPriceZeroXApiKeyParam)
  }

  func test_convenienceMethods_canBeMixedWithExplicitApiKey() async throws {
    // given
    let sourcesResponse = ZeroXSourcesResponse.stub()
    let quoteResponse = ZeroXQuoteResponse.stub()
    apiMock.getSourcesReturnValue = sourcesResponse
    apiMock.getQuoteReturnValue = quoteResponse
    let quoteRequest = ZeroXQuoteRequest.stub()
    let apiKey = "custom-api-key"

    // when - mix convenience and explicit API key methods
    _ = try await zeroX.getSources(chainId: "eip155:1") // convenience
    _ = try await zeroX.getSources(chainId: "eip155:1", zeroXApiKey: apiKey) // explicit
    
    _ = try await zeroX.getQuote(request: quoteRequest) // convenience
    _ = try await zeroX.getQuote(request: quoteRequest, zeroXApiKey: apiKey) // explicit

    // then - verify both patterns work
    XCTAssertEqual(apiMock.getSourcesCalls, 2)
    XCTAssertEqual(apiMock.getQuoteCalls, 2)
    // Last call should have API key
    XCTAssertEqual(apiMock.getSourcesZeroXApiKeyParam, apiKey)
    XCTAssertEqual(apiMock.getQuoteZeroXApiKeyParam, apiKey)
  }

  func test_convenienceMethods_workThroughProtocolType() async throws {
    // given
    let sourcesResponse = ZeroXSourcesResponse.stub()
    let quoteResponse = ZeroXQuoteResponse.stub()
    let priceResponse = ZeroXPriceResponse.stub()
    apiMock.getSourcesReturnValue = sourcesResponse
    apiMock.getQuoteReturnValue = quoteResponse
    apiMock.getPriceReturnValue = priceResponse
    
    // Cast to protocol type (as it would be used in Trading.zeroX)
    let zeroXProtocol: ZeroXProtocol = zeroX
    let quoteRequest = ZeroXQuoteRequest.stub()
    let priceRequest = ZeroXPriceRequest.stub()

    // when - call convenience methods through protocol type
    let sources = try await zeroXProtocol.getSources(chainId: "eip155:1")
    let quote = try await zeroXProtocol.getQuote(request: quoteRequest)
    let price = try await zeroXProtocol.getPrice(request: priceRequest)

    // then
    XCTAssertNotNil(sources)
    XCTAssertNotNil(quote)
    XCTAssertNotNil(price)
    XCTAssertEqual(apiMock.getSourcesCalls, 1)
    XCTAssertEqual(apiMock.getQuoteCalls, 1)
    XCTAssertEqual(apiMock.getPriceCalls, 1)
    // All should pass nil for zeroXApiKey
    XCTAssertNil(apiMock.getSourcesZeroXApiKeyParam)
    XCTAssertNil(apiMock.getQuoteZeroXApiKeyParam)
    XCTAssertNil(apiMock.getPriceZeroXApiKeyParam)
  }
}

// MARK: - Multiple Instance Tests

extension ZeroXTests {
  func test_multipleInstances_haveIndependentApis() {
    // given
    let api1 = PortalZeroXTradingApiMock()
    let api2 = PortalZeroXTradingApiMock()

    // when
    let zeroX1 = ZeroX(api: api1)
    let zeroX2 = ZeroX(api: api2)

    // then
    XCTAssertFalse(zeroX1 === zeroX2)
  }

  func test_multipleInstances_canOperateIndependently() async throws {
    // given
    let api1 = PortalZeroXTradingApiMock()
    api1.getSourcesReturnValue = ZeroXSourcesResponse.stub()
    let api2 = PortalZeroXTradingApiMock()
    api2.getSourcesReturnValue = ZeroXSourcesResponse.stub()

    let zeroX1 = ZeroX(api: api1)
    let zeroX2 = ZeroX(api: api2)

    // when
    _ = try await zeroX1.getSources(chainId: "eip155:1", zeroXApiKey: nil)
    _ = try await zeroX2.getSources(chainId: "eip155:137", zeroXApiKey: nil)

    // then
    XCTAssertEqual(api1.getSourcesCalls, 1)
    XCTAssertEqual(api2.getSourcesCalls, 1)
  }
}

// MARK: - Thread Safety Tests

extension ZeroXTests {
  func test_concurrentCalls_areHandledCorrectly() async throws {
    // given
    let mockResponse = ZeroXSourcesResponse.stub()
    apiMock.getSourcesReturnValue = mockResponse
    let callCount = 10

    // when
    await withTaskGroup(of: ZeroXSourcesResponse.self) { group in
      for _ in 0 ..< callCount {
        group.addTask {
          try! await self.zeroX.getSources(chainId: "eip155:1", zeroXApiKey: nil)
        }
      }

      var responses: [ZeroXSourcesResponse] = []
      for await response in group {
        responses.append(response)
      }

      // then
      XCTAssertEqual(responses.count, callCount)
    }

    XCTAssertEqual(apiMock.getSourcesCalls, callCount)
  }
}

// MARK: - Protocol Conformance Tests

extension ZeroXTests {
  func test_zeroX_conformsToZeroXProtocol() {
    // given
    let zeroXInstance: ZeroXProtocol = zeroX

    // then
    XCTAssertNotNil(zeroXInstance)
    XCTAssertTrue(zeroXInstance is ZeroXProtocol)
  }

  func test_zeroXMock_conformsToZeroXProtocol() {
    // given
    let zeroXMock = ZeroXMock()

    // when
    let conformsToProtocol = zeroXMock is ZeroXProtocol

    // then
    XCTAssertTrue(conformsToProtocol)
  }

  func test_protocol_canBeUsedPolymorphically() {
    // given
    let implementations: [ZeroXProtocol] = [
      ZeroX(api: PortalZeroXTradingApiMock()),
      ZeroXMock()
    ]

    // when & then
    for implementation in implementations {
      XCTAssertNotNil(implementation)
      XCTAssertTrue(implementation is ZeroXProtocol)
    }
  }
}

// MARK: - Mock Behavior Tests

extension ZeroXTests {
  func test_zeroXMock_defaultReturnValues() async throws {
    // given
    let zeroXMock = ZeroXMock()

    // when - calling methods without setting return values
    let sourcesResponse = try await zeroXMock.getSources(chainId: "eip155:1", zeroXApiKey: nil)
    let quoteResponse = try await zeroXMock.getQuote(request: ZeroXQuoteRequest.stub(), zeroXApiKey: nil)
    let priceResponse = try await zeroXMock.getPrice(request: ZeroXPriceRequest.stub(), zeroXApiKey: nil)

    // then - should return stub values
    XCTAssertNotNil(sourcesResponse)
    XCTAssertNotNil(quoteResponse)
    XCTAssertNotNil(priceResponse)
  }

  func test_zeroXMock_customReturnValues() async throws {
    // given
    let customSources = ZeroXSourcesResponse(data: ZeroXSourcesData(rawResponse: ZeroXSourcesRawResponse(sources: ["CustomSource"], zid: "test-zid")))
    let zeroXMock = ZeroXMock()
    zeroXMock.getSourcesReturnValue = customSources

    // when
    let response = try await zeroXMock.getSources(chainId: "eip155:1", zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response.data)
    XCTAssertEqual(response.data?.rawResponse.sources ?? [], ["CustomSource"])
  }

  func test_zeroXMock_parameterCapture() async throws {
    // given
    let zeroXMock = ZeroXMock()
    let zeroXApiKey = "captured-key"

    // when
    _ = try await zeroXMock.getSources(chainId: "eip155:42161", zeroXApiKey: zeroXApiKey)

    // then - should capture the parameters
    XCTAssertEqual(zeroXMock.getSourcesChainIdParam, "eip155:42161")
    XCTAssertEqual(zeroXMock.getSourcesZeroXApiKeyParam, "captured-key")
  }

  func test_zeroXMock_tracksMultipleCalls() async throws {
    // given
    let zeroXMock = ZeroXMock()

    // when
    _ = try await zeroXMock.getSources(chainId: "eip155:1", zeroXApiKey: nil)
    _ = try await zeroXMock.getSources(chainId: "eip155:137", zeroXApiKey: nil)
    _ = try await zeroXMock.getSources(chainId: "eip155:10", zeroXApiKey: nil)

    // then
    XCTAssertEqual(zeroXMock.getSourcesCalls, 3)
  }

  func test_zeroXMock_tracksDifferentMethodCalls() async throws {
    // given
    let zeroXMock = ZeroXMock()

    // when
    _ = try await zeroXMock.getSources(chainId: "eip155:1", zeroXApiKey: nil)
    _ = try await zeroXMock.getQuote(request: ZeroXQuoteRequest.stub(), zeroXApiKey: nil)
    _ = try await zeroXMock.getPrice(request: ZeroXPriceRequest.stub(), zeroXApiKey: nil)

    // then
    XCTAssertEqual(zeroXMock.getSourcesCalls, 1)
    XCTAssertEqual(zeroXMock.getQuoteCalls, 1)
    XCTAssertEqual(zeroXMock.getPriceCalls, 1)
  }

  func test_zeroXMock_reset() async throws {
    // given
    let zeroXMock = ZeroXMock()
    _ = try await zeroXMock.getSources(chainId: "eip155:1", zeroXApiKey: nil)
    XCTAssertEqual(zeroXMock.getSourcesCalls, 1)

    // when
    zeroXMock.reset()

    // then
    XCTAssertEqual(zeroXMock.getSourcesCalls, 0)
    XCTAssertNil(zeroXMock.getSourcesChainIdParam)
    XCTAssertNil(zeroXMock.getSourcesReturnValue)
  }

  func test_zeroXMock_errorSimulation() async throws {
    // given
    let zeroXMock = ZeroXMock()
    let testError = NSError(domain: "TestError", code: 500, userInfo: nil)
    zeroXMock.getSourcesError = testError

    // when/then
    do {
      _ = try await zeroXMock.getSources(chainId: "eip155:1", zeroXApiKey: nil)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual((error as NSError).code, 500)
    }
  }
}

// MARK: - Error Handling Tests

extension ZeroXTests {
  func test_getSources_throwsURLError() async throws {
    // given
    let expectedError = URLError(.notConnectedToInternet)
    apiMock.getSourcesError = expectedError

    // when/then
    do {
      _ = try await zeroX.getSources(chainId: "eip155:1", zeroXApiKey: nil)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertTrue(error is URLError)
      XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
    }
  }

  func test_getQuote_throwsDecodingError() async throws {
    // given
    let expectedError = DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Invalid JSON"))
    apiMock.getQuoteError = expectedError

    // when/then
    do {
      _ = try await zeroX.getQuote(request: ZeroXQuoteRequest.stub(), zeroXApiKey: nil)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertTrue(error is DecodingError)
    }
  }
}

// MARK: - Edge Cases Tests

extension ZeroXTests {
  func test_getQuote_withVeryLargeAmount() async throws {
    // given
    let mockResponse = ZeroXQuoteResponse.stub()
    apiMock.getQuoteReturnValue = mockResponse
    let request = ZeroXQuoteRequest.stub(sellAmount: "999999999999999999999999999999999999")

    // when
    let response = try await zeroX.getQuote(request: request, zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getQuoteRequestParam?.sellAmount, "999999999999999999999999999999999999")
  }

  func test_getQuote_withZeroAmount() async throws {
    // given
    let mockResponse = ZeroXQuoteResponse.stub()
    apiMock.getQuoteReturnValue = mockResponse
    let request = ZeroXQuoteRequest.stub(sellAmount: "0")

    // when
    let response = try await zeroX.getQuote(request: request, zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getQuoteRequestParam?.sellAmount, "0")
  }

  func test_getQuote_withMaxSlippageBps() async throws {
    // given
    let mockResponse = ZeroXQuoteResponse.stub()
    apiMock.getQuoteReturnValue = mockResponse
    let request = ZeroXQuoteRequest.stub(slippageBps: 10000) // 100%

    // when
    let response = try await zeroX.getQuote(request: request, zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getQuoteRequestParam?.slippageBps, 10000)
  }

  func test_getQuote_withZeroSlippageBps() async throws {
    // given
    let mockResponse = ZeroXQuoteResponse.stub()
    apiMock.getQuoteReturnValue = mockResponse
    let request = ZeroXQuoteRequest.stub(slippageBps: 0)

    // when
    let response = try await zeroX.getQuote(request: request, zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getQuoteRequestParam?.slippageBps, 0)
  }

  func test_getSources_withEmptyChainId() async throws {
    // given
    let mockResponse = ZeroXSourcesResponse.stub()
    apiMock.getSourcesReturnValue = mockResponse

    // when
    let response = try await zeroX.getSources(chainId: "", zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getSourcesChainIdParam, "")
  }

  func test_getQuote_withSpecialCharactersInChainId() async throws {
    // given
    let mockResponse = ZeroXQuoteResponse.stub()
    apiMock.getQuoteReturnValue = mockResponse
    let request = ZeroXQuoteRequest.stub(chainId: "eip155:1")

    // when
    let response = try await zeroX.getQuote(request: request, zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getQuoteRequestParam?.chainId, "eip155:1")
  }
}

// MARK: - Request Model Tests

extension ZeroXTests {
  func test_zeroXQuoteRequest_toRequestBodyIncludesRequiredParams() {
    // given
    let request = ZeroXQuoteRequest.stub(chainId: "eip155:1")

    // when
    let body = request.toRequestBody()

    // then
    XCTAssertNotNil(body["chainId"])
    XCTAssertNotNil(body["buyToken"])
    XCTAssertNotNil(body["sellToken"])
    XCTAssertNotNil(body["sellAmount"])
  }

  func test_zeroXPriceRequest_toRequestBodyIncludesRequiredParams() {
    // given
    let request = ZeroXPriceRequest.stub(chainId: "eip155:137")

    // when
    let body = request.toRequestBody()

    // then
    XCTAssertNotNil(body["chainId"])
    XCTAssertNotNil(body["buyToken"])
    XCTAssertNotNil(body["sellToken"])
    XCTAssertNotNil(body["sellAmount"])
  }

  func test_zeroXQuoteRequest_encodesOptionalFields() {
    // given
    let request = ZeroXQuoteRequest.stub(
      slippageBps: 50,
      excludedSources: "Uniswap",
      sellEntireBalance: true
    )

    // when
    let body = request.toRequestBody()

    // then
    XCTAssertEqual(body["slippageBps"]?.value as? Int, 50)
    XCTAssertEqual(body["excludedSources"]?.value as? String, "Uniswap")
    XCTAssertEqual(body["sellEntireBalance"]?.value as? String, "true")
  }
}

// MARK: - Complete Flow Tests

extension ZeroXTests {
  func test_completeSwapFlow() async throws {
    // given
    let zeroXMock = ZeroXMock()
    zeroXMock.getSourcesReturnValue = ZeroXSourcesResponse.stub()
    zeroXMock.getQuoteReturnValue = ZeroXQuoteResponse.stub()

    // Step 1: Get sources
    let sources = try await zeroXMock.getSources(chainId: "eip155:1", zeroXApiKey: nil)
    XCTAssertNotNil(sources)
    XCTAssertNotNil(sources.data)
    XCTAssertFalse(sources.data?.rawResponse.sources.isEmpty ?? true)

    // Step 2: Get quote
    let quoteRequest = ZeroXQuoteRequest.stub()
    let quote = try await zeroXMock.getQuote(request: quoteRequest, zeroXApiKey: nil)
    XCTAssertNotNil(quote)
    XCTAssertNotNil(quote.data)
    XCTAssertNotNil(quote.data?.rawResponse.transaction)

    // Verify call counts
    XCTAssertEqual(zeroXMock.getSourcesCalls, 1)
    XCTAssertEqual(zeroXMock.getQuoteCalls, 1)
  }

  func test_completeSwapFlow_withPriceCheck() async throws {
    // given
    let zeroXMock = ZeroXMock()
    zeroXMock.getSourcesReturnValue = ZeroXSourcesResponse.stub()
    zeroXMock.getPriceReturnValue = ZeroXPriceResponse.stub()
    zeroXMock.getQuoteReturnValue = ZeroXQuoteResponse.stub()

    // Step 1: Get sources
    let sources = try await zeroXMock.getSources(chainId: "eip155:1", zeroXApiKey: nil)
    XCTAssertNotNil(sources)

    // Step 2: Check price first (no transaction needed)
    let priceRequest = ZeroXPriceRequest.stub()
    let price = try await zeroXMock.getPrice(request: priceRequest, zeroXApiKey: nil)
    XCTAssertNotNil(price)
    XCTAssertNotNil(price.data)
    XCTAssertEqual(price.data?.rawResponse.liquidityAvailable ?? false, true)

    // Step 3: Get quote with transaction
    let quoteRequest = ZeroXQuoteRequest.stub()
    let quote = try await zeroXMock.getQuote(request: quoteRequest, zeroXApiKey: nil)
    XCTAssertNotNil(quote)

    // Verify call counts
    XCTAssertEqual(zeroXMock.getSourcesCalls, 1)
    XCTAssertEqual(zeroXMock.getPriceCalls, 1)
    XCTAssertEqual(zeroXMock.getQuoteCalls, 1)
  }
}

// MARK: - Dependency Injection Tests

extension ZeroXTests {
  func test_zeroX_supportsDependencyInjection() {
    // given
    let zeroXMock = ZeroXMock()

    // then
    XCTAssertNotNil(zeroXMock)
    XCTAssertTrue(zeroXMock is ZeroXProtocol)
  }

  func test_zeroX_injectedMock_isolatesTestBehavior() async throws {
    // given
    let zeroXMock1 = ZeroXMock()
    let zeroXMock2 = ZeroXMock()

    // when
    _ = try await zeroXMock1.getSources(chainId: "eip155:1", zeroXApiKey: nil)
    _ = try await zeroXMock1.getSources(chainId: "eip155:137", zeroXApiKey: nil)
    _ = try await zeroXMock2.getSources(chainId: "eip155:10", zeroXApiKey: nil)

    // then - mocks should be isolated
    XCTAssertEqual(zeroXMock1.getSourcesCalls, 2)
    XCTAssertEqual(zeroXMock2.getSourcesCalls, 1)
  }
}

