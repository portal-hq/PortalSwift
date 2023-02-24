//
//  MockStorage.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public class MockStorage: Storage {
  public override func delete(completion: @escaping (Result<Bool>) -> Void) -> Void {
    completion(Result(data: true))
  }

  public override func read(completion: @escaping (Result<String>) -> Void) -> Void {
    completion(Result(data: mockBackupShare))
  }

  public override func write(privateKey: String, completion: @escaping (Result<Bool>) -> Void) -> Void {
    completion(Result(data: true))
  }
}
