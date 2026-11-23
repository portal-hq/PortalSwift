//
//  MeldTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

@testable import PortalSwift
import XCTest

final class MeldTests: XCTestCase {
  private struct Failure: Error, Equatable {}

  private var api: PortalMeldApiMock!
  private var meld: Meld!

  override func setUp() {
    super.setUp()
    api = PortalMeldApiMock()
    meld = Meld(api: api)
  }

  override func tearDown() {
    api = nil
    meld = nil
    super.tearDown()
  }

  private static let customer = MeldCustomer(id: "meld-customer-1", accountId: "a", externalId: "e")
  private static let transaction = MeldTransactionResult(transaction: MeldTransaction(
    id: "t1", sessionId: "s1", status: .settled, transactionType: .cryptoPurchase, serviceProvider: "TRANSAK",
    createdAt: "2026-11-13T09:00:00Z", updatedAt: "2026-11-13T09:05:00Z"
  ))

  // MARK: - Forwarding

  func test_customers_forwardTheirArgumentsAndResults() async throws {
    var created: MeldCreateCustomerRequest?
    api.createCustomerHandler = { created = $0; return MeldCreateCustomerResponse(data: Self.customer) }
    api.searchCustomerHandler = { MeldSearchCustomerResponse(data: MeldCustomerSearchResult(customers: [Self.customer], count: 1, remaining: 0)) }

    let request = MeldCreateCustomerRequest(email: "ada@example.com", type: .individual)
    let createdResponse = try await meld.createCustomer(request: request)
    let searched = try await meld.searchCustomer()

    XCTAssertEqual(created, request)
    XCTAssertEqual(createdResponse.data, Self.customer)
    XCTAssertEqual(searched.data.customers, [Self.customer])
    XCTAssertEqual(api.calls, ["createCustomer", "searchCustomer"])
  }

  func test_retail_forwardsItsArgumentsAndResults() async throws {
    var quoteRequest: MeldGetRetailQuoteRequest?
    var widgetRequest: MeldCreateRetailWidgetRequest?
    var searchParams: MeldSearchRetailTransactionsParams?
    var transactionId: String?
    var sessionId: String?
    api.getRetailQuoteHandler = { quoteRequest = $0; return MeldGetRetailQuoteResponse(data: MeldRetailQuoteResult(quotes: [])) }
    api.createRetailWidgetHandler = {
      widgetRequest = $0
      return MeldCreateRetailWidgetResponse(data: MeldWidgetSession(id: "s1", token: "t", customerId: "c", externalCustomerId: "e", widgetUrl: "https://w"))
    }
    api.searchRetailTransactionsHandler = {
      searchParams = $0
      return MeldSearchRetailTransactionsResponse(data: MeldTransactionSearchResult(count: 0, remaining: 0, totalCount: 0, transactions: []))
    }
    api.getRetailTransactionHandler = { transactionId = $0; return MeldGetRetailTransactionResponse(data: Self.transaction) }
    api.getRetailTransactionBySessionHandler = { sessionId = $0; return MeldGetRetailTransactionResponse(data: Self.transaction) }

    let quote = MeldGetRetailQuoteRequest(countryCode: "US", sourceCurrencyCode: "USD", destinationCurrencyCode: "ETH", sourceAmount: 100)
    let widget = MeldCreateRetailWidgetRequest(
      sessionType: .buy,
      sessionData: MeldSessionData(countryCode: "US", serviceProvider: "TRANSAK", sourceCurrencyCode: "USD", sourceAmount: "100", destinationCurrencyCode: "ETH")
    )
    let params = MeldSearchRetailTransactionsParams(statuses: [.settled], limit: 5)

    _ = try await meld.getRetailQuote(request: quote)
    let session = try await meld.createRetailWidget(request: widget)
    _ = try await meld.searchRetailTransactions(params: params)
    let byId = try await meld.getRetailTransaction(transactionId: "t1")
    let bySession = try await meld.getRetailTransactionBySession(sessionId: "s1")

    XCTAssertEqual(quoteRequest, quote)
    XCTAssertEqual(widgetRequest, widget)
    XCTAssertEqual(session.data.id, "s1")
    XCTAssertEqual(searchParams, params)
    XCTAssertEqual(transactionId, "t1")
    XCTAssertEqual(sessionId, "s1")
    XCTAssertEqual(byId.data, Self.transaction)
    XCTAssertEqual(bySession.data, Self.transaction)
  }

