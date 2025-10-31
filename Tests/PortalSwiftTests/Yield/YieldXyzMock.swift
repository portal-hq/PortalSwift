//
//  YieldXyzMock.swift
//  PortalSwift
//
//  Created by Portal Labs
//

import Foundation
@testable import PortalSwift

/// Mock implementation of YieldXyzProtocol for testing purposes.
final class YieldXyzMock: YieldXyzProtocol {
  // Configurable return values
  var discoverReturnValue: YieldXyzGetYieldsResponse?
  var enterReturnValue: YieldXyzEnterYieldResponse?
  var trackReturnValue: YieldXyzTrackTransactionResponse?
  var getBalancesReturnValue: YieldXyzGetBalancesResponse?
  var getTransactionReturnValue: YieldXyzGetTransactionResponse?
  var getHistoricalActionsReturnValue: YieldXyzGetHistoricalActionsResponse?
  var manageReturnValue: YieldXyzManageYieldResponse?
  var exitReturnValue: YieldXyzExitResponse?

  // Call counters
  var discoverCalls = 0
  var enterCalls = 0
  var trackCalls = 0
  var getBalancesCalls = 0
  var getTransactionCalls = 0
  var getHistoricalActionsCalls = 0
  var manageCalls = 0
  var exitCalls = 0

  // Call parameters
  var discoverRequestParam: YieldXyzGetYieldsRequest?
  var enterRequestParam: YieldXyzEnterRequest?
  var trackTransactionIdParam: String?
  var trackTxHashParam: String?
  var getBalancesRequestParam: YieldXyzGetBalancesRequest?
  var getTransactionIdParam: String?
  var getHistoricalActionsRequestParam: YieldXyzGetHistoricalActionsRequest?
  var manageRequestParam: YieldXyzManageYieldRequest?
  var exitRequestParam: YieldXyzExitRequest?

  func discover(request: YieldXyzGetYieldsRequest?) async throws -> YieldXyzGetYieldsResponse {
    discoverCalls += 1
    discoverRequestParam = request
    return discoverReturnValue ?? YieldXyzGetYieldsResponse.stub()
  }

  func enter(request: YieldXyzEnterRequest) async throws -> YieldXyzEnterYieldResponse {
    enterCalls += 1
    enterRequestParam = request
    return enterReturnValue ?? YieldXyzEnterYieldResponse.stub()
  }

  func track(transactionId: String, txHash: String) async throws -> YieldXyzTrackTransactionResponse {
    trackCalls += 1
    trackTransactionIdParam = transactionId
    trackTxHashParam = txHash
    return trackReturnValue ?? YieldXyzTrackTransactionResponse.stub()
  }

  func getBalances(request: YieldXyzGetBalancesRequest) async throws -> YieldXyzGetBalancesResponse {
    getBalancesCalls += 1
    getBalancesRequestParam = request
    return getBalancesReturnValue ?? YieldXyzGetBalancesResponse.stub()
  }

  func getTransaction(transactionId: String) async throws -> YieldXyzGetTransactionResponse {
    getTransactionCalls += 1
    getTransactionIdParam = transactionId
    return getTransactionReturnValue ?? YieldXyzGetTransactionResponse.stub()
  }

  func getHistoricalActions(request: YieldXyzGetHistoricalActionsRequest) async throws -> YieldXyzGetHistoricalActionsResponse {
    getHistoricalActionsCalls += 1
    getHistoricalActionsRequestParam = request
    return getHistoricalActionsReturnValue ?? YieldXyzGetHistoricalActionsResponse.stub()
  }

  func manage(request: YieldXyzManageYieldRequest) async throws -> YieldXyzManageYieldResponse {
    manageCalls += 1
    manageRequestParam = request
    return manageReturnValue ?? YieldXyzManageYieldResponse.stub()
  }

  func exit(request: YieldXyzExitRequest) async throws -> YieldXyzExitResponse {
    exitCalls += 1
    exitRequestParam = request
    return exitReturnValue ?? YieldXyzExitResponse.stub()
  }
}
