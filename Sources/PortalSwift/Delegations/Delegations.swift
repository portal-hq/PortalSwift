//
//  Delegations.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Protocol defining the interface for Delegations functionality.
///
/// The Delegations provider enables token delegation management across EVM and Solana chains,
/// including approving delegates, revoking delegations, querying delegation status, and
/// executing transfers using delegated authority.
public protocol DelegationsProtocol {
  /// Approves a delegation for a specified token on a given chain.
  /// - Parameter request: The approval request containing chain, token, delegateAddress, and amount
  /// - Returns: Response containing transaction data and metadata
  /// - Throws: `URLError` if the URL cannot be constructed, or other network/decoding errors if the request fails.
  func approve(request: ApproveDelegationRequest) async throws -> ApproveDelegationResponse

  /// Revokes a delegation for a specified token on a given chain.
  /// - Parameter request: The revocation request containing chain, token, and delegateAddress
  /// - Returns: Response containing transaction data and metadata
  /// - Throws: `URLError` if the URL cannot be constructed, or other network/decoding errors if the request fails.
  func revoke(request: RevokeDelegationRequest) async throws -> RevokeDelegationResponse

  /// Retrieves the delegation status for a specified token and delegate address.
  /// - Parameter request: The status query containing chain, token, and delegateAddress
  /// - Returns: Response containing delegation status information
  /// - Throws: `URLError` if the URL cannot be constructed, or other network/decoding errors if the request fails.
  func getStatus(request: GetDelegationStatusRequest) async throws -> DelegationStatusResponse

  /// Transfers tokens from one address to another using delegated authority.
  /// - Parameter request: The transfer request containing chain, token, fromAddress, toAddress, and amount
  /// - Returns: Response containing transaction data and metadata
  /// - Throws: `URLError` if the URL cannot be constructed, or other network/decoding errors if the request fails.
  func transferFrom(request: TransferFromRequest) async throws -> TransferFromResponse
}

/// Delegations provider implementation.
///
/// This class provides access to token delegation capabilities via the Portal API,
/// enabling cross-chain delegation management for both EVM and Solana ecosystems.
///
/// ## Overview
/// The Delegations provider supports:
/// - **Approve**: Grant a delegate address permission to transfer tokens on your behalf
/// - **Revoke**: Remove a delegate's permission to transfer your tokens
/// - **Get Status**: Query current delegation state, balances, and active delegations
/// - **Transfer From**: Execute a transfer using previously approved delegated authority
///
/// ## Usage Example
/// ```swift
/// // Approve a delegation
/// let request = ApproveDelegationRequest(
///     chain: "eip155:11155111",
///     token: "USDC",
///     delegateAddress: "0x...",
///     amount: "1.0"
/// )
/// let response = try await portal.delegations.approve(request: request)
///
/// // Sign the returned transactions sequentially
/// if let transactions = response.transactions {
///     for tx in transactions { /* sign EVM tx */ }
/// } else if let encodedTxs = response.encodedTransactions {
///     for tx in encodedTxs { /* sign Solana tx */ }
/// }
/// ```
public class Delegations: DelegationsProtocol {
  private let api: PortalDelegationsApiProtocol

  /// Create an instance of Delegations.
  /// - Parameter api: The PortalDelegationsApi instance to use for delegation operations.
  public init(api: PortalDelegationsApiProtocol) {
    self.api = api
  }

  /// Approves a delegation for a specified token on a given chain.
  ///
  /// This method creates approval transactions that grant a delegate address the ability
  /// to transfer tokens on behalf of the owner. Returns transactions for EVM chains or
  /// encodedTransactions for Solana chains.
  ///
  /// - Parameter request: The approval request containing:
  ///   - `chain`: CAIP-2 chain ID (e.g., "eip155:11155111" or "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1")
  ///   - `token`: Token symbol or address (e.g., "USDC" or a contract address)
  ///   - `delegateAddress`: The address to delegate to
  ///   - `amount`: The amount to delegate
  /// - Returns: Response containing transaction data and approval metadata
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func approve(request: ApproveDelegationRequest) async throws -> ApproveDelegationResponse {
    try await api.approve(request: request)
  }

  /// Revokes a delegation for a specified token on a given chain.
  ///
  /// This method creates revocation transactions that remove a delegate's ability to
  /// transfer tokens on behalf of the owner. Returns transactions for EVM chains or
  /// encodedTransactions for Solana chains.
  ///
  /// - Parameter request: The revocation request containing:
  ///   - `chain`: CAIP-2 chain ID
  ///   - `token`: Token symbol or address
  ///   - `delegateAddress`: The address to revoke delegation from
  /// - Returns: Response containing transaction data and revocation metadata
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func revoke(request: RevokeDelegationRequest) async throws -> RevokeDelegationResponse {
    try await api.revoke(request: request)
  }

  /// Retrieves the delegation status for a specified token and delegate address.
  ///
  /// This method queries the current delegation state for a token, including balance
  /// information and active delegations with their allowed amounts.
  ///
  /// - Parameter request: The status query containing:
  ///   - `chain`: CAIP-2 chain ID
  ///   - `token`: Token symbol or address
  ///   - `delegateAddress`: The delegate address to query status for
  /// - Returns: Response containing chainId, token info, balance, and delegations array
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func getStatus(request: GetDelegationStatusRequest) async throws -> DelegationStatusResponse {
    try await api.getStatus(request: request)
  }

  /// Transfers tokens from one address to another using delegated authority.
  ///
  /// The caller must have been previously approved as a delegate. The transfer amount
  /// must not exceed the approved allowance. Returns transactions for EVM chains or
  /// encodedTransactions for Solana chains.
  ///
  /// - Parameter request: The transfer request containing:
  ///   - `chain`: CAIP-2 chain ID
  ///   - `token`: Token symbol or address
  ///   - `fromAddress`: The owner's address (who approved the delegation)
  ///   - `toAddress`: The recipient's address
  ///   - `amount`: The amount to transfer
  /// - Returns: Response containing transaction data and transfer metadata (metadata is non-optional)
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func transferFrom(request: TransferFromRequest) async throws -> TransferFromResponse {
    try await api.transferFrom(request: request)
  }
}
