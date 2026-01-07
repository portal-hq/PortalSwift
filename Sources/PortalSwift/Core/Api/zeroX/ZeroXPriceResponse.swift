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
  public let data: ZeroXPriceResponseData?
  /// Error message if the request failed.
  public let error: String?

  public init(data: ZeroXPriceResponseData? = nil, error: String? = nil) {
    self.data = data
    self.error = error
  }
}

/// Data wrapper for the price response.
public struct ZeroXPriceResponseData: Codable {
  /// The raw response from ZeroX containing price details.
  public let rawResponse: ZeroXPriceRawResponse

  public init(rawResponse: ZeroXPriceRawResponse) {
    self.rawResponse = rawResponse
  }
}

/// Raw response model from ZeroX containing detailed price information.
public struct ZeroXPriceRawResponse: Codable {
  /// The block number at which the price was generated (optional).
  public let blockNumber: String?
  /// The amount of tokens to receive.
  public let buyAmount: String
  /// The token address to buy.
  public let buyToken: String?
  /// Fee breakdown (optional).
  public let fees: ZeroXFees?
  /// The gas limit for the transaction (optional).
  public let gas: String?
  /// The gas price (optional).
  public let gasPrice: String?
  /// Any issues with the price quote (optional).
  public let issues: ZeroXIssues?
  /// Whether liquidity is available for this swap (optional).
  public let liquidityAvailable: Bool?
  /// The minimum amount of tokens to receive after slippage (optional).
  public let minBuyAmount: String?
  /// Route information for the swap (optional).
  public let route: ZeroXRoute?
  /// The amount of tokens to sell.
  public let sellAmount: String
  /// The token address to sell.
  public let sellToken: String?
  /// Token metadata including tax information (optional).
  public let tokenMetadata: ZeroXTokenMetadata?
  /// Total network fee for the transaction (optional).
  public let totalNetworkFee: String?

  public init(
    blockNumber: String? = nil,
    buyAmount: String,
    buyToken: String? = nil,
    fees: ZeroXFees? = nil,
    gas: String? = nil,
    gasPrice: String? = nil,
    issues: ZeroXIssues? = nil,
    liquidityAvailable: Bool? = nil,
    minBuyAmount: String? = nil,
    route: ZeroXRoute? = nil,
    sellAmount: String,
    sellToken: String? = nil,
    tokenMetadata: ZeroXTokenMetadata? = nil,
    totalNetworkFee: String? = nil
  ) {
    self.blockNumber = blockNumber
    self.buyAmount = buyAmount
    self.buyToken = buyToken
    self.fees = fees
    self.gas = gas
    self.gasPrice = gasPrice
    self.issues = issues
    self.liquidityAvailable = liquidityAvailable
    self.minBuyAmount = minBuyAmount
    self.route = route
    self.sellAmount = sellAmount
    self.sellToken = sellToken
    self.tokenMetadata = tokenMetadata
    self.totalNetworkFee = totalNetworkFee
  }
}

