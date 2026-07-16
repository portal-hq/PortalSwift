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

  /// Configures the default signer used by the high-level submit methods when no per-call override is given.
  /// - Parameter fn: The signer function that signs and broadcasts a transaction and returns its hash.
  func setSignAndSendTransaction(_ fn: @escaping DelegationSignAndSend)

  /// Approves a delegation and signs/broadcasts the resulting transaction(s) in one call.
  /// - Parameters:
  ///   - request: The approval request containing chain, token, delegateAddress, and amount
  ///   - options: Optional per-call signer override and progress callback
  /// - Returns: The broadcast transaction hashes
  /// - Throws: `DelegationsError` or network/signing errors
  func approveAndSubmit(request: ApproveDelegationRequest, options: DelegationSubmitOptions) async throws -> DelegationSubmitResult

  /// Revokes a delegation and signs/broadcasts the resulting transaction(s) in one call.
  /// - Parameters:
  ///   - request: The revocation request containing chain, token, and delegateAddress
  ///   - options: Optional per-call signer override and progress callback
  /// - Returns: The broadcast transaction hashes
  /// - Throws: `DelegationsError` or network/signing errors
  func revokeAndSubmit(request: RevokeDelegationRequest, options: DelegationSubmitOptions) async throws -> DelegationSubmitResult

  /// Executes a delegated transfer and signs/broadcasts the resulting transaction(s) in one call.
  /// - Parameters:
  ///   - request: The transfer request containing chain, token, fromAddress, toAddress, and amount
  ///   - options: Optional per-call signer override and progress callback
  /// - Returns: The broadcast transaction hashes
  /// - Throws: `DelegationsError` or network/signing errors
  func transferAndSubmit(request: TransferFromRequest, options: DelegationSubmitOptions) async throws -> DelegationSubmitResult
}

public extension DelegationsProtocol {
  /// Convenience overload allowing `approveAndSubmit` to be called without options.
  func approveAndSubmit(request: ApproveDelegationRequest) async throws -> DelegationSubmitResult {
    try await approveAndSubmit(request: request, options: DelegationSubmitOptions())
  }

  /// Convenience overload allowing `revokeAndSubmit` to be called without options.
  func revokeAndSubmit(request: RevokeDelegationRequest) async throws -> DelegationSubmitResult {
    try await revokeAndSubmit(request: request, options: DelegationSubmitOptions())
  }

  /// Convenience overload allowing `transferAndSubmit` to be called without options.
  func transferAndSubmit(request: TransferFromRequest) async throws -> DelegationSubmitResult {
    try await transferAndSubmit(request: request, options: DelegationSubmitOptions())
  }
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

  /// Instance-level signer used by the high-level submit methods when no per-call override is given.
  ///
  /// - Note: This is expected to be configured once (typically during `Portal` initialization) before
  ///   any submit call is made. Access is not synchronized, so reconfiguring it via
  ///   `setSignAndSendTransaction(_:)` while a submit call is in flight is not thread-safe. To vary
  ///   the signer per call, pass `DelegationSubmitOptions.signAndSendTransaction` instead.
  private var signAndSendTransactionFn: DelegationSignAndSend?

  /// Create an instance of Delegations.
  /// - Parameter api: The PortalDelegationsApi instance to use for delegation operations.
  public init(api: PortalDelegationsApiProtocol) {
    self.api = api
  }

