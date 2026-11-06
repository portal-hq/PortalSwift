//
//  PortalAggApi.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Protocol describing the Agg prediction-markets API surface: one method per route.
public protocol PortalAggApiProtocol: AnyObject {
  // Link
  func createLinkChallenge(request: AggLinkChallengeRequest) async throws -> AggCreateLinkChallengeResponse
  func createLink(request: AggLinkRequest) async throws -> AggCreateLinkResponse
  func getLink() async throws -> AggGetLinkResponse
  func deleteLink() async throws -> AggDeleteLinkResponse

  // Discovery
  func listEvents(params: AggListEventsParams) async throws -> AggListEventsResponse
  func getEvent(eventId: String, cluster: Bool?) async throws -> AggGetEventResponse
  func getEventBootstrap(eventId: String, limit: Int?) async throws -> AggGetEventBootstrapResponse
  func listMarkets(params: AggListMarketsParams) async throws -> AggListMarketsResponse
  func search(params: AggSearchParams) async throws -> AggSearchResponse
  func listCategories(params: AggListCategoriesParams) async throws -> AggListCategoriesResponse
  func getVenueGeoPolicy() async throws -> AggGetVenueGeoPolicyResponse
  func getAppConfig() async throws -> AggGetAppConfigResponse

  // Market data
  func getMidpoints(venueMarketIds: [String], bestPrice: Bool?) async throws -> AggGetMidpointsResponse
  func getOrderbooks(venueMarketIds: [String], depth: Int?) async throws -> AggGetOrderbooksResponse
  func getOutcomeOrderbook(outcomeId: String, depth: Int?) async throws -> AggGetOutcomeOrderbookResponse
  func getChartBars(params: AggChartParams) async throws -> AggGetChartBarsResponse
  func getChartHistoryManifest(params: AggChartParams) async throws -> AggGetChartHistoryManifestResponse

  // Account
  func getUser() async throws -> AggGetUserResponse
  func getDepositAddresses() async throws -> AggGetDepositAddressesResponse
  func getBalances(sync: Bool?, mode: AggMode?) async throws -> AggGetBalancesResponse
  func listPositions(params: AggListPositionsParams) async throws -> AggListPositionsResponse
  func listOrders(params: AggListOrdersParams) async throws -> AggListOrdersResponse
  func listActivity(params: AggListActivityParams) async throws -> AggListActivityResponse

  // Trading
  func createQuote(request: AggQuoteRequest) async throws -> AggCreateQuoteResponse
  func createOrder(request: AggOrderRequest) async throws -> AggCreateOrderResponse
  func getOrder(quoteId: String, mode: AggMode?) async throws -> AggGetOrderResponse
  func createLimitOrder(request: AggLimitOrderRequest) async throws -> AggCreateLimitOrderResponse
  func createDirectOrder(request: AggDirectOrderRequest) async throws -> AggCreateDirectOrderResponse
  func cancelOrder(request: AggCancelOrderRequest) async throws -> AggCancelOrderResponse
  func redeemPositions(request: AggRedeemRequest) async throws -> AggRedeemPositionsResponse

  // Withdrawals
  func quoteWithdrawable(request: AggWithdrawableQuoteRequest) async throws -> AggQuoteWithdrawableResponse
  func previewWithdrawal(request: AggWithdrawalRequest) async throws -> AggPreviewWithdrawalResponse
  func createWithdrawal(request: AggWithdrawalRequest) async throws -> AggWithdrawalResponse
  func getWithdrawal(withdrawalId: String) async throws -> AggWithdrawalResponse
}

public extension PortalAggApiProtocol {
  /// Starts a link on the Portal API's default chain.
  func createLinkChallenge() async throws -> AggCreateLinkChallengeResponse {
    try await createLinkChallenge(request: AggLinkChallengeRequest())
  }

  func listEvents() async throws -> AggListEventsResponse {
    try await listEvents(params: AggListEventsParams())
  }

