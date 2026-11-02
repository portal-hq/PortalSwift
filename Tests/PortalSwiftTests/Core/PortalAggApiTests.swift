//
//  PortalAggApiTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

@testable import PortalSwift
import XCTest

final class PortalAggApiTests: XCTestCase {
  private let encoder = JSONEncoder()
  private let host = "https://\(MockConstants.mockHost)"
  private lazy var base = "\(host)/api/v3/clients/me/integrations/agg"

  private var spy: PortalRequestsSpy!
  private var api: PortalAggApi!

  override func setUpWithError() throws {
    spy = PortalRequestsSpy()
    api = makeApi(retryDelays: [0, 0, 0])
  }

  override func tearDownWithError() throws {
    spy = nil
    api = nil
  }

  // MARK: - Helpers

  private func makeApi(retryDelays: [TimeInterval]) -> PortalAggApi {
    PortalAggApi(
      credentials: StaticCredentials(MockConstants.mockApiKey),
      apiHost: MockConstants.mockHost,
      requests: spy,
      sessionRefreshRetryDelays: retryDelays
    )
  }

  /// Answers with `{ "data": <json> }`.
  private func respond(data json: String) {
    spy.returnData = Data(#"{"data":\#(json)}"#.utf8)
  }

  private var lastUrl: String? {
    spy.executeRequestParam?.url.absoluteString
  }

  private func lastBody() throws -> NSDictionary {
    let payload = try XCTUnwrap(spy.executeRequestParam?.payload)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(payload)) as? NSDictionary)
  }

  private func traceId(of request: PortalBaseRequestProtocol) -> String? {
    request.headers[PORTAL_TRACE_ID_HEADER]
  }

  private static func httpError(_ status: Int, _ body: String) -> PortalRequestsError {
    status >= 500
      ? .internalServerError("\(status) - \(body)", url: "https://\(MockConstants.mockHost)")
      : .clientError("\(status) - \(body)", url: "https://\(MockConstants.mockHost)")
  }

  private static let sessionRefresh = httpError(
    503,
    #"{"error":"Agg session refresh in progress; retry shortly.","id":"AGG_SESSION_REFRESH_IN_PROGRESS"}"#
  )

  private static let linkChallenge = #"{"message":"m","signParams":["0x6d","0xabc"],"expiresAt":"2026-10-29T13:30:36.281Z"}"#
  private static let link = #"{"linked":true,"aggUserId":"u1","linkedAddress":"0xabc","linkedChainId":"eip155:137","externalIdLinked":true}"#
  private static let directOrder = #"{"orderId":"d1","externalId":"x1","venue":"polymarket","status":"pending","quoteId":"q1"}"#

  // MARK: - Routes

  private struct Route {
    let name: String
    let method: HttpMethod
    let url: String
    let response: String
    let call: (PortalAggApi) async throws -> Void
  }

  private lazy var routes: [Route] = {
    let withdrawal = AggWithdrawalRequest(tokenSymbol: .usdc, destinationChainId: "eip155:8453", amountRaw: "1500000", requestId: "r1")
    let chart = AggChartParams(venueMarketOutcomeId: "o1", to: 1000)
    return [
      Route(name: "createLinkChallenge", method: .post, url: "/link/challenge", response: Self.linkChallenge) { _ = try await $0.createLinkChallenge() },
      Route(name: "createLink", method: .post, url: "/link", response: Self.link) { _ = try await $0.createLink(request: AggLinkRequest(signature: "0xsig")) },
      Route(name: "getLink", method: .get, url: "/link", response: #"{"linked":false}"#) { _ = try await $0.getLink() },
      Route(name: "deleteLink", method: .delete, url: "/link", response: #"{"linked":false}"#) { _ = try await $0.deleteLink() },
      Route(name: "listEvents", method: .get, url: "/events", response: AggFixtures.venueEvents) { _ = try await $0.listEvents() },
      Route(name: "getEvent", method: .get, url: "/events/e1", response: AggFixtures.venueEventDetail) { _ = try await $0.getEvent(eventId: "e1") },
      Route(name: "getEventBootstrap", method: .get, url: "/events/e1/bootstrap", response: AggFixtures.venueEventBootstrap) {
        _ = try await $0.getEventBootstrap(eventId: "e1")
      },
      Route(name: "listMarkets", method: .get, url: "/markets", response: AggFixtures.venueMarkets) { _ = try await $0.listMarkets() },
      Route(name: "search", method: .get, url: "/search?q=vance&type=events", response: AggFixtures.searchEvents) {
        _ = try await $0.search(params: AggSearchParams(q: "vance", type: .events))
      },
      Route(name: "listCategories", method: .get, url: "/categories", response: AggFixtures.categories) { _ = try await $0.listCategories() },
      Route(name: "getVenueGeoPolicy", method: .get, url: "/venue-geo-policy", response: AggFixtures.venueGeoPolicy) { _ = try await $0.getVenueGeoPolicy() },
      Route(name: "getAppConfig", method: .get, url: "/app-config", response: AggFixtures.appConfig) { _ = try await $0.getAppConfig() },
      Route(name: "getMidpoints", method: .get, url: "/midpoints?venueMarketIds=m1%2Cm2", response: AggFixtures.midpoints) {
        _ = try await $0.getMidpoints(venueMarketIds: ["m1", "m2"])
      },
      Route(name: "getOrderbooks", method: .get, url: "/orderbooks?venueMarketIds=m1", response: AggFixtures.orderbooks) {
        _ = try await $0.getOrderbooks(venueMarketIds: ["m1"])
      },
      Route(name: "getOutcomeOrderbook", method: .get, url: "/orderbooks/outcome/o1", response: AggFixtures.orderbookOutcome) {
        _ = try await $0.getOutcomeOrderbook(outcomeId: "o1")
      },
      Route(name: "getChartBars", method: .get, url: "/charts/bars?venueMarketOutcomeId=o1&to=1000", response: AggFixtures.chartBars) {
        _ = try await $0.getChartBars(params: chart)
      },
      Route(name: "getChartHistoryManifest", method: .get, url: "/charts/history/manifest?venueMarketOutcomeId=o1&to=1000", response: AggFixtures.chartHistoryManifest) {
        _ = try await $0.getChartHistoryManifest(params: chart)
      },
      Route(name: "getUser", method: .get, url: "/me", response: AggFixtures.usersMe) { _ = try await $0.getUser() },
      Route(name: "getDepositAddresses", method: .get, url: "/deposit-addresses", response: AggFixtures.depositAddresses) { _ = try await $0.getDepositAddresses() },
      Route(name: "getBalances", method: .get, url: "/balances", response: AggFixtures.balances) { _ = try await $0.getBalances() },
      Route(name: "listPositions", method: .get, url: "/positions", response: AggFixtures.positionsResolved) { _ = try await $0.listPositions() },
      Route(name: "listOrders", method: .get, url: "/orders", response: AggFixtures.orders) { _ = try await $0.listOrders() },
      Route(name: "listActivity", method: .get, url: "/activity", response: AggFixtures.activity) { _ = try await $0.listActivity() },
      Route(name: "createQuote", method: .post, url: "/quotes", response: AggFixtures.quotePaper) {
        _ = try await $0.createQuote(request: AggQuoteRequest(outcomeId: "o1", side: .buy, amount: "1"))
      },
      Route(name: "createOrder", method: .post, url: "/orders", response: AggFixtures.fill) { _ = try await $0.createOrder(request: AggOrderRequest(quoteId: "q1")) },
      Route(name: "getOrder", method: .get, url: "/orders/q1", response: AggFixtures.executionStatus) { _ = try await $0.getOrder(quoteId: "q1") },
      Route(name: "createLimitOrder", method: .post, url: "/orders/limit", response: AggFixtures.limitOrderPlaced) {
        _ = try await $0.createLimitOrder(request: AggLimitOrderRequest(
          venue: .polymarket, venueMarketOutcomeId: "o1", side: .buy, limitPriceRaw: "200000", sizeRaw: "5000000", timeInForce: .gtc
        ))
      },
      Route(name: "createDirectOrder", method: .post, url: "/orders/direct", response: Self.directOrder) {
        _ = try await $0.createDirectOrder(request: AggDirectOrderRequest(venue: .polymarket, venueMarketOutcomeId: "o1", side: .buy, externalId: "x1", maxSpend: 1))
      },
      Route(name: "cancelOrder", method: .post, url: "/orders/cancel", response: AggFixtures.cancel) {
        _ = try await $0.cancelOrder(request: AggCancelOrderRequest(orderId: "or1"))
      },
      Route(name: "redeemPositions", method: .post, url: "/redemptions", response: AggFixtures.redeem) {
        _ = try await $0.redeemPositions(request: AggRedeemRequest(venueMarketOutcomeIds: ["v1"]))
      },
      Route(name: "quoteWithdrawable", method: .post, url: "/withdrawals/quote", response: AggFixtures.withdrawableQuote) {
        _ = try await $0.quoteWithdrawable(request: AggWithdrawableQuoteRequest(tokenSymbol: .usdc, destinationChainId: "eip155:8453"))
      },
      Route(name: "previewWithdrawal", method: .post, url: "/withdrawals/preview", response: AggFixtures.withdrawalPreview) {
        _ = try await $0.previewWithdrawal(request: withdrawal)
      },
      Route(name: "createWithdrawal", method: .post, url: "/withdrawals", response: AggFixtures.withdrawalSubmit) { _ = try await $0.createWithdrawal(request: withdrawal) },
      Route(name: "getWithdrawal", method: .get, url: "/withdrawals/w1", response: AggFixtures.withdrawalStatus) { _ = try await $0.getWithdrawal(withdrawalId: "w1") }
    ]
  }()

  func test_everyRoute_sendsItsMethodToItsPathWithTheBearerAndATraceId() async throws {
    XCTAssertEqual(routes.count, 34)
    for route in routes {
      spy = PortalRequestsSpy()
      api = makeApi(retryDelays: [])
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
      XCTAssertFalse(traceId(of: request)?.isEmpty ?? true, route.name)
      if route.method == .post {
        XCTAssertNotNil(request.payload, route.name)
      } else {
        XCTAssertNil(request.payload, route.name)
      }
    }
  }

  // MARK: - Query and path encoding

  func test_listEvents_sendsEveryFilterInOrder() async throws {
    respond(data: AggFixtures.venueEvents)

    _ = try await api.listEvents(params: AggListEventsParams(
      status: .open,
      search: "J.D. Vance",
      venues: [.polymarket, .kalshi],
      categoryIds: ["c1"],
      sortBy: .volume24hr,
      sortDir: .desc,
      limit: 10,
      cursor: "next"
    ))

    XCTAssertEqual(
      lastUrl,
      "\(base)/events?status=open&search=J.D.%20Vance&venues=polymarket%2Ckalshi&categoryIds=c1&sortBy=volume24hr&sortDir=desc&limit=10&cursor=next"
    )
  }

  func test_everyFilter_isSentInOrderAsTheApiSpellsIt() async throws {
    let cases: [(url: String, response: String, call: (PortalAggApi) async throws -> Void)] = [
      ("/events/e1?cluster=true", AggFixtures.venueEventDetail, { _ = try await $0.getEvent(eventId: "e1", cluster: true) }),
      ("/events/e1/bootstrap?limit=5", AggFixtures.venueEventBootstrap, { _ = try await $0.getEventBootstrap(eventId: "e1", limit: 5) }),
      (
        "/markets?venueEventId=ev1&status=resolved&venue=kalshi&search=fed%20rates&sortBy=updatedAt&sortDir=asc&projection=summary&limit=20&cursor=c1",
        AggFixtures.venueMarkets,
        { _ = try await $0.listMarkets(params: AggListMarketsParams(
          venueEventId: "ev1", status: .resolved, venue: .kalshi, search: "fed rates", sortBy: .updatedAt, sortDir: .asc, projection: .summary, limit: 20, cursor: "c1"
        )) }
      ),
      (
        "/search?q=J.D.%20Vance&type=markets&status=open&limit=3&cursor=c2",
        AggFixtures.searchMarkets,
        { _ = try await $0.search(params: AggSearchParams(q: "J.D. Vance", type: .markets, status: .open, limit: 3, cursor: "c2")) }
      ),
      ("/categories?parentId=p1&limit=2&cursor=c3", AggFixtures.categories, { _ = try await $0.listCategories(params: AggListCategoriesParams(parentId: "p1", limit: 2, cursor: "c3")) }),
      ("/midpoints?venueMarketIds=m1&bestPrice=true", AggFixtures.midpoints, { _ = try await $0.getMidpoints(venueMarketIds: ["m1"], bestPrice: true) }),
      ("/orderbooks?venueMarketIds=m1%2Cm2&depth=10", AggFixtures.orderbooks, { _ = try await $0.getOrderbooks(venueMarketIds: ["m1", "m2"], depth: 10) }),
      ("/orderbooks/outcome/o%2F1?depth=5", AggFixtures.orderbookOutcome, { _ = try await $0.getOutcomeOrderbook(outcomeId: "o/1", depth: 5) }),
      (
        "/charts/bars?venueMarketOutcomeId=o1&to=2000&from=1000&resolution=60&countBack=5",
        AggFixtures.chartBars,
        { _ = try await $0.getChartBars(params: AggChartParams(venueMarketOutcomeId: "o1", to: 2000, from: 1000, resolution: .oneHour, countBack: 5)) }
      ),
      (
        "/charts/history/manifest?venueMarketOutcomeId=o1&to=2000&resolution=1D",
        AggFixtures.chartHistoryManifest,
        { _ = try await $0.getChartHistoryManifest(params: AggChartParams(venueMarketOutcomeId: "o1", to: 2000, resolution: .oneDay)) }
      ),
      (
        "/positions?status=closed&mode=paper&limit=10&cursor=c4",
        AggFixtures.positionsPaper,
        { _ = try await $0.listPositions(params: AggListPositionsParams(status: .closed, mode: .paper, limit: 10, cursor: "c4")) }
      ),
      (
        "/orders?quoteId=q1&orderType=limit&mode=live&limit=50&cursor=c5",
        AggFixtures.orders,
        { _ = try await $0.listOrders(params: AggListOrdersParams(quoteId: "q1", orderType: .limit, mode: .live, limit: 50, cursor: "c5")) }
      ),
      ("/activity?type=user_op&limit=25&cursor=c6", AggFixtures.activity, { _ = try await $0.listActivity(params: AggListActivityParams(type: .userOp, limit: 25, cursor: "c6")) })
    ]
    for testCase in cases {
      spy = PortalRequestsSpy()
      api = makeApi(retryDelays: [])
      respond(data: testCase.response)

      try await testCase.call(api)

      XCTAssertEqual(lastUrl, base + testCase.url)
    }
  }

  func test_emptyFilterValues_areLeftOut() async throws {
    respond(data: AggFixtures.venueEvents)

    _ = try await api.listEvents(params: AggListEventsParams(search: "", venues: ["", .polymarket], categoryIds: [], cursor: ""))

    XCTAssertEqual(lastUrl, "\(base)/events?venues=polymarket")
  }

  func test_aLocalhostHost_isCalledOverHttp() async throws {
    let api = PortalAggApi(credentials: StaticCredentials(MockConstants.mockApiKey), apiHost: "localhost:3000", requests: spy)
    respond(data: #"{"linked":false}"#)

    _ = try await api.getLink()

    XCTAssertEqual(lastUrl, "http://localhost:3000/api/v3/clients/me/integrations/agg/link")
  }

  func test_getBalances_sendsSyncAndMode() async throws {
    respond(data: AggFixtures.balances)

    _ = try await api.getBalances(sync: true, mode: .paper)

    XCTAssertEqual(lastUrl, "\(base)/balances?sync=true&mode=paper")
  }

  func test_getOrder_encodesTheQuoteIdAsOnePathSegment() async throws {
    respond(data: AggFixtures.executionStatus)

    _ = try await api.getOrder(quoteId: "a/b?c", mode: .paper)

    XCTAssertEqual(lastUrl, "\(base)/orders/a%2Fb%3Fc?mode=paper")
  }

  func test_anEmptyPathId_isRefusedBeforeAnythingIsSent() async {
    do {
      _ = try await api.getWithdrawal(withdrawalId: "")
      XCTFail("Expected emptyIdentifier")
    } catch AggError.emptyIdentifier(let name) {
      XCTAssertEqual(name, "withdrawalId")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
    XCTAssertEqual(spy.executeCallsCount, 0)
  }

  func test_createQuote_sendsTheRequestAsItsBody() async throws {
    respond(data: AggFixtures.quotePaper)

    _ = try await api.createQuote(request: AggQuoteRequest(outcomeId: "o1", side: .buy, amount: "1", slippageBps: 100, mode: .paper))

    XCTAssertEqual(try lastBody(), ["outcomeId": "o1", "side": "buy", "amount": "1", "slippageBps": 100, "mode": "paper"])
  }

  // MARK: - Failures

  func test_aFailure_carriesTheTraceIdTheRequestWasSentWith() async throws {
    spy.executeThrowableErrorSequence = [
      Self.httpError(409, #"{"error":"This client is not linked to Agg. Complete the Agg link flow and retry.","id":"AGG_LINK_REQUIRED"}"#)
    ]

    do {
      _ = try await api.getBalances()
      XCTFail("Expected a failure")
    } catch {
      let requestError = try XCTUnwrap(error as? AggRequestError)
      XCTAssertEqual(requestError.traceId, spy.executeRequestParam.flatMap(traceId(of:)))

      let apiError = try XCTUnwrap(AggApiError.from(error))
      XCTAssertEqual(apiError.status, 409)
      XCTAssertTrue(apiError.isLinkRequired)
      XCTAssertEqual(apiError.traceId, requestError.traceId)
    }
  }

  func test_aggDecline_exposesItsCodeAndFieldsAsTypedDetails() async throws {
    spy.executeThrowableErrorSequence = [
      Self.httpError(422, #"{"error":"Agg rejected the request: invalid amount","details":{"code":"VALIDATION","fields":["amount",7]}}"#)
    ]

    do {
      _ = try await api.createQuote(request: AggQuoteRequest(outcomeId: "o1", side: .buy, amount: "0"))
      XCTFail("Expected a failure")
    } catch {
      let apiError = try XCTUnwrap(AggApiError.from(error))
      XCTAssertEqual(apiError.status, 422)
      XCTAssertNil(apiError.id)
      XCTAssertEqual(apiError.message, "Agg rejected the request: invalid amount")
      XCTAssertEqual(apiError.details, AggErrorDetails(code: "VALIDATION", fields: ["amount"]))
    }
  }

  func test_aCancelledRequest_isThrownAsACancellationNotWrapped() async {
    spy.executeThrowableErrorSequence = [CancellationError()]

    do {
      _ = try await api.getLink()
      XCTFail("Expected a cancellation")
    } catch {
      XCTAssertTrue(error is CancellationError, "\(error)")
    }
  }

  // MARK: - Session refresh retry

  func test_sessionRefresh_isRetriedWithANewTraceIdEachAttempt() async throws {
    spy.executeThrowableErrorSequence = [Self.sessionRefresh, Self.sessionRefresh]
    respond(data: AggFixtures.balances)

    _ = try await api.getBalances()

    XCTAssertEqual(spy.executeCallsCount, 3)
    let traceIds = spy.executeRequestHistory.compactMap(traceId(of:))
    XCTAssertEqual(Set(traceIds).count, 3)
  }

  func test_sessionRefresh_isReturnedOnceTheRetriesRunOut() async throws {
    spy.executeThrowableErrorSequence = [Self.sessionRefresh, Self.sessionRefresh, Self.sessionRefresh, Self.sessionRefresh]
    respond(data: AggFixtures.balances)

    do {
      _ = try await api.getBalances()
      XCTFail("Expected a failure")
    } catch {
      XCTAssertEqual(AggApiError.from(error)?.isSessionRefreshInProgress, true)
    }
    XCTAssertEqual(spy.executeCallsCount, 4)
  }

  func test_sessionRefresh_isNotRetriedOnALimitOrderCancelOrRedemption() async throws {
    let calls: [(PortalAggApi) async throws -> Void] = [
      { _ = try await $0.createLimitOrder(request: AggLimitOrderRequest(
        venue: .polymarket, venueMarketOutcomeId: "o1", side: .buy, limitPriceRaw: "1", sizeRaw: "1", timeInForce: .gtc
      )) },
      { _ = try await $0.cancelOrder(request: AggCancelOrderRequest(orderId: "or1")) },
      { _ = try await $0.redeemPositions(request: AggRedeemRequest(venueMarketOutcomeIds: ["v1"])) },
      { _ = try await $0.createWithdrawal(request: AggWithdrawalRequest(tokenSymbol: .usdc, destinationChainId: "eip155:8453", amountRaw: "1")) }
    ]
    for call in calls {
      spy = PortalRequestsSpy()
      api = makeApi(retryDelays: [0, 0, 0])
      spy.executeThrowableErrorSequence = [Self.sessionRefresh]

      do {
        try await call(api)
        XCTFail("Expected a failure")
      } catch {
        XCTAssertEqual(AggApiError.from(error)?.isSessionRefreshInProgress, true)
      }
      XCTAssertEqual(spy.executeCallsCount, 1)
    }
  }

  func test_sessionRefresh_isRetriedOnAWithdrawalWithARequestId() async throws {
    spy.executeThrowableErrorSequence = [Self.sessionRefresh]
    respond(data: AggFixtures.withdrawalSubmit)

    _ = try await api.createWithdrawal(request: AggWithdrawalRequest(
      tokenSymbol: .usdc, destinationChainId: "eip155:8453", amountRaw: "1500000", requestId: "r1"
    ))

    XCTAssertEqual(spy.executeCallsCount, 2)
  }

  func test_otherFailures_areNotRetried() async {
    spy.executeThrowableErrorSequence = [Self.httpError(503, #"{"error":"Agg is unavailable"}"#)]

    do {
      _ = try await api.getBalances()
      XCTFail("Expected a failure")
    } catch {
      XCTAssertEqual(AggApiError.from(error)?.status, 503)
    }
    XCTAssertEqual(spy.executeCallsCount, 1)
  }
}
