//
//  LifiCodableTests.swift
//  PortalSwift
//
//  Created by Portal Labs
//

import AnyCodable
import Foundation
@testable import PortalSwift
import XCTest

final class LifiCodableTests: XCTestCase {
  var encoder: JSONEncoder!
  var decoder: JSONDecoder!

  override func setUpWithError() throws {
    encoder = JSONEncoder()
    decoder = JSONDecoder()
  }

  override func tearDownWithError() throws {
    encoder = nil
    decoder = nil
  }
}

// MARK: - LifiToken Codable Tests

extension LifiCodableTests {
  func test_lifiToken_encodesAndDecodesCorrectly() throws {
    // given
    let token = LifiToken.stub()

    // when
    let data = try encoder.encode(token)
    let decoded = try decoder.decode(LifiToken.self, from: data)

    // then
    XCTAssertEqual(decoded.address, token.address)
    XCTAssertEqual(decoded.symbol, token.symbol)
    XCTAssertEqual(decoded.decimals, token.decimals)
    XCTAssertEqual(decoded.chainId, token.chainId)
    XCTAssertEqual(decoded.name, token.name)
    XCTAssertEqual(decoded.coinKey, token.coinKey)
    XCTAssertEqual(decoded.logoURI, token.logoURI)
    XCTAssertEqual(decoded.priceUSD, token.priceUSD)
  }

  func test_lifiToken_decodesWithNilOptionalFields() throws {
    // given
    let json = """
    {
      "address": "0xtest",
      "symbol": "TEST",
      "decimals": 18,
      "chainId": "1",
      "name": "Test Token"
    }
    """
    let data = json.data(using: .utf8)!

    // when
    let decoded = try decoder.decode(LifiToken.self, from: data)

    // then
    XCTAssertNil(decoded.coinKey)
    XCTAssertNil(decoded.logoURI)
    XCTAssertNil(decoded.priceUSD)
  }

  func test_lifiToken_withUnicodeCharacters() throws {
    // given
    let token = LifiToken(
      address: "0x123",
      symbol: "日本語",
      decimals: 18,
      chainId: "1",
      name: "Unicode Token 🚀",
      coinKey: nil,
      logoURI: nil,
      priceUSD: nil
    )

    // when
    let data = try encoder.encode(token)
    let decoded = try decoder.decode(LifiToken.self, from: data)

    // then
    XCTAssertEqual(decoded.symbol, "日本語")
    XCTAssertEqual(decoded.name, "Unicode Token 🚀")
  }
}

// MARK: - LifiRoutesRequest Codable Tests

extension LifiCodableTests {
  func test_lifiRoutesRequest_encodesAndDecodesCorrectly() throws {
    // given
    let request = LifiRoutesRequest.stub()

    // when
    let data = try encoder.encode(request)
    let decoded = try decoder.decode(LifiRoutesRequest.self, from: data)

    // then
    XCTAssertEqual(decoded.fromChainId, request.fromChainId)
    XCTAssertEqual(decoded.fromAmount, request.fromAmount)
    XCTAssertEqual(decoded.fromTokenAddress, request.fromTokenAddress)
    XCTAssertEqual(decoded.toChainId, request.toChainId)
    XCTAssertEqual(decoded.toTokenAddress, request.toTokenAddress)
  }

