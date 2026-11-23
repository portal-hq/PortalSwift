//
//  YieldXyzBorrowIntegrationTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import AnyCodable
import Foundation

/// A token of a lending market.
public struct YieldXyzBorrowToken: Codable, Equatable {
  /// The token contract; absent or `null` for a native token.
  public let address: String?
  public let symbol: String
  public let name: String
  public let decimals: Int
  public let logoURI: String?

  public init(address: String? = nil, symbol: String, name: String, decimals: Int, logoURI: String? = nil) {
    self.address = address
    self.symbol = symbol
    self.name = name
    self.decimals = decimals
    self.logoURI = logoURI
  }
}

/// Display metadata of an integration.
public struct YieldXyzBorrowIntegrationMetadata: Codable, Equatable {
  public let description: String
  public let externalLink: String
  public let logoURI: String

  public init(description: String, externalLink: String, logoURI: String) {
    self.description = description
    self.externalLink = externalLink
    self.logoURI = logoURI
  }
}

/// A lending action an integration supports, with the schema of its `args`.
public struct YieldXyzBorrowActionDefinition: Codable, Equatable {
  public let id: YieldXyzBorrowActionType
  public let label: String
  /// JSON-Schema-like description of the action's `args`, with UI hints (`label`, `placeholder`,
  /// `optionsRef`, …); passed through as returned.
  public let schema: [String: AnyCodable]

  public init(id: YieldXyzBorrowActionType, label: String, schema: [String: AnyCodable]) {
    self.id = id
    self.label = label
    self.schema = schema
  }
}

/// A lending protocol deployment (for example Aave or Morpho Blue).
public struct YieldXyzBorrowIntegration: Codable, Equatable {
  public let id: String
  public let providerId: String
  public let name: String
  /// CAIP-2 for chains Portal supports; the Yield.xyz network name otherwise.
  public let networks: [String]
  public let metadata: YieldXyzBorrowIntegrationMetadata
  public let actions: [YieldXyzBorrowActionDefinition]

  public init(
    id: String,
    providerId: String,
    name: String,
    networks: [String],
    metadata: YieldXyzBorrowIntegrationMetadata,
    actions: [YieldXyzBorrowActionDefinition]
  ) {
    self.id = id
    self.providerId = providerId
    self.name = name
    self.networks = networks
    self.metadata = metadata
    self.actions = actions
  }
}
