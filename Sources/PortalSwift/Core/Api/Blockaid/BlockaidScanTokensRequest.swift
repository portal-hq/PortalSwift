//
//  BlockaidScanTokensRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - BlockaidScanTokensRequest

public struct BlockaidScanTokensRequest: Codable {
  public let chain: String
  public let tokens: [String]
  public let metadata: BlockaidTokenMetadata?

  public init(
    chain: String,
    tokens: [String],
    metadata: BlockaidTokenMetadata? = nil
  ) {
    self.chain = chain
    self.tokens = tokens
    self.metadata = metadata
  }
}

// MARK: - BlockaidTokenMetadata

public struct BlockaidTokenMetadata: Codable {
  public let domain: String?

  public init(domain: String? = nil) {
    self.domain = domain
  }
}
