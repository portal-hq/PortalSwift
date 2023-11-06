//
//  GDriveStorage.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import CommonCrypto
import Foundation

import GoogleSignIn

public enum GDriveStorageError: Error {
  case portalApiNotConfigured
  case unableToFetchClientData
  case unknownError
}

public class GDriveStorage: Storage {
  public var accessToken: String?
  public var api: PortalApi?
  private var drive: GDriveClient
  private var filename: String?
  private var separator: String = ""

  public init(clientID: String, viewController: UIViewController) {
    self.drive = GDriveClient(clientId: clientID, view: viewController)
  }

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

  public func signIn(completion: @escaping (Result<GIDGoogleUser>) -> Void) {
    self.drive.auth.signIn { result in
      completion(result)
    }
  }

  public func validateOperations(callback: @escaping (Result<Bool>) -> Void) {
    self.drive.validateOperations(callback: callback)
  }

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

  private static func hash(_ str: String) -> String {
    let data = str.data(using: .utf8)!
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    data.withUnsafeBytes {
      _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
    }
    return Data(digest).map { String(format: "%02hhx", $0) }.joined()
  }
}
