//
//  PortalHypernativeApi.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Protocol for Hypernative Security API interactions.
public protocol PortalHypernativeApiProtocol: AnyObject {
  /// Scans an EIP-155 transaction for security risks.
  /// - Parameters:
  ///   - request: The scan request containing transaction details
  /// - Returns: Response containing security risk assessment
  func scanEip155Tx(request: ScanEip155Request) async throws -> ScanEip155Response
  
  /// Scans an EIP-712 typed message for security risks.
  /// - Parameters:
  ///   - request: The scan request containing EIP-712 message details
  /// - Returns: Response containing security risk assessment
  func scanEip712Tx(request: ScanEip712Request) async throws -> ScanEip712Response
  
  /// Scans a Solana transaction for security risks.
  /// - Parameters:
  ///   - request: The scan request containing Solana transaction details
  /// - Returns: Response containing security risk assessment
  func scanSolanaTx(request: ScanSolanaRequest) async throws -> ScanSolanaResponse
  
  /// Screens addresses for security risks.
  /// - Parameters:
  ///   - request: The scan request containing addresses to screen
  /// - Returns: Response containing security risk assessment for each address
  func scanAddresses(request: ScanAddressesRequest) async throws -> ScanAddressesResponse
  
  /// Scans NFTs for security risks.
  /// - Parameters:
  ///   - request: The scan request containing NFT addresses to scan
  /// - Returns: Response containing security risk assessment for each NFT
  func scanNfts(request: ScanNftsRequest) async throws -> ScanNftsResponse
  
  /// Scans tokens for security risks.
  /// - Parameters:
  ///   - request: The scan request containing token addresses to scan
  /// - Returns: Response containing security risk assessment for each token
  func scanTokens(request: ScanTokensRequest) async throws -> ScanTokensResponse
  
  /// Scans a URL for security risks.
  /// - Parameters:
  ///   - request: The scan request containing the URL to scan
  /// - Returns: Response containing security risk assessment for the URL
  func scanURL(request: ScanUrlRequest) async throws -> ScanUrlResponse
}

/// API class for Hypernative security integration functionality.
public class PortalHypernativeApi: PortalHypernativeApiProtocol {
  private let apiKey: String
  private let baseUrl: String
  private let requests: PortalRequestsProtocol
  private let logger = PortalLogger()

  /// Create an instance of PortalHypernativeApi.
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

