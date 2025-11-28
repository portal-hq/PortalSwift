//
//  PortalLifiTradingApiMock.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 23/11/2025.
//

import Foundation
@testable import PortalSwift

final class PortalLifiTradingApiMock: PortalLifiTradingApiProtocol {
  // Configurable return values
  var getRoutesReturnValue: LifiRoutesResponse?
  var getQuoteReturnValue: LifiQuoteResponse?
  var getStatusReturnValue: LifiStatusResponse?
  var getRouteStepReturnValue: LifiStepTransactionResponse?

  // Error simulation
  var getRoutesError: Error?
  var getQuoteError: Error?
  var getStatusError: Error?
  var getRouteStepError: Error?

  // Call counters
  var getRoutesCalls = 0
  var getQuoteCalls = 0
  var getStatusCalls = 0
  var getRouteStepCalls = 0

  // Call parameters
  var getRoutesRequestParam: LifiRoutesRequest?
  var getQuoteRequestParam: LifiQuoteRequest?
  var getStatusRequestParam: LifiStatusRequest?
  var getRouteStepRequestParam: LifiStepTransactionRequest?

  func getRoutes(request: LifiRoutesRequest) async throws -> LifiRoutesResponse {
    getRoutesCalls += 1
    getRoutesRequestParam = request
    if let error = getRoutesError {
      throw error
    }
    return getRoutesReturnValue ?? LifiRoutesResponse(data: nil, error: nil)
  }

  func getQuote(request: LifiQuoteRequest) async throws -> LifiQuoteResponse {
    getQuoteCalls += 1
    getQuoteRequestParam = request
    if let error = getQuoteError {
      throw error
    }
    return getQuoteReturnValue ?? LifiQuoteResponse(data: nil, error: nil)
  }

  func getStatus(request: LifiStatusRequest) async throws -> LifiStatusResponse {
    getStatusCalls += 1
    getStatusRequestParam = request
    if let error = getStatusError {
      throw error
    }
    return getStatusReturnValue ?? LifiStatusResponse(data: nil, error: nil)
  }

  func getRouteStep(request: LifiStepTransactionRequest) async throws -> LifiStepTransactionResponse {
    getRouteStepCalls += 1
    getRouteStepRequestParam = request
    if let error = getRouteStepError {
      throw error
    }
    return getRouteStepReturnValue ?? LifiStepTransactionResponse(data: nil, error: nil)
  }

  /// Resets all call counters and captured parameters
  func reset() {
    getRoutesCalls = 0
    getQuoteCalls = 0
    getStatusCalls = 0
    getRouteStepCalls = 0

    getRoutesRequestParam = nil
    getQuoteRequestParam = nil
    getStatusRequestParam = nil
    getRouteStepRequestParam = nil

    getRoutesReturnValue = nil
    getQuoteReturnValue = nil
    getStatusReturnValue = nil
    getRouteStepReturnValue = nil

    getRoutesError = nil
    getQuoteError = nil
    getStatusError = nil
    getRouteStepError = nil
  }
}
