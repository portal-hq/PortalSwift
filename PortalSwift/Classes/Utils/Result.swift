//
//  Result.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public struct Result<T> {
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
