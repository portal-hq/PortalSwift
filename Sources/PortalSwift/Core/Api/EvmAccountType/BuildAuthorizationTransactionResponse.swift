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
}

public struct BuildAuthorizationTransactionData: Codable {
  public let transaction: Eip7702Transaction
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
}

public struct AuthorizationListItem: Codable {
  public let address: String
  public let chainId: String
  public let nonce: String
  public let r: String
  public let s: String
  public let yParity: String
}

public struct BuildAuthorizationTransactionMetadata: Codable {
  public let authorization: AuthorizationDetail
  public let chainId: String
  public let hash: String?
  public let signature: AuthorizationSignature?
}

public struct AuthorizationSignature: Codable {
  public let r: String
  public let s: String
  public let yParity: String
}