  func test_lifiRoutesRequest_withAllOptions() throws {
    // given
    let bridges = LifiToolsConfiguration(allow: ["hop", "across"], deny: ["cbridge"], prefer: ["relay"])
    let exchanges = LifiToolsConfiguration(allow: ["uniswap"], deny: nil, prefer: ["1inch"])
    let timing = LifiTimingOptions(
      swapStepTimingStrategies: [LifiTimingStrategy(strategy: .minWaitTime, minWaitTimeMs: 1000)],
      routeTimingStrategies: nil
    )
    let options = LifiRoutesRequestOptions(
      insurance: true,
      integrator: "portal",
      slippage: 0.01,
      bridges: bridges,
      exchanges: exchanges,
      order: .cheapest,
      allowSwitchChain: true,
      allowDestinationCall: false,
      referrer: "0xRef",
      fee: 0.003,
      maxPriceImpact: 0.15,
      timing: timing
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
    let data = try encoder.encode(request)
    let decoded = try decoder.decode(LifiRoutesRequest.self, from: data)

    // then
    XCTAssertEqual(decoded.options?.insurance, true)
    XCTAssertEqual(decoded.options?.integrator, "portal")
    XCTAssertEqual(decoded.options?.slippage, 0.01)
    XCTAssertEqual(decoded.options?.bridges?.allow, ["hop", "across"])
    XCTAssertEqual(decoded.options?.bridges?.deny, ["cbridge"])
    XCTAssertEqual(decoded.options?.exchanges?.prefer, ["1inch"])
    XCTAssertEqual(decoded.options?.order, .cheapest)
    XCTAssertEqual(decoded.options?.allowSwitchChain, true)
    XCTAssertEqual(decoded.options?.allowDestinationCall, false)
    XCTAssertEqual(decoded.options?.referrer, "0xRef")
    XCTAssertEqual(decoded.options?.fee, 0.003)
    XCTAssertEqual(decoded.options?.maxPriceImpact, 0.15)
    XCTAssertEqual(decoded.options?.timing?.swapStepTimingStrategies?.count, 1)
  }
}

// MARK: - LifiQuoteRequest Codable Tests

extension LifiCodableTests {
  func test_lifiQuoteRequest_encodesAndDecodesCorrectly() throws {
    // given
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
      integrator: "portal",
      fee: 0.003,
      referrer: "0xRef",
      allowBridges: ["hop", "across"],
      allowExchanges: ["uniswap"],
      denyBridges: ["cbridge"],
      denyExchanges: nil,
      preferBridges: ["relay"],
      preferExchanges: ["1inch"],
      allowDestinationCall: true,
      fromAmountForGas: "50000000000000000",
      maxPriceImpact: 0.15,
      swapStepTimingStrategies: ["minWaitTime-1000"],
      routeTimingStrategies: ["minWaitTime-2000"],
      skipSimulation: true
    )

    // when
    let data = try encoder.encode(request)
    let decoded = try decoder.decode(LifiQuoteRequest.self, from: data)

    // then
    XCTAssertEqual(decoded.fromChain, "1")
    XCTAssertEqual(decoded.toChain, "137")
    XCTAssertEqual(decoded.fromToken, "ETH")
    XCTAssertEqual(decoded.toToken, "MATIC")
    XCTAssertEqual(decoded.fromAddress, "0xSender")
    XCTAssertEqual(decoded.fromAmount, "1000000000000000000")
    XCTAssertEqual(decoded.toAddress, "0xReceiver")
    XCTAssertEqual(decoded.order, .fastest)
    XCTAssertEqual(decoded.slippage, 0.005)
    XCTAssertEqual(decoded.integrator, "portal")
    XCTAssertEqual(decoded.fee, 0.003)
    XCTAssertEqual(decoded.referrer, "0xRef")
    XCTAssertEqual(decoded.allowBridges, ["hop", "across"])
    XCTAssertEqual(decoded.allowExchanges, ["uniswap"])
    XCTAssertEqual(decoded.denyBridges, ["cbridge"])
    XCTAssertNil(decoded.denyExchanges)
    XCTAssertEqual(decoded.preferBridges, ["relay"])
    XCTAssertEqual(decoded.preferExchanges, ["1inch"])
    XCTAssertEqual(decoded.allowDestinationCall, true)
    XCTAssertEqual(decoded.fromAmountForGas, "50000000000000000")
    XCTAssertEqual(decoded.maxPriceImpact, 0.15)
    XCTAssertEqual(decoded.swapStepTimingStrategies, ["minWaitTime-1000"])
    XCTAssertEqual(decoded.routeTimingStrategies, ["minWaitTime-2000"])
    XCTAssertEqual(decoded.skipSimulation, true)
  }
}

