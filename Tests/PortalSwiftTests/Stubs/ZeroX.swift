//
//  ZeroX.swift
//  PortalSwift
//
//  Created by Portal Labs
//

import Foundation
@testable import PortalSwift

// MARK: - Quote Request

extension ZeroXQuoteRequest {
  static func stub(
    chainId: String = "eip155:1",
    buyToken: String = "USDC",
    sellToken: String = "ETH",
    sellAmount: String = "1000000000000000000",
    txOrigin: String? = nil,
    swapFeeRecipient: String? = nil,
    swapFeeBps: Int? = nil,
    swapFeeToken: String? = nil,
    tradeSurplusRecipient: String? = nil,
    gasPrice: String? = nil,
    slippageBps: Int? = nil,
    excludedSources: String? = nil,
    sellEntireBalance: Bool? = nil
  ) -> Self {
    ZeroXQuoteRequest(
      chainId: chainId,
      buyToken: buyToken,
      sellToken: sellToken,
      sellAmount: sellAmount,
      txOrigin: txOrigin,
      swapFeeRecipient: swapFeeRecipient,
      swapFeeBps: swapFeeBps,
      swapFeeToken: swapFeeToken,
      tradeSurplusRecipient: tradeSurplusRecipient,
      gasPrice: gasPrice,
      slippageBps: slippageBps,
      excludedSources: excludedSources,
      sellEntireBalance: sellEntireBalance
    )
  }
}

// MARK: - Price Request

extension ZeroXPriceRequest {
  static func stub(
    chainId: String = "eip155:1",
    buyToken: String = "USDC",
    sellToken: String = "ETH",
    sellAmount: String = "1000000000000000000",
    txOrigin: String? = nil,
    swapFeeRecipient: String? = nil,
    swapFeeBps: Int? = nil,
    swapFeeToken: String? = nil,
    tradeSurplusRecipient: String? = nil,
    gasPrice: String? = nil,
    slippageBps: Int? = nil,
    excludedSources: String? = nil,
    sellEntireBalance: Bool? = nil
  ) -> Self {
    ZeroXPriceRequest(
      chainId: chainId,
      buyToken: buyToken,
      sellToken: sellToken,
      sellAmount: sellAmount,
      txOrigin: txOrigin,
      swapFeeRecipient: swapFeeRecipient,
      swapFeeBps: swapFeeBps,
      swapFeeToken: swapFeeToken,
      tradeSurplusRecipient: tradeSurplusRecipient,
      gasPrice: gasPrice,
      slippageBps: slippageBps,
      excludedSources: excludedSources,
      sellEntireBalance: sellEntireBalance
    )
  }
}

// MARK: - Sources Response

extension ZeroXSourcesRawResponse {
  static func stub(
    sources: [String] = ["Uniswap", "Sushiswap", "Curve", "Balancer"],
    zid: String = "0xcb8b525805920333079a1625"
  ) -> Self {
    ZeroXSourcesRawResponse(sources: sources, zid: zid)
  }
}

extension ZeroXSourcesData {
  static func stub(
    rawResponse: ZeroXSourcesRawResponse = .stub()
  ) -> Self {
    ZeroXSourcesData(rawResponse: rawResponse)
  }
}

extension ZeroXSourcesResponse {
  static func stub(
    data: ZeroXSourcesData = .stub()
  ) -> Self {
    ZeroXSourcesResponse(data: data)
  }
}

// MARK: - Transaction

extension ZeroXTransaction {
  static func stub(
    data: String = "0x1234567890abcdef",
    from: String = "0x1234567890abcdef1234567890abcdef12345678",
    gas: String = "21000",
    gasPrice: String = "50000000000",
    to: String = "0xdef171fe48cf0115b1d80b88dc8eab59176fee57",
    value: String = "1000000000000000000"
  ) -> Self {
    ZeroXTransaction(
      data: data,
      from: from,
      gas: gas,
      gasPrice: gasPrice,
      to: to,
      value: value
    )
  }
}

// MARK: - Issues

extension ZeroXAllowanceIssue {
  static func stub(
    actual: String = "0",
    spender: String = "0xdef171fe48cf0115b1d80b88dc8eab59176fee57"
  ) -> Self {
    ZeroXAllowanceIssue(actual: actual, spender: spender)
  }
}

extension ZeroXBalanceIssue {
  static func stub(
    token: String = "0x0000000000000000000000000000000000000000",
    actual: String = "500000000000000000",
    expected: String = "1000000000000000000"
  ) -> Self {
    ZeroXBalanceIssue(token: token, actual: actual, expected: expected)
  }
}

extension ZeroXIssues {
  static func stub(
    allowance: ZeroXAllowanceIssue? = nil,
    balance: ZeroXBalanceIssue? = nil,
    simulationIncomplete: Bool? = false,
    invalidSourcesPassed: [String]? = []
  ) -> Self {
    ZeroXIssues(
      allowance: allowance,
      balance: balance,
      simulationIncomplete: simulationIncomplete,
      invalidSourcesPassed: invalidSourcesPassed
    )
  }
}

// MARK: - Fees

extension ZeroXFeeDetail {
  static func stub(
    amount: String? = "1000000000000000",
    token: String? = "0x0000000000000000000000000000000000000000",
    type: String? = "gas"
  ) -> Self {
    ZeroXFeeDetail(amount: amount, token: token, type: type)
  }
}

