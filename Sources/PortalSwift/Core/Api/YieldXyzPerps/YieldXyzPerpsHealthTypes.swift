//
//  YieldXyzPerpsHealthTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// The Yield.xyz Perps API health.
public struct YieldXyzPerpsHealth: Codable, Equatable {
  public let status: YieldXyzPerpsHealthStatus
  public let timestamp: String

  public init(status: YieldXyzPerpsHealthStatus, timestamp: String) {
    self.status = status
    self.timestamp = timestamp
  }
}

/// The health of one venue.
public struct YieldXyzPerpsProviderHealth: Codable, Equatable {
  public let providerId: String
  public let state: YieldXyzPerpsProviderHealthState
  public let message: String?
  public let setAt: String?

  public init(providerId: String, state: YieldXyzPerpsProviderHealthState, message: String? = nil, setAt: String? = nil) {
    self.providerId = providerId
    self.state = state
    self.message = message
    self.setAt = setAt
  }
}

/// Per-venue health.
public struct YieldXyzPerpsProvidersHealth: Codable, Equatable {
  /// ISO-8601.
  public let generatedAt: String
  public let providers: [YieldXyzPerpsProviderHealth]

  public init(generatedAt: String, providers: [YieldXyzPerpsProviderHealth]) {
    self.generatedAt = generatedAt
    self.providers = providers
  }
}
