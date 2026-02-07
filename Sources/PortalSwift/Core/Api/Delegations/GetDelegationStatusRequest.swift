//
//  GetDelegationStatusRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - GetDelegationStatusRequest

/// Request to retrieve delegation status for a specified token and delegate address.
public struct GetDelegationStatusRequest: Codable {
  /// CAIP-2 chain ID (e.g., "eip155:11155111" or "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1")
  public let chain: String
  /// Token symbol or address (e.g., "USDC" or a contract address)
  public let token: String
  /// The delegate address to query status for
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
