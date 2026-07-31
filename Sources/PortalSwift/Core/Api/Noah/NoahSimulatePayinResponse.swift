//
//  NoahSimulatePayinResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Response from `POST /integrations/noah/payins/simulate`.
///
/// - Important: This endpoint is **sandbox-only**. In production environments the
///   BFF rejects the call with an HTTP 400, which the SDK surfaces as
///   `PortalRequestsError.clientError` (not an HTTP 403).
public struct NoahSimulatePayinResponse: Codable {
  public let data: NoahSimulatePayinData
  public let metadata: NoahResponseMetadata?

  public init(data: NoahSimulatePayinData, metadata: NoahResponseMetadata? = nil) {
    self.data = data
    self.metadata = metadata
  }
}

/// The `data` payload of a Noah simulate-payin response.
public struct NoahSimulatePayinData: Codable {
  public let fiatDepositId: String
  /// Reference for the simulated deposit, when returned by Noah.
  public let reference: String?

  public init(fiatDepositId: String, reference: String? = nil) {
    self.fiatDepositId = fiatDepositId
    self.reference = reference
  }
}
