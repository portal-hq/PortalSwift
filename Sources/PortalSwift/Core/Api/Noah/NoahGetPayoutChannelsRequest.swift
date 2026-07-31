//
//  NoahGetPayoutChannelsRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Query parameters for `GET /integrations/noah/payouts/channels`.
///
/// Only `cryptoCurrency` is required; `country` and `fiatCurrency` are optional
/// filters. `pageToken` is forwarded to Noah's pagination cursor — use the
/// `pageToken` returned in the previous response to fetch the next page.
public struct NoahGetPayoutChannelsRequest: Codable {
  public let cryptoCurrency: String
  public let country: String?
  public let fiatCurrency: String?
  public let fiatAmount: String?
  public let paymentMethodId: String?
  /// Page size between 1 and 100 (validated by the BFF).
  public let pageSize: Int?
  public let pageToken: String?

  public init(
    cryptoCurrency: String,
    country: String? = nil,
    fiatCurrency: String? = nil,
    fiatAmount: String? = nil,
    paymentMethodId: String? = nil,
    pageSize: Int? = nil,
    pageToken: String? = nil
  ) {
    self.cryptoCurrency = cryptoCurrency
    self.country = country
    self.fiatCurrency = fiatCurrency
    self.fiatAmount = fiatAmount
    self.paymentMethodId = paymentMethodId
    self.pageSize = pageSize
    self.pageToken = pageToken
  }
}
