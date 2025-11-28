//
//  LifiTests.swift
//  PortalSwift
//
//  Created by Portal Labs
//

import Foundation
@testable import PortalSwift
import XCTest
import AnyCodable

final class LifiTests: XCTestCase {
  var apiMock: PortalLifiTradingApiMock!
  var lifi: Lifi!

  override func setUpWithError() throws {
    apiMock = PortalLifiTradingApiMock()
    lifi = Lifi(api: apiMock)
  }

  override func tearDownWithError() throws {
    apiMock = nil
    lifi = nil
  }
}

// MARK: - Initialization Tests

extension LifiTests {
  func test_init_createsInstanceSuccessfully() {
    // given
    let api = PortalLifiTradingApiMock()

    // when
    let lifiInstance = Lifi(api: api)

    // then
    XCTAssertNotNil(lifiInstance)
  }

  func test_init_conformsToLifiProtocol() {
    // given
    let api = PortalLifiTradingApiMock()

    // when
    let lifiInstance = Lifi(api: api)

    // then
    XCTAssertTrue(lifiInstance is LifiProtocol)
  }

  func test_init_withSpy() {
    // given
    let spy = PortalLifiTradingApiSpy()

    // when
    let lifiInstance = Lifi(api: spy)

    // then
    XCTAssertNotNil(lifiInstance)
  }
}

// MARK: - getRoutes Tests

extension LifiTests {
  func test_getRoutes_returnsRoutesSuccessfully() async throws {
    // given
    let mockResponse = LifiRoutesResponse.stub()
    apiMock.getRoutesReturnValue = mockResponse
    let request = LifiRoutesRequest.stub()

    // when
    let response = try await lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertNil(response.error)
    XCTAssertEqual(apiMock.getRoutesCalls, 1)
  }

  func test_getRoutes_withMinimalRequest() async throws {
    // given
    let mockResponse = LifiRoutesResponse.stub()
    apiMock.getRoutesReturnValue = mockResponse
    let request = LifiRoutesRequest(
      fromChainId: "1",
      fromAmount: "1000000",
      fromTokenAddress: "0x0",
      toChainId: "137",
      toTokenAddress: "0x0"
    )

    // when
    let response = try await lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getRoutesCalls, 1)
  }

  func test_getRoutes_withFullRequest() async throws {
    // given
    let mockResponse = LifiRoutesResponse.stub()
    apiMock.getRoutesReturnValue = mockResponse
    let options = LifiRoutesRequestOptions.stub(
      integrator: "portal",
      slippage: 0.01,
      order: .cheapest,
      allowSwitchChain: true,
      allowDestinationCall: true,
      maxPriceImpact: 0.15
    )
    let request = LifiRoutesRequest(
      fromChainId: "1",
      fromAmount: "1000000000000000000",
      fromTokenAddress: "0x0000000000000000000000000000000000000000",
      toChainId: "137",
      toTokenAddress: "0x0000000000000000000000000000000000001010",
      options: options,
      fromAddress: "0x1234567890abcdef1234567890abcdef12345678",
      toAddress: "0x1234567890abcdef1234567890abcdef12345678",
      fromAmountForGas: "1000000000000000"
    )

    // when
    let response = try await lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data?.rawResponse.routes)
  }

  func test_getRoutes_withMultipleRoutes() async throws {
    // given
    let routes = [
      LifiRoute.stub(id: "route-1", tags: ["FASTEST"]),
      LifiRoute.stub(id: "route-2", tags: ["CHEAPEST"]),
      LifiRoute.stub(id: "route-3", tags: ["RECOMMENDED"])
    ]
    let rawResponse = LifiRoutesRawResponse.stub(routes: routes)
    let mockResponse = LifiRoutesResponse.stub(data: LifiRoutesData(rawResponse: rawResponse))
    apiMock.getRoutesReturnValue = mockResponse
    let request = LifiRoutesRequest.stub()

    // when
    let response = try await lifi.getRoutes(request: request)

    // then
    XCTAssertEqual(response.data?.rawResponse.routes.count, 3)
    XCTAssertEqual(response.data?.rawResponse.routes[0].tags, ["FASTEST"])
    XCTAssertEqual(response.data?.rawResponse.routes[1].tags, ["CHEAPEST"])
  }

  func test_getRoutes_withEmptyRoutes() async throws {
    // given
    let rawResponse = LifiRoutesRawResponse.stub(routes: [])
    let mockResponse = LifiRoutesResponse.stub(data: LifiRoutesData(rawResponse: rawResponse))
    apiMock.getRoutesReturnValue = mockResponse
    let request = LifiRoutesRequest.stub()

    // when
    let response = try await lifi.getRoutes(request: request)

    // then
    XCTAssertEqual(response.data?.rawResponse.routes.count, 0)
  }

  func test_getRoutes_withUnavailableRoutes() async throws {
    // given
    let unavailableRoutes = LifiUnavailableRoutes.stub(
      filteredOut: [LifiFilteredRoute.stub(reason: "Amount too low")],
      failed: [LifiFailedRoute.stub(overallPath: "1:ETH-hop-137:MATIC")]
    )
    let rawResponse = LifiRoutesRawResponse.stub(routes: [], unavailableRoutes: unavailableRoutes)
    let mockResponse = LifiRoutesResponse.stub(data: LifiRoutesData(rawResponse: rawResponse))
    apiMock.getRoutesReturnValue = mockResponse
    let request = LifiRoutesRequest.stub()

    // when
    let response = try await lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response.data?.rawResponse.unavailableRoutes)
    XCTAssertEqual(response.data?.rawResponse.unavailableRoutes?.filteredOut?.count, 1)
    XCTAssertEqual(response.data?.rawResponse.unavailableRoutes?.failed?.count, 1)
  }

  func test_getRoutes_withError() async throws {
    // given
    let mockResponse = LifiRoutesResponse.stub(data: nil, error: "No routes found")
    apiMock.getRoutesReturnValue = mockResponse
    let request = LifiRoutesRequest.stub()

    // when
    let response = try await lifi.getRoutes(request: request)

    // then
    XCTAssertNil(response.data)
    XCTAssertEqual(response.error, "No routes found")
  }

  func test_getRoutes_withBridgesConfiguration() async throws {
    // given
    let mockResponse = LifiRoutesResponse.stub()
    apiMock.getRoutesReturnValue = mockResponse
    let bridges = LifiToolsConfiguration(
      allow: ["hop", "across"],
      deny: ["cbridge"],
      prefer: ["relay"]
    )
    let options = LifiRoutesRequestOptions.stub(bridges: bridges)
    let request = LifiRoutesRequest.stub(options: options)

    // when
    let response = try await lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getRoutesCalls, 1)
  }

  func test_getRoutes_withExchangesConfiguration() async throws {
    // given
    let mockResponse = LifiRoutesResponse.stub()
    apiMock.getRoutesReturnValue = mockResponse
    let exchanges = LifiToolsConfiguration(
      allow: ["uniswap", "sushiswap"],
      deny: nil,
      prefer: ["1inch"]
    )
    let options = LifiRoutesRequestOptions.stub(exchanges: exchanges)
    let request = LifiRoutesRequest.stub(options: options)

    // when
    let response = try await lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response)
  }

  func test_getRoutes_withTimingOptions() async throws {
    // given
    let mockResponse = LifiRoutesResponse.stub()
    apiMock.getRoutesReturnValue = mockResponse
    let timing = LifiTimingOptions(
      swapStepTimingStrategies: [LifiTimingStrategy(strategy: .minWaitTime, minWaitTimeMs: 1000)],
      routeTimingStrategies: [LifiTimingStrategy(strategy: .minWaitTime, minWaitTimeMs: 2000)]
    )
    let options = LifiRoutesRequestOptions.stub(timing: timing)
    let request = LifiRoutesRequest.stub(options: options)

    // when
    let response = try await lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response)
  }
}

// MARK: - getQuote Tests

