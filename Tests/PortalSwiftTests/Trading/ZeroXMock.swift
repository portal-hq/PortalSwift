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
  var tradeAssetReturnValue: ZeroXTradeAssetResult?

  // MARK: - Error simulation

  var getSourcesError: Error?
  var getQuoteError: Error?
  var getPriceError: Error?
  var tradeAssetError: Error?

  // MARK: - Call counters

  var getSourcesCalls = 0
  var getQuoteCalls = 0
  var getPriceCalls = 0
  var tradeAssetCalls = 0

  // MARK: - Call parameters

  var getSourcesChainIdParam: String?
  var getSourcesZeroXApiKeyParam: String?
  var getQuoteRequestParam: ZeroXQuoteRequest?
  var getQuoteZeroXApiKeyParam: String?
  var getPriceRequestParam: ZeroXPriceRequest?
  var getPriceZeroXApiKeyParam: String?
  var tradeAssetParamsParam: ZeroXTradeAssetParams?

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

  func tradeAsset(
    params: ZeroXTradeAssetParams,
    onProgress: ((ZeroXTradeAssetProgressStatus, ZeroXTradeAssetProgressData) -> Void)?
  ) async throws -> ZeroXTradeAssetResult {
    tradeAssetCalls += 1
    tradeAssetParamsParam = params
    if let error = tradeAssetError {
      onProgress?(.failed, ZeroXTradeAssetProgressData(errorMessage: error.localizedDescription))
      throw error
    }
    // Resolve the result first so the reported hash always matches what we return.
    let result = tradeAssetReturnValue ?? ZeroXTradeAssetResult(hashes: ["0xmockhash"])
    onProgress?(.confirmed, ZeroXTradeAssetProgressData(txHash: result.hashes.first))
    return result
  }

  // MARK: - Helper Methods

  /// Resets all call counters and captured parameters
  func reset() {
    getSourcesCalls = 0
    getQuoteCalls = 0
    getPriceCalls = 0
    tradeAssetCalls = 0

    getSourcesChainIdParam = nil
    getSourcesZeroXApiKeyParam = nil
    getQuoteRequestParam = nil
    getQuoteZeroXApiKeyParam = nil
    getPriceRequestParam = nil
    getPriceZeroXApiKeyParam = nil
    tradeAssetParamsParam = nil

    getSourcesReturnValue = nil
    getQuoteReturnValue = nil
    getPriceReturnValue = nil
    tradeAssetReturnValue = nil

    getSourcesError = nil
    getQuoteError = nil
    getPriceError = nil
    tradeAssetError = nil
  }
}
