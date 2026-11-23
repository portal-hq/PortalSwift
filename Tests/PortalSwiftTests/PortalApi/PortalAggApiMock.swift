//
//  PortalAggApiMock.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import Foundation
@testable import PortalSwift

/// A `PortalAggApiProtocol` whose methods run the handler a test sets, and record each call in
/// order. A method without a handler throws `NotStubbed`.
final class PortalAggApiMock: PortalAggApiProtocol {
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

  var createLinkChallengeHandler: ((AggLinkChallengeRequest) async throws -> AggCreateLinkChallengeResponse)?
  func createLinkChallenge(request: AggLinkChallengeRequest) async throws -> AggCreateLinkChallengeResponse {
    record("createLinkChallenge")
    guard let handler = createLinkChallengeHandler else {
      throw NotStubbed(method: "createLinkChallenge")
    }
    return try await handler(request)
  }

  var createLinkHandler: ((AggLinkRequest) async throws -> AggCreateLinkResponse)?
  func createLink(request: AggLinkRequest) async throws -> AggCreateLinkResponse {
    record("createLink")
    guard let handler = createLinkHandler else {
      throw NotStubbed(method: "createLink")
    }
    return try await handler(request)
  }

  var getLinkHandler: (() async throws -> AggGetLinkResponse)?
  func getLink() async throws -> AggGetLinkResponse {
    record("getLink")
    guard let handler = getLinkHandler else {
      throw NotStubbed(method: "getLink")
    }
    return try await handler()
  }

  var deleteLinkHandler: (() async throws -> AggDeleteLinkResponse)?
  func deleteLink() async throws -> AggDeleteLinkResponse {
    record("deleteLink")
    guard let handler = deleteLinkHandler else {
      throw NotStubbed(method: "deleteLink")
    }
    return try await handler()
  }

  var listEventsHandler: ((AggListEventsParams) async throws -> AggListEventsResponse)?
  func listEvents(params: AggListEventsParams) async throws -> AggListEventsResponse {
    record("listEvents")
    guard let handler = listEventsHandler else {
      throw NotStubbed(method: "listEvents")
    }
    return try await handler(params)
  }

  var getEventHandler: ((String, Bool?) async throws -> AggGetEventResponse)?
  func getEvent(eventId: String, cluster: Bool?) async throws -> AggGetEventResponse {
    record("getEvent")
    guard let handler = getEventHandler else {
      throw NotStubbed(method: "getEvent")
    }
    return try await handler(eventId, cluster)
  }

  var getEventBootstrapHandler: ((String, Int?) async throws -> AggGetEventBootstrapResponse)?
  func getEventBootstrap(eventId: String, limit: Int?) async throws -> AggGetEventBootstrapResponse {
    record("getEventBootstrap")
    guard let handler = getEventBootstrapHandler else {
      throw NotStubbed(method: "getEventBootstrap")
    }
    return try await handler(eventId, limit)
  }

  var listMarketsHandler: ((AggListMarketsParams) async throws -> AggListMarketsResponse)?
  func listMarkets(params: AggListMarketsParams) async throws -> AggListMarketsResponse {
    record("listMarkets")
    guard let handler = listMarketsHandler else {
      throw NotStubbed(method: "listMarkets")
    }
    return try await handler(params)
  }

  var searchHandler: ((AggSearchParams) async throws -> AggSearchResponse)?
  func search(params: AggSearchParams) async throws -> AggSearchResponse {
    record("search")
    guard let handler = searchHandler else {
      throw NotStubbed(method: "search")
    }
    return try await handler(params)
  }

  var listCategoriesHandler: ((AggListCategoriesParams) async throws -> AggListCategoriesResponse)?
  func listCategories(params: AggListCategoriesParams) async throws -> AggListCategoriesResponse {
    record("listCategories")
    guard let handler = listCategoriesHandler else {
      throw NotStubbed(method: "listCategories")
    }
    return try await handler(params)
  }

  var getVenueGeoPolicyHandler: (() async throws -> AggGetVenueGeoPolicyResponse)?
  func getVenueGeoPolicy() async throws -> AggGetVenueGeoPolicyResponse {
    record("getVenueGeoPolicy")
    guard let handler = getVenueGeoPolicyHandler else {
      throw NotStubbed(method: "getVenueGeoPolicy")
    }
    return try await handler()
  }

