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

  /// Optional sequence of `getStatus` outcomes consumed in order (one per call). When non-empty it
  /// takes precedence over `getStatusError`/`getStatusReturnValue`; when exhausted it falls back to
  /// them. Enables testing the transient-error-then-recover branch of the polling loop.
  var getStatusResultSequence: [Swift.Result<LifiStatusResponse, Error>] = []

  /// Optional sequence of `getRouteStep` outcomes consumed in order (one per call). When non-empty
  /// it takes precedence over `getRouteStepError`/`getRouteStepReturnValue`; when exhausted it falls
  /// back to them. Enables returning a distinct response per step in multi-step tests.
  var getRouteStepResultSequence: [Swift.Result<LifiStepTransactionResponse, Error>] = []

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
    let queued: Swift.Result<LifiStatusResponse, Error>? = queue.sync {
      _getStatusCalls += 1
      _getStatusRequestParam = request
      return getStatusResultSequence.isEmpty ? nil : getStatusResultSequence.removeFirst()
    }
    if let queued {
      switch queued {
      case let .success(response): return response
      case let .failure(error): throw error
      }
    }
    if let error = getStatusError {
      throw error
    }
    return getStatusReturnValue ?? LifiStatusResponse(data: nil, error: nil)
  }

  func getRouteStep(request: LifiStepTransactionRequest) async throws -> LifiStepTransactionResponse {
    let queued: Swift.Result<LifiStepTransactionResponse, Error>? = queue.sync {
      _getRouteStepCalls += 1
      _getRouteStepRequestParam = request
      return getRouteStepResultSequence.isEmpty ? nil : getRouteStepResultSequence.removeFirst()
    }
    if let queued {
      switch queued {
      case let .success(response): return response
      case let .failure(error): throw error
      }
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

    getStatusResultSequence = []
    getRouteStepResultSequence = []
  }
}
