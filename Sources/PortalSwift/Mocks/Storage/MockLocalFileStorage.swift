//
//  MockLocalFileStorage.swift
//
//
//  Created by Blake Williams on 3/30/24.
//

import Foundation

class MockLocalFileStorage: LocalFileStorage {
  // Async decrypt implementation
  public func decrypt(_: String, withKey _: String) async throws -> String {
    return try MockConstants.mockMpcShareString
  }

  // Async delete implementation
  override public func delete() async throws -> Bool {
    return true
  }

  // Completion delete implementation
  override public func delete(completion: @escaping (Result<Bool>) -> Void) {
    completion(Result(data: true))
  }

  // Async encrypt implementation
  public func encrypt(_: String) async throws -> EncryptData {
    return MockConstants.mockEncryptData
  }

  // Async read implementation
  override public func read() async throws -> String {
    return MockConstants.mockEncryptionKey
  }

  // Completion read implementation
  override public func read(completion: @escaping (Result<String>) -> Void) {
    completion(Result(data: MockConstants.mockEncryptionKey))
  }

  // Async write implementation
  override public func write(_: String) async throws -> Bool {
    return true
  }

  // Completion write implementation
  override public func write(privateKey _: String, completion: @escaping (Result<Bool>) -> Void) {
    completion(Result(data: true))
  }
}