  var getAppConfigHandler: (() async throws -> AggGetAppConfigResponse)?
  func getAppConfig() async throws -> AggGetAppConfigResponse {
    record("getAppConfig")
    guard let handler = getAppConfigHandler else {
      throw NotStubbed(method: "getAppConfig")
    }
    return try await handler()
  }

  var getMidpointsHandler: (([String], Bool?) async throws -> AggGetMidpointsResponse)?
  func getMidpoints(venueMarketIds: [String], bestPrice: Bool?) async throws -> AggGetMidpointsResponse {
    record("getMidpoints")
    guard let handler = getMidpointsHandler else {
      throw NotStubbed(method: "getMidpoints")
    }
    return try await handler(venueMarketIds, bestPrice)
  }

  var getOrderbooksHandler: (([String], Int?) async throws -> AggGetOrderbooksResponse)?
  func getOrderbooks(venueMarketIds: [String], depth: Int?) async throws -> AggGetOrderbooksResponse {
    record("getOrderbooks")
    guard let handler = getOrderbooksHandler else {
      throw NotStubbed(method: "getOrderbooks")
    }
    return try await handler(venueMarketIds, depth)
  }

  var getOutcomeOrderbookHandler: ((String, Int?) async throws -> AggGetOutcomeOrderbookResponse)?
  func getOutcomeOrderbook(outcomeId: String, depth: Int?) async throws -> AggGetOutcomeOrderbookResponse {
    record("getOutcomeOrderbook")
    guard let handler = getOutcomeOrderbookHandler else {
      throw NotStubbed(method: "getOutcomeOrderbook")
    }
    return try await handler(outcomeId, depth)
  }

  var getChartBarsHandler: ((AggChartParams) async throws -> AggGetChartBarsResponse)?
  func getChartBars(params: AggChartParams) async throws -> AggGetChartBarsResponse {
    record("getChartBars")
    guard let handler = getChartBarsHandler else {
      throw NotStubbed(method: "getChartBars")
    }
    return try await handler(params)
  }

  var getChartHistoryManifestHandler: ((AggChartParams) async throws -> AggGetChartHistoryManifestResponse)?
  func getChartHistoryManifest(params: AggChartParams) async throws -> AggGetChartHistoryManifestResponse {
    record("getChartHistoryManifest")
    guard let handler = getChartHistoryManifestHandler else {
      throw NotStubbed(method: "getChartHistoryManifest")
    }
    return try await handler(params)
  }

  var getUserHandler: (() async throws -> AggGetUserResponse)?
  func getUser() async throws -> AggGetUserResponse {
    record("getUser")
    guard let handler = getUserHandler else {
      throw NotStubbed(method: "getUser")
    }
    return try await handler()
  }

  var getDepositAddressesHandler: (() async throws -> AggGetDepositAddressesResponse)?
  func getDepositAddresses() async throws -> AggGetDepositAddressesResponse {
    record("getDepositAddresses")
    guard let handler = getDepositAddressesHandler else {
      throw NotStubbed(method: "getDepositAddresses")
    }
    return try await handler()
  }

  var getBalancesHandler: ((Bool?, AggMode?) async throws -> AggGetBalancesResponse)?
  func getBalances(sync: Bool?, mode: AggMode?) async throws -> AggGetBalancesResponse {
    record("getBalances")
    guard let handler = getBalancesHandler else {
      throw NotStubbed(method: "getBalances")
    }
    return try await handler(sync, mode)
  }

  var listPositionsHandler: ((AggListPositionsParams) async throws -> AggListPositionsResponse)?
  func listPositions(params: AggListPositionsParams) async throws -> AggListPositionsResponse {
    record("listPositions")
    guard let handler = listPositionsHandler else {
      throw NotStubbed(method: "listPositions")
    }
    return try await handler(params)
  }

  var listOrdersHandler: ((AggListOrdersParams) async throws -> AggListOrdersResponse)?
  func listOrders(params: AggListOrdersParams) async throws -> AggListOrdersResponse {
    record("listOrders")
    guard let handler = listOrdersHandler else {
      throw NotStubbed(method: "listOrders")
    }
    return try await handler(params)
  }

  var listActivityHandler: ((AggListActivityParams) async throws -> AggListActivityResponse)?
  func listActivity(params: AggListActivityParams) async throws -> AggListActivityResponse {
    record("listActivity")
    guard let handler = listActivityHandler else {
      throw NotStubbed(method: "listActivity")
    }
    return try await handler(params)
  }

