//
//  PortalMeldApi.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Protocol describing the Meld API surface.
public protocol PortalMeldApiProtocol: AnyObject {
  // Customers
  func createCustomer(request: MeldCreateCustomerRequest) async throws -> MeldCreateCustomerResponse
  func searchCustomer() async throws -> MeldSearchCustomerResponse

  // Retail
  func getRetailQuote(request: MeldGetRetailQuoteRequest) async throws -> MeldGetRetailQuoteResponse
  func createRetailWidget(request: MeldCreateRetailWidgetRequest) async throws -> MeldCreateRetailWidgetResponse
  func searchRetailTransactions(params: MeldSearchRetailTransactionsParams) async throws -> MeldSearchRetailTransactionsResponse
  func getRetailTransaction(transactionId: String) async throws -> MeldGetRetailTransactionResponse
  func getRetailTransactionBySession(sessionId: String) async throws -> MeldGetRetailTransactionResponse

  // Network Partners
  func getNetworkPartnerCountries(params: MeldGetNetworkPartnerCountriesParams) async throws -> MeldGetNetworkPartnerCountriesResponse
  func getNetworkPartnerCurrencies(params: MeldGetNetworkPartnerCurrenciesParams) async throws -> MeldGetNetworkPartnerCurrenciesResponse
  func getNetworkPartnerFiatLimits(params: MeldGetNetworkPartnerFiatLimitsParams) async throws -> MeldGetNetworkPartnerFiatLimitsResponse
  func getNetworkPartnerKycLimits(params: MeldGetNetworkPartnerKycLimitsParams) async throws -> MeldGetNetworkPartnerKycLimitsResponse
  func getNetworkPartners(params: MeldGetNetworkPartnersParams) async throws -> MeldGetNetworkPartnersResponse
  func getNetworkPartnerPaymentMethods(params: MeldGetNetworkPartnerPaymentMethodsParams) async throws -> MeldGetNetworkPartnerPaymentMethodsResponse
  func getNetworkPartnerRoutes(params: MeldGetNetworkPartnerRoutesParams) async throws -> MeldGetNetworkPartnerRoutesResponse
  func getNetworkPartnerCountryDefaults(countryCode: String, category: MeldCategory) async throws -> MeldGetNetworkPartnerCountryDefaultsResponse
}

public extension PortalMeldApiProtocol {
  /// Convenience overload of `createCustomer` with no customer details.
  func createCustomer() async throws -> MeldCreateCustomerResponse {
    try await createCustomer(request: MeldCreateCustomerRequest())
  }

  /// Convenience overload of `searchRetailTransactions` without filters.
  func searchRetailTransactions() async throws -> MeldSearchRetailTransactionsResponse {
    try await searchRetailTransactions(params: MeldSearchRetailTransactionsParams())
  }

  /// Convenience overload of `getNetworkPartnerCountries` without filters.
  func getNetworkPartnerCountries() async throws -> MeldGetNetworkPartnerCountriesResponse {
    try await getNetworkPartnerCountries(params: MeldGetNetworkPartnerCountriesParams())
  }

  /// Convenience overload of `getNetworkPartnerCurrencies` without filters.
  func getNetworkPartnerCurrencies() async throws -> MeldGetNetworkPartnerCurrenciesResponse {
    try await getNetworkPartnerCurrencies(params: MeldGetNetworkPartnerCurrenciesParams())
  }

  /// Convenience overload of `getNetworkPartnerFiatLimits` without filters.
  func getNetworkPartnerFiatLimits() async throws -> MeldGetNetworkPartnerFiatLimitsResponse {
    try await getNetworkPartnerFiatLimits(params: MeldGetNetworkPartnerFiatLimitsParams())
  }

  /// Convenience overload of `getNetworkPartnerKycLimits` without filters.
  func getNetworkPartnerKycLimits() async throws -> MeldGetNetworkPartnerKycLimitsResponse {
    try await getNetworkPartnerKycLimits(params: MeldGetNetworkPartnerKycLimitsParams())
  }

  /// Convenience overload of `getNetworkPartners` without filters.
  func getNetworkPartners() async throws -> MeldGetNetworkPartnersResponse {
    try await getNetworkPartners(params: MeldGetNetworkPartnersParams())
  }

  /// Convenience overload of `getNetworkPartnerPaymentMethods` without filters.
  func getNetworkPartnerPaymentMethods() async throws -> MeldGetNetworkPartnerPaymentMethodsResponse {
    try await getNetworkPartnerPaymentMethods(params: MeldGetNetworkPartnerPaymentMethodsParams())
  }
}

