//
//  Lifi.swift
//  PortalSwift
//
//  Created by Portal Labs
//

import AnyCodable
import Foundation
@testable import PortalSwift

// MARK: - Token

extension LifiToken {
  static func stub(
    address: String = "0x0000000000000000000000000000000000000000",
    symbol: String = "ETH",
    decimals: Int = 18,
    chainId: String = "1",
    name: String = "Ethereum",
    coinKey: String? = "ETH",
    logoURI: String? = "https://example.com/eth.png",
    priceUSD: String? = "3000.00"
  ) -> Self {
    LifiToken(
      address: address,
      symbol: symbol,
      decimals: decimals,
      chainId: chainId,
      name: name,
      coinKey: coinKey,
      logoURI: logoURI,
      priceUSD: priceUSD
    )
  }
}

// MARK: - Tool Details

extension LifiToolDetails {
  static func stub(
    key: String? = "uniswap",
    name: String? = "Uniswap",
    logoURI: String? = "https://example.com/uniswap.png",
    webUrl: String? = "https://uniswap.org"
  ) -> Self {
    LifiToolDetails(key: key, name: name, logoURI: logoURI, webUrl: webUrl)
  }
}

// MARK: - Action

extension LifiAction {
  static func stub(
    fromChainId: String = "1",
    fromAmount: String = "1000000000000000000",
    fromToken: LifiToken = .stub(),
    toChainId: String = "137",
    toToken: LifiToken = .stub(symbol: "MATIC", chainId: "137", name: "Polygon"),
    slippage: Double? = 0.005,
    fromAddress: String? = "0x1234567890abcdef1234567890abcdef12345678",
    toAddress: String? = "0x1234567890abcdef1234567890abcdef12345678",
    destinationGasConsumption: String? = nil
  ) -> Self {
    LifiAction(
      fromChainId: fromChainId,
      fromAmount: fromAmount,
      fromToken: fromToken,
      toChainId: toChainId,
      toToken: toToken,
      slippage: slippage,
      fromAddress: fromAddress,
      toAddress: toAddress,
      destinationGasConsumption: destinationGasConsumption
    )
  }
}

// MARK: - Fee Cost

extension LifiFeeCost {
  static func stub(
    name: String = "Protocol Fee",
    percentage: String = "0.003",
    token: LifiToken = .stub(),
    amountUSD: String = "3.00",
    included: Bool = true,
    description: String? = "Fee charged by the protocol",
    amount: String? = "1000000000000000",
    feeSplit: LifiFeeSplit? = nil
  ) -> Self {
    LifiFeeCost(
      name: name,
      percentage: percentage,
      token: token,
      amountUSD: amountUSD,
      included: included,
      description: description,
      amount: amount,
      feeSplit: feeSplit
    )
  }
}

// MARK: - Gas Cost

extension LifiGasCost {
  static func stub(
    type: LifiGasCostType = .send,
    amount: String = "21000000000000",
    token: LifiToken = .stub(),
    price: String? = "50000000000",
    estimate: String? = "21000",
    limit: String? = "30000",
    amountUSD: String? = "5.00"
  ) -> Self {
    LifiGasCost(
      type: type,
      amount: amount,
      token: token,
      price: price,
      estimate: estimate,
      limit: limit,
      amountUSD: amountUSD
    )
  }
}

// MARK: - Estimate

extension LifiEstimate {
  static func stub(
    tool: String = "uniswap",
    fromAmount: String = "1000000000000000000",
    toAmount: String = "950000000000000000",
    toAmountMin: String = "940000000000000000",
    approvalAddress: String = "0xApprovalAddress",
    executionDuration: Double = 60.0,
    fromAmountUSD: String? = "3000.00",
    toAmountUSD: String? = "2850.00",
    feeCosts: [LifiFeeCost]? = [.stub()],
    gasCosts: [LifiGasCost]? = [.stub()],
    data: LifiEstimateData? = nil
  ) -> Self {
    LifiEstimate(
      tool: tool,
      fromAmount: fromAmount,
      toAmount: toAmount,
      toAmountMin: toAmountMin,
      approvalAddress: approvalAddress,
      executionDuration: executionDuration,
      fromAmountUSD: fromAmountUSD,
      toAmountUSD: toAmountUSD,
      feeCosts: feeCosts,
      gasCosts: gasCosts,
      data: data
    )
  }
}

// MARK: - Internal Step

extension LifiInternalStep {
  static func stub(
    id: String = "internal-step-1",
    type: LifiStepType = .swap,
    tool: String = "uniswap",
    toolDetails: LifiToolDetails = .stub(),
    action: LifiAction = .stub(),
    estimate: LifiEstimate = .stub()
  ) -> Self {
    LifiInternalStep(
      id: id,
      type: type,
      tool: tool,
      toolDetails: toolDetails,
      action: action,
      estimate: estimate
    )
  }
}

