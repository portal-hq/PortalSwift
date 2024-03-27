//
//  PortalKeychain.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// The main interface for Portal to securely store the client's signing share.
public class PortalKeychain {
  public var clientId: String?

  let deprecatedAddressKey = "PortalMpc.Address"
  let deprecatedShareKey = "PortalMpc.DkgResult"

  private var client: ClientResponse? {
    get async {
      await self.api.client
    }
  }

  private let api: PortalApi
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()
  private var metadata: PortalKeychainMetadata?
  private let metadataKey = ".metadata"
  private let sharesKey = ".shares"

  /// Creates an instance of PortalKeychain.
  init(api: PortalApi) {
    self.api = api

    Task {
      do {
        try await self.loadMetadata()
      } catch {}
    }
  }

  /*******************************************
   * Public functions
   *******************************************/

  public func getAddress(_ chainId: String) async throws -> String {
    let namespaceString = chainId.split(separator: ":").map(String.init)[0]
    guard let namespace = PortalNamespace(rawValue: namespaceString) else {
      throw KeychainError.unsupportedNamespace(chainId)
    }

    let metadata = try await getMetadata()
    guard let address = metadata.addresses?[namespace] else {
      throw KeychainError.noAddressForNamespace(namespace)
    }

    return address!
  }

  private func getMetadata() async throws -> PortalKeychainClientMetadata {
    guard let clientId = await client?.id else {
      throw KeychainError.clientNotFound
    }

    let value = try getItem("\(clientId).\(metadataKey)")
    guard let data = value.data(using: .utf8) else {
      throw KeychainError.unableToEncodeKeychainData
    }
    let metadata = try decoder.decode(PortalKeychainClientMetadata.self, from: data)

    return metadata
  }

  public func getShare(_ chainId: String) async throws -> String {
    let namespaceString = chainId.split(separator: ":").map(String.init)[0]
    guard let namespace = PortalNamespace(rawValue: namespaceString) else {
      throw KeychainError.unsupportedNamespace(chainId)
    }
    guard let curve = metadata?.namespaces[namespace] else {
      throw KeychainError.unsupportedNamespace(chainId)
    }

    let shares = try await getShares()
    guard let share = shares[curve.rawValue] else {
      throw KeychainError.shareNotFoundForCurve(curve)
    }

    return share.share
  }

  private func getShares() async throws -> PortalKeychainClientShares {
    guard let clientId = await client?.id else {
      throw KeychainError.clientNotFound
    }

    let value = try getItem("\(clientId).\(sharesKey)")
    guard let data = value.data(using: .utf8) else {
      throw KeychainError.unableToEncodeKeychainData
    }
    let shares = try decoder.decode(PortalKeychainClientShares.self, from: data)

    return shares
  }

  public func loadMetadata() async throws {
    if let client = await api.client {
      // Load the curve map into memory
      var metadata = PortalKeychainMetadata(
        namespaces: [:]
      )
      if let eip155Curve = client.metadata.namespaces.eip155?.curve {
        metadata.namespaces[.eip155] = eip155Curve
      }
      if let solanaCurve = client.metadata.namespaces.solana?.curve {
        metadata.namespaces[.solana] = solanaCurve
      }

      // Build the client's wallet metadata
      var wallets: [PortalCurve: PortalKeychainClientMetadataWallet] = [:]
      for wallet in client.wallets {
        wallets[wallet.curve] = PortalKeychainClientMetadataWallet(
          id: wallet.id,
          curve: wallet.curve,
          publicKey: wallet.publicKey,
          backupShares: wallet.backupSharePairs.map { share in
            PortalKeychainClientMetadataWalletBackupShare(
              backupMethod: share.backupMethod,
              createdAt: share.createdAt,
              id: share.id,
              status: share.status
            )
          },
          signingShares: wallet.signingSharePairs.map { share in
            PortalKeychainClientMetadataWalletShare(
              createdAt: share.createdAt,
              id: share.id,
              status: share.status
            )
          }
        )
      }

      // Build the client's metadata
      let clientMetadata = PortalKeychainClientMetadata(
        id: client.id,
        addresses: [
          .eip155: client.metadata.namespaces.eip155?.address,
          .solana: client.metadata.namespaces.solana?.address,
        ],
        custodian: client.custodian,
        wallets: wallets
      )

      // Write the metadata to the keychain
      try await self.setMetadata(clientMetadata)
    }

    throw KeychainError.clientNotFound
  }

  public func setMetadata(_ withData: PortalKeychainClientMetadata) async throws {
    guard let clientId = await client?.id else {
      throw KeychainError.clientNotFound
    }
    let data = try encoder.encode(withData)
    guard let value = String(data: data, encoding: .utf8) else {
      throw KeychainError.unableToEncodeKeychainData
    }

    try await self.setItem("\(clientId).\(self.metadataKey)", withValue: value)
  }

