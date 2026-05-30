//
//  NoahInitiatePayoutResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Response from `POST /integrations/noah/payouts`.
///
/// - Note: The BFF requires either a `trigger` on the request or a saved
///   payment method on the quote (via `paymentMethodId`). When `trigger` is
///   absent and the saved method is `SingleOnchainDepositSource`, the BFF
///   synthesises a default trigger with the supplied `expiry` / `nonce` /
///   `sourceAddress`.
public struct NoahInitiatePayoutResponse: Codable {
  public let data: NoahInitiatePayoutData
  public let metadata: NoahResponseMetadata?

  public init(data: NoahInitiatePayoutData, metadata: NoahResponseMetadata? = nil) {
    self.data = data
    self.metadata = metadata
  }
}

/// The `data` payload of a Noah initiate-payout response.
///
/// - `destinationAddress` is optional because the BFF derives it from
///   `conditions[0].destinationAddress` and falls back to `null` when the
///   shape is missing or malformed.
/// - `conditions` is optional because the upstream Noah workflow response
///   types it as optional; an empty workflow has no conditions.
public struct NoahInitiatePayoutData: Codable {
  public let destinationAddress: String?
  public let conditions: [NoahDepositSourceTriggerCondition]?

  public init(
    destinationAddress: String? = nil,
    conditions: [NoahDepositSourceTriggerCondition]? = nil
  ) {
    self.destinationAddress = destinationAddress
    self.conditions = conditions
  }
}