// MARK: - Step

extension LifiStep {
  static func stub(
    id: String = "step-1",
    type: LifiStepType = .lifi,
    tool: String = "relay",
    action: LifiAction = .stub(),
    toolDetails: LifiToolDetails? = .stub(),
    estimate: LifiEstimate? = .stub(),
    includedSteps: [LifiInternalStep]? = nil,
    integrator: String? = "portal",
    referrer: String? = nil,
    execution: AnyCodable? = nil,
    transactionRequest: AnyCodable? = nil,
    transactionId: String? = "tx-123",
    gasCostUSD: String? = "5.00",
    fromAddress: String? = "0x1234567890abcdef1234567890abcdef12345678",
    toAddress: String? = "0x1234567890abcdef1234567890abcdef12345678",
    containsSwitchChain: Bool? = false
  ) -> Self {
    LifiStep(
      id: id,
      type: type,
      tool: tool,
      action: action,
      toolDetails: toolDetails,
      estimate: estimate,
      includedSteps: includedSteps,
      integrator: integrator,
      referrer: referrer,
      execution: execution,
      transactionRequest: transactionRequest,
      transactionId: transactionId,
      gasCostUSD: gasCostUSD,
      fromAddress: fromAddress,
      toAddress: toAddress,
      containsSwitchChain: containsSwitchChain
    )
  }
}

// MARK: - Route

extension LifiRoute {
  static func stub(
    id: String = "route-1",
    fromChainId: String = "1",
    fromAmountUSD: String = "3000.00",
    fromAmount: String = "1000000000000000000",
    fromToken: LifiToken = .stub(),
    toChainId: String = "137",
    toAmountUSD: String = "2850.00",
    toAmount: String = "950000000000000000",
    toAmountMin: String = "940000000000000000",
    toToken: LifiToken = .stub(symbol: "MATIC", chainId: "137"),
    steps: [LifiStep] = [.stub()],
    gasCostUSD: String? = "5.00",
    fromAddress: String? = "0x1234567890abcdef1234567890abcdef12345678",
    toAddress: String? = "0x1234567890abcdef1234567890abcdef12345678",
    containsSwitchChain: Bool? = false,
    tags: [String]? = ["RECOMMENDED"]
  ) -> Self {
    LifiRoute(
      id: id,
      fromChainId: fromChainId,
      fromAmountUSD: fromAmountUSD,
      fromAmount: fromAmount,
      fromToken: fromToken,
      toChainId: toChainId,
      toAmountUSD: toAmountUSD,
      toAmount: toAmount,
      toAmountMin: toAmountMin,
      toToken: toToken,
      steps: steps,
      gasCostUSD: gasCostUSD,
      fromAddress: fromAddress,
      toAddress: toAddress,
      containsSwitchChain: containsSwitchChain,
      tags: tags
    )
  }
}

// MARK: - Unavailable Routes

extension LifiFilteredRoute {
  static func stub(
    overallPath: String? = "1:USDC-hop-137:USDC",
    reason: String? = "Insufficient liquidity"
  ) -> Self {
    LifiFilteredRoute(overallPath: overallPath, reason: reason)
  }
}

extension LifiFailedRoute {
  static func stub(
    overallPath: String? = "1:ETH-across-137:MATIC",
    subpaths: [String: LifiSubpathError]? = nil
  ) -> Self {
    LifiFailedRoute(overallPath: overallPath, subpaths: subpaths)
  }
}

extension LifiUnavailableRoutes {
  static func stub(
    filteredOut: [LifiFilteredRoute]? = nil,
    failed: [LifiFailedRoute]? = nil
  ) -> Self {
    LifiUnavailableRoutes(filteredOut: filteredOut, failed: failed)
  }
}

// MARK: - Routes Response

extension LifiRoutesRawResponse {
  static func stub(
    routes: [LifiRoute] = [.stub()],
    unavailableRoutes: LifiUnavailableRoutes? = nil
  ) -> Self {
    LifiRoutesRawResponse(routes: routes, unavailableRoutes: unavailableRoutes)
  }
}

extension LifiRoutesData {
  static func stub(rawResponse: LifiRoutesRawResponse = .stub()) -> Self {
    LifiRoutesData(rawResponse: rawResponse)
  }
}

extension LifiRoutesResponse {
  static func stub(data: LifiRoutesData? = .stub(), error: String? = nil) -> Self {
    LifiRoutesResponse(data: data, error: error)
  }
}

// MARK: - Quote Response

