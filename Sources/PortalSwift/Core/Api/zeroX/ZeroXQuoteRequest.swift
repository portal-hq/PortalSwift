//
//  ZeroXQuoteRequest.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2024 Portal Labs, Inc. All rights reserved.
//

import AnyCodable
import Foundation

/// Request model for getting a swap quote from ZeroX.
/// Note: `chainId` is used for the URL path only, not included in the request body.
public struct ZeroXQuoteRequest: Codable {
  /// The chain ID for the swap (used in URL path, e.g., "eip155:1")
  public let chainId: String
  /// The token to buy
  public let buyToken: String
  /// The token to sell
  public let sellToken: String
  /// The amount to sell in base units
  public let sellAmount: String
  /// The transaction origin address (optional)
  public let txOrigin: String?
  /// The swap fee recipient address (optional)
  public let swapFeeRecipient: String?
  /// The swap fee in basis points (optional)
  public let swapFeeBps: Int?
  /// The swap fee token (optional)
  public let swapFeeToken: String?
  /// The trade surplus recipient address (optional)
  public let tradeSurplusRecipient: String?
  /// The gas price (optional)
  public let gasPrice: String?
  /// The slippage tolerance in basis points (optional)
  public let slippageBps: Int?
  /// Comma-separated list of sources to exclude (optional)
  public let excludedSources: String?
  /// Whether to sell the entire balance (optional)
  public let sellEntireBalance: Bool?

  public init(
    chainId: String,
    buyToken: String,
    sellToken: String,
    sellAmount: String,
    txOrigin: String? = nil,
    swapFeeRecipient: String? = nil,
    swapFeeBps: Int? = nil,
    swapFeeToken: String? = nil,
    tradeSurplusRecipient: String? = nil,
    gasPrice: String? = nil,
    slippageBps: Int? = nil,
    excludedSources: String? = nil,
    sellEntireBalance: Bool? = nil
  ) {
    self.chainId = chainId
    self.buyToken = buyToken
    self.sellToken = sellToken
    self.sellAmount = sellAmount
    self.txOrigin = txOrigin
    self.swapFeeRecipient = swapFeeRecipient
    self.swapFeeBps = swapFeeBps
    self.swapFeeToken = swapFeeToken
    self.tradeSurplusRecipient = tradeSurplusRecipient
    self.gasPrice = gasPrice
    self.slippageBps = slippageBps
    self.excludedSources = excludedSources
    self.sellEntireBalance = sellEntireBalance
  }

  /// Converts the request to a dictionary for the request body, excluding `chainId`.
  public func toRequestBody() -> [String: AnyCodable] {
    var body: [String: AnyCodable] = [
      "buyToken": AnyCodable(buyToken),
      "sellToken": AnyCodable(sellToken),
      "sellAmount": AnyCodable(sellAmount)
    ]

    if let txOrigin = txOrigin { body["txOrigin"] = AnyCodable(txOrigin) }
    if let swapFeeRecipient = swapFeeRecipient { body["swapFeeRecipient"] = AnyCodable(swapFeeRecipient) }
    if let swapFeeBps = swapFeeBps { body["swapFeeBps"] = AnyCodable(swapFeeBps) }
    if let swapFeeToken = swapFeeToken { body["swapFeeToken"] = AnyCodable(swapFeeToken) }
    if let tradeSurplusRecipient = tradeSurplusRecipient { body["tradeSurplusRecipient"] = AnyCodable(tradeSurplusRecipient) }
    if let gasPrice = gasPrice { body["gasPrice"] = AnyCodable(gasPrice) }
    if let slippageBps = slippageBps { body["slippageBps"] = AnyCodable(slippageBps) }
    if let excludedSources = excludedSources { body["excludedSources"] = AnyCodable(excludedSources) }
    if let sellEntireBalance = sellEntireBalance { body["sellEntireBalance"] = AnyCodable(sellEntireBalance ? "true" : "false") }

    return body
  }
}