/// API class for the Meld fiat on- and off-ramp integration.
///
/// All endpoints sit under `/api/v3/clients/me/integrations/meld/*`, require the client credential as
/// a bearer token, and return `{ "data": ... }`. Meld must be enabled for the environment in the
/// Portal Dashboard. Failures are thrown as the transport reports them (`PortalRequestsError`); read
/// the status, message and `meldCustomerId` with `MeldApiError.from(_:)`.
public class PortalMeldApi: PortalMeldApiProtocol {
  /// Resolved per request and never cached, so a session rotated or invalidated underneath
  /// this instance is honoured on the next call. Shared by identity with the owning `PortalApi`.
  private let credentials: PortalCredentials
  private let requests: PortalRequestsProtocol
  private let requestBuilder: PortalIntegrationRequestBuilder
  private let logger = PortalLogger.shared

  /// Create an instance of `PortalMeldApi`.
  ///
  /// The credential is resolved again on every request and never at construction, so a session
  /// that rotates or is invalidated underneath this instance takes effect on the next call. The
  /// transport's 401 hook is wired to `credentials` only when the transport reports 401s and has
  /// no hook yet, and the `apiHost` is registered as Portal-owned (`PortalOwnedHosts`) so the hook
  /// and the trace header apply to it.
  /// - Parameters:
  ///   - credentials: The credential presented as the bearer on every request: a `StaticCredentials`
  ///     wrapping a Client API Key, or a session obtained through `PortalAuth`.
  ///   - apiHost: The Portal API hostname.
  ///   - requests: An instance of `PortalRequestsProtocol` used to perform HTTP requests.
  public init(
    credentials: PortalCredentials,
    apiHost: String = "api.portalhq.io",
    requests: PortalRequestsProtocol? = nil
  ) {
    self.credentials = credentials
    self.requestBuilder = PortalIntegrationRequestBuilder(
      baseUrl: apiHost.starts(with: "localhost") ? "http://\(apiHost)" : "https://\(apiHost)",
      basePath: "/api/v3/clients/me/integrations/meld",
      emptyIdentifier: { MeldError.emptyIdentifier(name: $0) }
    )
    self.requests = requests ?? PortalRequests()
    PortalOwnedHosts.register(apiHost)

    PortalCredentialSupport.installUnauthorizedHook(on: self.requests, for: credentials, context: "PortalMeldApi")
  }

  /*******************************************
   * Customers
   *******************************************/

  /// `POST /customers`: create the client's Meld customer. A client has at most one; a second call
  /// fails with `409`, and `MeldApiError.from(_:)?.meldCustomerId` is the existing customer's id.
  public func createCustomer(request: MeldCreateCustomerRequest) async throws -> MeldCreateCustomerResponse {
    try await post("createCustomer", path: "/customers", payload: request)
  }

  /// `GET /customers`: the client's Meld customer, if it has one.
  public func searchCustomer() async throws -> MeldSearchCustomerResponse {
    try await get("searchCustomer", path: "/customers")
  }

  /*******************************************
   * Retail
   *******************************************/

  /// `POST /retail/quote`: price a purchase or sale across the service providers. `sourceAmount` is
  /// a number here and a string in the widget session's `MeldSessionData`. A request no provider can
  /// serve can still succeed, with empty `quotes` and an `error` or `message`.
  public func getRetailQuote(request: MeldGetRetailQuoteRequest) async throws -> MeldGetRetailQuoteResponse {
    try await post("getRetailQuote", path: "/retail/quote", payload: request)
  }

  /// `POST /retail/widget`: start a widget session at one service provider, usually a quote's
  /// `serviceProvider`. Open the returned `widgetUrl` in the browser (`SFSafariViewController`), not
  /// in an in-app web view; its token is single-use.
  public func createRetailWidget(request: MeldCreateRetailWidgetRequest) async throws -> MeldCreateRetailWidgetResponse {
    try await post("createRetailWidget", path: "/retail/widget", payload: request)
  }

