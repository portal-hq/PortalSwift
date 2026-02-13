//
//  EvmAccountType.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Errors specific to the EvmAccountType integration.
public enum EvmAccountTypeError: LocalizedError, Equatable {
  case portalNotInitialized
  case unsupportedChainNamespace(String)
  case invalidAccountType(String)
  case invalidSignatureResponse
  case invalidTransactionResponse

  public var errorDescription: String? {
    switch self {
    case .portalNotInitialized:
      return "Portal instance is not available for signing or sending transaction."
    case .unsupportedChainNamespace(let chainId):
      return "Chain must use eip155 namespace. Got: \(chainId)"
    case .invalidAccountType(let status):
      return "Account type must be EIP_155_EOA to upgrade. Current status: \(status)"
    case .invalidSignatureResponse:
      return "Invalid signature response from rawSign."
    case .invalidTransactionResponse:
      return "Transaction hash is missing from buildAuthorizationTransaction response."
    }
  }
}

/// Minimal protocol for portal capabilities required by EvmAccountType (rawSign and request).
/// Portal conforms to this protocol; tests can use a small mock.
public protocol EvmAccountTypePortalDependency: AnyObject {
  func rawSign(message: String, chainId: String, signatureApprovalMemo: String?) async throws -> PortalProviderResult
  func request(chainId: String, method: PortalRequestMethod, params: [Any], options: RequestOptions?) async throws -> PortalProviderResult
}

/// Protocol defining the interface for EVM Account Type functionality.
public protocol EvmAccountTypeProtocol {
  /// Retrieves the account type for the client's wallet on the given chain.
  /// - Parameter chainId: CAIP-2 chain ID (e.g., "eip155:11155111")
  /// - Returns: Response containing account type status and metadata
  func getStatus(chainId: String) async throws -> EvmAccountTypeResponse

  /// Upgrades an EIP-155 EOA account to EIP-7702 on the given chain.
  /// - Parameter chainId: CAIP-2 chain ID (e.g., "eip155:11155111")
  /// - Returns: The transaction hash of the submitted upgrade transaction
  /// - Throws: `EvmAccountTypeError` or network/signing errors
  func upgradeTo7702(chainId: String) async throws -> String
}

/// EvmAccountType provider implementation.
public class EvmAccountType: EvmAccountTypeProtocol {
  private let api: PortalEvmAccountTypeApiProtocol
  private weak var portal: EvmAccountTypePortalDependency?

  /// Create an instance of EvmAccountType.
  /// - Parameters:
  ///   - api: The PortalEvmAccountTypeApi instance for API calls.
  ///   - portal: The portal (or mock) providing rawSign and request (can be nil in tests).
  public init(api: PortalEvmAccountTypeApiProtocol, portal: EvmAccountTypePortalDependency?) {
    self.api = api
    self.portal = portal
  }

  /// Retrieves the account type for the client's wallet on the given chain.
  public func getStatus(chainId: String) async throws -> EvmAccountTypeResponse {
    return try await api.getStatus(chainId: chainId)
  }

  /// Upgrades an EIP-155 EOA account to EIP-7702.
  ///
  /// Steps: validate eip155 namespace → getStatus → require EIP_155_EOA → build authorization list →
  /// raw sign hash (without 0x) → build authorization transaction (subsidized) → return tx hash.
  public func upgradeTo7702(chainId: String) async throws -> String {
    // 1. Validate chain namespace is eip155
    let blockchain = try PortalBlockchain(fromChainId: chainId)
    guard blockchain.namespace == .eip155 else {
      throw EvmAccountTypeError.unsupportedChainNamespace(chainId)
    }

    // 2. Get status and require EIP_155_EOA
    let statusResponse = try await getStatus(chainId: chainId)
    guard statusResponse.data.status == "EIP_155_EOA" else {
      throw EvmAccountTypeError.invalidAccountType(statusResponse.data.status)
    }

    guard let portal = portal else {
      throw EvmAccountTypeError.portalNotInitialized
    }

    // 3. Build authorization list and get hash
    let authListResponse = try await api.buildAuthorizationList(chainId: chainId)
    let hash = authListResponse.data.hash
    let messageToSign = hash.hasPrefix("0x") ? String(hash.dropFirst(2)) : hash

    // 4. Raw sign the hash
    let signResult = try await portal.rawSign(message: messageToSign, chainId: chainId, signatureApprovalMemo: nil)
    guard let signature = signResult.result as? String else {
      throw EvmAccountTypeError.invalidSignatureResponse
    }
    let signatureWithoutPrefix = signature.hasPrefix("0x") ? String(signature.dropFirst(2)) : signature

    // 5. Build authorization transaction
    let buildTxResponse = try await api.buildAuthorizationTransaction(chainId: chainId, signature: signatureWithoutPrefix, subsidize: true)
    let transaction = buildTxResponse.data.transaction
    guard let txHash = buildTxResponse.data.transactionHash else {
      throw EvmAccountTypeError.invalidTransactionResponse
    }
    return txHash

    // 6. Convert Eip7702Transaction to params and send via eth_sendTransaction
//    let txParams = transactionToParams(transaction)
//    let requestResult = try await portal.request(
//      chainId: chainId,
//      method: .eth_sendTransaction,
//      params: [txParams],
//      options: nil
//    )
//    guard let txHash = requestResult.result as? String else {
//      throw EvmAccountTypeError.invalidTransactionResponse
//    }
//    return txHash
  }

  /// Converts Eip7702Transaction to a dictionary suitable for eth_sendTransaction params.
  private func transactionToParams(_ tx: Eip7702Transaction) -> [String: Any] {
    var params: [String: Any] = [
      "from": tx.from,
      "to": tx.to
    ]
    if let type = tx.type {
      params["type"] = type
    }
    if let value = tx.value {
      params["value"] = value
    }
    if let data = tx.data {
      params["data"] = data
    }
    if let nonce = tx.nonce {
      params["nonce"] = nonce
    }
    if let chainId = tx.chainId {
      params["chainId"] = chainId
    }
    if let list = tx.authorizationList, !list.isEmpty {
      params["authorizationList"] = list.map { item in
        [
          "address": item.address,
          "chainId": item.chainId,
          "nonce": item.nonce,
          "r": item.r,
          "s": item.s,
          "yParity": item.yParity
        ] as [String: String]
      }
    }
    if let gasLimit = tx.gasLimit {
      params["gasLimit"] = gasLimit
    }
    if let maxFeePerGas = tx.maxFeePerGas {
      params["maxFeePerGas"] = maxFeePerGas
    }
    if let maxPriorityFeePerGas = tx.maxPriorityFeePerGas {
      params["maxPriorityFeePerGas"] = maxPriorityFeePerGas
    }
    return params
  }
}
