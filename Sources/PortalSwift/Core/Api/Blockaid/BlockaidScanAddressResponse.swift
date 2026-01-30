//
//  BlockaidScanAddressResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - BlockaidScanAddressResponse

public struct BlockaidScanAddressResponse: Codable {
  public let data: BlockaidScanAddressData?
}

public struct BlockaidScanAddressData: Codable {
  public let rawResponse: BlockaidScanAddressRawResponse
}

public struct BlockaidScanAddressRawResponse: Codable {
  public let resultType: String
  public let features: [BlockaidAddressFeature]?
  public let error: String?

  private enum CodingKeys: String, CodingKey {
    case features, error
    case resultType = "result_type"
  }
}

// MARK: - BlockaidAddressFeature

public struct BlockaidAddressFeature: Codable {
  public let type: String
  public let featureId: String
  public let description: String

  private enum CodingKeys: String, CodingKey {
    case type, description
    case featureId = "feature_id"
  }
}
