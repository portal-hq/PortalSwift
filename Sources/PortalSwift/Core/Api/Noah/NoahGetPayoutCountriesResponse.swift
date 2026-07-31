//
//  NoahGetPayoutCountriesResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Response from `GET /integrations/noah/payouts/countries`.
public struct NoahGetPayoutCountriesResponse: Codable {
  public let data: NoahGetPayoutCountriesData
  public let metadata: NoahResponseMetadata?

  public init(data: NoahGetPayoutCountriesData, metadata: NoahResponseMetadata? = nil) {
    self.data = data
    self.metadata = metadata
  }
}

/// The `data` payload of a Noah get-payout-countries response.
///
/// `countries` is keyed by country code and contains the list of fiat currency
/// codes supported in that country.
public struct NoahGetPayoutCountriesData: Codable {
  public let countries: [String: [String]]

  public init(countries: [String: [String]]) {
    self.countries = countries
  }
}
