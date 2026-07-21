//
//  PortalYieldXyzApiMock.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 30/10/2025.
//

import Foundation
@testable import PortalSwift

final class PortalYieldXyzApiMock: PortalYieldXyzApiProtocol {
  // Configurable return values
  var getYieldsReturnValue: YieldXyzGetYieldsResponse?
  var enterYieldReturnValue: YieldXyzEnterYieldResponse?
  var exitYieldReturnValue: YieldXyzExitResponse?
  var manageYieldReturnValue: YieldXyzManageYieldResponse?
  var getYieldBalancesReturnValue: YieldXyzGetBalancesResponse?
  var getHistoricalYieldActionsReturnValue: YieldXyzGetHistoricalActionsResponse?
  var getYieldTransactionReturnValue: YieldXyzGetTransactionResponse?
  var submitTransactionHashReturnValue: YieldXyzTrackTransactionResponse?
  var getYieldDefaultsReturnValue: YieldXyzGetDefaultsResponse?
  var getYieldValidatorsReturnValue: YieldXyzGetValidatorsResponse?

  // Call counters
  var getYieldsCalls = 0
  var enterYieldCalls = 0
  var exitYieldCalls = 0
  var manageYieldCalls = 0
  var getYieldBalancesCalls = 0
  var getHistoricalYieldActionsCalls = 0
  var getYieldTransactionCalls = 0
  var submitTransactionHashCalls = 0
  var getYieldDefaultsCalls = 0
  var getYieldValidatorsCalls = 0

  // Call parameters
  var getYieldDefaultsIncludeOpportunitiesParam: Bool?
  var getYieldValidatorsYieldIdParam: String?

  func getYields(request _: YieldXyzGetYieldsRequest) async throws -> YieldXyzGetYieldsResponse {
    getYieldsCalls += 1
    return getYieldsReturnValue ?? YieldXyzGetYieldsResponse.stub()
  }

  func enterYield(request _: YieldXyzEnterRequest) async throws -> YieldXyzEnterYieldResponse {
    enterYieldCalls += 1
    return enterYieldReturnValue ?? YieldXyzEnterYieldResponse.stub()
  }

  func exitYield(request _: YieldXyzExitRequest) async throws -> YieldXyzExitResponse {
    exitYieldCalls += 1
    return exitYieldReturnValue ?? YieldXyzExitResponse.stub()
  }

  func manageYield(request _: YieldXyzManageYieldRequest) async throws -> YieldXyzManageYieldResponse {
    manageYieldCalls += 1
    return manageYieldReturnValue ?? YieldXyzManageYieldResponse.stub()
  }

  func getYieldBalances(request _: YieldXyzGetBalancesRequest) async throws -> YieldXyzGetBalancesResponse {
    getYieldBalancesCalls += 1
    return getYieldBalancesReturnValue ?? YieldXyzGetBalancesResponse.stub()
  }

  func getHistoricalYieldActions(request _: YieldXyzGetHistoricalActionsRequest) async throws -> YieldXyzGetHistoricalActionsResponse {
    getHistoricalYieldActionsCalls += 1
    return getHistoricalYieldActionsReturnValue ?? YieldXyzGetHistoricalActionsResponse.stub()
  }

  func getYieldTransaction(transactionId _: String) async throws -> YieldXyzGetTransactionResponse {
    getYieldTransactionCalls += 1
    return getYieldTransactionReturnValue ?? YieldXyzGetTransactionResponse.stub()
  }

  func submitTransactionHash(request _: YieldXyzTrackTransactionRequest) async throws -> YieldXyzTrackTransactionResponse {
    submitTransactionHashCalls += 1
    return submitTransactionHashReturnValue ?? YieldXyzTrackTransactionResponse.stub()
  }

  func getYieldDefaults(includeOpportunities: Bool?) async throws -> YieldXyzGetDefaultsResponse {
    getYieldDefaultsCalls += 1
    getYieldDefaultsIncludeOpportunitiesParam = includeOpportunities
    return getYieldDefaultsReturnValue ?? YieldXyzGetDefaultsResponse.stub()
  }

  func getYieldValidators(yieldId: String) async throws -> YieldXyzGetValidatorsResponse {
    getYieldValidatorsCalls += 1
    getYieldValidatorsYieldIdParam = yieldId
    return getYieldValidatorsReturnValue ?? YieldXyzGetValidatorsResponse.stub()
  }
}
