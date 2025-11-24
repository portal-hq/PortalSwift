//
//  Lifi.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 23/11/2025.
//

import Foundation

/// Protocol defining the interface for Lifi Swap provider functionality.
public protocol LifiProtocol {
  func getRoutes(request: LifiRoutesRequest) async throws -> LifiRoutesResponse
  func getQuote(request: LifiQuoteRequest) async throws -> LifiQuoteResponse
  func getStatus(request: LifiStatusRequest) async throws -> LifiStatusResponse
  func stepTransaction(request: LifiStepTransactionRequest) async throws -> LifiStepTransactionResponse
}

/// Lifi provider implementation for swap functionality.
public class Lifi: LifiProtocol {
  private let api: PortalSwapLifiApiProtocol

  /// Create an instance of Lifi.
  /// - Parameter api: The PortalSwapLifiApi instance to use for swap operations.
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

  /// Submits step transaction details to the Lifi integration.
  public func stepTransaction(request: LifiStepTransactionRequest) async throws -> LifiStepTransactionResponse {
    return try await api.stepTransaction(request: request)
  }
}
