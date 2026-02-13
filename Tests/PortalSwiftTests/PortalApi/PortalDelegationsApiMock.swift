//
//  PortalDelegationsApiMock.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import Foundation
@testable import PortalSwift

final class PortalDelegationsApiMock: PortalDelegationsApiProtocol {
  // MARK: - approve

  var approveReturnValue: ApproveDelegationResponse?
  var approveError: Error?
  var approveCallCount = 0
  var approveRequest: ApproveDelegationRequest?

  func approve(request: ApproveDelegationRequest) async throws -> ApproveDelegationResponse {
    approveCallCount += 1
    approveRequest = request
    if let error = approveError {
      throw error
    }
    return approveReturnValue ?? ApproveDelegationResponse(transactions: nil, encodedTransactions: nil, metadata: nil)
  }

  // MARK: - revoke

  var revokeReturnValue: RevokeDelegationResponse?
  var revokeError: Error?
  var revokeCallCount = 0
  var revokeRequest: RevokeDelegationRequest?

  func revoke(request: RevokeDelegationRequest) async throws -> RevokeDelegationResponse {
    revokeCallCount += 1
    revokeRequest = request
    if let error = revokeError {
      throw error
    }
    return revokeReturnValue ?? RevokeDelegationResponse(transactions: nil, encodedTransactions: nil, metadata: nil)
  }

  // MARK: - getStatus

  var getStatusReturnValue: DelegationStatusResponse?
  var getStatusError: Error?
  var getStatusCallCount = 0
  var getStatusRequest: GetDelegationStatusRequest?

  func getStatus(request: GetDelegationStatusRequest) async throws -> DelegationStatusResponse {
    getStatusCallCount += 1
    getStatusRequest = request
    if let error = getStatusError {
      throw error
    }
    return getStatusReturnValue ?? DelegationStatusResponse(
      chainId: "eip155:11155111",
      token: "USDC",
      tokenAddress: "0xtoken",
      tokenAccount: nil,
      balance: nil,
      balanceRaw: nil,
      delegations: []
    )
  }

  // MARK: - transferFrom

  var transferFromReturnValue: TransferFromResponse?
  var transferFromError: Error?
  var transferFromCallCount = 0
  var transferFromRequest: TransferFromRequest?

  func transferFrom(request: TransferFromRequest) async throws -> TransferFromResponse {
    transferFromCallCount += 1
    transferFromRequest = request
    if let error = transferFromError {
      throw error
    }
    return transferFromReturnValue ?? TransferFromResponse(
      transactions: nil,
      encodedTransactions: nil,
      metadata: TransferAsDelegateMetadata(
        amount: "1.0",
        amountRaw: "1000000",
        chainId: "eip155:11155111"
      )
    )
  }
}
