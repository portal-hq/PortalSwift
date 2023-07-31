//
//  ICloudStorage.swift
//  PortalSwift
//
//  Created by Kelson Adams on 7/31/23.
//

import Foundation

public class ICloudStorage: Storage {
  public var api: PortalApi?
  public var key: String = ""
  private var keyValueStorage: ICloudKeyValue
  private var documentStorage: ICloudDocuments

  public init(api: PortalApi?, key: String) {
    self.api = api
    self.key = key
    self.keyValueStorage = ICloudKeyValue(api: api, key: key)
    self.documentStorage = ICloudDocuments(api: api, key: key)
    super.init()
  }

  override public func read(completion: @escaping (Result<String>) -> Void) {
    self.documentStorage.read(completion: completion)
  }

  override public func write(privateKey: String, completion: @escaping (Result<Bool>) -> Void) {
    self.documentStorage.write(privateKey: privateKey, completion: completion)
  }

  override public func delete(completion: @escaping (Result<Bool>) -> Void) {
    self.documentStorage.delete(completion: completion)
  }

  public func migrateKeyValueDataToDocuments(completion: @escaping (Result<Bool>) -> Void) {
    self.documentStorage.read { (readDocumentResult: Result<String>) in
      if let readDocumentError = readDocumentResult.error {
        completion(Result(error: readDocumentError))
        return
      }

      // If there is already data in documentStorage, no need to migrate.
      if readDocumentResult.data != nil {
        completion(Result(data: false)) // Indicates no migration was necessary.
        return
      }

      self.keyValueStorage.read { (readResult: Result<String>) in
        if let readError = readResult.error {
          completion(Result(error: readError))
          return
        }

        let keyValueData = readResult.data!

        self.write(privateKey: keyValueData) { (writeResult: Result<Bool>) in
          if let writeError = writeResult.error {
            completion(Result(error: writeError))
            return
          }

          self.keyValueStorage.delete { (deleteResult: Result<Bool>) in
            if let deleteError = deleteResult.error {
              completion(Result(error: deleteError))
              return
            }

            completion(Result(data: true))
          }
        }
      }
    }
  }

  public func validateOperations(callback: @escaping (Result<Bool>) -> Void) {
    // Perform data migration before validating operations
    self.migrateKeyValueDataToDocuments { (migrationResult: Result<Bool>) in
      if let migrationError = migrationResult.error {
        callback(Result(error: migrationError))
        return
      }

      // If the migration is successful, proceed with validating operations
      let testFileName = "portal_test.txt"
      let testFileContent = "test_content"

      self.documentStorage.rawWrite(filename: testFileName, content: testFileContent, inTestFolder: true) { writeResult in
        if let writeError = writeResult.error {
          callback(Result(error: writeError))
          return
        }

        self.documentStorage.rawRead(filename: testFileName, fromTestFolder: true) { readResult in
          if let readError = readResult.error {
            callback(Result(error: readError))
            return
          }

          if readResult.data != testFileContent {
            callback(Result(error: iCloudStorageError.validationMismatch))
            return
          }

          self.documentStorage.rawDelete(filename: testFileName, fromTestFolder: true) { deleteResult in
            if let deleteError = deleteResult.error {
              callback(Result(error: deleteError))
            } else {
              callback(Result(data: true))
            }
          }
        }
      }
    }
  }
}
