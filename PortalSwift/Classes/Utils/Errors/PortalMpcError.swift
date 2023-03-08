//
//  PortalMpcError.swift
//  PortalSwift
//
//  Created by Blake Williams on 3/8/23.
//

import Foundation

public class PortalMpcError: Error {
  public var code: Int
  public var message: String
  
  init (_ error: PortalError) {
    self.code = error.code
    self.message = error.message
  }
}
