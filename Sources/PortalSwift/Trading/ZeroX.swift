//
//  ZeroX.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2024 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// Minimal protocol for the Portal capability required by `ZeroX.tradeAsset` (request).
/// Portal conforms to this protocol; tests can use a small mock.
public protocol ZeroXPortalDependency: AnyObject {
  func request(chainId: String, method: PortalRequestMethod, params: [Any], options: RequestOptions?) async throws -> PortalProviderResult
}

/// Protocol defining the interface for 0x trading provider functionality.
public protocol ZeroXProtocol {
  /// Retrieves available swap sources for a chain.
  /// - Parameters:
  ///   - chainId: The chain ID (e.g., "eip155:1")
  ///   - zeroXApiKey: Optional 0x API key to override the one configured in Portal Dashboard. If `nil`, the SDK will use the API key configured in the Portal Dashboard.
  /// - Returns: Response containing available swap sources
  func getSources(chainId: String, zeroXApiKey: String?) async throws -> ZeroXSourcesResponse

  /// Retrieves a swap quote with transaction data.
  /// - Parameters:
  ///   - request: The quote request parameters
  ///   - zeroXApiKey: Optional 0x API key to override the one configured in Portal Dashboard. If `nil`, the SDK will use the API key configured in the Portal Dashboard.
  /// - Returns: Response containing the quote with transaction data
  func getQuote(request: ZeroXQuoteRequest, zeroXApiKey: String?) async throws -> ZeroXQuoteResponse

  /// Retrieves a price quote without transaction data.
  /// - Parameters:
  ///   - request: The price request parameters
  ///   - zeroXApiKey: Optional 0x API key to override the one configured in Portal Dashboard. If `nil`, the SDK will use the API key configured in the Portal Dashboard.
  /// - Returns: Response containing the price data
  func getPrice(request: ZeroXPriceRequest, zeroXApiKey: String?) async throws -> ZeroXPriceResponse

  /// Fetches a 0x quote and executes the returned transaction: sign, broadcast, and wait for the
  /// on-chain receipt before resolving.
  /// - Parameters:
  ///   - params: The swap parameters (chain, tokens, amount, and optional overrides).
  ///   - onProgress: Optional callback invoked with status updates throughout the flow.
  /// - Returns: A result containing the transaction hash(es). For same-chain swaps this is a single hash.
  func tradeAsset(
    params: ZeroXTradeAssetParams,
    onProgress: ((ZeroXTradeAssetProgressStatus, ZeroXTradeAssetProgressData) -> Void)?
  ) async throws -> ZeroXTradeAssetResult
}

// MARK: - Protocol Extension for Default Parameters

public extension ZeroXProtocol {
  /// Retrieves available swap sources for a chain using the API key configured in Portal Dashboard.
  ///
  /// This is a convenience method that allows you to fetch swap sources without explicitly passing the `zeroXApiKey` parameter.
  /// It automatically uses the 0x API key configured in your Portal Dashboard settings.
  ///
  /// This method fetches the list of available swap sources (e.g., Uniswap, Sushiswap, Curve) for the specified chain.
  /// The sources represent the different DEX aggregators and liquidity pools that 0x can route swaps through.
  ///
  /// **API Key Configuration:**
  /// This method uses the 0x API key configured in the Portal Dashboard. If you need to override the Dashboard
  /// configuration for a specific request, use `getSources(chainId:zeroXApiKey:)` instead.
  ///
  /// - Parameter chainId: The chain ID in the format "eip155:{chainId}" (e.g., "eip155:1" for Ethereum mainnet, "eip155:137" for Polygon).
  /// - Returns: Response containing available swap sources as an array of source names (e.g., ["Uniswap", "Sushiswap", "Curve"]).
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  ///
  /// - Note: This method is equivalent to calling `getSources(chainId:zeroXApiKey:)` with `zeroXApiKey: nil`.
  ///
  /// - SeeAlso: `getSources(chainId:zeroXApiKey:)` for the version that allows API key override.
  func getSources(chainId: String) async throws -> ZeroXSourcesResponse {
    return try await getSources(chainId: chainId, zeroXApiKey: nil)
  }

