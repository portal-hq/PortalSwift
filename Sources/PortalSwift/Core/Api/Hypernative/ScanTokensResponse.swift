//
//  ScanTokensResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - ScanTokensResponse

public struct ScanTokensResponse: Codable {
  public let data: ScanTokensData?
  public let error: String?
}

public struct ScanTokensData: Codable {
  public let rawResponse: ScanTokensRawResponse
}

public struct ScanTokensRawResponse: Codable {
  public let success: Bool
  public let data: ScanTokensDataContent?
  public let error: String?
  public let version: String?
  public let service: String?
}

public struct ScanTokensDataContent: Codable {
  public let tokens: [ScanTokensResponseItem]
}

public struct ScanTokensResponseItem: Codable {
  public let address: String
  public let chain: String
  public let reputation: ScanTokensReputation?
}

public struct ScanTokensReputation: Codable {
  public let recommendation: String
}
