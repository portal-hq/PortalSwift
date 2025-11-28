//
//  PortalLifiTradingApiTests.swift
//  PortalSwift
//
//  Created by Portal Labs
//

import Foundation
@testable import PortalSwift
import XCTest

final class PortalLifiTradingApiTests: XCTestCase {
  var requestsSpy: PortalRequestsSpy!
  var lifiApi: PortalLifiTradingApi!
  let testApiKey = "test-api-key-12345"
  let encoder = JSONEncoder()

  override func setUpWithError() throws {
    requestsSpy = PortalRequestsSpy()
    lifiApi = PortalLifiTradingApi(apiKey: testApiKey, apiHost: "api.portalhq.io", requests: requestsSpy)
  }

  override func tearDownWithError() throws {
    requestsSpy = nil
    lifiApi = nil
  }

  // Helper to set return data
  private func setReturnValue<T: Encodable>(_ value: T) throws {
    requestsSpy.returnData = try encoder.encode(value)
  }
}

// MARK: - Initialization Tests

extension PortalLifiTradingApiTests {
  func test_init_createsInstanceSuccessfully() {
    // given & when
    let api = PortalLifiTradingApi(apiKey: testApiKey)

    // then
    XCTAssertNotNil(api)
  }

  func test_init_conformsToProtocol() {
    // given & when
    let api = PortalLifiTradingApi(apiKey: testApiKey)

    // then
    XCTAssertTrue(api is PortalLifiTradingApiProtocol)
  }

  func test_init_withCustomHost() {
    // given & when
    let api = PortalLifiTradingApi(apiKey: testApiKey, apiHost: "custom.api.io", requests: requestsSpy)

    // then
    XCTAssertNotNil(api)
  }

  func test_init_withLocalhost() {
    // given & when
    let api = PortalLifiTradingApi(apiKey: testApiKey, apiHost: "localhost:3000", requests: requestsSpy)

    // then
    XCTAssertNotNil(api)
  }

  func test_init_withDefaultRequests() {
    // given & when
    let api = PortalLifiTradingApi(apiKey: testApiKey, apiHost: "api.portalhq.io")

    // then
    XCTAssertNotNil(api)
  }
}

// MARK: - getRoutes URL Construction Tests

extension PortalLifiTradingApiTests {
  func test_getRoutes_constructsCorrectURL() async throws {
    // given
    try setReturnValue(LifiRoutesResponse.stub())
    let request = LifiRoutesRequest.stub()

    // when
    _ = try await lifiApi.getRoutes(request: request)

    // then
    let expectedURL = "https://api.portalhq.io/api/v3/clients/me/integrations/lifi/routes"
    XCTAssertEqual(requestsSpy.executeRequestParam?.url.absoluteString, expectedURL)
  }

  func test_getRoutes_usesPostMethod() async throws {
    // given
    try setReturnValue(LifiRoutesResponse.stub())
    let request = LifiRoutesRequest.stub()

    // when
    _ = try await lifiApi.getRoutes(request: request)

    // then
    XCTAssertEqual(requestsSpy.executeRequestParam?.method, .post)
  }

  func test_getRoutes_includesBearerToken() async throws {
    // given
    try setReturnValue(LifiRoutesResponse.stub())
    let request = LifiRoutesRequest.stub()

    // when
    _ = try await lifiApi.getRoutes(request: request)

    // then
    XCTAssertEqual(requestsSpy.executeRequestParam?.headers["Authorization"], "Bearer \(testApiKey)")
  }

  func test_getRoutes_sendsRequestPayload() async throws {
    // given
    try setReturnValue(LifiRoutesResponse.stub())
    let request = LifiRoutesRequest(
      fromChainId: "1",
      fromAmount: "1000000000000000000",
      fromTokenAddress: "0xETH",
      toChainId: "137",
      toTokenAddress: "0xMATIC"
    )

    // when
    _ = try await lifiApi.getRoutes(request: request)

    // then
    XCTAssertNotNil(requestsSpy.executeRequestParam?.payload)
  }

  func test_getRoutes_withLocalhostUsesHttp() async throws {
    // given
    let localhostApi = PortalLifiTradingApi(apiKey: testApiKey, apiHost: "localhost:3000", requests: requestsSpy)
    try setReturnValue(LifiRoutesResponse.stub())
    let request = LifiRoutesRequest.stub()

    // when
    _ = try await localhostApi.getRoutes(request: request)

    // then
    XCTAssertTrue(requestsSpy.executeRequestParam?.url.absoluteString.hasPrefix("http://") ?? false)
  }

