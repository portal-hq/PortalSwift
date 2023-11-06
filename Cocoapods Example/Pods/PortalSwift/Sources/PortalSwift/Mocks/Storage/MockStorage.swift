//
//  MockStorage.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public class MockStorage: Storage {
  override public func delete(completion: @escaping (Result<Bool>) -> Void) {
    completion(Result(data: true))
  }

  override public func read(completion: @escaping (Result<String>) -> Void) {
    completion(Result(data: mockBackupShare))
  }

  override public func write(privateKey _: String, completion: @escaping (Result<Bool>) -> Void) {
    completion(Result(data: true))
  }
}
