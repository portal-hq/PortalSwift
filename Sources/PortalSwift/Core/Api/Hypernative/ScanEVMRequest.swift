//
//  ScanEVMRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - ScanEVMRequest

public struct ScanEVMRequest: Codable {
  public let transaction: ScanEVMTransaction
  public let url: String?
  public let blockNumber: Int?
  public let validateNonce: Bool?
  public let showFullFindings: Bool?
  public let policy: String?

  public init(
    transaction: ScanEVMTransaction,
    url: String? = nil,
    blockNumber: Int? = nil,
    validateNonce: Bool? = nil,
    showFullFindings: Bool? = nil,
    policy: String? = nil
  ) {
    self.transaction = transaction
    self.url = url
    self.blockNumber = blockNumber
    self.validateNonce = validateNonce
    self.showFullFindings = showFullFindings
    self.policy = policy
  }
}

// MARK: - ScanEVMTransaction

public struct ScanEVMTransaction: Codable {
  public let chain: String
  public let fromAddress: String
  public let toAddress: String
  public let input: String?
  public let value: Int?
  public let nonce: Int?
  public let hash: String?
  public let gas: Int?
  public let gasPrice: Int?
  public let maxPriorityFeePerGas: Int?
  public let maxFeePerGas: Int?

  public init(
    chain: String,
    fromAddress: String,
    toAddress: String,
    input: String? = nil,
    value: Int? = nil,
    nonce: Int? = nil,
    hash: String? = nil,
    gas: Int? = nil,
    gasPrice: Int? = nil,
    maxPriorityFeePerGas: Int? = nil,
    maxFeePerGas: Int? = nil
  ) {
    self.chain = chain
    self.fromAddress = fromAddress
    self.toAddress = toAddress
    self.input = input
    self.value = value
    self.nonce = nonce
    self.hash = hash
    self.gas = gas
    self.gasPrice = gasPrice
    self.maxPriorityFeePerGas = maxPriorityFeePerGas
    self.maxFeePerGas = maxFeePerGas
  }
}
