//
//  MockPortalKeychainAccess.swift
//
//
//  Created by Blake Williams on 3/31/24.
//

import Foundation

public class MockPortalKeychainAccess: PortalKeychainAccess {
  private let encoder = JSONEncoder()
  private var keychainData: [String: String] = [:]

  override public init() {}

  override public func addItem(_ key: String, value: String) throws {
    keychainData[key] = value
  }
  
  override public func deleteItem(_ key: String) throws {
    keychainData[key] = nil
  }

  override public func getItem(_ key: String) throws -> String {
    let keyParts = key.split(separator: ".").map(String.init)
    let keyType = keyParts.last
    switch keyType {
      case "metadata":
        let metadataData = try encoder.encode(MockConstants.mockKeychainClientMetadata)
        guard let metadataString = String(data: metadataData, encoding: .utf8) else {
          throw PortalKeychainAccessError.unexpectedItemData("Unable to encode data.")
        }
        return metadataString
      case "shares":
        let sharesData = try encoder.encode(MockConstants.mockGenerateResponse)
        guard let sharesString = String(data: sharesData, encoding: .utf8) else {
          throw PortalKeychainAccessError.unexpectedItemData("Unable to encode data.")
        }
        return sharesString
      case "testKey":
        if let value = keychainData[key] {
          return value
        } else {
          throw PortalKeychainAccessError.itemNotFound(key)
        }
      default:
        throw PortalKeychainAccessError.itemNotFound(key)
    }
  }

  override public func updateItem(_ key: String, value: String) throws {
    if keychainData[key] != nil {
      keychainData[key] = value
    } else {
      throw PortalKeychainAccessError.itemNotFound(key)
    }
  }
}
