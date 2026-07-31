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
  /// Optional explicit trigger. Accepts the Single, Permanent, or Quoted
  /// variant. When omitted, the BFF synthesises a Single trigger from the
  /// quote and the supplied `sourceAddress` / `expiry` / `nonce`.
  public let trigger: NoahOnchainDepositSourceTrigger?
  /// Optional business (partner) fee. Forwarded to Noah as `BusinessFee`.
  public let businessFee: NoahBusinessFee?

  public init(
    payoutId: String,
    sourceAddress: String,
    expiry: String,
    nonce: String,
    network: String,
    trigger: NoahOnchainDepositSourceTrigger? = nil,
    businessFee: NoahBusinessFee? = nil
  ) {
    self.payoutId = payoutId
    self.sourceAddress = sourceAddress
    self.expiry = expiry
    self.nonce = nonce
    self.network = network
    self.trigger = trigger
    self.businessFee = businessFee
  }
}