  func test_getRoutes_withProductionHostUsesHttps() async throws {
    // given
    try setReturnValue(LifiRoutesResponse.stub())
    let request = LifiRoutesRequest.stub()

    // when
    _ = try await lifiApi.getRoutes(request: request)

    // then
    XCTAssertTrue(requestsSpy.executeRequestParam?.url.absoluteString.hasPrefix("https://") ?? false)
  }
}

// MARK: - getQuote URL Construction Tests

extension PortalLifiTradingApiTests {
  func test_getQuote_constructsCorrectURL() async throws {
    // given
    try setReturnValue(LifiQuoteResponse.stub())
    let request = LifiQuoteRequest.stub()

    // when
    _ = try await lifiApi.getQuote(request: request)

    // then
    let expectedURL = "https://api.portalhq.io/api/v3/clients/me/integrations/lifi/quote"
    XCTAssertEqual(requestsSpy.executeRequestParam?.url.absoluteString, expectedURL)
  }

  func test_getQuote_usesPostMethod() async throws {
    // given
    try setReturnValue(LifiQuoteResponse.stub())
    let request = LifiQuoteRequest.stub()

    // when
    _ = try await lifiApi.getQuote(request: request)

    // then
    XCTAssertEqual(requestsSpy.executeRequestParam?.method, .post)
  }

  func test_getQuote_includesBearerToken() async throws {
    // given
    try setReturnValue(LifiQuoteResponse.stub())
    let request = LifiQuoteRequest.stub()

    // when
    _ = try await lifiApi.getQuote(request: request)

    // then
    XCTAssertEqual(requestsSpy.executeRequestParam?.headers["Authorization"], "Bearer \(testApiKey)")
  }

  func test_getQuote_sendsRequestPayload() async throws {
    // given
    try setReturnValue(LifiQuoteResponse.stub())
    let request = LifiQuoteRequest(
      fromChain: "1",
      toChain: "137",
      fromToken: "ETH",
      toToken: "MATIC",
      fromAddress: "0x123",
      fromAmount: "1000000000000000000"
    )

    // when
    _ = try await lifiApi.getQuote(request: request)

    // then
    XCTAssertNotNil(requestsSpy.executeRequestParam?.payload)
  }
}

// MARK: - getStatus URL Construction Tests

extension PortalLifiTradingApiTests {
  func test_getStatus_constructsBaseURL() async throws {
    // given
    try setReturnValue(LifiStatusResponse.stub())
    let request = LifiStatusRequest(txHash: "0xabc123")

    // when
    _ = try await lifiApi.getStatus(request: request)

    // then
    XCTAssertTrue(requestsSpy.executeRequestParam?.url.absoluteString.contains("/api/v3/clients/me/integrations/lifi/status") ?? false)
  }

  func test_getStatus_usesGetMethod() async throws {
    // given
    try setReturnValue(LifiStatusResponse.stub())
    let request = LifiStatusRequest(txHash: "0xabc123")

    // when
    _ = try await lifiApi.getStatus(request: request)

    // then
    XCTAssertEqual(requestsSpy.executeRequestParam?.method, .get)
  }

  func test_getStatus_includesQueryParameters() async throws {
    // given
    try setReturnValue(LifiStatusResponse.stub())
    let request = LifiStatusRequest(
      txHash: "0xabc123def456",
      bridge: .relay,
      fromChain: "1",
      toChain: "137"
    )

    // when
    _ = try await lifiApi.getStatus(request: request)

    // then
    let urlString = requestsSpy.executeRequestParam?.url.absoluteString ?? ""
    XCTAssertTrue(urlString.contains("txHash=0xabc123def456"))
    XCTAssertTrue(urlString.contains("bridge=relay"))
    XCTAssertTrue(urlString.contains("fromChain=1"))
    XCTAssertTrue(urlString.contains("toChain=137"))
  }

  func test_getStatus_withOnlyTxHash() async throws {
    // given
    try setReturnValue(LifiStatusResponse.stub())
    let request = LifiStatusRequest(txHash: "0xtest")

    // when
    _ = try await lifiApi.getStatus(request: request)

    // then
    let urlString = requestsSpy.executeRequestParam?.url.absoluteString ?? ""
    XCTAssertTrue(urlString.contains("txHash=0xtest"))
    XCTAssertFalse(urlString.contains("bridge="))
    XCTAssertFalse(urlString.contains("fromChain="))
    XCTAssertFalse(urlString.contains("toChain="))
  }

