import CloudKit
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
  case modelNotFound
  case validationFailed

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
    case .modelNotFound:
      return "The model 'PortalBackupKey' was not found in CloudKit with properties 'clientIdentifier' and 'decryptionKey'."
    case .validationFailed:
      return "Unable to validate all CloudKit CRUD operations."
    }
  }
}

public class ICloudStorage: Storage {
  public var api: PortalApi? {
    didSet {
      self.keyValueStorage.api = self.api
      self.cloudKitStorage.api = self.api
    }
  }

  private var keyValueStorage: ICloudKeyValue
  private var cloudKitStorage: CloudKitStorage

  override public init() {
    self.keyValueStorage = ICloudKeyValue(api: self.api)
    self.cloudKitStorage = CloudKitStorage(api: self.api)
    super.init()
  }

  override public func read(completion: @escaping (Result<String>) -> Void) {
    self.cloudKitStorage.read(completion: completion)
  }

  override public func write(privateKey: String, completion: @escaping (Result<Bool>) -> Void) {
    self.cloudKitStorage.write(privateKey: privateKey, completion: completion)
  }

  override public func delete(completion: @escaping (Result<Bool>) -> Void) {
    self.cloudKitStorage.delete(completion: completion)
  }

  public func migrateKeyValueDataToDocuments(completion: @escaping (Result<Bool>) -> Void) {
    self.cloudKitStorage.read { (readDocumentResult: Result<String>) in
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

  public func validateOperations(completion: @escaping (Result<Bool>) -> Void) {
    let testId = "portal_test_id"
    let testValue = "test_value"

    self.cloudKitStorage.rawWrite(id: testId, data: testValue) { writeResult in
      // Handle errors.
      guard writeResult.error == nil else {
        return completion(Result(error: writeResult.error!))
      }

      self.cloudKitStorage.rawRead(id: testId) { readResult in
        // Handle errors.
        guard readResult.error == nil else {
          return completion(Result(error: readResult.error!))
        }

        if readResult.data == testValue {
          self.cloudKitStorage.rawDelete(id: testId) { deleteResult in
            // Handle errors.
            guard deleteResult.error == nil else {
              return completion(Result(error: deleteResult.error!))
            }

            return completion(Result(data: true))
          }
        } else {
          return completion(Result(error: iCloudStorageError.validationFailed))
        }
      }
    }
  }
}
