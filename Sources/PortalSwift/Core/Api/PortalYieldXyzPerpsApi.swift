//
//  PortalYieldXyzPerpsApi.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Protocol describing the Yield.xyz Perps API surface.
public protocol PortalYieldXyzPerpsApiProtocol: AnyObject {
  func getProviders() async throws -> YieldXyzPerpsGetProvidersResponse
  func getProvider(providerId: String) async throws -> YieldXyzPerpsGetProviderResponse
  func getMarkets(params: YieldXyzPerpsGetMarketsParams) async throws -> YieldXyzPerpsGetMarketsResponse
  func getMarket(marketId: String) async throws -> YieldXyzPerpsGetMarketResponse
  func getMarketCandles(marketId: String, params: YieldXyzPerpsGetMarketCandlesParams) async throws -> YieldXyzPerpsGetMarketCandlesResponse
  func getPositions(request: YieldXyzPerpsPortfolioRequest) async throws -> YieldXyzPerpsGetPositionsResponse
  func getOrders(request: YieldXyzPerpsPortfolioRequest) async throws -> YieldXyzPerpsGetOrdersResponse
  func getBalances(request: YieldXyzPerpsPortfolioRequest) async throws -> YieldXyzPerpsGetBalancesResponse
  func createAction(request: YieldXyzPerpsCreateActionRequest) async throws -> YieldXyzPerpsCreateActionResponse
  func getActions(request: YieldXyzPerpsGetActionsRequest) async throws -> YieldXyzPerpsGetActionsResponse
  func getAction(actionId: String) async throws -> YieldXyzPerpsGetActionResponse
  func submitTransaction(params: YieldXyzPerpsSubmitTransactionParams) async throws -> YieldXyzPerpsSubmitTransactionResponse
  func getActivity(request: YieldXyzPerpsGetActivityRequest) async throws -> YieldXyzPerpsGetActivityResponse
  func getEvents(request: YieldXyzPerpsGetEventsRequest) async throws -> YieldXyzPerpsGetEventsResponse
  func getEvent(eventId: String) async throws -> YieldXyzPerpsGetEventResponse
  func getHealth() async throws -> YieldXyzPerpsGetHealthResponse
  func getProvidersHealth() async throws -> YieldXyzPerpsGetProvidersHealthResponse
}

public extension PortalYieldXyzPerpsApiProtocol {
  /// Convenience overload of `getMarkets` without filters.
  func getMarkets() async throws -> YieldXyzPerpsGetMarketsResponse {
    try await getMarkets(params: YieldXyzPerpsGetMarketsParams())
  }
}

/// API class for the Yield.xyz Perps integration.
///
/// Mirrors the React Native `PortalYieldXyzPerpsApi` HTTP surface. All endpoints sit under
/// `/api/v3/clients/me/integrations/yield-xyz-perps/*`, require the client credential as a bearer
/// token, and return `{ "data": ... }`. Failures are thrown as the transport reports them
/// (`PortalRequestsError`); read the Portal error `id` and `details` with
/// `YieldXyzPerpsApiError.from(_:)`.
public class PortalYieldXyzPerpsApi: PortalYieldXyzPerpsApiProtocol {
  /// Resolved per request and never cached, so a session rotated or invalidated underneath
  /// this instance is honoured on the next call. Shared by identity with the owning `PortalApi`.
  private let credentials: PortalCredentials
  private let baseUrl: String
  private let requests: PortalRequestsProtocol
  private let logger = PortalLogger.shared

  private static let basePath = "/api/v3/clients/me/integrations/yield-xyz-perps"

