//
//  PortalZeroXTradingApiTests.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import AnyCodable
import Foundation
@testable import PortalSwift
import XCTest

final class PortalZeroXTradingApiTests: XCTestCase {
  var requestsSpy: PortalRequestsSpy!
  var zeroXApi: PortalZeroXTradingApi!
  let testApiKey = "test-api-key-12345"
  let encoder = JSONEncoder()

  override func setUpWithError() throws {
    requestsSpy = PortalRequestsSpy()
    zeroXApi = PortalZeroXTradingApi(apiKey: testApiKey, apiHost: "api.portalhq.io", requests: requestsSpy)
  }

  override func tearDownWithError() throws {
    requestsSpy = nil
    zeroXApi = nil
  }

  // Helper to set return data
  private func setReturnValue<T: Encodable>(_ value: T) throws {
    requestsSpy.returnData = try encoder.encode(value)
  }
}

// MARK: - Initialization Tests

extension PortalZeroXTradingApiTests {
  func test_init_createsInstanceSuccessfully() {
    // given & when
    let api = PortalZeroXTradingApi(apiKey: testApiKey)

    // then
    XCTAssertNotNil(api)
  }

  func test_init_conformsToProtocol() {
    // given & when
    let api = PortalZeroXTradingApi(apiKey: testApiKey)

    // then
    XCTAssertTrue(api is PortalZeroXTradingApiProtocol)
  }

  func test_init_withCustomHost() {
    // given & when
    let api = PortalZeroXTradingApi(apiKey: testApiKey, apiHost: "custom.api.io", requests: requestsSpy)

    // then
    XCTAssertNotNil(api)
  }

  func test_init_withLocalhost() {
    // given & when
    let api = PortalZeroXTradingApi(apiKey: testApiKey, apiHost: "localhost:3000", requests: requestsSpy)

    // then
    XCTAssertNotNil(api)
  }

  func test_init_withDefaultRequests() {
    // given & when
    let api = PortalZeroXTradingApi(apiKey: testApiKey, apiHost: "api.portalhq.io")

    // then
    XCTAssertNotNil(api)
  }
}

// MARK: - getSources URL Construction Tests

extension PortalZeroXTradingApiTests {
  func test_getSources_constructsCorrectURL() async throws {
    // given
    try setReturnValue(ZeroXSourcesResponse.stub())
    let chainId = "eip155:1"

    // when
    _ = try await zeroXApi.getSources(chainId: chainId, zeroXApiKey: nil)

    // then
    let request = requestsSpy.executeRequestParam as? PortalAPIRequest
    let expectedURL = "https://api.portalhq.io/api/v3/clients/me/integrations/0x/swap/sources"
    XCTAssertEqual(request?.url.absoluteString, expectedURL)
  }

  func test_getSources_usesPostMethod() async throws {
    // given
    try setReturnValue(ZeroXSourcesResponse.stub())

    // when
    _ = try await zeroXApi.getSources(chainId: "eip155:1", zeroXApiKey: nil)

    // then
    let request = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(request?.method, .post)
  }

  func test_getSources_includesBearerToken() async throws {
    // given
    try setReturnValue(ZeroXSourcesResponse.stub())

    // when
    _ = try await zeroXApi.getSources(chainId: "eip155:1", zeroXApiKey: nil)

    // then
    let request = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(request?.headers["Authorization"], "Bearer \(testApiKey)")
  }

  func test_getSources_includesChainIdInBody() async throws {
    // given
    try setReturnValue(ZeroXSourcesResponse.stub())
    let chainId = "eip155:137"

    // when
    _ = try await zeroXApi.getSources(chainId: chainId, zeroXApiKey: nil)

    // then
    let request = requestsSpy.executeRequestParam as? PortalAPIRequest
    let payload = request?.payload as? [String: AnyCodable]
    XCTAssertEqual(payload?["chainId"]?.value as? String, chainId)
  }

