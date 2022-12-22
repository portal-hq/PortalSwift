//
//  MockICloudStorage.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public class MockICloudStorage: ICloudStorage {
  public override func read(completion: @escaping (Result<String>) -> Void) -> Void {
    completion(Result(data: mockBackupShare))
  }

  public override func write(privateKey: String, completion: @escaping (Result<Bool>) -> Void) -> Void {
    completion(Result(data: true))
  }

  public override func delete(completion: @escaping (Result<Bool>) -> Void) -> Void {
    completion(Result(data: true))
  }

  public override func getAvailability() -> String {
    return ICloudStatus.available.rawValue
  }
}
