//
//  MockPortalKeychainAccess.swift
//
//
//  Created by Blake Williams on 3/31/24.
//

import Foundation

public class MockPortalKeychainAccess: PortalKeychainAccessProtocol {
  private let encoder = JSONEncoder()

  public init() {}

  public func addItem(_: String, value _: String) throws {}

  public func deleteItem(_: String) throws {}

  public func getItem(_ key: String) throws -> String {
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
    default:
      throw PortalKeychainAccessError.itemNotFound(key)
    }
  }

  public func updateItem(_: String, value _: String) throws {}
}
