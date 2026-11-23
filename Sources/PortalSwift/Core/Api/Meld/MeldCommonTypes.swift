//
//  MeldCommonTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - Envelopes

/// The success envelope every Meld endpoint returns: `{ "data": ... }`.
public struct MeldResponse<T: Codable & Equatable>: Codable, Equatable {
  public let data: T

  public init(data: T) {
    self.data = data
  }
}

/// The success envelope of an endpoint whose `data` can be `null`: `{ "data": ... }`. A missing
/// `data` decodes as `nil` too.
public struct MeldNullableResponse<T: Codable & Equatable>: Codable, Equatable {
  public let data: T?

  public init(data: T?) {
    self.data = data
  }
}

// MARK: - Closed values

/// The kind of widget session. The Portal API accepts only these.
public enum MeldSessionType: String, Codable, Equatable {
  case buy = "BUY"
  case sell = "SELL"
  case transfer = "TRANSFER"
}

// MARK: - Open values

/// A Meld product category.
public struct MeldCategory: MeldOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let cryptoOnramp: Self = "CRYPTO_ONRAMP"
  public static let cryptoOfframp: Self = "CRYPTO_OFFRAMP"
  public static let cryptoTransfer: Self = "CRYPTO_TRANSFER"
  public static let cryptoVirtualAccountOnramp: Self = "CRYPTO_VIRTUAL_ACCOUNT_ONRAMP"
  public static let cryptoVirtualAccountOfframp: Self = "CRYPTO_VIRTUAL_ACCOUNT_OFFRAMP"
  public static let bankLinking: Self = "BANK_LINKING"
  public static let fiatPayments: Self = "FIAT_PAYMENTS"
  public static let customerKyc: Self = "CUSTOMER_KYC"
  public static let cryptoOnrampSwap: Self = "CRYPTO_ONRAMP_SWAP"
  public static let cryptoOfframpSwap: Self = "CRYPTO_OFFRAMP_SWAP"
}

/// The family a payment method belongs to.
public struct MeldPaymentType: MeldOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let bankTransfer: Self = "BANK_TRANSFER"
  public static let card: Self = "CARD"
  public static let cash: Self = "CASH"
  public static let exchange: Self = "EXCHANGE"
  public static let local: Self = "LOCAL"
  public static let mobileWallet: Self = "MOBILE_WALLET"
}

/// The period a KYC limit applies to.
public struct MeldLimitType: MeldOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let transaction: Self = "TRANSACTION"
  public static let daily: Self = "DAILY"
  public static let weekly: Self = "WEEKLY"
  public static let monthly: Self = "MONTHLY"
  public static let yearly: Self = "YEARLY"
}

/// Whether a currency is fiat or crypto.
public struct MeldCurrencyType: MeldOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let fiat: Self = "FIAT"
  public static let crypto: Self = "CRYPTO"
}

/// How a card payment method is rendered.
public struct MeldCardRenderMode: MeldOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let iframe: Self = "IFRAME"
  public static let redirect: Self = "REDIRECT"
}

/// The availability of a network partner or of one of its capabilities.
public struct MeldPartnerStatus: MeldOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let live: Self = "LIVE"
  public static let recentlyAdded: Self = "RECENTLY_ADDED"
  public static let building: Self = "BUILDING"
  public static let deprecated: Self = "DEPRECATED"
}

/// The domain of a network partner's capability.
public struct MeldPartnerDomain: MeldOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let payment: Self = "PAYMENT"
  public static let financialAccount: Self = "FINANCIAL_ACCOUNT"
}

/// The kind of a quote or transaction. Also a `searchRetailTransactions` filter.
public struct MeldTransactionType: MeldOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let cryptoPurchase: Self = "CRYPTO_PURCHASE"
  public static let cryptoSell: Self = "CRYPTO_SELL"
  public static let cryptoTransfer: Self = "CRYPTO_TRANSFER"
  public static let cryptoPurchaseSwap: Self = "CRYPTO_PURCHASE_SWAP"
  public static let cryptoSellSwap: Self = "CRYPTO_SELL_SWAP"
}

/// The status of a transaction. Also a `searchRetailTransactions` filter.
public struct MeldTransactionStatus: MeldOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let pendingCreated: Self = "PENDING_CREATED"
  public static let pending: Self = "PENDING"
  public static let processing: Self = "PROCESSING"
  public static let authorized: Self = "AUTHORIZED"
  public static let authorizationExpired: Self = "AUTHORIZATION_EXPIRED"
  public static let settling: Self = "SETTLING"
  public static let onrampSettled: Self = "ONRAMP_SETTLED"
  public static let settled: Self = "SETTLED"
  public static let refunded: Self = "REFUNDED"
  public static let declined: Self = "DECLINED"
  public static let cancelled: Self = "CANCELLED"
  public static let failed: Self = "FAILED"
  public static let error: Self = "ERROR"
  public static let voided: Self = "VOIDED"
  public static let twoFaRequired: Self = "TWO_FA_REQUIRED"
  public static let twoFaProvided: Self = "TWO_FA_PROVIDED"
}

/// A widget field the user cannot change.
public struct MeldLockField: MeldOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let cryptoCurrency: Self = "cryptoCurrency"
  public static let destinationCurrencyCode: Self = "destinationCurrencyCode"
  public static let sourceCurrencyCode: Self = "sourceCurrencyCode"
  public static let walletAddress: Self = "walletAddress"
  public static let sourceAmount: Self = "sourceAmount"
  public static let paymentMethodType: Self = "paymentMethodType"
}

/// Whether a customer is a person or a business.
public struct MeldCustomerType: MeldOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let individual: Self = "INDIVIDUAL"
  public static let business: Self = "BUSINESS"
}

/// The status of a customer or of one of its addresses.
public struct MeldCustomerStatus: MeldOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let active: Self = "ACTIVE"
  public static let inactive: Self = "INACTIVE"
}

/// What a customer address is used for.
public struct MeldCustomerAddressType: MeldOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let billing: Self = "BILLING"
  public static let shipping: Self = "SHIPPING"
  public static let residence: Self = "RESIDENCE"
}

/// The KYC status of a customer at a service provider.
public struct MeldKycStatus: MeldOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let pending: Self = "PENDING"
  public static let approved: Self = "APPROVED"
  public static let rejected: Self = "REJECTED"
  public static let expired: Self = "EXPIRED"
  public static let unknown: Self = "UNKNOWN"
}

// MARK: - Shared shapes

/// Logo URLs for a dark and a light background.
public struct MeldLogo: Codable, Equatable {
  public let dark: String
  public let light: String

  public init(dark: String, light: String) {
    self.dark = dark
    self.light = light
  }
}