  /// Scans an EIP-155 transaction for security risks.
  ///
  /// This method analyzes an Ethereum/EVM transaction (EIP-155 format) to identify potential security threats,
  /// including malicious contracts, suspicious token approvals, phishing attempts, and other risk factors.
  /// The analysis includes transaction simulation, balance change detection, and comprehensive risk scoring.
  ///
  /// - Parameters:
  ///   - request: The scan request containing:
  ///     - `transaction`: The EIP-155 transaction object with chain, from/to addresses, input data, value, gas, etc.
  ///     - `url`: Optional URL associated with the transaction (e.g., dApp origin)
  ///     - `blockNumber`: Optional block number for transaction validation
  ///     - `validateNonce`: Optional flag to validate transaction nonce
  ///     - `showFullFindings`: Optional flag to include detailed findings in the response
  ///     - `policy`: Optional policy ID to use for scanning
  /// - Returns: Response containing:
  ///   - Security risk assessment with recommendation (accept, notes, warn, deny, autoAccept)
  ///   - Detailed findings with severity levels
  ///   - Involved assets and their risk status
  ///   - Balance changes and parsed actions
  ///   - Transaction trace information
  ///   - Expected transaction status (success/fail)
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func scanEip155Tx(request: ScanEip155Request) async throws -> ScanEip155Response {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/hypernative/eip-155/scan") else {
      logger.error("PortalHypernativeApi.scanEip155Tx() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: ScanEip155Response.self)
    } catch {
      logger.error("PortalHypernativeApi.scanEip155Tx() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Scans an EIP-712 typed message for security risks.
  ///
  /// This method analyzes an EIP-712 structured data message (commonly used for token approvals, permits, and other
  /// typed signatures) to identify potential security threats. It evaluates the message content, domain, and types
  /// to detect malicious patterns, excessive permissions, and suspicious interactions.
  ///
  /// - Parameters:
  ///   - request: The scan request containing:
  ///     - `walletAddress`: The wallet address that will sign the message
  ///     - `chainId`: The chain ID in the format "eip155:{chainId}" (e.g., "eip155:1" for Ethereum mainnet)
  ///     - `eip712Message`: The EIP-712 typed data structure with primaryType, types, domain, and message
  ///     - `showFullFindings`: Optional flag to include detailed findings in the response
  ///     - `policy`: Optional policy ID to use for scanning
  /// - Returns: Response containing:
  ///   - Security risk assessment with recommendation (accept, notes, warn, deny, autoAccept)
  ///   - Detailed findings with severity levels
  ///   - Involved assets and their risk status
  ///   - Parsed actions (e.g., token approvals)
  ///   - Transaction trace information
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func scanEip712Tx(request: ScanEip712Request) async throws -> ScanEip712Response {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/hypernative/eip-712/scan") else {
      logger.error("PortalHypernativeApi.scanEip712Tx() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: ScanEip712Response.self)
    } catch {
      logger.error("PortalHypernativeApi.scanEip712Tx() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Scans a Solana transaction for security risks.
  ///
  /// This method analyzes a Solana transaction to identify potential security threats, including malicious programs,
  /// suspicious token transfers, unauthorized account access, and other risk factors specific to the Solana blockchain.
  /// The analysis includes transaction simulation and comprehensive risk scoring.
  ///
  /// - Parameters:
  ///   - request: The scan request containing:
  ///     - `transaction`: The Solana transaction object with message, signatures, rawTransaction, and version
  ///     - `url`: Optional URL associated with the transaction (e.g., dApp origin)
  ///     - `validateRecentBlockHash`: Optional flag to validate the recent blockhash
  ///     - `showFullFindings`: Optional flag to include detailed findings in the response
  ///     - `policy`: Optional policy ID to use for scanning
  /// - Returns: Response containing:
  ///   - Security risk assessment with recommendation (accept, notes, warn, deny, autoAccept)
  ///   - Detailed findings with severity levels
  ///   - Involved assets and their risk status
  ///   - Balance changes and parsed actions
  ///   - Transaction trace information
  ///   - Expected transaction status (success/fail)
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func scanSolanaTx(request: ScanSolanaRequest) async throws -> ScanSolanaResponse {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/hypernative/solana/scan") else {
      logger.error("PortalHypernativeApi.scanSolanaTx() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: ScanSolanaResponse.self)
    } catch {
      logger.error("PortalHypernativeApi.scanSolanaTx() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Screens addresses for security risks.
  ///
  /// This method screens one or more blockchain addresses to identify security risks, including association with
  /// known malicious entities, mixer services, scam operations, and other flagged activities. It provides
  /// comprehensive risk scoring and exposure analysis for each address.
  ///
  /// - Parameters:
  ///   - request: The scan request containing:
  ///     - `addresses`: Array of addresses to screen (supports multiple addresses in a single request)
  ///     - `screenerPolicyId`: Optional policy ID to use for screening
  /// - Returns: Response containing an array of results, each with:
  ///   - Address risk assessment with recommendation (Approve, Deny, etc.)
  ///   - Severity level (High, Medium, Low, N/A)
  ///   - Total incoming USD value from flagged sources
  ///   - Policy ID and timestamp
  ///   - Detailed flags with events and exposures
  ///   - Flagged interactions and counterparty information
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func scanAddresses(request: ScanAddressesRequest) async throws -> ScanAddressesResponse {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/hypernative/addresses/scan") else {
      logger.error("PortalHypernativeApi.scanAddresses() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: ScanAddressesResponse.self)
    } catch {
      logger.error("PortalHypernativeApi.scanAddresses() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Scans NFTs for security risks.
  ///
  /// This method screens one or more NFT contract addresses to identify security risks, including known scam NFTs,
  /// malicious contracts, and other flagged collections. It helps users make informed decisions before interacting
  /// with NFT contracts.
  ///
  /// - Parameters:
  ///   - request: The scan request containing:
  ///     - `nfts`: Array of NFT items to scan, each with:
  ///       - `address`: The NFT contract address
  ///       - `chain`: Optional chain identifier
  ///       - `evmChainId`: Optional EVM chain ID in the format "eip155:{chainId}"
  /// - Returns: Response containing an array of results, each with:
  ///   - NFT contract address and chain information
  ///   - `accept`: Boolean indicating whether the NFT is safe to interact with
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func scanNfts(request: ScanNftsRequest) async throws -> ScanNftsResponse {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/hypernative/nfts/scan") else {
      logger.error("PortalHypernativeApi.scanNfts() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: ScanNftsResponse.self)
    } catch {
      logger.error("PortalHypernativeApi.scanNfts() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Scans tokens for security risks.
  ///
  /// This method screens one or more token contract addresses to identify security risks, including known scam tokens,
  /// honeypots, rug pulls, and other malicious contracts. It provides reputation information to help users make
  /// informed decisions before interacting with token contracts.
  ///
  /// - Parameters:
  ///   - request: The scan request containing:
  ///     - `tokens`: Array of token items to scan, each with:
  ///       - `address`: The token contract address
  ///       - `chain`: Optional chain identifier
  ///       - `evmChainId`: Optional EVM chain ID in the format "eip155:{chainId}"
  /// - Returns: Response containing an array of results, each with:
  ///   - Token contract address and chain information
  ///   - `reputation`: Optional reputation data with recommendation (accept, deny)
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func scanTokens(request: ScanTokensRequest) async throws -> ScanTokensResponse {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/hypernative/tokens/scan") else {
      logger.error("PortalHypernativeApi.scanTokens() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: ScanTokensResponse.self)
    } catch {
      logger.error("PortalHypernativeApi.scanTokens() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Scans a URL for security risks.
  ///
  /// This method screens a URL to identify security risks, including known phishing sites, malicious domains,
  /// and other flagged web resources. It helps protect users from interacting with dangerous websites.
  ///
  /// - Parameters:
  ///   - request: The scan request containing:
  ///     - `url`: The URL to scan (e.g., "curve.fi", "example.com")
  /// - Returns: Response containing:
  ///   - `isMalicious`: Boolean indicating whether the URL is flagged as malicious
  ///   - `deepScanTriggered`: Optional boolean indicating if a deep scan was triggered
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func scanURL(request: ScanUrlRequest) async throws -> ScanUrlResponse {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/hypernative/url/scan") else {
      logger.error("PortalHypernativeApi.scanURL() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: ScanUrlResponse.self)
    } catch {
      logger.error("PortalHypernativeApi.scanURL() - Error: \(error.localizedDescription)")
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
