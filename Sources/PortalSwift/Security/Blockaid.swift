//
//  Blockaid.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Protocol defining the interface for Blockaid security provider functionality.
///
/// The Blockaid security provider enables real-time security scanning and risk assessment
/// for blockchain transactions, addresses, tokens, and URLs via Blockaid's security API.
public protocol BlockaidProtocol {
  /// Scans an EVM transaction for security risks.
  /// - Parameter request: The scan request containing chain, metadata, transaction data, and options
  /// - Returns: Response containing validation result, simulation, and risk features
  /// - Throws: `URLError` if the request fails or network errors occur
  func scanEVMTx(request: BlockaidScanEVMRequest) async throws -> BlockaidScanEVMResponse

  /// Scans a Solana transaction for security risks.
  /// - Parameter request: The scan request containing account address, serialized transactions, chain, and options
  /// - Returns: Response containing validation result, simulation, and extended features
  /// - Throws: `URLError` if the request fails or network errors occur
  func scanSolanaTx(request: BlockaidScanSolanaRequest) async throws -> BlockaidScanSolanaResponse

  /// Scans an address for security risks (EVM or Solana).
  /// - Parameter request: The scan request containing address, chain (CAIP-2), and optional metadata
  /// - Returns: Response containing result type (Benign, Warning, Malicious) and features
  /// - Throws: `URLError` if the request fails or network errors occur
  func scanAddress(request: BlockaidScanAddressRequest) async throws -> BlockaidScanAddressResponse

  /// Scans multiple tokens for security risks.
  /// - Parameter request: The scan request containing chain and array of token addresses
  /// - Returns: Response containing per-token results with result type, metadata, and features
  /// - Throws: `URLError` if the request fails or network errors occur
  func scanTokens(request: BlockaidScanTokensRequest) async throws -> BlockaidScanTokensResponse

  /// Scans a URL for security risks (phishing, malicious dApps).
  /// - Parameter request: The scan request containing the URL and optional metadata
  /// - Returns: Response containing status (hit/miss), isMalicious, and contract operations when available
  /// - Throws: `URLError` if the request fails or network errors occur
  func scanURL(request: BlockaidScanURLRequest) async throws -> BlockaidScanURLResponse
}

/// Blockaid provider implementation for security functionality.
///
/// This class provides access to Blockaid's security scanning capabilities via the Portal API,
/// enabling risk assessment for EVM and Solana transactions, addresses, tokens, and URLs.
///
/// ## Overview
/// The Blockaid provider integrates with Portal's security infrastructure to provide:
/// - **EVM Transaction Scanning**: Analyze Ethereum/EVM transactions for malicious addresses and simulation
/// - **Solana Transaction Scanning**: Analyze Solana transactions for drainer and transfer-farming risks
/// - **Address Screening**: Check addresses (EVM or Solana) against known malicious entities
/// - **Token Scanning**: Check token contracts for scams, honeypots, and malicious metadata
/// - **URL Scanning**: Detect phishing sites and malicious dApps (status hit/miss, isMalicious)
///
/// ## Usage Example
/// ```swift
/// // Scan an EVM transaction
/// let data = BlockaidScanEVMTransactionData(
///     from: "0x...",
///     to: "0x...",
///     data: "0x",
///     value: "0x1000"
/// )
/// let request = BlockaidScanEVMRequest(
///     chain: "eip155:1",
///     metadata: BlockaidScanEVMMetadata(domain: "https://example.com"),
///     data: data,
///     options: [.simulation, .validation]
/// )
/// let response = try await portal.security.blockaid.scanEVMTx(request: request)
///
/// if response.data?.rawResponse.validation?.resultType == "Malicious" {
///     print("Transaction blocked: potential security risk")
/// }
/// ```
public class Blockaid: BlockaidProtocol {
  private let api: PortalBlockaidApiProtocol

  /// Create an instance of Blockaid.
  /// - Parameter api: The PortalBlockaidApi instance to use for security operations.
  public init(api: PortalBlockaidApiProtocol) {
    self.api = api
  }

  /// Scans an EVM transaction for security risks.
  ///
  /// This method analyzes an EVM transaction (including raw value transfers and contract calls) before it's submitted.
  /// The scan checks for:
  /// - Transfers to known malicious or phishing addresses
  /// - Malicious contract interactions
  /// - Risk features (e.g. KNOWN_MALICIOUS_ADDRESS)
  ///
  /// The response includes validation (result type, reason, features) and optionally simulation
  /// (assets diffs, transaction actions, account summary) when requested.
  ///
  /// - Parameter request: The scan request containing:
  ///   - `chain`: CAIP-2 chain ID (e.g. "eip155:1")
  ///   - `metadata`: Optional domain for dApp context
  ///   - `data`: Transaction data (from, to, data, value, gas, gas_price)
  ///   - `options`: Optional array of "simulation", "validation", "gas_estimation", "events"
  ///   - `block`: Optional block number for simulation
  /// - Returns: Response containing:
  ///   - `validation`: Result type (Benign, Warning, Malicious), reason, description, features
  ///   - `simulation`: When requested, assets_diffs, transaction_actions, account_summary
  ///   - `block`, `chain`, `account_address`
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func scanEVMTx(request: BlockaidScanEVMRequest) async throws -> BlockaidScanEVMResponse {
    try await api.scanEVMTx(request: request)
  }

