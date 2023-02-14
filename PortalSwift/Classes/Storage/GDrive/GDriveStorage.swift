//
//  GDriveStorage.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

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
    drive = GDriveClient(clientId: clientID, view: viewController)
  }

  public override func delete(completion: @escaping (Result<Bool>) -> Void) -> Void {
    getFilename() { filename in
      if (filename.error != nil) {
        completion(Result(data: false, error: filename.error!))
        return
      }
      
      do {
        try self.drive.getIdForFilename(filename: filename.data!) { fileId in
          if (fileId.error != nil) {
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

  public override func read(completion: @escaping (Result<String>) -> Void) -> Void {
    getFilename() { filename in
      if (filename.error != nil) {
        completion(Result(error: filename.error!))
        return
      }
      
      do {
        try self.drive.getIdForFilename(filename: filename.data!) { fileId in
          if (fileId.error != nil) {
            completion(Result(error: fileId.error!))
            return
          }
          
          self.drive.read(id: fileId.data!) { content in
            if (content.error != nil) {
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

  public override func write(privateKey: String, completion: @escaping (Result<Bool>) -> Void) -> Void {
    getFilename() { filename in
      if (filename.error != nil) {
        completion(Result(data: false, error: filename.error!))
        return
      }
      
      do {
        try self.drive.write(filename: filename.data!, content: privateKey) { writeResult in
          if (writeResult.error != nil) {
            completion(Result(data: false, error: writeResult.error!))
            return
          }
          
          completion(Result(data: true))
        }
      } catch {
        completion(Result(error: error))
      }
    }
    
    return completion(Result(error: GDriveStorageError.unknownError))
  }

  public func signIn(completion: @escaping (Result<GIDGoogleUser>) -> Void) -> Void {
    drive.auth.signIn() { result in
      completion(result)
    }
  }
        
  
  private func getFilename(callback: @escaping (Result<String>) -> Void) -> Void {
    if (api == nil) {
      callback(Result(error: GDriveStorageError.portalApiNotConfigured))
    }

    do {
      if (self.filename == nil || self.filename!.count < 1) {
        try api!.getClient() { client in
          if (client.error != nil) {
            callback(Result(error: client.error!))
            return
          } else if (client.data == nil) {
            callback(Result(error: GDriveStorageError.unableToFetchClientData))
            return
          }
          
          let name = self.hash(
            value: "\(client.data!.custodian.id)\(client.data!.id)"
          )
          
          self.filename = "\(name).txt"
          
          callback(Result(data: self.filename!))
        }
      }
      
      callback(Result(data: self.filename!))
    } catch {
      callback(Result(error: error))
    }
  }
  
  private func hash(value: String) -> String {
//    let s = String(self).unicodeScalars
//    return Int(s[s.startIndex].value)
    
    var hash = 0

    // Handle empty strings
    if (value.count == 0) {
      return "\(hash)"
    }

    for char in value {
      let charScalars = String(char).unicodeScalars
      let char = Int(charScalars[charScalars.startIndex].value)
      
      hash = (hash << 5) - hash + char
      hash |= 0 // Convert to 32bit integer
    }

    return "\(abs(hash))"
  }
}
