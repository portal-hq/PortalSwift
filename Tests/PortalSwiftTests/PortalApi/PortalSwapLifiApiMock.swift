//
//  PortalSwapLifiApiMock.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 23/11/2025.
//

import Foundation
@testable import PortalSwift

final class PortalSwapLifiApiMock: PortalSwapLifiApiProtocol {
  // Configurable return values
  var getRoutesReturnValue: LifiRoutesResponse?
  var getQuoteReturnValue: LifiQuoteResponse?
  var getStatusReturnValue: LifiStatusResponse?
  var getRouteStepReturnValue: LifiStepTransactionResponse?

  // Call counters
  var getRoutesCalls = 0
  var getQuoteCalls = 0
  var getStatusCalls = 0
  var getRouteStepCalls = 0

  func getRoutes(request _: LifiRoutesRequest) async throws -> LifiRoutesResponse {
    getRoutesCalls += 1
    return getRoutesReturnValue ?? LifiRoutesResponse(data: nil, error: nil)
  }

  func getQuote(request _: LifiQuoteRequest) async throws -> LifiQuoteResponse {
    getQuoteCalls += 1
    return getQuoteReturnValue ?? LifiQuoteResponse(data: nil, error: nil)
  }

  func getStatus(request _: LifiStatusRequest) async throws -> LifiStatusResponse {
    getStatusCalls += 1
    return getStatusReturnValue ?? LifiStatusResponse(data: nil, error: nil)
  }

  func getRouteStep(request _: LifiStepTransactionRequest) async throws -> LifiStepTransactionResponse {
    getRouteStepCalls += 1
    return getRouteStepReturnValue ?? LifiStepTransactionResponse(data: nil, error: nil)
  }
}