  func getEvent(eventId: String) async throws -> AggGetEventResponse {
    try await getEvent(eventId: eventId, cluster: nil)
  }

  func getEventBootstrap(eventId: String) async throws -> AggGetEventBootstrapResponse {
    try await getEventBootstrap(eventId: eventId, limit: nil)
  }

  func listMarkets() async throws -> AggListMarketsResponse {
    try await listMarkets(params: AggListMarketsParams())
  }

  func listCategories() async throws -> AggListCategoriesResponse {
    try await listCategories(params: AggListCategoriesParams())
  }

  func getMidpoints(venueMarketIds: [String]) async throws -> AggGetMidpointsResponse {
    try await getMidpoints(venueMarketIds: venueMarketIds, bestPrice: nil)
  }

  func getOrderbooks(venueMarketIds: [String]) async throws -> AggGetOrderbooksResponse {
    try await getOrderbooks(venueMarketIds: venueMarketIds, depth: nil)
  }

  func getOutcomeOrderbook(outcomeId: String) async throws -> AggGetOutcomeOrderbookResponse {
    try await getOutcomeOrderbook(outcomeId: outcomeId, depth: nil)
  }

  func getBalances() async throws -> AggGetBalancesResponse {
    try await getBalances(sync: nil, mode: nil)
  }

  func listPositions() async throws -> AggListPositionsResponse {
    try await listPositions(params: AggListPositionsParams())
  }

  func listOrders() async throws -> AggListOrdersResponse {
    try await listOrders(params: AggListOrdersParams())
  }

  func listActivity() async throws -> AggListActivityResponse {
    try await listActivity(params: AggListActivityParams())
  }

  func getOrder(quoteId: String) async throws -> AggGetOrderResponse {
    try await getOrder(quoteId: quoteId, mode: nil)
  }
}

/// API class for the Agg prediction-markets integration.
///
/// All endpoints sit under `/api/v3/clients/me/integrations/agg`, require the client credential as
/// a bearer token, and return `{ "data": ... }`. A request the SDK refuses before sending it (an
/// empty path id) throws `AggError.emptyIdentifier`. Every failure after the request was sent is
/// thrown as an `AggRequestError`, which carries the transport's error and the `X-Portal-Trace-Id`
/// the request was sent with, where the other Portal API classes throw the transport's error
/// itself: match `PortalRequestsError` on its `underlyingError`. Read the Portal error `id`, Agg's
/// `details` and the trace id with `AggApiError.from(_:)`.
///
/// `503 AGG_SESSION_REFRESH_IN_PROGRESS` is retried after 0.5, 1 and 2 seconds. The Portal API
/// returns it before it calls Agg, or after Agg rejected the session, so the request did nothing and
/// repeating it cannot trade or send twice. Limit orders, cancels, redemptions and withdrawals
/// without a `requestId` still return it to the caller instead of retrying, as in the other Portal
/// SDKs.
public class PortalAggApi: PortalAggApiProtocol {
  static let defaultSessionRefreshRetryDelays: [TimeInterval] = [0.5, 1, 2]

  /// Resolved per request and never cached, so a session rotated or invalidated underneath this
  /// instance is honoured on the next call. Shared by identity with the owning `PortalApi`.
  private let credentials: PortalCredentials
  private let requests: PortalRequestsProtocol
  private let requestBuilder: YieldXyzRequestBuilder
  private let sessionRefreshRetryDelays: [TimeInterval]
  private let logger = PortalLogger.shared

