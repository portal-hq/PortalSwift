//
//  MockPortalKeyValueStore.swift
//
//
//  Created by Blake Williams on 3/31/24.
//

import Foundation

class MockPortalKeyValueStore: PortalKeyValueStoreProtocol {
  public func delete(_: String) -> Bool {
    return true
  }

  public func read(_: String) -> String {
    return MockConstants.mockEncryptionKey
  }

  public func write(_: String, value _: String) -> Bool {
    return true
  }
}