extension LifiTests {
  func test_getQuote_returnsQuoteSuccessfully() async throws {
    // given
    let mockResponse = LifiQuoteResponse.stub()
    apiMock.getQuoteReturnValue = mockResponse
    let request = LifiQuoteRequest.stub()

    // when
    let response = try await lifi.getQuote(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertNil(response.error)
    XCTAssertEqual(apiMock.getQuoteCalls, 1)
  }

  func test_getQuote_withMinimalRequest() async throws {
    // given
    let mockResponse = LifiQuoteResponse.stub()
    apiMock.getQuoteReturnValue = mockResponse
    let request = LifiQuoteRequest(
      fromChain: "1",
      toChain: "137",
      fromToken: "ETH",
      toToken: "MATIC",
      fromAddress: "0x1234567890abcdef1234567890abcdef12345678",
      fromAmount: "1000000000000000000"
    )

    // when
    let response = try await lifi.getQuote(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getQuoteCalls, 1)
  }

  func test_getQuote_withFullRequest() async throws {
    // given
    let mockResponse = LifiQuoteResponse.stub()
    apiMock.getQuoteReturnValue = mockResponse
    let request = LifiQuoteRequest(
      fromChain: "1",
      toChain: "137",
      fromToken: "0x0000000000000000000000000000000000000000",
      toToken: "0x0000000000000000000000000000000000001010",
      fromAddress: "0x1234567890abcdef1234567890abcdef12345678",
      fromAmount: "1000000000000000000",
      toAddress: "0xabcdef1234567890abcdef1234567890abcdef12",
      order: .cheapest,
      slippage: 0.01,
      integrator: "portal",
      fee: 0.003,
      referrer: "0xReferrer",
      allowBridges: ["hop", "across"],
      allowExchanges: ["uniswap"],
      denyBridges: ["cbridge"],
      denyExchanges: nil,
      preferBridges: ["relay"],
      preferExchanges: ["1inch"],
      allowDestinationCall: true,
      fromAmountForGas: "1000000000000000",
      maxPriceImpact: 0.15,
      swapStepTimingStrategies: ["minWaitTime-1000-10-100"],
      routeTimingStrategies: ["minWaitTime-2000-5-200"],
      skipSimulation: true
    )

    // when
    let response = try await lifi.getQuote(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data?.rawResponse)
  }

  func test_getQuote_withError() async throws {
    // given
    let mockResponse = LifiQuoteResponse.stub(data: nil, error: "Unable to find quote")
    apiMock.getQuoteReturnValue = mockResponse
    let request = LifiQuoteRequest.stub()

    // when
    let response = try await lifi.getQuote(request: request)

    // then
    XCTAssertNil(response.data)
    XCTAssertEqual(response.error, "Unable to find quote")
  }

  func test_getQuote_withDifferentOrderOptions() async throws {
    // given
    let mockResponse = LifiQuoteResponse.stub()
    apiMock.getQuoteReturnValue = mockResponse

    // when - fastest
    let fastestRequest = LifiQuoteRequest.stub(order: .fastest)
    let fastestResponse = try await lifi.getQuote(request: fastestRequest)

    // when - cheapest
    let cheapestRequest = LifiQuoteRequest.stub(order: .cheapest)
    let cheapestResponse = try await lifi.getQuote(request: cheapestRequest)

    // then
    XCTAssertNotNil(fastestResponse)
    XCTAssertNotNil(cheapestResponse)
    XCTAssertEqual(apiMock.getQuoteCalls, 2)
  }

  func test_getQuote_withIncludedSteps() async throws {
    // given
    let step = LifiStep.stub(
      includedSteps: [
        LifiInternalStep.stub(id: "swap-1", type: .swap),
        LifiInternalStep.stub(id: "bridge-1", type: .cross)
      ]
    )
    let quoteData = LifiQuoteData(rawResponse: step)
    let mockResponse = LifiQuoteResponse(data: quoteData, error: nil)
    apiMock.getQuoteReturnValue = mockResponse
    let request = LifiQuoteRequest.stub()

    // when
    let response = try await lifi.getQuote(request: request)

    // then
    XCTAssertEqual(response.data?.rawResponse.includedSteps?.count, 2)
    XCTAssertEqual(response.data?.rawResponse.includedSteps?[0].type, .swap)
    XCTAssertEqual(response.data?.rawResponse.includedSteps?[1].type, .cross)
  }

  func test_getQuote_withEstimateData() async throws {
    // given
    let estimate = LifiEstimate.stub(
      fromAmount: "1000000000000000000",
      toAmount: "950000000000000000",
      toAmountMin: "940000000000000000",
      executionDuration: 120.0,
      feeCosts: [LifiFeeCost.stub()],
      gasCosts: [LifiGasCost.stub()]
    )
    let step = LifiStep.stub(estimate: estimate)
    let mockResponse = LifiQuoteResponse(data: LifiQuoteData(rawResponse: step), error: nil)
    apiMock.getQuoteReturnValue = mockResponse
    let request = LifiQuoteRequest.stub()

    // when
    let response = try await lifi.getQuote(request: request)

    // then
    XCTAssertNotNil(response.data?.rawResponse.estimate)
    XCTAssertEqual(response.data?.rawResponse.estimate?.executionDuration, 120.0)
    XCTAssertNotNil(response.data?.rawResponse.estimate?.feeCosts)
    XCTAssertNotNil(response.data?.rawResponse.estimate?.gasCosts)
  }
}

// MARK: - getStatus Tests

extension LifiTests {
  func test_getStatus_returnsStatusSuccessfully() async throws {
    // given
    let mockResponse = LifiStatusResponse.stub()
    apiMock.getStatusReturnValue = mockResponse
    let request = LifiStatusRequest.stub()

    // when
    let response = try await lifi.getStatus(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertNil(response.error)
    XCTAssertEqual(apiMock.getStatusCalls, 1)
  }

  func test_getStatus_withMinimalRequest() async throws {
    // given
    let mockResponse = LifiStatusResponse.stub()
    apiMock.getStatusReturnValue = mockResponse
    let request = LifiStatusRequest(txHash: "0xabc123")

    // when
    let response = try await lifi.getStatus(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getStatusCalls, 1)
  }

  func test_getStatus_withFullRequest() async throws {
    // given
    let mockResponse = LifiStatusResponse.stub()
    apiMock.getStatusReturnValue = mockResponse
    let request = LifiStatusRequest(
      txHash: "0xabc123def456789",
      bridge: .relay,
      fromChain: "1",
      toChain: "137"
    )

    // when
    let response = try await lifi.getStatus(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data?.rawResponse)
  }

  func test_getStatus_pendingStatus() async throws {
    // given
    let rawResponse = LifiStatusRawResponse.stub(
      status: .pending,
      substatus: .waitSourceConfirmations,
      substatusMessage: "Waiting for confirmations"
    )
    let mockResponse = LifiStatusResponse.stub(data: LifiStatusData(rawResponse: rawResponse))
    apiMock.getStatusReturnValue = mockResponse
    let request = LifiStatusRequest.stub()

    // when
    let response = try await lifi.getStatus(request: request)

    // then
    XCTAssertEqual(response.data?.rawResponse.status, .pending)
    XCTAssertEqual(response.data?.rawResponse.substatus, .waitSourceConfirmations)
    XCTAssertEqual(response.data?.rawResponse.substatusMessage, "Waiting for confirmations")
  }

  func test_getStatus_doneStatus() async throws {
    // given
    let rawResponse = LifiStatusRawResponse.stub(
      status: .done,
      substatus: .completed,
      substatusMessage: "Transfer completed"
    )
    let mockResponse = LifiStatusResponse.stub(data: LifiStatusData(rawResponse: rawResponse))
    apiMock.getStatusReturnValue = mockResponse
    let request = LifiStatusRequest.stub()

    // when
    let response = try await lifi.getStatus(request: request)

    // then
    XCTAssertEqual(response.data?.rawResponse.status, .done)
    XCTAssertEqual(response.data?.rawResponse.substatus, .completed)
  }

  func test_getStatus_failedStatus() async throws {
    // given
    let rawResponse = LifiStatusRawResponse.stub(
      status: .failed,
      substatus: .unknownError,
      substatusMessage: "Transaction reverted"
    )
    let mockResponse = LifiStatusResponse.stub(data: LifiStatusData(rawResponse: rawResponse))
    apiMock.getStatusReturnValue = mockResponse
    let request = LifiStatusRequest.stub()

    // when
    let response = try await lifi.getStatus(request: request)

    // then
    XCTAssertEqual(response.data?.rawResponse.status, .failed)
    XCTAssertEqual(response.data?.rawResponse.substatus, .unknownError)
  }

  func test_getStatus_notFoundStatus() async throws {
    // given
    let rawResponse = LifiStatusRawResponse.stub(status: .notFound)
    let mockResponse = LifiStatusResponse.stub(data: LifiStatusData(rawResponse: rawResponse))
    apiMock.getStatusReturnValue = mockResponse
    let request = LifiStatusRequest.stub()

    // when
    let response = try await lifi.getStatus(request: request)

    // then
    XCTAssertEqual(response.data?.rawResponse.status, .notFound)
  }

  func test_getStatus_invalidStatus() async throws {
    // given
    let rawResponse = LifiStatusRawResponse.stub(status: .invalid)
    let mockResponse = LifiStatusResponse.stub(data: LifiStatusData(rawResponse: rawResponse))
    apiMock.getStatusReturnValue = mockResponse
    let request = LifiStatusRequest.stub()

    // when
    let response = try await lifi.getStatus(request: request)

    // then
    XCTAssertEqual(response.data?.rawResponse.status, .invalid)
  }

  func test_getStatus_withReceivingInfo() async throws {
    // given
    let receiving = LifiReceivingInfo.stub(
      chainId: "137",
      txHash: "0xdef789",
      amount: "950000000000000000"
    )
    let rawResponse = LifiStatusRawResponse.stub(receiving: receiving)
    let mockResponse = LifiStatusResponse.stub(data: LifiStatusData(rawResponse: rawResponse))
    apiMock.getStatusReturnValue = mockResponse
    let request = LifiStatusRequest.stub()

    // when
    let response = try await lifi.getStatus(request: request)

    // then
    XCTAssertNotNil(response.data?.rawResponse.receiving)
    XCTAssertEqual(response.data?.rawResponse.receiving?.chainId, "137")
    XCTAssertEqual(response.data?.rawResponse.receiving?.txHash, "0xdef789")
  }

  func test_getStatus_withDifferentBridges() async throws {
    // given
    let mockResponse = LifiStatusResponse.stub()
    apiMock.getStatusReturnValue = mockResponse

    let bridges: [LifiStatusBridge] = [
      .hop, .cbridge, .across, .relay, .symbiosis, .thorswap, .squid, .allbridge, .mayan, .debridge, .chainflip
    ]

    for bridge in bridges {
      let request = LifiStatusRequest(txHash: "0xtest", bridge: bridge)

      // when
      let response = try await lifi.getStatus(request: request)

      // then
      XCTAssertNotNil(response)
    }

    XCTAssertEqual(apiMock.getStatusCalls, bridges.count)
  }

  func test_getStatus_withError() async throws {
    // given
    let mockResponse = LifiStatusResponse.stub(data: nil, error: "Transaction not found")
    apiMock.getStatusReturnValue = mockResponse
    let request = LifiStatusRequest.stub()

    // when
    let response = try await lifi.getStatus(request: request)

    // then
    XCTAssertNil(response.data)
    XCTAssertEqual(response.error, "Transaction not found")
  }

  func test_getStatus_withSubstatuses() async throws {
    // given
    let substatuses: [LifiTransferSubstatus] = [
      .waitSourceConfirmations,
      .waitDestinationTransaction,
      .bridgeNotAvailable,
      .chainNotAvailable,
      .refundInProgress,
      .unknownError,
      .completed,
      .partial,
      .refunded
    ]

    for substatus in substatuses {
      let rawResponse = LifiStatusRawResponse.stub(substatus: substatus)
      let mockResponse = LifiStatusResponse.stub(data: LifiStatusData(rawResponse: rawResponse))
      apiMock.getStatusReturnValue = mockResponse
      let request = LifiStatusRequest.stub()

      // when
      let response = try await lifi.getStatus(request: request)

      // then
      XCTAssertEqual(response.data?.rawResponse.substatus, substatus)
    }
  }
}

// MARK: - getRouteStep Tests

extension LifiTests {
  func test_getRouteStep_returnsStepSuccessfully() async throws {
    // given
    let mockResponse = LifiStepTransactionResponse.stub()
    apiMock.getRouteStepReturnValue = mockResponse
    let request = LifiStep.stub()

    // when
    let response = try await lifi.getRouteStep(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertNil(response.error)
    XCTAssertEqual(apiMock.getRouteStepCalls, 1)
  }

  func test_getRouteStep_withSwapStep() async throws {
    // given
    let mockResponse = LifiStepTransactionResponse.stub()
    apiMock.getRouteStepReturnValue = mockResponse
    let request = LifiStep.stub(type: .swap, tool: "uniswap")

    // when
    let response = try await lifi.getRouteStep(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data?.rawResponse)
  }

  func test_getRouteStep_withCrossChainStep() async throws {
    // given
    let mockResponse = LifiStepTransactionResponse.stub()
    apiMock.getRouteStepReturnValue = mockResponse
    let request = LifiStep.stub(type: .cross, tool: "relay")

    // when
    let response = try await lifi.getRouteStep(request: request)

    // then
    XCTAssertNotNil(response)
  }

  func test_getRouteStep_withLifiStep() async throws {
    // given
    let mockResponse = LifiStepTransactionResponse.stub()
    apiMock.getRouteStepReturnValue = mockResponse
    let request = LifiStep.stub(type: .lifi)

    // when
    let response = try await lifi.getRouteStep(request: request)

    // then
    XCTAssertNotNil(response)
  }

  func test_getRouteStep_withProtocolStep() async throws {
    // given
    let mockResponse = LifiStepTransactionResponse.stub()
    apiMock.getRouteStepReturnValue = mockResponse
    let request = LifiStep.stub(type: .protocol)

    // when
    let response = try await lifi.getRouteStep(request: request)

    // then
    XCTAssertNotNil(response)
  }

  func test_getRouteStep_withError() async throws {
    // given
    let mockResponse = LifiStepTransactionResponse.stub(data: nil, error: "Step execution failed")
    apiMock.getRouteStepReturnValue = mockResponse
    let request = LifiStep.stub()

    // when
    let response = try await lifi.getRouteStep(request: request)

    // then
    XCTAssertNil(response.data)
    XCTAssertEqual(response.error, "Step execution failed")
  }

  func test_getRouteStep_withTransactionRequest() async throws {
    // given
    let step = LifiStep.stub(transactionRequest: AnyCodable(["to": "0xtest", "value": "1000"]))
    let mockResponse = LifiStepTransactionResponse(data: LifiStepTransactionData(rawResponse: step), error: nil)
    apiMock.getRouteStepReturnValue = mockResponse
    let request = LifiStep.stub()

    // when
    let response = try await lifi.getRouteStep(request: request)

    // then
    XCTAssertNotNil(response.data?.rawResponse.transactionRequest)
  }

  func test_getRouteStep_withEstimate() async throws {
    // given
    let estimate = LifiEstimate.stub(
      fromAmount: "1000000000000000000",
      toAmount: "950000000000000000",
      executionDuration: 60.0
    )
    let step = LifiStep.stub(estimate: estimate)
    let mockResponse = LifiStepTransactionResponse(data: LifiStepTransactionData(rawResponse: step), error: nil)
    apiMock.getRouteStepReturnValue = mockResponse
    let request = LifiStep.stub()

    // when
    let response = try await lifi.getRouteStep(request: request)

    // then
    XCTAssertNotNil(response.data?.rawResponse.estimate)
    XCTAssertEqual(response.data?.rawResponse.estimate?.executionDuration, 60.0)
  }
}

// MARK: - Multiple Instance Tests

extension LifiTests {
  func test_multipleInstances_haveIndependentApis() {
    // given
    let api1 = PortalLifiTradingApiMock()
    let api2 = PortalLifiTradingApiMock()

    // when
    let lifi1 = Lifi(api: api1)
    let lifi2 = Lifi(api: api2)

    // then
    XCTAssertFalse(lifi1 === lifi2)
  }

