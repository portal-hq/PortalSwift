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

/// A single line item in a payout quote fee breakdown.
public struct NoahTransactionBreakdownItem: Codable {
  /// One of `"ChannelFee"`, `"BusinessFee"`, or `"Remaining"`.
  public let type: String
  public let amount: String

  public init(type: String, amount: String) {
    self.type = type
    self.amount = amount
  }
}

/// A signed payout quote that can be used to lock in a rate.
public struct NoahSellQuote: Codable {
  public let signedQuote: String
  public let expiry: String

  public init(signedQuote: String, expiry: String) {
    self.signedQuote = signedQuote
    self.expiry = expiry
  }
}

/// The `data` payload of a Noah get-payout-quote response.
public struct NoahGetPayoutQuoteData: Codable {
  public let payoutId: String
  public let totalFee: String
  public let cryptoAmountEstimate: String
  /// The crypto amount the client is authorized to send for this quote.
  public let cryptoAuthorizedAmount: String
  public let formSessionId: String
  /// Exchange rate applied to the quote, when returned by Noah.
  public let rate: String?
  /// Fee breakdown line items, when returned by Noah.
  public let breakdown: [NoahTransactionBreakdownItem]?
  /// Signed quote details, present for quoted (rate-locked) payouts.
  public let quote: NoahSellQuote?
  public let nextStep: NoahFormNextStep?

  public init(
    payoutId: String,
    totalFee: String,
    cryptoAmountEstimate: String,
    cryptoAuthorizedAmount: String,
    formSessionId: String,
    rate: String? = nil,
    breakdown: [NoahTransactionBreakdownItem]? = nil,
    quote: NoahSellQuote? = nil,
    nextStep: NoahFormNextStep? = nil
  ) {
    self.payoutId = payoutId
    self.totalFee = totalFee
    self.cryptoAmountEstimate = cryptoAmountEstimate
    self.cryptoAuthorizedAmount = cryptoAuthorizedAmount
    self.formSessionId = formSessionId
    self.rate = rate
    self.breakdown = breakdown
    self.quote = quote
    self.nextStep = nextStep
  }
}