// MARK: - LifiStatusRequest Codable Tests

extension LifiCodableTests {
  func test_lifiStatusRequest_encodesAndDecodesCorrectly() throws {
    // given
    let request = LifiStatusRequest(
      txHash: "0xabc123def456",
      bridge: .relay,
      fromChain: "1",
      toChain: "137"
    )

    // when
    let data = try encoder.encode(request)
    let decoded = try decoder.decode(LifiStatusRequest.self, from: data)

    // then
    XCTAssertEqual(decoded.txHash, "0xabc123def456")
    XCTAssertEqual(decoded.bridge, .relay)
    XCTAssertEqual(decoded.fromChain, "1")
    XCTAssertEqual(decoded.toChain, "137")
  }

  func test_lifiStatusRequest_allBridgeTypes() throws {
    let bridges: [LifiStatusBridge] = [
      .hop, .cbridge, .celercircle, .optimism, .polygon,
      .arbitrum, .avalanche, .across, .gnosis, .omni,
      .relay, .celerim, .symbiosis, .thorswap, .squid,
      .allbridge, .mayan, .debridge, .chainflip
    ]

    for bridge in bridges {
      let request = LifiStatusRequest(txHash: "0xtest", bridge: bridge)
      let data = try encoder.encode(request)
      let decoded = try decoder.decode(LifiStatusRequest.self, from: data)
      XCTAssertEqual(decoded.bridge, bridge)
    }
  }
}

// MARK: - LifiRoutesResponse Codable Tests

extension LifiCodableTests {
  func test_lifiRoutesResponse_encodesAndDecodesCorrectly() throws {
    // given
    let response = LifiRoutesResponse.stub()

    // when
    let data = try encoder.encode(response)
    let decoded = try decoder.decode(LifiRoutesResponse.self, from: data)

    // then
    XCTAssertNotNil(decoded.data)
    XCTAssertNil(decoded.error)
  }

  func test_lifiRoutesResponse_withError() throws {
    // given
    let response = LifiRoutesResponse(data: nil, error: "No routes found")

    // when
    let data = try encoder.encode(response)
    let decoded = try decoder.decode(LifiRoutesResponse.self, from: data)

    // then
    XCTAssertNil(decoded.data)
    XCTAssertEqual(decoded.error, "No routes found")
  }

  func test_lifiRoutesResponse_withMultipleRoutes() throws {
    // given
    let routes = [
      LifiRoute.stub(id: "route-1", tags: ["FASTEST"]),
      LifiRoute.stub(id: "route-2", tags: ["CHEAPEST"]),
      LifiRoute.stub(id: "route-3", tags: ["RECOMMENDED"])
    ]
    let rawResponse = LifiRoutesRawResponse(routes: routes, unavailableRoutes: nil)
    let response = LifiRoutesResponse(data: LifiRoutesData(rawResponse: rawResponse), error: nil)

    // when
    let data = try encoder.encode(response)
    let decoded = try decoder.decode(LifiRoutesResponse.self, from: data)

    // then
    XCTAssertEqual(decoded.data?.rawResponse.routes.count, 3)
    XCTAssertEqual(decoded.data?.rawResponse.routes[0].id, "route-1")
    XCTAssertEqual(decoded.data?.rawResponse.routes[0].tags, ["FASTEST"])
    XCTAssertEqual(decoded.data?.rawResponse.routes[1].id, "route-2")
    XCTAssertEqual(decoded.data?.rawResponse.routes[2].id, "route-3")
  }

