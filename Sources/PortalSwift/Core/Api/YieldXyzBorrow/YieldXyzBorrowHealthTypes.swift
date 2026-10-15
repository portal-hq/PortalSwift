//
//  YieldXyzBorrowHealthTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// The Yield.xyz Borrow API health.
public struct YieldXyzBorrowHealthStatus: Codable, Equatable {
  public let status: YieldXyzBorrowHealthStatusValue
  /// ISO 8601.
  public let timestamp: String

  public init(status: YieldXyzBorrowHealthStatusValue, timestamp: String) {
    self.status = status
    self.timestamp = timestamp
  }
}
