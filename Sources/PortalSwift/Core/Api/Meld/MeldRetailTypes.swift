//
//  MeldRetailTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import AnyCodable
import Foundation

// MARK: - Quotes

/// The quotes for a `getRetailQuote` request.
///
/// A request no provider can serve can still succeed with an empty `quotes` and an `error` or
/// `message` explaining why.
public struct MeldRetailQuoteResult: Codable, Equatable {
  public let quotes: [MeldQuote]
  public let message: String?
  public let error: String?
  public let timestamp: String?

  public init(quotes: [MeldQuote], message: String? = nil, error: String? = nil, timestamp: String? = nil) {
    self.quotes = quotes
    self.message = message
    self.error = error
    self.timestamp = timestamp
  }
}

/// One service provider's price.
public struct MeldQuote: Codable, Equatable {
  public let transactionType: MeldTransactionType
  public let sourceAmount: Double
  public let sourceAmountWithoutFees: Double?
  public let sourceCurrencyCode: String
  public let destinationAmount: Double
  public let destinationAmountWithoutFees: Double?
  public let destinationCurrencyCode: String
  public let exchangeRate: Double
  public let transactionFee: Double
  public let networkFee: Double?
  public let partnerFee: Double?
  public let totalFee: Double
  public let fiatAmountWithoutFees: Double?
  public let paymentMethodType: String
  /// Pass it as `MeldSessionData.serviceProvider` to open this provider's widget.
  public let serviceProvider: String
  public let countryCode: String?
  public let customerScore: Double?
  public let institutionName: String?
  public let isNativeAvailable: Bool?
  public let rampIntelligence: MeldRampIntelligence?

  public init(
    transactionType: MeldTransactionType,
    sourceAmount: Double,
    sourceAmountWithoutFees: Double? = nil,
    sourceCurrencyCode: String,
    destinationAmount: Double,
    destinationAmountWithoutFees: Double? = nil,
    destinationCurrencyCode: String,
    exchangeRate: Double,
    transactionFee: Double,
    networkFee: Double? = nil,
    partnerFee: Double? = nil,
    totalFee: Double,
    fiatAmountWithoutFees: Double? = nil,
    paymentMethodType: String,
    serviceProvider: String,
    countryCode: String? = nil,
    customerScore: Double? = nil,
    institutionName: String? = nil,
    isNativeAvailable: Bool? = nil,
    rampIntelligence: MeldRampIntelligence? = nil
  ) {
    self.transactionType = transactionType
    self.sourceAmount = sourceAmount
    self.sourceAmountWithoutFees = sourceAmountWithoutFees
    self.sourceCurrencyCode = sourceCurrencyCode
    self.destinationAmount = destinationAmount
    self.destinationAmountWithoutFees = destinationAmountWithoutFees
    self.destinationCurrencyCode = destinationCurrencyCode
    self.exchangeRate = exchangeRate
    self.transactionFee = transactionFee
    self.networkFee = networkFee
    self.partnerFee = partnerFee
    self.totalFee = totalFee
    self.fiatAmountWithoutFees = fiatAmountWithoutFees
    self.paymentMethodType = paymentMethodType
    self.serviceProvider = serviceProvider
    self.countryCode = countryCode
    self.customerScore = customerScore
    self.institutionName = institutionName
    self.isNativeAvailable = isNativeAvailable
    self.rampIntelligence = rampIntelligence
  }
}

/// Meld's ranking hints for a quote.
public struct MeldRampIntelligence: Codable, Equatable {
  public let rampScore: Double?
  public let lowKyc: Bool?
  /// When the customer last used this provider, as an ISO 8601 datetime.
  public let previouslyUsed: String?

  public init(rampScore: Double? = nil, lowKyc: Bool? = nil, previouslyUsed: String? = nil) {
    self.rampScore = rampScore
    self.lowKyc = lowKyc
    self.previouslyUsed = previouslyUsed
  }
}

// MARK: - Widget

/// A widget session. Open `widgetUrl` in the browser; its token is single-use, so open it once
/// and do not log or store it.
public struct MeldWidgetSession: Codable, Equatable {
  /// The session id; read the purchase with `getRetailTransactionBySession(sessionId:)`.
  public let id: String
  public let token: String
  /// The client's Meld customer. Meld creates one when the request had no `customerId`; Portal
  /// records it on the next `searchCustomer()`, and until then passing it as a `customerId` fails
  /// with `404`.
  public let customerId: String
  public let externalCustomerId: String
  public let externalSessionId: String?
  public let widgetUrl: String

  public init(
    id: String,
    token: String,
    customerId: String,
    externalCustomerId: String,
    externalSessionId: String? = nil,
    widgetUrl: String
  ) {
    self.id = id
    self.token = token
    self.customerId = customerId
    self.externalCustomerId = externalCustomerId
    self.externalSessionId = externalSessionId
    self.widgetUrl = widgetUrl
  }
}

