//
//  MockFirebaseStorage.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public class MockFirebaseStorage: FirebaseStorage {
  public init() {
    super.init(
      getToken: { return "mock-firebase-token" },
      encryption: MockPortalEncryption(),
      requests: MockPortalRequests()
    )
  }

  // Async delete implementation
  override public func delete() async throws -> Bool {
    return true
  }

  // Async read implementation
  override public func read() async throws -> String {
    return MockConstants.mockEncryptionKey
  }

  // Async write implementation
  override public func write(_: String) async throws -> Bool {
    return true
  }

  override public func validateOperations() async throws -> Bool {
    return true
  }
}
