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
  public enum ICloudStorageError: LocalizedError {
    case noAPIKeyProvided(String)
    case noAccessToICloud(String)
    case notSignedIntoICloud(String)
    case unableToDeriveKey(String)
    case unableToRetrieveClient(String)
    case failedValidateOperations(String)
    case binaryNotConfigured
    case unableToFetchClientData
    case unableToDeleteFile
    case unableToReadFile
    case unableToFetchIOSHash
    case unknownError
  }

  public enum ICloudStatus: String {
    case available
    case notSignedIn
    case noAccess
  }

  public var mobile: Mobile?
  /// The Portal API instance to retrieve the client's and custodian's IDs.
  public weak var api: PortalApiProtocol?
  /// The key used to store the private key in iCloud.
  public var key: String = ""

  public let encryption: PortalEncryptionProtocol

  private let isSimulator = TARGET_OS_SIMULATOR != 0
  private let storage: PortalKeyValueStoreProtocol
  private var filenameHashes: [String: String]?

  public init(
    mobile: Mobile? = nil,
    encryption: PortalEncryptionProtocol? = nil,
    keyValueStore: PortalKeyValueStoreProtocol? = nil
  ) {
    self.encryption = encryption ?? PortalEncryption()
    self.storage = keyValueStore ?? PortalKeyValueStore()
    self.mobile = mobile
  }

  /*******************************************
   * Public functions
   *******************************************/

  public func delete() async throws -> Bool {
    let hashes = try await getFilenameHashes()

    for hash in hashes.values {
      if self.storage.delete(hash) {
        return true
      }
    }

    throw ICloudStorageError.unableToDeleteFile
  }

  public func read() async throws -> String {
    let hashes = try await getFilenameHashes()

    for hash in hashes.values {
      let value = self.storage.read(hash)
      if !value.isEmpty {
        return value
      }
    }

    throw ICloudStorageError.unableToReadFile
  }

  public func write(_ value: String) async throws -> Bool {
    let key = try await getDefaultFilename()
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

  /****************************
   * Private functions
   *******************************************/

  private func getFilenameHashes() async throws -> [String: String] {
    if let hashes = self.filenameHashes {
      return hashes
    }

    guard let api = self.api else {
      throw ICloudStorageError.noAPIKeyProvided("No API key provided")
    }

    guard let client = try await api.client else {
      throw ICloudStorageError.unableToRetrieveClient("Unable to retrieve client from PortalApi.")
    }

    let custodianId = client.custodian.id
    let clientId = client.id
    self.filenameHashes = try await self.fetchFileHashes(custodianId: custodianId, clientId: clientId)

    return self.filenameHashes!
  }

  private func getDefaultFilename() async throws -> String {
    let hashes = try await getFilenameHashes()
    guard let defaultHash = hashes["default"] else {
      throw ICloudStorageError.unableToFetchIOSHash
    }
    return defaultHash
  }

  private func fetchFileHashes(custodianId: String, clientId: String) async throws -> [String: String] {
    let input = [
      "custodianId": custodianId,
      "clientId": clientId
    ]

    guard let mobile = self.mobile else {
      throw ICloudStorageError.binaryNotConfigured
    }

    guard let inputJSON = try? JSONSerialization.data(withJSONObject: input),
          let inputJSONString = String(data: inputJSON, encoding: .utf8)
    else {
      throw ICloudStorageError.unableToFetchClientData
    }

    let hashesJSON = mobile.MobileGetCustodianIdClientIdHashes(inputJSONString)

    guard let hashesData = hashesJSON.data(using: .utf8) else {
      throw ICloudStorageError.unableToFetchClientData
    }

    do {
      let response = try JSONDecoder().decode(CustodianIDClientIDHashesResponse.self, from: hashesData)

      if let error = response.error {
        throw ICloudStorageError.unableToFetchClientData
      }

      guard let hashes = response.data else {
        throw ICloudStorageError.unableToFetchClientData
      }

      return hashes.toMap()
    } catch {
      throw ICloudStorageError.unableToFetchClientData
    }
  }
}
