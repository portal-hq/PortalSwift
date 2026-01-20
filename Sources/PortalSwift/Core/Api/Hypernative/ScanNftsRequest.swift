//
//  ScanNftsRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - ScanNftsRequest

public struct ScanNftsRequest: Codable {
  public let nfts: [ScanNftsRequestItem]

  public init(nfts: [ScanNftsRequestItem]) {
    self.nfts = nfts
  }
}

public struct ScanNftsRequestItem: Codable {
  public let address: String
  public let chain: String?
  public let evmChainId: String?

  public init(address: String, chain: String? = nil, evmChainId: String? = nil) {
    self.address = address
    self.chain = chain
    self.evmChainId = evmChainId
  }
}
