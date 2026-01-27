//
//  BlockaidScanAddressRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - BlockaidScanAddressRequest

public struct BlockaidScanAddressRequest: Codable {
  public let address: String
  public let chain: String
  public let metadata: BlockaidScanAddressMetadata?

  public init(
    address: String,
    chain: String,
    metadata: BlockaidScanAddressMetadata? = nil
  ) {
    self.address = address
    self.chain = chain
    self.metadata = metadata
  }
}

// MARK: - BlockaidScanAddressMetadata

public struct BlockaidScanAddressMetadata: Codable {
  public let domain: String?

  public init(domain: String? = nil) {
    self.domain = domain
  }
}
