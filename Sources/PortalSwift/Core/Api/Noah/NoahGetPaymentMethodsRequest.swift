//
//  NoahGetPaymentMethodsRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Query parameters for `GET /integrations/noah/payouts/payment-methods`.
///
/// All parameters are optional; omitting them lets connect-api fall back to
/// its server-side defaults (`pageSize` defaults to whatever Noah uses).
///
/// - `pageSize`: clamped to the range `[1, 100]` by connect-api.
/// - `pageToken`: cursor from a previous response's `data.pageToken`.
/// - `capability`: filter the payment methods by what they can be used for.
public struct NoahGetPaymentMethodsRequest: Codable {
  public let pageSize: Int?
  public let pageToken: String?
  public let capability: NoahPaymentMethodCapability?

  public init(
    pageSize: Int? = nil,
    pageToken: String? = nil,
    capability: NoahPaymentMethodCapability? = nil
  ) {
    self.pageSize = pageSize
    self.pageToken = pageToken
    self.capability = capability
  }
}
