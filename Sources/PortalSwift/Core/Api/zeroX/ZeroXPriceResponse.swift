//
//  ZeroXPriceResponse.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2024 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// Response model containing a price quote from ZeroX (without transaction data).
public struct ZeroXPriceResponse: Codable {
  /// The response data containing the price details.
  public let data: ZeroXPriceResponseData

  public init(data: ZeroXPriceResponseData) {
    self.data = data
  }
}

/// Data wrapper for the price response.
public struct ZeroXPriceResponseData: Codable {
  /// The price details.
  public let price: ZeroXPriceData

  public init(price: ZeroXPriceData) {
    self.price = price
  }
}

/// Detailed price data from ZeroX (without transaction information).
public struct ZeroXPriceData: Codable {
  /// The amount of tokens to receive.
  public let buyAmount: String
  /// The amount of tokens to sell.
  public let sellAmount: String
  /// The exchange rate (optional - may not be present in all responses).
  public let price: String?
  /// Estimated gas for the transaction (optional).
  public let estimatedGas: String?
  /// The gas price (optional).
  public let gasPrice: String?
  /// Whether liquidity is available for this swap (optional).
  public let liquidityAvailable: Bool?
  /// The minimum amount of tokens to receive after slippage (optional).
  public let minBuyAmount: String?
  /// Fee breakdown (optional).
  public let fees: ZeroXFees?
  /// Any issues with the price (optional).
  public let issues: ZeroXIssues?

  public init(
    buyAmount: String,
    sellAmount: String,
    price: String? = nil,
    estimatedGas: String? = nil,
    gasPrice: String? = nil,
    liquidityAvailable: Bool? = nil,
    minBuyAmount: String? = nil,
    fees: ZeroXFees? = nil,
    issues: ZeroXIssues? = nil
  ) {
    self.buyAmount = buyAmount
    self.sellAmount = sellAmount
    self.price = price
    self.estimatedGas = estimatedGas
    self.gasPrice = gasPrice
    self.liquidityAvailable = liquidityAvailable
    self.minBuyAmount = minBuyAmount
    self.fees = fees
    self.issues = issues
  }
}

