//
//  NoahInitiateKycRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import AnyCodable
import Foundation

/// A fiat option offered to the customer during KYC.
public struct NoahFiatOption: Codable {
  public let fiatCurrencyCode: String

  public init(fiatCurrencyCode: String) {
    self.fiatCurrencyCode = fiatCurrencyCode
  }
}

/// Request body for `POST /integrations/noah/customers/kyc`.
public struct NoahInitiateKycRequest: Codable {
  public let returnUrl: String
  public let fiatOptions: [NoahFiatOption]?
  public let customerType: NoahCustomerType?
  public let metadata: [String: AnyCodable]? // TODO: revisit -- strongly type once backend schema is finalized
  public let form: [String: AnyCodable]? // TODO: revisit -- strongly type once backend schema is finalized

  public init(
    returnUrl: String,
    fiatOptions: [NoahFiatOption]? = nil,
    customerType: NoahCustomerType? = nil,
    metadata: [String: AnyCodable]? = nil,
    form: [String: AnyCodable]? = nil
  ) {
    self.returnUrl = returnUrl
    self.fiatOptions = fiatOptions
    self.customerType = customerType
    self.metadata = metadata
    self.form = form
  }
}