  /// `GET /retail/transactions`: the client's transactions, newest first. There is no paging: at most
  /// `limit` (up to 100) come back; narrow the search with `from` / `to`.
  public func searchRetailTransactions(params: MeldSearchRetailTransactionsParams) async throws -> MeldSearchRetailTransactionsResponse {
    try await get("searchRetailTransactions", path: "/retail/transactions", query: [
      ("statuses", PortalIntegrationRequestBuilder.joined(params.statuses?.map(\.rawValue))),
      ("types", PortalIntegrationRequestBuilder.joined(params.types?.map(\.rawValue))),
      ("serviceProviders", PortalIntegrationRequestBuilder.joined(params.serviceProviders)),
      ("sessionIds", PortalIntegrationRequestBuilder.joined(params.sessionIds)),
      ("externalSessionIds", PortalIntegrationRequestBuilder.joined(params.externalSessionIds)),
      ("serviceProviderTransactionId", params.serviceProviderTransactionId),
      ("limit", params.limit.map(String.init)),
      ("amountFrom", params.amountFrom.flatMap(Self.plainDecimal)),
      ("amountTo", params.amountTo.flatMap(Self.plainDecimal)),
      ("from", params.from),
      ("to", params.to)
    ])
  }

  /// `GET /retail/transactions/:transactionId`: one transaction.
  public func getRetailTransaction(transactionId: String) async throws -> MeldGetRetailTransactionResponse {
    try await get("getRetailTransaction", path: "/retail/transactions/\(pathSegment("transactionId", transactionId))")
  }

  /// `GET /retail/transactions/sessions/:sessionId`: the transaction of a widget session (the
  /// session's `id`). Fails with `404` until the user has started a purchase in the widget.
  public func getRetailTransactionBySession(sessionId: String) async throws -> MeldGetRetailTransactionResponse {
    try await get("getRetailTransactionBySession", path: "/retail/transactions/sessions/\(pathSegment("sessionId", sessionId))")
  }

  /*******************************************
   * Network Partners
   *******************************************/

  /// `GET /network-partners/countries`: the countries the service providers serve.
  public func getNetworkPartnerCountries(params: MeldGetNetworkPartnerCountriesParams) async throws -> MeldGetNetworkPartnerCountriesResponse {
    try await get("getNetworkPartnerCountries", path: "/network-partners/countries", query: [
      ("category", params.category?.rawValue),
      ("partners", PortalIntegrationRequestBuilder.joined(params.partners))
    ])
  }

  /// `GET /network-partners/currencies`: fiat and crypto currencies. Crypto currency codes are per
  /// chain; each currency's `chainId` says which.
  public func getNetworkPartnerCurrencies(params: MeldGetNetworkPartnerCurrenciesParams) async throws -> MeldGetNetworkPartnerCurrenciesResponse {
    try await get("getNetworkPartnerCurrencies", path: "/network-partners/currencies", query: [
      ("category", params.category?.rawValue),
      ("country", params.country),
      ("network", params.network),
      ("partner", params.partner),
      ("paymentType", params.paymentType?.rawValue),
      ("providerCurrencyCode", params.providerCurrencyCode),
      ("subdivision", params.subdivision),
      ("type", params.type?.rawValue)
    ])
  }

  /// `GET /network-partners/fiat-limits`: the fiat amount range of each provider and payment method.
  public func getNetworkPartnerFiatLimits(params: MeldGetNetworkPartnerFiatLimitsParams) async throws -> MeldGetNetworkPartnerFiatLimitsResponse {
    try await get("getNetworkPartnerFiatLimits", path: "/network-partners/fiat-limits", query: [
      ("category", params.category?.rawValue),
      ("country", params.country),
      ("currencyCode", params.currencyCode),
      ("partners", PortalIntegrationRequestBuilder.joined(params.partners)),
      ("paymentMethod", params.paymentMethod),
      ("paymentType", params.paymentType?.rawValue),
      ("subdivision", params.subdivision)
    ])
  }

  /// `GET /network-partners/kyc-limits`: how much a customer can transact per period at each KYC
  /// level.
  public func getNetworkPartnerKycLimits(params: MeldGetNetworkPartnerKycLimitsParams) async throws -> MeldGetNetworkPartnerKycLimitsResponse {
    try await get("getNetworkPartnerKycLimits", path: "/network-partners/kyc-limits", query: [
      ("category", params.category?.rawValue),
      ("country", params.country),
      ("currencyCode", params.currencyCode),
      ("limitType", params.limitType?.rawValue),
      ("partners", PortalIntegrationRequestBuilder.joined(params.partners))
    ])
  }

  /// `GET /network-partners/partners`: the service providers, their capabilities and logos.
  public func getNetworkPartners(params: MeldGetNetworkPartnersParams) async throws -> MeldGetNetworkPartnersResponse {
    try await get("getNetworkPartners", path: "/network-partners/partners", query: [
      ("category", params.category?.rawValue),
      ("country", params.country),
      ("cryptoCurrency", params.cryptoCurrency),
      ("fiatCurrency", params.fiatCurrency),
      ("partner", params.partner),
      ("paymentMethod", params.paymentMethod),
      ("paymentType", params.paymentType?.rawValue),
      ("subdivision", params.subdivision)
    ])
  }