  /// Retrieves a swap quote with transaction data using the API key configured in Portal Dashboard.
  ///
  /// This is a convenience method that allows you to fetch a swap quote without explicitly passing the `zeroXApiKey` parameter.
  /// It automatically uses the 0x API key configured in your Portal Dashboard settings.
  ///
  /// This method fetches a swap quote that includes transaction data ready to be submitted to the blockchain.
  /// The quote includes the transaction object with all necessary fields (to, from, data, gas, etc.) that can be directly
  /// used with `portal.request()` to execute the swap.
  ///
  /// **API Key Configuration:**
  /// This method uses the 0x API key configured in the Portal Dashboard. If you need to override the Dashboard
  /// configuration for a specific request, use `getQuote(request:zeroXApiKey:)` instead.
  ///
  /// - Parameter request: The quote request parameters containing chain ID, tokens, amounts, and optional swap configuration.
  ///   - Note: The `chainId` in the request is used for the URL path only and is excluded from the request body.
  /// - Returns: Response containing the quote with transaction data, including buy/sell amounts, price, gas estimates, and a ready-to-submit transaction object.
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  ///
  /// - Note: This method is equivalent to calling `getQuote(request:zeroXApiKey:)` with `zeroXApiKey: nil`.
  ///
  /// - SeeAlso: `getQuote(request:zeroXApiKey:)` for the version that allows API key override.
  func getQuote(request: ZeroXQuoteRequest) async throws -> ZeroXQuoteResponse {
    return try await getQuote(request: request, zeroXApiKey: nil)
  }

  /// Retrieves a price quote without transaction data using the API key configured in Portal Dashboard.
  ///
  /// This is a convenience method that allows you to fetch a price quote without explicitly passing the `zeroXApiKey` parameter.
  /// It automatically uses the 0x API key configured in your Portal Dashboard settings.
  ///
  /// This method fetches a price quote for a swap without generating transaction data. This is useful for:
  /// - Checking swap prices before committing to a transaction
  /// - Displaying price information to users
  /// - Comparing prices across different swap sources
  ///
  /// Unlike `getQuote()`, this method does not return transaction data.
  /// The response includes price information, fees breakdown, and liquidity availability.
  ///
  /// **API Key Configuration:**
  /// This method uses the 0x API key configured in the Portal Dashboard. If you need to override the Dashboard
  /// configuration for a specific request, use `getPrice(request:zeroXApiKey:)` instead.
  ///
  /// - Parameter request: The price request parameters containing chain ID, tokens, amounts, and optional swap configuration.
  ///   - Note: The `chainId` in the request is used for the URL path only and is excluded from the request body.
  /// - Returns: Response containing the price data, including buy/sell amounts, price, gas estimates, fees breakdown, and liquidity availability.
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  ///
  /// - Note: This method is equivalent to calling `getPrice(request:zeroXApiKey:)` with `zeroXApiKey: nil`.
  ///
  /// - SeeAlso: `getPrice(request:zeroXApiKey:)` for the version that allows API key override.
  func getPrice(request: ZeroXPriceRequest) async throws -> ZeroXPriceResponse {
    return try await getPrice(request: request, zeroXApiKey: nil)
  }

  /// Fetches a 0x quote and executes the returned transaction without a progress callback.
  ///
  /// This is a convenience method equivalent to calling `tradeAsset(params:onProgress:)` with `onProgress: nil`.
  ///
  /// - Parameter params: The swap parameters (chain, tokens, amount, and optional overrides).
  /// - Returns: A result containing the transaction hash(es). For same-chain swaps this is a single hash.
  func tradeAsset(params: ZeroXTradeAssetParams) async throws -> ZeroXTradeAssetResult {
    return try await tradeAsset(params: params, onProgress: nil)
  }
}

/// 0x provider implementation for trading functionality.
public class ZeroX: ZeroXProtocol {
  private let api: PortalZeroXTradingApiProtocol
  private weak var portal: ZeroXPortalDependency?

  /// Poll interval (in nanoseconds) used while waiting for on-chain confirmation. Defaults to 4 seconds.
  /// Exposed as `internal` so tests can reduce the interval; production uses the default.
  var confirmationPollIntervalNanoseconds: UInt64 = 4_000_000_000
  /// Maximum number of polling attempts (~15 minutes at a 4s interval).
  /// Exposed as `internal` so tests can reduce the attempt count; production uses the default.
  var confirmationMaxAttempts: Int = 225

  /// Create an instance of ZeroX.
  /// - Parameters:
  ///   - api: The PortalZeroXTradingApi instance to use for trading operations.
  ///   - portal: The portal (or mock) providing `request` for signing and confirmation (can be `nil`, e.g. in tests).
  public init(api: PortalZeroXTradingApiProtocol, portal: ZeroXPortalDependency? = nil) {
    self.api = api
    self.portal = portal
  }

  /// Sets the portal dependency used by `tradeAsset` for signing and confirmation.
  /// - Parameter portal: The portal (or mock) providing `request`.
  public func setPortal(_ portal: ZeroXPortalDependency?) {
    self.portal = portal
  }

