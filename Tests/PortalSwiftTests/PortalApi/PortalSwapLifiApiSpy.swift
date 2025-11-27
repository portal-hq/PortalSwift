//
//  PortalSwapLifiApiSpy.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 23/11/2025.
//

import Foundation
@testable import PortalSwift

final class PortalSwapLifiApiSpy: PortalSwapLifiApiProtocol {
  // MARK: - getRoutes

  var getRoutesCallsCount = 0
  var getRoutesRequestParam: LifiRoutesRequest?
  var getRoutesReturnValue: LifiRoutesResponse = LifiRoutesResponse(data: nil, error: nil)
  func getRoutes(request: LifiRoutesRequest) async throws -> LifiRoutesResponse {
    getRoutesCallsCount += 1
    getRoutesRequestParam = request
    return getRoutesReturnValue
  }

  // MARK: - getQuote

  var getQuoteCallsCount = 0
  var getQuoteRequestParam: LifiQuoteRequest?
  var getQuoteReturnValue: LifiQuoteResponse = LifiQuoteResponse(data: nil, error: nil)
  func getQuote(request: LifiQuoteRequest) async throws -> LifiQuoteResponse {
    getQuoteCallsCount += 1
    getQuoteRequestParam = request
    return getQuoteReturnValue
  }

  // MARK: - getStatus

  var getStatusCallsCount = 0
  var getStatusRequestParam: LifiStatusRequest?
  var getStatusReturnValue: LifiStatusResponse = LifiStatusResponse(data: nil, error: nil)
  func getStatus(request: LifiStatusRequest) async throws -> LifiStatusResponse {
    getStatusCallsCount += 1
    getStatusRequestParam = request
    return getStatusReturnValue
  }

  // MARK: - getRouteStep

  var getRouteStepCallsCount = 0
  var getRouteStepRequestParam: LifiStepTransactionRequest?
  var getRouteStepReturnValue: LifiStepTransactionResponse = LifiStepTransactionResponse(data: nil, error: nil)
  func getRouteStep(request: LifiStepTransactionRequest) async throws -> LifiStepTransactionResponse {
    getRouteStepCallsCount += 1
    getRouteStepRequestParam = request
    return getRouteStepReturnValue
  }
}