  /// `GET /network-partners/payment-methods`: the payment methods available.
  public func getNetworkPartnerPaymentMethods(params: MeldGetNetworkPartnerPaymentMethodsParams) async throws -> MeldGetNetworkPartnerPaymentMethodsResponse {
    try await get("getNetworkPartnerPaymentMethods", path: "/network-partners/payment-methods", query: [
      ("category", params.category?.rawValue),
      ("country", params.country),
      ("currencyCode", params.currencyCode),
      ("partners", PortalIntegrationRequestBuilder.joined(params.partners)),
      ("paymentType", params.paymentType?.rawValue),
      ("subdivision", params.subdivision)
    ])
  }

  /// `GET /network-partners/routes/:category/:countryCode/:sourceCurrencyCode/:destinationCurrencyCode`:
  /// what each partner supports for a currency pair, with each payment method's limits.
  public func getNetworkPartnerRoutes(params: MeldGetNetworkPartnerRoutesParams) async throws -> MeldGetNetworkPartnerRoutesResponse {
    try await get(
      "getNetworkPartnerRoutes",
      path: "/network-partners/routes/\(pathSegment("category", params.category.rawValue))"
        + "/\(pathSegment("countryCode", params.countryCode))"
        + "/\(pathSegment("sourceCurrencyCode", params.sourceCurrencyCode))"
        + "/\(pathSegment("destinationCurrencyCode", params.destinationCurrencyCode))",
      query: [
        ("partners", PortalIntegrationRequestBuilder.joined(params.partners)),
        ("paymentMethod", params.paymentMethod),
        ("paymentType", params.paymentType?.rawValue),
        ("subdivision", params.subdivision)
      ]
    )
  }

  /// `GET /network-partners/defaults/:countryCode/:category`: the country's default fiat currency
  /// and payment methods. `data` is `nil` when Meld has none.
  public func getNetworkPartnerCountryDefaults(
    countryCode: String,
    category: MeldCategory
  ) async throws -> MeldGetNetworkPartnerCountryDefaultsResponse {
    try await get(
      "getNetworkPartnerCountryDefaults",
      path: "/network-partners/defaults/\(pathSegment("countryCode", countryCode))/\(pathSegment("category", category.rawValue))"
    )
  }

  /*******************************************
   * Private functions
   *******************************************/

  /// `value` as a plain decimal, with no exponent and no trailing `.0` (`100`, `99.5`, `10000000`),
  /// whatever the device locale. `nil` for a non-finite value, which is then not sent.
  static func plainDecimal(_ value: Double) -> String? {
    guard value.isFinite,
          let decimal = Decimal(string: "\(value)", locale: Locale(identifier: "en_US_POSIX"))
    else {
      return nil
    }
    return "\(decimal)"
  }

  private func pathSegment(_ name: String, _ value: String) throws -> String {
    try requestBuilder.pathSegment(name, value)
  }

  private func get<ResponseType: Decodable>(
    _ method: String,
    path: @autoclosure () throws -> String,
    query: [(String, String?)] = []
  ) async throws -> ResponseType {
    do {
      let url = try requestBuilder.makeUrl(path: path(), query: query)
      // Resolved here, at the moment the request is built, so a rotated session is sent on the
      // next call and a dead one fails before anything reaches the wire.
      let token = try PortalCredentialSupport.resolveToken(self.credentials)
      let portalRequest = PortalAPIRequest(url: url, bearerToken: token)
      return try await requests.execute(request: portalRequest, mappingInResponse: ResponseType.self)
    } catch {
      logger.error("PortalMeldApi.\(method)() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  private func post<ResponseType: Decodable>(
    _ method: String,
    path: @autoclosure () throws -> String,
    payload: Codable
  ) async throws -> ResponseType {
    do {
      let url = try requestBuilder.makeUrl(path: path())
      let token = try PortalCredentialSupport.resolveToken(self.credentials)
      let portalRequest = PortalAPIRequest(url: url, method: .post, payload: payload, bearerToken: token)
      return try await requests.execute(request: portalRequest, mappingInResponse: ResponseType.self)
    } catch {
      logger.error("PortalMeldApi.\(method)() - Error: \(error.localizedDescription)")
      throw error
    }
  }
}
