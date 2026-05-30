//
//  NoahInitiatePayoutRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Request body for `POST /integrations/noah/payouts`.
public struct NoahInitiatePayoutRequest: Codable {
  public let payoutId: String
  public let sourceAddress: String
  public let expiry: String
  public let nonce: String
  public let network: String
  public let trigger: NoahSingleOnchainDepositSourceTriggerInput?

  public init(
    payoutId: String,
    sourceAddress: String,
    expiry: String,
    nonce: String,
    network: String,
    trigger: NoahSingleOnchainDepositSourceTriggerInput? = nil
  ) {
    self.payoutId = payoutId
    self.sourceAddress = sourceAddress
    self.expiry = expiry
    self.nonce = nonce
    self.network = network
    self.trigger = trigger
  }
}