  func test_getStatus_allBridgeTypes() async throws {
    // given
    let bridges: [LifiStatusBridge] = [
      .hop, .cbridge, .celercircle, .optimism, .polygon,
      .arbitrum, .avalanche, .across, .gnosis, .omni,
      .relay, .celerim, .symbiosis, .thorswap, .squid,
      .allbridge, .mayan, .debridge, .chainflip
    ]

    for bridge in bridges {
      try setReturnValue(LifiStatusResponse.stub())
      let request = LifiStatusRequest(txHash: "0xtest", bridge: bridge)

      // when
      _ = try await lifiApi.getStatus(request: request)

      // then
      let urlString = requestsSpy.executeRequestParam?.url.absoluteString ?? ""
      XCTAssertTrue(urlString.contains("bridge=\(bridge.rawValue)"), "Bridge \(bridge) should be in URL")
    }
  }
}

// MARK: - getRouteStep URL Construction Tests

extension PortalLifiTradingApiTests {
  func test_getRouteStep_constructsCorrectURL() async throws {
    // given
    try setReturnValue(LifiStepTransactionResponse.stub())
    let request = LifiStep.stub()

    // when
    _ = try await lifiApi.getRouteStep(request: request)

    // then
    let expectedURL = "https://api.portalhq.io/api/v3/clients/me/integrations/lifi/route-step-details"
    XCTAssertEqual(requestsSpy.executeRequestParam?.url.absoluteString, expectedURL)
  }

  func test_getRouteStep_usesPostMethod() async throws {
    // given
    try setReturnValue(LifiStepTransactionResponse.stub())
    let request = LifiStep.stub()

    // when
    _ = try await lifiApi.getRouteStep(request: request)

    // then
    XCTAssertEqual(requestsSpy.executeRequestParam?.method, .post)
  }

  func test_getRouteStep_includesBearerToken() async throws {
    // given
    try setReturnValue(LifiStepTransactionResponse.stub())
    let request = LifiStep.stub()

    // when
    _ = try await lifiApi.getRouteStep(request: request)

    // then
    XCTAssertEqual(requestsSpy.executeRequestParam?.headers["Authorization"], "Bearer \(testApiKey)")
  }

  func test_getRouteStep_sendsStepAsPayload() async throws {
    // given
    try setReturnValue(LifiStepTransactionResponse.stub())
    let request = LifiStep.stub(id: "step-test-123", type: .cross, tool: "relay")

    // when
    _ = try await lifiApi.getRouteStep(request: request)

    // then
    XCTAssertNotNil(requestsSpy.executeRequestParam?.payload)
  }
}

// MARK: - Response Handling Tests

extension PortalLifiTradingApiTests {
  func test_getRoutes_returnsSuccessfulResponse() async throws {
    // given
    let expectedResponse = LifiRoutesResponse.stub()
    try setReturnValue(expectedResponse)

    // when
    let response = try await lifiApi.getRoutes(request: LifiRoutesRequest.stub())

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertNil(response.error)
  }

  func test_getRoutes_returnsErrorResponse() async throws {
    // given
    let expectedResponse = LifiRoutesResponse(data: nil, error: "No routes available")
    try setReturnValue(expectedResponse)

    // when
    let response = try await lifiApi.getRoutes(request: LifiRoutesRequest.stub())

    // then
    XCTAssertNil(response.data)
    XCTAssertEqual(response.error, "No routes available")
  }

  func test_getQuote_returnsSuccessfulResponse() async throws {
    // given
    let expectedResponse = LifiQuoteResponse.stub()
    try setReturnValue(expectedResponse)

    // when
    let response = try await lifiApi.getQuote(request: LifiQuoteRequest.stub())

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
  }

  func test_getStatus_returnsSuccessfulResponse() async throws {
    // given
    let expectedResponse = LifiStatusResponse.stub()
    try setReturnValue(expectedResponse)

    // when
    let response = try await lifiApi.getStatus(request: LifiStatusRequest.stub())

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
  }

  func test_getRouteStep_returnsSuccessfulResponse() async throws {
    // given
    let expectedResponse = LifiStepTransactionResponse.stub()
    try setReturnValue(expectedResponse)

    // when
    let response = try await lifiApi.getRouteStep(request: LifiStep.stub())

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
  }
}

// MARK: - Multiple Calls Tests

extension PortalLifiTradingApiTests {
  func test_multipleCalls_trackCorrectly() async throws {
    // given
    try setReturnValue(LifiRoutesResponse.stub())

    // when
    _ = try await lifiApi.getRoutes(request: LifiRoutesRequest.stub())
    _ = try await lifiApi.getRoutes(request: LifiRoutesRequest.stub())
    _ = try await lifiApi.getRoutes(request: LifiRoutesRequest.stub())

    // then
    XCTAssertEqual(requestsSpy.executeCallsCount, 3)
  }

