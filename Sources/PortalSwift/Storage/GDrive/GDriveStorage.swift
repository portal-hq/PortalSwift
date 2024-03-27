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

      print("Filename: \(self.filename ?? "")")
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
    async {
      do {
        let success = try await delete()
        completion(Result(data: success))
      } catch {
        completion(Result(error: error))
      }
    }
  }

  @available(*, deprecated, renamed: "read", message: "Please use the async/await implementation of read().")
  override public func read(completion: @escaping (Result<String>) -> Void) {
    async {
      do {
        let value = try await read()
        completion(Result(data: value))
      } catch {
        completion(Result(error: error))
      }
    }
  }

  @available(*, deprecated, renamed: "write", message: "Please use the async/await implementation of write().")
  override public func write(privateKey: String, completion: @escaping (Result<Bool>) -> Void) {
    async {
      do {
        let success = try await write(privateKey)
        completion(Result(data: success))
      } catch {
        completion(Result(error: error))
      }
    }
  }

  @available(*, deprecated, renamed: "signIn", message: "Please use the async/await implementation of signIn().")
  public func signIn(completion: @escaping (Result<GIDGoogleUser>) -> Void) {
    async {
      do {
        let user = try await drive.auth.signIn()
        completion(Result(data: user))
      } catch {
        completion(Result(error: error))
      }
    }
  }

  @available(*, deprecated, renamed: "validateOperations", message: "Please use the async/await implementation of validateOperations().")
  public func validateOperations(callback: @escaping (Result<Bool>) -> Void) {
    async {
      do {
        let success = try await drive.validateOperations()
        callback(Result(data: success))
      } catch {
        callback(Result(error: error))
      }
    }
  }
}

public enum GDriveStorageError: Error, Equatable {
  case portalApiNotConfigured
  case unableToFetchClientData
  case unableToGetClient
  case unknownError
}
