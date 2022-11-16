//
//  Storage.swift
//  FBSnapshotTestCase
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

private enum StorageError: Error {
  case mustExtendStorageClass
}

public class Storage {
  public func delete() throws -> Bool {
    throw StorageError.mustExtendStorageClass
  }

  public func read() throws -> String {
    throw StorageError.mustExtendStorageClass
  }

  public func write(privateKey: String) throws -> Bool {
    throw StorageError.mustExtendStorageClass
  }
}
