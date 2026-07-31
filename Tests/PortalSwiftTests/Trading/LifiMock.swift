//
//  LifiMock.swift
//  PortalSwift
//
//  Created by Portal Labs
//

import Foundation
@testable import PortalSwift

/// Mock implementation of LifiProtocol for testing purposes.
final class LifiMock: LifiProtocol {
  // MARK: - Configurable return values

  var getRoutesReturnValue: LifiRoutesResponse?
  var getQuoteReturnValue: LifiQuoteResponse?
  var getStatusReturnValue: LifiStatusResponse?
  var getRouteStepReturnValue: LifiStepTransactionResponse?
  var tradeAssetReturnValue: LifiTradeAssetResult?
  var pollStatusReturnValue: LifiStatusRawResponse?

  // MARK: - Error simulation

  var getRoutesError: Error?
  var getQuoteError: Error?
  var getStatusError: Error?
  var getRouteStepError: Error?
  var tradeAssetError: Error?
  var pollStatusError: Error?

  // MARK: - Call counters

  var getRoutesCalls = 0
  var getQuoteCalls = 0
  var getStatusCalls = 0
  var getRouteStepCalls = 0
  var tradeAssetCalls = 0
  var pollStatusCalls = 0

  // MARK: - Call parameters

  var getRoutesRequestParam: LifiRoutesRequest?
  var getQuoteRequestParam: LifiQuoteRequest?
  var getStatusRequestParam: LifiStatusRequest?
  var getRouteStepRequestParam: LifiStepTransactionRequest?
  var tradeAssetParamsParam: LifiTradeAssetParams?
  var pollStatusRequestParam: LifiStatusRequest?

  // MARK: - Protocol Implementation

  func getRoutes(request: LifiRoutesRequest) async throws -> LifiRoutesResponse {
    getRoutesCalls += 1
    getRoutesRequestParam = request
    if let error = getRoutesError {
      throw error
    }
    return getRoutesReturnValue ?? LifiRoutesResponse.stub()
  }

  func getQuote(request: LifiQuoteRequest) async throws -> LifiQuoteResponse {
    getQuoteCalls += 1
    getQuoteRequestParam = request
    if let error = getQuoteError {
      throw error
    }
    return getQuoteReturnValue ?? LifiQuoteResponse.stub()
  }

  func getStatus(request: LifiStatusRequest) async throws -> LifiStatusResponse {
    getStatusCalls += 1
    getStatusRequestParam = request
    if let error = getStatusError {
      throw error
    }
    return getStatusReturnValue ?? LifiStatusResponse.stub()
  }

  func getRouteStep(request: LifiStepTransactionRequest) async throws -> LifiStepTransactionResponse {
    getRouteStepCalls += 1
    getRouteStepRequestParam = request
    if let error = getRouteStepError {
      throw error
    }
    return getRouteStepReturnValue ?? LifiStepTransactionResponse.stub()
  }

  func tradeAsset(params: LifiTradeAssetParams) async throws -> LifiTradeAssetResult {
    tradeAssetCalls += 1
    tradeAssetParamsParam = params
    if let error = tradeAssetError {
      throw error
    }
    return tradeAssetReturnValue ?? LifiTradeAssetResult.stub()
  }

  func pollStatus(
    request: LifiStatusRequest,
    onUpdate: ((LifiStatusRawResponse) -> Bool)?,
    options _: LifiPollStatusOptions
  ) async throws -> LifiStatusRawResponse {
    pollStatusCalls += 1
    pollStatusRequestParam = request
    if let error = pollStatusError {
      throw error
    }
    let result = pollStatusReturnValue ?? LifiStatusRawResponse.stub()
    // Mirror the real Lifi.pollStatus contract: only invoke onUpdate for non-terminal statuses,
    // and throw on a FAILED terminal state instead of returning it.
    switch result.status {
    case .done:
      return result
    case .failed:
      let detail = result.substatusMessage ?? result.substatus?.rawValue ?? "LiFi transfer FAILED"
      throw LifiTradeAssetError.lifiTransferFailed(detail)
    default:
      _ = onUpdate?(result)
      return result
    }
  }

  // MARK: - Helper Methods

  /// Resets all call counters and captured parameters
  func reset() {
    getRoutesCalls = 0
    getQuoteCalls = 0
    getStatusCalls = 0
    getRouteStepCalls = 0
    tradeAssetCalls = 0
    pollStatusCalls = 0

    getRoutesRequestParam = nil
    getQuoteRequestParam = nil
    getStatusRequestParam = nil
    getRouteStepRequestParam = nil
    tradeAssetParamsParam = nil
    pollStatusRequestParam = nil

    getRoutesReturnValue = nil
    getQuoteReturnValue = nil
    getStatusReturnValue = nil
    getRouteStepReturnValue = nil
    tradeAssetReturnValue = nil
    pollStatusReturnValue = nil

    getRoutesError = nil
    getQuoteError = nil
    getStatusError = nil
    getRouteStepError = nil
    tradeAssetError = nil
    pollStatusError = nil
  }
}
