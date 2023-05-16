//
//  PortalStorage.swift
//  PortalSwift
//
//  Created by Blake Williams on 5/16/23.
//

import Foundation

public enum PortalBackupStorageError: Error {
  case mustImplementBackup
}

public class PortalStorage: Storage {
  override public init() {}
  
  /// Deletes an item in storage.
  /// - Parameter completion: Resolves as a Result<Bool>.
  /// - Returns: Void
  public override func delete(completion: @escaping (Result<Bool>) -> Void) -> Void {
    completion(Result(error: PortalBackupStorageError.mustImplementBackup))
  }

  /// Reads an item from storage.
  /// - Parameter completion: Resolves as a Result<String>, which includes the value from storage for the specified key.
  /// - Returns: Void
  public override func read(completion: @escaping (Result<String>) -> Void) -> Void {
    completion(Result(error: PortalBackupStorageError.mustImplementBackup))
  }

  /// Writes an item to storage.
  /// - Parameter completion: Resolves as a Result<Bool>.
  /// - Returns: Void
  public override func write(privateKey: String, completion: @escaping (Result<Bool>) -> Void) -> Void {
    completion(Result(error: PortalBackupStorageError.mustImplementBackup))
  }
}
