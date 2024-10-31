//
//  LocalFileStorage.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public enum LocalFileStorageError: LocalizedError {
  case mustExtendStorageClass
  case fileNotFound
  case writeError
  case readError
}

public class LocalFileStorage: Storage, PortalStorage {
  public weak var api: PortalApiProtocol?
  public let encryption: PortalEncryptionProtocol
  var fileName: String = "PORTAL_BACKUP_SHARE"

  public init(fileName: String = "PORTAL_BACKUP_SHARE", encryption: PortalEncryptionProtocol = PortalEncryption()) {
    self.encryption = encryption
    self.fileName = fileName
    super.init()
  }

  /*******************************************
   * Public functions
   *******************************************/

  /// Deletes an item in storage.
  public func delete() async throws -> Bool {
    let fileURL = self.getDocumentsDirectory().appendingPathComponent(self.fileName)

    do {
      try FileManager.default.removeItem(at: fileURL)
      return true
    } catch {
      throw LocalFileStorageError.fileNotFound
    }
  }

  /// Reads an item from storage.
  public func read() async throws -> String {
    let fileURL = self.getDocumentsDirectory().appendingPathComponent(self.fileName)

    do {
      let content = try String(contentsOf: fileURL)
      return content
    } catch {
      throw LocalFileStorageError.readError
    }
  }

  public func validateOperations() async throws -> Bool {
    return true
  }

  /// Writes an item to storage.
  public func write(_ value: String) async throws -> Bool {
    let fileURL = self.getDocumentsDirectory().appendingPathComponent(self.fileName)

    do {
      try value.write(to: fileURL, atomically: true, encoding: .utf8)

      return true
    } catch {
      throw LocalFileStorageError.writeError
    }
  }

  /*******************************************
   * Private functions
   *******************************************/

  /// Get the documents directory for the app.
  private func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
  }

  /*******************************************
   * Deprecated functions
   *******************************************/

  /// Deletes an item in storage.
  override public func delete(completion: @escaping (Result<Bool>) -> Void) {
    let fileURL = self.getDocumentsDirectory().appendingPathComponent(self.fileName)

    do {
      try FileManager.default.removeItem(at: fileURL)
      completion(Result(data: true))
    } catch {
      completion(Result(error: LocalFileStorageError.fileNotFound))
    }
  }

  /// Reads an item from storage.
  override public func read(completion: @escaping (Result<String>) -> Void) {
    let fileURL = self.getDocumentsDirectory().appendingPathComponent(self.fileName)

    do {
      let content = try String(contentsOf: fileURL)
      completion(Result(data: content))
    } catch {
      completion(Result(error: LocalFileStorageError.readError))
    }
  }

  /// Writes an item to storage.
  override public func write(privateKey content: String, completion: @escaping (Result<Bool>) -> Void) {
    let fileURL = self.getDocumentsDirectory().appendingPathComponent(self.fileName)

    do {
      try content.write(to: fileURL, atomically: true, encoding: .utf8)
      completion(Result(data: true))
    } catch {
      completion(Result(error: LocalFileStorageError.writeError))
    }
  }
}
