//
//  GDriveStorage.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

import GoogleSignIn

public enum GDriveStorageError: Error {
  case unknownError
}

public class GDriveStorage: Storage {
  public var accessToken: String?
  public var api: PortalApi?
  private var separator: String = ""

  public override init() {
    _ = GIDConfiguration(clientID: "YOUR_IOS_CLIENT_ID")
  }

  public func assignAccessToken() -> Void {

  }

  public override func delete(completion: @escaping (Result<Bool>) -> Void) -> Void {
    return completion(Result(error: GDriveStorageError.unknownError))
  }

  public override func read(completion: @escaping (Result<String>) -> Void) -> Void {
    return completion(Result(data: ""))
  }

  public override func write(privateKey: String, completion: @escaping (Result<Bool>) -> Void) -> Void {
    return completion(Result(error: GDriveStorageError.unknownError))
  }

  private func signIn() -> Void {
    return
  }
}
