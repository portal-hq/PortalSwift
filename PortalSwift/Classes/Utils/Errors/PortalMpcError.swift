//
//  PortalMpcError.swift
//  PortalSwift
//
//  Created by Blake Williams on 3/8/23.
//

import Foundation

public class PortalMpcError: LocalizedError, CustomStringConvertible {
  public var code: Int
  public var message: String

  init(_ error: PortalError) {
    code = error.code
    message = error.message
  }

  public var errorDescription: String {
    return "PortalMpcError -code: \(code) -message: \(message)"
  }

  public var description: String {
    return errorDescription
  }
}