  func test_lifiRoutesResponse_withUnavailableRoutes() throws {
    // given
    let unavailableRoutes = LifiUnavailableRoutes(
      filteredOut: [
        LifiFilteredRoute(overallPath: "1:USDC-hop-137:USDC", reason: "Insufficient liquidity")
      ],
      failed: [
        LifiFailedRoute(overallPath: "1:ETH-across-137:MATIC", subpaths: nil)
      ]
    )
    let rawResponse = LifiRoutesRawResponse(routes: [], unavailableRoutes: unavailableRoutes)
    let response = LifiRoutesResponse(data: LifiRoutesData(rawResponse: rawResponse), error: nil)

    // when
    let data = try encoder.encode(response)
    let decoded = try decoder.decode(LifiRoutesResponse.self, from: data)

    // then
    XCTAssertEqual(decoded.data?.rawResponse.routes.count, 0)
    XCTAssertEqual(decoded.data?.rawResponse.unavailableRoutes?.filteredOut?.count, 1)
    XCTAssertEqual(decoded.data?.rawResponse.unavailableRoutes?.filteredOut?[0].reason, "Insufficient liquidity")
    XCTAssertEqual(decoded.data?.rawResponse.unavailableRoutes?.failed?.count, 1)
  }
}

// MARK: - LifiStep Codable Tests

extension LifiCodableTests {
  func test_lifiStep_encodesAndDecodesCorrectly() throws {
    // given
    let step = LifiStep.stub()

    // when
    let data = try encoder.encode(step)
    let decoded = try decoder.decode(LifiStep.self, from: data)

    // then
    XCTAssertEqual(decoded.id, step.id)
    XCTAssertEqual(decoded.type, step.type)
    XCTAssertEqual(decoded.tool, step.tool)
  }

  func test_lifiStep_allTypes() throws {
    let types: [LifiStepType] = [.swap, .cross, .lifi, .protocol]

    for type in types {
      let step = LifiStep.stub(type: type)
      let data = try encoder.encode(step)
      let decoded = try decoder.decode(LifiStep.self, from: data)
      XCTAssertEqual(decoded.type, type)
    }
  }

  func test_lifiStep_withIncludedSteps() throws {
    // given
    let includedSteps = [
      LifiInternalStep.stub(id: "step-1", type: .swap),
      LifiInternalStep.stub(id: "step-2", type: .cross)
    ]
    let step = LifiStep.stub(includedSteps: includedSteps)

    // when
    let data = try encoder.encode(step)
    let decoded = try decoder.decode(LifiStep.self, from: data)

    // then
    XCTAssertEqual(decoded.includedSteps?.count, 2)
    XCTAssertEqual(decoded.includedSteps?[0].id, "step-1")
    XCTAssertEqual(decoded.includedSteps?[0].type, .swap)
    XCTAssertEqual(decoded.includedSteps?[1].id, "step-2")
    XCTAssertEqual(decoded.includedSteps?[1].type, .cross)
  }
}

// MARK: - LifiEstimate Codable Tests

extension LifiCodableTests {
  func test_lifiEstimate_encodesAndDecodesCorrectly() throws {
    // given
    let estimate = LifiEstimate.stub()

    // when
    let data = try encoder.encode(estimate)
    let decoded = try decoder.decode(LifiEstimate.self, from: data)

    // then
    XCTAssertEqual(decoded.tool, estimate.tool)
    XCTAssertEqual(decoded.fromAmount, estimate.fromAmount)
    XCTAssertEqual(decoded.toAmount, estimate.toAmount)
    XCTAssertEqual(decoded.toAmountMin, estimate.toAmountMin)
    XCTAssertEqual(decoded.approvalAddress, estimate.approvalAddress)
    XCTAssertEqual(decoded.executionDuration, estimate.executionDuration)
  }

