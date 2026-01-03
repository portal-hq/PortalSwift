//
//  ZeroXQuoteResponse.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2024 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// Response model containing a swap quote from ZeroX.
public struct ZeroXQuoteResponse: Codable {
  /// The response data containing the quote details.
  public let data: ZeroXQuoteResponseData

  public init(data: ZeroXQuoteResponseData) {
    self.data = data
  }
}

/// Data wrapper for the quote response.
public struct ZeroXQuoteResponseData: Codable {
  /// The quote details including transaction data.
  public let quote: ZeroXQuoteData

  public init(quote: ZeroXQuoteData) {
    self.quote = quote
  }
}

/// Detailed quote data from ZeroX including transaction information.
public struct ZeroXQuoteData: Codable {
  /// The amount of tokens to receive.
  public let buyAmount: String
  /// The amount of tokens to sell.
  public let sellAmount: String
  /// The exchange rate.
  public let price: String
  /// Estimated gas for the transaction.
  public let estimatedGas: String
  /// The gas price.
  public let gasPrice: String
  /// The total cost of the swap.
  public let cost: Double
  /// Whether liquidity is available for this swap.
  public let liquidityAvailable: Bool
  /// The minimum amount of tokens to receive after slippage.
  public let minBuyAmount: String
  /// The transaction data to submit.
  public let transaction: ZeroXTransaction
  /// Any issues with the quote (optional).
  public let issues: ZeroXIssues?

  public init(
    buyAmount: String,
    sellAmount: String,
    price: String,
    estimatedGas: String,
    gasPrice: String,
    cost: Double,
    liquidityAvailable: Bool,
    minBuyAmount: String,
    transaction: ZeroXTransaction,
    issues: ZeroXIssues? = nil
  ) {
    self.buyAmount = buyAmount
    self.sellAmount = sellAmount
    self.price = price
    self.estimatedGas = estimatedGas
    self.gasPrice = gasPrice
    self.cost = cost
    self.liquidityAvailable = liquidityAvailable
    self.minBuyAmount = minBuyAmount
    self.transaction = transaction
    self.issues = issues
  }
}

/// Transaction data from ZeroX quote.
public struct ZeroXTransaction: Codable {
  /// The transaction calldata.
  public let data: String
  /// The sender address.
  public let from: String
  /// The gas limit.
  public let gas: String
  /// The gas price.
  public let gasPrice: String
  /// The contract address to call.
  public let to: String
  /// The value to send
  public let value: String

  public init(
    data: String,
    from: String,
    gas: String,
    gasPrice: String,
    to: String,
    value: String
  ) {
    self.data = data
    self.from = from
    self.gas = gas
    self.gasPrice = gasPrice
    self.to = to
    self.value = value
  }
}

