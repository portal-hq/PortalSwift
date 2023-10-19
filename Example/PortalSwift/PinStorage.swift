//
//  PinStorage.swift
//  PortalSwift
//
//  Created by Rami Shahatit on 10/4/23.
//

import Foundation

/// Responsible for CRUD actions for items in the specified storage.
open class PinStorage {
  public init() {}
  /// Deletes an item in storage.
  /// - Parameter completion: Resolves as a Result<Bool>.
  /// - Returns: Void
  open func delete(completion: @escaping (Result<Bool>) -> Void) {
    completion(Result(error: StorageError.mustExtendStorageClass))
  }

  /// Reads an item from storage.
  /// - Parameter completion: Resolves as a Result<String>, which includes the value from storage for the specified key.
  /// - Returns: Void
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