extension LifiQuoteData {
  static func stub(rawResponse: LifiStep = .stub()) -> Self {
    LifiQuoteData(rawResponse: rawResponse)
  }
}

extension LifiQuoteResponse {
  static func stub(data: LifiQuoteData? = .stub(), error: String? = nil) -> Self {
    LifiQuoteResponse(data: data, error: error)
  }
}

// MARK: - Status Response

extension LifiTransactionInfo {
  static func stub(
    txHash: String = "0xabc123def456",
    txLink: String = "https://etherscan.io/tx/0xabc123def456",
    amount: String = "1000000000000000000",
    amountUSD: String? = "3000.00",
    token: LifiToken = .stub(),
    chainId: String = "1",
    gasToken: LifiToken? = .stub(),
    gasAmount: String? = "21000000000000",
    gasAmountUSD: String? = "5.00",
    gasPrice: String? = "50000000000",
    gasUsed: String? = "21000",
    timestamp: Int? = 1_700_000_000,
    value: String? = "1000000000000000000",
    includedSteps: [LifiIncludedSwapStep]? = nil
  ) -> Self {
    LifiTransactionInfo(
      txHash: txHash,
      txLink: txLink,
      amount: amount,
      amountUSD: amountUSD,
      token: token,
      chainId: chainId,
      gasToken: gasToken,
      gasAmount: gasAmount,
      gasAmountUSD: gasAmountUSD,
      gasPrice: gasPrice,
      gasUsed: gasUsed,
      timestamp: timestamp,
      value: value,
      includedSteps: includedSteps
    )
  }
}

extension LifiReceivingInfo {
  static func stub(
    chainId: String? = "137",
    txHash: String? = "0xdef789abc012",
    txLink: String? = "https://polygonscan.com/tx/0xdef789abc012",
    token: LifiToken? = .stub(chainId: "137"),
    amount: String? = "950000000000000000",
    gasToken: LifiToken? = nil,
    gasAmount: String? = nil,
    gasAmountUSD: String? = nil,
    gasPrice: String? = nil,
    gasUsed: String? = nil,
    timestamp: Int? = 1_700_000_060,
    value: String? = nil,
    includedSteps: [LifiIncludedSwapStep]? = nil
  ) -> Self {
    LifiReceivingInfo(
      chainId: chainId,
      txHash: txHash,
      txLink: txLink,
      token: token,
      amount: amount,
      gasToken: gasToken,
      gasAmount: gasAmount,
      gasAmountUSD: gasAmountUSD,
      gasPrice: gasPrice,
      gasUsed: gasUsed,
      timestamp: timestamp,
      value: value,
      includedSteps: includedSteps
    )
  }
}

extension LifiMetadata {
  static func stub(integrator: String? = "portal") -> Self {
    LifiMetadata(integrator: integrator)
  }
}

extension LifiStatusRawResponse {
  static func stub(
    sending: LifiTransactionInfo = .stub(),
    receiving: LifiReceivingInfo? = .stub(),
    feeCosts: [LifiFeeCost]? = nil,
    status: LifiTransferStatus = .done,
    substatus: LifiTransferSubstatus? = .completed,
    substatusMessage: String? = "Transfer completed successfully",
    tool: String = "relay",
    transactionId: String? = "tx-123",
    fromAddress: String? = "0x1234567890abcdef1234567890abcdef12345678",
    toAddress: String? = "0x1234567890abcdef1234567890abcdef12345678",
    lifiExplorerLink: String? = "https://explorer.li.fi/tx/123",
    bridgeExplorerLink: String? = nil,
    metadata: LifiMetadata? = .stub()
  ) -> Self {
    LifiStatusRawResponse(
      sending: sending,
      receiving: receiving,
      feeCosts: feeCosts,
      status: status,
      substatus: substatus,
      substatusMessage: substatusMessage,
      tool: tool,
      transactionId: transactionId,
      fromAddress: fromAddress,
      toAddress: toAddress,
      lifiExplorerLink: lifiExplorerLink,
      bridgeExplorerLink: bridgeExplorerLink,
      metadata: metadata
    )
  }
}

extension LifiStatusData {
  static func stub(rawResponse: LifiStatusRawResponse = .stub()) -> Self {
    LifiStatusData(rawResponse: rawResponse)
  }
}

extension LifiStatusResponse {
  static func stub(data: LifiStatusData? = .stub(), error: String? = nil) -> Self {
    LifiStatusResponse(data: data, error: error)
  }
}

// MARK: - Step Transaction Response

extension LifiStepTransactionData {
  static func stub(rawResponse: LifiStep = .stub()) -> Self {
    LifiStepTransactionData(rawResponse: rawResponse)
  }
}

