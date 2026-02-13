//
//  BuildAuthorizationListResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

public struct BuildAuthorizationListResponse: Codable {
  public let data: BuildAuthorizationListData
  public let metadata: BuildAuthorizationListMetadata

  public init(data: BuildAuthorizationListData, metadata: BuildAuthorizationListMetadata) {
    self.data = data
    self.metadata = metadata
  }
}

public struct BuildAuthorizationListData: Codable {
  public let hash: String

  public init(hash: String) {
    self.hash = hash
  }
}

public struct BuildAuthorizationListMetadata: Codable {
  public let authorization: AuthorizationDetail
  public let chainId: String

  public init(authorization: AuthorizationDetail, chainId: String) {
    self.authorization = authorization
    self.chainId = chainId
  }
}

public struct AuthorizationDetail: Codable {
  public let contractAddress: String
  public let chainId: String
  public let nonce: String

  public init(contractAddress: String, chainId: String, nonce: String) {
    self.contractAddress = contractAddress
    self.chainId = chainId
    self.nonce = nonce
  }
}
