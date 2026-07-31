//
//  NoahGetPayoutChannelFormResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import AnyCodable
import Foundation

/// Response from `GET /integrations/noah/payouts/channels/{channelId}/form`.
public struct NoahGetPayoutChannelFormResponse: Codable {
  public let data: NoahGetPayoutChannelFormData
  public let metadata: NoahResponseMetadata?

  public init(data: NoahGetPayoutChannelFormData, metadata: NoahResponseMetadata? = nil) {
    self.data = data
    self.metadata = metadata
  }
}

/// The `data` payload of a Noah get-payout-channel-form response.
public struct NoahGetPayoutChannelFormData: Codable {
  public let formSchema: [String: AnyCodable]? // TODO: revisit -- strongly type once backend schema is finalized
  public let formMetadata: NoahFormMetadata?

  public init(
    formSchema: [String: AnyCodable]? = nil,
    formMetadata: NoahFormMetadata? = nil
  ) {
    self.formSchema = formSchema
    self.formMetadata = formMetadata
  }
}