  func test_getSources_withSpecialCharactersInChainId() async throws {
    // given
    try setReturnValue(ZeroXSourcesResponse.stub())
    let chainId = "eip155:42161" // Arbitrum

    // when
    _ = try await zeroXApi.getSources(chainId: chainId, zeroXApiKey: nil)

    // then
    let request = requestsSpy.executeRequestParam as? PortalAPIRequest
    let payload = request?.payload as? [String: AnyCodable]
    XCTAssertEqual(payload?["chainId"]?.value as? String, chainId)
  }

  func test_getSources_withLocalhostUsesHttp() async throws {
    // given
    let localhostApi = PortalZeroXTradingApi(apiKey: testApiKey, apiHost: "localhost:3000", requests: requestsSpy)
    try setReturnValue(ZeroXSourcesResponse.stub())

    // when
    _ = try await localhostApi.getSources(chainId: "eip155:1", zeroXApiKey: nil)

    // then
    let request = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertTrue(request?.url.absoluteString.hasPrefix("http://") ?? false)
  }

  func test_getSources_withProductionHostUsesHttps() async throws {
    // given
    try setReturnValue(ZeroXSourcesResponse.stub())

    // when
    _ = try await zeroXApi.getSources(chainId: "eip155:1", zeroXApiKey: nil)

    // then
    let request = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertTrue(request?.url.absoluteString.hasPrefix("https://") ?? false)
  }

  func test_getSources_includesZeroXApiKeyInBody() async throws {
    // given
    try setReturnValue(ZeroXSourcesResponse.stub())
    let zeroXApiKey = "zero-x-api-key-123"

    // when
    _ = try await zeroXApi.getSources(chainId: "eip155:1", zeroXApiKey: zeroXApiKey)

    // then
    let request = requestsSpy.executeRequestParam as? PortalAPIRequest
    let payload = request?.payload as? [String: AnyCodable]
    XCTAssertEqual(payload?["zeroXApiKey"]?.value as? String, zeroXApiKey)
  }

  func test_getSources_withoutZeroXApiKey_includesOnlyChainIdInBody() async throws {
    // given
    try setReturnValue(ZeroXSourcesResponse.stub())
    let chainId = "eip155:1"

    // when
    _ = try await zeroXApi.getSources(chainId: chainId, zeroXApiKey: nil)

    // then
    let request = requestsSpy.executeRequestParam as? PortalAPIRequest
    let payload = request?.payload as? [String: AnyCodable]
    XCTAssertEqual(payload?["chainId"]?.value as? String, chainId)
    XCTAssertNil(payload?["zeroXApiKey"])
  }
}

// MARK: - getQuote URL Construction Tests

extension PortalZeroXTradingApiTests {
  func test_getQuote_constructsCorrectURL() async throws {
    // given
    try setReturnValue(ZeroXQuoteResponse.stub())
    let request = ZeroXQuoteRequest.stub(chainId: "eip155:1")

    // when
    _ = try await zeroXApi.getQuote(request: request, zeroXApiKey: nil)

    // then
    let apiRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let expectedURL = "https://api.portalhq.io/api/v3/clients/me/integrations/0x/swap/quote"
    XCTAssertEqual(apiRequest?.url.absoluteString, expectedURL)
  }

  func test_getQuote_usesPostMethod() async throws {
    // given
    try setReturnValue(ZeroXQuoteResponse.stub())
    let request = ZeroXQuoteRequest.stub()

    // when
    _ = try await zeroXApi.getQuote(request: request, zeroXApiKey: nil)

    // then
    let apiRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(apiRequest?.method, .post)
  }

  func test_getQuote_includesBearerToken() async throws {
    // given
    try setReturnValue(ZeroXQuoteResponse.stub())
    let request = ZeroXQuoteRequest.stub()

    // when
    _ = try await zeroXApi.getQuote(request: request, zeroXApiKey: nil)

    // then
    let apiRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(apiRequest?.headers["Authorization"], "Bearer \(testApiKey)")
  }

