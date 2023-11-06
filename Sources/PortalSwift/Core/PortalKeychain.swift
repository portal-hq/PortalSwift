//
//  PortalKeychain.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// The main interface for Portal to securely store the client's signing share.
public class PortalKeychain: MobileStorageAdapter {
  public var clientId: String?

  let deprecatedAddressKey = "PortalMpc.Address"
  let deprecatedShareKey = "PortalMpc.DkgResult"

  public enum KeychainError: Error, Equatable {
    case ItemNotFound(item: String)
    case ItemAlreadyExists(item: String)
    case unexpectedItemData(item: String)
    case unhandledError(status: OSStatus)
    case clientIdNotSetYet
    case keychainUnavailableOrNoPasscode(status: OSStatus)
  }

  /// Creates an instance of PortalKeychain.
  override public init() {}

  /// Retrieve the address stored in the client's keychain.
  /// - Returns: The client's address.
  override public func getAddress() throws -> String {
    let clientId = try getClientId()
    let addressKey = "\(clientId).address"
    var address: String

    do {
      address = try self.getItem(item: addressKey)
    } catch KeychainError.ItemNotFound(item: addressKey) {
      do {
        // Fallback to deprecated key.
        address = try self.getItem(item: self.deprecatedAddressKey)
      } catch KeychainError.ItemNotFound(item: self.deprecatedAddressKey) {
        // Throw original item not found error.
        throw KeychainError.ItemNotFound(item: addressKey)
      }
    }

    return address
  }

  /// Retrieve the signing share stored in the client's keychain.
  /// - Returns: The client's signing share.
  override public func getSigningShare() throws -> String {
    let clientId = try getClientId()
    let shareKey = "\(clientId).share"
    var share: String

    do {
      share = try self.getItem(item: shareKey)
    } catch KeychainError.ItemNotFound(item: shareKey) {
      do {
        // Fallback to deprecated key.
        share = try self.getItem(item: self.deprecatedShareKey)
      } catch KeychainError.ItemNotFound(item: self.deprecatedShareKey) {
        // Throw original item not found error.
        throw KeychainError.ItemNotFound(item: shareKey)
      }
    }

    return share
  }

  /// Sets the address in the client's keychain.
  /// - Parameter address: The public address of the client's wallet.
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
  override public func deleteAddress() throws {
    let clientId = try getClientId()
    let addressKey = "\(clientId).address"

    try deleteItem(key: addressKey)
    try deleteItem(key: deprecatedAddressKey)
  }

  /// Deletes the signing share stored in the client's keychain.
  override public func deleteSigningShare() throws {
    let clientId = try getClientId()
    let shareKey = "\(clientId).share"

    try deleteItem(key: shareKey)
    try deleteItem(key: deprecatedShareKey)
  }

  /// Tests `setItem` in the client's keychain.
  public func validateOperations(completion: @escaping (Result<OSStatus>) -> Void) {
    do {
      let _ = try getClientId()
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
        try self.deleteItem(key: testKey)
        return completion(Result(data: result.data!))
      } catch {
        return completion(Result(error: error))
      }
    }
  }

  private func getItem(item: String) throws -> String {
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
    guard status != errSecItemNotFound else { throw KeychainError.ItemNotFound(item: item) }
    guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }

    // Attempt to format the keychain item as a string.
    guard let itemData = keychainItem as? Data,
          let itemString = String(data: itemData, encoding: String.Encoding.utf8)
    else {
      throw KeychainError.unexpectedItemData(item: item)
    }

    return itemString
  }

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
        try self.updateItem(key: key, value: value)
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

  private func updateItem(key: String, value: String) throws {
    // Construct the query to update the keychain item.
    let query: [String: AnyObject] = [
      kSecAttrService as String: "PortalMpc.\(key)" as AnyObject,
      kSecAttrAccount as String: key as AnyObject,
      kSecClass as String: kSecClassGenericPassword,
    ]

    // Construct the attributes to update the keychain item.
    let attributes: [String: AnyObject] = [
      kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly as AnyObject,
      kSecValueData as String: value.data(using: String.Encoding.utf8) as AnyObject,
    ]

    // Try to update the keychain item that matches the query.
    let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

    // Throw if the status is not successful.
    guard status != errSecItemNotFound else {
      throw KeychainError.ItemNotFound(item: key)
    }
    guard status != errSecNotAvailable else {
      throw KeychainError.keychainUnavailableOrNoPasscode(status: status)
    }
    guard status == errSecSuccess else {
      throw KeychainError.unhandledError(status: status)
    }
  }

  private func deleteItem(key: String) throws {
    let query: [String: AnyObject] = [
      kSecAttrService as String: "PortalMpc.\(key)" as AnyObject,
      kSecAttrAccount as String: key as AnyObject,
      kSecClass as String: kSecClassGenericPassword,
    ]

    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.unhandledError(status: status) }
  }

  private func getClientId() throws -> String {
    if self.clientId == nil {
      throw KeychainError.clientIdNotSetYet
    }

    return self.clientId!
  }
}
