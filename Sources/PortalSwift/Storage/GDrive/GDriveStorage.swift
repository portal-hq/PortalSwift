//
//  GDriveStorage.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import CommonCrypto
import Foundation

import GoogleSignIn

public class GDriveStorage: Storage, PortalStorage {
  public var accessToken: String?
  public weak var api: PortalApiProtocol?
  public var clientId: String? {
    get { return self.drive.clientId }
    set(clientId) { self.drive.clientId = clientId }
  }

  public let encryption: PortalEncryptionProtocol
  public var mobile: Mobile?
  public var folder: String {
    get { return self.drive.folder }
    set(folder) { self.drive.folder = folder }
  }

  var useAppDataFolderForBackup: Bool {
    get { return self.drive.useAppDataFolderForBackup ?? false }
    set(useAppDataFolderForBackup) { self.drive.useAppDataFolderForBackup = useAppDataFolderForBackup }
  }

  public var view: UIViewController? {
    get {
      return self.drive.view
    }
    set(view) {
      self.drive.view = view
    }
  }

  private var drive: GDriveClientProtocol
  private var filename: String?
  private var logger = PortalLogger()
  private var separator: String = ""
  private var filenameHashes: [String: String]?

  public init(
    mobile: Mobile? = nil,
    clientID: String? = nil,
    viewController: UIViewController? = nil,
    encryption: PortalEncryptionProtocol? = nil,
    driveClient: GDriveClientProtocol? = nil
  ) {
    self.mobile = mobile
    self.drive = driveClient ?? GDriveClient(clientId: clientID, view: viewController)
    self.encryption = encryption ?? PortalEncryption()
  }

  /*******************************************
   * Public functions
   *******************************************/

  public func delete() async throws -> Bool {
    let hashes = try await getFilenameHashes()

    for hash in hashes.values {
      if let fileId = try? await drive.getIdForFilename(hash, useAppDataFolderForBackup: useAppDataFolderForBackup) {
        if try await self.drive.delete(fileId) {
          return true
        }
      }
    }

    throw GDriveStorageError.unableToDeleteFile
  }

  public func read() async throws -> String {
    let hashes = try await getFilenameHashes()

    do {
      var recoveredFiles: [String: String] = [:]
      var shouldReadFromAppDataFolder: Bool = useAppDataFolderForBackup
      do {
        // try the default folder depending on the `useAppDataFolderForBackup` flag value
        recoveredFiles = try await drive.recoverFiles(for: hashes, useAppDataFolderForBackup: shouldReadFromAppDataFolder)
      } catch {
        // if the default folder failed try the other folder.
        shouldReadFromAppDataFolder.toggle()
        recoveredFiles = try await drive.recoverFiles(for: hashes, useAppDataFolderForBackup: shouldReadFromAppDataFolder)
      }

      // Prioritize default file if available
      if let defaultFile = recoveredFiles["default"] {
        return defaultFile
      }

      // If iOS file is not available, return content of any recovered file
      if let anyContent = recoveredFiles.values.first {
        return anyContent
      }

      // This should never happen because recoverFiles throws an error if no files are recovered
      throw GDriveStorageError.unableToReadFile
    } catch let GDriveClientError.unableToRecoverAnyFiles(errors) {
      self.logger.error("GDriveStorage.read() - Unable to recover any files. Errors: \(errors)")
      throw GDriveStorageError.unableToReadFile
    } catch {
      self.logger.error("GDriveStorage.read() - Unexpected error: \(error)")
      throw GDriveStorageError.unableToReadFile
    }
  }

  public func write(_ value: String) async throws -> Bool {
    let filename = try await getDefaultFilename()
    return try await self.drive.write(filename, withContent: value)
  }

  public func signIn() async throws -> GIDGoogleUser {
    guard let auth = drive.auth else {
      self.logger.debug("GDriveStorage.signIn() - ❌ Authentication not initialized. GDrive config has not been set yet.")
      throw GDriveClientError.authenticationNotInitialized("Please call Portal.setGDriveConfiguration() to configure GoogleDrive")
    }

    return try await auth.signIn()
  }

  public func validateOperations() async throws -> Bool {
    return try await self.drive.validateOperations()
  }

  /*******************************************
   * Private functions
   *******************************************/
  private func getFilenameHashes() async throws -> [String: String] {
    guard let api = self.api else {
      throw GDriveStorageError.portalApiNotConfigured
    }

    guard let client = try await api.client else {
      throw GDriveStorageError.unableToGetClient
    }

    let custodianId = client.custodian.id
    let clientId = client.id
    self.filenameHashes = try await self.fetchFileHashes(custodianId: custodianId, clientId: clientId)

    return self.filenameHashes!
  }

  private func getDefaultFilename() async throws -> String {
    let hashes = try await getFilenameHashes()
    guard let defaultHash = hashes["default"] else {
      throw GDriveStorageError.unableToFetchDefaultHash
    }
    return defaultHash
  }

  private func fetchFileHashes(custodianId: String, clientId: String) async throws -> [String: String] {
    let input = [
      "custodianId": custodianId,
      "clientId": clientId
    ]

    guard let mobile = self.mobile else {
      throw GDriveStorageError.binaryNotConfigured
    }

    guard let inputJSON = try? JSONSerialization.data(withJSONObject: input),
          let inputJSONString = String(data: inputJSON, encoding: .utf8)
    else {
      throw GDriveStorageError.unableToFetchClientData
    }

    let hashesJSON = mobile.MobileGetCustodianIdClientIdHashes(inputJSONString)

    guard let hashesData = hashesJSON.data(using: .utf8) else {
      throw GDriveStorageError.unableToFetchClientData
    }

    do {
      let response = try JSONDecoder().decode(CustodianIDClientIDHashesResponse.self, from: hashesData)

      if let error = response.error {
        self.logger.error("GDriveStorage.fetchFileHashes() - \(error.message)")
        throw GDriveStorageError.unableToFetchClientData
      }

      guard let hashes = response.data else {
        throw GDriveStorageError.unableToFetchClientData
      }

      return hashes.toMap()
    } catch {
      if let decodingError = error as? DecodingError {
        self.logger.error("GDriveStorage.fetchFileHashes() - Decoding Error: \(decodingError)")
      }
      throw GDriveStorageError.unableToFetchClientData
    }
  }
}

struct CustodianIDClientIDHashesResponse: Codable {
  let data: CustodianIDClientIDHashes?
  let error: CustodianIDClientIDHashesResponseError?
}

struct CustodianIDClientIDHashesResponseError: Codable {
  let code: Int
  let message: String
}

struct CustodianIDClientIDHashes: Codable {
  let android, defaultHash, ios, reactNative, webSDK: String

  enum CodingKeys: String, CodingKey {
    case android
    case defaultHash = "default"
    case ios
    case reactNative = "react_native"
    case webSDK = "web_sdk"
  }

  func toMap() -> [String: String] {
    return [
      "android": self.android,
      "default": self.defaultHash,
      "ios": self.ios,
      "react_native": self.reactNative,
      "web_sdk": self.webSDK
    ]
  }
}

public enum GDriveStorageError: LocalizedError, Equatable {
  case portalApiNotConfigured
  case binaryNotConfigured
  case unableToFetchClientData
  case unableToGetClient
  case unableToDeleteFile
  case unableToReadFile
  case unableToFetchDefaultHash
  case unknownError
}