  /// Create an instance of `PortalAggApi`.
  ///
  /// The credential is resolved again on every request and never at construction. The transport's
  /// 401 hook is wired to `credentials` only when the transport reports 401s and has no hook yet,
  /// and the `apiHost` is registered as Portal-owned (`PortalOwnedHosts`) so the hook and the trace
  /// header apply to it.
  /// - Parameters:
  ///   - credentials: The credential presented as the bearer on every request: a `StaticCredentials`
  ///     wrapping a Client API Key, or a session obtained through `PortalAuth`.
  ///   - apiHost: The Portal API hostname.
  ///   - requests: An instance of `PortalRequestsProtocol` used to perform HTTP requests.
  public convenience init(
    credentials: PortalCredentials,
    apiHost: String = "api.portalhq.io",
    requests: PortalRequestsProtocol? = nil
  ) {
    self.init(
      credentials: credentials,
      apiHost: apiHost,
      requests: requests,
      sessionRefreshRetryDelays: Self.defaultSessionRefreshRetryDelays
    )
  }

  init(
    credentials: PortalCredentials,
    apiHost: String,
    requests: PortalRequestsProtocol?,
    sessionRefreshRetryDelays: [TimeInterval]
  ) {
    self.credentials = credentials
    self.requestBuilder = YieldXyzRequestBuilder(
      baseUrl: apiHost.starts(with: "localhost") ? "http://\(apiHost)" : "https://\(apiHost)",
      basePath: "/api/v3/clients/me/integrations/agg",
      emptyIdentifier: { AggError.emptyIdentifier(name: $0) }
    )
    self.requests = requests ?? PortalRequests()
    self.sessionRefreshRetryDelays = sessionRefreshRetryDelays
    PortalOwnedHosts.register(apiHost)

    PortalCredentialSupport.installUnauthorizedHook(on: self.requests, for: credentials, context: "PortalAggApi")
  }

  /*******************************************
   * Link
   *******************************************/

  /// Starts a link: returns the Sign-In with Ethereum challenge to sign. `POST /link/challenge`
  public func createLinkChallenge(request: AggLinkChallengeRequest) async throws -> AggCreateLinkChallengeResponse {
    try await send("createLinkChallenge", .post, path: "/link/challenge", payload: request, retry: true)
  }

  /// Completes a link with the challenge's `personal_sign` signature. `POST /link`
  public func createLink(request: AggLinkRequest) async throws -> AggCreateLinkResponse {
    try await send("createLink", .post, path: "/link", payload: request, retry: true)
  }

  /// Gets the stored link. `GET /link`
  public func getLink() async throws -> AggGetLinkResponse {
    try await send("getLink", .get, path: "/link")
  }

  /// Unlinks the client from Agg. `DELETE /link`
  public func deleteLink() async throws -> AggDeleteLinkResponse {
    try await send("deleteLink", .delete, path: "/link", retry: true)
  }

  /*******************************************
   * Discovery
   *******************************************/

  /// Lists events with their markets and outcomes. `GET /events`
  public func listEvents(params: AggListEventsParams) async throws -> AggListEventsResponse {
    try await send("listEvents", .get, path: "/events", query: [
      ("status", params.status?.rawValue),
      ("search", params.search),
      ("venues", YieldXyzRequestBuilder.joined(params.venues?.map(\.rawValue))),
      ("categoryIds", YieldXyzRequestBuilder.joined(params.categoryIds)),
      ("sortBy", params.sortBy?.rawValue),
      ("sortDir", params.sortDir?.rawValue),
      ("limit", params.limit.map(String.init)),
      ("cursor", params.cursor)
    ])
  }

  /// Gets one event, including its `description`. `GET /events/{eventId}`
  public func getEvent(eventId: String, cluster: Bool?) async throws -> AggGetEventResponse {
    try await send(
      "getEvent",
      .get,
      path: "/events/\(pathSegment("eventId", eventId))",
      query: [("cluster", cluster.map(String.init))]
    )
  }

  /// Gets an event page: the event, its first markets and the outcomes to chart.
  /// `GET /events/{eventId}/bootstrap`
  public func getEventBootstrap(eventId: String, limit: Int?) async throws -> AggGetEventBootstrapResponse {
    try await send(
      "getEventBootstrap",
      .get,
      path: "/events/\(pathSegment("eventId", eventId))/bootstrap",
      query: [("limit", limit.map(String.init))]
    )
  }