extension ZeroXZeroExFeeDetail {
  static func stub(
    billingType: String? = "on-chain",
    feeAmount: String? = "500000000000000",
    feeToken: String? = "0x0000000000000000000000000000000000000000",
    feeType: String? = "volume"
  ) -> Self {
    ZeroXZeroExFeeDetail(
      billingType: billingType,
      feeAmount: feeAmount,
      feeToken: feeToken,
      feeType: feeType
    )
  }
}

extension ZeroXFees {
  static func stub(
    integratorFee: ZeroXFeeDetail? = nil,
    zeroExFee: ZeroXZeroExFeeDetail? = nil,
    gasFee: ZeroXFeeDetail? = .stub()
  ) -> Self {
    ZeroXFees(
      integratorFee: integratorFee,
      zeroExFee: zeroExFee,
      gasFee: gasFee
    )
  }
}

// MARK: - Quote Response

extension ZeroXQuoteRawResponse {
  static func stub(
    blockNumber: String? = "24179070",
    buyAmount: String = "3000000000",
    buyToken: String? = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
    fees: ZeroXFees? = nil,
    issues: ZeroXIssues? = nil,
    liquidityAvailable: Bool? = true,
    minBuyAmount: String? = "2970000000",
    route: ZeroXRoute? = nil,
    sellAmount: String = "1000000000000000000",
    sellToken: String? = "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
    tokenMetadata: ZeroXTokenMetadata? = nil,
    totalNetworkFee: String? = "50011696133192",
    transaction: ZeroXTransaction = .stub()
  ) -> Self {
    ZeroXQuoteRawResponse(
      blockNumber: blockNumber,
      buyAmount: buyAmount,
      buyToken: buyToken,
      fees: fees,
      issues: issues,
      liquidityAvailable: liquidityAvailable,
      minBuyAmount: minBuyAmount,
      route: route,
      sellAmount: sellAmount,
      sellToken: sellToken,
      tokenMetadata: tokenMetadata,
      totalNetworkFee: totalNetworkFee,
      transaction: transaction
    )
  }
}

extension ZeroXRoute {
  static func stub(
    fills: [ZeroXFill]? = nil,
    tokens: [ZeroXRouteToken]? = nil
  ) -> Self {
    ZeroXRoute(fills: fills, tokens: tokens)
  }
}

extension ZeroXFill {
  static func stub(
    from: String = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
    to: String = "0x6b175474e89094c44da98b954eedeac495271d0f",
    source: String = "Uniswap_V2",
    proportionBps: String = "10000"
  ) -> Self {
    ZeroXFill(from: from, to: to, source: source, proportionBps: proportionBps)
  }
}

extension ZeroXRouteToken {
  static func stub(
    address: String = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
    symbol: String = "USDC"
  ) -> Self {
    ZeroXRouteToken(address: address, symbol: symbol)
  }
}

extension ZeroXTokenMetadata {
  static func stub(
    buyToken: ZeroXTokenTaxMetadata? = nil,
    sellToken: ZeroXTokenTaxMetadata? = nil
  ) -> Self {
    ZeroXTokenMetadata(buyToken: buyToken, sellToken: sellToken)
  }
}

extension ZeroXTokenTaxMetadata {
  static func stub(
    buyTaxBps: String? = "0",
    sellTaxBps: String? = "0",
    transferTaxBps: String? = "0"
  ) -> Self {
    ZeroXTokenTaxMetadata(buyTaxBps: buyTaxBps, sellTaxBps: sellTaxBps, transferTaxBps: transferTaxBps)
  }
}

extension ZeroXQuoteResponseData {
  static func stub(
    rawResponse: ZeroXQuoteRawResponse = .stub()
  ) -> Self {
    ZeroXQuoteResponseData(rawResponse: rawResponse)
  }
}

extension ZeroXQuoteResponse {
  static func stub(
    data: ZeroXQuoteResponseData = .stub()
  ) -> Self {
    ZeroXQuoteResponse(data: data)
  }
}

// MARK: - Price Response

extension ZeroXPriceRawResponse {
  static func stub(
    blockNumber: String? = "24179158",
    buyAmount: String = "3000000000",
    buyToken: String? = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
    fees: ZeroXFees? = nil,
    gas: String? = "379677",
    gasPrice: String? = "132508222",
    issues: ZeroXIssues? = nil,
    liquidityAvailable: Bool? = true,
    minBuyAmount: String? = "2970000000",
    route: ZeroXRoute? = nil,
    sellAmount: String = "1000000000000000000",
    sellToken: String? = "0xdac17f958d2ee523a2206206994597c13d831ec7",
    tokenMetadata: ZeroXTokenMetadata? = nil,
    totalNetworkFee: String? = "50310324204294"
  ) -> Self {
    ZeroXPriceRawResponse(
      blockNumber: blockNumber,
      buyAmount: buyAmount,
      buyToken: buyToken,
      fees: fees,
      gas: gas,
      gasPrice: gasPrice,
      issues: issues,
      liquidityAvailable: liquidityAvailable,
      minBuyAmount: minBuyAmount,
      route: route,
      sellAmount: sellAmount,
      sellToken: sellToken,
      tokenMetadata: tokenMetadata,
      totalNetworkFee: totalNetworkFee
    )
  }
}

extension ZeroXPriceResponseData {
  static func stub(
    rawResponse: ZeroXPriceRawResponse = .stub()
  ) -> Self {
    ZeroXPriceResponseData(rawResponse: rawResponse)
  }
}

extension ZeroXPriceResponse {
  static func stub(
    data: ZeroXPriceResponseData = .stub()
  ) -> Self {
    ZeroXPriceResponse(data: data)
  }
}