  /// Configures the default signer used by `approveAndSubmit`, `revokeAndSubmit`, and
  /// `transferAndSubmit` when no per-call `DelegationSubmitOptions.signAndSendTransaction` is provided.
  ///
  /// Typically wired once during Portal initialization.
  /// - Parameter fn: The signer function that signs and broadcasts a transaction and returns its hash.
  public func setSignAndSendTransaction(_ fn: @escaping DelegationSignAndSend) {
    self.signAndSendTransactionFn = fn
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

  // MARK: - High-Level Submit Methods

  /// Approves a delegation and signs/broadcasts the resulting transaction(s) in one call.
  ///
  /// Constructs the approval transaction(s) via `approve`, then signs and submits each transaction
  /// sequentially. Confirmation is not awaited; callers can use `DelegationSubmitResult.hashes` to
  /// track confirmations themselves.
  public func approveAndSubmit(request: ApproveDelegationRequest, options: DelegationSubmitOptions) async throws -> DelegationSubmitResult {
    let signAndSend = try resolveSigner(options)
    let response = try await api.approve(request: request)
    return try await executeAndTrack(
      transactions: normalizeToTransactionList(transactions: response.transactions, encodedTransactions: response.encodedTransactions),
      chainId: request.chain,
      signAndSend: signAndSend,
      onProgress: options.onProgress
    )
  }

  /// Revokes a delegation and signs/broadcasts the resulting transaction(s) in one call.
  ///
  /// Constructs the revocation transaction(s) via `revoke`, then signs and submits each transaction
  /// sequentially. Confirmation is not awaited.
  public func revokeAndSubmit(request: RevokeDelegationRequest, options: DelegationSubmitOptions) async throws -> DelegationSubmitResult {
    let signAndSend = try resolveSigner(options)
    let response = try await api.revoke(request: request)
    return try await executeAndTrack(
      transactions: normalizeToTransactionList(transactions: response.transactions, encodedTransactions: response.encodedTransactions),
      chainId: request.chain,
      signAndSend: signAndSend,
      onProgress: options.onProgress
    )
  }

  /// Executes a delegated transfer and signs/broadcasts the resulting transaction(s) in one call.
  ///
  /// Constructs the transfer transaction(s) via `transferFrom`, then signs and submits each
  /// transaction sequentially. The caller must have been previously approved as a delegate.
  /// Confirmation is not awaited.
  public func transferAndSubmit(request: TransferFromRequest, options: DelegationSubmitOptions) async throws -> DelegationSubmitResult {
    let signAndSend = try resolveSigner(options)
    let response = try await api.transferFrom(request: request)
    return try await executeAndTrack(
      transactions: normalizeToTransactionList(transactions: response.transactions, encodedTransactions: response.encodedTransactions),
      chainId: request.chain,
      signAndSend: signAndSend,
      onProgress: options.onProgress
    )
  }

  // MARK: - Private Helpers

  /// Resolves the signer to use, preferring the per-call override, then the instance-level signer.
  /// - Throws: `DelegationsError.noSignerConfigured` if neither is configured.
  private func resolveSigner(_ options: DelegationSubmitOptions) throws -> DelegationSignAndSend {
    if let signer = options.signAndSendTransaction {
      return signer
    }
    if let signer = signAndSendTransactionFn {
      return signer
    }
    throw DelegationsError.noSignerConfigured
  }

  /// Normalizes a delegation response into a single ordered list of transactions to sign.
  ///
  /// Prefers EVM `transactions` when non-empty, otherwise falls back to Solana `encodedTransactions`.
  private func normalizeToTransactionList(transactions: [ConstructedEipTransaction]?, encodedTransactions: [String]?) -> [DelegationTransaction] {
    if let transactions, !transactions.isEmpty {
      return transactions.map { .evm($0) }
    }
    if let encodedTransactions, !encodedTransactions.isEmpty {
      return encodedTransactions.map { .solana($0) }
    }
    return []
  }

  /// Signs and broadcasts each transaction sequentially, emitting progress and collecting hashes.
  /// - Throws: `DelegationsError.noTransactions` if empty, or `DelegationsError.invalidTransactionHash`
  ///   if the signer returns an empty hash.
  private func executeAndTrack(
    transactions: [DelegationTransaction],
    chainId: String,
    signAndSend: DelegationSignAndSend,
    onProgress: ((DelegationSubmitProgress) -> Void)?
  ) async throws -> DelegationSubmitResult {
    guard !transactions.isEmpty else {
      throw DelegationsError.noTransactions
    }
    let total = transactions.count
    var hashes: [String] = []
    for (index, tx) in transactions.enumerated() {
      onProgress?(DelegationSubmitProgress(step: .signing, index: index, total: total))
      let hash = try await signAndSend(tx, chainId)
      guard !hash.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw DelegationsError.invalidTransactionHash(index: index, chainId: chainId)
      }
      hashes.append(hash)
      onProgress?(DelegationSubmitProgress(step: .submitted, index: index, total: total, hash: hash))
    }
    return DelegationSubmitResult(hashes: hashes)
  }
}
