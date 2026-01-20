//
//  ScanTokensRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - ScanTokensRequest

public struct ScanTokensRequest: Codable {
  public let tokens: [ScanTokensRequestItem]

  public init(tokens: [ScanTokensRequestItem]) {
    self.tokens = tokens
  }
}

public struct ScanTokensRequestItem: Codable {
  public let address: String
  public let chain: String?
  public let evmChainId: String?

  public init(address: String, chain: String? = nil, evmChainId: String? = nil) {
    self.address = address
    self.chain = chain
    self.evmChainId = evmChainId
  }
}
