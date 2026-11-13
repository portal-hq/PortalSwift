//
//  PortalMeldApiTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

@testable import PortalSwift
import XCTest

final class PortalMeldApiTests: XCTestCase {
  private let encoder = JSONEncoder()
  private let host = "https://\(MockConstants.mockHost)"
  private lazy var base = "\(host)/api/v3/clients/me/integrations/meld"

  private var spy: PortalRequestsSpy!
  private var api: PortalMeldApi!

  override func setUpWithError() throws {
    spy = PortalRequestsSpy()
    api = makeApi()
  }

  override func tearDownWithError() throws {
    spy = nil
    api = nil
  }

  // MARK: - Helpers

  private func makeApi() -> PortalMeldApi {
    PortalMeldApi(credentials: StaticCredentials(MockConstants.mockApiKey), apiHost: MockConstants.mockHost, requests: spy)
  }

  /// Answers with `{ "data": <json> }`.
  private func respond(data json: String) {
    spy.returnData = Data(#"{"data":\#(json)}"#.utf8)
  }

  private var lastUrl: String? {
    spy.executeRequestParam?.url.absoluteString
  }

  private func body(of request: PortalBaseRequestProtocol) throws -> NSDictionary {
    let payload = try XCTUnwrap(request.payload)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(payload)) as? NSDictionary)
  }

  /// Every key of `object`, at any depth.
  private func allKeys(_ object: Any) -> Set<String> {
    switch object {
    case let dictionary as [String: Any]:
      return dictionary.reduce(into: Set(dictionary.keys)) { $0.formUnion(allKeys($1.value)) }
    case let array as [Any]:
      return array.reduce(into: Set<String>()) { $0.formUnion(allKeys($1)) }
    default:
      return []
    }
  }

  private static let widgetRequest = MeldCreateRetailWidgetRequest(
    sessionType: .buy,
    sessionData: MeldSessionData(
      countryCode: "US",
      serviceProvider: "TRANSAK",
      sourceCurrencyCode: "USD",
      sourceAmount: "100",
      destinationCurrencyCode: "ETH",
      walletAddress: "0xabc",
      paymentMethodType: "CREDIT_DEBIT_CARD",
      lockFields: [.sourceAmount]
    ),
    externalSessionId: "my-session",
    customerId: "meld-customer-1"
  )

  private static let quoteRequest = MeldGetRetailQuoteRequest(
    countryCode: "US",
    sourceCurrencyCode: "USD",
    destinationCurrencyCode: "ETH",
    sourceAmount: 100,
    paymentMethodType: "CREDIT_DEBIT_CARD",
    serviceProviders: ["TRANSAK"]
  )

  // MARK: - Routes

  private struct Route {
    let name: String
    let method: HttpMethod
    let url: String
    let response: String
    let call: (PortalMeldApi) async throws -> Void
  }

  private lazy var routes: [Route] = [
    Route(name: "createCustomer", method: .post, url: "/customers", response: MeldFixtures.customerCreate) {
      _ = try await $0.createCustomer(request: MeldCreateCustomerRequest(email: "ada@example.com"))
    },
    Route(name: "searchCustomer", method: .get, url: "/customers", response: MeldFixtures.customerSearch) { _ = try await $0.searchCustomer() },
    Route(name: "getRetailQuote", method: .post, url: "/retail/quote", response: MeldFixtures.quote) { _ = try await $0.getRetailQuote(request: Self.quoteRequest) },
    Route(name: "createRetailWidget", method: .post, url: "/retail/widget", response: MeldFixtures.syntheticWidgetSession) {
      _ = try await $0.createRetailWidget(request: Self.widgetRequest)
    },
    Route(name: "searchRetailTransactions", method: .get, url: "/retail/transactions", response: MeldFixtures.syntheticTransactionsSearch) {
      _ = try await $0.searchRetailTransactions(params: MeldSearchRetailTransactionsParams())
    },
    Route(name: "getRetailTransaction", method: .get, url: "/retail/transactions/t1", response: MeldFixtures.syntheticTransaction) {
      _ = try await $0.getRetailTransaction(transactionId: "t1")
    },
    Route(name: "getRetailTransactionBySession", method: .get, url: "/retail/transactions/sessions/s1", response: MeldFixtures.syntheticTransaction) {
      _ = try await $0.getRetailTransactionBySession(sessionId: "s1")
    },
    Route(name: "getNetworkPartnerCountries", method: .get, url: "/network-partners/countries", response: MeldFixtures.npCountries) {
      _ = try await $0.getNetworkPartnerCountries(params: MeldGetNetworkPartnerCountriesParams())
    },
    Route(name: "getNetworkPartnerCurrencies", method: .get, url: "/network-partners/currencies", response: MeldFixtures.npCurrenciesCrypto) {
      _ = try await $0.getNetworkPartnerCurrencies(params: MeldGetNetworkPartnerCurrenciesParams())
    },
    Route(name: "getNetworkPartnerFiatLimits", method: .get, url: "/network-partners/fiat-limits", response: MeldFixtures.npFiatLimits) {
      _ = try await $0.getNetworkPartnerFiatLimits(params: MeldGetNetworkPartnerFiatLimitsParams())
    },
    Route(name: "getNetworkPartnerKycLimits", method: .get, url: "/network-partners/kyc-limits", response: MeldFixtures.syntheticNpKycLimits) {
      _ = try await $0.getNetworkPartnerKycLimits(params: MeldGetNetworkPartnerKycLimitsParams())
    },
    Route(name: "getNetworkPartners", method: .get, url: "/network-partners/partners", response: MeldFixtures.npPartners) {
      _ = try await $0.getNetworkPartners(params: MeldGetNetworkPartnersParams())
    },
    Route(name: "getNetworkPartnerPaymentMethods", method: .get, url: "/network-partners/payment-methods", response: MeldFixtures.npPaymentMethods) {
      _ = try await $0.getNetworkPartnerPaymentMethods(params: MeldGetNetworkPartnerPaymentMethodsParams())
    },
    Route(name: "getNetworkPartnerRoutes", method: .get, url: "/network-partners/routes/CRYPTO_ONRAMP/US/USD/ETH", response: MeldFixtures.npRoutes) {
      _ = try await $0.getNetworkPartnerRoutes(params: MeldGetNetworkPartnerRoutesParams(
        category: .cryptoOnramp, countryCode: "US", sourceCurrencyCode: "USD", destinationCurrencyCode: "ETH"
      ))
    },
    Route(name: "getNetworkPartnerCountryDefaults", method: .get, url: "/network-partners/defaults/US/CRYPTO_ONRAMP", response: MeldFixtures.npDefaults) {
      _ = try await $0.getNetworkPartnerCountryDefaults(countryCode: "US", category: .cryptoOnramp)
    }
  ]

  func test_everyRoute_sendsItsMethodToItsPathWithTheBearer() async throws {
    XCTAssertEqual(routes.count, 15)
    for route in routes {
      spy = PortalRequestsSpy()
      api = makeApi()
      respond(data: route.response)

      do {
        try await route.call(api)
      } catch {
        XCTFail("\(route.name) failed: \(error)")
        continue
      }

      let request = try XCTUnwrap(spy.executeRequestParam, route.name)
      XCTAssertEqual(request.method, route.method, route.name)
      XCTAssertEqual(request.url.absoluteString, base + route.url, route.name)
      XCTAssertEqual(request.headers["Authorization"], "Bearer \(MockConstants.mockApiKey)", route.name)
      if route.method == .post {
        XCTAssertNotNil(request.payload, route.name)
      } else {
        XCTAssertNil(request.payload, route.name)
      }
    }
  }

  /// Portal sets the customer's external ids from the client itself; the SDK never sends them.
  func test_noRequest_sendsTheExternalCustomerIds() async throws {
    for route in routes {
      spy = PortalRequestsSpy()
      api = makeApi()
      respond(data: route.response)
      try await route.call(api)

      let request = try XCTUnwrap(spy.executeRequestParam, route.name)
      XCTAssertFalse(request.url.absoluteString.contains("externalCustomerId"), route.name)
      XCTAssertFalse(request.url.absoluteString.contains("externalId"), route.name)
      if request.payload != nil {
        let keys = try allKeys(body(of: request))
        XCTAssertFalse(keys.contains("externalCustomerId"), route.name)
        XCTAssertFalse(keys.contains("externalId"), route.name)
      }
    }
  }

  // MARK: - Bodies

  func test_quoteAndWidget_sendTheirBodiesAsGiven() async throws {
    respond(data: MeldFixtures.quote)
    _ = try await api.getRetailQuote(request: Self.quoteRequest)
    let quote = try body(of: XCTUnwrap(spy.executeRequestParam))

    XCTAssertEqual(quote, [
      "countryCode": "US",
      "sourceCurrencyCode": "USD",
      "destinationCurrencyCode": "ETH",
      "sourceAmount": 100,
      "paymentMethodType": "CREDIT_DEBIT_CARD",
      "serviceProviders": ["TRANSAK"]
    ])

    respond(data: MeldFixtures.syntheticWidgetSession)
    _ = try await api.createRetailWidget(request: Self.widgetRequest)
    let widget = try body(of: XCTUnwrap(spy.executeRequestParam))

    XCTAssertEqual(widget, [
      "sessionType": "BUY",
      "sessionData": [
        "countryCode": "US",
        "serviceProvider": "TRANSAK",
        "sourceCurrencyCode": "USD",
        "sourceAmount": "100",
        "destinationCurrencyCode": "ETH",
        "walletAddress": "0xabc",
        "paymentMethodType": "CREDIT_DEBIT_CARD",
        "lockFields": ["sourceAmount"]
      ],
      "externalSessionId": "my-session",
      "customerId": "meld-customer-1"
    ])
  }

  func test_createCustomer_withoutDetails_sendsAnEmptyObject() async throws {
    respond(data: MeldFixtures.customerCreate)

    _ = try await api.createCustomer()

    XCTAssertEqual(try body(of: XCTUnwrap(spy.executeRequestParam)), [:])
  }

  // MARK: - Query encoding

  func test_searchRetailTransactions_sendsEveryFilterInOrder() async throws {
    respond(data: MeldFixtures.syntheticTransactionsSearch)

    _ = try await api.searchRetailTransactions(params: MeldSearchRetailTransactionsParams(
      statuses: [.settled, .pending],
      types: [.cryptoPurchase],
      serviceProviders: ["TRANSAK", "MOONPAY"],
      sessionIds: ["s1"],
      externalSessionIds: ["e1"],
      serviceProviderTransactionId: "spt 1",
      limit: 50,
      amountFrom: 100,
      amountTo: 99.5,
      from: "2026-11-01",
      to: "2026-11-13T10:00:00Z"
    ))

    XCTAssertEqual(
      lastUrl,
      "\(base)/retail/transactions?statuses=SETTLED%2CPENDING&types=CRYPTO_PURCHASE&serviceProviders=TRANSAK%2CMOONPAY&sessionIds=s1"
        + "&externalSessionIds=e1&serviceProviderTransactionId=spt%201&limit=50&amountFrom=100&amountTo=99.5&from=2026-11-01&to=2026-11-13T10%3A00%3A00Z"
    )
  }

  func test_networkPartnerFilters_areSentInOrderAsTheApiSpellsThem() async throws {
    let cases: [(url: String, response: String, call: (PortalMeldApi) async throws -> Void)] = [
      (
        "/network-partners/countries?category=CRYPTO_ONRAMP&partners=TRANSAK%2CMOONPAY",
        MeldFixtures.npCountries,
        { _ = try await $0.getNetworkPartnerCountries(params: MeldGetNetworkPartnerCountriesParams(category: .cryptoOnramp, partners: ["TRANSAK", "MOONPAY"])) }
      ),
      (
        "/network-partners/currencies?category=CRYPTO_ONRAMP&country=US&network=ETH&partner=TRANSAK&paymentType=CARD&providerCurrencyCode=eth&subdivision=US-TX&type=CRYPTO",
        MeldFixtures.npCurrenciesCrypto,
        { _ = try await $0.getNetworkPartnerCurrencies(params: MeldGetNetworkPartnerCurrenciesParams(
          category: .cryptoOnramp, country: "US", network: "ETH", partner: "TRANSAK", paymentType: .card,
          providerCurrencyCode: "eth", subdivision: "US-TX", type: .crypto
        )) }
      ),
      (
        "/network-partners/fiat-limits?category=CRYPTO_ONRAMP&country=US&currencyCode=USD&partners=TRANSAK&paymentMethod=CREDIT_DEBIT_CARD&paymentType=CARD&subdivision=US-TX",
        MeldFixtures.npFiatLimits,
        { _ = try await $0.getNetworkPartnerFiatLimits(params: MeldGetNetworkPartnerFiatLimitsParams(
          category: .cryptoOnramp, country: "US", currencyCode: "USD", partners: ["TRANSAK"],
          paymentMethod: "CREDIT_DEBIT_CARD", paymentType: .card, subdivision: "US-TX"
        )) }
      ),
      (
        "/network-partners/kyc-limits?category=CRYPTO_ONRAMP&country=US&currencyCode=USD&limitType=DAILY&partners=TRANSAK",
        MeldFixtures.syntheticNpKycLimits,
        { _ = try await $0.getNetworkPartnerKycLimits(params: MeldGetNetworkPartnerKycLimitsParams(
          category: .cryptoOnramp, country: "US", currencyCode: "USD", limitType: .daily, partners: ["TRANSAK"]
        )) }
      ),
      (
        "/network-partners/partners?category=CRYPTO_ONRAMP&country=US&cryptoCurrency=ETH&fiatCurrency=USD&partner=TRANSAK&paymentMethod=APPLE_PAY&paymentType=MOBILE_WALLET&subdivision=US-TX",
        MeldFixtures.npPartners,
        { _ = try await $0.getNetworkPartners(params: MeldGetNetworkPartnersParams(
          category: .cryptoOnramp, country: "US", cryptoCurrency: "ETH", fiatCurrency: "USD", partner: "TRANSAK",
          paymentMethod: "APPLE_PAY", paymentType: .mobileWallet, subdivision: "US-TX"
        )) }
      ),
      (
        "/network-partners/payment-methods?category=CRYPTO_ONRAMP&country=US&currencyCode=USD&partners=TRANSAK&paymentType=CARD&subdivision=US-TX",
        MeldFixtures.npPaymentMethods,
        { _ = try await $0.getNetworkPartnerPaymentMethods(params: MeldGetNetworkPartnerPaymentMethodsParams(
          category: .cryptoOnramp, country: "US", currencyCode: "USD", partners: ["TRANSAK"], paymentType: .card, subdivision: "US-TX"
        )) }
      ),
      (
        "/network-partners/routes/CRYPTO_OFFRAMP/US/ETH/USD?partners=TRANSAK&paymentMethod=CREDIT_DEBIT_CARD&paymentType=CARD&subdivision=US-TX",
        MeldFixtures.npRoutes,
        { _ = try await $0.getNetworkPartnerRoutes(params: MeldGetNetworkPartnerRoutesParams(
          category: .cryptoOfframp, countryCode: "US", sourceCurrencyCode: "ETH", destinationCurrencyCode: "USD",
          partners: ["TRANSAK"], paymentMethod: "CREDIT_DEBIT_CARD", paymentType: .card, subdivision: "US-TX"
        )) }
      )
    ]

    for (url, response, call) in cases {
      respond(data: response)
      try await call(api)
      XCTAssertEqual(lastUrl, base + url)
    }
  }

  func test_emptyFilterValues_areLeftOut() async throws {
    respond(data: MeldFixtures.npCountries)

    _ = try await api.getNetworkPartnerCountries(params: MeldGetNetworkPartnerCountriesParams(category: "", partners: ["", ""]))

    XCTAssertEqual(lastUrl, "\(base)/network-partners/countries")
  }

  func test_openValues_areSentByTheirRawValue() async throws {
    respond(data: MeldFixtures.npCurrenciesCrypto)

    _ = try await api.getNetworkPartnerCurrencies(params: MeldGetNetworkPartnerCurrenciesParams(category: "CRYPTO_SOMETHING_NEW", type: "STABLE"))

    XCTAssertEqual(lastUrl, "\(base)/network-partners/currencies?category=CRYPTO_SOMETHING_NEW&type=STABLE")
  }

  // MARK: - Amounts

  func test_amounts_areSentAsPlainDecimals() {
    XCTAssertEqual(PortalMeldApi.plainDecimal(100), "100")
    XCTAssertEqual(PortalMeldApi.plainDecimal(99.5), "99.5")
    XCTAssertEqual(PortalMeldApi.plainDecimal(1e7), "10000000")
    XCTAssertEqual(PortalMeldApi.plainDecimal(0.1), "0.1")
    XCTAssertEqual(PortalMeldApi.plainDecimal(1e16), "10000000000000000")
    XCTAssertEqual(PortalMeldApi.plainDecimal(0.0000001), "0.0000001")
    XCTAssertNil(PortalMeldApi.plainDecimal(.nan))
    XCTAssertNil(PortalMeldApi.plainDecimal(.infinity))
  }

  func test_aNonFiniteAmount_isNotSent() async throws {
    respond(data: MeldFixtures.transactionsSearchEmpty)

    _ = try await api.searchRetailTransactions(params: MeldSearchRetailTransactionsParams(amountFrom: .nan, amountTo: 1e7))

    XCTAssertEqual(lastUrl, "\(base)/retail/transactions?amountTo=10000000")
  }

  // MARK: - Path encoding

  func test_pathValues_areEncodedAsOneSegment() async throws {
    respond(data: MeldFixtures.syntheticTransaction)
    _ = try await api.getRetailTransaction(transactionId: "a/b c")
    XCTAssertEqual(lastUrl, "\(base)/retail/transactions/a%2Fb%20c")

    _ = try await api.getRetailTransactionBySession(sessionId: "s/1?x")
    XCTAssertEqual(lastUrl, "\(base)/retail/transactions/sessions/s%2F1%3Fx")

    respond(data: MeldFixtures.npRoutes)
    _ = try await api.getNetworkPartnerRoutes(params: MeldGetNetworkPartnerRoutesParams(
      category: .cryptoOnramp, countryCode: "US", sourceCurrencyCode: "US D", destinationCurrencyCode: "USDC/BASE"
    ))
    XCTAssertEqual(lastUrl, "\(base)/network-partners/routes/CRYPTO_ONRAMP/US/US%20D/USDC%2FBASE")

    respond(data: MeldFixtures.npDefaults)
    _ = try await api.getNetworkPartnerCountryDefaults(countryCode: "U/S", category: .cryptoOnramp)
    XCTAssertEqual(lastUrl, "\(base)/network-partners/defaults/U%2FS/CRYPTO_ONRAMP")
  }

  func test_anEmptyPathValue_isRefusedBeforeAnyRequest() async {
    let cases: [(name: String, call: (PortalMeldApi) async throws -> Void)] = [
      ("transactionId", { _ = try await $0.getRetailTransaction(transactionId: "") }),
      ("sessionId", { _ = try await $0.getRetailTransactionBySession(sessionId: "") }),
      ("category", { _ = try await $0.getNetworkPartnerRoutes(params: MeldGetNetworkPartnerRoutesParams(
        category: "", countryCode: "US", sourceCurrencyCode: "USD", destinationCurrencyCode: "ETH"
      )) }),
      ("countryCode", { _ = try await $0.getNetworkPartnerRoutes(params: MeldGetNetworkPartnerRoutesParams(
        category: .cryptoOnramp, countryCode: "", sourceCurrencyCode: "USD", destinationCurrencyCode: "ETH"
      )) }),
      ("sourceCurrencyCode", { _ = try await $0.getNetworkPartnerRoutes(params: MeldGetNetworkPartnerRoutesParams(
        category: .cryptoOnramp, countryCode: "US", sourceCurrencyCode: "", destinationCurrencyCode: "ETH"
      )) }),
      ("destinationCurrencyCode", { _ = try await $0.getNetworkPartnerRoutes(params: MeldGetNetworkPartnerRoutesParams(
        category: .cryptoOnramp, countryCode: "US", sourceCurrencyCode: "USD", destinationCurrencyCode: ""
      )) }),
      ("countryCode", { _ = try await $0.getNetworkPartnerCountryDefaults(countryCode: "", category: .cryptoOnramp) }),
      ("category", { _ = try await $0.getNetworkPartnerCountryDefaults(countryCode: "US", category: "") })
    ]

    for (name, call) in cases {
      do {
        try await call(api)
        XCTFail("Expected emptyIdentifier(\(name))")
      } catch {
        XCTAssertEqual(error as? MeldError, .emptyIdentifier(name: name))
      }
    }
    XCTAssertEqual(spy.executeCallsCount, 0)
  }

  // MARK: - Responses and failures

  func test_countryDefaults_nullOrMissingData_isNil() async throws {
    spy.returnData = Data(#"{"data":null}"#.utf8)
    let null = try await api.getNetworkPartnerCountryDefaults(countryCode: "AQ", category: .cryptoOnramp)
    XCTAssertNil(null.data)

    spy.returnData = Data("{}".utf8)
    let missing = try await api.getNetworkPartnerCountryDefaults(countryCode: "AQ", category: .cryptoOnramp)
    XCTAssertNil(missing.data)
  }

  func test_responses_decodeTheirData() async throws {
    respond(data: MeldFixtures.quote)
    let quote = try await api.getRetailQuote(request: Self.quoteRequest)
    XCTAssertEqual(quote.data.quotes.first?.serviceProvider, "TRANSAK")

    respond(data: MeldFixtures.npPartners)
    let partners = try await api.getNetworkPartners()
    XCTAssertEqual(partners.data.first?.serviceProvider, "TRANSAK")
  }

  func test_aFailure_isRethrownUnchanged() async {
    let failure = PortalRequestsError.clientError(
      "409 - \(MeldFixtures.errorCustomerDuplicate)",
      url: "\(base)/customers"
    )
    spy.executeThrowableErrorSequence = [failure]

    do {
      _ = try await api.createCustomer()
      XCTFail("Expected the transport's error")
    } catch {
      XCTAssertEqual(error as? PortalRequestsError, failure)
      XCTAssertEqual(MeldApiError.from(error)?.meldCustomerId, "meld-customer-1")
    }
  }

  func test_aResponseThatDoesNotMatch_failsToDecode() async {
    respond(data: #"{"customers":"nope"}"#)

    do {
      _ = try await api.searchCustomer()
      XCTFail("Expected a decoding error")
    } catch {
      XCTAssertTrue(error is DecodingError, "\(error)")
    }
  }

  // MARK: - Overloads

  func test_overloads_sendNoFilters() async throws {
    let cases: [(url: String, response: String, call: (PortalMeldApi) async throws -> Void)] = [
      ("/retail/transactions", MeldFixtures.transactionsSearchEmpty, { _ = try await $0.searchRetailTransactions() }),
      ("/network-partners/countries", MeldFixtures.npCountries, { _ = try await $0.getNetworkPartnerCountries() }),
      ("/network-partners/currencies", MeldFixtures.npCurrenciesFiat, { _ = try await $0.getNetworkPartnerCurrencies() }),
      ("/network-partners/fiat-limits", MeldFixtures.npFiatLimits, { _ = try await $0.getNetworkPartnerFiatLimits() }),
      ("/network-partners/kyc-limits", MeldFixtures.npKycLimitsEmpty, { _ = try await $0.getNetworkPartnerKycLimits() }),
      ("/network-partners/partners", MeldFixtures.npPartners, { _ = try await $0.getNetworkPartners() }),
      ("/network-partners/payment-methods", MeldFixtures.npPaymentMethods, { _ = try await $0.getNetworkPartnerPaymentMethods() })
    ]

    for (url, response, call) in cases {
      respond(data: response)
      try await call(api)
      XCTAssertEqual(lastUrl, base + url)
    }
  }

  // MARK: - Credentials

  func test_construction_installsTheUnauthorizedHook() {
    XCTAssertEqual(spy.onUnauthorizedSetCount, 1)
  }
}
