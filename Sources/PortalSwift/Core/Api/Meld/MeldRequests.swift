//
//  MeldRequests.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - Bodies

/// Creates the Meld customer of the current client. Every field is optional; Portal links the
/// customer to the client itself.
public struct MeldCreateCustomerRequest: Codable, Equatable {
  public let name: MeldCustomerName?
  public let email: String?
  public let phone: String?
  /// `YYYY-MM-DD`.
  public let dateOfBirth: String?
  public let type: MeldCustomerType?

  public init(
    name: MeldCustomerName? = nil,
    email: String? = nil,
    phone: String? = nil,
    dateOfBirth: String? = nil,
    type: MeldCustomerType? = nil
  ) {
    self.name = name
    self.email = email
    self.phone = phone
    self.dateOfBirth = dateOfBirth
    self.type = type
  }
}

/// Prices a purchase or sale across the service providers.
public struct MeldGetRetailQuoteRequest: Codable, Equatable {
  /// ISO 3166-1 alpha-2 country code, e.g. `US`.
  public let countryCode: String
  /// The currency the user pays with, e.g. `USD` when buying.
  public let sourceCurrencyCode: String
  /// The currency the user receives, e.g. `ETH` when buying.
  public let destinationCurrencyCode: String
  /// The amount in `sourceCurrencyCode`, sent as a JSON number. (The widget session's
  /// `MeldSessionData.sourceAmount` is a string.)
  public let sourceAmount: Double
  public let walletAddress: String?
  /// A Meld customer Portal has on record for the client: the one `createCustomer` created or
  /// `searchCustomer()` found. Any other id fails with `404` (`Meld customer does not exist.`).
  public let customerId: String?
  /// e.g. `CREDIT_DEBIT_CARD`.
  public let paymentMethodType: String?
  /// Restricts the quote to these service providers, e.g. `["TRANSAK"]`.
  public let serviceProviders: [String]?
  public let subdivision: String?

  public init(
    countryCode: String,
    sourceCurrencyCode: String,
    destinationCurrencyCode: String,
    sourceAmount: Double,
    walletAddress: String? = nil,
    customerId: String? = nil,
    paymentMethodType: String? = nil,
    serviceProviders: [String]? = nil,
    subdivision: String? = nil
  ) {
    self.countryCode = countryCode
    self.sourceCurrencyCode = sourceCurrencyCode
    self.destinationCurrencyCode = destinationCurrencyCode
    self.sourceAmount = sourceAmount
    self.walletAddress = walletAddress
    self.customerId = customerId
    self.paymentMethodType = paymentMethodType
    self.serviceProviders = serviceProviders
    self.subdivision = subdivision
  }
}

/// Starts a widget session at one service provider.
public struct MeldCreateRetailWidgetRequest: Codable, Equatable {
  public let sessionType: MeldSessionType
  public let sessionData: MeldSessionData
  /// Your own id for the session, returned on its transactions.
  public let externalSessionId: String?
  /// The Meld customer to attach. Without it, Meld creates or reuses one for the client.
  /// A Meld customer Portal has on record for the client: the one `createCustomer` created or
  /// `searchCustomer()` found. Any other id fails with `404` (`Meld customer does not exist.`).
  public let customerId: String?
  public let bypassKyc: Bool?

  public init(
    sessionType: MeldSessionType,
    sessionData: MeldSessionData,
    externalSessionId: String? = nil,
    customerId: String? = nil,
    bypassKyc: Bool? = nil
  ) {
    self.sessionType = sessionType
    self.sessionData = sessionData
    self.externalSessionId = externalSessionId
    self.customerId = customerId
    self.bypassKyc = bypassKyc
  }
}

/// What the widget opens with.
public struct MeldSessionData: Codable, Equatable {
  public let countryCode: String
  /// The service provider to open, usually a quote's `serviceProvider`, e.g. `TRANSAK`.
  public let serviceProvider: String
  public let sourceCurrencyCode: String
  /// The amount in `sourceCurrencyCode`, sent as a string, e.g. `"100"`. (The quote's
  /// `MeldGetRetailQuoteRequest.sourceAmount` is a number.) Use a plain decimal such as `"99.5"`:
  /// a `Double`'s description can carry an exponent (`1e+16`); format through `Decimal` or a
  /// `NumberFormatter` with the `en_US_POSIX` locale.
  public let sourceAmount: String
  public let destinationCurrencyCode: String
  /// On a `BUY`, the wallet that receives the crypto; it must be on the chain of
  /// `destinationCurrencyCode`.
  public let walletAddress: String?
  /// The memo or tag some chains need next to the address.
  public let walletTag: String?
  public let paymentMethodType: String?
  /// Where the provider sends the user when they are done.
  public let redirectUrl: String?
  /// Fields the user cannot change in the widget.
  public let lockFields: [MeldLockField]?
  /// The user's public IP address. Some providers, such as Transak, refuse to open a session without it.
  /// Portal forwards the value as given and does not fill it in.
  public let clientIpAddress: String?

