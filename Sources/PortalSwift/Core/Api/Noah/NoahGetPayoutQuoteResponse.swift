//
//  NoahGetPayoutQuoteResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Response from `POST /integrations/noah/payouts/quote`.
public struct NoahGetPayoutQuoteResponse: Codable {
  public let data: NoahGetPayoutQuoteData
  public let metadata: NoahResponseMetadata?

  public init(data: NoahGetPayoutQuoteData, metadata: NoahResponseMetadata? = nil) {
    self.data = data
    self.metadata = metadata
  }
}

/// The `data` payload of a Noah get-payout-quote response.
public struct NoahGetPayoutQuoteData: Codable {
  public let payoutId: String
  public let totalFee: String
  public let cryptoAmountEstimate: String
  public let formSessionId: String
  public let nextStep: NoahFormNextStep?

  public init(
    payoutId: String,
    totalFee: String,
    cryptoAmountEstimate: String,
    formSessionId: String,
    nextStep: NoahFormNextStep? = nil
  ) {
    self.payoutId = payoutId
    self.totalFee = totalFee
    self.cryptoAmountEstimate = cryptoAmountEstimate
    self.formSessionId = formSessionId
    self.nextStep = nextStep
  }
}
