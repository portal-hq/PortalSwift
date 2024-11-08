//
//  MockGDriveClient.swift
//
//
//  Created by Blake Williams on 3/30/24.
//

import UIKit

class MockGDriveClient: GDriveClientProtocol {
  var useAppDataFolderForBackup: Bool?

  var auth: GoogleAuth? = nil

  var clientId: String? = nil

  var folder: String = ""

  var view: UIViewController? = nil

  public func delete(_: String) async throws -> Bool {
    return true
  }

  public func getAccessToken() async throws -> String {
    return MockConstants.mockGoogleAccessToken
  }

  public func getIdForFilename(_: String, useAppDataFolderForBackup _: Bool) async throws -> String {
    return MockConstants.mockGDriveFileId
  }

  public func read(_: String) async throws -> String {
    return MockConstants.mockEncryptionKey
  }

  public func validateOperations() async throws -> Bool {
    return true
  }

  public func write(_: String, withContent _: String) async throws -> Bool {
    return true
  }

  func recoverFiles(for _: [String: String], useAppDataFolderForBackup _: Bool) async throws -> [String: String] {
    return [:]
  }
}