  func test_multipleInstances_canOperateIndependently() async throws {
    // given
    let api1 = PortalLifiTradingApiMock()
    api1.getRoutesReturnValue = LifiRoutesResponse.stub()
    let api2 = PortalLifiTradingApiMock()
    api2.getRoutesReturnValue = LifiRoutesResponse.stub()

    let lifi1 = Lifi(api: api1)
    let lifi2 = Lifi(api: api2)

    // when
    _ = try await lifi1.getRoutes(request: LifiRoutesRequest.stub())
    _ = try await lifi2.getRoutes(request: LifiRoutesRequest.stub())

    // then
    XCTAssertEqual(api1.getRoutesCalls, 1)
    XCTAssertEqual(api2.getRoutesCalls, 1)
  }
}

// MARK: - Thread Safety Tests

extension LifiTests {
  func test_concurrentCalls_areHandledCorrectly() async throws {
    // given
    let mockResponse = LifiRoutesResponse.stub()
    apiMock.getRoutesReturnValue = mockResponse
    let request = LifiRoutesRequest.stub()
    let callCount = 10

    // when
    await withTaskGroup(of: LifiRoutesResponse.self) { group in
      for _ in 0 ..< callCount {
        group.addTask {
          try! await self.lifi.getRoutes(request: request)
        }
      }

      var responses: [LifiRoutesResponse] = []
      for await response in group {
        responses.append(response)
      }

      // then
      XCTAssertEqual(responses.count, callCount)
    }

    XCTAssertEqual(apiMock.getRoutesCalls, callCount)
  }
}

// MARK: - Protocol Conformance Tests

extension LifiTests {
  func test_lifi_conformsToLifiProtocol() {
    // given
    let lifiInstance: LifiProtocol = lifi

    // then
    XCTAssertNotNil(lifiInstance)
    XCTAssertTrue(lifiInstance is LifiProtocol)
  }

  func test_lifiMock_conformsToLifiProtocol() {
    // given
    let lifiMock = LifiMock()

    // when
    let conformsToProtocol = lifiMock is LifiProtocol

    // then
    XCTAssertTrue(conformsToProtocol)
  }

