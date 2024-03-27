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
  public var api: PortalApi?
  private var drive: GDriveClient
  private var filename: String?
  private var separator: String = ""

  public var view: UIViewController? {
    get {
      return self.drive.auth.view
    }
    set(view) {
      self.drive.auth.view = view
    }
  }

  public init(clientID: String, viewController: UIViewController? = nil) {
    self.drive = GDriveClient(clientId: clientID, view: viewController)
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
    return try await self.drive.auth.signIn()
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

  private func getFilename() async throws -> String {
    guard let api = self.api else {
      throw GDriveStorageError.portalApiNotConfigured
    }

    if self.filename == nil || self.filename == "" {
      guard let client = await api.client else {
        throw GDriveStorageError.unableToGetClient
      }

      let name = GDriveStorage.hash("\(client.custodian.id)\(client.id)")
      self.filename = "\(name).txt"
    }

    return self.filename!
  }

  private static func hash(_ str: String) -> String {
    let data = str.data(using: .utf8)!
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    data.withUnsafeBytes {
      _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
    }
    return Data(digest).map { String(format: "%02hhx", $0) }.joined()
  }

  /*******************************************
   * Deprecated functions
   *******************************************/

  @available(*, deprecated, renamed: "delete", message: "Please use the async/await implementation of delete().")
  override public func delete(completion: @escaping (Result<Bool>) -> Void) {
    self.getFilename { filename in
      if filename.error != nil {
        completion(Result(data: false, error: filename.error!))
        return
      }

      do {
        try self.drive.getIdForFilename(filename: filename.data!) { fileId in
          if fileId.error != nil {
            completion(Result(data: false, error: fileId.error!))
            return
          }

          self.drive.delete(id: fileId.data!) { deleteResult in
            completion(deleteResult)
          }
        }
      } catch {
        completion(Result(error: error))
      }
    }
  }

  @available(*, deprecated, renamed: "read", message: "Please use the async/await implementation of read().")
  override public func read(completion: @escaping (Result<String>) -> Void) {
    self.getFilename { filename in
      if filename.error != nil {
        completion(Result(error: filename.error!))
        return
      }

      do {
        try self.drive.getIdForFilename(filename: filename.data!) { fileId in
          if fileId.error != nil {
            completion(Result(error: fileId.error!))
            return
          }

          self.drive.read(id: fileId.data!) { content in
            if content.error != nil {
              completion(Result(error: content.error!))
              return
            }

            completion(Result(data: content.data!))
          }
        }
      } catch {
        completion(Result(error: error))
      }
    }
  }

  @available(*, deprecated, renamed: "write", message: "Please use the async/await implementation of write().")
  override public func write(privateKey: String, completion: @escaping (Result<Bool>) -> Void) {
    self.getFilename { filename in
      if filename.error != nil {
        completion(Result(data: false, error: filename.error!))
        return
      }

      do {
        try self.drive.write(filename: filename.data!, content: privateKey) { writeResult in
          if writeResult.error != nil {
            completion(Result(data: false, error: writeResult.error!))
            return
          }

          completion(Result(data: true))
        }
      } catch {
        completion(Result(data: false, error: error))
      }
    }
  }

  @available(*, deprecated, renamed: "signIn", message: "Please use the async/await implementation of signIn().")
  public func signIn(completion: @escaping (Result<GIDGoogleUser>) -> Void) {
    self.drive.auth.signIn { result in
      completion(result)
    }
  }

  @available(*, deprecated, renamed: "validateOperations", message: "Please use the async/await implementation of validateOperations().")
  public func validateOperations(callback: @escaping (Result<Bool>) -> Void) {
    self.drive.validateOperations(callback: callback)
  }

  @available(*, deprecated, renamed: "getFilename", message: "Please use the async/await implementation of getFilename().")
  private func getFilename(callback: @escaping (Result<String>) -> Void) {
    if self.api == nil {
      callback(Result(error: GDriveStorageError.portalApiNotConfigured))
      return
    }

    do {
      if self.filename == nil || self.filename!.count < 1 {
        try self.api!.getClient { client in
          if client.error != nil {
            callback(Result(error: client.error!))
            return
          } else if client.data == nil {
            callback(Result(error: GDriveStorageError.unableToFetchClientData))
            return
          }

          let name = GDriveStorage.hash(
            "\(client.data!.custodian.id)\(client.data!.id)"
          )

          self.filename = "\(name).txt"

          callback(Result(data: self.filename!))
        }
      } else {
        callback(Result(data: self.filename!))
      }
    } catch {
      callback(Result(error: error))
    }
  }
}

public enum GDriveStorageError: Error, Equatable {
  case portalApiNotConfigured
  case unableToFetchClientData
  case unableToGetClient
  case unknownError
}