  /// Lists markets. `GET /markets`
  public func listMarkets(params: AggListMarketsParams) async throws -> AggListMarketsResponse {
    try await send("listMarkets", .get, path: "/markets", query: [
      ("venueEventId", params.venueEventId),
      ("status", params.status?.rawValue),
      ("venue", params.venue?.rawValue),
      ("search", params.search),
      ("sortBy", params.sortBy?.rawValue),
      ("sortDir", params.sortDir?.rawValue),
      ("projection", params.projection?.rawValue),
      ("limit", params.limit.map(String.init)),
      ("cursor", params.cursor)
    ])
  }

  /// Searches events or markets, ranked by relevance. `GET /search`
  public func search(params: AggSearchParams) async throws -> AggSearchResponse {
    try await send("search", .get, path: "/search", query: [
      ("q", params.q),
      ("type", params.type.rawValue),
      ("status", params.status?.rawValue),
      ("limit", params.limit.map(String.init)),
      ("cursor", params.cursor)
    ])
  }

  /// Lists categories, or a category's children. `GET /categories`
  public func listCategories(params: AggListCategoriesParams) async throws -> AggListCategoriesResponse {
    try await send("listCategories", .get, path: "/categories", query: [
      ("parentId", params.parentId),
      ("limit", params.limit.map(String.init)),
      ("cursor", params.cursor)
    ])
  }

  /// Gets the countries each venue blocks. `GET /venue-geo-policy`
  public func getVenueGeoPolicy() async throws -> AggGetVenueGeoPolicyResponse {
    try await send("getVenueGeoPolicy", .get, path: "/venue-geo-policy")
  }

  /// Gets the app's venue and category switches. `GET /app-config`
  public func getAppConfig() async throws -> AggGetAppConfigResponse {
    try await send("getAppConfig", .get, path: "/app-config")
  }

  /*******************************************
   * Market data
   *******************************************/

  /// Gets live midpoints for a batch of markets. `GET /midpoints`
  public func getMidpoints(venueMarketIds: [String], bestPrice: Bool?) async throws -> AggGetMidpointsResponse {
    try await send("getMidpoints", .get, path: "/midpoints", query: [
      ("venueMarketIds", YieldXyzRequestBuilder.joined(venueMarketIds)),
      ("bestPrice", bestPrice.map(String.init))
    ])
  }

  /// Gets live order books for a batch of markets. `GET /orderbooks`
  public func getOrderbooks(venueMarketIds: [String], depth: Int?) async throws -> AggGetOrderbooksResponse {
    try await send("getOrderbooks", .get, path: "/orderbooks", query: [
      ("venueMarketIds", YieldXyzRequestBuilder.joined(venueMarketIds)),
      ("depth", depth.map(String.init))
    ])
  }

  /// Gets one outcome's ladder and depth. `GET /orderbooks/outcome/{outcomeId}`
  public func getOutcomeOrderbook(outcomeId: String, depth: Int?) async throws -> AggGetOutcomeOrderbookResponse {
    try await send(
      "getOutcomeOrderbook",
      .get,
      path: "/orderbooks/outcome/\(pathSegment("outcomeId", outcomeId))",
      query: [("depth", depth.map(String.init))]
    )
  }

  /// Gets OHLCV bars for an outcome. `GET /charts/bars`
  public func getChartBars(params: AggChartParams) async throws -> AggGetChartBarsResponse {
    try await send("getChartBars", .get, path: "/charts/bars", query: Self.chartQuery(params))
  }

  /// Gets the CDN chunks of an outcome's finalized chart history. `GET /charts/history/manifest`
  public func getChartHistoryManifest(params: AggChartParams) async throws -> AggGetChartHistoryManifestResponse {
    try await send("getChartHistoryManifest", .get, path: "/charts/history/manifest", query: Self.chartQuery(params))
  }

  /*******************************************
   * Account
   *******************************************/

