//
//  PortalZeroXTradingApiMock.swift
//  PortalSwift
//
//  Created by Portal Labs
//

import Foundation
@testable import PortalSwift

final class PortalZeroXTradingApiMock: PortalZeroXTradingApiProtocol {
  // Configurable return values
  var getSourcesReturnValue: ZeroXSourcesResponse?
  var getQuoteReturnValue: ZeroXQuoteResponse?
  var getPriceReturnValue: ZeroXPriceResponse?

  // Error simulation
  var getSourcesError: Error?
  var getQuoteError: Error?
  var getPriceError: Error?

  // Thread-safe serial queue for synchronizing access to counters and parameters
  private let queue = DispatchQueue(label: "com.portal.PortalZeroXTradingApiMock.queue")

  // Call counters (thread-safe via serial queue)
  private var _getSourcesCalls = 0
  private var _getQuoteCalls = 0
  private var _getPriceCalls = 0

  var getSourcesCalls: Int {
    queue.sync { _getSourcesCalls }
  }

  var getQuoteCalls: Int {
    queue.sync { _getQuoteCalls }
  }

  var getPriceCalls: Int {
    queue.sync { _getPriceCalls }
  }

  // Call parameters (thread-safe via serial queue)
  private var _getSourcesChainIdParam: String?
  private var _getSourcesZeroXApiKeyParam: String?
  private var _getQuoteRequestParam: ZeroXQuoteRequest?
  private var _getQuoteZeroXApiKeyParam: String?
  private var _getPriceRequestParam: ZeroXPriceRequest?
  private var _getPriceZeroXApiKeyParam: String?

  var getSourcesChainIdParam: String? {
    queue.sync { _getSourcesChainIdParam }
  }

  var getSourcesZeroXApiKeyParam: String? {
    queue.sync { _getSourcesZeroXApiKeyParam }
  }

  var getQuoteRequestParam: ZeroXQuoteRequest? {
    queue.sync { _getQuoteRequestParam }
  }

  var getQuoteZeroXApiKeyParam: String? {
    queue.sync { _getQuoteZeroXApiKeyParam }
  }

  var getPriceRequestParam: ZeroXPriceRequest? {
    queue.sync { _getPriceRequestParam }
  }

  var getPriceZeroXApiKeyParam: String? {
    queue.sync { _getPriceZeroXApiKeyParam }
  }

  func getSources(chainId: String, zeroXApiKey: String?) async throws -> ZeroXSourcesResponse {
    queue.sync {
      _getSourcesCalls += 1
      _getSourcesChainIdParam = chainId
      _getSourcesZeroXApiKeyParam = zeroXApiKey
    }
    if let error = getSourcesError {
      throw error
    }
    return getSourcesReturnValue ?? ZeroXSourcesResponse.stub()
  }

  func getQuote(request: ZeroXQuoteRequest, zeroXApiKey: String?) async throws -> ZeroXQuoteResponse {
    queue.sync {
      _getQuoteCalls += 1
      _getQuoteRequestParam = request
      _getQuoteZeroXApiKeyParam = zeroXApiKey
    }
    if let error = getQuoteError {
      throw error
    }
    return getQuoteReturnValue ?? ZeroXQuoteResponse.stub()
  }

  func getPrice(request: ZeroXPriceRequest, zeroXApiKey: String?) async throws -> ZeroXPriceResponse {
    queue.sync {
      _getPriceCalls += 1
      _getPriceRequestParam = request
      _getPriceZeroXApiKeyParam = zeroXApiKey
    }
    if let error = getPriceError {
      throw error
    }
    return getPriceReturnValue ?? ZeroXPriceResponse.stub()
  }

  /// Resets all call counters and captured parameters
  func reset() {
    queue.sync {
      _getSourcesCalls = 0
      _getQuoteCalls = 0
      _getPriceCalls = 0

      _getSourcesChainIdParam = nil
      _getSourcesZeroXApiKeyParam = nil
      _getQuoteRequestParam = nil
      _getQuoteZeroXApiKeyParam = nil
      _getPriceRequestParam = nil
      _getPriceZeroXApiKeyParam = nil
    }

    getSourcesReturnValue = nil
    getQuoteReturnValue = nil
    getPriceReturnValue = nil

    getSourcesError = nil
    getQuoteError = nil
    getPriceError = nil
  }
}
