//
//  PortalYieldXyzBorrowApiMock.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import Foundation
@testable import PortalSwift

/// A scriptable `PortalYieldXyzBorrowApiProtocol` double. Every method records its calls. The
/// `getAction`, `stepAction` and `submitTransaction` results can be driven by a handler (a stateful
/// fake backend), or scripted per call (consumed in order, then falling back to the return value),
/// which drives the execution-runner tests. Recorded state is lock-protected, so concurrent
/// executions can share one instance.
final class PortalYieldXyzBorrowApiMock: PortalYieldXyzBorrowApiProtocol {
  private let lock = NSLock()

  private func locked<T>(_ body: () throws -> T) rethrows -> T {
    lock.lock()
    defer { lock.unlock() }
    return try body()
  }

  // MARK: Health

  var getHealthReturnValue: YieldXyzBorrowGetHealthResponse?
  private(set) var getHealthCallsCount = 0
  func getHealth() async throws -> YieldXyzBorrowGetHealthResponse {
    locked { getHealthCallsCount += 1 }
    return getHealthReturnValue ?? YieldXyzBorrowResponse(data: YieldXyzBorrowHealthStatus(status: .ok, timestamp: "2026-08-26T10:30:00.000Z"))
  }

  // MARK: Integrations

  var getIntegrationsReturnValue: YieldXyzBorrowGetIntegrationsResponse?
  private(set) var getIntegrationsCallsCount = 0
  func getIntegrations() async throws -> YieldXyzBorrowGetIntegrationsResponse {
    locked { getIntegrationsCallsCount += 1 }
    return getIntegrationsReturnValue ?? YieldXyzBorrowResponse(data: [.stub()])
  }

  var getIntegrationReturnValue: YieldXyzBorrowGetIntegrationResponse?
  private(set) var getIntegrationIntegrationIdParam: String?
  func getIntegration(integrationId: String) async throws -> YieldXyzBorrowGetIntegrationResponse {
    locked { getIntegrationIntegrationIdParam = integrationId }
    return getIntegrationReturnValue ?? YieldXyzBorrowResponse(data: .stub())
  }

  // MARK: Markets

  var getMarketsReturnValue: YieldXyzBorrowGetMarketsResponse?
  private(set) var getMarketsParams: YieldXyzBorrowGetMarketsParams?
  func getMarkets(params: YieldXyzBorrowGetMarketsParams) async throws -> YieldXyzBorrowGetMarketsResponse {
    locked { getMarketsParams = params }
    return getMarketsReturnValue ?? YieldXyzBorrowResponse(data: YieldXyzBorrowPage(total: 1, offset: 0, limit: 25, items: [.stub()]))
  }

  var getMarketReturnValue: YieldXyzBorrowGetMarketResponse?
  private(set) var getMarketMarketIdParam: String?
  func getMarket(marketId: String) async throws -> YieldXyzBorrowGetMarketResponse {
    locked { getMarketMarketIdParam = marketId }
    return getMarketReturnValue ?? YieldXyzBorrowResponse(data: .stub())
  }

  // MARK: Positions

  var getPositionsReturnValue: YieldXyzBorrowGetPositionsResponse?
  private(set) var getPositionsParams: YieldXyzBorrowGetPositionsParams?
  func getPositions(params: YieldXyzBorrowGetPositionsParams) async throws -> YieldXyzBorrowGetPositionsResponse {
    locked { getPositionsParams = params }
    return getPositionsReturnValue ?? YieldXyzBorrowResponse(data: .stub())
  }

  var getLiquidationsReturnValue: YieldXyzBorrowGetLiquidationsResponse?
  private(set) var getLiquidationsParams: YieldXyzBorrowGetLiquidationsParams?
  func getLiquidations(params: YieldXyzBorrowGetLiquidationsParams) async throws -> YieldXyzBorrowGetLiquidationsResponse {
    locked { getLiquidationsParams = params }
    return getLiquidationsReturnValue ?? YieldXyzBorrowResponse(data: YieldXyzBorrowPage(total: 1, offset: 0, limit: 25, items: [.stub()]))
  }

  // MARK: Actions

  var createActionReturnValue: YieldXyzBorrowActionResponse?
  var createActionError: Error?
  private(set) var createActionParams: YieldXyzBorrowCreateActionParams?
  private(set) var createActionCallsCount = 0
  func createAction(params: YieldXyzBorrowCreateActionParams) async throws -> YieldXyzBorrowActionResponse {
    try locked {
      createActionCallsCount += 1
      createActionParams = params
      if let createActionError {
        throw createActionError
      }
    }
    return createActionReturnValue ?? YieldXyzBorrowResponse(data: .stub())
  }

