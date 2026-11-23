//
//  PortalYieldXyzPerpsApiMock.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import Foundation
@testable import PortalSwift

/// A scriptable `PortalYieldXyzPerpsApiProtocol` double. Every method records its calls; the
/// `getAction` and `submitTransaction` results can be scripted per call (consumed in order, then
/// falling back to the return value), which drives the execution-runner tests.
final class PortalYieldXyzPerpsApiMock: PortalYieldXyzPerpsApiProtocol {
  // MARK: Providers

  var getProvidersReturnValue: YieldXyzPerpsGetProvidersResponse?
  private(set) var getProvidersCallsCount = 0
  func getProviders() async throws -> YieldXyzPerpsGetProvidersResponse {
    getProvidersCallsCount += 1
    return getProvidersReturnValue ?? YieldXyzPerpsResponse(data: [.stub()])
  }

  var getProviderReturnValue: YieldXyzPerpsGetProviderResponse?
  private(set) var getProviderProviderIdParam: String?
  func getProvider(providerId: String) async throws -> YieldXyzPerpsGetProviderResponse {
    getProviderProviderIdParam = providerId
    return getProviderReturnValue ?? YieldXyzPerpsResponse(data: .stub())
  }

  // MARK: Markets

  var getMarketsReturnValue: YieldXyzPerpsGetMarketsResponse?
  private(set) var getMarketsParams: YieldXyzPerpsGetMarketsParams?
  func getMarkets(params: YieldXyzPerpsGetMarketsParams) async throws -> YieldXyzPerpsGetMarketsResponse {
    getMarketsParams = params
    return getMarketsReturnValue ?? YieldXyzPerpsResponse(data: YieldXyzPerpsPage(total: 1, offset: 0, limit: 25, items: [.stub()]))
  }

  var getMarketReturnValue: YieldXyzPerpsGetMarketResponse?
  private(set) var getMarketMarketIdParam: String?
  func getMarket(marketId: String) async throws -> YieldXyzPerpsGetMarketResponse {
    getMarketMarketIdParam = marketId
    return getMarketReturnValue ?? YieldXyzPerpsResponse(data: .stub())
  }

  var getMarketCandlesReturnValue: YieldXyzPerpsGetMarketCandlesResponse?
  private(set) var getMarketCandlesMarketIdParam: String?
  private(set) var getMarketCandlesParams: YieldXyzPerpsGetMarketCandlesParams?
  func getMarketCandles(marketId: String, params: YieldXyzPerpsGetMarketCandlesParams) async throws -> YieldXyzPerpsGetMarketCandlesResponse {
    getMarketCandlesMarketIdParam = marketId
    getMarketCandlesParams = params
    return getMarketCandlesReturnValue ?? YieldXyzPerpsResponse(data: .stub())
  }

  // MARK: Account

  var getPositionsReturnValue: YieldXyzPerpsGetPositionsResponse?
  private(set) var getPositionsRequest: YieldXyzPerpsPortfolioRequest?
  func getPositions(request: YieldXyzPerpsPortfolioRequest) async throws -> YieldXyzPerpsGetPositionsResponse {
    getPositionsRequest = request
    return getPositionsReturnValue ?? YieldXyzPerpsResponse(data: [.stub()])
  }

  var getOrdersReturnValue: YieldXyzPerpsGetOrdersResponse?
  private(set) var getOrdersRequest: YieldXyzPerpsPortfolioRequest?
  func getOrders(request: YieldXyzPerpsPortfolioRequest) async throws -> YieldXyzPerpsGetOrdersResponse {
    getOrdersRequest = request
    return getOrdersReturnValue ?? YieldXyzPerpsResponse(data: [.stub()])
  }

  var getBalancesReturnValue: YieldXyzPerpsGetBalancesResponse?
  private(set) var getBalancesRequest: YieldXyzPerpsPortfolioRequest?
  func getBalances(request: YieldXyzPerpsPortfolioRequest) async throws -> YieldXyzPerpsGetBalancesResponse {
    getBalancesRequest = request
    return getBalancesReturnValue ?? YieldXyzPerpsResponse(data: .stub())
  }

  // MARK: Actions

  var createActionReturnValue: YieldXyzPerpsCreateActionResponse?
  var createActionError: Error?
  private(set) var createActionRequest: YieldXyzPerpsCreateActionRequest?
  private(set) var createActionCallsCount = 0
  func createAction(request: YieldXyzPerpsCreateActionRequest) async throws -> YieldXyzPerpsCreateActionResponse {
    createActionCallsCount += 1
    createActionRequest = request
    if let createActionError {
      throw createActionError
    }
    return createActionReturnValue ?? YieldXyzPerpsResponse(data: .stub())
  }