  func test_networkPartners_forwardTheirParams() async throws {
    var received: [String: Any] = [:]
    api.getNetworkPartnerCountriesHandler = { received["countries"] = $0; return MeldGetNetworkPartnerCountriesResponse(data: MeldNetworkPartnerCountriesResult(countries: [])) }
    api.getNetworkPartnerCurrenciesHandler = { received["currencies"] = $0; return MeldGetNetworkPartnerCurrenciesResponse(data: MeldNetworkPartnerCurrenciesResult(currencies: [])) }
    api.getNetworkPartnerFiatLimitsHandler = { received["fiatLimits"] = $0; return MeldGetNetworkPartnerFiatLimitsResponse(data: MeldNetworkPartnerFiatLimitsResult(fiatLimits: [])) }
    api.getNetworkPartnerKycLimitsHandler = { received["kycLimits"] = $0; return MeldGetNetworkPartnerKycLimitsResponse(data: MeldNetworkPartnerKycLimitsResult(kycLimits: [])) }
    api.getNetworkPartnersHandler = { received["partners"] = $0; return MeldGetNetworkPartnersResponse(data: []) }
    api.getNetworkPartnerPaymentMethodsHandler = { received["paymentMethods"] = $0; return MeldGetNetworkPartnerPaymentMethodsResponse(data: []) }
    api.getNetworkPartnerRoutesHandler = { received["routes"] = $0; return MeldGetNetworkPartnerRoutesResponse(data: []) }
    api.getNetworkPartnerCountryDefaultsHandler = { received["defaults"] = "\($0)/\($1.rawValue)"; return MeldGetNetworkPartnerCountryDefaultsResponse(data: nil) }

    let countries = MeldGetNetworkPartnerCountriesParams(category: .cryptoOnramp)
    let currencies = MeldGetNetworkPartnerCurrenciesParams(type: .crypto)
    let fiatLimits = MeldGetNetworkPartnerFiatLimitsParams(currencyCode: "USD")
    let kycLimits = MeldGetNetworkPartnerKycLimitsParams(limitType: .daily)
    let partners = MeldGetNetworkPartnersParams(country: "US")
    let paymentMethods = MeldGetNetworkPartnerPaymentMethodsParams(paymentType: .card)
    let routes = MeldGetNetworkPartnerRoutesParams(category: .cryptoOnramp, countryCode: "US", sourceCurrencyCode: "USD", destinationCurrencyCode: "ETH")

    _ = try await meld.getNetworkPartnerCountries(params: countries)
    _ = try await meld.getNetworkPartnerCurrencies(params: currencies)
    _ = try await meld.getNetworkPartnerFiatLimits(params: fiatLimits)
    _ = try await meld.getNetworkPartnerKycLimits(params: kycLimits)
    _ = try await meld.getNetworkPartners(params: partners)
    _ = try await meld.getNetworkPartnerPaymentMethods(params: paymentMethods)
    _ = try await meld.getNetworkPartnerRoutes(params: routes)
    let defaults = try await meld.getNetworkPartnerCountryDefaults(countryCode: "US", category: .cryptoOnramp)

    XCTAssertEqual(received["countries"] as? MeldGetNetworkPartnerCountriesParams, countries)
    XCTAssertEqual(received["currencies"] as? MeldGetNetworkPartnerCurrenciesParams, currencies)
    XCTAssertEqual(received["fiatLimits"] as? MeldGetNetworkPartnerFiatLimitsParams, fiatLimits)
    XCTAssertEqual(received["kycLimits"] as? MeldGetNetworkPartnerKycLimitsParams, kycLimits)
    XCTAssertEqual(received["partners"] as? MeldGetNetworkPartnersParams, partners)
    XCTAssertEqual(received["paymentMethods"] as? MeldGetNetworkPartnerPaymentMethodsParams, paymentMethods)
    XCTAssertEqual(received["routes"] as? MeldGetNetworkPartnerRoutesParams, routes)
    XCTAssertEqual(received["defaults"] as? String, "US/CRYPTO_ONRAMP")
    XCTAssertNil(defaults.data)
  }

