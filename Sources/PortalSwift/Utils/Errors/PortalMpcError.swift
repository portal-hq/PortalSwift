//
//  PortalMpcError.swift
//  PortalSwift
//
//  Created by Blake Williams on 3/8/23.
//

import Foundation

public class PortalMpcError: LocalizedError, CustomStringConvertible, Equatable {
  public var code: Int
  public var message: String

  init(_ error: PortalError) {
    self.code = error.code
    self.message = error.message
  }

  public var errorDescription: String {
    return "PortalMpcError -code: \(self.code) -message: \(self.message)"
  }

  public var description: String {
    return self.errorDescription
  }

    public static func == (lhs: PortalMpcError, rhs: PortalMpcError) -> Bool {
        return lhs.code == rhs.code && lhs.message == rhs.message
    }
}
