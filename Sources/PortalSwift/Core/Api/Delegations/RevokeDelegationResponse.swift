//
//  RevokeDelegationResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - RevokeDelegationResponse

/// Response from the revoke delegation endpoint.
/// For EVM chains, `transactions` is populated. For Solana chains, `encodedTransactions` is populated.
public struct RevokeDelegationResponse: Codable {
  /// Array of constructed EVM transactions (populated for EVM chains)
  public let transactions: [ConstructedEipTransaction]?
  /// Array of encoded Solana transaction strings (populated for Solana chains)
  public let encodedTransactions: [String]?
  /// Metadata about the revocation operation
  public let metadata: RevokeDelegationMetadata?

  public init(
    transactions: [ConstructedEipTransaction]? = nil,
    encodedTransactions: [String]? = nil,
    metadata: RevokeDelegationMetadata? = nil
  ) {
    self.transactions = transactions
    self.encodedTransactions = encodedTransactions
    self.metadata = metadata
  }
}

// MARK: - RevokeDelegationMetadata

/// Metadata returned with a revoke delegation response.
public struct RevokeDelegationMetadata: Codable {
  public let chainId: String
  public let revokedAddress: String
  public let tokenSymbol: String
  public let tokenAddress: String?
  public let ownerAddress: String?
  public let tokenAccount: String?

  public init(
    chainId: String,
    revokedAddress: String,
    tokenSymbol: String,
    tokenAddress: String? = nil,
    ownerAddress: String? = nil,
    tokenAccount: String? = nil
  ) {
    self.chainId = chainId
    self.revokedAddress = revokedAddress
    self.tokenSymbol = tokenSymbol
    self.tokenAddress = tokenAddress
    self.ownerAddress = ownerAddress
    self.tokenAccount = tokenAccount
  }
}
