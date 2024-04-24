//
//  PortalRpcError.swift
//  PortalSwift
//
//  Created by Blake Williams on 3/8/23.
//

import Foundation

public class PortalRpcError: LocalizedError, CustomStringConvertible {
  public var code: Int
  public var message: String

  init(_ error: PortalProviderRpcResponseError) {
    self.code = error.code
    self.message = error.message
  }

  public var errorDescription: String {
    return "PortalRpcError -code: \(self.code) -message: \(self.message)"
  }

  public var description: String {
    return self.errorDescription
  }
}
