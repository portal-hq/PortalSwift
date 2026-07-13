//
//  NoahInitiateKycResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Response from `POST /integrations/noah/customers/kyc`.
///
/// - Note: This endpoint is idempotent on the BFF. If a `NoahCustomer` record
///   already exists for the client, the previously stored `hostedUrl` is
///   returned regardless of KYC status (`Pending`, `Submitted`, `Approved`,
///   `Declined`, etc.). Do not expect a fresh KYC URL for an existing customer.
public struct NoahInitiateKycResponse: Codable {
  public let data: NoahInitiateKycData
  public let metadata: NoahResponseMetadata?

  public init(data: NoahInitiateKycData, metadata: NoahResponseMetadata? = nil) {
    self.data = data
    self.metadata = metadata
  }
}

/// The `data` payload of a Noah initiate-KYC response.
public struct NoahInitiateKycData: Codable {
  public let hostedUrl: String

  public init(hostedUrl: String) {
    self.hostedUrl = hostedUrl
  }
}
