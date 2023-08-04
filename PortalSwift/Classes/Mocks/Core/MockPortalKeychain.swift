//
//  MockPortalKeychain.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public class MockPortalKeychain: PortalKeychain {
  override public func getAddress() throws -> String {
    return mockAddress
  }

  override public func getSigningShare() throws -> String {
    return mockSigningShare
  }

  override public func deleteAddress() throws {}

  override public func deleteSigningShare() throws {}

  override public func setAddress(address _: String, completion: (Result<OSStatus>) -> Void) {
    return completion(Result(data: OSStatus(1)))
  }

  override public func setSigningShare(signingShare _: String, completion: (Result<OSStatus>) -> Void) {
    return completion(Result(data: OSStatus(1)))
  }

  override public func validateOperations(completion: @escaping (Result<OSStatus>) -> Void) {
    return completion(Result(data: OSStatus(1)))
  }
}
