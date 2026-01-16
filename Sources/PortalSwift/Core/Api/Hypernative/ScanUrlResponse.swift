//
//  ScanUrlResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - ScanUrlResponse

public struct ScanUrlResponse: Codable {
  public let data: ScanUrlData?
  public let error: String?
}

public struct ScanUrlData: Codable {
  public let rawResponse: ScanUrlRawResponse
}

public struct ScanUrlRawResponse: Codable {
  public let success: Bool
  public let data: ScanUrlDataContent?
  public let error: String?
  public let version: String?
  public let service: String?
}

public struct ScanUrlDataContent: Codable {
  public let isMalicious: Bool
  public let deepScanTriggered: Bool?
}
