//
//  NoahGetPayoutQuoteRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import AnyCodable
import Foundation

/// Request body for `POST /integrations/noah/payouts/quote`.
///
/// Provide exactly one of `fiatAmount` or `cryptoAmount`; the BFF rejects
/// requests that set both or neither.
public struct NoahGetPayoutQuoteRequest: Codable {
  public let channelId: String
  public let cryptoCurrency: String
  /// Fiat amount to receive. Mutually exclusive with `cryptoAmount`.
  public let fiatAmount: String?
  /// Crypto amount to sell. Mutually exclusive with `fiatAmount`.
  public let cryptoAmount: String?
  /// Request a signed, rate-locked quote. Required to later submit a
  /// `QuotedOnchainDepositSourceTriggerInput` payout.
  public let quoted: Bool?
  public let form: [String: AnyCodable]? // TODO: revisit -- strongly type once backend schema is finalized
  public let fiatCurrency: String?
  public let paymentMethodId: String?
  /// Existing form session to continue (reuses a prepared payout intent for
  /// multi-step forms).
  public let formSessionId: String?
  /// Optional business (partner) fee. Forwarded to Noah as `BusinessFee`.
  public let businessFee: NoahBusinessFee?

  public init(
    channelId: String,
    cryptoCurrency: String,
    fiatAmount: String? = nil,
    cryptoAmount: String? = nil,
    quoted: Bool? = nil,
    form: [String: AnyCodable]? = nil,
    fiatCurrency: String? = nil,
    paymentMethodId: String? = nil,
    formSessionId: String? = nil,
    businessFee: NoahBusinessFee? = nil
  ) {
    self.channelId = channelId
    self.cryptoCurrency = cryptoCurrency
    self.fiatAmount = fiatAmount
    self.cryptoAmount = cryptoAmount
    self.quoted = quoted
    self.form = form
    self.fiatCurrency = fiatCurrency
    self.paymentMethodId = paymentMethodId
    self.formSessionId = formSessionId
    self.businessFee = businessFee
  }
}
