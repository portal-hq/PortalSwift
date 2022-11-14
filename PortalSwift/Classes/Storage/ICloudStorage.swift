//
//  ICloudStorage.swift
//  FBSnapshotTestCase
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public class ICloudStorage: Storage {
  public var api: PortalApi?
  
  override
  public init() {
    
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
}
