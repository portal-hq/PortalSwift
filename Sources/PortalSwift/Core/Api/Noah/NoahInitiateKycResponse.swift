//
//  NoahInitiateKycResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Response from `POST /integrations/noah/customers/kyc`.
///
/// - Note: This endpoint is idempotent on the BFF: a customer already in `Approved`
///   or `Submitted` status will receive a return URL pointing at the post-KYC
///   destination instead of a fresh KYC URL.
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
