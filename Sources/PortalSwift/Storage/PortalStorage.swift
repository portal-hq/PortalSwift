//
//  Storage.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public enum StorageError: Error {
  case mustExtendStorageClass
}

/// Responsible for CRUD actions for items in the specified storage.
open class Storage {
  public init() {}
  /// Deletes an item in storage.
  /// - Parameter completion: Resolves as a Result<Bool>.
  /// - Returns: Void
  @available(*, deprecated, renamed: "delete", message: "Please use the async/await implementation of delete().")
  open func delete(completion: @escaping (Result<Bool>) -> Void) {
    completion(Result(error: StorageError.mustExtendStorageClass))
  }

  /// Reads an item from storage.
  /// - Parameter completion: Resolves as a Result<String>, which includes the value from storage for the specified key.
  /// - Returns: Void
  @available(*, deprecated, renamed: "read", message: "Please use the async/await implementation of read().")
  open func read(completion: @escaping (Result<String>) -> Void) {
    completion(Result(error: StorageError.mustExtendStorageClass))
  }

  /// Writes an item to storage.
  /// - Parameter completion: Resolves as a Result<Bool>.
  /// - Returns: Void
  open func write(privateKey _: String, completion: @escaping (Result<Bool>) -> Void) {
    completion(Result(error: StorageError.mustExtendStorageClass))
  }
}

public protocol PortalStorage {
  func delete() async throws -> Bool
  func read() async throws -> String
  func validateOperations() async throws -> Bool
  func write(_ value: String) async throws -> Bool
}