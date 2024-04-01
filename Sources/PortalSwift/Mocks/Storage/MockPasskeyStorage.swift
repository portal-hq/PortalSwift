//
//  File.swift
//
//
//  Created by Blake Williams on 3/30/24.
//

import Foundation

@available(iOS 16, *)
class MockPasskeyStorage: PasskeyStorage {
  // Async decrypt implementation
  public func decrypt(_: String, withKey _: String) async throws -> String {
    return try MockConstants.mockMpcShareString
  }

  // Async delete implementation
  override public func delete() async throws -> Bool {
    return true
  }

  // Async encrypt implementation
  public func encrypt(_: String) async throws -> EncryptData {
    return MockConstants.mockEncryptData
  }

  // Async read implementation
  override public func read() async throws -> String {
    return MockConstants.mockEncryptionKey
  }

  // Async write implementation
  override public func write(_: String) async throws -> Bool {
    return true
  }

  override public func validateOperations() async throws -> Bool {
    return true
  }
}
