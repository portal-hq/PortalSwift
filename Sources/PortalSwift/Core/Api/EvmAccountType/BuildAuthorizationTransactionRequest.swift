//
//  BuildAuthorizationTransactionRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

public struct BuildAuthorizationTransactionRequest: Codable {
  public let signature: String

  public init(signature: String) {
    self.signature = signature
  }
}
