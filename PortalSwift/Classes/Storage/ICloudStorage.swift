//
//  ICloudStorage.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import CommonCrypto
import Foundation

/// A storage class that uses iCloud's key-value store to store/retrieve private keys.
public class ICloudStorage: Storage {
  public enum ICloudStorageError: Error {
    case noAPIKeyProvided(String)
    case noAccessToICloud(String)
    case notSignedIntoICloud(String)
    case unableToDeriveKey(String)
    case unableToRetrieveClient(String)
    case failedValidateOperations(String)
    case unknownError
  }

  public enum ICloudStatus: String {
    case available
    case notSignedIn
    case noAccess
  }

  /// The Portal API instance to retrieve the client's and custodian's IDs.
  public var api: PortalApi?
  /// The key used to store the private key in iCloud.
  public var key: String = ""

  private let isSimulator = TARGET_OS_SIMULATOR != 0

  /// Initializes a new ICloudStorage instance.
  override public init() {}

  /// Reads the private key stored in iCloud's key-value store.
  /// - Parameter completion: Resolves as a Result which can include the private key stored in iCloud's key-value store.
  /// - Returns: Void
  override public func read(completion: @escaping (Result<String>) -> Void) {
    self.getKey { (result: Result<String>) in
      // Escape early if we can't get the key.
      if result.error != nil {
        completion(Result(error: result.error!))
        return
      }

      // Read from iCloud.
      NSUbiquitousKeyValueStore.default.synchronize()
      completion(Result(data: NSUbiquitousKeyValueStore.default.string(forKey: result.data!) ?? ""))
    }
  }

  /// Writes the private key to iCloud's key-value store.
  /// - Parameters:
  ///   - privateKey: The private key to write to iCloud's key-value store.
  ///   - completion: Resolves as a Result<Bool>.
  /// - Returns: Void
  override public func write(privateKey: String, completion: @escaping (Result<Bool>) -> Void) {
    self.getKey { (result: Result<String>) in
      // Escape early if we can't get the key.
      if result.error != nil {
        completion(Result(error: result.error!))
        return
      }

      // Write to iCloud.
      NSUbiquitousKeyValueStore.default.synchronize()
      NSUbiquitousKeyValueStore.default.set(privateKey, forKey: result.data!)
      NSUbiquitousKeyValueStore.default.synchronize()
      completion(Result(data: true))
    }
  }

  /// Deletes the private key stored in iCloud's key-value store.
  /// - Parameter completion: Resolves as a Result<Bool>.
  /// - Returns: Void
  override public func delete(completion: @escaping (Result<Bool>) -> Void) {
    self.getKey { (result: Result<String>) in
      // Escape early if we can't get the key.
      if result.error != nil {
        completion(Result(error: result.error!))
        return
      }

      // Delete from iCloud.
      NSUbiquitousKeyValueStore.default.synchronize()
      NSUbiquitousKeyValueStore.default.removeObject(forKey: result.data!)
      NSUbiquitousKeyValueStore.default.synchronize()
      completion(Result(data: true))
    }
  }

  /// Checks the availability and functionality of the iCloud key-value store.
  ///
  /// This method tests the iCloud key-value store by performing a sequence of write, read, and delete operations using a test key and value.
  /// It is designed to verify that all basic operations can be successfully performed on the user's iCloud key-value store.
  ///
  /// Specifically, the method:
  /// 1. Writes a test value to the store using a test key.
  /// 2. Attempts to read the written test value from the store using the test key.
  /// 3. If the read is successful and returns the correct test value, it proceeds to delete the test value from the store using the test key.
  /// 4. Finally, it checks if the deletion was successful by attempting to read the test value again. If the read returns `nil`, it concludes that the test sequence was successful.
  ///
  /// The method uses a `Result<Bool>` type to inform the caller of the outcome. If all operations were successful, it returns `Result(data: true)`.
  /// If any operation fails, it returns a `Result` with an error detailing the type of failure, either `ICloudStorageError.failedToRead` or `ICloudStorageError.failedToDelete`.
  ///
  /// - Parameter callback: A closure that takes a `Result<Bool>` as its parameter and returns `Void`.
  public func validateOperations(callback: @escaping (Result<Bool>) -> Void) {
    let testKey = "portal_test"
    let testValue = "test_value"

    self.rawWrite(key: testKey, value: testValue)

    if let readValue = rawRead(key: testKey), readValue == testValue {
      self.rawDelete(key: testKey)
      if self.rawRead(key: testKey) == nil {
        // Availability check succeeded.
        callback(Result(data: true))
      } else {
        callback(Result(error: ICloudStorageError.failedValidateOperations("Failed to delete test data")))
      }
    } else {
      callback(Result(error: ICloudStorageError.failedValidateOperations("Failed to read/write test data")))
    }
  }

  /// Reads the value stored in iCloud's key-value store with the given key.
  /// - Parameter key: The key to read the value from.
  /// - Returns: The value associated with the key, or nil if the key was not found.
  private func rawRead(key: String) -> String? {
    NSUbiquitousKeyValueStore.default.synchronize()
    return NSUbiquitousKeyValueStore.default.string(forKey: key)
  }

  /// Writes a value to iCloud's key-value store.
  /// - Parameters:
  ///   - key: The key to associate with the value.
  ///   - value: The value to write to iCloud's key-value store.
  private func rawWrite(key: String, value: String) {
    NSUbiquitousKeyValueStore.default.set(value, forKey: key)
    NSUbiquitousKeyValueStore.default.synchronize()
  }

  /// Deletes the value associated with a key in iCloud's key-value store.
  /// - Parameter key: The key to remove along with its associated value.
  private func rawDelete(key: String) {
    NSUbiquitousKeyValueStore.default.removeObject(forKey: key)
    NSUbiquitousKeyValueStore.default.synchronize()
  }

  private func getKey(completion: @escaping (Result<String>) -> Void) {
    if self.key.count > 0 {
      completion(Result(data: self.key))
      return
    }

    if self.api == nil {
      completion(Result(error: ICloudStorageError.noAPIKeyProvided("No API key provided")))
      return
    }

    do {
      try self.api!.getClient { (result: Result<Client>) in
        if result.error != nil {
          completion(Result(error: result.error!))
          return
        }
        let key = self.createKey(client: result.data!)
        completion(Result(data: key))
      }
    } catch {
      completion(Result(error: ICloudStorageError.unableToRetrieveClient("Unable to retrieve client from API")))
    }
  }

  private func createKey(client: Client) -> String {
    return ICloudStorage.hash("\(client.custodian.id)\(client.id)")
  }

  private static func hash(_ str: String) -> String {
    let data = str.data(using: .utf8)!
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    data.withUnsafeBytes {
      _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
    }
    return Data(digest).map { String(format: "%02hhx", $0) }.joined()
  }
}
