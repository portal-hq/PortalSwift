//
//  NoahInitiatePayinResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Response from `POST /integrations/noah/payins`.
public struct NoahInitiatePayinResponse: Codable {
  public let data: NoahInitiatePayinData
  public let metadata: NoahResponseMetadata?

  public init(data: NoahInitiatePayinData, metadata: NoahResponseMetadata? = nil) {
    self.data = data
    self.metadata = metadata
  }
}

/// The `data` payload of a Noah initiate-payin response.
public struct NoahInitiatePayinData: Codable {
  public let payinId: String
  public let bankDetails: NoahBankDetails

  public init(payinId: String, bankDetails: NoahBankDetails) {
    self.payinId = payinId
    self.bankDetails = bankDetails
  }
}
