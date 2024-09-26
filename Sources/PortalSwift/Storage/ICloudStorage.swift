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
  public var api: PortalApiProtocol?
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
    ICloudStorage.hash("\(client.custodian.id)\(client.id)")
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

  public static func hash(_ str: String) -> String {
    let data = str.data(using: .utf8)!
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    data.withUnsafeBytes {
      _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
    }
    return Data(digest).map { String(format: "%02hhx", $0) }.joined()
  }
}
