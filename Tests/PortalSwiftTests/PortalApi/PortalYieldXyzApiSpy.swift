//
//  PortalYieldXyzApiSpy.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 30/10/2025.
//

import Foundation
@testable import PortalSwift

final class PortalYieldXyzApiSpy: PortalYieldXyzApiProtocol {
  // MARK: - getYields

  var getYieldsCallsCount = 0
  var getYieldsRequestParam: YieldXyzGetYieldsRequest?
  var getYieldsReturnValue: YieldXyzGetYieldsResponse = .stub()
  func getYields(request: YieldXyzGetYieldsRequest) async throws -> YieldXyzGetYieldsResponse {
    getYieldsCallsCount += 1
    getYieldsRequestParam = request
    return getYieldsReturnValue
  }

  // MARK: - enterYield

  var enterYieldCallsCount = 0
  var enterYieldRequestParam: YieldXyzEnterRequest?
  var enterYieldReturnValue: YieldXyzEnterYieldResponse = .stub()
  func enterYield(request: YieldXyzEnterRequest) async throws -> YieldXyzEnterYieldResponse {
    enterYieldCallsCount += 1
    enterYieldRequestParam = request
    return enterYieldReturnValue
  }

  // MARK: - exitYield

  var exitYieldCallsCount = 0
  var exitYieldRequestParam: YieldXyzExitRequest?
  var exitYieldReturnValue: YieldXyzExitResponse = .stub()
  func exitYield(request: YieldXyzExitRequest) async throws -> YieldXyzExitResponse {
    exitYieldCallsCount += 1
    exitYieldRequestParam = request
    return exitYieldReturnValue
  }

  // MARK: - manageYield

  var manageYieldCallsCount = 0
  var manageYieldRequestParam: YieldXyzManageYieldRequest?
  var manageYieldReturnValue: YieldXyzManageYieldResponse = .stub()
  func manageYield(request: YieldXyzManageYieldRequest) async throws -> YieldXyzManageYieldResponse {
    manageYieldCallsCount += 1
    manageYieldRequestParam = request
    return manageYieldReturnValue
  }

  // MARK: - getYieldBalances

  var getYieldBalancesCallsCount = 0
  var getYieldBalancesRequestParam: YieldXyzGetBalancesRequest?
  var getYieldBalancesReturnValue: YieldXyzGetBalancesResponse = .stub()
  func getYieldBalances(request: YieldXyzGetBalancesRequest) async throws -> YieldXyzGetBalancesResponse {
    getYieldBalancesCallsCount += 1
    getYieldBalancesRequestParam = request
    return getYieldBalancesReturnValue
  }

  // MARK: - getHistoricalYieldActions

  var getHistoricalYieldActionsCallsCount = 0
  var getHistoricalYieldActionsRequestParam: YieldXyzGetHistoricalActionsRequest?
  var getHistoricalYieldActionsReturnValue: YieldXyzGetHistoricalActionsResponse = .stub()
  func getHistoricalYieldActions(request: YieldXyzGetHistoricalActionsRequest) async throws -> YieldXyzGetHistoricalActionsResponse {
    getHistoricalYieldActionsCallsCount += 1
    getHistoricalYieldActionsRequestParam = request
    return getHistoricalYieldActionsReturnValue
  }

  // MARK: - getYieldTransaction

  var getYieldTransactionCallsCount = 0
  var getYieldTransactionIdParam: String?
  var getYieldTransactionReturnValue: YieldXyzGetTransactionResponse = .stub()
  func getYieldTransaction(transactionId: String) async throws -> YieldXyzGetTransactionResponse {
    getYieldTransactionCallsCount += 1
    getYieldTransactionIdParam = transactionId
    return getYieldTransactionReturnValue
  }

  // MARK: - submitTransactionHash

  var submitTransactionHashCallsCount = 0
  var submitTransactionHashRequestParam: YieldXyzTrackTransactionRequest?
  var submitTransactionHashReturnValue: YieldXyzTrackTransactionResponse = .stub()
  func submitTransactionHash(request: YieldXyzTrackTransactionRequest) async throws -> YieldXyzTrackTransactionResponse {
    submitTransactionHashCallsCount += 1
    submitTransactionHashRequestParam = request
    return submitTransactionHashReturnValue
  }
}
