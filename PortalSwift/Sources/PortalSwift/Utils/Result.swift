//
//  Result.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// A result from a completion handler.
public struct Result<T> {
  /// The optional data returned from the completion handler.
  public var data: T?

  /// An optional error.
  public var error: Error?

  /// A new result with the given data.
  public init(data: T) {
    self.data = data
  }

  /// A new result with the given error.
  public init(error: Error) {
    self.error = error
  }

  /// A new result with the given data and error.
  public init(data: T, error: Error) {
    self.data = data
    self.error = error
  }
}
