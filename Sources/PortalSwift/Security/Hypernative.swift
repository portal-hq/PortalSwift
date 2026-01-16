//
//  Hypernative.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Protocol defining the interface for Hypernative security provider functionality.
///
/// The Hypernative security provider enables real-time security scanning and risk assessment
/// for blockchain transactions, addresses, NFTs, tokens, and URLs. It integrates with Hypernative's
/// security infrastructure to detect phishing, scams, malicious contracts, and other security threats.
public protocol HypernativeProtocol {
  /// Scans an EVM transaction for security risks.
  /// - Parameter request: The scan request containing transaction details (chain, addresses, input data, etc.)
  /// - Returns: Response containing risk assessment, recommendations, findings, and trace data
  /// - Throws: `URLError` if the request fails or network errors occur
  func scanEVMTx(request: ScanEVMRequest) async throws -> ScanEVMResponse
  
  /// Scans an EIP-712 typed message for security risks.
  /// - Parameter request: The scan request containing wallet address, chain ID, and EIP-712 typed data
  /// - Returns: Response containing risk assessment, recommendations, and findings for the typed message
  /// - Throws: `URLError` if the request fails or network errors occur
  func scanEip712Tx(request: ScanEip712Request) async throws -> ScanEip712Response
  
  /// Scans a Solana transaction for security risks.
  /// - Parameter request: The scan request containing the Solana transaction (raw or structured)
  /// - Returns: Response containing risk assessment, recommendations, findings, and trace data
  /// - Throws: `URLError` if the request fails or network errors occur
  func scanSolanaTx(request: ScanSolanaRequest) async throws -> ScanSolanaResponse
  
  /// Screens multiple addresses for security risks and compliance flags.
  /// - Parameter request: The scan request containing an array of addresses to screen
  /// - Returns: Response containing risk assessment, severity, and compliance flags for each address
  /// - Throws: `URLError` if the request fails or network errors occur
  func scanAddresses(request: ScanAddressesRequest) async throws -> ScanAddressesResponse
  
  /// Scans multiple NFTs for security risks.
  /// - Parameter request: The scan request containing an array of NFT addresses and chain IDs
  /// - Returns: Response containing accept/reject status for each NFT
  /// - Throws: `URLError` if the request fails or network errors occur
  func scanNfts(request: ScanNftsRequest) async throws -> ScanNftsResponse
  
  /// Scans multiple tokens for security risks and reputation.
  /// - Parameter request: The scan request containing an array of token addresses and chain IDs
  /// - Returns: Response containing reputation and recommendation for each token
  /// - Throws: `URLError` if the request fails or network errors occur
  func scanTokens(request: ScanTokensRequest) async throws -> ScanTokensResponse
  
  /// Scans a URL for malicious content and phishing indicators.
  /// - Parameter request: The scan request containing the URL to scan
  /// - Returns: Response indicating whether the URL is malicious
  /// - Throws: `URLError` if the request fails or network errors occur
  func scanURL(request: ScanUrlRequest) async throws -> ScanUrlResponse
}

/// Hypernative provider implementation for security functionality.
///
/// This class provides access to Hypernative's security scanning capabilities, enabling
/// real-time risk assessment for blockchain transactions, addresses, NFTs, tokens, and URLs.
///
/// ## Overview
/// The Hypernative provider integrates with Portal's security infrastructure to provide:
/// - **Transaction Scanning**: Analyze EVM, EIP-712, and Solana transactions for security risks
/// - **Address Screening**: Check addresses against known phishing, scam, and compliance databases
/// - **NFT Verification**: Validate NFT contracts for security risks
/// - **Token Reputation**: Check token contracts for rug pulls, honeypots, and other risks
/// - **URL Scanning**: Detect malicious URLs and phishing sites
///
/// ## Usage Example
/// ```swift
/// // Scan an EVM transaction
/// let transaction = ScanEVMTransaction(
///     chain: "eip155:1",
///     fromAddress: "0x...",
///     toAddress: "0x...",
///     input: "0x...",
///     value: 0,
///     nonce: 1,
///     gas: 21000,
///     gasPrice: 20000000000
/// )
/// let request = ScanEVMRequest(transaction: transaction)
/// let response = try await portal.security.hypernative.scanEVMTx(request: request)
///
/// if response.data?.rawResponse.data?.recommendation == "deny" {
///     print("Transaction blocked: potential security risk")
/// }
/// ```
public class Hypernative: HypernativeProtocol {
  private let api: PortalHypernativeApiProtocol

  /// Create an instance of Hypernative.
  /// - Parameter api: The PortalHypernativeApi instance to use for security operations.
  public init(api: PortalHypernativeApiProtocol) {
    self.api = api
  }

  /// Scans an EVM transaction for security risks.
  ///
  /// This method analyzes an EVM transaction (including EIP-155, EIP-1559, and other EVM transaction formats) before it's submitted to the blockchain.
  /// The scan checks for:
  /// - Interactions with known phishing/scam addresses
  /// - Malicious contract interactions
  /// - Suspicious approval patterns
  /// - Token transfer risks
  ///
  /// The response includes a recommendation (accept, warn, deny) along with detailed findings
  /// explaining any identified risks.
  ///
  /// - Parameter request: The scan request containing:
  ///   - `transaction`: The transaction object with chain, addresses, input data, value, gas, etc.
  ///   - `url`: Optional URL context for the transaction
  ///   - `blockNumber`: Optional block number for simulation
  ///   - `showFullFindings`: Whether to include detailed findings in the response
  /// - Returns: Response containing:
  ///   - `recommendation`: The security recommendation (accept, notes, warn, deny, autoAccept)
  ///   - `findings`: Array of security findings with severity and details
  ///   - `trace`: Transaction execution trace for debugging
  ///   - `parsedActions`: Parsed transaction actions (approvals, transfers, etc.)
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func scanEVMTx(request: ScanEVMRequest) async throws -> ScanEVMResponse {
    return try await api.scanEVMTx(request: request)
  }