  func test_lifiEstimate_withCosts() throws {
    // given
    let feeCosts = [
      LifiFeeCost.stub(name: "Fee 1"),
      LifiFeeCost.stub(name: "Fee 2")
    ]
    let gasCosts = [
      LifiGasCost.stub(type: .approve),
      LifiGasCost.stub(type: .send)
    ]
    let estimate = LifiEstimate(
      tool: "uniswap",
      fromAmount: "1000000000000000000",
      toAmount: "950000000000000000",
      toAmountMin: "940000000000000000",
      approvalAddress: "0xApproval",
      executionDuration: 60.0,
      fromAmountUSD: "3000.00",
      toAmountUSD: "2850.00",
      feeCosts: feeCosts,
      gasCosts: gasCosts,
      data: nil
    )

    // when
    let data = try encoder.encode(estimate)
    let decoded = try decoder.decode(LifiEstimate.self, from: data)

    // then
    XCTAssertEqual(decoded.feeCosts?.count, 2)
    XCTAssertEqual(decoded.gasCosts?.count, 2)
    XCTAssertEqual(decoded.gasCosts?[0].type, .approve)
    XCTAssertEqual(decoded.gasCosts?[1].type, .send)
  }
}

// MARK: - LifiGasCost Codable Tests

extension LifiCodableTests {
  func test_lifiGasCost_allTypes() throws {
    let types: [LifiGasCostType] = [.sum, .approve, .send]

    for type in types {
      let gasCost = LifiGasCost.stub(type: type)
      let data = try encoder.encode(gasCost)
      let decoded = try decoder.decode(LifiGasCost.self, from: data)
      XCTAssertEqual(decoded.type, type)
    }
  }

  func test_lifiGasCost_encodesAllFields() throws {
    // given
    let gasCost = LifiGasCost(
      type: .send,
      amount: "21000000000000",
      token: LifiToken.stub(),
      price: "50000000000",
      estimate: "21000",
      limit: "30000",
      amountUSD: "5.00"
    )

    // when
    let data = try encoder.encode(gasCost)
    let decoded = try decoder.decode(LifiGasCost.self, from: data)

    // then
    XCTAssertEqual(decoded.type, .send)
    XCTAssertEqual(decoded.amount, "21000000000000")
    XCTAssertEqual(decoded.price, "50000000000")
    XCTAssertEqual(decoded.estimate, "21000")
    XCTAssertEqual(decoded.limit, "30000")
    XCTAssertEqual(decoded.amountUSD, "5.00")
  }
}

// MARK: - LifiStatusResponse Codable Tests

extension LifiCodableTests {
  func test_lifiStatusResponse_allStatuses() throws {
    let statuses: [LifiTransferStatus] = [.notFound, .invalid, .pending, .done, .failed]

    for status in statuses {
      let rawResponse = LifiStatusRawResponse.stub(status: status)
      let response = LifiStatusResponse(data: LifiStatusData(rawResponse: rawResponse), error: nil)
      let data = try encoder.encode(response)
      let decoded = try decoder.decode(LifiStatusResponse.self, from: data)
      XCTAssertEqual(decoded.data?.rawResponse.status, status)
    }
  }

  func test_lifiStatusResponse_allSubstatuses() throws {
    let substatuses: [LifiTransferSubstatus] = [
      .waitSourceConfirmations, .waitDestinationTransaction,
      .bridgeNotAvailable, .chainNotAvailable, .refundInProgress,
      .unknownError, .completed, .partial, .refunded
    ]

    for substatus in substatuses {
      let rawResponse = LifiStatusRawResponse.stub(substatus: substatus)
      let response = LifiStatusResponse(data: LifiStatusData(rawResponse: rawResponse), error: nil)
      let data = try encoder.encode(response)
      let decoded = try decoder.decode(LifiStatusResponse.self, from: data)
      XCTAssertEqual(decoded.data?.rawResponse.substatus, substatus)
    }
  }

  func test_lifiStatusResponse_withReceivingInfo() throws {
    // given
    let receiving = LifiReceivingInfo.stub(
      chainId: "137",
      txHash: "0xdef789",
      amount: "950000000000000000"
    )
    let rawResponse = LifiStatusRawResponse.stub(receiving: receiving)
    let response = LifiStatusResponse(data: LifiStatusData(rawResponse: rawResponse), error: nil)

    // when
    let data = try encoder.encode(response)
    let decoded = try decoder.decode(LifiStatusResponse.self, from: data)

    // then
    XCTAssertEqual(decoded.data?.rawResponse.receiving?.chainId, "137")
    XCTAssertEqual(decoded.data?.rawResponse.receiving?.txHash, "0xdef789")
    XCTAssertEqual(decoded.data?.rawResponse.receiving?.amount, "950000000000000000")
  }
}