  /// The characters `encodeURIComponent` leaves unescaped. Query values and path segments are
  /// encoded with it so the wire format matches the other Portal SDKs, and so `+`, `&`, `=`, `,`,
  /// `/` and `:` never reach the server unescaped (Express decodes a raw `+` as a space).
  private static let uriComponentAllowed = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()"
  )

  /// Create an instance of `PortalYieldXyzPerpsApi`.
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
    self.baseUrl = apiHost.starts(with: "localhost") ? "http://\(apiHost)" : "https://\(apiHost)"
    self.requests = requests ?? PortalRequests()
    PortalOwnedHosts.register(apiHost)

    PortalCredentialSupport.installUnauthorizedHook(on: self.requests, for: credentials, context: "PortalYieldXyzPerpsApi")
  }

  /// Create an instance of `PortalYieldXyzPerpsApi`.
  ///
  /// Kept as a convenience; the key is wrapped in `StaticCredentials` and everything else follows
  /// the credentials path. A blank key fails on first use with `PortalCredentialError.unavailable`.
  /// - Parameters:
  ///   - apiKey: The Portal Client API key.
  ///   - apiHost: The Portal API hostname.
  ///   - requests: An instance of `PortalRequestsProtocol` used to perform HTTP requests.
  @available(*, deprecated, message: "Use init(credentials:) instead; wrap a Client API Key in StaticCredentials(apiKey) or pass a PortalAuth session.")
  public convenience init(
    apiKey: String,
    apiHost: String = "api.portalhq.io",
    requests: PortalRequestsProtocol? = nil
  ) {
    self.init(credentials: StaticCredentials(apiKey), apiHost: apiHost, requests: requests)
  }

  /*******************************************
   * Public functions
   *******************************************/

  /// List the trading venues, their supported actions and the `args` schema of each action.
  public func getProviders() async throws -> YieldXyzPerpsGetProvidersResponse {
    try await get("getProviders", path: "/providers")
  }

  /// Get one trading venue.
  public func getProvider(providerId: String) async throws -> YieldXyzPerpsGetProviderResponse {
    try await get("getProvider", path: "/providers/\(pathSegment(providerId))")
  }

  /// List markets, optionally filtered by venue and sorted.
  public func getMarkets(params: YieldXyzPerpsGetMarketsParams) async throws -> YieldXyzPerpsGetMarketsResponse {
    try await get("getMarkets", path: "/markets", query: [
      ("offset", params.offset.map(String.init)),
      ("limit", params.limit.map(String.init)),
      ("providerId", params.providerId),
      ("sortBy", params.sortBy?.rawValue),
      ("order", params.order?.rawValue)
    ])
  }

  /// Get one market.
  public func getMarket(marketId: String) async throws -> YieldXyzPerpsGetMarketResponse {
    try await get("getMarket", path: "/markets/\(pathSegment(marketId))")
  }

  /// Get OHLCV candles of a market over a time window.
  public func getMarketCandles(
    marketId: String,
    params: YieldXyzPerpsGetMarketCandlesParams
  ) async throws -> YieldXyzPerpsGetMarketCandlesResponse {
    try await get("getMarketCandles", path: "/markets/\(pathSegment(marketId))/candles", query: [
      ("interval", params.interval.rawValue),
      ("from", String(params.from)),
      ("to", params.to.map { String($0) })
    ])
  }

  /// Get an account's open positions on one or more venues.
  public func getPositions(request: YieldXyzPerpsPortfolioRequest) async throws -> YieldXyzPerpsGetPositionsResponse {
    try await post("getPositions", path: "/positions", payload: request.sanitized)
  }

  /// Get an account's resting orders on one or more venues.
  public func getOrders(request: YieldXyzPerpsPortfolioRequest) async throws -> YieldXyzPerpsGetOrdersResponse {
    try await post("getOrders", path: "/orders", payload: request.sanitized)
  }

  /// Get an account's collateral and margin on one venue.
  public func getBalances(request: YieldXyzPerpsPortfolioRequest) async throws -> YieldXyzPerpsGetBalancesResponse {
    try await post("getBalances", path: "/balances", payload: request.sanitized)
  }

  /// Build an action and return it with its unsigned transactions.
  public func createAction(request: YieldXyzPerpsCreateActionRequest) async throws -> YieldXyzPerpsCreateActionResponse {
    try await post("createAction", path: "/actions", payload: request)
  }

  /// List an account's actions.
  public func getActions(request: YieldXyzPerpsGetActionsRequest) async throws -> YieldXyzPerpsGetActionsResponse {
    let params = request.params
    return try await get("getActions", path: "/actions", query: [
      ("offset", params.offset.map(String.init)),
      ("limit", params.limit.map(String.init)),
      ("address", request.address),
      ("providerId", params.providerId),
      ("marketId", params.marketId),
      ("type", params.type?.rawValue),
      ("status", params.status?.rawValue),
      ("statuses", Self.joined(params.statuses?.map(\.rawValue)))
    ])
  }

  /// Get one action with its transactions and status.
  public func getAction(actionId: String) async throws -> YieldXyzPerpsGetActionResponse {
    try await get("getAction", path: "/actions/\(pathSegment(actionId))")
  }

  /// Submit a signature or a broadcast transaction hash for one transaction. Keys left `nil` are
  /// not sent.
  public func submitTransaction(params: YieldXyzPerpsSubmitTransactionParams) async throws -> YieldXyzPerpsSubmitTransactionResponse {
    let body = YieldXyzPerpsSubmitTransactionBody(
      signedPayload: params.signedPayload,
      transactionHash: params.transactionHash,
      actionId: params.actionId
    )
    return try await post("submitTransaction", path: "/transactions/\(pathSegment(params.transactionId))/submit", payload: body)
  }

  /// Get an account's unified activity feed (actions and events, newest first).
  public func getActivity(request: YieldXyzPerpsGetActivityRequest) async throws -> YieldXyzPerpsGetActivityResponse {
    let params = request.params
    return try await get("getActivity", path: "/activity", query: [
      ("offset", params.offset.map(String.init)),
      ("limit", params.limit.map(String.init)),
      ("address", request.address),
      ("providerId", params.providerId),
      ("providerIds", Self.joined(params.providerIds)),
      ("actionStatus", params.actionStatus?.rawValue),
      ("actionStatuses", Self.joined(params.actionStatuses?.map(\.rawValue)))
    ])
  }

  /// List an account's lifecycle events.
  public func getEvents(request: YieldXyzPerpsGetEventsRequest) async throws -> YieldXyzPerpsGetEventsResponse {
    let params = request.params
    return try await get("getEvents", path: "/events", query: [
      ("offset", params.offset.map(String.init)),
      ("limit", params.limit.map(String.init)),
      ("address", request.address),
      ("providerId", params.providerId),
      ("providerIds", Self.joined(params.providerIds)),
      ("eventType", params.eventType?.rawValue),
      ("eventTypes", Self.joined(params.eventTypes?.map(\.rawValue))),
      ("marketId", params.marketId),
      ("perpActionId", params.perpActionId),
      ("providerOrderId", params.providerOrderId),
      ("fromDate", params.fromDate),
      ("toDate", params.toDate)
    ])
  }

  /// Get one lifecycle event.
  public func getEvent(eventId: String) async throws -> YieldXyzPerpsGetEventResponse {
    try await get("getEvent", path: "/events/\(pathSegment(eventId))")
  }

  /// Get the Yield.xyz Perps API health.
  public func getHealth() async throws -> YieldXyzPerpsGetHealthResponse {
    try await get("getHealth", path: "/health")
  }

  /// Get per-venue health.
  public func getProvidersHealth() async throws -> YieldXyzPerpsGetProvidersHealthResponse {
    try await get("getProvidersHealth", path: "/health/providers")
  }

  /*******************************************
   * Private functions
   *******************************************/

  /// Percent-encodes `value` as a single URI component.
  private static func encodeURIComponent(_ value: String) -> String? {
    value.addingPercentEncoding(withAllowedCharacters: uriComponentAllowed)
  }

  /// Comma-joins a list filter, skipping blank entries; an empty list is not sent.
  private static func joined(_ values: [String]?) -> String? {
    guard let values = values?.filter({ !$0.isEmpty }), !values.isEmpty else {
      return nil
    }
    return values.joined(separator: ",")
  }

  private func pathSegment(_ value: String) throws -> String {
    guard let encoded = Self.encodeURIComponent(value) else {
      throw PortalApiError.unableToEncodeData
    }
    return encoded
  }

  /// Builds the URL of `path` with the query items that have a value, in the order given. A blank
  /// value is not sent: the Portal API rejects an empty string.
  private func makeUrl(path: String, query: [(String, String?)]) throws -> URL {
    var urlString = "\(baseUrl)\(Self.basePath)\(path)"
    var pairs: [String] = []
    for (name, value) in query {
      guard let value, !value.isEmpty else {
        continue
      }
      guard let encoded = Self.encodeURIComponent(value) else {
        throw PortalApiError.unableToEncodeData
      }
      pairs.append("\(name)=\(encoded)")
    }
    if !pairs.isEmpty {
      urlString += "?" + pairs.joined(separator: "&")
    }
    guard let url = URL(string: urlString) else {
      throw URLError(.badURL)
    }
    return url
  }

  private func get<ResponseType: Decodable>(
    _ method: String,
    path: @autoclosure () throws -> String,
    query: [(String, String?)] = []
  ) async throws -> ResponseType {
    do {
      let url = try makeUrl(path: path(), query: query)
      // Resolved here, at the moment the request is built, so a rotated session is sent on the
      // next call and a dead one fails before anything reaches the wire.
      let token = try PortalCredentialSupport.resolveToken(self.credentials)
      let portalRequest = PortalAPIRequest(url: url, bearerToken: token)
      return try await requests.execute(request: portalRequest, mappingInResponse: ResponseType.self)
    } catch {
      logger.error("PortalYieldXyzPerpsApi.\(method)() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  private func post<ResponseType: Decodable>(
    _ method: String,
    path: @autoclosure () throws -> String,
    payload: Codable
  ) async throws -> ResponseType {
    do {
      let url = try makeUrl(path: path(), query: [])
      let token = try PortalCredentialSupport.resolveToken(self.credentials)
      let portalRequest = PortalAPIRequest(url: url, method: .post, payload: payload, bearerToken: token)
      return try await requests.execute(request: portalRequest, mappingInResponse: ResponseType.self)
    } catch {
      logger.error("PortalYieldXyzPerpsApi.\(method)() - Error: \(error.localizedDescription)")
      throw error
    }
  }
}
