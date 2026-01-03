//
//  ZeroXMock.swift
//  PortalSwift
//
//  Created by Portal Labs
//

import Foundation
@testable import PortalSwift

/// Mock implementation of ZeroXProtocol for testing purposes.
final class ZeroXMock: ZeroXProtocol {
  // MARK: - Configurable return values

  var getSourcesReturnValue: ZeroXSourcesResponse?
  var getQuoteReturnValue: ZeroXQuoteResponse?
  var getPriceReturnValue: ZeroXPriceResponse?

  // MARK: - Error simulation

  var getSourcesError: Error?
  var getQuoteError: Error?
  var getPriceError: Error?

  // MARK: - Call counters

  var getSourcesCalls = 0
  var getQuoteCalls = 0
  var getPriceCalls = 0

  // MARK: - Call parameters

  var getSourcesChainIdParam: String?
  var getSourcesZeroXApiKeyParam: String?
  var getQuoteRequestParam: ZeroXQuoteRequest?
  var getQuoteZeroXApiKeyParam: String?
  var getPriceRequestParam: ZeroXPriceRequest?
  var getPriceZeroXApiKeyParam: String?

  // MARK: - Protocol Implementation

  func getSources(chainId: String, zeroXApiKey: String?) async throws -> ZeroXSourcesResponse {
    getSourcesCalls += 1
    getSourcesChainIdParam = chainId
    getSourcesZeroXApiKeyParam = zeroXApiKey
    if let error = getSourcesError {
      throw error
    }
    return getSourcesReturnValue ?? ZeroXSourcesResponse.stub()
  }

  func getQuote(request: ZeroXQuoteRequest, zeroXApiKey: String?) async throws -> ZeroXQuoteResponse {
    getQuoteCalls += 1
    getQuoteRequestParam = request
    getQuoteZeroXApiKeyParam = zeroXApiKey
    if let error = getQuoteError {
      throw error
    }
    return getQuoteReturnValue ?? ZeroXQuoteResponse.stub()
  }

  func getPrice(request: ZeroXPriceRequest, zeroXApiKey: String?) async throws -> ZeroXPriceResponse {
    getPriceCalls += 1
    getPriceRequestParam = request
    getPriceZeroXApiKeyParam = zeroXApiKey
    if let error = getPriceError {
      throw error
    }
    return getPriceReturnValue ?? ZeroXPriceResponse.stub()
  }

  // MARK: - Helper Methods

  /// Resets all call counters and captured parameters
  func reset() {
    getSourcesCalls = 0
    getQuoteCalls = 0
    getPriceCalls = 0

    getSourcesChainIdParam = nil
    getSourcesZeroXApiKeyParam = nil
    getQuoteRequestParam = nil
    getQuoteZeroXApiKeyParam = nil
    getPriceRequestParam = nil
    getPriceZeroXApiKeyParam = nil

    getSourcesReturnValue = nil
    getQuoteReturnValue = nil
    getPriceReturnValue = nil

    getSourcesError = nil
    getQuoteError = nil
    getPriceError = nil
  }
}

