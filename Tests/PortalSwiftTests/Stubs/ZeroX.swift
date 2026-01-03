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
    taker: String = "0x1234567890abcdef1234567890abcdef12345678",
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
      taker: taker,
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
    taker: String? = nil,
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
      taker: taker,
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

extension ZeroXSourcesData {
  static func stub(
    sources: [String] = ["Uniswap", "Sushiswap", "Curve", "Balancer"]
  ) -> Self {
    ZeroXSourcesData(sources: sources)
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
    simulationIncomplete: Bool = false,
    invalidSourcesPassed: [String] = []
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
    amount: String = "1000000000000000",
    token: String = "0x0000000000000000000000000000000000000000",
    type: String = "gas"
  ) -> Self {
    ZeroXFeeDetail(amount: amount, token: token, type: type)
  }
}

extension ZeroXZeroExFeeDetail {
  static func stub(
    billingType: String = "on-chain",
    feeAmount: String = "500000000000000",
    feeToken: String = "0x0000000000000000000000000000000000000000",
    feeType: String = "volume"
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

extension ZeroXQuoteData {
  static func stub(
    buyAmount: String = "3000000000",
    sellAmount: String = "1000000000000000000",
    price: String = "3000.00",
    estimatedGas: String = "150000",
    gasPrice: String = "50000000000",
    cost: Double = 7.50,
    liquidityAvailable: Bool = true,
    minBuyAmount: String = "2970000000",
    transaction: ZeroXTransaction = .stub(),
    issues: ZeroXIssues? = nil
  ) -> Self {
    ZeroXQuoteData(
      buyAmount: buyAmount,
      sellAmount: sellAmount,
      price: price,
      estimatedGas: estimatedGas,
      gasPrice: gasPrice,
      cost: cost,
      liquidityAvailable: liquidityAvailable,
      minBuyAmount: minBuyAmount,
      transaction: transaction,
      issues: issues
    )
  }
}

extension ZeroXQuoteResponseData {
  static func stub(
    quote: ZeroXQuoteData = .stub()
  ) -> Self {
    ZeroXQuoteResponseData(quote: quote)
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

extension ZeroXPriceData {
  static func stub(
    buyAmount: String = "3000000000",
    sellAmount: String = "1000000000000000000",
    price: String = "3000.00",
    estimatedGas: String = "150000",
    gasPrice: String = "50000000000",
    liquidityAvailable: Bool = true,
    minBuyAmount: String = "2970000000",
    fees: ZeroXFees? = .stub(),
    issues: ZeroXIssues? = nil
  ) -> Self {
    ZeroXPriceData(
      buyAmount: buyAmount,
      sellAmount: sellAmount,
      price: price,
      estimatedGas: estimatedGas,
      gasPrice: gasPrice,
      liquidityAvailable: liquidityAvailable,
      minBuyAmount: minBuyAmount,
      fees: fees,
      issues: issues
    )
  }
}

extension ZeroXPriceResponseData {
  static func stub(
    price: ZeroXPriceData = .stub()
  ) -> Self {
    ZeroXPriceResponseData(price: price)
  }
}

extension ZeroXPriceResponse {
  static func stub(
    data: ZeroXPriceResponseData = .stub()
  ) -> Self {
    ZeroXPriceResponse(data: data)
  }
}

