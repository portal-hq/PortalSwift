//
//  BuildAuthorizationTransactionRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

public struct BuildAuthorizationTransactionRequest: Codable {
  public let signature: String
  public let subsidize: Bool?

  public init(signature: String, subsidize: Bool? = nil) {
    self.signature = signature
    self.subsidize = subsidize
  }
}
