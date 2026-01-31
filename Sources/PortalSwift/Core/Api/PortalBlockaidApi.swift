//
//  PortalBlockaidApi.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Protocol for Blockaid Security API interactions.
public protocol PortalBlockaidApiProtocol: AnyObject {
  /// Scans an EVM transaction for security risks.
  /// - Parameters:
  ///   - request: The scan request containing chain, metadata, transaction data, and options
  /// - Returns: Response containing validation result, simulation, and risk features
  func scanEVMTx(request: BlockaidScanEVMRequest) async throws -> BlockaidScanEVMResponse

  /// Scans a Solana transaction for security risks.
  /// - Parameters:
  ///   - request: The scan request containing account address, serialized transactions, chain, and options
  /// - Returns: Response containing validation result, simulation, and extended features
  func scanSolanaTx(request: BlockaidScanSolanaRequest) async throws -> BlockaidScanSolanaResponse

  /// Scans an address for security risks (EVM or Solana).
  /// - Parameters:
  ///   - request: The scan request containing address, chain (CAIP-2), and optional metadata
  /// - Returns: Response containing result type (Benign, Warning, Malicious) and features
  func scanAddress(request: BlockaidScanAddressRequest) async throws -> BlockaidScanAddressResponse

  /// Scans multiple tokens for security risks.
  /// - Parameters:
  ///   - request: The scan request containing chain and array of token addresses
  /// - Returns: Response containing per-token results with result type, metadata, and features
  func scanTokens(request: BlockaidScanTokensRequest) async throws -> BlockaidScanTokensResponse

  /// Scans a URL for security risks (phishing, malicious dApps).
  /// - Parameters:
  ///   - request: The scan request containing the URL and optional metadata
  /// - Returns: Response containing status (hit/miss), isMalicious, and contract operations when available
  func scanURL(request: BlockaidScanURLRequest) async throws -> BlockaidScanURLResponse
}

/// API class for Blockaid security integration functionality.
public class PortalBlockaidApi: PortalBlockaidApiProtocol {
  private let apiKey: String
  private let baseUrl: String
  private let requests: PortalRequestsProtocol
  private let logger = PortalLogger()

  /// Create an instance of PortalBlockaidApi.
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