  func test_differentMethods_callCorrectEndpoints() async throws {
    // given
    try setReturnValue(LifiRoutesResponse.stub())
    _ = try await lifiApi.getRoutes(request: LifiRoutesRequest.stub())
    let routesURL = requestsSpy.executeRequestParam?.url.absoluteString

    try setReturnValue(LifiQuoteResponse.stub())
    _ = try await lifiApi.getQuote(request: LifiQuoteRequest.stub())
    let quoteURL = requestsSpy.executeRequestParam?.url.absoluteString

    try setReturnValue(LifiStatusResponse.stub())
    _ = try await lifiApi.getStatus(request: LifiStatusRequest.stub())
    let statusURL = requestsSpy.executeRequestParam?.url.absoluteString

    try setReturnValue(LifiStepTransactionResponse.stub())
    _ = try await lifiApi.getRouteStep(request: LifiStep.stub())
    let stepURL = requestsSpy.executeRequestParam?.url.absoluteString

    // then
    XCTAssertTrue(routesURL?.contains("/routes") ?? false)
    XCTAssertTrue(quoteURL?.contains("/quote") ?? false)
    XCTAssertTrue(statusURL?.contains("/status") ?? false)
    XCTAssertTrue(stepURL?.contains("/route-step-details") ?? false)
  }
}

// MARK: - Request Payload Tests

extension PortalLifiTradingApiTests {
  func test_getRoutes_payloadContainsAllRequiredFields() async throws {
    // given
    try setReturnValue(LifiRoutesResponse.stub())
    let request = LifiRoutesRequest(
      fromChainId: "1",
      fromAmount: "1000000000000000000",
      fromTokenAddress: "0xETH",
      toChainId: "137",
      toTokenAddress: "0xMATIC"
    )

    // when
    _ = try await lifiApi.getRoutes(request: request)

    // then
    let payload = requestsSpy.executeRequestParam?.payload as? LifiRoutesRequest
    XCTAssertEqual(payload?.fromChainId, "1")
    XCTAssertEqual(payload?.fromAmount, "1000000000000000000")
    XCTAssertEqual(payload?.fromTokenAddress, "0xETH")
    XCTAssertEqual(payload?.toChainId, "137")
    XCTAssertEqual(payload?.toTokenAddress, "0xMATIC")
  }

  func test_getRoutes_payloadContainsOptionalFields() async throws {
    // given
    try setReturnValue(LifiRoutesResponse.stub())
    let options = LifiRoutesRequestOptions(
      integrator: "portal",
      slippage: 0.01,
      order: .cheapest
    )
    let request = LifiRoutesRequest(
      fromChainId: "1",
      fromAmount: "1000000000000000000",
      fromTokenAddress: "0xETH",
      toChainId: "137",
      toTokenAddress: "0xMATIC",
      options: options,
      fromAddress: "0xSender",
      toAddress: "0xReceiver",
      fromAmountForGas: "50000000000000000"
    )

    // when
    _ = try await lifiApi.getRoutes(request: request)

    // then
    let payload = requestsSpy.executeRequestParam?.payload as? LifiRoutesRequest
    XCTAssertEqual(payload?.options?.integrator, "portal")
    XCTAssertEqual(payload?.options?.slippage, 0.01)
    XCTAssertEqual(payload?.options?.order, .cheapest)
    XCTAssertEqual(payload?.fromAddress, "0xSender")
    XCTAssertEqual(payload?.toAddress, "0xReceiver")
    XCTAssertEqual(payload?.fromAmountForGas, "50000000000000000")
  }

  func test_getQuote_payloadContainsAllFields() async throws {
    // given
    try setReturnValue(LifiQuoteResponse.stub())
    let request = LifiQuoteRequest(
      fromChain: "1",
      toChain: "137",
      fromToken: "ETH",
      toToken: "MATIC",
      fromAddress: "0xSender",
      fromAmount: "1000000000000000000",
      toAddress: "0xReceiver",
      order: .fastest,
      slippage: 0.005,
      integrator: "portal"
    )

    // when
    _ = try await lifiApi.getQuote(request: request)

    // then
    let payload = requestsSpy.executeRequestParam?.payload as? LifiQuoteRequest
    XCTAssertEqual(payload?.fromChain, "1")
    XCTAssertEqual(payload?.toChain, "137")
    XCTAssertEqual(payload?.fromToken, "ETH")
    XCTAssertEqual(payload?.toToken, "MATIC")
    XCTAssertEqual(payload?.fromAddress, "0xSender")
    XCTAssertEqual(payload?.fromAmount, "1000000000000000000")
    XCTAssertEqual(payload?.toAddress, "0xReceiver")
    XCTAssertEqual(payload?.order, .fastest)
    XCTAssertEqual(payload?.slippage, 0.005)
    XCTAssertEqual(payload?.integrator, "portal")
  }
}

