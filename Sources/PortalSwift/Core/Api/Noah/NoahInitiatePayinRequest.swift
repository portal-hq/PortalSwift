//
//  NoahInitiatePayinRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Request body for `POST /integrations/noah/payins`.
public struct NoahInitiatePayinRequest: Codable {
  public let fiatCurrency: String
  public let cryptoCurrency: String
  public let network: String
  public let destinationAddress: String
  /// Optional per-payment-method business (partner) fees, keyed by payment
  /// method type. Forwarded to Noah as `BusinessFees`.
  public let businessFees: [String: NoahBusinessFee]?

  public init(
    fiatCurrency: String,
    cryptoCurrency: String,
    network: String,
    destinationAddress: String,
    businessFees: [String: NoahBusinessFee]? = nil
  ) {
    self.fiatCurrency = fiatCurrency
    self.cryptoCurrency = cryptoCurrency
    self.network = network
    self.destinationAddress = destinationAddress
    self.businessFees = businessFees
  }
}