  /// Retrieves available swap sources for a chain.
  ///
  /// This method fetches the list of available swap sources (e.g., Uniswap, Sushiswap, Curve) for the specified chain.
  /// The 0x API key can be configured in two ways:
  /// 1. **Portal Dashboard** (Recommended): Configure your 0x API key in the Portal Dashboard. The SDK will use it automatically when `zeroXApiKey` is `nil`.
  /// 2. **Per-Request Override**: Provide the API key in the `zeroXApiKey` parameter to override the Dashboard configuration for this specific request.
  ///
  /// - Parameters:
  ///   - chainId: The chain ID in the format "eip155:{chainId}" (e.g., "eip155:1" for Ethereum mainnet, "eip155:137" for Polygon).
  ///   - zeroXApiKey: Optional 0x API key to override the one configured in Portal Dashboard.
  ///     - If `nil`: The SDK will use the API key configured in the Portal Dashboard.
  ///     - If provided: This API key will be used for this request, overriding the Dashboard configuration.
  ///     - The API key is used to authenticate requests to the 0x API service and is included in the request body.
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
  /// The 0x API key can be configured in two ways:
  /// 1. **Portal Dashboard** (Recommended): Configure your 0x API key in the Portal Dashboard. The SDK will use it automatically when `zeroXApiKey` is `nil`.
  /// 2. **Per-Request Override**: Provide the API key in the `zeroXApiKey` parameter to override the Dashboard configuration for this specific request.
  ///
  /// - Parameters:
  ///   - request: The quote request parameters containing chain ID, tokens, amounts, and optional swap configuration.
  ///     - Note: The `chainId` in the request is used for the URL path only and is excluded from the request body.
  ///   - zeroXApiKey: Optional 0x API key to override the one configured in Portal Dashboard.
  ///     - If `nil`: The SDK will use the API key configured in the Portal Dashboard.
  ///     - If provided: This API key will be used for this request, overriding the Dashboard configuration.
  ///     - The API key is used to authenticate requests to the 0x API service and is included in the request body.
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
  /// The 0x API key can be configured in two ways:
  /// 1. **Portal Dashboard** (Recommended): Configure your 0x API key in the Portal Dashboard. The SDK will use it automatically when `zeroXApiKey` is `nil`.
  /// 2. **Per-Request Override**: Provide the API key in the `zeroXApiKey` parameter to override the Dashboard configuration for this specific request.
  ///
  /// - Parameters:
  ///   - request: The price request parameters containing chain ID, tokens, amounts, and optional swap configuration.
  ///     - Note: The `chainId` in the request is used for the URL path only and is excluded from the request body.
  ///   - zeroXApiKey: Optional 0x API key to override the one configured in Portal Dashboard.
  ///     - If `nil`: The SDK will use the API key configured in the Portal Dashboard.
  ///     - If provided: This API key will be used for this request, overriding the Dashboard configuration.
  ///     - The API key is used to authenticate requests to the 0x API service and is included in the request body.
  /// - Returns: Response containing the price data, including buy/sell amounts, price, gas estimates, fees breakdown, and liquidity availability.
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func getPrice(request: ZeroXPriceRequest, zeroXApiKey: String? = nil) async throws -> ZeroXPriceResponse {
    return try await api.getPrice(request: request, zeroXApiKey: zeroXApiKey)
  }

  /// Fetches a 0x quote and executes the returned transaction end-to-end.
  ///
  /// Flow: fetch quote -> validate -> sign + broadcast via `eth_sendTransaction` -> wait for the
  /// on-chain receipt -> return the transaction hash. Progress is reported via `onProgress` at each step.
  ///
  /// - Parameters:
  ///   - params: The swap parameters (chain, tokens, amount, and optional overrides).
  ///   - onProgress: Optional callback invoked with status updates throughout the flow.
  /// - Returns: A result containing the transaction hash(es). For same-chain swaps this is a single hash.
  /// - Throws: `ZeroXTradeAssetError` for quote/transaction/confirmation failures, or any error thrown by the underlying API/signing.
  public func tradeAsset(
    params: ZeroXTradeAssetParams,
    onProgress: ((ZeroXTradeAssetProgressStatus, ZeroXTradeAssetProgressData) -> Void)? = nil
  ) async throws -> ZeroXTradeAssetResult {
    func report(_ status: ZeroXTradeAssetProgressStatus, _ data: ZeroXTradeAssetProgressData = ZeroXTradeAssetProgressData()) {
      onProgress?(status, data)
    }

    guard let portal = portal else {
      let error = ZeroXTradeAssetError.portalNotInitialized
      report(.failed, ZeroXTradeAssetProgressData(errorMessage: error.localizedDescription))
      throw error
    }

    let network = params.chainId

    // 1. Fetch quote
    report(.fetchingQuote)

    let quote: ZeroXQuoteResponse
    do {
      quote = try await api.getQuote(request: params.toQuoteRequest(), zeroXApiKey: params.zeroXApiKey)
    } catch {
      report(.failed, ZeroXTradeAssetProgressData(errorMessage: "getQuote failed: \(error.localizedDescription)"))
      throw error
    }

    // 2. Validate quote. Fail closed on any non-empty error string.
    if let quoteError = quote.error, !quoteError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      let error = ZeroXTradeAssetError.quoteError(quoteError)
      report(.failed, ZeroXTradeAssetProgressData(errorMessage: error.localizedDescription))
      throw error
    }