  var getActionsReturnValue: YieldXyzPerpsGetActionsResponse?
  private(set) var getActionsRequest: YieldXyzPerpsGetActionsRequest?
  func getActions(request: YieldXyzPerpsGetActionsRequest) async throws -> YieldXyzPerpsGetActionsResponse {
    getActionsRequest = request
    return getActionsReturnValue ?? YieldXyzPerpsResponse(data: YieldXyzPerpsPage(total: 1, offset: 0, limit: 25, items: [.stub()]))
  }

  /// Consumed one per `getAction` call before `getActionReturnValue` applies.
  var getActionResults: [Swift.Result<YieldXyzPerpsAction, Error>] = []
  var getActionReturnValue: YieldXyzPerpsAction?
  private(set) var getActionCallsCount = 0
  private(set) var getActionActionIdParam: String?
  func getAction(actionId: String) async throws -> YieldXyzPerpsGetActionResponse {
    getActionCallsCount += 1
    getActionActionIdParam = actionId
    if !getActionResults.isEmpty {
      return try YieldXyzPerpsResponse(data: getActionResults.removeFirst().get())
    }
    return YieldXyzPerpsResponse(data: getActionReturnValue ?? .stub())
  }

  /// Consumed one per `submitTransaction` call before `submitTransactionReturnValue` applies.
  var submitTransactionResults: [Swift.Result<YieldXyzPerpsSubmitResult, Error>] = []
  var submitTransactionReturnValue: YieldXyzPerpsSubmitResult?
  private(set) var submitTransactionParams: [YieldXyzPerpsSubmitTransactionParams] = []
  func submitTransaction(params: YieldXyzPerpsSubmitTransactionParams) async throws -> YieldXyzPerpsSubmitTransactionResponse {
    submitTransactionParams.append(params)
    if !submitTransactionResults.isEmpty {
      return try YieldXyzPerpsResponse(data: submitTransactionResults.removeFirst().get())
    }
    return YieldXyzPerpsResponse(data: submitTransactionReturnValue ?? .stub())
  }

  // MARK: History

  var getActivityReturnValue: YieldXyzPerpsGetActivityResponse?
  private(set) var getActivityRequest: YieldXyzPerpsGetActivityRequest?
  func getActivity(request: YieldXyzPerpsGetActivityRequest) async throws -> YieldXyzPerpsGetActivityResponse {
    getActivityRequest = request
    return getActivityReturnValue ?? YieldXyzPerpsResponse(data: YieldXyzPerpsPage(total: 0, offset: 0, limit: 25, items: []))
  }

  var getEventsReturnValue: YieldXyzPerpsGetEventsResponse?
  private(set) var getEventsRequest: YieldXyzPerpsGetEventsRequest?
  func getEvents(request: YieldXyzPerpsGetEventsRequest) async throws -> YieldXyzPerpsGetEventsResponse {
    getEventsRequest = request
    return getEventsReturnValue ?? YieldXyzPerpsResponse(data: YieldXyzPerpsPage(total: 1, offset: 0, limit: 25, items: [.stub()]))
  }

  var getEventReturnValue: YieldXyzPerpsGetEventResponse?
  private(set) var getEventEventIdParam: String?
  func getEvent(eventId: String) async throws -> YieldXyzPerpsGetEventResponse {
    getEventEventIdParam = eventId
    return getEventReturnValue ?? YieldXyzPerpsResponse(data: .stub())
  }

  // MARK: Health

  var getHealthReturnValue: YieldXyzPerpsGetHealthResponse?
  private(set) var getHealthCallsCount = 0
  func getHealth() async throws -> YieldXyzPerpsGetHealthResponse {
    getHealthCallsCount += 1
    return getHealthReturnValue ?? YieldXyzPerpsResponse(data: YieldXyzPerpsHealth(status: .ok, timestamp: "2026-08-26T10:30:00.000Z"))
  }

  var getProvidersHealthReturnValue: YieldXyzPerpsGetProvidersHealthResponse?
  private(set) var getProvidersHealthCallsCount = 0
  func getProvidersHealth() async throws -> YieldXyzPerpsGetProvidersHealthResponse {
    getProvidersHealthCallsCount += 1
    return getProvidersHealthReturnValue ?? YieldXyzPerpsResponse(data: YieldXyzPerpsProvidersHealth(
      generatedAt: "2026-08-26T10:30:00.000Z",
      providers: [YieldXyzPerpsProviderHealth(providerId: "hyperliquid", state: .healthy)]
    ))
  }
}
