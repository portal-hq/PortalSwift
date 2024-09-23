//
//  PortalKeyValueStore.swift
//
//
//  Created by Blake Williams on 3/31/24.
//

import Foundation

public protocol PortalKeyValueStoreProtocol {
    func delete(_ key: String) -> Bool
    func read(_ key: String) -> String
    func write(_ key: String, value: String) -> Bool
}

public class PortalKeyValueStore: PortalKeyValueStoreProtocol {
  public init() {}

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
