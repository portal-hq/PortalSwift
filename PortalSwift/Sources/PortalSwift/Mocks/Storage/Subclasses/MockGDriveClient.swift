//
//  MockGDriveClient.swift
//
//
//  Created by Blake Williams on 3/30/24.
//

import Foundation

class MockGDriveClient: GDriveClient {
  override public func delete(_: String) async throws -> Bool {
    return true
  }

  override public func getAccessToken() async throws -> String {
    return MockConstants.mockGoogleAccessToken
  }

  override public func getIdForFilename(_: String) async throws -> String {
    return MockConstants.mockGDriveFileId
  }

  override public func read(_: String) async throws -> String {
    return MockConstants.mockEncryptionKey
  }

  override public func validateOperations() async throws -> Bool {
    return true
  }

  override public func write(_: String, withContent _: String) async throws -> Bool {
    return true
  }
}
