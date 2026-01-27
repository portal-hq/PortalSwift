//
//  BlockaidScanSolanaRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - BlockaidScanSolanaRequest

public struct BlockaidScanSolanaRequest: Codable {
  public let accountAddress: String
  public let transactions: [String]
  public let metadata: BlockaidScanSolanaMetadata?
  public let encoding: BlockaidScanSolanaEncoding?
  public let chain: String
  public let options: [BlockaidScanSolanaOption]?
  public let method: String?

  private enum CodingKeys: String, CodingKey {
    case accountAddress = "account_address"
    case transactions, metadata, encoding, chain, options, method
  }

  public init(
    accountAddress: String,
    transactions: [String],
    metadata: BlockaidScanSolanaMetadata? = nil,
    encoding: BlockaidScanSolanaEncoding? = nil,
    chain: String,
    options: [BlockaidScanSolanaOption]? = nil,
    method: String? = nil
  ) {
    self.accountAddress = accountAddress
    self.transactions = transactions
    self.metadata = metadata
    self.encoding = encoding
    self.chain = chain
    self.options = options
    self.method = method
  }
}

// MARK: - BlockaidScanSolanaMetadata

public struct BlockaidScanSolanaMetadata: Codable {
  public let url: String?

  public init(url: String? = nil) {
    self.url = url
  }
}

// MARK: - BlockaidScanSolanaEncoding

public enum BlockaidScanSolanaEncoding: String, Codable {
  case base58
  case base64
}

// MARK: - BlockaidScanSolanaOption

public enum BlockaidScanSolanaOption: String, Codable {
  case simulation
  case validation
}
