//
//  NoahSimulatePayinRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Request body for `POST /integrations/noah/payins/simulate`.
public struct NoahSimulatePayinRequest: Codable {
  public let paymentMethodId: String
  public let fiatAmount: String
  public let fiatCurrency: String

  public init(
    paymentMethodId: String,
    fiatAmount: String,
    fiatCurrency: String
  ) {
    self.paymentMethodId = paymentMethodId
    self.fiatAmount = fiatAmount
    self.fiatCurrency = fiatCurrency
  }
}