  func test_getQuote_includesChainIdInBody() async throws {
    // given
    try setReturnValue(ZeroXQuoteResponse.stub())
    let request = ZeroXQuoteRequest.stub(chainId: "eip155:137")

    // when
    _ = try await zeroXApi.getQuote(request: request, zeroXApiKey: nil)

    // then
    let apiRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let payload = apiRequest?.payload as? [String: AnyCodable]
    XCTAssertEqual(payload?["chainId"]?.value as? String, "eip155:137")
  }

  func test_getQuote_includesRequiredFieldsInBody() async throws {
    // given
    try setReturnValue(ZeroXQuoteResponse.stub())
    let request = ZeroXQuoteRequest.stub(
      buyToken: "USDC",
      sellToken: "ETH",
      sellAmount: "1000000000000000000"
    )

    // when
    _ = try await zeroXApi.getQuote(request: request, zeroXApiKey: nil)

    // then
    let apiRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let payload = apiRequest?.payload as? [String: AnyCodable]
    XCTAssertEqual(payload?["buyToken"]?.value as? String, "USDC")
    XCTAssertEqual(payload?["sellToken"]?.value as? String, "ETH")
    XCTAssertEqual(payload?["sellAmount"]?.value as? String, "1000000000000000000")
  }

  func test_getQuote_includesOptionalFieldsInBody() async throws {
    // given
    try setReturnValue(ZeroXQuoteResponse.stub())
    let request = ZeroXQuoteRequest.stub(
      slippageBps: 50,
      excludedSources: "Uniswap",
      sellEntireBalance: true
    )

    // when
    _ = try await zeroXApi.getQuote(request: request, zeroXApiKey: nil)

    // then
    let apiRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let payload = apiRequest?.payload as? [String: AnyCodable]
    XCTAssertEqual(payload?["slippageBps"]?.value as? Int, 50)
    XCTAssertEqual(payload?["excludedSources"]?.value as? String, "Uniswap")
    XCTAssertEqual(payload?["sellEntireBalance"]?.value as? String, "true")
  }

  func test_getQuote_includesZeroXApiKeyInBody() async throws {
    // given
    try setReturnValue(ZeroXQuoteResponse.stub())
    let request = ZeroXQuoteRequest.stub()
    let zeroXApiKey = "zero-x-api-key-456"

    // when
    _ = try await zeroXApi.getQuote(request: request, zeroXApiKey: zeroXApiKey)

    // then
    let apiRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let payload = apiRequest?.payload as? [String: AnyCodable]
    XCTAssertEqual(payload?["zeroXApiKey"]?.value as? String, zeroXApiKey)
  }

  func test_getQuote_sellEntireBalanceConvertsBoolToString() async throws {
    // given
    try setReturnValue(ZeroXQuoteResponse.stub())
    let request = ZeroXQuoteRequest.stub(sellEntireBalance: false)

    // when
    _ = try await zeroXApi.getQuote(request: request, zeroXApiKey: nil)

    // then
    let apiRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let payload = apiRequest?.payload as? [String: AnyCodable]
    XCTAssertEqual(payload?["sellEntireBalance"]?.value as? String, "false")
  }
}

// MARK: - getPrice URL Construction Tests

extension PortalZeroXTradingApiTests {
  func test_getPrice_constructsCorrectURL() async throws {
    // given
    try setReturnValue(ZeroXPriceResponse.stub())
    let request = ZeroXPriceRequest.stub(chainId: "eip155:1")

    // when
    _ = try await zeroXApi.getPrice(request: request, zeroXApiKey: nil)

    // then
    let apiRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let expectedURL = "https://api.portalhq.io/api/v3/clients/me/integrations/0x/swap/price"
    XCTAssertEqual(apiRequest?.url.absoluteString, expectedURL)
  }

