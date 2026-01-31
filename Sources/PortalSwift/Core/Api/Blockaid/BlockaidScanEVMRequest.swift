//
//  BlockaidScanEVMRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - BlockaidScanEVMRequest

public struct BlockaidScanEVMRequest: Codable {
  public let chain: String
  public let metadata: BlockaidScanEVMMetadata?
  public let data: BlockaidScanEVMTransactionData
  public let options: [BlockaidScanEVMOption]?
  public let block: String?

  public init(
    chain: String,
    metadata: BlockaidScanEVMMetadata? = nil,
    data: BlockaidScanEVMTransactionData,
    options: [BlockaidScanEVMOption]? = nil,
    block: String? = nil
  ) {
    self.chain = chain
    self.metadata = metadata
    self.data = data
    self.options = options
    self.block = block
  }
}

// MARK: - BlockaidScanEVMTransactionData

public struct BlockaidScanEVMTransactionData: Codable {
  public let from: String
  public let to: String?
  public let data: String?
  public let value: String?
  public let gas: String?
  public let gasPrice: String?

  private enum CodingKeys: String, CodingKey {
    case from, to, data, value, gas
    case gasPrice = "gas_price"
  }

  public init(
    from: String,
    to: String? = nil,
    data: String? = nil,
    value: String? = nil,
    gas: String? = nil,
    gasPrice: String? = nil
  ) {
    self.from = from
    self.to = to
    self.data = data
    self.value = value
    self.gas = gas
    self.gasPrice = gasPrice
  }
}

// MARK: - BlockaidScanEVMMetadata

public struct BlockaidScanEVMMetadata: Codable {
  public let domain: String?

  public init(domain: String? = nil) {
    self.domain = domain
  }
}

// MARK: - BlockaidScanEVMOption

public enum BlockaidScanEVMOption: String, Codable {
  case simulation
  case validation
  case gasEstimation = "gas_estimation"
  case events
}
