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

public class Storage {
  public func delete(completion: @escaping (Result<Bool>) -> Void) -> Void {
    completion(Result(error: StorageError.mustExtendStorageClass))
  }

  public func read(completion: @escaping (Result<String>) -> Void) -> Void {
    completion(Result(error: StorageError.mustExtendStorageClass))
  }

  public func write(privateKey: String, completion: @escaping (Result<Bool>) -> Void) -> Void {
    completion(Result(error: StorageError.mustExtendStorageClass))
  }
}
