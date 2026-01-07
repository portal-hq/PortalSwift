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
  public let data: ZeroXQuoteResponseData?
  /// Error message if the request failed.
  public let error: String?

  public init(data: ZeroXQuoteResponseData? = nil, error: String? = nil) {
    self.data = data
    self.error = error
  }
}

/// Data wrapper for the quote response.
public struct ZeroXQuoteResponseData: Codable {
  /// The raw response from ZeroX containing quote details.
  public let rawResponse: ZeroXQuoteRawResponse

  public init(rawResponse: ZeroXQuoteRawResponse) {
    self.rawResponse = rawResponse
  }
}

/// Raw response model from ZeroX containing detailed quote information.
public struct ZeroXQuoteRawResponse: Codable {
  /// The block number at which the quote was generated (optional).
  public let blockNumber: String?
  /// The amount of tokens to receive.
  public let buyAmount: String
  /// The token address to buy.
  public let buyToken: String?
  /// Fee breakdown (optional).
  public let fees: ZeroXFees?
  /// Any issues with the quote (optional).
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
  /// The transaction data to submit.
  public let transaction: ZeroXTransaction

  public init(
    blockNumber: String? = nil,
    buyAmount: String,
    buyToken: String? = nil,
    fees: ZeroXFees? = nil,
    issues: ZeroXIssues? = nil,
    liquidityAvailable: Bool? = nil,
    minBuyAmount: String? = nil,
    route: ZeroXRoute? = nil,
    sellAmount: String,
    sellToken: String? = nil,
    tokenMetadata: ZeroXTokenMetadata? = nil,
    totalNetworkFee: String? = nil,
    transaction: ZeroXTransaction
  ) {
    self.blockNumber = blockNumber
    self.buyAmount = buyAmount
    self.buyToken = buyToken
    self.fees = fees
    self.issues = issues
    self.liquidityAvailable = liquidityAvailable
    self.minBuyAmount = minBuyAmount
    self.route = route
    self.sellAmount = sellAmount
    self.sellToken = sellToken
    self.tokenMetadata = tokenMetadata
    self.totalNetworkFee = totalNetworkFee
    self.transaction = transaction
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

