//
//  MockPortalMpc.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public class MockPortalMpc: PortalMpc {
  public override func backup(method: BackupMethods.RawValue, completion: @escaping (Result<String>) -> Void) -> Void {
    completion(Result(data: mockBackupShare))
  }

  public override func generate(completion: @escaping (Result<String>) -> Void) -> Void {
    completion(Result(data: mockAddress))
  }

  public override func recover(cipherText: String, method: BackupMethods.RawValue, completion: @escaping (Result<String>) -> Void) -> Void {
    completion(Result(data: mockBackupShare))
  }
}
