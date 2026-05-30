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

  public init(
    fiatCurrency: String,
    cryptoCurrency: String,
    network: String,
    destinationAddress: String
  ) {
    self.fiatCurrency = fiatCurrency
    self.cryptoCurrency = cryptoCurrency
    self.network = network
    self.destinationAddress = destinationAddress
  }
}
