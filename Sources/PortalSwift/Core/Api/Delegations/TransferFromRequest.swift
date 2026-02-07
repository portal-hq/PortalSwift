//
//  TransferFromRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - TransferFromRequest

/// Request to transfer tokens using delegated authority.
/// The caller must have been previously approved as a delegate.
public struct TransferFromRequest: Codable {
  /// CAIP-2 chain ID (e.g., "eip155:11155111" or "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1")
  public let chain: String
  /// Token symbol or address (e.g., "USDC" or a contract address)
  public let token: String
  /// The owner's address (who approved the delegation)
  public let fromAddress: String
  /// The recipient's address
  public let toAddress: String
  /// The amount to transfer (e.g., "1.0")
  public let amount: String

  public init(
    chain: String,
    token: String,
    fromAddress: String,
    toAddress: String,
    amount: String
  ) {
    self.chain = chain
    self.token = token
    self.fromAddress = fromAddress
    self.toAddress = toAddress
    self.amount = amount
  }
}