  public init(
    countryCode: String,
    serviceProvider: String,
    sourceCurrencyCode: String,
    sourceAmount: String,
    destinationCurrencyCode: String,
    walletAddress: String? = nil,
    walletTag: String? = nil,
    paymentMethodType: String? = nil,
    redirectUrl: String? = nil,
    lockFields: [MeldLockField]? = nil,
    clientIpAddress: String? = nil
  ) {
    self.countryCode = countryCode
    self.serviceProvider = serviceProvider
    self.sourceCurrencyCode = sourceCurrencyCode
    self.sourceAmount = sourceAmount
    self.destinationCurrencyCode = destinationCurrencyCode
    self.walletAddress = walletAddress
    self.walletTag = walletTag
    self.paymentMethodType = paymentMethodType
    self.redirectUrl = redirectUrl
    self.lockFields = lockFields
    self.clientIpAddress = clientIpAddress
  }
}

// MARK: - Query parameters

/// Filters for `searchRetailTransactions`. List filters match any of their values.
public struct MeldSearchRetailTransactionsParams: Equatable {
  public let statuses: [MeldTransactionStatus]?
  public let types: [MeldTransactionType]?
  public let serviceProviders: [String]?
  public let sessionIds: [String]?
  public let externalSessionIds: [String]?
  public let serviceProviderTransactionId: String?
  /// 1–100; Meld's default is 10. There is no paging: narrow the search with `from` / `to` instead.
  public let limit: Int?
  public let amountFrom: Double?
  public let amountTo: Double?
  /// ISO 8601 date or datetime.
  public let from: String?
  /// ISO 8601 date or datetime.
  public let to: String?

  public init(
    statuses: [MeldTransactionStatus]? = nil,
    types: [MeldTransactionType]? = nil,
    serviceProviders: [String]? = nil,
    sessionIds: [String]? = nil,
    externalSessionIds: [String]? = nil,
    serviceProviderTransactionId: String? = nil,
    limit: Int? = nil,
    amountFrom: Double? = nil,
    amountTo: Double? = nil,
    from: String? = nil,
    to: String? = nil
  ) {
    self.statuses = statuses
    self.types = types
    self.serviceProviders = serviceProviders
    self.sessionIds = sessionIds
    self.externalSessionIds = externalSessionIds
    self.serviceProviderTransactionId = serviceProviderTransactionId
    self.limit = limit
    self.amountFrom = amountFrom
    self.amountTo = amountTo
    self.from = from
    self.to = to
  }
}

/// Filters for `getNetworkPartnerCountries`.
public struct MeldGetNetworkPartnerCountriesParams: Equatable {
  public let category: MeldCategory?
  /// Service provider ids, e.g. `["TRANSAK"]`.
  public let partners: [String]?

  public init(category: MeldCategory? = nil, partners: [String]? = nil) {
    self.category = category
    self.partners = partners
  }
}

/// Filters for `getNetworkPartnerCurrencies`.
public struct MeldGetNetworkPartnerCurrenciesParams: Equatable {
  public let category: MeldCategory?
  public let country: String?
  public let network: String?
  /// One service provider id.
  public let partner: String?
  public let paymentType: MeldPaymentType?
  public let providerCurrencyCode: String?
  public let subdivision: String?
  public let type: MeldCurrencyType?

  public init(
    category: MeldCategory? = nil,
    country: String? = nil,
    network: String? = nil,
    partner: String? = nil,
    paymentType: MeldPaymentType? = nil,
    providerCurrencyCode: String? = nil,
    subdivision: String? = nil,
    type: MeldCurrencyType? = nil
  ) {
    self.category = category
    self.country = country
    self.network = network
    self.partner = partner
    self.paymentType = paymentType
    self.providerCurrencyCode = providerCurrencyCode
    self.subdivision = subdivision
    self.type = type
  }
}

