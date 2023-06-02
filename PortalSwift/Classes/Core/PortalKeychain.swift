//
//  PortalKeychain.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// The main interface for Portal to securely store the client's signing share.
public class PortalKeychain: MobileStorageAdapter {
  let Address = "PortalMpc.Address"
  let SigningShare = "PortalMpc.DkgResult"
  
  enum KeychainError: Error {
    case ItemNotFound(item: String)
    case ItemAlreadyExists(item: String)
    case unexpectedItemData(item: String)
    case unhandledError(status: OSStatus)
    case keychainUnavailableOrNoPasscode(status: OSStatus)
  }
  
  /// Creates an instance of PortalKeychain.
  override public init() {}
  
  /// Retrieve the address stored in the client's keychain.
  /// - Returns: The client's address.
  override public func getAddress() throws -> String {
    return try getItem(item: Address)
  }
  
  /// Retrieve the signing share stored in the client's keychain.
  /// - Returns: The client's signing share.
  override public func getSigningShare() throws -> String {
    return try getItem(item: SigningShare)
    
  }
  
  /// Sets the address in the client's keychain.
  /// - Parameter address: The public address of the client's wallet.
  override public func setAddress(
    address: String,
    completion: (Result<OSStatus>) -> Void
  ) {
    setItem(key: Address, value: address) { result in
      // Handle errors
      guard result.error == nil else {
        return completion(Result(error: result.error!))
      }
      
      return completion(Result(data: result.data!))
    }
  }
  
  /// Sets the signing share in the client's keychain.
  /// - Parameter signingShare: A dkg object.
  override public func setSigningShare(
    signingShare: String,
    completion: (Result<OSStatus>) -> Void
  ) -> Void {
    setItem(key: SigningShare, value: signingShare) { result in
      // Handle errors
      guard result.error == nil else {
        return completion(Result(error: result.error!))
      }
      
      return completion(Result(data: result.data!))
    }
  }
  
  /// Deletes the address stored in the client's keychain.
  /// - Returns: The client's address.
  override public func deleteAddress() throws {
    try deleteItem(key: Address)
  }
  
  /// Deletes the signing share stored in the client's keychain.
  /// - Returns: The client's signing share.
  override public func deleteSigningShare() throws {
    try deleteItem(key: SigningShare)
  }
  
  /// Tests `setItem` in the client's keychain.
  public func validateOperations(completion: (Result<OSStatus>) -> Void) {
    let testKey = "portal_test"
    let testValue = "test_value"
    setItem(key: testKey, value: testValue) { [weak self] result in
      // Handle errors.
      guard result.error == nil else {
        return completion(Result(error: result.error!))
      }
      
      do {
        // Delete the key that was created.
        try self?.deleteItem(key: testKey)
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
      kSecReturnData as String: true
    ]
    
    // Try to retrieve the keychain item that matches the query.
    var keychainItem: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &keychainItem)
    
    // Throw if the status is not successful.
    guard status != errSecItemNotFound else { throw KeychainError.ItemNotFound(item: item)}
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
    completion: (Result<OSStatus>) -> Void
  ) -> Void {
    do {
      // Construct the query to set the keychain item.
      let query: [String: AnyObject] = [
        kSecAttrService as String: "PortalMpc.\(key)" as AnyObject,
        kSecAttrAccount as String: key as AnyObject,
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly as AnyObject,
        kSecValueData as String: value.data(using: String.Encoding.utf8) as AnyObject
      ]
      
      // Try to set the keychain item that matches the query.
      let status = SecItemAdd(query as CFDictionary, nil)
      
      // Throw if the status is not successful.
      if (status == errSecDuplicateItem) {
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
      kSecClass as String: kSecClassGenericPassword
    ]
    
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.unhandledError(status: status) }
  }
}
