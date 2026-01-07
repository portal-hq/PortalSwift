//
//  PortalZeroXTradingApi.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2024 Portal Labs, Inc. All rights reserved.
//

import AnyCodable
import Foundation

/// Protocol for ZeroX Trading API interactions.
public protocol PortalZeroXTradingApiProtocol: AnyObject {
  /// Retrieves available swap sources for a chain.
  /// - Parameters:
  ///   - chainId: The chain ID (e.g., "eip155:1")
  ///   - zeroXApiKey: Optional ZeroX API key to override the one configured in Portal Dashboard. If `nil`, the SDK will use the API key configured in the Portal Dashboard. This parameter allows you to override the Dashboard configuration on a per-request basis. The API key is used to authenticate requests to the ZeroX API service.
  /// - Returns: Response containing available swap sources
  func getSources(chainId: String, zeroXApiKey: String?) async throws -> ZeroXSourcesResponse
  
  /// Retrieves a swap quote with transaction data.
  /// - Parameters:
  ///   - request: The quote request parameters
  ///   - zeroXApiKey: Optional ZeroX API key to override the one configured in Portal Dashboard. If `nil`, the SDK will use the API key configured in the Portal Dashboard. This parameter allows you to override the Dashboard configuration on a per-request basis. The API key is used to authenticate requests to the ZeroX API service.
  /// - Returns: Response containing the quote with transaction data
  func getQuote(request: ZeroXQuoteRequest, zeroXApiKey: String?) async throws -> ZeroXQuoteResponse
  
  /// Retrieves a price quote without transaction data.
  /// - Parameters:
  ///   - request: The price request parameters
  ///   - zeroXApiKey: Optional ZeroX API key to override the one configured in Portal Dashboard. If `nil`, the SDK will use the API key configured in the Portal Dashboard. This parameter allows you to override the Dashboard configuration on a per-request basis. The API key is used to authenticate requests to the ZeroX API service.
  /// - Returns: Response containing the price data
  func getPrice(request: ZeroXPriceRequest, zeroXApiKey: String?) async throws -> ZeroXPriceResponse
}

/// API class specifically for ZeroX Trading integration functionality.
public class PortalZeroXTradingApi: PortalZeroXTradingApiProtocol {
  private let apiKey: String
  private let baseUrl: String
  private let requests: PortalRequestsProtocol
  private let logger = PortalLogger()

  /// Create an instance of PortalZeroXTradingApi.
  /// - Parameters:
  ///   - apiKey: The Client API key.
  ///   - apiHost: The Portal API hostname.
  ///   - requests: An instance of PortalRequestsProtocol to handle HTTP requests.
  public init(
    apiKey: String,
    apiHost: String = "api.portalhq.io",
    requests: PortalRequestsProtocol? = nil
  ) {
    self.apiKey = apiKey
    self.baseUrl = apiHost.starts(with: "localhost") ? "http://\(apiHost)" : "https://\(apiHost)"
    self.requests = requests ?? PortalRequests()
  }

  /*******************************************
   * Public functions
   *******************************************/

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
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/0x/swap/sources") else {
      logger.error("PortalZeroXTradingApi.getSources() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      // Build request body with chainId and zeroXApiKey if provided
      var body: [String: AnyCodable] = [
        "chainId": AnyCodable(chainId)
      ]
      if let zeroXApiKey = zeroXApiKey {
        body["zeroXApiKey"] = AnyCodable(zeroXApiKey)
      }

      return try await post(url, withBearerToken: apiKey, andPayload: body, mappingInResponse: ZeroXSourcesResponse.self)
    } catch {
      logger.error("PortalZeroXTradingApi.getSources() - Error: \(error.localizedDescription)")
      throw error
    }
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
  ///     - Note: The `chainId` in the request is included in the request body.
  ///   - zeroXApiKey: Optional ZeroX API key to override the one configured in Portal Dashboard.
  ///     - If `nil`: The SDK will use the API key configured in the Portal Dashboard.
  ///     - If provided: This API key will be used for this request, overriding the Dashboard configuration.
  ///     - The API key is used to authenticate requests to the ZeroX API service and is included in the request body.
  /// - Returns: Response containing the quote with transaction data, including buy/sell amounts, price, gas estimates, and a ready-to-submit transaction object.
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func getQuote(request: ZeroXQuoteRequest, zeroXApiKey: String? = nil) async throws -> ZeroXQuoteResponse {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/0x/swap/quote") else {
      logger.error("PortalZeroXTradingApi.getQuote() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      // Build request body including chainId
      var body = request.toRequestBody()
      body["chainId"] = AnyCodable(request.chainId)

      // Merge zeroXApiKey if provided
      if let zeroXApiKey = zeroXApiKey {
        body["zeroXApiKey"] = AnyCodable(zeroXApiKey)
      }

      return try await post(url, withBearerToken: apiKey, andPayload: body, mappingInResponse: ZeroXQuoteResponse.self)
    } catch {
      logger.error("PortalZeroXTradingApi.getQuote() - Error: \(error.localizedDescription)")
      throw error
    }
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
  ///     - Note: The `chainId` in the request is included in the request body.
  ///   - zeroXApiKey: Optional ZeroX API key to override the one configured in Portal Dashboard.
  ///     - If `nil`: The SDK will use the API key configured in the Portal Dashboard.
  ///     - If provided: This API key will be used for this request, overriding the Dashboard configuration.
  ///     - The API key is used to authenticate requests to the ZeroX API service and is included in the request body.
  /// - Returns: Response containing the price data, including buy/sell amounts, price, gas estimates, fees breakdown, and liquidity availability.
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func getPrice(request: ZeroXPriceRequest, zeroXApiKey: String? = nil) async throws -> ZeroXPriceResponse {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/0x/swap/price") else {
      logger.error("PortalZeroXTradingApi.getPrice() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      // Build request body including chainId
      var body = request.toRequestBody()
      body["chainId"] = AnyCodable(request.chainId)

      // Merge zeroXApiKey if provided
      if let zeroXApiKey = zeroXApiKey {
        body["zeroXApiKey"] = AnyCodable(zeroXApiKey)
      }

      return try await post(url, withBearerToken: apiKey, andPayload: body, mappingInResponse: ZeroXPriceResponse.self)
    } catch {
      logger.error("PortalZeroXTradingApi.getPrice() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /*******************************************
   * Private functions
   *******************************************/

  /// URL-encodes the chainId for use in URL paths.
  private func encodeChainId(_ chainId: String) -> String {
    return chainId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? chainId
  }

  @discardableResult
  private func post<ResponseType>(
    _ url: URL,
    withBearerToken: String? = nil,
    andPayload: [String: AnyCodable]? = nil,
    mappingInResponse: ResponseType.Type
  ) async throws -> ResponseType where ResponseType: Decodable {
    let portalRequest = PortalAPIRequest(url: url, method: .post, payload: andPayload, bearerToken: withBearerToken)
    return try await requests.execute(request: portalRequest, mappingInResponse: mappingInResponse.self)
  }
}

