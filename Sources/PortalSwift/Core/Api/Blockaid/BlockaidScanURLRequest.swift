//
//  BlockaidScanURLRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - BlockaidScanURLRequest

public struct BlockaidScanURLRequest: Codable {
  public let url: String
  public let metadata: BlockaidScanURLMetadata?

  public init(
    url: String,
    metadata: BlockaidScanURLMetadata? = nil
  ) {
    self.url = url
    self.metadata = metadata
  }
}

// MARK: - BlockaidScanURLMetadata

public struct BlockaidScanURLMetadata: Codable {
  public let type: BlockaidScanURLMetadataType?

  public init(type: BlockaidScanURLMetadataType? = nil) {
    self.type = type
  }
}

// MARK: - BlockaidScanURLMetadataType

public enum BlockaidScanURLMetadataType: String, Codable {
  case catalog
  case wallet
}
