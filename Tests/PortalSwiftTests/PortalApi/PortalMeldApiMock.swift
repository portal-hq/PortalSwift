//
//  PortalMeldApiMock.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import Foundation
@testable import PortalSwift

/// A Meld double for both layers (`PortalMeldApiProtocol` and `MeldProtocol`): each method runs the
/// handler a test sets and records the call in order. A method without a handler throws `NotStubbed`.
final class PortalMeldApiMock: MeldProtocol {
  struct NotStubbed: Error {
    let method: String
  }

  private let lock = NSLock()
  private var _calls: [String] = []

  /// The methods called, in order.
  var calls: [String] {
    lock.lock()
    defer { lock.unlock() }
    return _calls
  }

  func callCount(_ method: String) -> Int {
    calls.filter { $0 == method }.count
  }

  private func record(_ method: String) {
    lock.lock()
    _calls.append(method)
    lock.unlock()
  }

  var createCustomerHandler: ((MeldCreateCustomerRequest) async throws -> MeldCreateCustomerResponse)?
  func createCustomer(request: MeldCreateCustomerRequest) async throws -> MeldCreateCustomerResponse {
    record("createCustomer")
    guard let handler = createCustomerHandler else {
      throw NotStubbed(method: "createCustomer")
    }
    return try await handler(request)
  }

  var searchCustomerHandler: (() async throws -> MeldSearchCustomerResponse)?
  func searchCustomer() async throws -> MeldSearchCustomerResponse {
    record("searchCustomer")
    guard let handler = searchCustomerHandler else {
      throw NotStubbed(method: "searchCustomer")
    }
    return try await handler()
  }

  var getRetailQuoteHandler: ((MeldGetRetailQuoteRequest) async throws -> MeldGetRetailQuoteResponse)?
  func getRetailQuote(request: MeldGetRetailQuoteRequest) async throws -> MeldGetRetailQuoteResponse {
    record("getRetailQuote")
    guard let handler = getRetailQuoteHandler else {
      throw NotStubbed(method: "getRetailQuote")
    }
    return try await handler(request)
  }

  var createRetailWidgetHandler: ((MeldCreateRetailWidgetRequest) async throws -> MeldCreateRetailWidgetResponse)?
  func createRetailWidget(request: MeldCreateRetailWidgetRequest) async throws -> MeldCreateRetailWidgetResponse {
    record("createRetailWidget")
    guard let handler = createRetailWidgetHandler else {
      throw NotStubbed(method: "createRetailWidget")
    }
    return try await handler(request)
  }

  var searchRetailTransactionsHandler: ((MeldSearchRetailTransactionsParams) async throws -> MeldSearchRetailTransactionsResponse)?
  func searchRetailTransactions(params: MeldSearchRetailTransactionsParams) async throws -> MeldSearchRetailTransactionsResponse {
    record("searchRetailTransactions")
    guard let handler = searchRetailTransactionsHandler else {
      throw NotStubbed(method: "searchRetailTransactions")
    }
    return try await handler(params)
  }

  var getRetailTransactionHandler: ((String) async throws -> MeldGetRetailTransactionResponse)?
  func getRetailTransaction(transactionId: String) async throws -> MeldGetRetailTransactionResponse {
    record("getRetailTransaction")
    guard let handler = getRetailTransactionHandler else {
      throw NotStubbed(method: "getRetailTransaction")
    }
    return try await handler(transactionId)
  }

  var getRetailTransactionBySessionHandler: ((String) async throws -> MeldGetRetailTransactionResponse)?
  func getRetailTransactionBySession(sessionId: String) async throws -> MeldGetRetailTransactionResponse {
    record("getRetailTransactionBySession")
    guard let handler = getRetailTransactionBySessionHandler else {
      throw NotStubbed(method: "getRetailTransactionBySession")
    }
    return try await handler(sessionId)
  }

  var getNetworkPartnerCountriesHandler: ((MeldGetNetworkPartnerCountriesParams) async throws -> MeldGetNetworkPartnerCountriesResponse)?
  func getNetworkPartnerCountries(params: MeldGetNetworkPartnerCountriesParams) async throws -> MeldGetNetworkPartnerCountriesResponse {
    record("getNetworkPartnerCountries")
    guard let handler = getNetworkPartnerCountriesHandler else {
      throw NotStubbed(method: "getNetworkPartnerCountries")
    }
    return try await handler(params)
  }

