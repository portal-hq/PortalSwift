//
//  File.swift
//
//
//  Created by Blake Williams on 4/1/24.
//

import Foundation

public class MockPortalEncryption: PortalEncryption {
  override public func decrypt(_: String, withPrivateKey _: String) async throws -> String {
    let data = try JSONEncoder().encode(MockConstants.mockGenerateResponse)
    guard let generateResponse = String(data: data, encoding: .utf8) else {
      throw PortalEncryptionError.unableToEncodeData
    }
    return generateResponse
  }

  override public func decrypt(_: String, withPassword _: String) async throws -> String {
    let data = try JSONEncoder().encode(MockConstants.mockGenerateResponse)
    guard let generateResponse = String(data: data, encoding: .utf8) else {
      throw PortalEncryptionError.unableToEncodeData
    }
    return generateResponse
  }

  override public func encrypt(_: String) async throws -> EncryptData {
    return MockConstants.mockEncryptData
  }

  override public func encrypt(_: String, withPassword _: String) async throws -> String {
    return MockConstants.mockCiphertext
  }
}