  /// Gets the Agg user profile. `GET /me`
  public func getUser() async throws -> AggGetUserResponse {
    try await send("getUser", .get, path: "/me")
  }

  /// Gets where to send funds; can be `.notReady` while Agg provisions the wallets.
  /// `GET /deposit-addresses`
  public func getDepositAddresses() async throws -> AggGetDepositAddressesResponse {
    try await send("getDepositAddresses", .get, path: "/deposit-addresses")
  }

  /// Gets the managed balance. `GET /balances`
  /// - Parameter sync: Re-read the chains first, e.g. after a deposit. Live mode only.
  public func getBalances(sync: Bool?, mode: AggMode?) async throws -> AggGetBalancesResponse {
    try await send("getBalances", .get, path: "/balances", query: [
      ("sync", sync.map(String.init)),
      ("mode", mode?.rawValue)
    ])
  }

  /// Lists open and resolved positions. `GET /positions`
  public func listPositions(params: AggListPositionsParams) async throws -> AggListPositionsResponse {
    try await send("listPositions", .get, path: "/positions", query: [
      ("status", params.status?.rawValue),
      ("mode", params.mode?.rawValue),
      ("limit", params.limit.map(String.init)),
      ("cursor", params.cursor)
    ])
  }

  /// Lists orders. `GET /orders`
  public func listOrders(params: AggListOrdersParams) async throws -> AggListOrdersResponse {
    try await send("listOrders", .get, path: "/orders", query: [
      ("quoteId", params.quoteId),
      ("orderType", params.orderType?.rawValue),
      ("mode", params.mode?.rawValue),
      ("limit", params.limit.map(String.init)),
      ("cursor", params.cursor)
    ])
  }

  /// Lists trades, transfers and claims, newest first. `GET /activity`
  public func listActivity(params: AggListActivityParams) async throws -> AggListActivityResponse {
    try await send("listActivity", .get, path: "/activity", query: [
      ("type", params.type?.rawValue),
      ("limit", params.limit.map(String.init)),
      ("cursor", params.cursor)
    ])
  }

  /*******************************************
   * Trading
   *******************************************/

  /// Prices an outcome across every venue. `POST /quotes`
  public func createQuote(request: AggQuoteRequest) async throws -> AggCreateQuoteResponse {
    try await send("createQuote", .post, path: "/quotes", payload: request, retry: true)
  }

  /// Fills a quote; poll `getOrder` with its `quoteId` until it is terminal. `POST /orders`
  public func createOrder(request: AggOrderRequest) async throws -> AggCreateOrderResponse {
    try await send("createOrder", .post, path: "/orders", payload: request, retry: true)
  }

  /// Gets a fill's progress. `GET /orders/{quoteId}`
  public func getOrder(quoteId: String, mode: AggMode?) async throws -> AggGetOrderResponse {
    try await send(
      "getOrder",
      .get,
      path: "/orders/\(pathSegment("quoteId", quoteId))",
      query: [("mode", mode?.rawValue)]
    )
  }

  /// Places a resting limit order. `POST /orders/limit`
  public func createLimitOrder(request: AggLimitOrderRequest) async throws -> AggCreateLimitOrderResponse {
    try await send("createLimitOrder", .post, path: "/orders/limit", payload: request, retry: false)
  }

  /// Places a market order on one named venue, without a quote. `POST /orders/direct`
  public func createDirectOrder(request: AggDirectOrderRequest) async throws -> AggCreateDirectOrderResponse {
    try await send("createDirectOrder", .post, path: "/orders/direct", payload: request, retry: true)
  }

  /// Cancels a resting order. `POST /orders/cancel`
  public func cancelOrder(request: AggCancelOrderRequest) async throws -> AggCancelOrderResponse {
    try await send("cancelOrder", .post, path: "/orders/cancel", payload: request, retry: false)
  }

  /// Redeems resolved positions. `POST /redemptions`
  public func redeemPositions(request: AggRedeemRequest) async throws -> AggRedeemPositionsResponse {
    try await send("redeemPositions", .post, path: "/redemptions", payload: request, retry: false)
  }

