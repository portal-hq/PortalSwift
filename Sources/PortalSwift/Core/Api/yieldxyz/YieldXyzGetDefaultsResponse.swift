//
//  YieldXyzGetDefaultsResponse.swift
//  PortalSwift
//
//  Created by Portal Labs
//

import Foundation

/// Response from the Portal yield defaults endpoint.
///
/// The payload maps a `"{caip2}:{TOKEN}"` key (e.g. `"eip155:1:USDC"`) to the default yield
/// configured for that chain + token. Unlike most Yield.xyz endpoints, this payload is NOT
/// wrapped in `rawResponse`; the map lives directly under `data`.
public struct YieldXyzGetDefaultsResponse: Codable {
  public let data: [String: YieldXyzDefaultYieldEntry]?
  public let error: String?

  public init(data: [String: YieldXyzDefaultYieldEntry]? = nil, error: String? = nil) {
    self.data = data
    self.error = error
  }
}

/// A single default-yield entry for a `"{caip2}:{TOKEN}"` key.
public struct YieldXyzDefaultYieldEntry: Codable {
  public let yieldId: String?
  /// Populated only when the defaults request is made with `includeOpportunities = true`.
  public let opportunity: YieldXyzOpportunity?

  public init(yieldId: String? = nil, opportunity: YieldXyzOpportunity? = nil) {
    self.yieldId = yieldId
    self.opportunity = opportunity
  }
}