  /// Scans an EVM transaction for security risks.
  ///
  /// This method sends an EVM transaction to the Blockaid-backed endpoint for validation and optional simulation.
  /// It identifies potential security threats such as transfers to known malicious addresses, malicious contract
  /// interactions, and other risk features (e.g. KNOWN_MALICIOUS_ADDRESS).
  ///
  /// - Parameters:
  ///   - request: The scan request containing:
  ///     - `chain`: CAIP-2 chain ID (e.g., "eip155:1")
  ///     - `metadata`: Domain or context for the transaction (e.g., dApp origin)
  ///     - `data`: Transaction data (from, to, data, value, gas, gas_price)
  ///     - `options`: Optional array of simulation, validation, gas_estimation, events
  ///     - `block`: Optional block number for simulation
  /// - Returns: Response containing:
  ///   - `validation`: Result type (Benign, Warning, Malicious), reason, description, features
  ///   - `simulation`: When requested, assets_diffs, transaction_actions, account_summary
  ///   - `block`, `chain`, `account_address`
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func scanEVMTx(request: BlockaidScanEVMRequest) async throws -> BlockaidScanEVMResponse {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/blockaid/evm/scan") else {
      logger.error("PortalBlockaidApi.scanEVMTx() - Unable to build request URL.")
      throw URLError(.badURL)
    }
    do {
      return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: BlockaidScanEVMResponse.self)
    } catch {
      logger.error("PortalBlockaidApi.scanEVMTx() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Scans a Solana transaction for security risks.
  ///
  /// This method sends one or more serialized Solana transactions to the Blockaid-backed endpoint for validation
  /// and optional simulation. It identifies transfer-farming, drainer patterns, and known malicious addresses.
  ///
  /// - Parameters:
  ///   - request: The scan request containing:
  ///     - `accountAddress`: The wallet address that would sign or send the transaction
  ///     - `transactions`: Array of serialized transactions (base58 or base64 per encoding)
  ///     - `metadata`: Optional URL for dApp context
  ///     - `encoding`: Optional "base58" or "base64"
  ///     - `chain`: CAIP-2 chain ID (e.g., "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp")
  ///     - `options`: Optional array of simulation, validation
  ///     - `method`: Optional (e.g., "signAndSendTransaction")
  /// - Returns: Response containing:
  ///   - `result.validation`: result_type, reason, features, extended_features
  ///   - `result.simulation`: When requested, assets_diff, account_summary, transaction_actions
  ///   - `status`, `encoding`, `request_id`
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func scanSolanaTx(request: BlockaidScanSolanaRequest) async throws -> BlockaidScanSolanaResponse {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/blockaid/solana/scan") else {
      logger.error("PortalBlockaidApi.scanSolanaTx() - Unable to build request URL.")
      throw URLError(.badURL)
    }
    do {
      return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: BlockaidScanSolanaResponse.self)
    } catch {
      logger.error("PortalBlockaidApi.scanSolanaTx() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Scans an address for security risks (EVM or Solana).
  ///
  /// This method sends a single address to the Blockaid-backed endpoint to check against known malicious,
  /// phishing, and scam-associated addresses. The same endpoint is used for both EVM and Solana; the `chain`
  /// parameter determines how the address is interpreted.
  ///
  /// - Parameters:
  ///   - request: The scan request containing:
  ///     - `address`: The address to scan (EVM or Solana format)
  ///     - `chain`: CAIP-2 chain ID ("eip155:1" or "solana:...")
  ///     - `metadata`: Optional domain for dApp context (often used for EVM)
  /// - Returns: Response containing:
  ///   - `result_type`: Benign, Warning, Malicious, or Error
  ///   - `features`: Array of feature objects (type, feature_id, description)
  ///   - `error`: Present when result_type is Error
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func scanAddress(request: BlockaidScanAddressRequest) async throws -> BlockaidScanAddressResponse {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/blockaid/address/scan") else {
      logger.error("PortalBlockaidApi.scanAddress() - Unable to build request URL.")
      throw URLError(.badURL)
    }
    do {
      return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: BlockaidScanAddressResponse.self)
    } catch {
      logger.error("PortalBlockaidApi.scanAddress() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Scans multiple tokens for security risks.
  ///
  /// This method sends a list of token contract addresses to the Blockaid-backed endpoint for bulk scanning.
  /// It identifies known malicious or scam tokens, malicious metadata/URLs, airdrop patterns, honeypots,
  /// rug pulls, and similar risks. Results are returned as a dictionary keyed by token address.
  ///
  /// - Parameters:
  ///   - request: The scan request containing:
  ///     - `chain`: CAIP-2 chain ID (e.g., "eip155:1")
  ///     - `tokens`: Array of token contract addresses
  ///     - `metadata`: Optional domain for context
  /// - Returns: Response containing:
  ///   - `results`: Dictionary [token address → result] with result_type, malicious_score, attack_types,
  ///     chain, address, metadata, fees, features, trading_limits, financial_stats
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func scanTokens(request: BlockaidScanTokensRequest) async throws -> BlockaidScanTokensResponse {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/blockaid/tokens/scan") else {
      logger.error("PortalBlockaidApi.scanTokens() - Unable to build request URL.")
      throw URLError(.badURL)
    }
    do {
      return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: BlockaidScanTokensResponse.self)
    } catch {
      logger.error("PortalBlockaidApi.scanTokens() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Scans a URL for security risks (phishing, malicious dApps).
  ///
  /// This method sends a URL to the Blockaid-backed endpoint to check for known phishing sites, malicious
  /// dApp frontends, and related threats. When the URL is in the catalog, status is "hit" and fields such as
  /// isMalicious, isWeb3Site, network_operations, and contract_read/contract_write are populated; otherwise
  /// status is "miss".
  ///
  /// - Parameters:
  ///   - request: The scan request containing:
  ///     - `url`: The URL to scan (e.g., "https://app.uniswap.org")
  ///     - `metadata`: Optional object with type "catalog" or "wallet"
  /// - Returns: Response containing:
  ///   - `status`: "hit" or "miss"
  ///   - When hit: url, isMalicious, maliciousScore, isReachable, isWeb3Site, attackTypes,
  ///     networkOperations, jsonRpcOperations, contractWrite, contractRead
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func scanURL(request: BlockaidScanURLRequest) async throws -> BlockaidScanURLResponse {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/blockaid/url/scan") else {
      logger.error("PortalBlockaidApi.scanURL() - Unable to build request URL.")
      throw URLError(.badURL)
    }
    do {
      return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: BlockaidScanURLResponse.self)
    } catch {
      logger.error("PortalBlockaidApi.scanURL() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /*******************************************
   * Private functions
   *******************************************/

  /// Performs a POST request to the specified URL with optional bearer token authentication and payload.
  ///
  /// - Parameters:
  ///   - url: The target URL for the request
  ///   - withBearerToken: Optional bearer token for authentication
  ///   - andPayload: Optional Codable payload to send in the request body
  ///   - mappingInResponse: The response type to decode the response into
  /// - Returns: Decoded response of the specified type
  /// - Throws: Network or decoding errors if the request fails
  @discardableResult
  private func post<ResponseType>(
    _ url: URL,
    withBearerToken: String? = nil,
    andPayload: Codable? = nil,
    mappingInResponse: ResponseType.Type
  ) async throws -> ResponseType where ResponseType: Decodable {
    let portalRequest = PortalAPIRequest(url: url, method: .post, payload: andPayload, bearerToken: withBearerToken)
    return try await requests.execute(request: portalRequest, mappingInResponse: mappingInResponse.self)
  }
}