extension LifiStepTransactionResponse {
  static func stub(data: LifiStepTransactionData? = .stub(), error: String? = nil) -> Self {
    LifiStepTransactionResponse(data: data, error: error)
  }
}

// MARK: - Request Stubs

extension LifiRoutesRequest {
  static func stub(
    fromChainId: String = "1",
    fromAmount: String = "1000000000000000000",
    fromTokenAddress: String = "0x0000000000000000000000000000000000000000",
    toChainId: String = "137",
    toTokenAddress: String = "0x0000000000000000000000000000000000001010",
    options: LifiRoutesRequestOptions? = nil,
    fromAddress: String? = "0x1234567890abcdef1234567890abcdef12345678",
    toAddress: String? = "0x1234567890abcdef1234567890abcdef12345678",
    fromAmountForGas: String? = nil
  ) -> Self {
    LifiRoutesRequest(
      fromChainId: fromChainId,
      fromAmount: fromAmount,
      fromTokenAddress: fromTokenAddress,
      toChainId: toChainId,
      toTokenAddress: toTokenAddress,
      options: options,
      fromAddress: fromAddress,
      toAddress: toAddress,
      fromAmountForGas: fromAmountForGas
    )
  }
}

extension LifiRoutesRequestOptions {
  static func stub(
    insurance: Bool? = nil,
    integrator: String? = "portal",
    slippage: Double? = 0.005,
    bridges: LifiToolsConfiguration? = nil,
    exchanges: LifiToolsConfiguration? = nil,
    order: LifiRoutesOrder? = .fastest,
    allowSwitchChain: Bool? = false,
    allowDestinationCall: Bool? = true,
    referrer: String? = nil,
    fee: Double? = nil,
    maxPriceImpact: Double? = 0.1,
    timing: LifiTimingOptions? = nil
  ) -> Self {
    LifiRoutesRequestOptions(
      insurance: insurance,
      integrator: integrator,
      slippage: slippage,
      bridges: bridges,
      exchanges: exchanges,
      order: order,
      allowSwitchChain: allowSwitchChain,
      allowDestinationCall: allowDestinationCall,
      referrer: referrer,
      fee: fee,
      maxPriceImpact: maxPriceImpact,
      timing: timing
    )
  }
}

extension LifiQuoteRequest {
  static func stub(
    fromChain: String = "1",
    toChain: String = "137",
    fromToken: String = "ETH",
    toToken: String = "MATIC",
    fromAddress: String = "0x1234567890abcdef1234567890abcdef12345678",
    fromAmount: String = "1000000000000000000",
    toAddress: String? = nil,
    order: LifiQuoteOrder? = .fastest,
    slippage: Double? = 0.005,
    integrator: String? = "portal",
    fee: Double? = nil,
    referrer: String? = nil,
    allowBridges: [String]? = nil,
    allowExchanges: [String]? = nil,
    denyBridges: [String]? = nil,
    denyExchanges: [String]? = nil,
    preferBridges: [String]? = nil,
    preferExchanges: [String]? = nil,
    allowDestinationCall: Bool? = true,
    fromAmountForGas: String? = nil,
    maxPriceImpact: Double? = nil,
    swapStepTimingStrategies: [String]? = nil,
    routeTimingStrategies: [String]? = nil,
    skipSimulation: Bool? = nil
  ) -> Self {
    LifiQuoteRequest(
      fromChain: fromChain,
      toChain: toChain,
      fromToken: fromToken,
      toToken: toToken,
      fromAddress: fromAddress,
      fromAmount: fromAmount,
      toAddress: toAddress,
      order: order,
      slippage: slippage,
      integrator: integrator,
      fee: fee,
      referrer: referrer,
      allowBridges: allowBridges,
      allowExchanges: allowExchanges,
      denyBridges: denyBridges,
      denyExchanges: denyExchanges,
      preferBridges: preferBridges,
      preferExchanges: preferExchanges,
      allowDestinationCall: allowDestinationCall,
      fromAmountForGas: fromAmountForGas,
      maxPriceImpact: maxPriceImpact,
      swapStepTimingStrategies: swapStepTimingStrategies,
      routeTimingStrategies: routeTimingStrategies,
      skipSimulation: skipSimulation
    )
  }
}

extension LifiStatusRequest {
  static func stub(
    txHash: String = "0xabc123def456",
    bridge: LifiStatusBridge? = .relay,
    fromChain: String? = "1",
    toChain: String? = "137"
  ) -> Self {
    LifiStatusRequest(
      txHash: txHash,
      bridge: bridge,
      fromChain: fromChain,
      toChain: toChain
    )
  }
}