  func test_protocol_canBeUsedPolymorphically() {
    // given
    let implementations: [LifiProtocol] = [
      Lifi(api: PortalLifiTradingApiMock()),
      LifiMock()
    ]

    // when & then
    for implementation in implementations {
      XCTAssertNotNil(implementation)
      XCTAssertTrue(implementation is LifiProtocol)
    }
  }
}

// MARK: - Mock Behavior Tests

extension LifiTests {
  func test_lifiMock_defaultReturnValues() async throws {
    // given
    let lifiMock = LifiMock()

    // when - calling methods without setting return values
    let routesResponse = try await lifiMock.getRoutes(request: LifiRoutesRequest.stub())
    let quoteResponse = try await lifiMock.getQuote(request: LifiQuoteRequest.stub())
    let statusResponse = try await lifiMock.getStatus(request: LifiStatusRequest.stub())
    let stepResponse = try await lifiMock.getRouteStep(request: LifiStep.stub())

    // then - should return stub values
    XCTAssertNotNil(routesResponse)
    XCTAssertNotNil(quoteResponse)
    XCTAssertNotNil(statusResponse)
    XCTAssertNotNil(stepResponse)
  }

  func test_lifiMock_customReturnValues() async throws {
    // given
    let customResponse = LifiRoutesResponse(data: nil, error: "Custom error")
    let lifiMock = LifiMock()
    lifiMock.getRoutesReturnValue = customResponse

    // when
    let response = try await lifiMock.getRoutes(request: LifiRoutesRequest.stub())

    // then
    XCTAssertEqual(response.error, "Custom error")
    XCTAssertNil(response.data)
  }

  func test_lifiMock_parameterCapture() async throws {
    // given
    let lifiMock = LifiMock()
    let request = LifiRoutesRequest(
      fromChainId: "1",
      fromAmount: "1000000000000000000",
      fromTokenAddress: "0xETH",
      toChainId: "137",
      toTokenAddress: "0xMATIC",
      options: LifiRoutesRequestOptions.stub(slippage: 0.01)
    )

    // when
    _ = try await lifiMock.getRoutes(request: request)

    // then - should capture the request parameters
    XCTAssertNotNil(lifiMock.getRoutesRequestParam)
    XCTAssertEqual(lifiMock.getRoutesRequestParam?.fromChainId, "1")
    XCTAssertEqual(lifiMock.getRoutesRequestParam?.toChainId, "137")
    XCTAssertEqual(lifiMock.getRoutesRequestParam?.options?.slippage, 0.01)
  }

  func test_lifiMock_tracksMultipleCalls() async throws {
    // given
    let lifiMock = LifiMock()

    // when
    _ = try await lifiMock.getRoutes(request: LifiRoutesRequest.stub())
    _ = try await lifiMock.getRoutes(request: LifiRoutesRequest.stub())
    _ = try await lifiMock.getRoutes(request: LifiRoutesRequest.stub())

    // then
    XCTAssertEqual(lifiMock.getRoutesCalls, 3)
  }

  func test_lifiMock_tracksDifferentMethodCalls() async throws {
    // given
    let lifiMock = LifiMock()

    // when
    _ = try await lifiMock.getRoutes(request: LifiRoutesRequest.stub())
    _ = try await lifiMock.getQuote(request: LifiQuoteRequest.stub())
    _ = try await lifiMock.getStatus(request: LifiStatusRequest.stub())
    _ = try await lifiMock.getRouteStep(request: LifiStep.stub())

    // then
    XCTAssertEqual(lifiMock.getRoutesCalls, 1)
    XCTAssertEqual(lifiMock.getQuoteCalls, 1)
    XCTAssertEqual(lifiMock.getStatusCalls, 1)
    XCTAssertEqual(lifiMock.getRouteStepCalls, 1)
  }

  func test_lifiMock_reset() async throws {
    // given
    let lifiMock = LifiMock()
    _ = try await lifiMock.getRoutes(request: LifiRoutesRequest.stub())
    XCTAssertEqual(lifiMock.getRoutesCalls, 1)

    // when
    lifiMock.reset()

    // then
    XCTAssertEqual(lifiMock.getRoutesCalls, 0)
    XCTAssertNil(lifiMock.getRoutesRequestParam)
    XCTAssertNil(lifiMock.getRoutesReturnValue)
  }

  func test_lifiMock_errorSimulation() async throws {
    // given
    let lifiMock = LifiMock()
    let testError = NSError(domain: "TestError", code: 500, userInfo: nil)
    lifiMock.getRoutesError = testError

    // when/then
    do {
      _ = try await lifiMock.getRoutes(request: LifiRoutesRequest.stub())
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual((error as NSError).code, 500)
    }
  }
}

// MARK: - Dependency Injection Tests

extension LifiTests {
  func test_lifi_supportsDependencyInjection() {
    // given
    let lifiMock = LifiMock()

    // then
    XCTAssertNotNil(lifiMock)
    XCTAssertTrue(lifiMock is LifiProtocol)
  }

  func test_lifi_injectedMock_isolatesTestBehavior() async throws {
    // given
    let lifiMock1 = LifiMock()
    let lifiMock2 = LifiMock()

    // when
    _ = try await lifiMock1.getRoutes(request: LifiRoutesRequest.stub())
    _ = try await lifiMock1.getRoutes(request: LifiRoutesRequest.stub())
    _ = try await lifiMock2.getRoutes(request: LifiRoutesRequest.stub())

    // then - mocks should be isolated
    XCTAssertEqual(lifiMock1.getRoutesCalls, 2)
    XCTAssertEqual(lifiMock2.getRoutesCalls, 1)
  }
}

// MARK: - Data Model Tests

extension LifiTests {
  func test_lifiToken_hasCorrectProperties() {
    // given
    let token = LifiToken.stub(
      address: "0xtest",
      symbol: "TEST",
      decimals: 18,
      chainId: "1",
      name: "Test Token"
    )

    // then
    XCTAssertEqual(token.address, "0xtest")
    XCTAssertEqual(token.symbol, "TEST")
    XCTAssertEqual(token.decimals, 18)
    XCTAssertEqual(token.chainId, "1")
    XCTAssertEqual(token.name, "Test Token")
  }

  func test_lifiRoute_hasCorrectProperties() {
    // given
    let route = LifiRoute.stub(
      id: "route-test",
      fromChainId: "1",
      toChainId: "137",
      gasCostUSD: "10.00",
      tags: ["FASTEST", "RECOMMENDED"]
    )

    // then
    XCTAssertEqual(route.id, "route-test")
    XCTAssertEqual(route.fromChainId, "1")
    XCTAssertEqual(route.toChainId, "137")
    XCTAssertEqual(route.gasCostUSD, "10.00")
    XCTAssertEqual(route.tags, ["FASTEST", "RECOMMENDED"])
  }

  func test_lifiStep_hasCorrectProperties() {
    // given
    let step = LifiStep.stub(
      id: "step-test",
      type: .cross,
      tool: "relay",
      transactionId: "tx-test"
    )

    // then
    XCTAssertEqual(step.id, "step-test")
    XCTAssertEqual(step.type, .cross)
    XCTAssertEqual(step.tool, "relay")
    XCTAssertEqual(step.transactionId, "tx-test")
  }

  func test_lifiStepType_allCases() {
    // given/then
    XCTAssertEqual(LifiStepType.swap.rawValue, "swap")
    XCTAssertEqual(LifiStepType.cross.rawValue, "cross")
    XCTAssertEqual(LifiStepType.lifi.rawValue, "lifi")
    XCTAssertEqual(LifiStepType.protocol.rawValue, "protocol")
  }

  func test_lifiTransferStatus_allCases() {
    // given/then
    XCTAssertEqual(LifiTransferStatus.notFound.rawValue, "NOT_FOUND")
    XCTAssertEqual(LifiTransferStatus.invalid.rawValue, "INVALID")
    XCTAssertEqual(LifiTransferStatus.pending.rawValue, "PENDING")
    XCTAssertEqual(LifiTransferStatus.done.rawValue, "DONE")
    XCTAssertEqual(LifiTransferStatus.failed.rawValue, "FAILED")
  }

  func test_lifiGasCostType_allCases() {
    // given/then
    XCTAssertEqual(LifiGasCostType.sum.rawValue, "SUM")
    XCTAssertEqual(LifiGasCostType.approve.rawValue, "APPROVE")
    XCTAssertEqual(LifiGasCostType.send.rawValue, "SEND")
  }

  func test_lifiRoutesOrder_allCases() {
    // given/then
    XCTAssertEqual(LifiRoutesOrder.fastest.rawValue, "FASTEST")
    XCTAssertEqual(LifiRoutesOrder.cheapest.rawValue, "CHEAPEST")
  }