// MARK: - Thread Safety Tests

extension PortalLifiTradingApiTests {
  func test_concurrentCalls_handleCorrectly() async throws {
    // given
    try setReturnValue(LifiRoutesResponse.stub())
    let callCount = 10

    // when
    await withTaskGroup(of: Void.self) { group in
      for _ in 0 ..< callCount {
        group.addTask {
          _ = try? await self.lifiApi.getRoutes(request: LifiRoutesRequest.stub())
        }
      }
    }

    // then
    XCTAssertEqual(requestsSpy.executeCallsCount, callCount)
  }
}

// MARK: - API Key Tests

extension PortalLifiTradingApiTests {
  func test_allMethods_useSameApiKey() async throws {
    // given
    let customApiKey = "custom-api-key-67890"
    let customApi = PortalLifiTradingApi(apiKey: customApiKey, requests: requestsSpy)

    // Routes
    try setReturnValue(LifiRoutesResponse.stub())
    _ = try await customApi.getRoutes(request: LifiRoutesRequest.stub())
    XCTAssertEqual(requestsSpy.executeRequestParam?.headers["Authorization"], "Bearer \(customApiKey)")

    // Quote
    try setReturnValue(LifiQuoteResponse.stub())
    _ = try await customApi.getQuote(request: LifiQuoteRequest.stub())
    XCTAssertEqual(requestsSpy.executeRequestParam?.headers["Authorization"], "Bearer \(customApiKey)")

    // Status
    try setReturnValue(LifiStatusResponse.stub())
    _ = try await customApi.getStatus(request: LifiStatusRequest.stub())
    XCTAssertEqual(requestsSpy.executeRequestParam?.headers["Authorization"], "Bearer \(customApiKey)")

    // Route Step
    try setReturnValue(LifiStepTransactionResponse.stub())
    _ = try await customApi.getRouteStep(request: LifiStep.stub())
    XCTAssertEqual(requestsSpy.executeRequestParam?.headers["Authorization"], "Bearer \(customApiKey)")
  }

  func test_emptyApiKey_stillSendsAuthorizationHeader() async throws {
    // given
    let emptyApiKeyApi = PortalLifiTradingApi(apiKey: "", requests: requestsSpy)
    try setReturnValue(LifiRoutesResponse.stub())

    // when
    _ = try await emptyApiKeyApi.getRoutes(request: LifiRoutesRequest.stub())

    // then
    XCTAssertEqual(requestsSpy.executeRequestParam?.headers["Authorization"], "Bearer ")
  }
}

// MARK: - Host Configuration Tests

extension PortalLifiTradingApiTests {
  func test_customHost_usedInAllRequests() async throws {
    // given
    let customHost = "custom.lifi.io"
    let customApi = PortalLifiTradingApi(apiKey: testApiKey, apiHost: customHost, requests: requestsSpy)
    try setReturnValue(LifiRoutesResponse.stub())

    // when
    _ = try await customApi.getRoutes(request: LifiRoutesRequest.stub())

    // then
    XCTAssertTrue(requestsSpy.executeRequestParam?.url.absoluteString.contains(customHost) ?? false)
  }

  func test_localhostWithPort_usesHttpScheme() async throws {
    // given
    let localhostApi = PortalLifiTradingApi(apiKey: testApiKey, apiHost: "localhost:8080", requests: requestsSpy)
    try setReturnValue(LifiRoutesResponse.stub())

    // when
    _ = try await localhostApi.getRoutes(request: LifiRoutesRequest.stub())

    // then
    let urlString = requestsSpy.executeRequestParam?.url.absoluteString ?? ""
    XCTAssertTrue(urlString.hasPrefix("http://localhost:8080"))
  }

  func test_productionHost_usesHttpsScheme() async throws {
    // given
    try setReturnValue(LifiRoutesResponse.stub())

    // when
    _ = try await lifiApi.getRoutes(request: LifiRoutesRequest.stub())

    // then
    let urlString = requestsSpy.executeRequestParam?.url.absoluteString ?? ""
    XCTAssertTrue(urlString.hasPrefix("https://"))
  }
}
