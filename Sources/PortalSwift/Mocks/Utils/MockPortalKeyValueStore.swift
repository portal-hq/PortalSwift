//
//  File.swift
//
//
//  Created by Blake Williams on 3/31/24.
//

import Foundation

class MockPortalKeyValueStore: PortalKeyValueStore {
  override public func delete(_: String) -> Bool {
    return true
  }

  override public func read(_: String) -> String {
    return MockConstants.mockEncryptionKey
  }

  override public func write(_: String, value _: String) -> Bool {
    return true
  }
}