  func test_lifiQuoteOrder_allCases() {
    // given/then
    XCTAssertEqual(LifiQuoteOrder.fastest.rawValue, "FASTEST")
    XCTAssertEqual(LifiQuoteOrder.cheapest.rawValue, "CHEAPEST")
  }
}

// MARK: - Error Code Tests

extension LifiTests {
  func test_lifiErrorCode_allCases() {
    // given/then
    XCTAssertEqual(LifiErrorCode.noPossibleRoute.rawValue, "NO_POSSIBLE_ROUTE")
    XCTAssertEqual(LifiErrorCode.insufficientLiquidity.rawValue, "INSUFFICIENT_LIQUIDITY")
    XCTAssertEqual(LifiErrorCode.toolTimeout.rawValue, "TOOL_TIMEOUT")
    XCTAssertEqual(LifiErrorCode.unknownError.rawValue, "UNKNOWN_ERROR")
    XCTAssertEqual(LifiErrorCode.rpcError.rawValue, "RPC_ERROR")
    XCTAssertEqual(LifiErrorCode.amountTooLow.rawValue, "AMOUNT_TOO_LOW")
    XCTAssertEqual(LifiErrorCode.amountTooHigh.rawValue, "AMOUNT_TOO_HIGH")
    XCTAssertEqual(LifiErrorCode.feesHigherThanAmount.rawValue, "FEES_HIGHER_THAN_AMOUNT")
    XCTAssertEqual(LifiErrorCode.differentRecipientNotSupported.rawValue, "DIFFERENT_RECIPIENT_NOT_SUPPORTED")
    XCTAssertEqual(LifiErrorCode.toolSpecificError.rawValue, "TOOL_SPECIFIC_ERROR")
    XCTAssertEqual(LifiErrorCode.cannotGuaranteeMinAmount.rawValue, "CANNOT_GUARANTEE_MIN_AMOUNT")
    XCTAssertEqual(LifiErrorCode.rateLimitExceeded.rawValue, "RATE_LIMIT_EXCEEDED")
  }
}

// MARK: - Status Bridge Tests

extension LifiTests {
  func test_lifiStatusBridge_allCases() {
    // given/then
    XCTAssertEqual(LifiStatusBridge.hop.rawValue, "hop")
    XCTAssertEqual(LifiStatusBridge.cbridge.rawValue, "cbridge")
    XCTAssertEqual(LifiStatusBridge.celercircle.rawValue, "celercircle")
    XCTAssertEqual(LifiStatusBridge.optimism.rawValue, "optimism")
    XCTAssertEqual(LifiStatusBridge.polygon.rawValue, "polygon")
    XCTAssertEqual(LifiStatusBridge.arbitrum.rawValue, "arbitrum")
    XCTAssertEqual(LifiStatusBridge.avalanche.rawValue, "avalanche")
    XCTAssertEqual(LifiStatusBridge.across.rawValue, "across")
    XCTAssertEqual(LifiStatusBridge.gnosis.rawValue, "gnosis")
    XCTAssertEqual(LifiStatusBridge.omni.rawValue, "omni")
    XCTAssertEqual(LifiStatusBridge.relay.rawValue, "relay")
    XCTAssertEqual(LifiStatusBridge.celerim.rawValue, "celerim")
    XCTAssertEqual(LifiStatusBridge.symbiosis.rawValue, "symbiosis")
    XCTAssertEqual(LifiStatusBridge.thorswap.rawValue, "thorswap")
    XCTAssertEqual(LifiStatusBridge.squid.rawValue, "squid")
    XCTAssertEqual(LifiStatusBridge.allbridge.rawValue, "allbridge")
    XCTAssertEqual(LifiStatusBridge.mayan.rawValue, "mayan")
    XCTAssertEqual(LifiStatusBridge.debridge.rawValue, "debridge")
    XCTAssertEqual(LifiStatusBridge.chainflip.rawValue, "chainflip")
  }
}

// MARK: - Edge Cases Tests - Large Amounts

extension LifiTests {
  func test_getRoutes_withVeryLargeAmount() async throws {
    // given
    let mockResponse = LifiRoutesResponse.stub()
    apiMock.getRoutesReturnValue = mockResponse
    let request = LifiRoutesRequest(
      fromChainId: "1",
      fromAmount: "999999999999999999999999999999999999", // Very large amount
      fromTokenAddress: "0x0",
      toChainId: "137",
      toTokenAddress: "0x0"
    )

    // when
    let response = try await lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getRoutesRequestParam?.fromAmount, "999999999999999999999999999999999999")
  }

  func test_getRoutes_withZeroAmount() async throws {
    // given
    let mockResponse = LifiRoutesResponse.stub()
    apiMock.getRoutesReturnValue = mockResponse
    let request = LifiRoutesRequest(
      fromChainId: "1",
      fromAmount: "0",
      fromTokenAddress: "0x0",
      toChainId: "137",
      toTokenAddress: "0x0"
    )

    // when
    let response = try await lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getRoutesRequestParam?.fromAmount, "0")
  }

  func test_getQuote_withVeryLargeAmount() async throws {
    // given
    let mockResponse = LifiQuoteResponse.stub()
    apiMock.getQuoteReturnValue = mockResponse
    let request = LifiQuoteRequest(
      fromChain: "1",
      toChain: "137",
      fromToken: "ETH",
      toToken: "MATIC",
      fromAddress: "0x123",
      fromAmount: "999999999999999999999999999999999999"
    )

    // when
    let response = try await lifi.getQuote(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getQuoteRequestParam?.fromAmount, "999999999999999999999999999999999999")
  }
}

// MARK: - Edge Cases Tests - Slippage Boundaries

extension LifiTests {
  func test_getRoutes_withZeroSlippage() async throws {
    // given
    let mockResponse = LifiRoutesResponse.stub()
    apiMock.getRoutesReturnValue = mockResponse
    let options = LifiRoutesRequestOptions(slippage: 0.0)
    let request = LifiRoutesRequest.stub(options: options)

    // when
    let response = try await lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getRoutesRequestParam?.options?.slippage, 0.0)
  }

  func test_getRoutes_withMaxSlippage() async throws {
    // given
    let mockResponse = LifiRoutesResponse.stub()
    apiMock.getRoutesReturnValue = mockResponse
    let options = LifiRoutesRequestOptions(slippage: 1.0)
    let request = LifiRoutesRequest.stub(options: options)

    // when
    let response = try await lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getRoutesRequestParam?.options?.slippage, 1.0)
  }

  func test_getRoutes_withSmallSlippage() async throws {
    // given
    let mockResponse = LifiRoutesResponse.stub()
    apiMock.getRoutesReturnValue = mockResponse
    let options = LifiRoutesRequestOptions(slippage: 0.001) // 0.1%
    let request = LifiRoutesRequest.stub(options: options)

    // when
    let response = try await lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getRoutesRequestParam?.options?.slippage, 0.001)
  }

  func test_getQuote_withZeroSlippage() async throws {
    // given
    let mockResponse = LifiQuoteResponse.stub()
    apiMock.getQuoteReturnValue = mockResponse
    let request = LifiQuoteRequest.stub(slippage: 0.0)

    // when
    let response = try await lifi.getQuote(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getQuoteRequestParam?.slippage, 0.0)
  }

  func test_getQuote_withMaxSlippage() async throws {
    // given
    let mockResponse = LifiQuoteResponse.stub()
    apiMock.getQuoteReturnValue = mockResponse
    let request = LifiQuoteRequest.stub(slippage: 1.0)

    // when
    let response = try await lifi.getQuote(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getQuoteRequestParam?.slippage, 1.0)
  }
}

// MARK: - Edge Cases Tests - Fee Boundaries

extension LifiTests {
  func test_getRoutes_withZeroFee() async throws {
    // given
    let mockResponse = LifiRoutesResponse.stub()
    apiMock.getRoutesReturnValue = mockResponse
    let options = LifiRoutesRequestOptions(fee: 0.0)
    let request = LifiRoutesRequest.stub(options: options)

    // when
    let response = try await lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getRoutesRequestParam?.options?.fee, 0.0)
  }

  func test_getRoutes_withSmallFee() async throws {
    // given
    let mockResponse = LifiRoutesResponse.stub()
    apiMock.getRoutesReturnValue = mockResponse
    let options = LifiRoutesRequestOptions(fee: 0.001)
    let request = LifiRoutesRequest.stub(options: options)

    // when
    let response = try await lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getRoutesRequestParam?.options?.fee, 0.001)
  }

  func test_getQuote_withZeroFee() async throws {
    // given
    let mockResponse = LifiQuoteResponse.stub()
    apiMock.getQuoteReturnValue = mockResponse
    let request = LifiQuoteRequest.stub(fee: 0.0)

    // when
    let response = try await lifi.getQuote(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getQuoteRequestParam?.fee, 0.0)
  }

  func test_getQuote_withMaxFee() async throws {
    // given
    let mockResponse = LifiQuoteResponse.stub()
    apiMock.getQuoteReturnValue = mockResponse
    let request = LifiQuoteRequest.stub(fee: 0.99)

    // when
    let response = try await lifi.getQuote(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getQuoteRequestParam?.fee, 0.99)
  }
}

