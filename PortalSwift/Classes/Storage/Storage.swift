//
//  Storage.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

private enum StorageError: Error {
  case mustExtendStorageClass
}

/// Responsible for CRUD actions for items in the specified storage.
public class Storage {
  /// Deletes an item in storage.
  /// - Parameter completion: Resolves as a Result<Bool>.
  /// - Returns: Void
  public func delete(completion: @escaping (Result<Bool>) -> Void) -> Void {
    completion(Result(error: StorageError.mustExtendStorageClass))
  }

  /// Reads an item from storage.
  /// - Parameter completion: Resolves as a Result<String>, which includes the value from storage for the specified key.
  /// - Returns: Void
  public func read(completion: @escaping (Result<String>) -> Void) -> Void {
    completion(Result(error: StorageError.mustExtendStorageClass))
  }

  /// Writes an item to storage.
  /// - Parameter completion: Resolves as a Result<Bool>.
  /// - Returns: Void
  public func write(privateKey: String, completion: @escaping (Result<Bool>) -> Void) -> Void {
    completion(Result(error: StorageError.mustExtendStorageClass))
  }
}
