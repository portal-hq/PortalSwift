//
//  ZeroX.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2024 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// Protocol defining the interface for ZeroX trading provider functionality.
public protocol ZeroXProtocol {
  /// Retrieves available swap sources for a chain.
  /// - Parameters:
  ///   - chainId: The chain ID (e.g., "eip155:1")
  ///   - zeroXApiKey: Optional ZeroX API key to override the one configured in Portal Dashboard. If `nil`, the SDK will use the API key configured in the Portal Dashboard.
  /// - Returns: Response containing available swap sources
  func getSources(chainId: String, zeroXApiKey: String?) async throws -> ZeroXSourcesResponse
  
  /// Retrieves a swap quote with transaction data.
  /// - Parameters:
  ///   - request: The quote request parameters
  ///   - zeroXApiKey: Optional ZeroX API key to override the one configured in Portal Dashboard. If `nil`, the SDK will use the API key configured in the Portal Dashboard.
  /// - Returns: Response containing the quote with transaction data
  func getQuote(request: ZeroXQuoteRequest, zeroXApiKey: String?) async throws -> ZeroXQuoteResponse
  
  /// Retrieves a price quote without transaction data.
  /// - Parameters:
  ///   - request: The price request parameters
  ///   - zeroXApiKey: Optional ZeroX API key to override the one configured in Portal Dashboard. If `nil`, the SDK will use the API key configured in the Portal Dashboard.
  /// - Returns: Response containing the price data
  func getPrice(request: ZeroXPriceRequest, zeroXApiKey: String?) async throws -> ZeroXPriceResponse
}

/// ZeroX provider implementation for trading functionality.
public class ZeroX: ZeroXProtocol {
  private let api: PortalZeroXTradingApiProtocol

  /// Create an instance of ZeroX.
  /// - Parameter api: The PortalZeroXTradingApi instance to use for trading operations.
  public init(api: PortalZeroXTradingApiProtocol) {
    self.api = api
  }

  /// Retrieves available swap sources for a chain.
  ///
  /// This method fetches the list of available swap sources (e.g., Uniswap, Sushiswap, Curve) for the specified chain.
  /// The ZeroX API key can be configured in two ways:
  /// 1. **Portal Dashboard** (Recommended): Configure your ZeroX API key in the Portal Dashboard. The SDK will use it automatically when `zeroXApiKey` is `nil`.
  /// 2. **Per-Request Override**: Provide the API key in the `zeroXApiKey` parameter to override the Dashboard configuration for this specific request.
  ///
  /// - Parameters:
  ///   - chainId: The chain ID in the format "eip155:{chainId}" (e.g., "eip155:1" for Ethereum mainnet, "eip155:137" for Polygon).
  ///   - zeroXApiKey: Optional ZeroX API key to override the one configured in Portal Dashboard.
  ///     - If `nil`: The SDK will use the API key configured in the Portal Dashboard.
  ///     - If provided: This API key will be used for this request, overriding the Dashboard configuration.
  ///     - The API key is used to authenticate requests to the ZeroX API service and is included in the request body.
  /// - Returns: Response containing available swap sources as an array of source names (e.g., ["Uniswap", "Sushiswap", "Curve"]).
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func getSources(chainId: String, zeroXApiKey: String? = nil) async throws -> ZeroXSourcesResponse {
    return try await api.getSources(chainId: chainId, zeroXApiKey: zeroXApiKey)
  }

  /// Retrieves a swap quote with transaction data.
  ///
  /// This method fetches a swap quote that includes transaction data ready to be submitted to the blockchain.
  /// The quote includes the transaction object with all necessary fields (to, from, data, gas, etc.) that can be directly
  /// used with `portal.request()` to execute the swap.
  ///
  /// The ZeroX API key can be configured in two ways:
  /// 1. **Portal Dashboard** (Recommended): Configure your ZeroX API key in the Portal Dashboard. The SDK will use it automatically when `zeroXApiKey` is `nil`.
  /// 2. **Per-Request Override**: Provide the API key in the `zeroXApiKey` parameter to override the Dashboard configuration for this specific request.
  ///
  /// - Parameters:
  ///   - request: The quote request parameters containing chain ID, tokens, amounts, and optional swap configuration.
  ///     - Note: The `chainId` in the request is used for the URL path only and is excluded from the request body.
  ///   - zeroXApiKey: Optional ZeroX API key to override the one configured in Portal Dashboard.
  ///     - If `nil`: The SDK will use the API key configured in the Portal Dashboard.
  ///     - If provided: This API key will be used for this request, overriding the Dashboard configuration.
  ///     - The API key is used to authenticate requests to the ZeroX API service and is included in the request body.
  /// - Returns: Response containing the quote with transaction data, including buy/sell amounts, price, gas estimates, and a ready-to-submit transaction object.
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func getQuote(request: ZeroXQuoteRequest, zeroXApiKey: String? = nil) async throws -> ZeroXQuoteResponse {
    return try await api.getQuote(request: request, zeroXApiKey: zeroXApiKey)
  }

  /// Retrieves a price quote without transaction data.
  ///
  /// This method fetches a price quote for a swap without generating transaction data. This is useful for:
  /// - Checking swap prices before committing to a transaction
  /// - Displaying price information to users
  /// - Comparing prices across different swap sources
  ///
  /// Unlike `getQuote()`, this method does not return transaction data.
  /// The response includes price information, fees breakdown, and liquidity availability.
  ///
  /// The ZeroX API key can be configured in two ways:
  /// 1. **Portal Dashboard** (Recommended): Configure your ZeroX API key in the Portal Dashboard. The SDK will use it automatically when `zeroXApiKey` is `nil`.
  /// 2. **Per-Request Override**: Provide the API key in the `zeroXApiKey` parameter to override the Dashboard configuration for this specific request.
  ///
  /// - Parameters:
  ///   - request: The price request parameters containing chain ID, tokens, amounts, and optional swap configuration.
  ///     - Note: The `chainId` in the request is used for the URL path only and is excluded from the request body.
  ///   - zeroXApiKey: Optional ZeroX API key to override the one configured in Portal Dashboard.
  ///     - If `nil`: The SDK will use the API key configured in the Portal Dashboard.
  ///     - If provided: This API key will be used for this request, overriding the Dashboard configuration.
  ///     - The API key is used to authenticate requests to the ZeroX API service and is included in the request body.
  /// - Returns: Response containing the price data, including buy/sell amounts, price, gas estimates, fees breakdown, and liquidity availability.
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func getPrice(request: ZeroXPriceRequest, zeroXApiKey: String? = nil) async throws -> ZeroXPriceResponse {
    return try await api.getPrice(request: request, zeroXApiKey: zeroXApiKey)
  }
}