// MARK: - Edge Cases Tests - Empty Strings

extension LifiTests {
  func test_getRoutes_withEmptyChainId() async throws {
    // given
    let mockResponse = LifiRoutesResponse.stub()
    apiMock.getRoutesReturnValue = mockResponse
    let request = LifiRoutesRequest(
      fromChainId: "",
      fromAmount: "1000000",
      fromTokenAddress: "0x0",
      toChainId: "",
      toTokenAddress: "0x0"
    )

    // when
    let response = try await lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getRoutesRequestParam?.fromChainId, "")
    XCTAssertEqual(apiMock.getRoutesRequestParam?.toChainId, "")
  }

  func test_getRoutes_withEmptyTokenAddress() async throws {
    // given
    let mockResponse = LifiRoutesResponse.stub()
    apiMock.getRoutesReturnValue = mockResponse
    let request = LifiRoutesRequest(
      fromChainId: "1",
      fromAmount: "1000000",
      fromTokenAddress: "",
      toChainId: "137",
      toTokenAddress: ""
    )

    // when
    let response = try await lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getRoutesRequestParam?.fromTokenAddress, "")
    XCTAssertEqual(apiMock.getRoutesRequestParam?.toTokenAddress, "")
  }

  func test_getStatus_withEmptyTxHash() async throws {
    // given
    let mockResponse = LifiStatusResponse.stub()
    apiMock.getStatusReturnValue = mockResponse
    let request = LifiStatusRequest(txHash: "")

    // when
    let response = try await lifi.getStatus(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getStatusRequestParam?.txHash, "")
  }
}

// MARK: - Edge Cases Tests - Empty Arrays

extension LifiTests {
  func test_getRoutes_withEmptyBridgeArrays() async throws {
    // given
    let mockResponse = LifiRoutesResponse.stub()
    apiMock.getRoutesReturnValue = mockResponse
    let bridges = LifiToolsConfiguration(allow: [], deny: [], prefer: [])
    let options = LifiRoutesRequestOptions(bridges: bridges)
    let request = LifiRoutesRequest.stub(options: options)

    // when
    let response = try await lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getRoutesRequestParam?.options?.bridges?.allow, [])
    XCTAssertEqual(apiMock.getRoutesRequestParam?.options?.bridges?.deny, [])
    XCTAssertEqual(apiMock.getRoutesRequestParam?.options?.bridges?.prefer, [])
  }

  func test_getRoutes_withEmptyExchangeArrays() async throws {
    // given
    let mockResponse = LifiRoutesResponse.stub()
    apiMock.getRoutesReturnValue = mockResponse
    let exchanges = LifiToolsConfiguration(allow: [], deny: [], prefer: [])
    let options = LifiRoutesRequestOptions(exchanges: exchanges)
    let request = LifiRoutesRequest.stub(options: options)

    // when
    let response = try await lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getRoutesRequestParam?.options?.exchanges?.allow, [])
  }

  func test_getQuote_withEmptyBridgeArrays() async throws {
    // given
    let mockResponse = LifiQuoteResponse.stub()
    apiMock.getQuoteReturnValue = mockResponse
    let request = LifiQuoteRequest.stub(
      allowBridges: [],
      denyBridges: [],
      preferBridges: []
    )

    // when
    let response = try await lifi.getQuote(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getQuoteRequestParam?.allowBridges, [])
    XCTAssertEqual(apiMock.getQuoteRequestParam?.denyBridges, [])
    XCTAssertEqual(apiMock.getQuoteRequestParam?.preferBridges, [])
  }
}

// MARK: - Data Model Property Tests - LifiFeeSplit

extension LifiTests {
  func test_lifiFeeSplit_properties() {
    // given
    let feeSplit = LifiFeeSplit(integratorFee: "0.002", lifiFee: "0.001")

    // then
    XCTAssertEqual(feeSplit.integratorFee, "0.002")
    XCTAssertEqual(feeSplit.lifiFee, "0.001")
  }

  func test_lifiFeeSplit_withNilValues() {
    // given
    let feeSplit = LifiFeeSplit(integratorFee: nil, lifiFee: nil)

    // then
    XCTAssertNil(feeSplit.integratorFee)
    XCTAssertNil(feeSplit.lifiFee)
  }
}

// MARK: - Data Model Property Tests - LifiEstimateData

extension LifiTests {
  func test_lifiEstimateData_properties() {
    // given
    let bid = LifiBid(
      user: "0xUser",
      router: "0xRouter",
      initiator: "0xInitiator",
      sendingChainId: "1",
      sendingAssetId: "0xETH",
      amount: "1000000000000000000",
      receivingChainId: "137",
      receivingAssetId: "0xMATIC",
      amountReceived: "950000000000000000",
      receivingAddress: "0xReceiver",
      transactionId: "tx-123",
      expiry: 1700000000,
      callDataHash: "0xHash",
      callTo: "0xContract",
      encryptedCallData: "encrypted-data",
      sendingChainTxManagerAddress: "0xSendingManager",
      receivingChainTxManagerAddress: "0xReceivingManager",
      bidExpiry: 1700000100
    )
    let estimateData = LifiEstimateData(
      bid: bid,
      bidSignature: "0xSignature",
      gasFeeInReceivingToken: "1000000",
      totalFee: "5000000",
      metaTxRelayerFee: "500000",
      routerFee: "100000"
    )

    // then
    XCTAssertEqual(estimateData.bid?.user, "0xUser")
    XCTAssertEqual(estimateData.bid?.router, "0xRouter")
    XCTAssertEqual(estimateData.bid?.sendingChainId, "1")
    XCTAssertEqual(estimateData.bid?.receivingChainId, "137")
    XCTAssertEqual(estimateData.bidSignature, "0xSignature")
    XCTAssertEqual(estimateData.gasFeeInReceivingToken, "1000000")
    XCTAssertEqual(estimateData.totalFee, "5000000")
    XCTAssertEqual(estimateData.metaTxRelayerFee, "500000")
    XCTAssertEqual(estimateData.routerFee, "100000")
  }
}

// MARK: - Data Model Property Tests - LifiBid

extension LifiTests {
  func test_lifiBid_allProperties() {
    // given
    let bid = LifiBid(
      user: "0xUser",
      router: "0xRouter",
      initiator: "0xInitiator",
      sendingChainId: "1",
      sendingAssetId: "0xETH",
      amount: "1000000000000000000",
      receivingChainId: "137",
      receivingAssetId: "0xMATIC",
      amountReceived: "950000000000000000",
      receivingAddress: "0xReceiver",
      transactionId: "tx-123",
      expiry: 1700000000,
      callDataHash: "0xHash",
      callTo: "0xContract",
      encryptedCallData: "encrypted-data",
      sendingChainTxManagerAddress: "0xSendingManager",
      receivingChainTxManagerAddress: "0xReceivingManager",
      bidExpiry: 1700000100
    )

    // then
    XCTAssertEqual(bid.user, "0xUser")
    XCTAssertEqual(bid.router, "0xRouter")
    XCTAssertEqual(bid.initiator, "0xInitiator")
    XCTAssertEqual(bid.sendingChainId, "1")
    XCTAssertEqual(bid.sendingAssetId, "0xETH")
    XCTAssertEqual(bid.amount, "1000000000000000000")
    XCTAssertEqual(bid.receivingChainId, "137")
    XCTAssertEqual(bid.receivingAssetId, "0xMATIC")
    XCTAssertEqual(bid.amountReceived, "950000000000000000")
    XCTAssertEqual(bid.receivingAddress, "0xReceiver")
    XCTAssertEqual(bid.transactionId, "tx-123")
    XCTAssertEqual(bid.expiry, 1700000000)
    XCTAssertEqual(bid.callDataHash, "0xHash")
    XCTAssertEqual(bid.callTo, "0xContract")
    XCTAssertEqual(bid.encryptedCallData, "encrypted-data")
    XCTAssertEqual(bid.sendingChainTxManagerAddress, "0xSendingManager")
    XCTAssertEqual(bid.receivingChainTxManagerAddress, "0xReceivingManager")
    XCTAssertEqual(bid.bidExpiry, 1700000100)
  }
}

// MARK: - Data Model Property Tests - LifiSubpathError

extension LifiTests {
  func test_lifiSubpathError_properties() {
    // given
    let action = LifiAction.stub()
    let subpathError = LifiSubpathError(
      errorType: .noQuote,
      code: .insufficientLiquidity,
      action: action,
      tool: "uniswap",
      message: "Not enough liquidity"
    )

    // then
    XCTAssertEqual(subpathError.errorType, .noQuote)
    XCTAssertEqual(subpathError.code, .insufficientLiquidity)
    XCTAssertNotNil(subpathError.action)
    XCTAssertEqual(subpathError.tool, "uniswap")
    XCTAssertEqual(subpathError.message, "Not enough liquidity")
  }