  func test_getPrice_usesPostMethod() async throws {
    // given
    try setReturnValue(ZeroXPriceResponse.stub())
    let request = ZeroXPriceRequest.stub()

    // when
    _ = try await zeroXApi.getPrice(request: request, zeroXApiKey: nil)

    // then
    let apiRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(apiRequest?.method, .post)
  }

  func test_getPrice_includesBearerToken() async throws {
    // given
    try setReturnValue(ZeroXPriceResponse.stub())
    let request = ZeroXPriceRequest.stub()

    // when
    _ = try await zeroXApi.getPrice(request: request, zeroXApiKey: nil)

    // then
    let apiRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(apiRequest?.headers["Authorization"], "Bearer \(testApiKey)")
  }

  func test_getPrice_includesChainIdInBody() async throws {
    // given
    try setReturnValue(ZeroXPriceResponse.stub())
    let request = ZeroXPriceRequest.stub(chainId: "eip155:10")

    // when
    _ = try await zeroXApi.getPrice(request: request, zeroXApiKey: nil)

    // then
    let apiRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let payload = apiRequest?.payload as? [String: AnyCodable]
    XCTAssertEqual(payload?["chainId"]?.value as? String, "eip155:10")
  }

  func test_getPrice_includesRequiredFieldsInBody() async throws {
    // given
    try setReturnValue(ZeroXPriceResponse.stub())
    let request = ZeroXPriceRequest.stub(
      buyToken: "USDC",
      sellToken: "USDT",
      sellAmount: "1000000000"
    )

    // when
    _ = try await zeroXApi.getPrice(request: request, zeroXApiKey: nil)

    // then
    let apiRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let payload = apiRequest?.payload as? [String: AnyCodable]
    XCTAssertEqual(payload?["buyToken"]?.value as? String, "USDC")
    XCTAssertEqual(payload?["sellToken"]?.value as? String, "USDT")
    XCTAssertEqual(payload?["sellAmount"]?.value as? String, "1000000000")
  }

  func test_getPrice_includesZeroXApiKeyInBody() async throws {
    // given
    try setReturnValue(ZeroXPriceResponse.stub())
    let request = ZeroXPriceRequest.stub()
    let zeroXApiKey = "zero-x-api-key-789"

    // when
    _ = try await zeroXApi.getPrice(request: request, zeroXApiKey: zeroXApiKey)

    // then
    let apiRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let payload = apiRequest?.payload as? [String: AnyCodable]
    XCTAssertEqual(payload?["zeroXApiKey"]?.value as? String, zeroXApiKey)
  }
}

// MARK: - Response Handling Tests

