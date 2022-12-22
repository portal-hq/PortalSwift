//
//  MockPortalKeychain.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public class MockPortalKeychain: PortalKeychain {
  public override func getAddress() throws -> String {
    return mockAddress
  }

  public override func getSigningShare() throws -> String {
    return mockSigningShare
  }
  
  public override func setAddress(address: String) throws {}
  
  public override func setSigningShare(signingShare: String) throws {}
}
