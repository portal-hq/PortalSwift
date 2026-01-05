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
    let mockResponse = ZeroXSourcesResponse(data: ZeroXSourcesData(sources: []))
    apiMock.getSourcesReturnValue = mockResponse

    // when
    let response = try await zeroX.getSources(chainId: "eip155:1", zeroXApiKey: nil)

    // then
    XCTAssertEqual(response.data.sources.count, 0)
  }

  func test_getSources_withMultipleSources() async throws {
    // given
    let sources = ["Uniswap", "Sushiswap", "Curve", "Balancer", "1inch"]
    let mockResponse = ZeroXSourcesResponse(data: ZeroXSourcesData(sources: sources))
    apiMock.getSourcesReturnValue = mockResponse

    // when
    let response = try await zeroX.getSources(chainId: "eip155:1", zeroXApiKey: nil)

    // then
    XCTAssertEqual(response.data.sources.count, 5)
    XCTAssertTrue(response.data.sources.contains("Uniswap"))
    XCTAssertTrue(response.data.sources.contains("1inch"))
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
      taker: "0x123",
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
      taker: "0x1234567890abcdef1234567890abcdef12345678",
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
    XCTAssertNotNil(response.data.quote)
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
    let quoteData = ZeroXQuoteData.stub(transaction: transaction)
    let mockResponse = ZeroXQuoteResponse(data: ZeroXQuoteResponseData(quote: quoteData))
    apiMock.getQuoteReturnValue = mockResponse
    let request = ZeroXQuoteRequest.stub()

    // when
    let response = try await zeroX.getQuote(request: request, zeroXApiKey: nil)

    // then
    XCTAssertEqual(response.data.quote.transaction.data, "0xabcdef")
    XCTAssertEqual(response.data.quote.transaction.from, "0xfrom")
    XCTAssertEqual(response.data.quote.transaction.gas, "100000")
  }

  func test_getQuote_returnsIssues() async throws {
    // given
    let issues = ZeroXIssues.stub(
      allowance: ZeroXAllowanceIssue.stub(),
      balance: nil,
      simulationIncomplete: true,
      invalidSourcesPassed: ["InvalidSource"]
    )
    let quoteData = ZeroXQuoteData.stub(issues: issues)
    let mockResponse = ZeroXQuoteResponse(data: ZeroXQuoteResponseData(quote: quoteData))
    apiMock.getQuoteReturnValue = mockResponse
    let request = ZeroXQuoteRequest.stub()

    // when
    let response = try await zeroX.getQuote(request: request, zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response.data.quote.issues)
    XCTAssertNotNil(response.data.quote.issues?.allowance)
    XCTAssertEqual(response.data.quote.issues?.simulationIncomplete, true)
    XCTAssertEqual(response.data.quote.issues?.invalidSourcesPassed, ["InvalidSource"])
    // Verify optional fields can be nil
    XCTAssertNil(response.data.quote.issues?.balance)
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
      taker: "0xtaker",
      buyToken: "MATIC",
      sellToken: "USDC",
      sellAmount: "5000000"
    )
    let zeroXApiKey = "my-api-key"

    // when
    _ = try await zeroX.getQuote(request: request, zeroXApiKey: zeroXApiKey)

    // then
    XCTAssertEqual(apiMock.getQuoteRequestParam?.chainId, "eip155:137")
    XCTAssertEqual(apiMock.getQuoteRequestParam?.taker, "0xtaker")
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

  func test_getPrice_withOptionalTaker() async throws {
    // given
    let mockResponse = ZeroXPriceResponse.stub()
    apiMock.getPriceReturnValue = mockResponse
    let request = ZeroXPriceRequest.stub(taker: "0xtaker")

    // when
    let response = try await zeroX.getPrice(request: request, zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getPriceRequestParam?.taker, "0xtaker")
  }

  func test_getPrice_withoutTaker() async throws {
    // given
    let mockResponse = ZeroXPriceResponse.stub()
    apiMock.getPriceReturnValue = mockResponse
    let request = ZeroXPriceRequest.stub(taker: nil)

    // when
    let response = try await zeroX.getPrice(request: request, zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response)
    XCTAssertNil(apiMock.getPriceRequestParam?.taker)
  }

  func test_getPrice_returnsFees() async throws {
    // given
    let fees = ZeroXFees.stub(
      integratorFee: ZeroXFeeDetail.stub(amount: "100", token: "ETH", type: "integrator"),
      zeroExFee: ZeroXZeroExFeeDetail.stub(),
      gasFee: ZeroXFeeDetail.stub()
    )
    let priceData = ZeroXPriceData.stub(fees: fees)
    let mockResponse = ZeroXPriceResponse(data: ZeroXPriceResponseData(price: priceData))
    apiMock.getPriceReturnValue = mockResponse
    let request = ZeroXPriceRequest.stub()

    // when
    let response = try await zeroX.getPrice(request: request, zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response.data.price.fees)
    XCTAssertNotNil(response.data.price.fees?.integratorFee)
    XCTAssertNotNil(response.data.price.fees?.zeroExFee)
    XCTAssertNotNil(response.data.price.fees?.gasFee)
    // Verify optional fee fields can be accessed
    XCTAssertEqual(response.data.price.fees?.integratorFee?.amount, "100")
    XCTAssertEqual(response.data.price.fees?.integratorFee?.token, "ETH")
  }

  func test_getPrice_returnsIssues() async throws {
    // given
    let issues = ZeroXIssues.stub(simulationIncomplete: true)
    let priceData = ZeroXPriceData.stub(issues: issues)
    let mockResponse = ZeroXPriceResponse(data: ZeroXPriceResponseData(price: priceData))
    apiMock.getPriceReturnValue = mockResponse
    let request = ZeroXPriceRequest.stub()

    // when
    let response = try await zeroX.getPrice(request: request, zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response.data.price.issues)
    XCTAssertEqual(response.data.price.issues?.simulationIncomplete, true)
  }

  func test_getQuote_handlesOptionalFields() async throws {
    // given - quote with minimal fields (optional fields are nil)
    let quoteData = ZeroXQuoteData(
      buyAmount: "3000000000",
      sellAmount: "1000000000000000000",
      price: nil,
      estimatedGas: nil,
      gasPrice: nil,
      cost: nil,
      liquidityAvailable: nil,
      minBuyAmount: nil,
      transaction: ZeroXTransaction.stub(),
      issues: nil
    )
    let mockResponse = ZeroXQuoteResponse(data: ZeroXQuoteResponseData(quote: quoteData))
    apiMock.getQuoteReturnValue = mockResponse
    let request = ZeroXQuoteRequest.stub()

    // when
    let response = try await zeroX.getQuote(request: request, zeroXApiKey: nil)

    // then - verify optional fields can be nil
    XCTAssertNotNil(response.data.quote)
    XCTAssertNil(response.data.quote.price)
    XCTAssertNil(response.data.quote.estimatedGas)
    XCTAssertNil(response.data.quote.gasPrice)
    XCTAssertNil(response.data.quote.cost)
    XCTAssertNil(response.data.quote.liquidityAvailable)
    XCTAssertNil(response.data.quote.minBuyAmount)
    // Required fields should still be present
    XCTAssertEqual(response.data.quote.buyAmount, "3000000000")
    XCTAssertEqual(response.data.quote.sellAmount, "1000000000000000000")
    XCTAssertNotNil(response.data.quote.transaction)
  }

  func test_getPrice_handlesOptionalFields() async throws {
    // given - price with minimal fields (optional fields are nil)
    let priceData = ZeroXPriceData(
      buyAmount: "3000000000",
      sellAmount: "1000000000000000000",
      price: nil,
      estimatedGas: nil,
      gasPrice: nil,
      liquidityAvailable: nil,
      minBuyAmount: nil,
      fees: nil,
      issues: nil
    )
    let mockResponse = ZeroXPriceResponse(data: ZeroXPriceResponseData(price: priceData))
    apiMock.getPriceReturnValue = mockResponse
    let request = ZeroXPriceRequest.stub()

    // when
    let response = try await zeroX.getPrice(request: request, zeroXApiKey: nil)

    // then - verify optional fields can be nil
    XCTAssertNotNil(response.data.price)
    XCTAssertNil(response.data.price.price)
    XCTAssertNil(response.data.price.estimatedGas)
    XCTAssertNil(response.data.price.gasPrice)
    XCTAssertNil(response.data.price.liquidityAvailable)
    XCTAssertNil(response.data.price.minBuyAmount)
    XCTAssertNil(response.data.price.fees)
    XCTAssertNil(response.data.price.issues)
    // Required fields should still be present
    XCTAssertEqual(response.data.price.buyAmount, "3000000000")
    XCTAssertEqual(response.data.price.sellAmount, "1000000000000000000")
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
    let priceData = ZeroXPriceData.stub(fees: ZeroXFees.stub())
    let priceResponse = ZeroXPriceResponse(data: ZeroXPriceResponseData(price: priceData))
    apiMock.getPriceReturnValue = priceResponse

    // when
    let response = try await zeroX.getPrice(request: ZeroXPriceRequest.stub(), zeroXApiKey: nil)

    // then - price response has fees
    XCTAssertNotNil(response.data.price.fees)
    // Note: price response doesn't have transaction (unlike quote)
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
    let customSources = ZeroXSourcesResponse(data: ZeroXSourcesData(sources: ["CustomSource"]))
    let zeroXMock = ZeroXMock()
    zeroXMock.getSourcesReturnValue = customSources

    // when
    let response = try await zeroXMock.getSources(chainId: "eip155:1", zeroXApiKey: nil)

    // then
    XCTAssertEqual(response.data.sources, ["CustomSource"])
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
  func test_zeroXQuoteRequest_toRequestBodyExcludesChainId() {
    // given
    let request = ZeroXQuoteRequest.stub(chainId: "eip155:1")

    // when
    let body = request.toRequestBody()

    // then
    XCTAssertNil(body["chainId"])
    XCTAssertNotNil(body["taker"])
    XCTAssertNotNil(body["buyToken"])
    XCTAssertNotNil(body["sellToken"])
    XCTAssertNotNil(body["sellAmount"])
  }

  func test_zeroXPriceRequest_toRequestBodyExcludesChainId() {
    // given
    let request = ZeroXPriceRequest.stub(chainId: "eip155:137")

    // when
    let body = request.toRequestBody()

    // then
    XCTAssertNil(body["chainId"])
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
    XCTAssertFalse(sources.data.sources.isEmpty)

    // Step 2: Get quote
    let quoteRequest = ZeroXQuoteRequest.stub()
    let quote = try await zeroXMock.getQuote(request: quoteRequest, zeroXApiKey: nil)
    XCTAssertNotNil(quote)
    XCTAssertNotNil(quote.data.quote.transaction)

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
    XCTAssertEqual(price.data.price.liquidityAvailable, true)

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

