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
  
  override
  public init() {
    let signInConfig = GIDConfiguration(clientID: "YOUR_IOS_CLIENT_ID")
    
  }
  
  public func assignAccessToken() -> Void {
    
  }
  
  override
  public func delete() throws -> Bool {
    return true
  }
  
  override
  public func read() throws -> String {
    return ""
  }
  
  override
  public func write(privateKey: String) throws -> String {
    return ""
  }
  
  private func signIn() throws -> Void {
    
  }
}
