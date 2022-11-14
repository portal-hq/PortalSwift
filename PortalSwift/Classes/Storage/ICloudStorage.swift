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
  public var key: String = ""

  public override func delete() -> Bool {
    let key = self.getKey()

    NSUbiquitousKeyValueStore.default.removeObject(forKey: key)
    NSUbiquitousKeyValueStore.default.synchronize()

    return true
  }

  public override func read() -> String {
    let key = self.getKey()

    NSUbiquitousKeyValueStore.default.synchronize()
    let value = NSUbiquitousKeyValueStore.default.string(forKey: key)

    return value ?? ""
  }

  public override func write(privateKey: String) -> String {
    let key = self.getKey()

    NSUbiquitousKeyValueStore.default.set(privateKey, forKey: key)
    NSUbiquitousKeyValueStore.default.synchronize()

    return read()
  }

  private func getKey() -> String {
    if self.key.count > 0 {
      return self.key
    }

    if self.api == nil {
      fatalError("[PortalICloudStorage] No Portal API instance found")
    }

    do {
      try self.api!.getClient(completion: { (client: Client) -> Void in
        self.key = ICloudStorage.hash("\(client.custodian.id)\(client.id)")
      })
    } catch {
      fatalError("[PortalICloudStorage] Failed to get client")
    }

    return self.key
  }

  private static func hash(_ str: String) -> String {
    var hash = 0

    // Handle empty strings
    if str.count == 0 {
      return String(hash)
    }

    for char in str {
      hash = (hash << 5) - hash + Int(char.unicodeScalars.first!.value)
      hash |= 0 // Convert to 32bit integer
    }

    return String(abs(hash))
  }
}