  func test_lifiSubpathError_allErrorCodes() {
    let errorCodes: [LifiErrorCode] = [
      .noPossibleRoute, .insufficientLiquidity, .toolTimeout,
      .unknownError, .rpcError, .amountTooLow, .amountTooHigh,
      .feesHigherThanAmount, .differentRecipientNotSupported,
      .toolSpecificError, .cannotGuaranteeMinAmount, .rateLimitExceeded
    ]

    for code in errorCodes {
      let subpathError = LifiSubpathError(
        errorType: .noQuote,
        code: code,
        action: nil,
        tool: nil,
        message: nil
      )
      XCTAssertEqual(subpathError.code, code)
    }
  }
}

// MARK: - Data Model Property Tests - LifiIncludedSwapStep

extension LifiTests {
  func test_lifiIncludedSwapStep_properties() {
    // given
    let fromToken = LifiToken.stub(symbol: "ETH")
    let toToken = LifiToken.stub(symbol: "USDC")
    let toolDetails = LifiToolDetails.stub(key: "uniswap", name: "Uniswap")
    let includedStep = LifiIncludedSwapStep(
      tool: "uniswap",
      toolDetails: toolDetails,
      fromAmount: "1000000000000000000",
      fromToken: fromToken,
      toAmount: "3000000000",
      toToken: toToken,
      bridgedAmount: nil
    )

    // then
    XCTAssertEqual(includedStep.tool, "uniswap")
    XCTAssertEqual(includedStep.toolDetails?.key, "uniswap")
    XCTAssertEqual(includedStep.toolDetails?.name, "Uniswap")
    XCTAssertEqual(includedStep.fromAmount, "1000000000000000000")
    XCTAssertEqual(includedStep.fromToken?.symbol, "ETH")
    XCTAssertEqual(includedStep.toAmount, "3000000000")
    XCTAssertEqual(includedStep.toToken?.symbol, "USDC")
    XCTAssertNil(includedStep.bridgedAmount)
  }

  func test_lifiIncludedSwapStep_withBridgedAmount() {
    // given
    let includedStep = LifiIncludedSwapStep(
      tool: "relay",
      toolDetails: nil,
      fromAmount: "1000000000000000000",
      fromToken: nil,
      toAmount: "950000000000000000",
      toToken: nil,
      bridgedAmount: "950000000000000000"
    )

    // then
    XCTAssertEqual(includedStep.bridgedAmount, "950000000000000000")
  }
}

// MARK: - Data Model Property Tests - LifiReceivingInfo

extension LifiTests {
  func test_lifiReceivingInfo_allProperties() {
    // given
    let token = LifiToken.stub(symbol: "MATIC")
    let gasToken = LifiToken.stub(symbol: "MATIC")
    let includedStep = LifiIncludedSwapStep(
      tool: "sushiswap",
      toolDetails: nil,
      fromAmount: nil,
      fromToken: nil,
      toAmount: nil,
      toToken: nil,
      bridgedAmount: nil
    )
    let receivingInfo = LifiReceivingInfo(
      chainId: "137",
      txHash: "0xdef789",
      txLink: "https://polygonscan.com/tx/0xdef789",
      token: token,
      amount: "950000000000000000",
      gasToken: gasToken,
      gasAmount: "21000000000000",
      gasAmountUSD: "0.01",
      gasPrice: "50000000000",
      gasUsed: "21000",
      timestamp: 1700000060,
      value: "950000000000000000",
      includedSteps: [includedStep]
    )

    // then
    XCTAssertEqual(receivingInfo.chainId, "137")
    XCTAssertEqual(receivingInfo.txHash, "0xdef789")
    XCTAssertEqual(receivingInfo.txLink, "https://polygonscan.com/tx/0xdef789")
    XCTAssertEqual(receivingInfo.token?.symbol, "MATIC")
    XCTAssertEqual(receivingInfo.amount, "950000000000000000")
    XCTAssertEqual(receivingInfo.gasToken?.symbol, "MATIC")
    XCTAssertEqual(receivingInfo.gasAmount, "21000000000000")
    XCTAssertEqual(receivingInfo.gasAmountUSD, "0.01")
    XCTAssertEqual(receivingInfo.gasPrice, "50000000000")
    XCTAssertEqual(receivingInfo.gasUsed, "21000")
    XCTAssertEqual(receivingInfo.timestamp, 1700000060)
    XCTAssertEqual(receivingInfo.value, "950000000000000000")
    XCTAssertEqual(receivingInfo.includedSteps?.count, 1)
    XCTAssertEqual(receivingInfo.includedSteps?[0].tool, "sushiswap")
  }
}

// MARK: - Data Model Property Tests - LifiTransactionInfo

extension LifiTests {
  func test_lifiTransactionInfo_allProperties() {
    // given
    let token = LifiToken.stub(symbol: "ETH")
    let gasToken = LifiToken.stub(symbol: "ETH")
    let txInfo = LifiTransactionInfo(
      txHash: "0xabc123",
      txLink: "https://etherscan.io/tx/0xabc123",
      amount: "1000000000000000000",
      amountUSD: "3000.00",
      token: token,
      chainId: "1",
      gasToken: gasToken,
      gasAmount: "21000000000000",
      gasAmountUSD: "5.00",
      gasPrice: "50000000000",
      gasUsed: "21000",
      timestamp: 1700000000,
      value: "1000000000000000000",
      includedSteps: nil
    )

    // then
    XCTAssertEqual(txInfo.txHash, "0xabc123")
    XCTAssertEqual(txInfo.txLink, "https://etherscan.io/tx/0xabc123")
    XCTAssertEqual(txInfo.amount, "1000000000000000000")
    XCTAssertEqual(txInfo.amountUSD, "3000.00")
    XCTAssertEqual(txInfo.token.symbol, "ETH")
    XCTAssertEqual(txInfo.chainId, "1")
    XCTAssertEqual(txInfo.gasToken?.symbol, "ETH")
    XCTAssertEqual(txInfo.gasAmount, "21000000000000")
    XCTAssertEqual(txInfo.gasAmountUSD, "5.00")
    XCTAssertEqual(txInfo.gasPrice, "50000000000")
    XCTAssertEqual(txInfo.gasUsed, "21000")
    XCTAssertEqual(txInfo.timestamp, 1700000000)
    XCTAssertEqual(txInfo.value, "1000000000000000000")
    XCTAssertNil(txInfo.includedSteps)
  }
}

// MARK: - Data Model Property Tests - LifiMetadata

extension LifiTests {
  func test_lifiMetadata_properties() {
    // given
    let metadata = LifiMetadata(integrator: "portal")

    // then
    XCTAssertEqual(metadata.integrator, "portal")
  }

  func test_lifiMetadata_withNilIntegrator() {
    // given
    let metadata = LifiMetadata(integrator: nil)

    // then
    XCTAssertNil(metadata.integrator)
  }
}

// MARK: - API Throws Error Tests

extension LifiTests {
  func test_getRoutes_throwsError() async throws {
    // given
    let expectedError = NSError(domain: "TestError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server error"])
    apiMock.getRoutesError = expectedError

    // when/then
    do {
      _ = try await lifi.getRoutes(request: LifiRoutesRequest.stub())
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual((error as NSError).code, 500)
    }
  }

  func test_getQuote_throwsError() async throws {
    // given
    let expectedError = NSError(domain: "TestError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Bad request"])
    apiMock.getQuoteError = expectedError

    // when/then
    do {
      _ = try await lifi.getQuote(request: LifiQuoteRequest.stub())
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual((error as NSError).code, 400)
    }
  }

  func test_getStatus_throwsError() async throws {
    // given
    let expectedError = NSError(domain: "TestError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Not found"])
    apiMock.getStatusError = expectedError

    // when/then
    do {
      _ = try await lifi.getStatus(request: LifiStatusRequest.stub())
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual((error as NSError).code, 404)
    }
  }

  func test_getRouteStep_throwsError() async throws {
    // given
    let expectedError = NSError(domain: "TestError", code: 503, userInfo: [NSLocalizedDescriptionKey: "Service unavailable"])
    apiMock.getRouteStepError = expectedError

    // when/then
    do {
      _ = try await lifi.getRouteStep(request: LifiStep.stub())
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual((error as NSError).code, 503)
    }
  }

  func test_getRoutes_throwsURLError() async throws {
    // given
    let expectedError = URLError(.notConnectedToInternet)
    apiMock.getRoutesError = expectedError

    // when/then
    do {
      _ = try await lifi.getRoutes(request: LifiRoutesRequest.stub())
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
      _ = try await lifi.getQuote(request: LifiQuoteRequest.stub())
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertTrue(error is DecodingError)
    }
  }
}

// MARK: - Complex Scenario Tests

