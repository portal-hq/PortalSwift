//
//  File.swift
//
//
//  Created by Blake Williams on 3/31/24.
//

import Foundation

class PortalKeyValueStore {
  public func delete(_ key: String) -> Bool {
    // Delete from iCloud.
    NSUbiquitousKeyValueStore.default.synchronize()
    NSUbiquitousKeyValueStore.default.removeObject(forKey: key)
    NSUbiquitousKeyValueStore.default.synchronize()

    return true
  }

  public func read(_ key: String) -> String {
    // Read from iCloud.
    NSUbiquitousKeyValueStore.default.synchronize()
    return NSUbiquitousKeyValueStore.default.string(forKey: key) ?? ""
  }

  public func write(_ key: String, value: String) -> Bool {
    // Write to iCloud.
    NSUbiquitousKeyValueStore.default.synchronize()
    NSUbiquitousKeyValueStore.default.set(value, forKey: key)
    NSUbiquitousKeyValueStore.default.synchronize()

    return true
  }
}
