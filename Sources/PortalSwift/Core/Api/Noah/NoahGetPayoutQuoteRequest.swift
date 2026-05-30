//
//  NoahGetPayoutQuoteRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import AnyCodable
import Foundation

/// Request body for `POST /integrations/noah/payouts/quote`.
public struct NoahGetPayoutQuoteRequest: Codable {
  public let channelId: String
  public let cryptoCurrency: String
  public let fiatAmount: String
  public let form: [String: AnyCodable]? // TODO: revisit -- strongly type once backend schema is finalized
  public let fiatCurrency: String?
  public let paymentMethodId: String?

  public init(
    channelId: String,
    cryptoCurrency: String,
    fiatAmount: String,
    form: [String: AnyCodable]? = nil,
    fiatCurrency: String? = nil,
    paymentMethodId: String? = nil
  ) {
    self.channelId = channelId
    self.cryptoCurrency = cryptoCurrency
    self.fiatAmount = fiatAmount
    self.form = form
    self.fiatCurrency = fiatCurrency
    self.paymentMethodId = paymentMethodId
  }
}