  var createQuoteHandler: ((AggQuoteRequest) async throws -> AggCreateQuoteResponse)?
  func createQuote(request: AggQuoteRequest) async throws -> AggCreateQuoteResponse {
    record("createQuote")
    guard let handler = createQuoteHandler else {
      throw NotStubbed(method: "createQuote")
    }
    return try await handler(request)
  }

  var createOrderHandler: ((AggOrderRequest) async throws -> AggCreateOrderResponse)?
  func createOrder(request: AggOrderRequest) async throws -> AggCreateOrderResponse {
    record("createOrder")
    guard let handler = createOrderHandler else {
      throw NotStubbed(method: "createOrder")
    }
    return try await handler(request)
  }

  var getOrderHandler: ((String, AggMode?) async throws -> AggGetOrderResponse)?
  func getOrder(quoteId: String, mode: AggMode?) async throws -> AggGetOrderResponse {
    record("getOrder")
    guard let handler = getOrderHandler else {
      throw NotStubbed(method: "getOrder")
    }
    return try await handler(quoteId, mode)
  }

  var createLimitOrderHandler: ((AggLimitOrderRequest) async throws -> AggCreateLimitOrderResponse)?
  func createLimitOrder(request: AggLimitOrderRequest) async throws -> AggCreateLimitOrderResponse {
    record("createLimitOrder")
    guard let handler = createLimitOrderHandler else {
      throw NotStubbed(method: "createLimitOrder")
    }
    return try await handler(request)
  }

  var createDirectOrderHandler: ((AggDirectOrderRequest) async throws -> AggCreateDirectOrderResponse)?
  func createDirectOrder(request: AggDirectOrderRequest) async throws -> AggCreateDirectOrderResponse {
    record("createDirectOrder")
    guard let handler = createDirectOrderHandler else {
      throw NotStubbed(method: "createDirectOrder")
    }
    return try await handler(request)
  }

  var cancelOrderHandler: ((AggCancelOrderRequest) async throws -> AggCancelOrderResponse)?
  func cancelOrder(request: AggCancelOrderRequest) async throws -> AggCancelOrderResponse {
    record("cancelOrder")
    guard let handler = cancelOrderHandler else {
      throw NotStubbed(method: "cancelOrder")
    }
    return try await handler(request)
  }

  var redeemPositionsHandler: ((AggRedeemRequest) async throws -> AggRedeemPositionsResponse)?
  func redeemPositions(request: AggRedeemRequest) async throws -> AggRedeemPositionsResponse {
    record("redeemPositions")
    guard let handler = redeemPositionsHandler else {
      throw NotStubbed(method: "redeemPositions")
    }
    return try await handler(request)
  }

  var quoteWithdrawableHandler: ((AggWithdrawableQuoteRequest) async throws -> AggQuoteWithdrawableResponse)?
  func quoteWithdrawable(request: AggWithdrawableQuoteRequest) async throws -> AggQuoteWithdrawableResponse {
    record("quoteWithdrawable")
    guard let handler = quoteWithdrawableHandler else {
      throw NotStubbed(method: "quoteWithdrawable")
    }
    return try await handler(request)
  }

  var previewWithdrawalHandler: ((AggWithdrawalRequest) async throws -> AggPreviewWithdrawalResponse)?
  func previewWithdrawal(request: AggWithdrawalRequest) async throws -> AggPreviewWithdrawalResponse {
    record("previewWithdrawal")
    guard let handler = previewWithdrawalHandler else {
      throw NotStubbed(method: "previewWithdrawal")
    }
    return try await handler(request)
  }

  var createWithdrawalHandler: ((AggWithdrawalRequest) async throws -> AggWithdrawalResponse)?
  func createWithdrawal(request: AggWithdrawalRequest) async throws -> AggWithdrawalResponse {
    record("createWithdrawal")
    guard let handler = createWithdrawalHandler else {
      throw NotStubbed(method: "createWithdrawal")
    }
    return try await handler(request)
  }

  var getWithdrawalHandler: ((String) async throws -> AggWithdrawalResponse)?
  func getWithdrawal(withdrawalId: String) async throws -> AggWithdrawalResponse {
    record("getWithdrawal")
    guard let handler = getWithdrawalHandler else {
      throw NotStubbed(method: "getWithdrawal")
    }
    return try await handler(withdrawalId)
  }
}
