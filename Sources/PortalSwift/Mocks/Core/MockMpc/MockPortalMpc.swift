//
//  MockPortalMpc.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.

import Foundation

public class MockPortalMpc: PortalMpc {
  override public func backup(method _: BackupMethods.RawValue, backupConfigs _: BackupConfigs? = nil, completion: @escaping (Result<String>) -> Void, progress: ((MpcStatus) -> Void)? = nil) {
    completion(Result(data: mockBackupShare))
    progress?(MpcStatus(status: MpcStatuses.done, done: true))
  }

  override public func generate(completion: @escaping (Result<String>) -> Void, progress: ((MpcStatus) -> Void)? = nil) {
    completion(Result(data: mockAddress))
    progress?(MpcStatus(status: MpcStatuses.done, done: true))
  }

  override public func recover(cipherText _: String, method _: BackupMethods.RawValue, backupConfigs _: BackupConfigs? = nil, completion: @escaping (Result<String>) -> Void, progress: ((MpcStatus) -> Void)? = nil) {
    completion(Result(data: mockBackupShare))
    progress?(MpcStatus(status: MpcStatuses.done, done: true))
  }

  override public func ejectPrivateKey(clientBackupCiphertext _: String, method _: BackupMethods.RawValue, backupConfigs _: BackupConfigs? = nil, orgBackupShare _: String, completion: @escaping (Result<String>) -> Void) {
    completion(Result(data: mockPrivateKey))
  }
}