  /// Scans an EIP-712 typed message for security risks.
  ///
  /// This method analyzes an EIP-712 typed data message before it's signed. EIP-712 messages
  /// are commonly used for:
  /// - Token approvals (Permit, Permit2)
  /// - NFT marketplace listings
  /// - DEX order signatures
  /// - Gasless transactions
  ///
  /// The scan checks for:
  /// - Malicious permit requests that could drain wallets
  /// - Phishing signatures targeting valuable assets
  /// - Suspicious spender addresses
  ///
  /// - Parameter request: The scan request containing:
  ///   - `walletAddress`: The address that will sign the message
  ///   - `chainId`: The chain ID (e.g., "eip155:1")
  ///   - `eip712Message`: The typed data structure with domain, types, and message
  ///   - `showFullFindings`: Whether to include detailed findings in the response
  /// - Returns: Response containing:
  ///   - `recommendation`: The security recommendation (accept, notes, warn, deny, autoAccept)
  ///   - `findings`: Array of security findings with severity and details
  ///   - `parsedActions`: Parsed message actions (approvals, etc.)
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func scanEip712Tx(request: ScanEip712Request) async throws -> ScanEip712Response {
    return try await api.scanEip712Tx(request: request)
  }

  /// Scans a Solana transaction for security risks.
  ///
  /// This method analyzes a Solana transaction before it's submitted to the blockchain.
  /// The scan checks for:
  /// - Interactions with known malicious programs
  /// - Suspicious token transfers
  /// - Drainer attacks
  /// - Authority transfer risks
  ///
  /// - Parameter request: The scan request containing:
  ///   - `transaction`: The Solana transaction (raw base64 or structured message)
  ///   - `url`: Optional URL context for the transaction
  ///   - `validateRecentBlockHash`: Whether to validate the blockhash
  ///   - `showFullFindings`: Whether to include detailed findings in the response
  /// - Returns: Response containing:
  ///   - `recommendation`: The security recommendation (accept, notes, warn, deny, autoAccept)
  ///   - `findings`: Array of security findings with severity and details
  ///   - `trace`: Transaction execution trace
  ///   - `parsedActions`: Parsed transaction actions
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func scanSolanaTx(request: ScanSolanaRequest) async throws -> ScanSolanaResponse {
    return try await api.scanSolanaTx(request: request)
  }

  /// Screens multiple addresses for security risks and compliance flags.
  ///
  /// This method checks addresses against Hypernative's database of known:
  /// - Phishing addresses
  /// - Scam contracts
  /// - Mixer/tumbler services (Tornado Cash, etc.)
  /// - Sanctioned entities
  /// - Hacked/exploited contracts
  ///
  /// The response includes detailed exposure information showing the connection
  /// path to flagged entities.
  ///
  /// - Parameter request: The scan request containing:
  ///   - `addresses`: Array of addresses to screen
  ///   - `screenerPolicyId`: Optional policy ID for custom screening rules
  /// - Returns: Response containing for each address:
  ///   - `recommendation`: Approve or Deny
  ///   - `severity`: Risk severity (High, Medium, Low, N/A)
  ///   - `flags`: Array of compliance flags with exposure details
  ///   - `totalIncomingUsd`: Total USD value of incoming transactions
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func scanAddresses(request: ScanAddressesRequest) async throws -> ScanAddressesResponse {
    return try await api.scanAddresses(request: request)
  }

  /// Scans multiple NFTs for security risks.
  ///
  /// This method checks NFT contracts for:
  /// - Known scam/fake NFT collections
  /// - Malicious contract code
  /// - Stolen/compromised NFTs
  /// - Suspicious minting patterns
  ///
  /// - Parameter request: The scan request containing:
  ///   - `nfts`: Array of NFT items with address and chain ID
  /// - Returns: Response containing for each NFT:
  ///   - `accept`: Boolean indicating if the NFT is safe
  ///   - `chain`: The blockchain network
  ///   - `address`: The NFT contract address
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func scanNfts(request: ScanNftsRequest) async throws -> ScanNftsResponse {
    return try await api.scanNfts(request: request)
  }

  /// Scans multiple tokens for security risks and reputation.
  ///
  /// This method checks token contracts for:
  /// - Honeypot tokens (can't sell)
  /// - Rug pull indicators
  /// - Malicious transfer fees
  /// - Blacklist/whitelist functions
  /// - Known scam tokens
  ///
  /// - Parameter request: The scan request containing:
  ///   - `tokens`: Array of token items with address and chain ID
  /// - Returns: Response containing for each token:
  ///   - `reputation.recommendation`: Accept or Deny
  ///   - `chain`: The blockchain network
  ///   - `address`: The token contract address
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func scanTokens(request: ScanTokensRequest) async throws -> ScanTokensResponse {
    return try await api.scanTokens(request: request)
  }

  /// Scans a URL for malicious content and phishing indicators.
  ///
  /// This method checks URLs for:
  /// - Known phishing sites
  /// - Malware distribution
  /// - Fake dApp frontends
  /// - Domain spoofing
  /// - Recently registered suspicious domains
  ///
  /// - Parameter request: The scan request containing:
  ///   - `url`: The URL to scan (e.g., "curve.fi", "https://uniswap.org")
  /// - Returns: Response containing:
  ///   - `isMalicious`: Boolean indicating if the URL is malicious
  ///   - `deepScanTriggered`: Whether a deep scan was performed
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func scanURL(request: ScanUrlRequest) async throws -> ScanUrlResponse {
    return try await api.scanURL(request: request)
  }
}
