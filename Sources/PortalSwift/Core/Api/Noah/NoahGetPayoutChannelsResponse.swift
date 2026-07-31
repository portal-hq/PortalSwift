//
//  NoahGetPayoutChannelsResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Response from `GET /integrations/noah/payouts/channels`.
public struct NoahGetPayoutChannelsResponse: Codable {
  public let data: NoahGetPayoutChannelsData
  public let metadata: NoahResponseMetadata?

  public init(data: NoahGetPayoutChannelsData, metadata: NoahResponseMetadata? = nil) {
    self.data = data
    self.metadata = metadata
  }
}

/// The `data` payload of a Noah get-payout-channels response.
public struct NoahGetPayoutChannelsData: Codable {
  public let items: [NoahChannel]
  public let pageToken: String?

  public init(items: [NoahChannel], pageToken: String? = nil) {
    self.items = items
    self.pageToken = pageToken
  }
}