    guard let rawResponse = quote.data?.rawResponse else {
      let error = ZeroXTradeAssetError.missingQuoteData
      report(.failed, ZeroXTradeAssetProgressData(errorMessage: error.localizedDescription))
      throw error
    }

    let transaction = rawResponse.transaction
    guard !transaction.to.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      let error = ZeroXTradeAssetError.missingTransaction
      report(.failed, ZeroXTradeAssetProgressData(errorMessage: error.localizedDescription))
      throw error
    }

    // 3. Sign + broadcast
    report(.signing, ZeroXTradeAssetProgressData(
      buyAmount: rawResponse.buyAmount,
      sellAmount: rawResponse.sellAmount,
      transaction: transaction
    ))

    let txParams: [String: Any] = [
      "from": transaction.from,
      "to": transaction.to,
      "data": transaction.data,
      "value": transaction.value,
      "gas": transaction.gas,
      "gasPrice": transaction.gasPrice
    ]

    let txHash: String
    do {
      let response = try await portal.request(
        chainId: network,
        method: .eth_sendTransaction,
        params: [txParams],
        options: nil
      )
      guard let hash = response.result as? String, !hash.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        let error = ZeroXTradeAssetError.invalidTransactionHash
        report(.failed, ZeroXTradeAssetProgressData(errorMessage: error.localizedDescription))
        throw error
      }
      txHash = hash
    } catch let error as ZeroXTradeAssetError {
      throw error
    } catch {
      report(.failed, ZeroXTradeAssetProgressData(errorMessage: "eth_sendTransaction failed: \(error.localizedDescription)"))
      throw error
    }

    // 4. Submitted + confirming
    report(.submitted, ZeroXTradeAssetProgressData(
      txHash: txHash,
      buyAmount: rawResponse.buyAmount,
      sellAmount: rawResponse.sellAmount,
      transaction: transaction
    ))

    report(.confirming, ZeroXTradeAssetProgressData(
      txHash: txHash,
      buyAmount: rawResponse.buyAmount,
      sellAmount: rawResponse.sellAmount,
      transaction: transaction
    ))

    // 5. Wait for confirmation
    let confirmed: Bool
    do {
      confirmed = try await waitForConfirmation(txHash: txHash, chainId: network, portal: portal)
    } catch {
      report(.failed, ZeroXTradeAssetProgressData(txHash: txHash, errorMessage: "waitForConfirmation failed: \(error.localizedDescription)"))
      throw error
    }

    guard confirmed else {
      let message = "On-chain confirmation did not complete for \(txHash) on \(network)."
      let error = ZeroXTradeAssetError.confirmationFailed(message)
      report(.failed, ZeroXTradeAssetProgressData(txHash: txHash, errorMessage: message))
      throw error
    }

    // 6. Confirmed
    report(.confirmed, ZeroXTradeAssetProgressData(txHash: txHash))

    return ZeroXTradeAssetResult(hashes: [txHash])
  }

  /// Polls `eth_getTransactionReceipt` until the transaction is mined.
  /// - Returns: `true` when the receipt reports success (`status == "0x1"`).
  /// - Throws: `ZeroXTradeAssetError.confirmationFailed` on revert (`status == "0x0"`) or timeout.
  private func waitForConfirmation(txHash: String, chainId: String, portal: ZeroXPortalDependency) async throws -> Bool {
    for _ in 0 ..< confirmationMaxAttempts {
      try await Task.sleep(nanoseconds: confirmationPollIntervalNanoseconds)

      let response = try await portal.request(
        chainId: chainId,
        method: .eth_getTransactionReceipt,
        params: [txHash],
        options: nil
      )

      if let receipt = response.result as? EthTransactionResponse, let status = receipt.result?.status {
        if status == "0x1" {
          return true
        } else {
          throw ZeroXTradeAssetError.confirmationFailed("Transaction \(txHash) reverted (status: \(status)).")
        }
      }
    }

    throw ZeroXTradeAssetError.confirmationFailed("Transaction \(txHash) was not confirmed within the timeout window.")
  }
}
