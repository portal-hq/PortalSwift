//
//  MeldCodableTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

@testable import PortalSwift
import XCTest

final class MeldCodableTests: XCTestCase {
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()

  private func decode<T: Decodable>(_: T.Type, _ json: String, file: StaticString = #filePath, line: UInt = #line) throws -> T {
    do {
      return try decoder.decode(T.self, from: Data(json.utf8))
    } catch {
      XCTFail("\(T.self) did not decode: \(error)", file: file, line: line)
      throw error
    }
  }

  /// The JSON object `value` encodes to.
  private func encodedObject<T: Encodable>(_ value: T) throws -> NSDictionary {
    try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(value)) as? NSDictionary)
  }

  /// `value` with every `null` and every ignored key removed, at any depth. An entry of `ignoring` is
  /// a key (`"supportUrl"`), or a key under a parent key (`"paymentMethods.category"`) when the same
  /// name is a real field elsewhere in the payload.
  private func normalized(_ value: Any, ignoring: Set<String>, parentKey: String? = nil) -> Any? {
    switch value {
    case is NSNull:
      return nil
    case let dictionary as [String: Any]:
      var result: [String: Any] = [:]
      for (key, element) in dictionary {
        if ignoring.contains(key) || parentKey.map({ ignoring.contains("\($0).\(key)") }) == true {
          continue
        }
        if let element = normalized(element, ignoring: ignoring, parentKey: key) {
          result[key] = element
        }
      }
      return result
    case let array as [Any]:
      return array.map { normalized($0, ignoring: ignoring, parentKey: parentKey) ?? NSNull() }
    default:
      return value
    }
  }

  /// Decodes `json`, encodes the result and checks nothing was lost or renamed: the encoded JSON
  /// must equal the fixture, nulls aside. `ignoring` lists the keys Meld sends that the model leaves
  /// out on purpose (not in connect-api's schema). A misspelled property fails here as long as some
  /// fixture gives it a value, which is why the `synthetic*Full` fixtures fill every optional.
  private func assertLosslessRoundTrip<T: Codable>(
    _: T.Type,
    _ json: String,
    ignoring: Set<String> = [],
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws {
    let value = try decode(T.self, json, file: file, line: line)
    let original = try JSONSerialization.jsonObject(with: Data(json.utf8), options: .fragmentsAllowed)
    let encoded = try JSONSerialization.jsonObject(with: encoder.encode(value), options: .fragmentsAllowed)

    let expected = normalized(original, ignoring: ignoring) as AnyObject
    let actual = normalized(encoded, ignoring: []) as AnyObject
    XCTAssertTrue(expected.isEqual(actual), "\(T.self) lost or renamed a field.\nExpected: \(expected)\nActual: \(actual)", file: file, line: line)
  }

  // MARK: - Every fixture decodes

  /// `decode` records each failure with its type and `try?` carries on, so one run names every type
  /// that no longer decodes.
  func test_everyFixture_decodesIntoItsType() {
    _ = try? decode(MeldCustomer.self, MeldFixtures.customerCreate)
    _ = try? decode(MeldCustomerSearchResult.self, MeldFixtures.customerSearch)
    _ = try? decode(MeldCustomerSearchResult.self, MeldFixtures.customerSearchEmpty)
    _ = try? decode(MeldCustomer.self, MeldFixtures.syntheticCustomerFull)
    _ = try? decode(MeldRetailQuoteResult.self, MeldFixtures.quote)
    _ = try? decode(MeldRetailQuoteResult.self, MeldFixtures.syntheticQuoteEmpty)
    _ = try? decode(MeldRetailQuoteResult.self, MeldFixtures.syntheticQuoteFull)
    _ = try? decode(MeldWidgetSession.self, MeldFixtures.syntheticWidgetSession)
    _ = try? decode(MeldTransactionSearchResult.self, MeldFixtures.transactionsSearchEmpty)
    _ = try? decode(MeldTransactionSearchResult.self, MeldFixtures.syntheticTransactionsSearch)
    _ = try? decode(MeldTransactionResult.self, MeldFixtures.syntheticTransaction)
    _ = try? decode(MeldNetworkPartnerCountriesResult.self, MeldFixtures.npCountries)
    _ = try? decode(MeldNetworkPartnerCurrenciesResult.self, MeldFixtures.npCurrenciesCrypto)
    _ = try? decode(MeldNetworkPartnerCurrenciesResult.self, MeldFixtures.npCurrenciesFiat)
    _ = try? decode(MeldNetworkPartnerFiatLimitsResult.self, MeldFixtures.npFiatLimits)
    _ = try? decode(MeldNetworkPartnerKycLimitsResult.self, MeldFixtures.npKycLimitsEmpty)
    _ = try? decode(MeldNetworkPartnerKycLimitsResult.self, MeldFixtures.syntheticNpKycLimits)
    _ = try? decode([MeldNetworkPartner].self, MeldFixtures.npPartners)
    _ = try? decode([MeldNetworkPartner].self, MeldFixtures.syntheticNpPartnersFull)
    _ = try? decode([MeldNetworkPartnerPaymentMethod].self, MeldFixtures.npPaymentMethods)
    _ = try? decode([MeldNetworkPartnerPaymentMethod].self, MeldFixtures.syntheticNpPaymentMethodsFull)
    _ = try? decode([MeldNetworkPartnerRoute].self, MeldFixtures.npRoutes)
    _ = try? decode([MeldNetworkPartnerRoute].self, MeldFixtures.syntheticNpRoutesFull)
    _ = try? decode(MeldNetworkPartnerCountryDefaults.self, MeldFixtures.npDefaults)
  }

  // MARK: - Nothing lost or renamed

  func test_fixtures_roundTripWithoutLosingAField() throws {
    try assertLosslessRoundTrip(MeldCustomer.self, MeldFixtures.customerCreate)
    try assertLosslessRoundTrip(MeldCustomerSearchResult.self, MeldFixtures.customerSearch)
    try assertLosslessRoundTrip(MeldCustomerSearchResult.self, MeldFixtures.customerSearchEmpty)
    try assertLosslessRoundTrip(MeldRetailQuoteResult.self, MeldFixtures.quote)
    try assertLosslessRoundTrip(MeldRetailQuoteResult.self, MeldFixtures.syntheticQuoteEmpty)
    try assertLosslessRoundTrip(MeldRetailQuoteResult.self, MeldFixtures.syntheticQuoteFull)
    try assertLosslessRoundTrip(MeldWidgetSession.self, MeldFixtures.syntheticWidgetSession)
    try assertLosslessRoundTrip(MeldTransactionSearchResult.self, MeldFixtures.transactionsSearchEmpty)
    try assertLosslessRoundTrip(MeldNetworkPartnerCountriesResult.self, MeldFixtures.npCountries)
    try assertLosslessRoundTrip(MeldNetworkPartnerCurrenciesResult.self, MeldFixtures.npCurrenciesCrypto)
    try assertLosslessRoundTrip(MeldNetworkPartnerCurrenciesResult.self, MeldFixtures.npCurrenciesFiat)
    try assertLosslessRoundTrip(MeldNetworkPartnerFiatLimitsResult.self, MeldFixtures.npFiatLimits)
    try assertLosslessRoundTrip(MeldNetworkPartnerKycLimitsResult.self, MeldFixtures.npKycLimitsEmpty)
    try assertLosslessRoundTrip(MeldNetworkPartnerKycLimitsResult.self, MeldFixtures.syntheticNpKycLimits)
    try assertLosslessRoundTrip(MeldNetworkPartnerCountryDefaults.self, MeldFixtures.npDefaults)
    // Fields Meld sends that connect-api's schemas do not list (a backend finding), left out on purpose.
    try assertLosslessRoundTrip([MeldNetworkPartner].self, MeldFixtures.npPartners, ignoring: ["supportUrl", "checkout", "kycLevel", "kycShareMethods"])
    try assertLosslessRoundTrip([MeldNetworkPartnerPaymentMethod].self, MeldFixtures.npPaymentMethods, ignoring: ["category", "checkoutSupported"])
    try assertLosslessRoundTrip([MeldNetworkPartnerRoute].self, MeldFixtures.npRoutes, ignoring: ["paymentMethods.category", "paymentMethods.checkoutSupported"])
    try assertLosslessRoundTrip([MeldNetworkPartner].self, MeldFixtures.syntheticNpPartnersFull, ignoring: ["supportUrl", "checkout", "kycLevel", "kycShareMethods"])
    try assertLosslessRoundTrip([MeldNetworkPartnerPaymentMethod].self, MeldFixtures.syntheticNpPaymentMethodsFull, ignoring: ["category", "checkoutSupported"])
    // `category` is a real field of the route's KYC limits; only the payment methods' one is extra.
    try assertLosslessRoundTrip([MeldNetworkPartnerRoute].self, MeldFixtures.syntheticNpRoutesFull, ignoring: ["paymentMethods.category", "paymentMethods.checkoutSupported"])
  }

  /// The five provider-specific fields keep everything Meld sends, nested `null`s included.
  func test_untypedFields_roundTripWithoutLosingAField() throws {
    try assertLosslessRoundTrip(MeldCustomer.self, MeldFixtures.syntheticCustomerFull)
    // `fiatAmountInUsd` is a transaction field the schema passes through but does not list.
    try assertLosslessRoundTrip(MeldTransactionResult.self, MeldFixtures.syntheticTransaction, ignoring: ["fiatAmountInUsd"])
    try assertLosslessRoundTrip(MeldTransactionSearchResult.self, MeldFixtures.syntheticTransactionsSearch, ignoring: ["fiatAmountInUsd"])
  }

  // MARK: - Fields

  func test_createdCustomer_hasNoKey_butTheSearchedOneHas() throws {
    let created = try decode(MeldCustomer.self, MeldFixtures.customerCreate)
    let searched = try decode(MeldCustomerSearchResult.self, MeldFixtures.customerSearch)

    XCTAssertNil(created.key)
    XCTAssertEqual(created.type, .individual)
    XCTAssertEqual(created.status, .active)
    XCTAssertEqual(searched.customers.first?.key, "REDACTED_key")
    XCTAssertEqual(searched.count, 1)
  }

  func test_quote_readsTheProviderAndAmounts() throws {
    let result = try decode(MeldRetailQuoteResult.self, MeldFixtures.quote)
    let quote = try XCTUnwrap(result.quotes.first)

    XCTAssertEqual(quote.transactionType, .cryptoPurchase)
    XCTAssertEqual(quote.serviceProvider, "TRANSAK")
    XCTAssertEqual(quote.sourceAmount, 100)
    XCTAssertEqual(quote.destinationAmount, 0.0461126)
    XCTAssertEqual(quote.paymentMethodType, "CREDIT_DEBIT_CARD")
    XCTAssertNil(quote.networkFee)
    XCTAssertNil(quote.rampIntelligence?.previouslyUsed)
    XCTAssertEqual(quote.rampIntelligence?.rampScore, 90.54)
  }

  func test_quoteWithNoProvider_isAnEmptyListWithTheReason() throws {
    let result = try decode(MeldRetailQuoteResult.self, MeldFixtures.syntheticQuoteEmpty)

    XCTAssertTrue(result.quotes.isEmpty)
    XCTAssertEqual(result.error, "NO_QUOTES")
    XCTAssertNotNil(result.message)
  }

  func test_currencies_readTheChainOfEachCryptoCurrency() throws {
    let currencies = try decode(MeldNetworkPartnerCurrenciesResult.self, MeldFixtures.npCurrenciesCrypto).currencies
    let byCode = Dictionary(uniqueKeysWithValues: currencies.map { ($0.currencyCode, $0) })

    XCTAssertEqual(byCode["ETH"]?.chainId, "1")
    XCTAssertEqual(byCode["ETH"]?.type, .crypto)
    XCTAssertEqual(byCode["SOL"]?.chainId, "101")
    XCTAssertNil(byCode["APT"]?.chainId)
    XCTAssertNil(byCode["APT"]?.contract)
  }

  func test_partners_readCapabilitiesLogoAndHeadless() throws {
    let partner = try XCTUnwrap(decode([MeldNetworkPartner].self, MeldFixtures.npPartners).first)

    XCTAssertEqual(partner.status, .live)
    XCTAssertEqual(partner.categories, [.cryptoOfframp, .cryptoOnramp])
    XCTAssertEqual(partner.capabilities.first?.domains, [.payment])
    XCTAssertFalse(partner.logo.darkShort.isEmpty)
    XCTAssertFalse(partner.headless.supported)
  }

  func test_routes_readPaymentMethodLimits() throws {
    let route = try XCTUnwrap(decode([MeldNetworkPartnerRoute].self, MeldFixtures.npRoutes).first)
    let card = try XCTUnwrap(route.paymentMethods.first { $0.name == "CREDIT_DEBIT_CARD" })

    XCTAssertEqual(card.paymentType, .card)
    XCTAssertEqual(card.limits, MeldNetworkPartnerRoute.Limits(currencyCode: "USD", min: 5, max: 3000))
    XCTAssertTrue(route.kycLimits.isEmpty)
  }

  func test_transaction_readsStatusTypeAndCryptoDetails() throws {
    let transaction = try decode(MeldTransactionResult.self, MeldFixtures.syntheticTransaction).transaction

    XCTAssertEqual(transaction.status, .settled)
    XCTAssertEqual(transaction.transactionType, .cryptoPurchase)
    XCTAssertEqual(transaction.cryptoDetails?.chainId, "1")
    XCTAssertEqual(transaction.cryptoDetails?.destinationWalletAddress, "0x000000000000000000000000000000000000dEaD")
    XCTAssertNotNil(transaction.serviceProviderDetails?["orderId"])
  }

  // MARK: - Open values

  func test_openValues_keepAValueMeldAddsLater() throws {
    var json = MeldFixtures.syntheticTransaction
    json = json.replacingOccurrences(of: #""status":"SETTLED""#, with: #""status":"PARTIALLY_REFUNDED""#)
    json = json.replacingOccurrences(of: #""transactionType":"CRYPTO_PURCHASE""#, with: #""transactionType":"CRYPTO_BRIDGE""#)

    let transaction = try decode(MeldTransactionResult.self, json).transaction

    XCTAssertEqual(transaction.status.rawValue, "PARTIALLY_REFUNDED")
    XCTAssertEqual(transaction.transactionType, "CRYPTO_BRIDGE")
    let encoded = try encodedObject(transaction)
    XCTAssertEqual(encoded["status"] as? String, "PARTIALLY_REFUNDED")
    XCTAssertEqual(encoded["transactionType"] as? String, "CRYPTO_BRIDGE")
  }

  // MARK: - Optionals

  func test_nullAndAbsentOptionals_bothDecodeAsNil() throws {
    let withNull = try decode(MeldWidgetSession.self, #"{"id":"s","token":"t","customerId":"c","externalCustomerId":"e","widgetUrl":"https://w","externalSessionId":null}"#)
    let absent = try decode(MeldWidgetSession.self, #"{"id":"s","token":"t","customerId":"c","externalCustomerId":"e","widgetUrl":"https://w"}"#)

    XCTAssertNil(withNull.externalSessionId)
    XCTAssertNil(absent.externalSessionId)
    XCTAssertEqual(withNull, absent)
  }

  func test_kycLimit_withoutLevels_decodes() throws {
    let limit = try decode(
      MeldNetworkPartnerKycLimit.self,
      #"{"provider":"TRANSAK","countryCode":"US","limitType":"DAILY","currencyCode":"USD","level1":1000,"level2":null}"#
    )

    XCTAssertEqual(limit.level1, 1000)
    XCTAssertNil(limit.level2)
    XCTAssertNil(limit.level3)
  }

  func test_countryDefaults_dataCanBeNullOrMissing() throws {
    let null = try decode(MeldGetNetworkPartnerCountryDefaultsResponse.self, #"{"data":null}"#)
    let missing = try decode(MeldGetNetworkPartnerCountryDefaultsResponse.self, "{}")
    let present = try decode(MeldGetNetworkPartnerCountryDefaultsResponse.self, #"{"data":\#(MeldFixtures.npDefaults)}"#)

    XCTAssertNil(null.data)
    XCTAssertNil(missing.data)
    XCTAssertEqual(present.data?.category, .cryptoOnramp)
    XCTAssertEqual(present.data?.paymentMethods.first, "CREDIT_DEBIT_CARD")
  }

  // MARK: - Requests

  func test_sessionType_encodesEveryValue() throws {
    let encoded = try [MeldSessionType.buy, .sell, .transfer].map { try String(decoding: encoder.encode($0), as: UTF8.self) }

    XCTAssertEqual(encoded, [#""BUY""#, #""SELL""#, #""TRANSFER""#])
  }

  func test_quoteRequest_sendsSourceAmountAsANumber() throws {
    let request = MeldGetRetailQuoteRequest(countryCode: "US", sourceCurrencyCode: "USD", destinationCurrencyCode: "ETH", sourceAmount: 100)

    let encoded = try encodedObject(request)

    XCTAssertTrue(encoded["sourceAmount"] is NSNumber)
    XCTAssertEqual((encoded["sourceAmount"] as? NSNumber)?.doubleValue, 100)
  }

  func test_widgetRequest_sendsSourceAmountAsAString() throws {
    let request = MeldCreateRetailWidgetRequest(
      sessionType: .buy,
      sessionData: MeldSessionData(
        countryCode: "US",
        serviceProvider: "TRANSAK",
        sourceCurrencyCode: "USD",
        sourceAmount: "100",
        destinationCurrencyCode: "ETH",
        lockFields: [.sourceAmount],
        clientIpAddress: "203.0.113.42"
      )
    )

    let encoded = try encodedObject(request)
    let sessionData = try XCTUnwrap(encoded["sessionData"] as? NSDictionary)

    XCTAssertEqual(encoded["sessionType"] as? String, "BUY")
    XCTAssertEqual(sessionData["sourceAmount"] as? String, "100")
    XCTAssertEqual(sessionData["lockFields"] as? [String], ["sourceAmount"])
    XCTAssertEqual(sessionData["clientIpAddress"] as? String, "203.0.113.42")
  }

  func test_requests_omitNilOptionals() throws {
    XCTAssertEqual(try encodedObject(MeldCreateCustomerRequest()), [:])

    let sessionData = try encodedObject(MeldSessionData(
      countryCode: "US",
      serviceProvider: "TRANSAK",
      sourceCurrencyCode: "USD",
      sourceAmount: "100",
      destinationCurrencyCode: "ETH"
    ))
    XCTAssertEqual(
      Set(sessionData.allKeys as? [String] ?? []),
      ["countryCode", "serviceProvider", "sourceCurrencyCode", "sourceAmount", "destinationCurrencyCode"]
    )

    let quote = try encodedObject(MeldGetRetailQuoteRequest(countryCode: "US", sourceCurrencyCode: "USD", destinationCurrencyCode: "ETH", sourceAmount: 1))
    XCTAssertEqual(Set(quote.allKeys as? [String] ?? []), ["countryCode", "sourceCurrencyCode", "destinationCurrencyCode", "sourceAmount"])
  }

  func test_createCustomerRequest_encodesNameAndType() throws {
    let request = MeldCreateCustomerRequest(name: MeldCustomerName(firstName: "Ada"), email: "ada@example.com", dateOfBirth: "1990-01-31", type: .individual)

    let encoded = try encodedObject(request)

    XCTAssertEqual(encoded["name"] as? NSDictionary, ["firstName": "Ada"])
    XCTAssertEqual(encoded["type"] as? String, "INDIVIDUAL")
    XCTAssertEqual(encoded["dateOfBirth"] as? String, "1990-01-31")
    XCTAssertNil(encoded["phone"])
  }
}