/// Filters for `getNetworkPartnerFiatLimits`.
public struct MeldGetNetworkPartnerFiatLimitsParams: Equatable {
  public let category: MeldCategory?
  public let country: String?
  public let currencyCode: String?
  public let partners: [String]?
  public let paymentMethod: String?
  public let paymentType: MeldPaymentType?
  public let subdivision: String?

  public init(
    category: MeldCategory? = nil,
    country: String? = nil,
    currencyCode: String? = nil,
    partners: [String]? = nil,
    paymentMethod: String? = nil,
    paymentType: MeldPaymentType? = nil,
    subdivision: String? = nil
  ) {
    self.category = category
    self.country = country
    self.currencyCode = currencyCode
    self.partners = partners
    self.paymentMethod = paymentMethod
    self.paymentType = paymentType
    self.subdivision = subdivision
  }
}

/// Filters for `getNetworkPartnerKycLimits`.
public struct MeldGetNetworkPartnerKycLimitsParams: Equatable {
  public let category: MeldCategory?
  public let country: String?
  public let currencyCode: String?
  public let limitType: MeldLimitType?
  public let partners: [String]?

  public init(
    category: MeldCategory? = nil,
    country: String? = nil,
    currencyCode: String? = nil,
    limitType: MeldLimitType? = nil,
    partners: [String]? = nil
  ) {
    self.category = category
    self.country = country
    self.currencyCode = currencyCode
    self.limitType = limitType
    self.partners = partners
  }
}

/// Filters for `getNetworkPartners`.
public struct MeldGetNetworkPartnersParams: Equatable {
  public let category: MeldCategory?
  public let country: String?
  public let cryptoCurrency: String?
  public let fiatCurrency: String?
  /// One service provider id.
  public let partner: String?
  public let paymentMethod: String?
  public let paymentType: MeldPaymentType?
  public let subdivision: String?

  public init(
    category: MeldCategory? = nil,
    country: String? = nil,
    cryptoCurrency: String? = nil,
    fiatCurrency: String? = nil,
    partner: String? = nil,
    paymentMethod: String? = nil,
    paymentType: MeldPaymentType? = nil,
    subdivision: String? = nil
  ) {
    self.category = category
    self.country = country
    self.cryptoCurrency = cryptoCurrency
    self.fiatCurrency = fiatCurrency
    self.partner = partner
    self.paymentMethod = paymentMethod
    self.paymentType = paymentType
    self.subdivision = subdivision
  }
}

/// Filters for `getNetworkPartnerPaymentMethods`.
public struct MeldGetNetworkPartnerPaymentMethodsParams: Equatable {
  public let category: MeldCategory?
  public let country: String?
  public let currencyCode: String?
  public let partners: [String]?
  public let paymentType: MeldPaymentType?
  public let subdivision: String?

  public init(
    category: MeldCategory? = nil,
    country: String? = nil,
    currencyCode: String? = nil,
    partners: [String]? = nil,
    paymentType: MeldPaymentType? = nil,
    subdivision: String? = nil
  ) {
    self.category = category
    self.country = country
    self.currencyCode = currencyCode
    self.partners = partners
    self.paymentType = paymentType
    self.subdivision = subdivision
  }
}

/// The route to look up for `getNetworkPartnerRoutes`, plus optional filters.
public struct MeldGetNetworkPartnerRoutesParams: Equatable {
  public let category: MeldCategory
  public let countryCode: String
  public let sourceCurrencyCode: String
  public let destinationCurrencyCode: String
  public let partners: [String]?
  public let paymentMethod: String?
  public let paymentType: MeldPaymentType?
  public let subdivision: String?

  public init(
    category: MeldCategory,
    countryCode: String,
    sourceCurrencyCode: String,
    destinationCurrencyCode: String,
    partners: [String]? = nil,
    paymentMethod: String? = nil,
    paymentType: MeldPaymentType? = nil,
    subdivision: String? = nil
  ) {
    self.category = category
    self.countryCode = countryCode
    self.sourceCurrencyCode = sourceCurrencyCode
    self.destinationCurrencyCode = destinationCurrencyCode
    self.partners = partners
    self.paymentMethod = paymentMethod
    self.paymentType = paymentType
    self.subdivision = subdivision
  }
}
