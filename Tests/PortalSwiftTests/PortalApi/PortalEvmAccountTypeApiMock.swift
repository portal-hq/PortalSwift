//
//  PortalEvmAccountTypeApiMock.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import Foundation
@testable import PortalSwift

final class PortalEvmAccountTypeApiMock: PortalEvmAccountTypeApiProtocol {
  // MARK: - getStatus

  var getStatusReturnValue: EvmAccountTypeResponse?
  var getStatusError: Error?
  var getStatusCallCount = 0
  var getStatusChainId: String?

  func getStatus(chainId: String) async throws -> EvmAccountTypeResponse {
    getStatusCallCount += 1
    getStatusChainId = chainId
    if let error = getStatusError {
      throw error
    }
    return getStatusReturnValue ?? EvmAccountTypeResponse(
      data: EvmAccountTypeData(status: "EIP_155_EOA"),
      metadata: EvmAccountTypeMetadata(chainId: "eip155:11155111", eoaAddress: "0xeoa", smartContractAddress: nil)
    )
  }

  // MARK: - buildAuthorizationList

  var buildAuthorizationListReturnValue: BuildAuthorizationListResponse?
  var buildAuthorizationListError: Error?
  var buildAuthorizationListCallCount = 0
  var buildAuthorizationListChainId: String?

  func buildAuthorizationList(chainId: String) async throws -> BuildAuthorizationListResponse {
    buildAuthorizationListCallCount += 1
    buildAuthorizationListChainId = chainId
    if let error = buildAuthorizationListError {
      throw error
    }
    return buildAuthorizationListReturnValue ?? BuildAuthorizationListResponse(
      data: BuildAuthorizationListData(hash: "0xabc123"),
      metadata: BuildAuthorizationListMetadata(
        authorization: AuthorizationDetail(contractAddress: "0xcontract", chainId: "0x1", nonce: "0x0"),
        chainId: "eip155:11155111"
      )
    )
  }

  // MARK: - buildAuthorizationTransaction

  var buildAuthorizationTransactionReturnValue: BuildAuthorizationTransactionResponse?
  var buildAuthorizationTransactionError: Error?
  var buildAuthorizationTransactionCallCount = 0
  var buildAuthorizationTransactionChainId: String?
  var buildAuthorizationTransactionSignature: String?

  func buildAuthorizationTransaction(chainId: String, signature: String) async throws -> BuildAuthorizationTransactionResponse {
    buildAuthorizationTransactionCallCount += 1
    buildAuthorizationTransactionChainId = chainId
    buildAuthorizationTransactionSignature = signature
    if let error = buildAuthorizationTransactionError {
      throw error
    }
    return buildAuthorizationTransactionReturnValue ?? BuildAuthorizationTransactionResponse(
      data: BuildAuthorizationTransactionData(
        transaction: Eip7702Transaction(
          type: "eip7702",
          from: "0xfrom",
          to: "0xto",
          value: "0x0",
          data: "0x0",
          nonce: "0x0",
          chainId: "0x1",
          authorizationList: nil,
          gasLimit: nil,
          maxFeePerGas: nil,
          maxPriorityFeePerGas: nil
        )
      ),
      metadata: nil
    )
  }
}
