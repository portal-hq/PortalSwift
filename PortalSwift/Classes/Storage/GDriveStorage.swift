//
//  GDriveStorage.swift
//  FBSnapshotTestCase
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

import GoogleSignIn

public class GDriveStorage: Storage {
  public var accessToken: String?
  public var api: PortalApi?

  public override init() {
    let signInConfig = GIDConfiguration(clientID: "YOUR_IOS_CLIENT_ID")

  }

  public func assignAccessToken() -> Void {

  }

  public override func delete() throws -> Bool {
    return true
  }

  public override func read() throws -> String {
    return ""
  }

  public override func write(privateKey: String) throws -> Bool {
    return true
  }

  private func signIn() throws -> Void {

  }
}
