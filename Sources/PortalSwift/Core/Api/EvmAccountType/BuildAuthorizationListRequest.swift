//
//  BuildAuthorizationListRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

public struct BuildAuthorizationListRequest: Codable {
  public let subsidize: Bool?

  public init(subsidize: Bool? = nil) {
    self.subsidize = subsidize
  }
}
