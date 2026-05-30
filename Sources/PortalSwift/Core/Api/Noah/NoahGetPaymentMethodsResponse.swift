//
//  NoahGetPaymentMethodsResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Response from `GET /integrations/noah/payouts/payment-methods`.
public struct NoahGetPaymentMethodsResponse: Codable {
  public let data: NoahGetPaymentMethodsData
  public let metadata: NoahResponseMetadata?

  public init(data: NoahGetPaymentMethodsData, metadata: NoahResponseMetadata? = nil) {
    self.data = data
    self.metadata = metadata
  }
}

/// The `data` payload of a Noah get-payment-methods response.
public struct NoahGetPaymentMethodsData: Codable {
  public let paymentMethods: [NoahPaymentMethod]
  public let pageToken: String?

  public init(paymentMethods: [NoahPaymentMethod], pageToken: String? = nil) {
    self.paymentMethods = paymentMethods
    self.pageToken = pageToken
  }
}
