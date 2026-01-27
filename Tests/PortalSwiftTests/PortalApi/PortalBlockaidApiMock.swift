//
//  PortalBlockaidApiMock.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import Foundation
@testable import PortalSwift

final class PortalBlockaidApiMock: PortalBlockaidApiProtocol {

  var scanEVMTxReturnValue: BlockaidScanEVMResponse?
  var scanEVMTxError: Error?
  var scanEVMTxCallCount = 0
  var scanEVMTxRequest: BlockaidScanEVMRequest?

  func scanEVMTx(request: BlockaidScanEVMRequest) async throws -> BlockaidScanEVMResponse {
    scanEVMTxCallCount += 1
    scanEVMTxRequest = request
    if let error = scanEVMTxError {
      throw error
    }
    return scanEVMTxReturnValue ?? BlockaidScanEVMResponse(data: nil, error: nil)
  }

  var scanSolanaTxReturnValue: BlockaidScanSolanaResponse?
  var scanSolanaTxError: Error?
  var scanSolanaTxCallCount = 0
  var scanSolanaTxRequest: BlockaidScanSolanaRequest?

  func scanSolanaTx(request: BlockaidScanSolanaRequest) async throws -> BlockaidScanSolanaResponse {
    scanSolanaTxCallCount += 1
    scanSolanaTxRequest = request
    if let error = scanSolanaTxError {
      throw error
    }
    return scanSolanaTxReturnValue ?? BlockaidScanSolanaResponse(data: nil, error: nil)
  }

  var scanAddressReturnValue: BlockaidScanAddressResponse?
  var scanAddressError: Error?
  var scanAddressCallCount = 0
  var scanAddressRequest: BlockaidScanAddressRequest?

  func scanAddress(request: BlockaidScanAddressRequest) async throws -> BlockaidScanAddressResponse {
    scanAddressCallCount += 1
    scanAddressRequest = request
    if let error = scanAddressError {
      throw error
    }
    return scanAddressReturnValue ?? BlockaidScanAddressResponse(data: nil, error: nil)
  }

  var scanTokensReturnValue: BlockaidScanTokensResponse?
  var scanTokensError: Error?
  var scanTokensCallCount = 0
  var scanTokensRequest: BlockaidScanTokensRequest?

  func scanTokens(request: BlockaidScanTokensRequest) async throws -> BlockaidScanTokensResponse {
    scanTokensCallCount += 1
    scanTokensRequest = request
    if let error = scanTokensError {
      throw error
    }
    return scanTokensReturnValue ?? BlockaidScanTokensResponse(data: nil, error: nil)
  }

  var scanURLReturnValue: BlockaidScanURLResponse?
  var scanURLError: Error?
  var scanURLCallCount = 0
  var scanURLRequest: BlockaidScanURLRequest?

  func scanURL(request: BlockaidScanURLRequest) async throws -> BlockaidScanURLResponse {
    scanURLCallCount += 1
    scanURLRequest = request
    if let error = scanURLError {
      throw error
    }
    return scanURLReturnValue ?? BlockaidScanURLResponse(data: nil, error: nil)
  }
}
