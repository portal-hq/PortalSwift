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
  /// The response data containing the raw response with sources.
  public let data: ZeroXSourcesData?
  /// Error message if the request failed.
  public let error: String?

  public init(data: ZeroXSourcesData? = nil, error: String? = nil) {
    self.data = data
    self.error = error
  }
}

/// Data model containing the raw response with sources.
public struct ZeroXSourcesData: Codable {
  /// The raw response from ZeroX containing sources and zid.
  public let rawResponse: ZeroXSourcesRawResponse

  public init(rawResponse: ZeroXSourcesRawResponse) {
    self.rawResponse = rawResponse
  }
}

/// Raw response model from ZeroX containing the list of sources and zid.
public struct ZeroXSourcesRawResponse: Codable {
  /// List of available swap source names (e.g., ["Uniswap", "Sushiswap", "Curve"]).
  public let sources: [String]
  /// ZeroX identifier (zid) for the response.
  public let zid: String

  public init(sources: [String], zid: String) {
    self.sources = sources
    self.zid = zid
  }
}

