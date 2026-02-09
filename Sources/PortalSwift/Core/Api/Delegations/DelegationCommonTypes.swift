//
//  DelegationCommonTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - ConstructedEipTransaction

/// Represents a constructed EVM transaction returned by delegation endpoints.
public struct ConstructedEipTransaction: Codable {
  public let from: String
  public let to: String
  public let data: String?
  public let value: String?

  public init(
    from: String,
    to: String,
    data: String? = nil,
    value: String? = nil
  ) {
    self.from = from
    self.to = to
    self.data = data
    self.value = value
  }
}
