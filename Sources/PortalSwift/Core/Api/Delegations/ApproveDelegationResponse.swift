//
//  ApproveDelegationResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - ApproveDelegationResponse

/// Response from the approve delegation endpoint.
/// For EVM chains, `transactions` is populated. For Solana chains, `encodedTransactions` is populated.
public struct ApproveDelegationResponse: Codable {
  /// Array of constructed EVM transactions (populated for EVM chains)
  public let transactions: [ConstructedEipTransaction]?
  /// Array of encoded Solana transaction strings (populated for Solana chains)
  public let encodedTransactions: [String]?
  /// Metadata about the approval operation
  public let metadata: ApproveDelegationMetadata?

  public init(
    transactions: [ConstructedEipTransaction]? = nil,
    encodedTransactions: [String]? = nil,
    metadata: ApproveDelegationMetadata? = nil
  ) {
    self.transactions = transactions
    self.encodedTransactions = encodedTransactions
    self.metadata = metadata
  }
}

// MARK: - ApproveDelegationMetadata

/// Metadata returned with an approve delegation response.
public struct ApproveDelegationMetadata: Codable {
  public let chainId: String
  public let delegateAmount: String
  public let delegateAmountRaw: String?
  public let delegateAddress: String
  public let tokenSymbol: String
  public let tokenAddress: String?
  public let ownerAddress: String?
  public let tokenAccount: String?
  public let tokenMint: String?
  public let tokenDecimals: Int?
  public let lastValidBlockHeight: String?
  public let serializedTransactionBase64Encoded: String?
  public let serializedTransactionBase58Encoded: String?

  public init(
    chainId: String,
    delegateAmount: String,
    delegateAmountRaw: String? = nil,
    delegateAddress: String,
    tokenSymbol: String,
    tokenAddress: String? = nil,
    ownerAddress: String? = nil,
    tokenAccount: String? = nil,
    tokenMint: String? = nil,
    tokenDecimals: Int? = nil,
    lastValidBlockHeight: String? = nil,
    serializedTransactionBase64Encoded: String? = nil,
    serializedTransactionBase58Encoded: String? = nil
  ) {
    self.chainId = chainId
    self.delegateAmount = delegateAmount
    self.delegateAmountRaw = delegateAmountRaw
    self.delegateAddress = delegateAddress
    self.tokenSymbol = tokenSymbol
    self.tokenAddress = tokenAddress
    self.ownerAddress = ownerAddress
    self.tokenAccount = tokenAccount
    self.tokenMint = tokenMint
    self.tokenDecimals = tokenDecimals
    self.lastValidBlockHeight = lastValidBlockHeight
    self.serializedTransactionBase64Encoded = serializedTransactionBase64Encoded
    self.serializedTransactionBase58Encoded = serializedTransactionBase58Encoded
  }
}