// MARK: - LifiRoute Codable Tests

extension LifiCodableTests {
  func test_lifiRoute_encodesAndDecodesCorrectly() throws {
    // given
    let route = LifiRoute.stub()

    // when
    let data = try encoder.encode(route)
    let decoded = try decoder.decode(LifiRoute.self, from: data)

    // then
    XCTAssertEqual(decoded.id, route.id)
    XCTAssertEqual(decoded.fromChainId, route.fromChainId)
    XCTAssertEqual(decoded.toChainId, route.toChainId)
    XCTAssertEqual(decoded.fromAmount, route.fromAmount)
    XCTAssertEqual(decoded.toAmount, route.toAmount)
    XCTAssertEqual(decoded.gasCostUSD, route.gasCostUSD)
    XCTAssertEqual(decoded.tags, route.tags)
  }

  func test_lifiRoute_withMultipleSteps() throws {
    // given
    let steps = [
      LifiStep.stub(id: "step-1", type: .swap, tool: "uniswap"),
      LifiStep.stub(id: "step-2", type: .cross, tool: "relay"),
      LifiStep.stub(id: "step-3", type: .swap, tool: "sushiswap")
    ]
    let route = LifiRoute.stub(steps: steps)

    // when
    let data = try encoder.encode(route)
    let decoded = try decoder.decode(LifiRoute.self, from: data)

    // then
    XCTAssertEqual(decoded.steps.count, 3)
    XCTAssertEqual(decoded.steps[0].id, "step-1")
    XCTAssertEqual(decoded.steps[0].type, .swap)
    XCTAssertEqual(decoded.steps[1].id, "step-2")
    XCTAssertEqual(decoded.steps[1].type, .cross)
    XCTAssertEqual(decoded.steps[2].id, "step-3")
  }
}

// MARK: - LifiAction Codable Tests

extension LifiCodableTests {
  func test_lifiAction_encodesAndDecodesCorrectly() throws {
    // given
    let action = LifiAction.stub()

    // when
    let data = try encoder.encode(action)
    let decoded = try decoder.decode(LifiAction.self, from: data)

    // then
    XCTAssertEqual(decoded.fromChainId, action.fromChainId)
    XCTAssertEqual(decoded.fromAmount, action.fromAmount)
    XCTAssertEqual(decoded.toChainId, action.toChainId)
    XCTAssertEqual(decoded.slippage, action.slippage)
    XCTAssertEqual(decoded.fromAddress, action.fromAddress)
    XCTAssertEqual(decoded.toAddress, action.toAddress)
  }

  func test_lifiAction_withDestinationGasConsumption() throws {
    // given
    let action = LifiAction(
      fromChainId: "1",
      fromAmount: "1000000000000000000",
      fromToken: LifiToken.stub(),
      toChainId: "137",
      toToken: LifiToken.stub(),
      slippage: 0.005,
      fromAddress: "0xSender",
      toAddress: "0xReceiver",
      destinationGasConsumption: "50000"
    )

    // when
    let data = try encoder.encode(action)
    let decoded = try decoder.decode(LifiAction.self, from: data)

    // then
    XCTAssertEqual(decoded.destinationGasConsumption, "50000")
  }
}

// MARK: - LifiToolDetails Codable Tests

extension LifiCodableTests {
  func test_lifiToolDetails_encodesAndDecodesCorrectly() throws {
    // given
    let toolDetails = LifiToolDetails.stub()

    // when
    let data = try encoder.encode(toolDetails)
    let decoded = try decoder.decode(LifiToolDetails.self, from: data)

    // then
    XCTAssertEqual(decoded.key, toolDetails.key)
    XCTAssertEqual(decoded.name, toolDetails.name)
    XCTAssertEqual(decoded.logoURI, toolDetails.logoURI)
    XCTAssertEqual(decoded.webUrl, toolDetails.webUrl)
  }

