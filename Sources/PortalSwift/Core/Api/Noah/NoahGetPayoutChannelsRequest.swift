//
//  NoahGetPayoutChannelsRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Query parameters for `GET /integrations/noah/payouts/channels`.
///
/// `pageToken` is forwarded to Noah's pagination cursor. Use the
/// `pageToken` returned in the previous response to fetch the next page.
public struct NoahGetPayoutChannelsRequest: Codable {
  public let country: String
  public let cryptoCurrency: String
  public let fiatCurrency: String
  public let fiatAmount: String?
  public let pageToken: String?

  public init(
    country: String,
    cryptoCurrency: String,
    fiatCurrency: String,
    fiatAmount: String? = nil,
    pageToken: String? = nil
  ) {
    self.country = country
    self.cryptoCurrency = cryptoCurrency
    self.fiatCurrency = fiatCurrency
    self.fiatAmount = fiatAmount
    self.pageToken = pageToken
  }
}