  var getActionsReturnValue: YieldXyzBorrowGetActionsResponse?
  private(set) var getActionsParams: YieldXyzBorrowGetActionsParams?
  func getActions(params: YieldXyzBorrowGetActionsParams) async throws -> YieldXyzBorrowGetActionsResponse {
    locked { getActionsParams = params }
    return getActionsReturnValue ?? YieldXyzBorrowResponse(data: YieldXyzBorrowPage(total: 1, offset: 0, limit: 25, items: [.stub()]))
  }

  /// Answers every `getAction` call when set.
  var getActionHandler: ((String) async throws -> YieldXyzBorrowAction)?
  /// Consumed one per `getAction` call before `getActionReturnValue` applies.
  var getActionResults: [Swift.Result<YieldXyzBorrowAction, Error>] = []
  var getActionReturnValue: YieldXyzBorrowAction?
  private(set) var getActionCallsCount = 0
  private(set) var getActionActionIdParam: String?
  func getAction(actionId: String) async throws -> YieldXyzBorrowActionResponse {
    let scripted: Swift.Result<YieldXyzBorrowAction, Error>? = locked {
      getActionCallsCount += 1
      getActionActionIdParam = actionId
      return getActionResults.isEmpty ? nil : getActionResults.removeFirst()
    }
    if let getActionHandler {
      return try await YieldXyzBorrowResponse(data: getActionHandler(actionId))
    }
    if let scripted {
      return try YieldXyzBorrowResponse(data: scripted.get())
    }
    return YieldXyzBorrowResponse(data: getActionReturnValue ?? .stub())
  }

  /// Answers every `stepAction` call when set.
  var stepActionHandler: ((String) async throws -> YieldXyzBorrowAction)?
  /// Consumed one per `stepAction` call before `stepActionReturnValue` applies.
  var stepActionResults: [Swift.Result<YieldXyzBorrowAction, Error>] = []
  var stepActionReturnValue: YieldXyzBorrowAction?
  private(set) var stepActionCallsCount = 0
  private(set) var stepActionActionIdParam: String?
  func stepAction(actionId: String) async throws -> YieldXyzBorrowActionResponse {
    let scripted: Swift.Result<YieldXyzBorrowAction, Error>? = locked {
      stepActionCallsCount += 1
      stepActionActionIdParam = actionId
      return stepActionResults.isEmpty ? nil : stepActionResults.removeFirst()
    }
    if let stepActionHandler {
      return try await YieldXyzBorrowResponse(data: stepActionHandler(actionId))
    }
    if let scripted {
      return try YieldXyzBorrowResponse(data: scripted.get())
    }
    return YieldXyzBorrowResponse(data: stepActionReturnValue ?? .stub())
  }

  /// Answers every `submitTransaction` call when set.
  var submitTransactionHandler: ((String, YieldXyzBorrowSubmitTransactionParams) async throws -> YieldXyzBorrowSubmitTransactionResult)?
  /// Consumed one per `submitTransaction` call before `submitTransactionReturnValue` applies.
  var submitTransactionResults: [Swift.Result<YieldXyzBorrowSubmitTransactionResult, Error>] = []
  var submitTransactionReturnValue: YieldXyzBorrowSubmitTransactionResult?
  private(set) var submitTransactionCalls: [(transactionId: String, params: YieldXyzBorrowSubmitTransactionParams)] = []
  func submitTransaction(
    transactionId: String,
    params: YieldXyzBorrowSubmitTransactionParams
  ) async throws -> YieldXyzBorrowSubmitTransactionResponse {
    let scripted: Swift.Result<YieldXyzBorrowSubmitTransactionResult, Error>? = locked {
      submitTransactionCalls.append((transactionId, params))
      return submitTransactionResults.isEmpty ? nil : submitTransactionResults.removeFirst()
    }
    if let submitTransactionHandler {
      return try await YieldXyzBorrowResponse(data: submitTransactionHandler(transactionId, params))
    }
    if let scripted {
      return try YieldXyzBorrowResponse(data: scripted.get())
    }
    return YieldXyzBorrowResponse(data: submitTransactionReturnValue ?? .stub())
  }

  var submitTransactionCallsCount: Int {
    locked { submitTransactionCalls.count }
  }
}
