//
//  GDriveClientSpy.swift
//
//
//  Created by Ahmed Ragab on 26/09/2024.
//

@testable import PortalSwift
import UIKit

class GDriveClientSpy: GDriveClientProtocol {
  var backupOption: PortalSwift.GDriveBackupOption?

  var auth: PortalSwift.GoogleAuth? = nil

  var clientId: String? = nil

  var folder: String = ""

  var view: UIViewController? = nil

  var deleteCallsCount: Int = 0
  var deleteKeyParam: String? = nil
  var deleteReturnValue: Bool = true

  func delete(_ key: String) async throws -> Bool {
    deleteCallsCount += 1
    deleteKeyParam = key
    return deleteReturnValue
  }

  var getAccessTokenCallsCount: Int = 0
  var getAccessTokenReturnValue: String = ""

  func getAccessToken() async throws -> String {
    getAccessTokenCallsCount += 1
    return getAccessTokenReturnValue
  }

  var getIdForFilenameCallsCount: Int = 0
  var getIdForFilenameFilenameParam: String?
  var getIdForFilenameUseAppDataFolderParam: Bool?
  var getIdForFilenameReturnValue: String = ""

  func getIdForFilename(_ filename: String, useAppDataFolder: Bool) async throws -> String {
    getIdForFilenameCallsCount += 1
    getIdForFilenameFilenameParam = filename
    getIdForFilenameUseAppDataFolderParam = useAppDataFolder
    return getIdForFilenameReturnValue
  }

  var readCallsCount: Int = 0
  var readIdParam: String?
  var readReturnValue: String = ""

  func read(_ id: String) async throws -> String {
    readCallsCount += 1
    readIdParam = id
    return readReturnValue
  }

  var validateOperationsCallsCount: Int = 0
  var validateOperationsReturnValue: Bool = true

  func validateOperations() async throws -> Bool {
    validateOperationsCallsCount += 1
    return validateOperationsReturnValue
  }

  var writeCallsCount: Int = 0
  var writeFilenameParam: String?
  var writeWithContentParam: String?
  var writeReturnValue: Bool = true

  func write(_ filename: String, withContent: String) async throws -> Bool {
    writeCallsCount += 1
    writeFilenameParam = filename
    writeWithContentParam = withContent
    return writeReturnValue
  }

  var recoverFilesCallsCount: Int = 0
  var recoverFilesHashesParam: [String: String]?
  var recoverFilesUseAppDataFolderParam: Bool?
  var recoverFilesReturnValue: [String: String] = ["default": "123456789.txt"]

  func recoverFiles(for hashes: [String: String], useAppDataFolder: Bool) async throws -> [String: String] {
    recoverFilesCallsCount += 1
    recoverFilesHashesParam = hashes
    recoverFilesUseAppDataFolderParam = useAppDataFolder
    return recoverFilesReturnValue
  }
}