  func test_overloads_forwardEmptyParams() async throws {
    var createRequest: MeldCreateCustomerRequest?
    var searchParams: MeldSearchRetailTransactionsParams?
    var countries: MeldGetNetworkPartnerCountriesParams?
    var currencies: MeldGetNetworkPartnerCurrenciesParams?
    var fiatLimits: MeldGetNetworkPartnerFiatLimitsParams?
    var kycLimits: MeldGetNetworkPartnerKycLimitsParams?
    var partners: MeldGetNetworkPartnersParams?
    var paymentMethods: MeldGetNetworkPartnerPaymentMethodsParams?
    api.createCustomerHandler = { createRequest = $0; return MeldCreateCustomerResponse(data: Self.customer) }
    api.searchRetailTransactionsHandler = {
      searchParams = $0
      return MeldSearchRetailTransactionsResponse(data: MeldTransactionSearchResult(count: 0, remaining: 0, totalCount: 0, transactions: []))
    }
    api.getNetworkPartnerCountriesHandler = { countries = $0; return MeldGetNetworkPartnerCountriesResponse(data: MeldNetworkPartnerCountriesResult(countries: [])) }
    api.getNetworkPartnerCurrenciesHandler = { currencies = $0; return MeldGetNetworkPartnerCurrenciesResponse(data: MeldNetworkPartnerCurrenciesResult(currencies: [])) }
    api.getNetworkPartnerFiatLimitsHandler = { fiatLimits = $0; return MeldGetNetworkPartnerFiatLimitsResponse(data: MeldNetworkPartnerFiatLimitsResult(fiatLimits: [])) }
    api.getNetworkPartnerKycLimitsHandler = { kycLimits = $0; return MeldGetNetworkPartnerKycLimitsResponse(data: MeldNetworkPartnerKycLimitsResult(kycLimits: [])) }
    api.getNetworkPartnersHandler = { partners = $0; return MeldGetNetworkPartnersResponse(data: []) }
    api.getNetworkPartnerPaymentMethodsHandler = { paymentMethods = $0; return MeldGetNetworkPartnerPaymentMethodsResponse(data: []) }

    _ = try await meld.createCustomer()
    _ = try await meld.searchRetailTransactions()
    _ = try await meld.getNetworkPartnerCountries()
    _ = try await meld.getNetworkPartnerCurrencies()
    _ = try await meld.getNetworkPartnerFiatLimits()
    _ = try await meld.getNetworkPartnerKycLimits()
    _ = try await meld.getNetworkPartners()
    _ = try await meld.getNetworkPartnerPaymentMethods()

    XCTAssertEqual(createRequest, MeldCreateCustomerRequest())
    XCTAssertEqual(searchParams, MeldSearchRetailTransactionsParams())
    XCTAssertEqual(countries, MeldGetNetworkPartnerCountriesParams())
    XCTAssertEqual(currencies, MeldGetNetworkPartnerCurrenciesParams())
    XCTAssertEqual(fiatLimits, MeldGetNetworkPartnerFiatLimitsParams())
    XCTAssertEqual(kycLimits, MeldGetNetworkPartnerKycLimitsParams())
    XCTAssertEqual(partners, MeldGetNetworkPartnersParams())
    XCTAssertEqual(paymentMethods, MeldGetNetworkPartnerPaymentMethodsParams())
  }

  // MARK: - Failures

  func test_everyMethod_rethrowsTheApisFailure() async {
    let calls: [(String, (Meld) async throws -> Void)] = [
      ("createCustomer", { _ = try await $0.createCustomer() }),
      ("searchCustomer", { _ = try await $0.searchCustomer() }),
      ("getRetailQuote", { _ = try await $0.getRetailQuote(request: MeldGetRetailQuoteRequest(
        countryCode: "US", sourceCurrencyCode: "USD", destinationCurrencyCode: "ETH", sourceAmount: 1
      )) }),
      ("createRetailWidget", { _ = try await $0.createRetailWidget(request: MeldCreateRetailWidgetRequest(
        sessionType: .buy,
        sessionData: MeldSessionData(countryCode: "US", serviceProvider: "TRANSAK", sourceCurrencyCode: "USD", sourceAmount: "1", destinationCurrencyCode: "ETH")
      )) }),
      ("searchRetailTransactions", { _ = try await $0.searchRetailTransactions() }),
      ("getRetailTransaction", { _ = try await $0.getRetailTransaction(transactionId: "t1") }),
      ("getRetailTransactionBySession", { _ = try await $0.getRetailTransactionBySession(sessionId: "s1") }),
      ("getNetworkPartnerCountries", { _ = try await $0.getNetworkPartnerCountries() }),
      ("getNetworkPartnerCurrencies", { _ = try await $0.getNetworkPartnerCurrencies() }),
      ("getNetworkPartnerFiatLimits", { _ = try await $0.getNetworkPartnerFiatLimits() }),
      ("getNetworkPartnerKycLimits", { _ = try await $0.getNetworkPartnerKycLimits() }),
      ("getNetworkPartners", { _ = try await $0.getNetworkPartners() }),
      ("getNetworkPartnerPaymentMethods", { _ = try await $0.getNetworkPartnerPaymentMethods() }),
      ("getNetworkPartnerRoutes", { _ = try await $0.getNetworkPartnerRoutes(params: MeldGetNetworkPartnerRoutesParams(
        category: .cryptoOnramp, countryCode: "US", sourceCurrencyCode: "USD", destinationCurrencyCode: "ETH"
      )) }),
      ("getNetworkPartnerCountryDefaults", { _ = try await $0.getNetworkPartnerCountryDefaults(countryCode: "US", category: .cryptoOnramp) })
    ]
    XCTAssertEqual(calls.count, 15)

    // No handler is set, so every mock method throws `NotStubbed` naming itself.
    for (name, call) in calls {
      do {
        try await call(meld)
        XCTFail("\(name) should fail")
      } catch let error as PortalMeldApiMock.NotStubbed {
        XCTAssertEqual(error.method, name)
      } catch {
        XCTFail("\(name) changed the failure: \(error)")
      }
    }
  }

  func test_aHandlersFailure_reachesTheCaller() async {
    api.searchCustomerHandler = { throw Failure() }

    do {
      _ = try await meld.searchCustomer()
      XCTFail("Expected the failure")
    } catch {
      XCTAssertEqual(error as? Failure, Failure())
    }
  }
}
