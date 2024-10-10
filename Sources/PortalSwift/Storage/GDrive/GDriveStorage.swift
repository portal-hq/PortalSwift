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
  public var api: PortalApiProtocol?
  public var clientId: String? {
    get { return self.drive.clientId }
    set(clientId) { self.drive.clientId = clientId }
  }

  public let encryption: PortalEncryptionProtocol
  public var folder: String {
    get { return self.drive.folder }
    set(folder) { self.drive.folder = folder }
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

  public init(
    clientID: String? = nil,
    viewController: UIViewController? = nil,
    encryption: PortalEncryptionProtocol? = nil,
    driveClient: GDriveClientProtocol? = nil
  ) {
    self.drive = driveClient ?? GDriveClient(clientId: clientID, view: viewController)
    self.encryption = encryption ?? PortalEncryption()
  }

  /*******************************************
   * Public functions
   *******************************************/

  public func delete() async throws -> Bool {
    let filename = try await getFilename()
    let fileId = try await drive.getIdForFilename(filename)

    return try await self.drive.delete(fileId)
  }

  public func read() async throws -> String {
    let filename = try await getFilename()
    let fileId = try await drive.getIdForFilename(filename)

    let fileContents = try await drive.read(fileId)

    return fileContents
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

  public func write(_ value: String) async throws -> Bool {
    let filename = try await getFilename()

    return try await self.drive.write(filename, withContent: value)
  }

  /*******************************************
   * Private functions
   *******************************************/

  func getFilename() async throws -> String {
    guard let api = self.api else {
      throw GDriveStorageError.portalApiNotConfigured
    }

    if self.filename == nil || self.filename == "" {
      guard let client = try await api.client else {
        throw GDriveStorageError.unableToGetClient
      }

      let name = GDriveStorage.hash("\(client.custodian.id)\(client.id)")
      self.filename = "\(name).txt"

      print("Filename: \(self.filename ?? "")")
    }

    return self.filename!
  }

  static func hash(_ str: String) -> String {
    let data = str.data(using: .utf8)!
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    data.withUnsafeBytes {
      _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
    }
    return Data(digest).map { String(format: "%02hhx", $0) }.joined()
  }
}

public enum GDriveStorageError: Error, Equatable {
  case portalApiNotConfigured
  case unableToFetchClientData
  case unableToGetClient
  case unknownError
}
