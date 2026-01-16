//
//  PortalHypernativeApiMock.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import Foundation
@testable import PortalSwift

final class PortalHypernativeApiMock: PortalHypernativeApiProtocol {
  
  // MARK: - Configurable Return Values
  
  var scanEVMTxReturnValue: ScanEVMResponse?
  var scanEip712TxReturnValue: ScanEip712Response?
  var scanSolanaTxReturnValue: ScanSolanaResponse?
  var scanAddressesReturnValue: ScanAddressesResponse?
  var scanNftsReturnValue: ScanNftsResponse?
  var scanTokensReturnValue: ScanTokensResponse?
  var scanURLReturnValue: ScanUrlResponse?
  
  // MARK: - Error Simulation
  
  var scanEVMTxError: Error?
  var scanEip712TxError: Error?
  var scanSolanaTxError: Error?
  var scanAddressesError: Error?
  var scanNftsError: Error?
  var scanTokensError: Error?
  var scanURLError: Error?
  
  // MARK: - Call Tracking
  
  var scanEVMTxCallCount = 0
  var scanEip712TxCallCount = 0
  var scanSolanaTxCallCount = 0
  var scanAddressesCallCount = 0
  var scanNftsCallCount = 0
  var scanTokensCallCount = 0
  var scanURLCallCount = 0
  
  // MARK: - Request Capture
  
  var lastScanEVMRequest: ScanEVMRequest?
  var lastScanEip712Request: ScanEip712Request?
  var lastScanSolanaRequest: ScanSolanaRequest?
  var lastScanAddressesRequest: ScanAddressesRequest?
  var lastScanNftsRequest: ScanNftsRequest?
  var lastScanTokensRequest: ScanTokensRequest?
  var lastScanUrlRequest: ScanUrlRequest?
  
  // MARK: - Protocol Implementation
  
  func scanEVMTx(request: ScanEVMRequest) async throws -> ScanEVMResponse {
    scanEVMTxCallCount += 1
    lastScanEVMRequest = request
    if let error = scanEVMTxError {
      throw error
    }
    return scanEVMTxReturnValue ?? ScanEVMResponse(data: nil, error: nil)
  }
  
  func scanEip712Tx(request: ScanEip712Request) async throws -> ScanEip712Response {
    scanEip712TxCallCount += 1
    lastScanEip712Request = request
    if let error = scanEip712TxError {
      throw error
    }
    return scanEip712TxReturnValue ?? ScanEip712Response(data: nil, error: nil)
  }
  
  func scanSolanaTx(request: ScanSolanaRequest) async throws -> ScanSolanaResponse {
    scanSolanaTxCallCount += 1
    lastScanSolanaRequest = request
    if let error = scanSolanaTxError {
      throw error
    }
    return scanSolanaTxReturnValue ?? ScanSolanaResponse(data: nil, error: nil)
  }
  
  func scanAddresses(request: ScanAddressesRequest) async throws -> ScanAddressesResponse {
    scanAddressesCallCount += 1
    lastScanAddressesRequest = request
    if let error = scanAddressesError {
      throw error
    }
    return scanAddressesReturnValue ?? ScanAddressesResponse(data: nil, error: nil)
  }
  
  func scanNfts(request: ScanNftsRequest) async throws -> ScanNftsResponse {
    scanNftsCallCount += 1
    lastScanNftsRequest = request
    if let error = scanNftsError {
      throw error
    }
    return scanNftsReturnValue ?? ScanNftsResponse(data: nil, error: nil)
  }
  
  func scanTokens(request: ScanTokensRequest) async throws -> ScanTokensResponse {
    scanTokensCallCount += 1
    lastScanTokensRequest = request
    if let error = scanTokensError {
      throw error
    }
    return scanTokensReturnValue ?? ScanTokensResponse(data: nil, error: nil)
  }
  
  func scanURL(request: ScanUrlRequest) async throws -> ScanUrlResponse {
    scanURLCallCount += 1
    lastScanUrlRequest = request
    if let error = scanURLError {
      throw error
    }
    return scanURLReturnValue ?? ScanUrlResponse(data: nil, error: nil)
  }
  
  // MARK: - Reset
  
  func reset() {
    scanEVMTxCallCount = 0
    scanEip712TxCallCount = 0
    scanSolanaTxCallCount = 0
    scanAddressesCallCount = 0
    scanNftsCallCount = 0
    scanTokensCallCount = 0
    scanURLCallCount = 0
    
    lastScanEVMRequest = nil
    lastScanEip712Request = nil
    lastScanSolanaRequest = nil
    lastScanAddressesRequest = nil
    lastScanNftsRequest = nil
    lastScanTokensRequest = nil
    lastScanUrlRequest = nil
    
    scanEVMTxReturnValue = nil
    scanEip712TxReturnValue = nil
    scanSolanaTxReturnValue = nil
    scanAddressesReturnValue = nil
    scanNftsReturnValue = nil
    scanTokensReturnValue = nil
    scanURLReturnValue = nil
    
    scanEVMTxError = nil
    scanEip712TxError = nil
    scanSolanaTxError = nil
    scanAddressesError = nil
    scanNftsError = nil
    scanTokensError = nil
    scanURLError = nil
  }
}