  public func setShares(_: [String: PortalMpcGeneratedShare]) async throws {}

  /*******************************************
   * Private functions
   *******************************************/

  private func deleteItem(_ key: String) throws {
    let query: [String: AnyObject] = [
      kSecAttrService as String: "PortalMpc.\(key)" as AnyObject,
      kSecAttrAccount as String: key as AnyObject,
      kSecClass as String: kSecClassGenericPassword,
    ]

    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.unhandledError(status: status) }
  }

  private func getItem(_ item: String) throws -> String {
    // Construct the query to retrieve the keychain item.
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: item,
      kSecAttrService as String: "PortalMpc.\(item)",
      kSecMatchLimit as String: kSecMatchLimitOne,
      kSecReturnData as String: true,
    ]

    // Try to retrieve the keychain item that matches the query.
    var keychainItem: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &keychainItem)

    // Throw if the status is not successful.
    guard status != errSecItemNotFound else { throw KeychainError.itemNotFound(item: item) }
    guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }

    // Attempt to format the keychain item as a string.
    guard let itemData = keychainItem as? Data,
          let itemString = String(data: itemData, encoding: String.Encoding.utf8)
    else {
      throw KeychainError.unexpectedItemData(item: item)
    }

    return itemString
  }

  private func setItem(_ key: String, withValue: String) async throws {
    // Construct the query to set the keychain item.
    let query: [String: AnyObject] = [
      kSecAttrService as String: "PortalMpc.\(key)" as AnyObject,
      kSecAttrAccount as String: key as AnyObject,
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly as AnyObject,
      kSecValueData as String: withValue.data(using: String.Encoding.utf8) as AnyObject,
    ]

    // Try to set the keychain item that matches the query.
    let status = SecItemAdd(query as CFDictionary, nil)

    // Throw if the status is not successful.
    if status == errSecDuplicateItem {
      try self.updateItem(key, withValue: withValue)
    }

    guard status != errSecNotAvailable else {
      throw KeychainError.keychainUnavailableOrNoPasscode(status: status)
    }
    guard status == errSecSuccess else {
      throw KeychainError.unhandledError(status: status)
    }
  }

  private func updateItem(_ key: String, withValue: String) throws {
    // Construct the query to update the keychain item.
    let query: [String: AnyObject] = [
      kSecAttrService as String: "PortalMpc.\(key)" as AnyObject,
      kSecAttrAccount as String: key as AnyObject,
      kSecClass as String: kSecClassGenericPassword,
    ]

    // Construct the attributes to update the keychain item.
    let attributes: [String: AnyObject] = [
      kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly as AnyObject,
      kSecValueData as String: withValue.data(using: String.Encoding.utf8) as AnyObject,
    ]

    // Try to update the keychain item that matches the query.
    let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

    // Throw if the status is not successful.
    guard status != errSecItemNotFound else {
      throw KeychainError.itemNotFound(item: key)
    }
    guard status != errSecNotAvailable else {
      throw KeychainError.keychainUnavailableOrNoPasscode(status: status)
    }
    guard status == errSecSuccess else {
      throw KeychainError.unhandledError(status: status)
    }
  }

  /*******************************************
   * Deprecated functions
   *******************************************/

  /// Retrieve the address stored in the client's keychain.
  /// - Returns: The client's address.
  @available(*, deprecated, renamed: "getAddress", message: "Please use the async, chainId-specific implementation of getAddress().")
  public func getAddress() throws -> String {
    let clientId = try getClientId()
    let addressKey = "\(clientId).address"
    var address: String

    do {
      address = try self.getItem(addressKey)
    } catch KeychainError.itemNotFound(item: addressKey) {
      do {
        // Fallback to deprecated key.
        address = try self.getItem(self.deprecatedAddressKey)
      } catch KeychainError.itemNotFound(item: self.deprecatedAddressKey) {
        // Throw original item not found error.
        throw KeychainError.itemNotFound(item: addressKey)
      }
    }

    return address
  }

  /// Retrieve the signing share stored in the client's keychain.
  /// - Returns: The client's signing share.
  @available(*, deprecated, renamed: "getShares", message: "Please use the async implementation of getShares().")
  public func getSigningShare() throws -> String {
    let clientId = try getClientId()
    let shareKey = "\(clientId).share"
    var share: String

    do {
      share = try self.getItem(shareKey)
    } catch KeychainError.itemNotFound(item: shareKey) {
      do {
        // Fallback to deprecated key.
        share = try self.getItem(self.deprecatedShareKey)
      } catch KeychainError.itemNotFound(item: self.deprecatedShareKey) {
        // Throw original item not found error.
        throw KeychainError.itemNotFound(item: shareKey)
      }
    }

    return share
  }

  /// Sets the address in the client's keychain.
  /// - Parameter address: The public address of the client's wallet.
  @available(*, deprecated, renamed: "updateMetadata", message: "Please use the async implementation of updateMetadata().")
  public func setAddress(
    address: String,
    completion: @escaping (Result<OSStatus>) -> Void
  ) {
    var clientId: String
    do {
      clientId = try self.getClientId()
    } catch {
      completion(Result(error: error))
      return
    }
    let addressKey = "\(clientId).address"

    self.setItem(key: addressKey, value: address) { result in
      // Handle errors
      guard result.error == nil else {
        return completion(Result(error: result.error!))
      }

      return completion(Result(data: result.data!))
    }
  }

  /// Sets the signing share in the client's keychain.
  /// - Parameter signingShare: A dkg object.
  @available(*, deprecated, renamed: "updateShares", message: "Please use the async implementation of updateShares().")
  public func setSigningShare(
    signingShare: String,
    completion: @escaping (Result<OSStatus>) -> Void
  ) {
    var clientId: String
    do {
      clientId = try self.getClientId()
    } catch {
      completion(Result(error: error))
      return
    }
    let shareKey = "\(clientId).share"

    self.setItem(key: shareKey, value: signingShare) { result in
      // Handle errors
      guard result.error == nil else {
        return completion(Result(error: result.error!))
      }

      return completion(Result(data: result.data!))
    }
  }

  /// Deletes the address stored in the client's keychain.
  @available(*, deprecated, renamed: "deleteMetadata", message: "Please use the async implementation of deleteMetadata().")
  public func deleteAddress() throws {
    let clientId = try getClientId()
    let addressKey = "\(clientId).address"

    try deleteItem(addressKey)
    try deleteItem(deprecatedAddressKey)
  }

  /// Deletes the signing share stored in the client's keychain.
  @available(*, deprecated, renamed: "deleteShares", message: "Please use the async implementation of deleteShares().")
  public func deleteSigningShare() throws {
    let clientId = try getClientId()
    let shareKey = "\(clientId).share"

    try deleteItem(shareKey)
    try deleteItem(deprecatedShareKey)
  }

  /// Tests `setItem` in the client's keychain.
  @available(*, deprecated, renamed: "validateOperations", message: "Please use the async implementation of validateOperations().")
  func validateOperations(completion: @escaping (Result<OSStatus>) -> Void) {
    do {
      _ = try self.getClientId()
    } catch {
      completion(Result(error: error))
      return
    }

    let testKey = "portal_test"
    let testValue = "test_value"

    self.setItem(key: testKey, value: testValue) { result in
      // Handle errors.
      guard result.error == nil else {
        return completion(Result(error: result.error!))
      }

      do {
        // Delete the key that was created.
        try self.deleteItem(testKey)
        return completion(Result(data: result.data!))
      } catch {
        return completion(Result(error: error))
      }
    }
  }

  @available(*, deprecated, renamed: "setItem", message: "Please use the async implementation of setItem().")
  private func setItem(
    key: String,
    value: String,
    completion: @escaping (Result<OSStatus>) -> Void
  ) {
    do {
      // Construct the query to set the keychain item.
      let query: [String: AnyObject] = [
        kSecAttrService as String: "PortalMpc.\(key)" as AnyObject,
        kSecAttrAccount as String: key as AnyObject,
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly as AnyObject,
        kSecValueData as String: value.data(using: String.Encoding.utf8) as AnyObject,
      ]

      // Try to set the keychain item that matches the query.
      let status = SecItemAdd(query as CFDictionary, nil)

      // Throw if the status is not successful.
      if status == errSecDuplicateItem {
        try self.updateItem(key, withValue: value)
        return completion(Result(data: status))
      }
      guard status != errSecNotAvailable else {
        return completion(Result(error: KeychainError.keychainUnavailableOrNoPasscode(status: status)))
      }
      guard status == errSecSuccess else {
        return completion(Result(error: KeychainError.unhandledError(status: status)))
      }
      return completion(Result(data: status))
    } catch {
      return completion(Result(error: error))
    }
  }

  @available(*, deprecated, renamed: "client.id", message: "Please use the async `client` getter to access clientId.")
  private func getClientId() throws -> String {
    if self.clientId == nil {
      throw KeychainError.clientIdNotSetYet
    }

    return self.clientId!
  }
}

public enum KeychainError: Error, Equatable {
  case clientNotFound
  case clientIdNotSetYet
  case itemNotFound(item: String)
  case itemAlreadyExists(item: String)
  case keychainUnavailableOrNoPasscode(status: OSStatus)
  case noAddressForNamespace(_ namespace: PortalNamespace)
  case noWalletForNamespace(_ namespace: PortalNamespace)
  case noWalletsFound
  case shareNotFoundForCurve(_ curve: PortalCurve)
  case unableToEncodeKeychainData
  case unexpectedItemData(item: String)
  case unhandledError(status: OSStatus)
  case unsupportedNamespace(_ chainId: String)
}
