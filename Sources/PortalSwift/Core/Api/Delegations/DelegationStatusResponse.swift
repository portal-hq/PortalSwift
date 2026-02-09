//
//  DelegationStatusResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - DelegationStatusResponse

/// Response from the get delegation status endpoint.
public struct DelegationStatusResponse: Codable {
  public let chainId: String
  public let token: String
  public let tokenAddress: String
  public let tokenAccount: String?
  public let balance: String?
  public let balanceRaw: String?
  public let delegations: [DelegationStatus]

  public init(
    chainId: String,
    token: String,
    tokenAddress: String,
    tokenAccount: String? = nil,
    balance: String? = nil,
    balanceRaw: String? = nil,
    delegations: [DelegationStatus]
  ) {
    self.chainId = chainId
    self.token = token
    self.tokenAddress = tokenAddress
    self.tokenAccount = tokenAccount
    self.balance = balance
    self.balanceRaw = balanceRaw
    self.delegations = delegations
  }
}

// MARK: - DelegationStatus

/// Represents a single delegation entry with address and delegated amounts.
public struct DelegationStatus: Codable {
  public let address: String
  public let delegateAmount: String
  public let delegateAmountRaw: String

  public init(
    address: String,
    delegateAmount: String,
    delegateAmountRaw: String
  ) {
    self.address = address
    self.delegateAmount = delegateAmount
    self.delegateAmountRaw = delegateAmountRaw
  }
}
