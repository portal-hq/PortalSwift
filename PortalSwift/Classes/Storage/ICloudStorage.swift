//
//  ICloudStorage.swift
//  FBSnapshotTestCase
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation
import CommonCrypto

/// A storage class that uses iCloud's key-value store to store/retrieve private keys.
public class ICloudStorage: Storage {
  enum ICloudStorageError: Error {
    case noAPIKeyProvided(String)
    case unableToRetrieveClient(String)
    case unableToDeriveKey(String)
  }

  /// The Portal API instance to retrieve the client's and custodian's IDs.
  public var api: PortalApi?

  /// The key used to store the private key in iCloud.
  public var key: String = ""

  /**
     Initializes a new ICloudStorage instance.

     - Returns: A new ICloudStorage instance.
     */
  public override init() {}

  /**
     Reads the private key stored in iCloud's key-value store.

     - Returns: The private key stored in iCloud's key-value store.
     */
  public override func read() throws -> String {
    let key = try self.getKey()

    NSUbiquitousKeyValueStore.default.synchronize()
    return NSUbiquitousKeyValueStore.default.string(forKey: key) ?? ""
  }

  /**
     Writes the private key to iCloud's key-value store.

     - Parameters:
        - privateKey: The private key to write to iCloud's key-value store.

     - Returns: The private key written to iCloud's key-value store.
     */
  public override func write(privateKey: String) throws -> Bool {
    let key = try self.getKey()

    NSUbiquitousKeyValueStore.default.set(privateKey, forKey: key)
    NSUbiquitousKeyValueStore.default.synchronize()

    return true
  }

  /**
     Deletes the private key stored in iCloud's key-value store.

     - Returns: A boolean indicating whether the private key was deleted.
     */
  public override func delete() throws -> Bool {
    let key = try self.getKey()

    NSUbiquitousKeyValueStore.default.removeObject(forKey: key)
    NSUbiquitousKeyValueStore.default.synchronize()

    return true
  }

  /**
     Gets the key to use for storing/retrieving the private key in iCloud's key-value store.

      - Returns: The key to use for storing/retrieving the private key in iCloud's key-value store.
      */
  private func getKey() throws -> String {
    if self.key.count > 0 {
      return self.key
    }

    if self.api == nil {
      throw ICloudStorageError.noAPIKeyProvided("No API key provided")
    }

    do {
      try self.api!.getClient() { (client: Client) -> Void in
        self.key = ICloudStorage.hash("\(client.custodian.id)\(client.id)")
      }
    } catch {
      throw ICloudStorageError.unableToRetrieveClient("Unable to retrieve client from API")
    }

    if self.key.count == 0 {
      throw ICloudStorageError.unableToDeriveKey("Unable to derive the key from API")
    }

    return self.key
  }

  /**
     Hashes the given string.

     - Parameters:
        - str: The string to hash.

     - Returns: The hashed string.
     */
  private static func hash(_ str: String) -> String {
    let data = str.data(using: .utf8)!
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    data.withUnsafeBytes {
      _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
    }
    return Data(digest).map { String(format: "%02hhx", $0) }.joined()
  }
}
