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

  // Thread-safe serial queue for synchronizing access to counters and parameters
  private let queue = DispatchQueue(label: "com.portal.PortalLifiTradingApiMock.queue")

  // Call counters (thread-safe via serial queue)
  private var _getRoutesCalls = 0
  private var _getQuoteCalls = 0
  private var _getStatusCalls = 0
  private var _getRouteStepCalls = 0

  var getRoutesCalls: Int {
    queue.sync { _getRoutesCalls }
  }

  var getQuoteCalls: Int {
    queue.sync { _getQuoteCalls }
  }

  var getStatusCalls: Int {
    queue.sync { _getStatusCalls }
  }

  var getRouteStepCalls: Int {
    queue.sync { _getRouteStepCalls }
  }

  // Call parameters (thread-safe via serial queue)
  private var _getRoutesRequestParam: LifiRoutesRequest?
  private var _getQuoteRequestParam: LifiQuoteRequest?
  private var _getStatusRequestParam: LifiStatusRequest?
  private var _getRouteStepRequestParam: LifiStepTransactionRequest?

  var getRoutesRequestParam: LifiRoutesRequest? {
    queue.sync { _getRoutesRequestParam }
  }

  var getQuoteRequestParam: LifiQuoteRequest? {
    queue.sync { _getQuoteRequestParam }
  }

  var getStatusRequestParam: LifiStatusRequest? {
    queue.sync { _getStatusRequestParam }
  }

  var getRouteStepRequestParam: LifiStepTransactionRequest? {
    queue.sync { _getRouteStepRequestParam }
  }

  func getRoutes(request: LifiRoutesRequest) async throws -> LifiRoutesResponse {
    queue.sync {
      _getRoutesCalls += 1
      _getRoutesRequestParam = request
    }
    if let error = getRoutesError {
      throw error
    }
    return getRoutesReturnValue ?? LifiRoutesResponse(data: nil, error: nil)
  }

  func getQuote(request: LifiQuoteRequest) async throws -> LifiQuoteResponse {
    queue.sync {
      _getQuoteCalls += 1
      _getQuoteRequestParam = request
    }
    if let error = getQuoteError {
      throw error
    }
    return getQuoteReturnValue ?? LifiQuoteResponse(data: nil, error: nil)
  }

  func getStatus(request: LifiStatusRequest) async throws -> LifiStatusResponse {
    queue.sync {
      _getStatusCalls += 1
      _getStatusRequestParam = request
    }
    if let error = getStatusError {
      throw error
    }
    return getStatusReturnValue ?? LifiStatusResponse(data: nil, error: nil)
  }

  func getRouteStep(request: LifiStepTransactionRequest) async throws -> LifiStepTransactionResponse {
    queue.sync {
      _getRouteStepCalls += 1
      _getRouteStepRequestParam = request
    }
    if let error = getRouteStepError {
      throw error
    }
    return getRouteStepReturnValue ?? LifiStepTransactionResponse(data: nil, error: nil)
  }

  /// Resets all call counters and captured parameters
  func reset() {
    queue.sync {
      _getRoutesCalls = 0
      _getQuoteCalls = 0
      _getStatusCalls = 0
      _getRouteStepCalls = 0

      _getRoutesRequestParam = nil
      _getQuoteRequestParam = nil
      _getStatusRequestParam = nil
      _getRouteStepRequestParam = nil
    }

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
