//
//  Lifi.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 23/11/2025.
//

import Foundation

/// Protocol defining the interface for Lifi trading provider functionality.
public protocol LifiProtocol {
  func getRoutes(request: LifiRoutesRequest) async throws -> LifiRoutesResponse
  func getQuote(request: LifiQuoteRequest) async throws -> LifiQuoteResponse
  func getStatus(request: LifiStatusRequest) async throws -> LifiStatusResponse
  func getRouteStep(request: LifiStepTransactionRequest) async throws -> LifiStepTransactionResponse
}

/// Lifi provider implementation for trading functionality.
public class Lifi: LifiProtocol {
  private let api: PortalSwapLifiApiProtocol

  /// Create an instance of Lifi.
  /// - Parameter api: The PortalSwapLifiApi instance to use for trading operations.
  public init(api: PortalSwapLifiApiProtocol) {
    self.api = api
  }

  /// Retrieves routes from the Lifi integration.
  public func getRoutes(request: LifiRoutesRequest) async throws -> LifiRoutesResponse {
    return try await api.getRoutes(request: request)
  }

  /// Retrieves a quote from the Lifi integration.
  public func getQuote(request: LifiQuoteRequest) async throws -> LifiQuoteResponse {
    return try await api.getQuote(request: request)
  }

  /// Retrieves the status of a transaction from the Lifi integration.
  public func getStatus(request: LifiStatusRequest) async throws -> LifiStatusResponse {
    return try await api.getStatus(request: request)
  }

  /// Retrieves an unsigned transaction from the Lifi integration that has yet to be signed/submitted.
  public func getRouteStep(request: LifiStepTransactionRequest) async throws -> LifiStepTransactionResponse {
    return try await api.getRouteStep(request: request)
  }
}
