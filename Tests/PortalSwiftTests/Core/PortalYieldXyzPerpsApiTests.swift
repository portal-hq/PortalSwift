//
//  PortalYieldXyzPerpsApiTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import AnyCodable
@testable import PortalSwift
import XCTest

final class PortalYieldXyzPerpsApiTests: XCTestCase {
  private let encoder = JSONEncoder()
  private let base = "https://\(MockConstants.mockHost)/api/v3/clients/me/integrations/yield-xyz-perps"
  private let wallet = YieldXyzPerpsFixtures.wallet

  private var spy: PortalRequestsSpy!
  private var api: PortalYieldXyzPerpsApi!

  override func setUpWithError() throws {
    spy = PortalRequestsSpy()
    api = PortalYieldXyzPerpsApi(
      credentials: StaticCredentials(MockConstants.mockApiKey),
      apiHost: MockConstants.mockHost,
      requests: spy
    )
  }

  override func tearDownWithError() throws {
    spy = nil
    api = nil
  }

  // MARK: - Helpers

  private func respond<T: Encodable>(with response: T) throws {
    spy.returnData = try encoder.encode(response)
  }

  private var lastUrl: String? {
    spy.executeRequestParam?.url.absoluteString
  }

  /// The JSON object the last request sent as its body.
  private func lastBody() throws -> NSDictionary {
    let payload = try XCTUnwrap(spy.executeRequestParam?.payload)
    let data = try encoder.encode(payload)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? NSDictionary)
  }

  // MARK: - Providers

  func test_getProviders_sendsGetToProvidersWithBearer() async throws {
    try respond(with: YieldXyzPerpsGetProvidersResponse(data: [.stub()]))

    let response = try await api.getProviders()

    XCTAssertEqual(response.data, [.stub()])
    XCTAssertEqual(spy.executeCallsCount, 1)
    XCTAssertEqual(spy.executeRequestParam?.method, .get)
    XCTAssertEqual(lastUrl, "\(base)/providers")
    XCTAssertEqual(spy.executeRequestParam?.headers["Authorization"], "Bearer \(MockConstants.mockApiKey)")
    XCTAssertNil(spy.executeRequestParam?.payload)
  }

  func test_getProvider_encodesProviderIdAsOnePathSegment() async throws {
    try respond(with: YieldXyzPerpsGetProviderResponse(data: .stub()))

    _ = try await api.getProvider(providerId: "a/b c")

    XCTAssertEqual(lastUrl, "\(base)/providers/a%2Fb%20c")
  }

  // MARK: - Markets

  func test_getMarkets_sendsTheFiltersInAllowListOrder() async throws {
    try respond(with: YieldXyzPerpsGetMarketsResponse(data: YieldXyzPerpsPage(total: 1, offset: 20, limit: 10, items: [.stub()])))

    let response = try await api.getMarkets(params: YieldXyzPerpsGetMarketsParams(
      offset: 20,
      limit: 10,
      providerId: "hyperliquid",
      sortBy: .volume24h,
      order: .desc
    ))

    XCTAssertEqual(response.data.items.first?.id, "hyperliquid-eth-usdc")
    XCTAssertEqual(lastUrl, "\(base)/markets?offset=20&limit=10&providerId=hyperliquid&sortBy=volume24h&order=desc")
  }

  func test_getMarkets_withoutFilters_sendsNoQuery() async throws {
    try respond(with: YieldXyzPerpsGetMarketsResponse(data: YieldXyzPerpsPage(total: 0, offset: 0, limit: 25, items: [])))

    _ = try await api.getMarkets()

    XCTAssertEqual(lastUrl, "\(base)/markets")
  }

  func test_getMarket_encodesMarketId() async throws {
    try respond(with: YieldXyzPerpsGetMarketResponse(data: .stub()))

    _ = try await api.getMarket(marketId: "a/b c")

    XCTAssertEqual(lastUrl, "\(base)/markets/a%2Fb%20c")
  }

  func test_getMarketCandles_sendsTheWindow() async throws {
    try respond(with: YieldXyzPerpsGetMarketCandlesResponse(data: .stub()))

    let response = try await api.getMarketCandles(
      marketId: "hyperliquid-eth-usdc",
      params: YieldXyzPerpsGetMarketCandlesParams(interval: .oneHour, from: 1_756_166_400_000, to: 1_756_252_800_000)
    )

    XCTAssertEqual(response.data.candles.first?.trades, 482)
    XCTAssertEqual(lastUrl, "\(base)/markets/hyperliquid-eth-usdc/candles?interval=1h&from=1756166400000&to=1756252800000")
  }

  func test_getMarketCandles_withoutTo_omitsIt() async throws {
    try respond(with: YieldXyzPerpsGetMarketCandlesResponse(data: .stub()))

    _ = try await api.getMarketCandles(marketId: "m", params: YieldXyzPerpsGetMarketCandlesParams(interval: "2h", from: 0))

    XCTAssertEqual(lastUrl, "\(base)/markets/m/candles?interval=2h&from=0")
  }

  // MARK: - Account

  func test_getPositions_postsTheAccountAndVenueOnly() async throws {
    try respond(with: YieldXyzPerpsGetPositionsResponse(data: [.stub()]))

    let response = try await api.getPositions(request: YieldXyzPerpsPortfolioRequest(address: wallet, providerId: "hyperliquid"))

    XCTAssertEqual(response.data, [.stub()])
    XCTAssertEqual(spy.executeRequestParam?.method, .post)
    XCTAssertEqual(lastUrl, "\(base)/positions")
    XCTAssertEqual(try lastBody(), ["address": wallet, "providerId": "hyperliquid"])
  }

  func test_getOrders_postsProviderIds() async throws {
    try respond(with: YieldXyzPerpsGetOrdersResponse(data: [.stub()]))

    _ = try await api.getOrders(request: YieldXyzPerpsPortfolioRequest(address: wallet, providerIds: ["hyperliquid", "other"]))

    XCTAssertEqual(lastUrl, "\(base)/orders")
    XCTAssertEqual(try lastBody(), ["address": wallet, "providerIds": ["hyperliquid", "other"]])
  }

  func test_getBalances_postsToBalances() async throws {
    try respond(with: YieldXyzPerpsGetBalancesResponse(data: .stub()))

    let response = try await api.getBalances(request: YieldXyzPerpsPortfolioRequest(address: wallet, providerId: "hyperliquid"))

    XCTAssertEqual(response.data.availableBalance, 960.31)
    XCTAssertEqual(lastUrl, "\(base)/balances")
    XCTAssertEqual(try lastBody(), ["address": wallet, "providerId": "hyperliquid"])
  }

  // MARK: - Actions

  func test_createAction_postsArgsVerbatim() async throws {
    try respond(with: YieldXyzPerpsCreateActionResponse(data: .stub()))
    let args = YieldXyzPerpsActionArgs(
      amount: "100",
      fromToken: YieldXyzPerpsTokenIdentifier(network: "eip155:42161", address: YieldXyzPerpsFixtures.arbitrumUsdc),
      fundingMethod: .bridge2,
      additionalFields: ["venueSpecific": AnyCodable(true)]
    )

    _ = try await api.createAction(request: YieldXyzPerpsCreateActionRequest(providerId: "hyperliquid", address: wallet, action: .fund, args: args))

    XCTAssertEqual(lastUrl, "\(base)/actions")
    XCTAssertEqual(try lastBody(), [
      "providerId": "hyperliquid",
      "address": wallet,
      "action": "fund",
      "args": [
        "amount": "100",
        "fromToken": ["network": "eip155:42161", "address": YieldXyzPerpsFixtures.arbitrumUsdc],
        "fundingMethod": "bridge2",
        "venueSpecific": true
      ]
    ])
  }

  func test_getActions_sendsTheAllowListedFilters() async throws {
    try respond(with: YieldXyzPerpsGetActionsResponse(data: YieldXyzPerpsPage(total: 1, offset: 0, limit: 25, items: [.stub()])))

    _ = try await api.getActions(request: YieldXyzPerpsGetActionsRequest(address: wallet, params: YieldXyzPerpsGetActionsParams(
      limit: 25,
      providerId: "hyperliquid",
      marketId: "hyperliquid-eth-usdc",
      type: .open,
      statuses: [.created, .processing]
    )))

    XCTAssertEqual(
      lastUrl,
      "\(base)/actions?limit=25&address=\(wallet)&providerId=hyperliquid&marketId=hyperliquid-eth-usdc&type=open&statuses=CREATED%2CPROCESSING"
    )
  }

  func test_getActions_usesTheResolvedAddress_notTheParams() async throws {
    try respond(with: YieldXyzPerpsGetActionsResponse(data: YieldXyzPerpsPage(total: 0, offset: 0, limit: 25, items: [])))

    _ = try await api.getActions(request: YieldXyzPerpsGetActionsRequest(address: wallet, params: YieldXyzPerpsGetActionsParams(address: "0xignored", status: .success, statuses: [])))

    XCTAssertEqual(lastUrl, "\(base)/actions?address=\(wallet)&status=SUCCESS")
  }

  func test_getActions_joinsProviderIds() async throws {
    try respond(with: YieldXyzPerpsGetActionsResponse(data: YieldXyzPerpsPage(total: 0, offset: 0, limit: 25, items: [])))

    _ = try await api.getActions(request: YieldXyzPerpsGetActionsRequest(address: wallet, params: YieldXyzPerpsGetActionsParams(
      providerIds: ["hyperliquid", "", "other-venue"]
    )))

    XCTAssertEqual(lastUrl, "\(base)/actions?address=\(wallet)&providerIds=hyperliquid%2Cother-venue")
  }

  func test_getAction_encodesActionId() async throws {
    try respond(with: YieldXyzPerpsGetActionResponse(data: .stub()))

    let response = try await api.getAction(actionId: "act 1")

    XCTAssertEqual(response.data.id, "act-1")
    XCTAssertEqual(lastUrl, "\(base)/actions/act%201")
  }

  func test_submitTransaction_withSignature_postsSignatureAndActionIdOnly() async throws {
    try respond(with: YieldXyzPerpsSubmitTransactionResponse(data: .stub()))

    _ = try await api.submitTransaction(params: YieldXyzPerpsSubmitTransactionParams(
      transactionId: "tx-order-1",
      actionId: "act-1",
      signedPayload: YieldXyzPerpsFixtures.signature
    ))

    XCTAssertEqual(spy.executeRequestParam?.method, .post)
    XCTAssertEqual(lastUrl, "\(base)/transactions/tx-order-1/submit")
    XCTAssertEqual(try lastBody(), ["signedPayload": YieldXyzPerpsFixtures.signature, "actionId": "act-1"])
  }

  func test_submitTransaction_withHash_postsTheHashOnly() async throws {
    try respond(with: YieldXyzPerpsSubmitTransactionResponse(data: .stub()))

    _ = try await api.submitTransaction(params: YieldXyzPerpsSubmitTransactionParams(
      transactionId: "tx/fund",
      transactionHash: YieldXyzPerpsFixtures.fundingTxHash
    ))

    XCTAssertEqual(lastUrl, "\(base)/transactions/tx%2Ffund/submit")
    XCTAssertEqual(try lastBody(), ["transactionHash": YieldXyzPerpsFixtures.fundingTxHash])
  }

  // MARK: - History

  func test_getActivity_commaJoinsListFilters() async throws {
    try respond(with: YieldXyzPerpsGetActivityResponse(data: YieldXyzPerpsPage(total: 0, offset: 0, limit: 25, items: [])))

    _ = try await api.getActivity(request: YieldXyzPerpsGetActivityRequest(address: wallet, params: YieldXyzPerpsGetActivityParams(
      offset: 0,
      providerIds: ["hyperliquid", "other-venue"],
      actionStatuses: [.success, .failed]
    )))

    XCTAssertEqual(
      lastUrl,
      "\(base)/activity?offset=0&address=\(wallet)&providerIds=hyperliquid%2Cother-venue&actionStatuses=SUCCESS%2CFAILED"
    )
  }

  func test_getEvents_sendsEveryFilterEncoded() async throws {
    try respond(with: YieldXyzPerpsGetEventsResponse(data: YieldXyzPerpsPage(total: 1, offset: 0, limit: 100, items: [.stub()])))

    _ = try await api.getEvents(request: YieldXyzPerpsGetEventsRequest(address: wallet, params: YieldXyzPerpsGetEventsParams(
      providerId: "hyperliquid",
      eventTypes: [.orderFilled, .liquidation],
      marketId: "hyperliquid-eth-usdc",
      perpActionId: "act-1",
      providerOrderId: "394438950581",
      fromDate: "2026-09-01T00:00:00.000Z",
      toDate: "2026-09-02T00:00:00.000Z"
    )))

    XCTAssertEqual(
      lastUrl,
      "\(base)/events?address=\(wallet)&providerId=hyperliquid&eventTypes=order_filled%2Cliquidation&marketId=hyperliquid-eth-usdc&perpActionId=act-1&providerOrderId=394438950581&fromDate=2026-09-01T00%3A00%3A00.000Z&toDate=2026-09-02T00%3A00%3A00.000Z"
    )
  }

  func test_getEvents_encodesPlusSoItIsNotReadAsASpace() async throws {
    try respond(with: YieldXyzPerpsGetEventsResponse(data: YieldXyzPerpsPage(total: 0, offset: 0, limit: 100, items: [])))

    _ = try await api.getEvents(request: YieldXyzPerpsGetEventsRequest(address: wallet, params: YieldXyzPerpsGetEventsParams(
      eventType: .stopLossTriggered,
      fromDate: "2026-09-01T05:00:00+05:00"
    )))

    XCTAssertEqual(lastUrl, "\(base)/events?address=\(wallet)&eventType=stop_loss_triggered&fromDate=2026-09-01T05%3A00%3A00%2B05%3A00")
  }

  func test_getEvent_encodesEventId() async throws {
    try respond(with: YieldXyzPerpsGetEventResponse(data: .stub()))

    _ = try await api.getEvent(eventId: "evt/1")

    XCTAssertEqual(lastUrl, "\(base)/events/evt%2F1")
  }

  // MARK: - Health

  func test_getHealth_getsHealth() async throws {
    try respond(with: YieldXyzPerpsGetHealthResponse(data: YieldXyzPerpsHealth(status: .ok, timestamp: "2026-08-26T10:30:00.000Z")))

    let response = try await api.getHealth()

    XCTAssertEqual(response.data.status, .ok)
    XCTAssertEqual(lastUrl, "\(base)/health")
  }

  func test_getProvidersHealth_getsPerVenueHealth() async throws {
    try respond(with: YieldXyzPerpsGetProvidersHealthResponse(data: YieldXyzPerpsProvidersHealth(
      generatedAt: "2026-08-26T10:30:00.000Z",
      providers: [YieldXyzPerpsProviderHealth(providerId: "hyperliquid", state: .healthy)]
    )))

    let response = try await api.getProvidersHealth()

    XCTAssertEqual(response.data.providers.first?.state, .healthy)
    XCTAssertEqual(lastUrl, "\(base)/health/providers")
  }

  // MARK: - Blank values

  func test_portfolioRequests_dropBlankVenues() async throws {
    try respond(with: YieldXyzPerpsGetPositionsResponse(data: []))

    _ = try await api.getPositions(request: YieldXyzPerpsPortfolioRequest(address: wallet, providerId: "", providerIds: ["hyperliquid", ""]))

    XCTAssertEqual(try lastBody(), ["address": wallet, "providerIds": ["hyperliquid"]])
  }

  func test_submitTransaction_dropsBlankValues() async throws {
    try respond(with: YieldXyzPerpsSubmitTransactionResponse(data: .stub()))

    _ = try await api.submitTransaction(params: YieldXyzPerpsSubmitTransactionParams(
      transactionId: "tx",
      actionId: "",
      signedPayload: "",
      transactionHash: YieldXyzPerpsFixtures.fundingTxHash
    ))

    XCTAssertEqual(try lastBody(), ["transactionHash": YieldXyzPerpsFixtures.fundingTxHash])
  }

  func test_queries_skipBlankValuesAndBlankListEntries() async throws {
    try respond(with: YieldXyzPerpsGetActivityResponse(data: YieldXyzPerpsPage(total: 0, offset: 0, limit: 25, items: [])))

    _ = try await api.getActivity(request: YieldXyzPerpsGetActivityRequest(address: wallet, params: YieldXyzPerpsGetActivityParams(
      providerId: "",
      providerIds: ["", "hyperliquid"]
    )))

    XCTAssertEqual(lastUrl, "\(base)/activity?address=\(wallet)&providerIds=hyperliquid")
  }

  func test_blankIds_areRejectedBeforeAnyRequest() async {
    let calls: [(String, () async throws -> Void)] = [
      ("providerId", { _ = try await self.api.getProvider(providerId: "") }),
      ("marketId", { _ = try await self.api.getMarket(marketId: "") }),
      ("actionId", { _ = try await self.api.getAction(actionId: "") }),
      ("eventId", { _ = try await self.api.getEvent(eventId: "") }),
      ("transactionId", { _ = try await self.api.submitTransaction(params: YieldXyzPerpsSubmitTransactionParams(transactionId: "", transactionHash: "0x1")) })
    ]

    for (name, call) in calls {
      do {
        try await call()
        XCTFail("Expected \(name) to be rejected.")
      } catch {
        XCTAssertEqual(error as? YieldXyzPerpsError, .emptyIdentifier(name: name))
      }
    }
    XCTAssertEqual(spy.executeCallsCount, 0)
  }

  // MARK: - Errors

  func test_failures_areRethrownUnchanged() async throws {
    let failMock = PortalRequestsFailMock()
    failMock.errorToThrow = URLError(.timedOut)
    api = PortalYieldXyzPerpsApi(credentials: StaticCredentials(MockConstants.mockApiKey), apiHost: MockConstants.mockHost, requests: failMock)

    do {
      _ = try await api.getProviders()
      XCTFail("Expected error not thrown.")
    } catch {
      XCTAssertEqual(error as? URLError, URLError(.timedOut))
    }
  }

  func test_aBlankCredential_failsBeforeTheRequestIsSent() async throws {
    api = PortalYieldXyzPerpsApi(credentials: StaticCredentials(""), apiHost: MockConstants.mockHost, requests: spy)

    do {
      _ = try await api.getHealth()
      XCTFail("Expected error not thrown.")
    } catch {
      XCTAssertTrue(error is PortalCredentialError)
      XCTAssertEqual(spy.executeCallsCount, 0)
    }
  }
}
