//
//  ZeroXSourcesResponse.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2024 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// Response model containing available swap sources from ZeroX.
public struct ZeroXSourcesResponse: Codable {
  /// The response data containing the list of sources.
  public let data: ZeroXSourcesData

  public init(data: ZeroXSourcesData) {
    self.data = data
  }
}

/// Data model containing the list of available swap sources.
public struct ZeroXSourcesData: Codable {
  /// List of available swap source names (e.g., ["Uniswap", "Sushiswap"]).
  public let sources: [String]

  public init(sources: [String]) {
    self.sources = sources
  }
}

