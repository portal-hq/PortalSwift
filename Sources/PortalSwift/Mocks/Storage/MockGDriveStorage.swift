//
//  MockGDriveStorage.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation
import UIKit

public class MockGDriveStorage: GDriveStorage {
  public init(mobile: Mobile, clientID: String? = nil, viewController: UIViewController? = nil) {
    super.init(mobile: mobile, clientID: clientID, viewController: viewController, encryption: MockPortalEncryption())
  }

  // Async decrypt implementation
  public func decrypt(_: String, withKey _: String) async throws -> String {
    return try MockConstants.mockMpcShareString
  }

  // Async delete implementation
  override public func delete() async throws -> Bool {
    return true
  }

  // Async encrypt implementation
  public func encrypt(_: String) async throws -> EncryptData {
    return MockConstants.mockEncryptData
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
