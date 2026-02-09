//
//  TransferFromResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - TransferFromResponse

/// Response from the transfer-from delegation endpoint.
/// For EVM chains, `transactions` is populated. For Solana chains, `encodedTransactions` is populated.
public struct TransferFromResponse: Codable {
  /// Array of constructed EVM transactions (populated for EVM chains)
  public let transactions: [ConstructedEipTransaction]?
  /// Array of encoded Solana transaction strings (populated for Solana chains)
  public let encodedTransactions: [String]?
  /// Metadata about the transfer operation (non-optional)
  public let metadata: TransferAsDelegateMetadata

  public init(
    transactions: [ConstructedEipTransaction]? = nil,
    encodedTransactions: [String]? = nil,
    metadata: TransferAsDelegateMetadata
  ) {
    self.transactions = transactions
    self.encodedTransactions = encodedTransactions
    self.metadata = metadata
  }
}

// MARK: - TransferAsDelegateMetadata

/// Metadata returned with a transfer-from delegation response.
public struct TransferAsDelegateMetadata: Codable {
  public let amount: String
  public let amountRaw: String
  public let chainId: String
  public let delegateAddress: String?
  public let lastValidBlockHeight: String?
  public let needsRecipientTokenAccount: Bool?
  public let ownerAddress: String?
  public let recipientAddress: String?
  public let serializedTransactionBase58Encoded: String?
  public let serializedTransactionBase64Encoded: String?
  public let tokenAddress: String?
  public let tokenSymbol: String?
  public let tokenDecimals: Int?

  public init(
    amount: String,
    amountRaw: String,
    chainId: String,
    delegateAddress: String? = nil,
    lastValidBlockHeight: String? = nil,
    needsRecipientTokenAccount: Bool? = nil,
    ownerAddress: String? = nil,
    recipientAddress: String? = nil,
    serializedTransactionBase58Encoded: String? = nil,
    serializedTransactionBase64Encoded: String? = nil,
    tokenAddress: String? = nil,
    tokenSymbol: String? = nil,
    tokenDecimals: Int? = nil
  ) {
    self.amount = amount
    self.amountRaw = amountRaw
    self.chainId = chainId
    self.delegateAddress = delegateAddress
    self.lastValidBlockHeight = lastValidBlockHeight
    self.needsRecipientTokenAccount = needsRecipientTokenAccount
    self.ownerAddress = ownerAddress
    self.recipientAddress = recipientAddress
    self.serializedTransactionBase58Encoded = serializedTransactionBase58Encoded
    self.serializedTransactionBase64Encoded = serializedTransactionBase64Encoded
    self.tokenAddress = tokenAddress
    self.tokenSymbol = tokenSymbol
    self.tokenDecimals = tokenDecimals
  }
}
