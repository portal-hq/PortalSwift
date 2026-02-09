//
//  ApproveDelegationRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - ApproveDelegationRequest

/// Request to approve a delegation for a specified token on a given chain.
public struct ApproveDelegationRequest: Codable {
  /// CAIP-2 chain ID (e.g., "eip155:11155111" or "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1")
  public let chain: String
  /// Token symbol or address (e.g., "USDC" or a contract address)
  public let token: String
  /// The address to delegate to
  public let delegateAddress: String
  /// The amount to delegate (e.g., "1.0")
  public let amount: String

  public init(
    chain: String,
    token: String,
    delegateAddress: String,
    amount: String
  ) {
    self.chain = chain
    self.token = token
    self.delegateAddress = delegateAddress
    self.amount = amount
  }
}
