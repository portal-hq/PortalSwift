//
//  Result.swift
//  PortalSwift
//
//  Created by Blake Williams on 11/16/22.
//

import Foundation

public struct Result<T: Codable> {
  public var data: T?
  public var error: Error?
  
  public init(data: T) {
    self.data = data
  }
  
  public init(error: Error) {
    self.error = error
  }
  
  public init(data: T, error: Error) {
    self.data = data
    self.error = error
  }
}
