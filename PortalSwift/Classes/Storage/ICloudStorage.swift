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
    case unknownError
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
  public override func read(completion: @escaping (Result<String>) -> Void) -> Void {
    self.getKey() {
      (result: Result<String>) -> Void in

      if (result.data != nil) {
        NSUbiquitousKeyValueStore.default.synchronize()

        return completion(Result(data: NSUbiquitousKeyValueStore.default.string(forKey: result.data!) ?? ""))
      }

      return completion(result)
    }
  }

  /**
     Writes the private key to iCloud's key-value store.

     - Parameters:
        - privateKey: The private key to write to iCloud's key-value store.

     - Returns: The private key written to iCloud's key-value store.
     */
  public override func write(privateKey: String, completion: @escaping (Result<Bool>) -> Void) -> Void {
    self.getKey() {
      (result: Result<String>) -> Void in

      if (result.data != nil) {
        NSUbiquitousKeyValueStore.default.set(privateKey, forKey: result.data!)
        NSUbiquitousKeyValueStore.default.synchronize()

        return completion(Result(data: true))
      } else if (result.error != nil) {
        return completion(Result(error: result.error!))
      }

      return completion(Result(error: ICloudStorageError.unknownError))
    }
  }

  /**
     Deletes the private key stored in iCloud's key-value store.

     - Returns: A boolean indicating whether the private key was deleted.
     */
  public override func delete(completion: @escaping (Result<Bool>) -> Void) -> Void {
    self.getKey() {
      (result: Result<String>) -> Void in

      if (result.data != nil) {
        NSUbiquitousKeyValueStore.default.removeObject(forKey: result.data!)
        NSUbiquitousKeyValueStore.default.synchronize()

        return completion(Result(data: true))
      } else if (result.error != nil) {
        return completion(Result(error: result.error!))
      }

      return completion(Result(error: ICloudStorageError.unknownError))
    }
  }

  /**
     Gets the key to use for storing/retrieving the private key in iCloud's key-value store.

      - Returns: The key to use for storing/retrieving the private key in iCloud's key-value store.
      */
  private func getKey(completion: @escaping (Result<String>) -> Void) -> Void {
    if self.key.count > 0 {
      return completion(Result(data: self.key))
    }

    if self.api == nil {
      return completion(Result(error: ICloudStorageError.noAPIKeyProvided("No API key provided")))
    }

    do {
      try self.api!.getClient() { (result: Result<Any>) -> Void in
        let client = result.data as! Dictionary<String, Any>
        let clientID = client["id"] as! String
        
        let custodian = client["custodian"] as! Dictionary<String, Any>
        let custodianID = custodian["id"] as! String

        if (result.data != nil) {
          self.key = ICloudStorage.hash("\(custodianID)\(clientID)")
          return completion(Result(data: self.key))
        } else if (result.error != nil) {
          return completion(Result(error: result.error!))
        }

        return completion(Result(error: ICloudStorageError.unknownError))
      }
    } catch {
      completion(Result(error: ICloudStorageError.unableToRetrieveClient("Unable to retrieve client from API")))
    }
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
