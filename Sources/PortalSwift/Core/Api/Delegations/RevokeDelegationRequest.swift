//
//  RevokeDelegationRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - RevokeDelegationRequest

/// Request to revoke a delegation for a specified token on a given chain.
public struct RevokeDelegationRequest: Codable {
  /// CAIP-2 chain ID (e.g., "eip155:11155111" or "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1")
  public let chain: String
  /// Token symbol or address (e.g., "USDC" or a contract address)
  public let token: String
  /// The address to revoke delegation from
  public let delegateAddress: String

  public init(
    chain: String,
    token: String,
    delegateAddress: String
  ) {
    self.chain = chain
    self.token = token
    self.delegateAddress = delegateAddress
  }
}
