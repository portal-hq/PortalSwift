//
//  PortalMpcError.swift
//  PortalSwift
//
//  Created by Blake Williams on 3/8/23.
//

import Foundation

public class PortalMpcError: LocalizedError, CustomStringConvertible, Equatable {
  @available(*, deprecated, message: "Use `id` instead.")
  public var code: Int?
  public var id: String?
  public var message: String?

  init(_ error: PortalError) {
    self.code = error.code
    self.id = error.id
    self.message = error.message
  }

  public var errorDescription: String {
    return "PortalMpcError -id: \(self.id ?? "") -message: \(self.message ?? "")"
  }

  public var description: String {
    return self.errorDescription
  }

  public static func == (lhs: PortalMpcError, rhs: PortalMpcError) -> Bool {
    return lhs.code == rhs.code && lhs.message == rhs.message && lhs.id == rhs.id
  }
}
