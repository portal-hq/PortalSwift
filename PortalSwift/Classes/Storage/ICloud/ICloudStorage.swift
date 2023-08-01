//
//  ICloudStorage.swift
//  PortalSwift
//
//  Created by Kelson Adams on 7/31/23.
//

import Foundation

enum iCloudStorageError: Error, LocalizedError {
  case noAPIProvided
  case unableToRetrieveClient
  case noUbiquityContainer
  case fileDoesNotExist
  case writeError
  case readError
  case deleteError
  case validationMismatch
  case uploadError

  var errorDescription: String? {
    switch self {
    case .noAPIProvided:
      return "No API provided"
    case .unableToRetrieveClient:
      return "Unable to retrieve client from API"
    case .noUbiquityContainer:
      return "No ubiquity container found"
    case .fileDoesNotExist:
      return "File does not exist"
    case .writeError:
      return "There was an error while writing to iCloud"
    case .readError:
      return "There was an error while reading from iCloud"
    case .deleteError:
      return "There was an error while deleting from iCloud"
    case .validationMismatch:
      return "Validation mismatch: Written and read content do not match in validateOperations"
    case .uploadError:
      return "There was an error while writing to iCloud"
    }
  }
}

public class ICloudStorage: Storage {
  public var api: PortalApi? {
    didSet {
      self.keyValueStorage.api = self.api
      self.documentStorage.api = self.api
    }
  }

  private var keyValueStorage: ICloudKeyValue
  private var documentStorage: ICloudDocuments

  override public init() {
    self.keyValueStorage = ICloudKeyValue(api: self.api)
    self.documentStorage = ICloudDocuments(api: self.api)
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
        // Ignore the error if the file does not exist.
        if let storageError = readDocumentError as? iCloudStorageError, storageError != .fileDoesNotExist {
          completion(Result(error: readDocumentError))
          return
        }
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
            // Perform data migration if we have access to iCloud Documents.
            self.migrateKeyValueDataToDocuments { (migrationResult: Result<Bool>) in
              if let migrationError = migrationResult.error {
                callback(Result(error: migrationError))
                return
              }
              callback(Result(data: true))
            }
          }
        }
      }
    }
  }
}
