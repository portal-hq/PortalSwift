//
//  PortalKeychain.swift
//  FBSnapshotTestCase
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public class PortalKeychain {
  public init() {}
  
  public func getAddress() throws -> String {
    return ""
  }
  
  public func getSigningShare() throws -> String {
    return ""
  }
  
  public func setAddress(address: String) throws -> Bool {
    return true
  }
  
  public func setSigningShare(signingShare: String) throws -> Bool {
    return true
  }
}
