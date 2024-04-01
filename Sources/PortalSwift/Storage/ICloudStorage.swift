//
//  ICloudStorage.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import CommonCrypto
import Foundation

/// A storage class that uses iCloud's key-value store to store/retrieve private keys.
public class ICloudStorage: Storage, PortalStorage {
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

  public let encryption: PortalEncryption

  private let isSimulator = TARGET_OS_SIMULATOR != 0
  private let storage: PortalKeyValueStore

  /// Initializes a new ICloudStorage instance.
  public init(
    encryption: PortalEncryption? = nil,
    keyValueStore: PortalKeyValueStore? = nil
  ) {
    self.encryption = encryption ?? PortalEncryption()
    self.storage = keyValueStore ?? PortalKeyValueStore()
  }

  /*******************************************
   * Public functions
   *******************************************/

  public func delete() async throws -> Bool {
    let key = try await getKey()
    return self.storage.delete(key)
  }

  public func read() async throws -> String {
    let key = try await getKey()
    return self.storage.read(key)
  }

  public func write(_ value: String) async throws -> Bool {
    let key = try await getKey()
    return self.storage.write(key, value: value)
  }

  public func validateOperations() async throws -> Bool {
    let testKey = "portal_test"
    let testValue = "test_value"

    _ = self.storage.write(testKey, value: testValue)

    let readValue = self.storage.read(testKey)
    if readValue == testValue {
      _ = self.storage.delete(testKey)
      return true
    } else {
      throw ICloudStorageError.failedValidateOperations("Failed to read/write test data")
    }
  }

  /*******************************************
   * Private functions
   *******************************************/

  private func createKey(_ client: ClientResponse) -> String {
    return ICloudStorage.hash("\(client.custodian.id)\(client.id)")
  }

  private func getKey() async throws -> String {
    if key.count > 0 {
      return key
    }

    if self.api == nil {
      throw ICloudStorageError.noAPIKeyProvided("No API key provided")
    }

    guard let clientResponse = try await api!.client else {
      throw ICloudStorageError.unableToRetrieveClient("Unable to retrieve client from PortalApi.")
    }

    let key = self.createKey(clientResponse)

    return key
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

  public static func hash(_ str: String) -> String {
    let data = str.data(using: .utf8)!
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    data.withUnsafeBytes {
      _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
    }
    return Data(digest).map { String(format: "%02hhx", $0) }.joined()
  }

  /*******************************************
   * Deprecated functions
   *******************************************/

  /// Deletes the private key stored in iCloud's key-value store.
  /// - Parameter completion: Resolves as a Result<Bool>.
  /// - Returns: Void
  @available(*, deprecated, renamed: "delete", message: "Please use the async/await implementation of delete().")
  override public func delete(completion: @escaping (Result<Bool>) -> Void) {
    Task {
      do {
        let success = try await delete()
        completion(Result(data: success))
      } catch {
        completion(Result(error: error))
      }
    }
  }

  /// Reads the private key stored in iCloud's key-value store.
  /// - Parameter completion: Resolves as a Result which can include the private key stored in iCloud's key-value store.
  /// - Returns: Void
  @available(*, deprecated, renamed: "read", message: "Please use the async/await implementation of read().")
  override public func read(completion: @escaping (Result<String>) -> Void) {
    Task {
      do {
        let value = try await read()
        completion(Result(data: value))
      } catch {
        completion(Result(error: error))
      }
    }
  }

  /// Writes the private key to iCloud's key-value store.
  /// - Parameters:
  ///   - privateKey: The private key to write to iCloud's key-value store.
  ///   - completion: Resolves as a Result<Bool>.
  /// - Returns: Void
  @available(*, deprecated, renamed: "write", message: "Please use the async/await implementation of write().")
  override public func write(privateKey: String, completion: @escaping (Result<Bool>) -> Void) {
    Task {
      do {
        let success = try await write(privateKey)
        completion(Result(data: success))
      } catch {
        completion(Result(error: error))
      }
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
  @available(*, deprecated, renamed: "validateOperations", message: "Please use the async/await implementation of validateOperations().")
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
}
