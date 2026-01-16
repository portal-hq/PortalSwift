//
//  ScanNftsResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - ScanNftsResponse

public struct ScanNftsResponse: Codable {
  public let data: ScanNftsData?
  public let error: String?
}

public struct ScanNftsData: Codable {
  public let rawResponse: ScanNftsRawResponse
}

public struct ScanNftsRawResponse: Codable {
  public let success: Bool
  public let data: ScanNftsDataContent?
  public let error: String?
  public let version: String?
  public let service: String?
}

public struct ScanNftsDataContent: Codable {
  public let nfts: [ScanNftsResponseItem]
}

public struct ScanNftsResponseItem: Codable {
  public let address: String
  public let evmChainId: String
  public let accept: Bool
  public let chain: String
}
