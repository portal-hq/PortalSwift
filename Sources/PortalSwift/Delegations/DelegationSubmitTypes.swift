//
//  DelegationSubmitTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//
//  Supporting types for the high-level delegation submit methods
//  (approveAndSubmit / revokeAndSubmit / transferAndSubmit).
//

import Foundation

// MARK: - DelegationTransaction

/// A single transaction to be signed and broadcast by a delegation submit flow.
///
/// Delegation endpoints return either EVM transaction objects or base64-encoded Solana transaction
/// strings. This enum models both shapes in a type-safe way (avoiding `Any`).
public enum DelegationTransaction: Equatable {
  /// An EVM transaction, signed and sent via `eth_sendTransaction`.
  case evm(ConstructedEipTransaction)
  /// A base64-encoded Solana transaction, signed and sent via `sol_signAndSendTransaction`.
  case solana(String)

  /// The EVM transaction, if this is an `.evm` case.
  public var evmTransaction: ConstructedEipTransaction? {
    if case let .evm(transaction) = self { return transaction }
    return nil
  }

  /// The encoded Solana transaction, if this is a `.solana` case.
  public var solanaTransaction: String? {
    if case let .solana(encoded) = self { return encoded }
    return nil
  }
}

// MARK: - DelegationSignAndSend

/// Signer function used by the high-level delegation submit methods.
///
/// Receives a single `DelegationTransaction` (EVM object or Solana encoded string) and the CAIP-2
/// chain ID, signs and broadcasts it, and returns the resulting transaction hash.
public typealias DelegationSignAndSend = (_ transaction: DelegationTransaction, _ chainId: String) async throws -> String

// MARK: - DelegationSubmitStep

/// The step of a high-level delegation submit flow, emitted via `DelegationSubmitOptions.onProgress`.
public enum DelegationSubmitStep: String, Equatable {
  /// A transaction is about to be signed and sent.
  case signing
  /// A transaction has been broadcast and a hash was returned.
  case submitted
}

// MARK: - DelegationSubmitProgress

/// Progress event emitted during a high-level delegation submit flow.
public struct DelegationSubmitProgress: Equatable {
  /// The current step (`.signing` or `.submitted`).
  public let step: DelegationSubmitStep
  /// The 0-based index of the transaction within the sequence.
  public let index: Int
  /// The total number of transactions in the sequence.
  public let total: Int
  /// The transaction hash (only present on `.submitted`).
  public let hash: String?

  public init(step: DelegationSubmitStep, index: Int, total: Int, hash: String? = nil) {
    self.step = step
    self.index = index
    self.total = total
    self.hash = hash
  }
}

// MARK: - DelegationSubmitResult

/// Result of a high-level delegation submit flow.
public struct DelegationSubmitResult: Equatable {
  /// The transaction hashes, one per broadcast transaction, in submission order.
  public let hashes: [String]

  public init(hashes: [String]) {
    self.hashes = hashes
  }
}

// MARK: - DelegationSubmitOptions

/// Per-call options for the high-level delegation submit methods.
public struct DelegationSubmitOptions {
  /// Optional per-call signer override. When provided, it takes precedence over the instance-level
  /// signer configured via `Delegations.setSignAndSendTransaction(_:)`.
  public let signAndSendTransaction: DelegationSignAndSend?
  /// Optional callback invoked with `DelegationSubmitProgress` events as each transaction is signed
  /// and submitted.
  public let onProgress: ((DelegationSubmitProgress) -> Void)?

  public init(
    signAndSendTransaction: DelegationSignAndSend? = nil,
    onProgress: ((DelegationSubmitProgress) -> Void)? = nil
  ) {
    self.signAndSendTransaction = signAndSendTransaction
    self.onProgress = onProgress
  }
}

// MARK: - DelegationsError

/// Errors specific to the high-level delegation submit flows.
public enum DelegationsError: LocalizedError, Equatable {
  /// No signer was configured via options or `Delegations.setSignAndSendTransaction(_:)`.
  case noSignerConfigured
  /// The delegation response contained no transactions to sign.
  case noTransactions
  /// The signer returned an empty or invalid transaction hash.
  case invalidTransactionHash(index: Int, chainId: String)

  public var errorDescription: String? {
    switch self {
    case .noSignerConfigured:
      return "[Delegations] No signer configured. Call setSignAndSendTransaction() on the instance or pass signAndSendTransaction in options."
    case .noTransactions:
      return "No transactions in delegation response."
    case let .invalidTransactionHash(index, chainId):
      return "Invalid transaction hash returned from signAndSendTransaction at index \(index) for chain \(chainId)."
    }
  }
}
