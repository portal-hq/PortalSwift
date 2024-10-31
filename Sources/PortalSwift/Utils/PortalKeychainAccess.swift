//
//  PortalKeychainAccess.swift
//
//
//  Created by Blake Williams on 3/31/24.
//

import Foundation

public protocol PortalKeychainAccessProtocol {
  func addItem(_ key: String, value: String) throws
  func deleteItem(_ key: String) throws
  func getItem(_ key: String) throws -> String
  func updateItem(_ key: String, value: String) throws
}

public class PortalKeychainAccess: PortalKeychainAccessProtocol {
  private let baseKey = "PortalMpc"
  private let logger = PortalLogger()

  public func addItem(_ key: String, value: String) throws {
    // Construct the query to set the keychain item.
    let query: [String: AnyObject] = [
      kSecAttrService as String: "\(self.baseKey).\(key)" as AnyObject,
      kSecAttrAccount as String: key as AnyObject,
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly as AnyObject,
      kSecValueData as String: value.data(using: String.Encoding.utf8) as AnyObject
    ]

    // Try to set the keychain item that matches the query.
    let status = SecItemAdd(query as CFDictionary, nil)

    // Throw if the status is not successful.
    if status == errSecDuplicateItem {
      try self.updateItem(key, value: value)
    }

    guard status != errSecNotAvailable else {
      self.logger.error("PortalKeychain.updateItem() - Keychain unavailable: \(status)")
      throw PortalKeychainAccessError.keychainUnavailableOrNoPasscode(status)
    }
    guard status == errSecSuccess else {
      self.logger.error("PortalKeychain.updateItem() - Unhandled error: \(status)")
      throw PortalKeychainAccessError.unhandledError(status)
    }
  }

  public func deleteItem(_ key: String) throws {
    let query: [String: AnyObject] = [
      kSecAttrService as String: "\(self.baseKey).\(key)" as AnyObject,
      kSecAttrAccount as String: key as AnyObject,
      kSecClass as String: kSecClassGenericPassword
    ]

    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      self.logger.error("PortalKeychain.updateItem() - Unhandled error: \(status)")
      throw PortalKeychainAccessError.unhandledError(status)
    }
  }

  public func getItem(_ key: String) throws -> String {
    // Construct the query to retrieve the keychain item.
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
      kSecAttrService as String: "\(self.baseKey).\(key)",
      kSecMatchLimit as String: kSecMatchLimitOne,
      kSecReturnData as String: true
    ]

    // Try to retrieve the keychain item that matches the query.
    var keychainItem: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &keychainItem)

    // Throw if the status is not successful.
    guard status != errSecItemNotFound else { throw PortalKeychainAccessError.itemNotFound(key) }
    guard status == errSecSuccess else { throw PortalKeychainAccessError.unhandledError(status) }

    // Attempt to format the keychain item as a string.
    guard let data = keychainItem as? Data,
          let value = String(data: data, encoding: String.Encoding.utf8)
    else {
      self.logger.error("PortalKeychain.getItem() - Unexpected item: \(key)")
      throw PortalKeychainAccessError.unexpectedItemData(key)
    }

    return value
  }

  public func updateItem(_ key: String, value: String) throws {
    do {
      // Construct the query to update the keychain item.
      let query: [String: AnyObject] = [
        kSecAttrService as String: "\(self.baseKey).\(key)" as AnyObject,
        kSecAttrAccount as String: key as AnyObject,
        kSecClass as String: kSecClassGenericPassword
      ]

      // Construct the attributes to update the keychain item.
      let attributes: [String: AnyObject] = [
        kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly as AnyObject,
        kSecValueData as String: value.data(using: String.Encoding.utf8) as AnyObject
      ]

      // Try to update the keychain item that matches the query.
      let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

      // Throw if the status is not successful.
      guard status != errSecItemNotFound else {
        throw PortalKeychainAccessError.itemNotFound(key)
      }
      guard status != errSecNotAvailable else {
        self.logger.error("PortalKeychain.updateItem() - Keychain unavailable: \(status)")
        throw PortalKeychainAccessError.keychainUnavailableOrNoPasscode(status)
      }
      guard status == errSecSuccess else {
        self.logger.error("PortalKeychain.updateItem() - Unhandled error: \(status)")
        throw PortalKeychainAccessError.unhandledError(status)
      }
    } catch {
      if case PortalKeychainAccessError.itemNotFound = error {
        self.logger.debug("PortalKeychain.updateItem() - No existing item. Attempting to set item: \(key)")
        try self.addItem(key, value: value)
      } else {
        throw error
      }
    }
  }
}

enum PortalKeychainAccessError: LocalizedError {
  case itemNotFound(String)
  case keychainUnavailableOrNoPasscode(OSStatus)
  case unexpectedItemData(String)
  case unhandledError(OSStatus)
}