  var getNetworkPartnerCurrenciesHandler: ((MeldGetNetworkPartnerCurrenciesParams) async throws -> MeldGetNetworkPartnerCurrenciesResponse)?
  func getNetworkPartnerCurrencies(params: MeldGetNetworkPartnerCurrenciesParams) async throws -> MeldGetNetworkPartnerCurrenciesResponse {
    record("getNetworkPartnerCurrencies")
    guard let handler = getNetworkPartnerCurrenciesHandler else {
      throw NotStubbed(method: "getNetworkPartnerCurrencies")
    }
    return try await handler(params)
  }

  var getNetworkPartnerFiatLimitsHandler: ((MeldGetNetworkPartnerFiatLimitsParams) async throws -> MeldGetNetworkPartnerFiatLimitsResponse)?
  func getNetworkPartnerFiatLimits(params: MeldGetNetworkPartnerFiatLimitsParams) async throws -> MeldGetNetworkPartnerFiatLimitsResponse {
    record("getNetworkPartnerFiatLimits")
    guard let handler = getNetworkPartnerFiatLimitsHandler else {
      throw NotStubbed(method: "getNetworkPartnerFiatLimits")
    }
    return try await handler(params)
  }

  var getNetworkPartnerKycLimitsHandler: ((MeldGetNetworkPartnerKycLimitsParams) async throws -> MeldGetNetworkPartnerKycLimitsResponse)?
  func getNetworkPartnerKycLimits(params: MeldGetNetworkPartnerKycLimitsParams) async throws -> MeldGetNetworkPartnerKycLimitsResponse {
    record("getNetworkPartnerKycLimits")
    guard let handler = getNetworkPartnerKycLimitsHandler else {
      throw NotStubbed(method: "getNetworkPartnerKycLimits")
    }
    return try await handler(params)
  }

  var getNetworkPartnersHandler: ((MeldGetNetworkPartnersParams) async throws -> MeldGetNetworkPartnersResponse)?
  func getNetworkPartners(params: MeldGetNetworkPartnersParams) async throws -> MeldGetNetworkPartnersResponse {
    record("getNetworkPartners")
    guard let handler = getNetworkPartnersHandler else {
      throw NotStubbed(method: "getNetworkPartners")
    }
    return try await handler(params)
  }

  var getNetworkPartnerPaymentMethodsHandler: ((MeldGetNetworkPartnerPaymentMethodsParams) async throws -> MeldGetNetworkPartnerPaymentMethodsResponse)?
  func getNetworkPartnerPaymentMethods(params: MeldGetNetworkPartnerPaymentMethodsParams) async throws -> MeldGetNetworkPartnerPaymentMethodsResponse {
    record("getNetworkPartnerPaymentMethods")
    guard let handler = getNetworkPartnerPaymentMethodsHandler else {
      throw NotStubbed(method: "getNetworkPartnerPaymentMethods")
    }
    return try await handler(params)
  }

  var getNetworkPartnerRoutesHandler: ((MeldGetNetworkPartnerRoutesParams) async throws -> MeldGetNetworkPartnerRoutesResponse)?
  func getNetworkPartnerRoutes(params: MeldGetNetworkPartnerRoutesParams) async throws -> MeldGetNetworkPartnerRoutesResponse {
    record("getNetworkPartnerRoutes")
    guard let handler = getNetworkPartnerRoutesHandler else {
      throw NotStubbed(method: "getNetworkPartnerRoutes")
    }
    return try await handler(params)
  }

  var getNetworkPartnerCountryDefaultsHandler: ((String, MeldCategory) async throws -> MeldGetNetworkPartnerCountryDefaultsResponse)?
  func getNetworkPartnerCountryDefaults(countryCode: String, category: MeldCategory) async throws -> MeldGetNetworkPartnerCountryDefaultsResponse {
    record("getNetworkPartnerCountryDefaults")
    guard let handler = getNetworkPartnerCountryDefaultsHandler else {
      throw NotStubbed(method: "getNetworkPartnerCountryDefaults")
    }
    return try await handler(countryCode, category)
  }
}