  func test_lifiToolDetails_withNilFields() throws {
    // given
    let json = """
    {
      "key": "uniswap"
    }
    """
    let data = json.data(using: .utf8)!

    // when
    let decoded = try decoder.decode(LifiToolDetails.self, from: data)

    // then
    XCTAssertEqual(decoded.key, "uniswap")
    XCTAssertNil(decoded.name)
    XCTAssertNil(decoded.logoURI)
    XCTAssertNil(decoded.webUrl)
  }
}

// MARK: - LifiFeeCost Codable Tests

extension LifiCodableTests {
  func test_lifiFeeCost_encodesAndDecodesCorrectly() throws {
    // given
    let feeCost = LifiFeeCost.stub()

    // when
    let data = try encoder.encode(feeCost)
    let decoded = try decoder.decode(LifiFeeCost.self, from: data)

    // then
    XCTAssertEqual(decoded.name, feeCost.name)
    XCTAssertEqual(decoded.percentage, feeCost.percentage)
    XCTAssertEqual(decoded.amountUSD, feeCost.amountUSD)
    XCTAssertEqual(decoded.included, feeCost.included)
    XCTAssertEqual(decoded.description, feeCost.description)
    XCTAssertEqual(decoded.amount, feeCost.amount)
  }

  func test_lifiFeeCost_withFeeSplit() throws {
    // given
    let feeSplit = LifiFeeSplit(integratorFee: "0.002", lifiFee: "0.001")
    let feeCost = LifiFeeCost(
      name: "Protocol Fee",
      percentage: "0.003",
      token: LifiToken.stub(),
      amountUSD: "3.00",
      included: true,
      description: "Split fee",
      amount: "1000000000000000",
      feeSplit: feeSplit
    )

    // when
    let data = try encoder.encode(feeCost)
    let decoded = try decoder.decode(LifiFeeCost.self, from: data)

    // then
    XCTAssertEqual(decoded.feeSplit?.integratorFee, "0.002")
    XCTAssertEqual(decoded.feeSplit?.lifiFee, "0.001")
  }
}

// MARK: - LifiTimingStrategy Codable Tests

extension LifiCodableTests {
  func test_lifiTimingStrategy_encodesAndDecodesCorrectly() throws {
    // given
    let strategy = LifiTimingStrategy(
      strategy: .minWaitTime,
      minWaitTimeMs: 1000,
      startingExpectedResults: 10,
      reduceEveryMs: 100
    )

    // when
    let data = try encoder.encode(strategy)
    let decoded = try decoder.decode(LifiTimingStrategy.self, from: data)

    // then
    XCTAssertEqual(decoded.strategy, .minWaitTime)
    XCTAssertEqual(decoded.minWaitTimeMs, 1000)
    XCTAssertEqual(decoded.startingExpectedResults, 10)
    XCTAssertEqual(decoded.reduceEveryMs, 100)
  }
}

// MARK: - LifiToolsConfiguration Codable Tests

extension LifiCodableTests {
  func test_lifiToolsConfiguration_encodesAndDecodesCorrectly() throws {
    // given
    let config = LifiToolsConfiguration(
      allow: ["hop", "across", "relay"],
      deny: ["cbridge"],
      prefer: ["relay", "hop"]
    )

    // when
    let data = try encoder.encode(config)
    let decoded = try decoder.decode(LifiToolsConfiguration.self, from: data)

    // then
    XCTAssertEqual(decoded.allow, ["hop", "across", "relay"])
    XCTAssertEqual(decoded.deny, ["cbridge"])
    XCTAssertEqual(decoded.prefer, ["relay", "hop"])
  }