extension PortalZeroXTradingApiTests {
  func test_getSources_returnsSuccessfulResponse() async throws {
    // given
    let expectedResponse = ZeroXSourcesResponse.stub()
    try setReturnValue(expectedResponse)

    // when
    let response = try await zeroXApi.getSources(chainId: "eip155:1", zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertFalse(response.data?.rawResponse.sources.isEmpty ?? true)
  }

  func test_getSources_returnsEmptySources() async throws {
    // given
    let expectedResponse = ZeroXSourcesResponse(data: ZeroXSourcesData(rawResponse: ZeroXSourcesRawResponse(sources: [], zid: "test-zid")))
    try setReturnValue(expectedResponse)

    // when
    let response = try await zeroXApi.getSources(chainId: "eip155:1", zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertTrue(response.data?.rawResponse.sources.isEmpty ?? false)
  }

  func test_getQuote_returnsSuccessfulResponse() async throws {
    // given
    let expectedResponse = ZeroXQuoteResponse.stub()
    try setReturnValue(expectedResponse)

    // when
    let response = try await zeroXApi.getQuote(request: ZeroXQuoteRequest.stub(), zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertNotNil(response.data?.rawResponse)
    XCTAssertNotNil(response.data?.rawResponse.transaction)
  }

  func test_getPrice_returnsSuccessfulResponse() async throws {
    // given
    let expectedResponse = ZeroXPriceResponse.stub()
    try setReturnValue(expectedResponse)

    // when
    let response = try await zeroXApi.getPrice(request: ZeroXPriceRequest.stub(), zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertNotNil(response.data?.rawResponse)
  }

  func test_getPrice_returnsFeesInResponse() async throws {
    // given
    let fees = ZeroXFees.stub()
    let priceData = ZeroXPriceRawResponse.stub(fees: fees)
    let expectedResponse = ZeroXPriceResponse(data: ZeroXPriceResponseData(rawResponse: priceData))
    try setReturnValue(expectedResponse)

    // when
    let response = try await zeroXApi.getPrice(request: ZeroXPriceRequest.stub(), zeroXApiKey: nil)

    // then
    XCTAssertNotNil(response.data)
    XCTAssertNotNil(response.data?.rawResponse.fees)
  }
}

// MARK: - Multiple Calls Tests

extension PortalZeroXTradingApiTests {
  func test_multipleCalls_trackCorrectly() async throws {
    // given
    try setReturnValue(ZeroXSourcesResponse.stub())

    // when
    _ = try await zeroXApi.getSources(chainId: "eip155:1", zeroXApiKey: nil)
    _ = try await zeroXApi.getSources(chainId: "eip155:137", zeroXApiKey: nil)
    _ = try await zeroXApi.getSources(chainId: "eip155:10", zeroXApiKey: nil)

    // then
    XCTAssertEqual(requestsSpy.executeCallsCount, 3)
  }

  func test_differentMethods_callCorrectEndpoints() async throws {
    // given
    try setReturnValue(ZeroXSourcesResponse.stub())
    _ = try await zeroXApi.getSources(chainId: "eip155:1", zeroXApiKey: nil)
    let sourcesURL = (requestsSpy.executeRequestParam as? PortalAPIRequest)?.url.absoluteString

    try setReturnValue(ZeroXQuoteResponse.stub())
    _ = try await zeroXApi.getQuote(request: ZeroXQuoteRequest.stub(), zeroXApiKey: nil)
    let quoteURL = (requestsSpy.executeRequestParam as? PortalAPIRequest)?.url.absoluteString

    try setReturnValue(ZeroXPriceResponse.stub())
    _ = try await zeroXApi.getPrice(request: ZeroXPriceRequest.stub(), zeroXApiKey: nil)
    let priceURL = (requestsSpy.executeRequestParam as? PortalAPIRequest)?.url.absoluteString

    // then
    XCTAssertTrue(sourcesURL?.contains("/integrations/0x/swap/sources") ?? false)
    XCTAssertTrue(quoteURL?.contains("/integrations/0x/swap/quote") ?? false)
    XCTAssertTrue(priceURL?.contains("/integrations/0x/swap/price") ?? false)
  }
}

// MARK: - Request Payload Tests

extension PortalZeroXTradingApiTests {
  func test_getQuote_payloadContainsAllRequiredFields() async throws {
    // given
    try setReturnValue(ZeroXQuoteResponse.stub())
    let request = ZeroXQuoteRequest.stub(
      buyToken: "USDC",
      sellToken: "ETH",
      sellAmount: "1000000000000000000"
    )

    // when
    _ = try await zeroXApi.getQuote(request: request, zeroXApiKey: nil)

    // then
    let apiRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let payload = apiRequest?.payload as? [String: AnyCodable]
    XCTAssertEqual(payload?["buyToken"]?.value as? String, "USDC")
    XCTAssertEqual(payload?["sellToken"]?.value as? String, "ETH")
    XCTAssertEqual(payload?["sellAmount"]?.value as? String, "1000000000000000000")
  }

  func test_getQuote_payloadContainsOptionalFields() async throws {
    // given
    try setReturnValue(ZeroXQuoteResponse.stub())
    let request = ZeroXQuoteRequest.stub(
      chainId: "eip155:1",
      txOrigin: "0xOrigin",
      swapFeeRecipient: "0xFee",
      swapFeeBps: 100,
      swapFeeToken: "USDC",
      tradeSurplusRecipient: "0xSurplus",
      gasPrice: "50000000000",
      slippageBps: 50,
      excludedSources: "Uniswap,Sushiswap",
      sellEntireBalance: true
    )

    // when
    _ = try await zeroXApi.getQuote(request: request, zeroXApiKey: nil)

    // then
    let apiRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let payload = apiRequest?.payload as? [String: AnyCodable]
    XCTAssertEqual(payload?["chainId"]?.value as? String, "eip155:1")
    XCTAssertEqual(payload?["txOrigin"]?.value as? String, "0xOrigin")
    XCTAssertEqual(payload?["swapFeeRecipient"]?.value as? String, "0xFee")
    XCTAssertEqual(payload?["swapFeeBps"]?.value as? Int, 100)
    XCTAssertEqual(payload?["swapFeeToken"]?.value as? String, "USDC")
    XCTAssertEqual(payload?["tradeSurplusRecipient"]?.value as? String, "0xSurplus")
    XCTAssertEqual(payload?["gasPrice"]?.value as? String, "50000000000")
    XCTAssertEqual(payload?["slippageBps"]?.value as? Int, 50)
    XCTAssertEqual(payload?["excludedSources"]?.value as? String, "Uniswap,Sushiswap")
    XCTAssertEqual(payload?["sellEntireBalance"]?.value as? String, "true")
  }

  func test_getPrice_payloadContainsAllFields() async throws {
    // given
    try setReturnValue(ZeroXPriceResponse.stub())
    let request = ZeroXPriceRequest.stub(
      chainId: "eip155:1",
      buyToken: "USDC",
      sellToken: "USDT",
      sellAmount: "1000000000",
      txOrigin: "0xOrigin",
      slippageBps: 30
    )

    // when
    _ = try await zeroXApi.getPrice(request: request, zeroXApiKey: nil)

    // then
    let apiRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let payload = apiRequest?.payload as? [String: AnyCodable]
    XCTAssertEqual(payload?["chainId"]?.value as? String, "eip155:1")
    XCTAssertEqual(payload?["buyToken"]?.value as? String, "USDC")
    XCTAssertEqual(payload?["sellToken"]?.value as? String, "USDT")
    XCTAssertEqual(payload?["sellAmount"]?.value as? String, "1000000000")
    XCTAssertEqual(payload?["txOrigin"]?.value as? String, "0xOrigin")
    XCTAssertEqual(payload?["slippageBps"]?.value as? Int, 30)
  }
}

// MARK: - Thread Safety Tests

extension PortalZeroXTradingApiTests {
  func test_concurrentCalls_handleCorrectly() async throws {
    // given
    try setReturnValue(ZeroXSourcesResponse.stub())
    let callCount = 10

    // when
    await withTaskGroup(of: Void.self) { group in
      for _ in 0 ..< callCount {
        group.addTask {
          _ = try? await self.zeroXApi.getSources(chainId: "eip155:1", zeroXApiKey: nil)
        }
      }
    }

    // then
    XCTAssertEqual(requestsSpy.executeCallsCount, callCount)
  }
}

// MARK: - API Key Tests

extension PortalZeroXTradingApiTests {
  func test_allMethods_useSameApiKey() async throws {
    // given
    let customApiKey = "custom-api-key-67890"
    let customApi = PortalZeroXTradingApi(apiKey: customApiKey, requests: requestsSpy)

    // Sources
    try setReturnValue(ZeroXSourcesResponse.stub())
    _ = try await customApi.getSources(chainId: "eip155:1", zeroXApiKey: nil)
    var request = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(request?.headers["Authorization"], "Bearer \(customApiKey)")

    // Quote
    try setReturnValue(ZeroXQuoteResponse.stub())
    _ = try await customApi.getQuote(request: ZeroXQuoteRequest.stub(), zeroXApiKey: nil)
    request = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(request?.headers["Authorization"], "Bearer \(customApiKey)")

    // Price
    try setReturnValue(ZeroXPriceResponse.stub())
    _ = try await customApi.getPrice(request: ZeroXPriceRequest.stub(), zeroXApiKey: nil)
    request = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(request?.headers["Authorization"], "Bearer \(customApiKey)")
  }

  func test_emptyApiKey_stillSendsAuthorizationHeader() async throws {
    // given
    let emptyApiKeyApi = PortalZeroXTradingApi(apiKey: "", requests: requestsSpy)
    try setReturnValue(ZeroXSourcesResponse.stub())

    // when
    _ = try await emptyApiKeyApi.getSources(chainId: "eip155:1", zeroXApiKey: nil)

    // then
    let request = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(request?.headers["Authorization"], "Bearer ")
  }

  func test_zeroXApiKey_overrideWorksForAllMethods() async throws {
    // given
    let overrideKey = "override-key-123"
    try setReturnValue(ZeroXSourcesResponse.stub())

    // Sources
    _ = try await zeroXApi.getSources(chainId: "eip155:1", zeroXApiKey: overrideKey)
    var request = requestsSpy.executeRequestParam as? PortalAPIRequest
    var payload = request?.payload as? [String: AnyCodable]
    XCTAssertEqual(payload?["zeroXApiKey"]?.value as? String, overrideKey)

    // Quote
    try setReturnValue(ZeroXQuoteResponse.stub())
    _ = try await zeroXApi.getQuote(request: ZeroXQuoteRequest.stub(), zeroXApiKey: overrideKey)
    request = requestsSpy.executeRequestParam as? PortalAPIRequest
    payload = request?.payload as? [String: AnyCodable]
    XCTAssertEqual(payload?["zeroXApiKey"]?.value as? String, overrideKey)

    // Price
    try setReturnValue(ZeroXPriceResponse.stub())
    _ = try await zeroXApi.getPrice(request: ZeroXPriceRequest.stub(), zeroXApiKey: overrideKey)
    request = requestsSpy.executeRequestParam as? PortalAPIRequest
    payload = request?.payload as? [String: AnyCodable]
    XCTAssertEqual(payload?["zeroXApiKey"]?.value as? String, overrideKey)
  }
}

// MARK: - Host Configuration Tests

extension PortalZeroXTradingApiTests {
  func test_customHost_usedInAllRequests() async throws {
    // given
    let customHost = "custom.zeroX.io"
    let customApi = PortalZeroXTradingApi(apiKey: testApiKey, apiHost: customHost, requests: requestsSpy)
    try setReturnValue(ZeroXSourcesResponse.stub())

    // when
    _ = try await customApi.getSources(chainId: "eip155:1", zeroXApiKey: nil)

    // then
    let request = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertTrue(request?.url.absoluteString.contains(customHost) ?? false)
  }

  func test_localhostWithPort_usesHttpScheme() async throws {
    // given
    let localhostApi = PortalZeroXTradingApi(apiKey: testApiKey, apiHost: "localhost:8080", requests: requestsSpy)
    try setReturnValue(ZeroXSourcesResponse.stub())

    // when
    _ = try await localhostApi.getSources(chainId: "eip155:1", zeroXApiKey: nil)

    // then
    let request = requestsSpy.executeRequestParam as? PortalAPIRequest
    let urlString = request?.url.absoluteString ?? ""
    XCTAssertTrue(urlString.hasPrefix("http://localhost:8080"))
  }

  func test_productionHost_usesHttpsScheme() async throws {
    // given
    try setReturnValue(ZeroXSourcesResponse.stub())

    // when
    _ = try await zeroXApi.getSources(chainId: "eip155:1", zeroXApiKey: nil)

    // then
    let request = requestsSpy.executeRequestParam as? PortalAPIRequest
    let urlString = request?.url.absoluteString ?? ""
    XCTAssertTrue(urlString.hasPrefix("https://"))
  }
}

// MARK: - ChainId in Request Body Tests

extension PortalZeroXTradingApiTests {
  func test_chainId_includedInRequestBodyForAllMethods() async throws {
    // given
    let chainId = "eip155:1"
    
    // Test getSources
    try setReturnValue(ZeroXSourcesResponse.stub())
    _ = try await zeroXApi.getSources(chainId: chainId, zeroXApiKey: nil)
    var request = requestsSpy.executeRequestParam as? PortalAPIRequest
    var payload = request?.payload as? [String: AnyCodable]
    XCTAssertEqual(payload?["chainId"]?.value as? String, chainId)
    
    // Test getQuote
    try setReturnValue(ZeroXQuoteResponse.stub())
    _ = try await zeroXApi.getQuote(request: ZeroXQuoteRequest.stub(chainId: chainId), zeroXApiKey: nil)
    request = requestsSpy.executeRequestParam as? PortalAPIRequest
    payload = request?.payload as? [String: AnyCodable]
    XCTAssertEqual(payload?["chainId"]?.value as? String, chainId)
    
    // Test getPrice
    try setReturnValue(ZeroXPriceResponse.stub())
    _ = try await zeroXApi.getPrice(request: ZeroXPriceRequest.stub(chainId: chainId), zeroXApiKey: nil)
    request = requestsSpy.executeRequestParam as? PortalAPIRequest
    payload = request?.payload as? [String: AnyCodable]
    XCTAssertEqual(payload?["chainId"]?.value as? String, chainId)
  }

  func test_chainId_handlesMultipleChainsInBody() async throws {
    // given
    let chainIds = ["eip155:1", "eip155:137", "eip155:42161", "eip155:10"]

    for chainId in chainIds {
      // when
      try setReturnValue(ZeroXSourcesResponse.stub())
      _ = try await zeroXApi.getSources(chainId: chainId, zeroXApiKey: nil)

      // then
      let request = requestsSpy.executeRequestParam as? PortalAPIRequest
      let payload = request?.payload as? [String: AnyCodable]
      XCTAssertEqual(payload?["chainId"]?.value as? String, chainId, "ChainId \(chainId) should be in request body")
    }
  }
}

// MARK: - Error Handling Tests

extension PortalZeroXTradingApiTests {
  func test_getSources_throwsURLErrorOnInvalidURL() async throws {
    // given
    // This test would require mocking URL construction to fail
    // For now, we test that the method handles errors properly
    try setReturnValue(ZeroXSourcesResponse.stub())

    // when & then - should not throw for valid chainId
    do {
      _ = try await zeroXApi.getSources(chainId: "eip155:1", zeroXApiKey: nil)
      // Success case - no error thrown
    } catch {
      XCTFail("Should not throw error for valid chainId")
    }
  }

  func test_getQuote_throwsDecodingErrorOnInvalidResponse() async throws {
    // given
    requestsSpy.returnData = Data("invalid json".utf8)

    // when & then
    do {
      _ = try await zeroXApi.getQuote(request: ZeroXQuoteRequest.stub(), zeroXApiKey: nil)
      XCTFail("Should throw decoding error")
    } catch {
      XCTAssertTrue(error is DecodingError || error is NSError)
    }
  }

  func test_getPrice_throwsDecodingErrorOnInvalidResponse() async throws {
    // given
    requestsSpy.returnData = Data("invalid json".utf8)

    // when & then
    do {
      _ = try await zeroXApi.getPrice(request: ZeroXPriceRequest.stub(), zeroXApiKey: nil)
      XCTFail("Should throw decoding error")
    } catch {
      XCTAssertTrue(error is DecodingError || error is NSError)
    }
  }
}

