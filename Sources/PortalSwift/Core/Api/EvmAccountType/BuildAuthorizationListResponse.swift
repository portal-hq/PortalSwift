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
}

public struct BuildAuthorizationListData: Codable {
  public let hash: String
}

public struct BuildAuthorizationListMetadata: Codable {
  public let authorization: AuthorizationDetail
  public let chainId: String
}

public struct AuthorizationDetail: Codable {
  public let contractAddress: String
  public let chainId: String
  public let nonce: String
}
