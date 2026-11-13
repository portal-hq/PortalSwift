//
//  Meld.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Meld fiat on- and off-ramp surface, available as `portal.ramps.meld`.
///
/// It has the same methods as `portal.api.meld` (`PortalMeldApiProtocol`), including the
/// no-argument overloads.
public protocol MeldProtocol: PortalMeldApiProtocol {}

/// Meld fiat on- and off-ramp aggregator: customers, quotes and widget sessions across service
/// providers, the resulting transactions, and the Network Partners catalogue (countries,
/// currencies, limits, partners, payment methods, routes and country defaults).
///
/// A typical purchase: `getNetworkPartnerCountryDefaults` → `getRetailQuote` → `createRetailWidget`
/// with the chosen quote's `serviceProvider` → open `widgetUrl` in `SFSafariViewController` →
/// `getRetailTransactionBySession` when the user comes back. Meld must be enabled for the
/// environment in the Portal Dashboard. Read failures with `MeldApiError.from(_:)`.
public class Meld: MeldProtocol {
  private let api: PortalMeldApiProtocol

  /// Create an instance of `Meld`.
  /// - Parameter api: The Meld API client, usually `portal.api.meld`.
  public init(api: PortalMeldApiProtocol) {
    self.api = api
  }

  // MARK: - Customers

  /// Creates the client's Meld customer. A second call fails with `409`;
  /// `MeldApiError.from(_:)?.meldCustomerId` is the existing customer's id.
  public func createCustomer(request: MeldCreateCustomerRequest) async throws -> MeldCreateCustomerResponse {
    try await api.createCustomer(request: request)
  }

  /// The client's Meld customer, if it has one.
  public func searchCustomer() async throws -> MeldSearchCustomerResponse {
    try await api.searchCustomer()
  }

  // MARK: - Retail

  /// Prices a purchase or sale across the service providers.
  public func getRetailQuote(request: MeldGetRetailQuoteRequest) async throws -> MeldGetRetailQuoteResponse {
    try await api.getRetailQuote(request: request)
  }

  /// Starts a widget session at one service provider. Open `widgetUrl` once, in the browser.
  public func createRetailWidget(request: MeldCreateRetailWidgetRequest) async throws -> MeldCreateRetailWidgetResponse {
    try await api.createRetailWidget(request: request)
  }

  /// The client's transactions, at most `limit` (up to 100); there is no paging.
  public func searchRetailTransactions(params: MeldSearchRetailTransactionsParams) async throws -> MeldSearchRetailTransactionsResponse {
    try await api.searchRetailTransactions(params: params)
  }

  /// One transaction.
  public func getRetailTransaction(transactionId: String) async throws -> MeldGetRetailTransactionResponse {
    try await api.getRetailTransaction(transactionId: transactionId)
  }

  /// The transaction of a widget session; `404` until the user has started a purchase.
  public func getRetailTransactionBySession(sessionId: String) async throws -> MeldGetRetailTransactionResponse {
    try await api.getRetailTransactionBySession(sessionId: sessionId)
  }

  // MARK: - Network Partners

  public func getNetworkPartnerCountries(params: MeldGetNetworkPartnerCountriesParams) async throws -> MeldGetNetworkPartnerCountriesResponse {
    try await api.getNetworkPartnerCountries(params: params)
  }

  public func getNetworkPartnerCurrencies(params: MeldGetNetworkPartnerCurrenciesParams) async throws -> MeldGetNetworkPartnerCurrenciesResponse {
    try await api.getNetworkPartnerCurrencies(params: params)
  }

  public func getNetworkPartnerFiatLimits(params: MeldGetNetworkPartnerFiatLimitsParams) async throws -> MeldGetNetworkPartnerFiatLimitsResponse {
    try await api.getNetworkPartnerFiatLimits(params: params)
  }

  public func getNetworkPartnerKycLimits(params: MeldGetNetworkPartnerKycLimitsParams) async throws -> MeldGetNetworkPartnerKycLimitsResponse {
    try await api.getNetworkPartnerKycLimits(params: params)
  }

  public func getNetworkPartners(params: MeldGetNetworkPartnersParams) async throws -> MeldGetNetworkPartnersResponse {
    try await api.getNetworkPartners(params: params)
  }

  public func getNetworkPartnerPaymentMethods(params: MeldGetNetworkPartnerPaymentMethodsParams) async throws -> MeldGetNetworkPartnerPaymentMethodsResponse {
    try await api.getNetworkPartnerPaymentMethods(params: params)
  }

  public func getNetworkPartnerRoutes(params: MeldGetNetworkPartnerRoutesParams) async throws -> MeldGetNetworkPartnerRoutesResponse {
    try await api.getNetworkPartnerRoutes(params: params)
  }

  /// The country's default fiat currency and payment methods; `data` is `nil` when Meld has none.
  public func getNetworkPartnerCountryDefaults(
    countryCode: String,
    category: MeldCategory
  ) async throws -> MeldGetNetworkPartnerCountryDefaultsResponse {
    try await api.getNetworkPartnerCountryDefaults(countryCode: countryCode, category: category)
  }
}