// MARK: - Transactions

/// A purchase or sale made through a widget session.
public struct MeldTransaction: Codable, Equatable {
  public let id: String
  public let sessionId: String
  public let externalSessionId: String?
  public let externalCustomerId: String?
  public let customerId: String?
  public let customer: Customer?
  public let status: MeldTransactionStatus
  public let transactionType: MeldTransactionType
  public let serviceProvider: String
  public let sourceAmount: Double?
  public let sourceCurrencyCode: String?
  public let destinationAmount: Double?
  public let destinationCurrencyCode: String?
  public let createdAt: String
  public let updatedAt: String
  public let paymentMethodType: String?
  public let cryptoDetails: MeldTransactionCryptoDetails?
  /// Provider-specific data, passed through as Meld returns it.
  public let serviceProviderDetails: [String: AnyCodable]?

  public struct Customer: Codable, Equatable {
    public let externalId: String?

    public init(externalId: String? = nil) {
      self.externalId = externalId
    }
  }

  public init(
    id: String,
    sessionId: String,
    externalSessionId: String? = nil,
    externalCustomerId: String? = nil,
    customerId: String? = nil,
    customer: Customer? = nil,
    status: MeldTransactionStatus,
    transactionType: MeldTransactionType,
    serviceProvider: String,
    sourceAmount: Double? = nil,
    sourceCurrencyCode: String? = nil,
    destinationAmount: Double? = nil,
    destinationCurrencyCode: String? = nil,
    createdAt: String,
    updatedAt: String,
    paymentMethodType: String? = nil,
    cryptoDetails: MeldTransactionCryptoDetails? = nil,
    serviceProviderDetails: [String: AnyCodable]? = nil
  ) {
    self.id = id
    self.sessionId = sessionId
    self.externalSessionId = externalSessionId
    self.externalCustomerId = externalCustomerId
    self.customerId = customerId
    self.customer = customer
    self.status = status
    self.transactionType = transactionType
    self.serviceProvider = serviceProvider
    self.sourceAmount = sourceAmount
    self.sourceCurrencyCode = sourceCurrencyCode
    self.destinationAmount = destinationAmount
    self.destinationCurrencyCode = destinationCurrencyCode
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.paymentMethodType = paymentMethodType
    self.cryptoDetails = cryptoDetails
    self.serviceProviderDetails = serviceProviderDetails
  }
}

/// The on-chain side of a transaction.
public struct MeldTransactionCryptoDetails: Codable, Equatable {
  public let blockchainTransactionId: String?
  public let chainId: String?
  public let destinationWalletAddress: String?
  public let sourceWalletAddress: String?
  public let sessionWalletAddress: String?
  public let institution: String?
  public let networkFee: Double?
  public let partnerFee: Double?
  public let swapFee: Double?
  public let totalFee: Double?
  public let transactionFee: Double?

  public init(
    blockchainTransactionId: String? = nil,
    chainId: String? = nil,
    destinationWalletAddress: String? = nil,
    sourceWalletAddress: String? = nil,
    sessionWalletAddress: String? = nil,
    institution: String? = nil,
    networkFee: Double? = nil,
    partnerFee: Double? = nil,
    swapFee: Double? = nil,
    totalFee: Double? = nil,
    transactionFee: Double? = nil
  ) {
    self.blockchainTransactionId = blockchainTransactionId
    self.chainId = chainId
    self.destinationWalletAddress = destinationWalletAddress
    self.sourceWalletAddress = sourceWalletAddress
    self.sessionWalletAddress = sessionWalletAddress
    self.institution = institution
    self.networkFee = networkFee
    self.partnerFee = partnerFee
    self.swapFee = swapFee
    self.totalFee = totalFee
    self.transactionFee = transactionFee
  }
}

/// The result of `searchRetailTransactions`. There is no paging: up to `limit` transactions come
/// back (Meld's default is 10, the maximum 100), and `remaining` counts the rest.
public struct MeldTransactionSearchResult: Codable, Equatable {
  public let count: Int
  public let remaining: Int
  public let totalCount: Int
  public let transactions: [MeldTransaction]

  public init(count: Int, remaining: Int, totalCount: Int, transactions: [MeldTransaction]) {
    self.count = count
    self.remaining = remaining
    self.totalCount = totalCount
    self.transactions = transactions
  }
}

/// One transaction, from `getRetailTransaction` or `getRetailTransactionBySession`.
public struct MeldTransactionResult: Codable, Equatable {
  public let transaction: MeldTransaction

  public init(transaction: MeldTransaction) {
    self.transaction = transaction
  }
}
