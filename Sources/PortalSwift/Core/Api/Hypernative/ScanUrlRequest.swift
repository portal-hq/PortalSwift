//
//  ScanUrlRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - ScanUrlRequest

public struct ScanUrlRequest: Codable {
  public let url: String

  public init(url: String) {
    self.url = url
  }
}