extension LifiTests {
  func test_getRoutes_withComplexToolsConfiguration() async throws {
    // given
    let mockResponse = LifiRoutesResponse.stub()
    apiMock.getRoutesReturnValue = mockResponse

    let bridges = LifiToolsConfiguration(
      allow: ["hop", "across", "relay", "symbiosis", "cbridge"],
      deny: ["allbridge", "mayan"],
      prefer: ["relay", "hop"]
    )
    let exchanges = LifiToolsConfiguration(
      allow: ["uniswap", "sushiswap", "1inch", "paraswap"],
      deny: ["dodo"],
      prefer: ["1inch", "uniswap"]
    )
    let timing = LifiTimingOptions(
      swapStepTimingStrategies: [
        LifiTimingStrategy(strategy: .minWaitTime, minWaitTimeMs: 1000, startingExpectedResults: 10, reduceEveryMs: 100),
        LifiTimingStrategy(strategy: .minWaitTime, minWaitTimeMs: 2000, startingExpectedResults: 5, reduceEveryMs: 200)
      ],
      routeTimingStrategies: [
        LifiTimingStrategy(strategy: .minWaitTime, minWaitTimeMs: 3000)
      ]
    )
    let options = LifiRoutesRequestOptions(
      insurance: false,
      integrator: "portal",
      slippage: 0.005,
      bridges: bridges,
      exchanges: exchanges,
      order: .cheapest,
      allowSwitchChain: true,
      allowDestinationCall: true,
      referrer: "0xReferrer",
      fee: 0.003,
      maxPriceImpact: 0.10,
      timing: timing
    )
    let request = LifiRoutesRequest(
      fromChainId: "1",
      fromAmount: "1000000000000000000",
      fromTokenAddress: "0xETH",
      toChainId: "42161", // Arbitrum
      toTokenAddress: "0xARB",
      options: options,
      fromAddress: "0xSender",
      toAddress: "0xReceiver",
      fromAmountForGas: "50000000000000000"
    )

    // when
    let response = try await lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(apiMock.getRoutesCalls, 1)
    XCTAssertEqual(apiMock.getRoutesRequestParam?.options?.bridges?.allow?.count, 5)
    XCTAssertEqual(apiMock.getRoutesRequestParam?.options?.exchanges?.prefer?.count, 2)
    XCTAssertEqual(apiMock.getRoutesRequestParam?.options?.timing?.swapStepTimingStrategies?.count, 2)
  }

  func test_getRoutes_responseWithComplexRouteStructure() async throws {
    // given
    let internalSteps = [
      LifiInternalStep.stub(id: "swap-1", type: .swap, tool: "uniswap"),
      LifiInternalStep.stub(id: "bridge-1", type: .cross, tool: "relay"),
      LifiInternalStep.stub(id: "swap-2", type: .swap, tool: "sushiswap")
    ]
    let steps = [
      LifiStep.stub(id: "step-1", type: .lifi, tool: "lifi", includedSteps: internalSteps)
    ]
    let routes = [
      LifiRoute.stub(id: "route-1", steps: steps, tags: ["CHEAPEST", "RECOMMENDED"]),
      LifiRoute.stub(id: "route-2", tags: ["FASTEST"])
    ]
    let unavailableRoutes = LifiUnavailableRoutes(
      filteredOut: [
        LifiFilteredRoute(overallPath: "1:ETH-hop-42161:ETH", reason: "Low liquidity")
      ],
      failed: [
        LifiFailedRoute(overallPath: "1:ETH-across-42161:ETH", subpaths: nil)
      ]
    )
    let rawResponse = LifiRoutesRawResponse(routes: routes, unavailableRoutes: unavailableRoutes)
    let mockResponse = LifiRoutesResponse(data: LifiRoutesData(rawResponse: rawResponse), error: nil)
    apiMock.getRoutesReturnValue = mockResponse

    // when
    let response = try await lifi.getRoutes(request: LifiRoutesRequest.stub())

    // then
    XCTAssertEqual(response.data?.rawResponse.routes.count, 2)
    XCTAssertEqual(response.data?.rawResponse.routes[0].steps[0].includedSteps?.count, 3)
    XCTAssertEqual(response.data?.rawResponse.routes[0].tags?.count, 2)
    XCTAssertNotNil(response.data?.rawResponse.unavailableRoutes)
    XCTAssertEqual(response.data?.rawResponse.unavailableRoutes?.filteredOut?.count, 1)
    XCTAssertEqual(response.data?.rawResponse.unavailableRoutes?.failed?.count, 1)
  }

  func test_crossChainSwapCompleteFlow() async throws {
    // given - Step 1: Get routes
    let routes = [
      LifiRoute.stub(id: "best-route", tags: ["RECOMMENDED"]),
      LifiRoute.stub(id: "cheap-route", tags: ["CHEAPEST"]),
      LifiRoute.stub(id: "fast-route", tags: ["FASTEST"])
    ]
    let routesResponse = LifiRoutesResponse.stub(
      data: LifiRoutesData(rawResponse: LifiRoutesRawResponse(routes: routes, unavailableRoutes: nil))
    )
    apiMock.getRoutesReturnValue = routesResponse

    // when
    let routesResult = try await lifi.getRoutes(request: LifiRoutesRequest.stub())

    // then
    XCTAssertEqual(routesResult.data?.rawResponse.routes.count, 3)

    // given - Step 2: Get quote for selected route
    let quoteStep = LifiStep.stub(
      includedSteps: [
        LifiInternalStep.stub(id: "swap-1", type: .swap),
        LifiInternalStep.stub(id: "bridge-1", type: .cross)
      ]
    )
    let quoteResponse = LifiQuoteResponse(data: LifiQuoteData(rawResponse: quoteStep), error: nil)
    apiMock.getQuoteReturnValue = quoteResponse

    // when
    let quoteResult = try await lifi.getQuote(request: LifiQuoteRequest.stub())

    // then
    XCTAssertEqual(quoteResult.data?.rawResponse.includedSteps?.count, 2)

    // given - Step 3: Get route step transaction
    let stepTransactionResponse = LifiStepTransactionResponse.stub()
    apiMock.getRouteStepReturnValue = stepTransactionResponse

    // when
    let stepResult = try await lifi.getRouteStep(request: LifiStep.stub())

    // then
    XCTAssertNotNil(stepResult.data)

    // given - Step 4: Check status - pending
    let pendingStatus = LifiStatusRawResponse.stub(
      status: .pending,
      substatus: .waitSourceConfirmations,
      substatusMessage: "Waiting for 6 confirmations"
    )
    apiMock.getStatusReturnValue = LifiStatusResponse(data: LifiStatusData(rawResponse: pendingStatus), error: nil)

    // when
    let pendingResult = try await lifi.getStatus(request: LifiStatusRequest.stub())

    // then
    XCTAssertEqual(pendingResult.data?.rawResponse.status, .pending)
    XCTAssertEqual(pendingResult.data?.rawResponse.substatus, .waitSourceConfirmations)

    // given - Step 5: Check status - waiting destination
    let waitingStatus = LifiStatusRawResponse.stub(
      status: .pending,
      substatus: .waitDestinationTransaction,
      substatusMessage: "Bridging in progress"
    )
    apiMock.getStatusReturnValue = LifiStatusResponse(data: LifiStatusData(rawResponse: waitingStatus), error: nil)

    // when
    let waitingResult = try await lifi.getStatus(request: LifiStatusRequest.stub())

    // then
    XCTAssertEqual(waitingResult.data?.rawResponse.status, .pending)
    XCTAssertEqual(waitingResult.data?.rawResponse.substatus, .waitDestinationTransaction)

    // given - Step 6: Check status - completed
    let completedStatus = LifiStatusRawResponse.stub(
      status: .done,
      substatus: .completed,
      substatusMessage: "Transfer completed successfully"
    )
    apiMock.getStatusReturnValue = LifiStatusResponse(data: LifiStatusData(rawResponse: completedStatus), error: nil)

    // when
    let completedResult = try await lifi.getStatus(request: LifiStatusRequest.stub())

    // then
    XCTAssertEqual(completedResult.data?.rawResponse.status, .done)
    XCTAssertEqual(completedResult.data?.rawResponse.substatus, .completed)

    // Verify all calls
    XCTAssertEqual(apiMock.getRoutesCalls, 1)
    XCTAssertEqual(apiMock.getQuoteCalls, 1)
    XCTAssertEqual(apiMock.getRouteStepCalls, 1)
    XCTAssertEqual(apiMock.getStatusCalls, 3)
  }
}

// MARK: - LifiTimingStrategyType Tests

extension LifiTests {
  func test_lifiTimingStrategyType_rawValue() {
    // given/then
    XCTAssertEqual(LifiTimingStrategyType.minWaitTime.rawValue, "minWaitTime")
  }
}

// MARK: - LifiErrorType Tests

extension LifiTests {
  func test_lifiErrorType_rawValue() {
    // given/then
    XCTAssertEqual(LifiErrorType.noQuote.rawValue, "NO_QUOTE")
  }
}

