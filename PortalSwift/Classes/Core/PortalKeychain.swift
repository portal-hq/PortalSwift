//
//  PortalKeychain.swift
//  FBSnapshotTestCase
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public class PortalKeychain {
      
    let Address = "address"
    let SigningShare = "signingShare"


  enum KeychainError: Error {
    case ItemNotFound(item: String)
    case ItemAlreadyExists(item: String)
    case unexpectedItemData(item: String)
    case unhandledError(status: OSStatus)
  }
  
  public init() {}
  
  /// Retrieve the address stored in the users keychain
  /// - Returns: Address
  public func getAddress() throws -> String {
    return try getItem(item: Address)
  }
  
  /// Retrieve the signing share stored in the users keychain
  /// - Returns: signingShare
  public func getSigningShare() throws -> String {
    return try getItem(item: SigningShare)

  }
  
  /// Sets the address in the users keychain
  /// - Parameter address: the address of the MPC wallet
  /// - Returns: true or throws an error
  public func setAddress(address: String) throws {
    try setItem(key: Address, value: address)
  }
  
  /// Sets the signing share in the users keychain
  /// - Parameter signingShare: A dkg object
  /// - Returns: true or throws an error
  public func setSigningShare(signingShare: String) throws  {
    try setItem(key: SigningShare, value: signingShare)
  }
  
  private func getItem(item: String) throws -> String {
    let query: [String: Any] = [
                                kSecClass as String: kSecClassGenericPassword,
                                kSecAttrAccount as String: item,
                                kSecAttrService as String: "PortalMpc.\(item)",
                                kSecMatchLimit as String: kSecMatchLimitOne,
                                kSecReturnData as String: true]
    var keychainItem: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &keychainItem)
    guard status != errSecItemNotFound else { throw KeychainError.ItemNotFound(item: item)}
    guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }
    
    guard let itemData = keychainItem as? Data,
        let itemString = String(data: itemData, encoding: String.Encoding.utf8)
    else {
      throw KeychainError.unexpectedItemData(item: item)
    }
    return itemString
  }
  
  private func setItem(key: String, value: String) throws {
    let query: [String: AnyObject] = [
        kSecAttrService as String: "PortalMpc.\(key)" as AnyObject,
        kSecAttrAccount as String: key as AnyObject,
        kSecClass as String: kSecClassGenericPassword,
        kSecValueData as String: value.data(using: String.Encoding.utf8) as AnyObject
    ]
    let status = SecItemAdd(query as CFDictionary, nil)
    if (status == errSecDuplicateItem) { return try self.updateItem(key: key, value: value) }
    guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }
  }
  
  private func updateItem(key: String, value: String) throws {
    let query: [String: AnyObject] = [
      kSecAttrService as String: "PortalMpc.\(key)" as AnyObject,
      kSecAttrAccount as String: key as AnyObject,
        kSecClass as String: kSecClassGenericPassword
    ]
    
    let attributes: [String: AnyObject] = [
        kSecValueData as String: value.data(using: String.Encoding.utf8) as AnyObject
    ]

    let status = SecItemUpdate(
        query as CFDictionary,
        attributes as CFDictionary
    )
    
    guard status != errSecItemNotFound else {
         throw KeychainError.ItemNotFound(item: key)
     }
    
    guard status == errSecSuccess else {
        throw KeychainError.unhandledError(status: status)
    }
  }
  

}