  /*******************************************
   * Withdrawals
   *******************************************/

  /// Gets how much can leave, to a given chain. `POST /withdrawals/quote`
  public func quoteWithdrawable(request: AggWithdrawableQuoteRequest) async throws -> AggQuoteWithdrawableResponse {
    try await send("quoteWithdrawable", .post, path: "/withdrawals/quote", payload: request, retry: true)
  }

  /// Gets a withdrawal's fees and receive amount; dispatches nothing. `POST /withdrawals/preview`
  public func previewWithdrawal(request: AggWithdrawalRequest) async throws -> AggPreviewWithdrawalResponse {
    try await send("previewWithdrawal", .post, path: "/withdrawals/preview", payload: request, retry: true)
  }

  /// Moves funds out of Agg. Pass a `requestId` to make it safe to retry. `POST /withdrawals`
  public func createWithdrawal(request: AggWithdrawalRequest) async throws -> AggWithdrawalResponse {
    let hasRequestId = !(request.requestId ?? "").isEmpty
    return try await send("createWithdrawal", .post, path: "/withdrawals", payload: request, retry: hasRequestId)
  }

  /// Gets a withdrawal's status. `GET /withdrawals/{withdrawalId}`
  public func getWithdrawal(withdrawalId: String) async throws -> AggWithdrawalResponse {
    try await send("getWithdrawal", .get, path: "/withdrawals/\(pathSegment("withdrawalId", withdrawalId))")
  }

  /*******************************************
   * Private functions
   *******************************************/

  private static func chartQuery(_ params: AggChartParams) -> [(String, String?)] {
    [
      ("venueMarketOutcomeId", params.venueMarketOutcomeId),
      ("to", String(params.to)),
      ("from", params.from.map(String.init)),
      ("resolution", params.resolution?.rawValue),
      ("countBack", params.countBack.map(String.init))
    ]
  }

  /// Encodes an id as a single path segment; an empty id is rejected.
  private func pathSegment(_ name: String, _ value: String) throws -> String {
    try requestBuilder.pathSegment(name, value)
  }

  /// Sends one request, repeating it on `AGG_SESSION_REFRESH_IN_PROGRESS` when `retry` allows (always
  /// for a GET). Each attempt carries its own trace id; a failure is thrown with the trace id of the
  /// attempt that failed.
  private func send<ResponseType: Decodable>(
    _ method: String,
    _ httpMethod: HttpMethod,
    path: @autoclosure () throws -> String,
    query: [(String, String?)] = [],
    payload: Codable? = nil,
    retry: Bool = true
  ) async throws -> ResponseType {
    let url: URL
    do {
      url = try requestBuilder.makeUrl(path: path(), query: query)
    } catch {
      logger.error("PortalAggApi.\(method)() - Error: \(error.localizedDescription)")
      throw error
    }

    var attempt = 0
    while true {
      // Resolved per attempt, so a rotated session is sent on the next one and a dead one fails
      // before anything reaches the wire.
      let token = try PortalCredentialSupport.resolveToken(self.credentials)
      let traceId = generateTraceId()
      let request = PortalAPIRequest(url: url, method: httpMethod, payload: payload, bearerToken: token, traceId: traceId)
      do {
        return try await requests.execute(request: request, mappingInResponse: ResponseType.self)
      } catch {
        if YieldXyzCancellation.isCancellation(error) {
          throw error
        }
        if retry, attempt < sessionRefreshRetryDelays.count, AggApiError.from(error)?.isSessionRefreshInProgress == true {
          try await YieldXyzExecutionClock.sleep(seconds: sessionRefreshRetryDelays[attempt])
          attempt += 1
          continue
        }
        logger.error("PortalAggApi.\(method)() - Error (trace id \(traceId)): \(error.localizedDescription)")
        throw AggRequestError(traceId: traceId, underlyingError: error)
      }
    }
  }
}
