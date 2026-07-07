//
//  ZeroXTradeAsset.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2025 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// Parameters for the high-level `tradeAsset` swap method.
///
/// Mirrors the fields of `ZeroXQuoteRequest` (used internally to fetch a quote) and adds
/// optional `fromAddress` and `zeroXApiKey` overrides.
public struct ZeroXTradeAssetParams {
  /// The chain ID for the swap (e.g., "eip155:1").
  public let chainId: String
  /// The token to buy.
  public let buyToken: String
  /// The token to sell.
  public let sellToken: String
  /// The amount to sell in base units.
  public let sellAmount: String
  /// The transaction origin address (optional).
  public let txOrigin: String?
  /// The swap fee recipient address (optional).
  public let swapFeeRecipient: String?
  /// The swap fee in basis points (optional).
  public let swapFeeBps: Int?
  /// The swap fee token (optional).
  public let swapFeeToken: String?
  /// The trade surplus recipient address (optional).
  public let tradeSurplusRecipient: String?
  /// The gas price (optional).
  public let gasPrice: String?
  /// The slippage tolerance in basis points (optional).
  public let slippageBps: Int?
  /// Comma-separated list of sources to exclude (optional).
  public let excludedSources: String?
  /// Whether to sell the entire balance (optional).
  public let sellEntireBalance: Bool?
  /// Sender address of the swap transaction (optional). Mirrors LiFi's `fromAddress` naming.
  public let fromAddress: String?
  /// Optional 0x API key to override the one configured in Portal Dashboard.
  public let zeroXApiKey: String?

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
    sellEntireBalance: Bool? = nil,
    fromAddress: String? = nil,
    zeroXApiKey: String? = nil
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
    self.fromAddress = fromAddress
    self.zeroXApiKey = zeroXApiKey
  }

  /// Builds the `ZeroXQuoteRequest` used internally to fetch the swap quote.
  func toQuoteRequest() -> ZeroXQuoteRequest {
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

/// Progress status emitted during a `tradeAsset` execution.
public enum ZeroXTradeAssetProgressStatus: String {
  case fetchingQuote = "fetching_quote"
  case signing
  case submitted
  case confirming
  case confirmed
  case failed
}

/// Progress payload emitted alongside a `ZeroXTradeAssetProgressStatus`.
public struct ZeroXTradeAssetProgressData {
  /// The transaction hash once submitted (optional).
  public let txHash: String?
  /// An error message when the status is `failed` (optional).
  public let errorMessage: String?
  /// The buy amount from the quote (optional).
  public let buyAmount: String?
  /// The sell amount from the quote (optional).
  public let sellAmount: String?
  /// The transaction object from the quote (optional).
  public let transaction: ZeroXTransaction?

  public init(
    txHash: String? = nil,
    errorMessage: String? = nil,
    buyAmount: String? = nil,
    sellAmount: String? = nil,
    transaction: ZeroXTransaction? = nil
  ) {
    self.txHash = txHash
    self.errorMessage = errorMessage
    self.buyAmount = buyAmount
    self.sellAmount = sellAmount
    self.transaction = transaction
  }
}

/// Result returned by `tradeAsset`. For same-chain 0x swaps `hashes` contains a single element.
public struct ZeroXTradeAssetResult {
  /// The transaction hashes produced by the swap.
  public let hashes: [String]

  public init(hashes: [String]) {
    self.hashes = hashes
  }
}

/// Errors thrown by the `tradeAsset` flow.
public enum ZeroXTradeAssetError: LocalizedError, Equatable {
  case portalNotInitialized
  case quoteError(String)
  case missingQuoteData
  case missingTransaction
  case invalidTransactionHash
  case confirmationFailed(String)

  public var errorDescription: String? {
    switch self {
    case .portalNotInitialized:
      return "Portal instance is not available for signing or sending the swap transaction."
    case let .quoteError(message):
      return "Quote error: \(message)"
    case .missingQuoteData:
      return "Quote response missing data.rawResponse."
    case .missingTransaction:
      return "Quote response missing a valid transaction (expected non-empty \"to\")."
    case .invalidTransactionHash:
      return "Signing returned an empty or invalid transaction hash."
    case let .confirmationFailed(message):
      return message
    }
  }
}
