//
//  BuildAuthorizationTransactionResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

public struct BuildAuthorizationTransactionResponse: Codable {
  public let data: BuildAuthorizationTransactionData
  public let metadata: BuildAuthorizationTransactionMetadata?

  public init(data: BuildAuthorizationTransactionData, metadata: BuildAuthorizationTransactionMetadata? = nil) {
    self.data = data
    self.metadata = metadata
  }
}

public struct BuildAuthorizationTransactionData: Codable {
  public let transaction: Eip7702Transaction

  public init(transaction: Eip7702Transaction) {
    self.transaction = transaction
  }
}

public struct Eip7702Transaction: Codable {
  public let type: String?
  public let from: String
  public let to: String
  public let value: String?
  public let data: String?
  public let nonce: String?
  public let chainId: String?
  public let authorizationList: [AuthorizationListItem]?
  public let gasLimit: String?
  public let maxFeePerGas: String?
  public let maxPriorityFeePerGas: String?

  public init(
    type: String? = nil,
    from: String,
    to: String,
    value: String? = nil,
    data: String? = nil,
    nonce: String? = nil,
    chainId: String? = nil,
    authorizationList: [AuthorizationListItem]? = nil,
    gasLimit: String? = nil,
    maxFeePerGas: String? = nil,
    maxPriorityFeePerGas: String? = nil
  ) {
    self.type = type
    self.from = from
    self.to = to
    self.value = value
    self.data = data
    self.nonce = nonce
    self.chainId = chainId
    self.authorizationList = authorizationList
    self.gasLimit = gasLimit
    self.maxFeePerGas = maxFeePerGas
    self.maxPriorityFeePerGas = maxPriorityFeePerGas
  }
}

public struct AuthorizationListItem: Codable {
  public let address: String
  public let chainId: String
  public let nonce: String
  public let r: String
  public let s: String
  public let yParity: String

  public init(address: String, chainId: String, nonce: String, r: String, s: String, yParity: String) {
    self.address = address
    self.chainId = chainId
    self.nonce = nonce
    self.r = r
    self.s = s
    self.yParity = yParity
  }
}

public struct BuildAuthorizationTransactionMetadata: Codable {
  public let authorization: AuthorizationDetail
  public let chainId: String
  public let hash: String?
  public let signature: AuthorizationSignature?

  public init(authorization: AuthorizationDetail, chainId: String, hash: String? = nil, signature: AuthorizationSignature? = nil) {
    self.authorization = authorization
    self.chainId = chainId
    self.hash = hash
    self.signature = signature
  }
}

public struct AuthorizationSignature: Codable {
  public let r: String
  public let s: String
  public let yParity: String

  public init(r: String, s: String, yParity: String) {
    self.r = r
    self.s = s
    self.yParity = yParity
  }
}