  func test_lifiToolsConfiguration_withEmptyArrays() throws {
    // given
    let config = LifiToolsConfiguration(allow: [], deny: [], prefer: [])

    // when
    let data = try encoder.encode(config)
    let decoded = try decoder.decode(LifiToolsConfiguration.self, from: data)

    // then
    XCTAssertEqual(decoded.allow, [])
    XCTAssertEqual(decoded.deny, [])
    XCTAssertEqual(decoded.prefer, [])
  }
}

// MARK: - Enum Raw Value Tests

extension LifiCodableTests {
  func test_lifiRoutesOrder_rawValues() {
    XCTAssertEqual(LifiRoutesOrder.fastest.rawValue, "FASTEST")
    XCTAssertEqual(LifiRoutesOrder.cheapest.rawValue, "CHEAPEST")
  }

  func test_lifiQuoteOrder_rawValues() {
    XCTAssertEqual(LifiQuoteOrder.fastest.rawValue, "FASTEST")
    XCTAssertEqual(LifiQuoteOrder.cheapest.rawValue, "CHEAPEST")
  }

  func test_lifiStepType_rawValues() {
    XCTAssertEqual(LifiStepType.swap.rawValue, "swap")
    XCTAssertEqual(LifiStepType.cross.rawValue, "cross")
    XCTAssertEqual(LifiStepType.lifi.rawValue, "lifi")
    XCTAssertEqual(LifiStepType.protocol.rawValue, "protocol")
  }

  func test_lifiGasCostType_rawValues() {
    XCTAssertEqual(LifiGasCostType.sum.rawValue, "SUM")
    XCTAssertEqual(LifiGasCostType.approve.rawValue, "APPROVE")
    XCTAssertEqual(LifiGasCostType.send.rawValue, "SEND")
  }

  func test_lifiTransferStatus_rawValues() {
    XCTAssertEqual(LifiTransferStatus.notFound.rawValue, "NOT_FOUND")
    XCTAssertEqual(LifiTransferStatus.invalid.rawValue, "INVALID")
    XCTAssertEqual(LifiTransferStatus.pending.rawValue, "PENDING")
    XCTAssertEqual(LifiTransferStatus.done.rawValue, "DONE")
    XCTAssertEqual(LifiTransferStatus.failed.rawValue, "FAILED")
  }

  func test_lifiTransferSubstatus_rawValues() {
    XCTAssertEqual(LifiTransferSubstatus.waitSourceConfirmations.rawValue, "WAIT_SOURCE_CONFIRMATIONS")
    XCTAssertEqual(LifiTransferSubstatus.waitDestinationTransaction.rawValue, "WAIT_DESTINATION_TRANSACTION")
    XCTAssertEqual(LifiTransferSubstatus.bridgeNotAvailable.rawValue, "BRIDGE_NOT_AVAILABLE")
    XCTAssertEqual(LifiTransferSubstatus.chainNotAvailable.rawValue, "CHAIN_NOT_AVAILABLE")
    XCTAssertEqual(LifiTransferSubstatus.refundInProgress.rawValue, "REFUND_IN_PROGRESS")
    XCTAssertEqual(LifiTransferSubstatus.unknownError.rawValue, "UNKNOWN_ERROR")
    XCTAssertEqual(LifiTransferSubstatus.completed.rawValue, "COMPLETED")
    XCTAssertEqual(LifiTransferSubstatus.partial.rawValue, "PARTIAL")
    XCTAssertEqual(LifiTransferSubstatus.refunded.rawValue, "REFUNDED")
  }

  func test_lifiErrorCode_rawValues() {
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

  func test_lifiErrorType_rawValues() {
    XCTAssertEqual(LifiErrorType.noQuote.rawValue, "NO_QUOTE")
  }

  func test_lifiTimingStrategyType_rawValues() {
    XCTAssertEqual(LifiTimingStrategyType.minWaitTime.rawValue, "minWaitTime")
  }

  func test_lifiStatusBridge_rawValues() {
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