  /// Scans a Solana transaction for security risks.
  ///
  /// This method analyzes one or more serialized Solana transactions before they are signed or sent.
  /// The scan checks for:
  /// - Transfers to known malicious addresses
  /// - Transfer-farming and drainer patterns
  /// - Extended features (e.g. KNOWN_MALICIOUS_ADDRESS)
  ///
  /// The response includes validation (result type, reason, features, extended_features) and
  /// optionally simulation (assets_diff, account_summary, transaction_actions) when requested.
  ///
  /// - Parameter request: The scan request containing:
  ///   - `accountAddress`: The wallet address that would sign/send the transaction
  ///   - `transactions`: Array of serialized transactions (base58 or base64 per encoding)
  ///   - `metadata`: Optional URL for dApp context
  ///   - `encoding`: Optional "base58" or "base64"
  ///   - `chain`: CAIP-2 chain ID (e.g. "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp")
  ///   - `options`: Optional array of "simulation", "validation"
  ///   - `method`: Optional e.g. "signAndSendTransaction"
  /// - Returns: Response containing:
  ///   - `result.validation`: result_type, reason, features, extended_features
  ///   - `result.simulation`: When requested, assets_diff, account_summary, transaction_actions
  ///   - `status`, `encoding`, `request_id`
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func scanSolanaTx(request: BlockaidScanSolanaRequest) async throws -> BlockaidScanSolanaResponse {
    try await api.scanSolanaTx(request: request)
  }

  /// Scans an address for security risks (EVM or Solana).
  ///
  /// This method checks a single address against Blockaid's database of known:
  /// - Malicious and phishing addresses
  /// - Scam and fraud-associated addresses
  /// - Other risk categories (e.g. IS_EOA, OWNED_BY_SYSTEM_PROGRAM on Solana)
  ///
  /// Use the same endpoint for both EVM and Solana; the `chain` parameter determines interpretation.
  ///
  /// - Parameter request: The scan request containing:
  ///   - `address`: The address to scan (EVM or Solana format)
  ///   - `chain`: CAIP-2 chain ID ("eip155:1" or "solana:...")
  ///   - `metadata`: Optional domain for dApp context (often used for EVM)
  /// - Returns: Response containing:
  ///   - `result_type`: Benign, Warning, Malicious, or Error
  ///   - `features`: Array of feature objects (type, feature_id, description)
  ///   - `error`: Present when result_type is Error
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func scanAddress(request: BlockaidScanAddressRequest) async throws -> BlockaidScanAddressResponse {
    try await api.scanAddress(request: request)
  }

  /// Scans multiple tokens for security risks.
  ///
  /// This method checks token contracts for:
  /// - Known malicious or scam tokens
  /// - Malicious metadata and URLs
  /// - Airdrop patterns, static/dynamic analysis flags
  /// - Honeypots, rug pulls, and similar malicious contract patterns
  ///
  /// Results are returned in a dictionary keyed by token address.
  ///
  /// - Parameter request: The scan request containing:
  ///   - `chain`: CAIP-2 chain ID (e.g. "eip155:1")
  ///   - `tokens`: Array of token contract addresses
  ///   - `metadata`: Optional domain for context
  /// - Returns: Response containing:
  ///   - `results`: Dictionary [token address → result] with result_type, malicious_score, attack_types,
  ///     chain, address, metadata, fees, features, trading_limits, financial_stats
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func scanTokens(request: BlockaidScanTokensRequest) async throws -> BlockaidScanTokensResponse {
    try await api.scanTokens(request: request)
  }

  /// Scans a URL for malicious content and phishing indicators.
  ///
  /// This method checks URLs for:
  /// - Known phishing and scam sites
  /// - Malicious dApp frontends
  /// - Contract read/write and JSON-RPC operations when the site is Web3
  ///
  /// When the URL is not in the catalog, status is "miss"; when it is, status is "hit" and
  /// additional fields (isMalicious, isWeb3Site, network_operations, etc.) are populated.
  ///
  /// - Parameter request: The scan request containing:
  ///   - `url`: The URL to scan (e.g. "https://app.uniswap.org")
  ///   - `metadata`: Optional object with type "catalog" or "wallet"
  /// - Returns: Response containing:
  ///   - `status`: "hit" or "miss"
  ///   - When hit: `url`, `isMalicious`, `maliciousScore`, `isReachable`, `isWeb3Site`,
  ///     `attackTypes`, `networkOperations`, `jsonRpcOperations`, `contractWrite`, `contractRead`
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func scanURL(request: BlockaidScanURLRequest) async throws -> BlockaidScanURLResponse {
    try await api.scanURL(request: request)
  }
}
