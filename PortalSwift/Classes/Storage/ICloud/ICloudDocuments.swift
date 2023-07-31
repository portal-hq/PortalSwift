//
//  ICloudDocuments.swift
//  PortalSwift
//
//  Created by Kelson Adams on 7/31/23.
//

import CommonCrypto
import Foundation

enum iCloudStorageError: Error, LocalizedError {
  case noAPIKeyProvided
  case unableToRetrieveClient
  case noUbiquityContainer
  case writeError
  case readError
  case deleteError
  case validationMismatch

  var errorDescription: String? {
    switch self {
    case .noAPIKeyProvided:
      return "No API Key provided"
    case .unableToRetrieveClient:
      return "Unable to retrieve client from API"
    case .noUbiquityContainer:
      return "No ubiquity container found"
    case .writeError:
      return "There was an error while writing to iCloud"
    case .readError:
      return "There was an error while reading from iCloud"
    case .deleteError:
      return "There was an error while deleting from iCloud"
    case .validationMismatch:
      return "Validation mismatch: Written and read content do not match in validateOperations"
    }
  }
}

public class ICloudDocuments: Storage {
  /// The Portal API instance to retrieve the client's and custodian's IDs.
  public var api: PortalApi?
  /// The key used to store the private key in iCloud.
  public var key: String = ""

  public init(api: PortalApi?, key: String) {
    self.api = api
    self.key = key
    super.init()
  }

  private var ubiquityContainerURL: URL? {
    return FileManager.default.url(forUbiquityContainerIdentifier: nil)?
      .appendingPathComponent("Documents")
      .appendingPathComponent("_PORTAL_MPC_DO_NOT_DELETE_")
  }

  private var testUbiquityContainerURL: URL? {
    return FileManager.default.url(forUbiquityContainerIdentifier: nil)?
      .appendingPathComponent("Documents")
      .appendingPathComponent("_PORTAL_TEST_TEMP")
  }

  override public func write(privateKey: String, completion: @escaping (Result<Bool>) -> Void) {
    self.getFilename { result in
      if let error = result.error {
        completion(Result(error: error))
        return
      }

      self.rawWrite(filename: result.data!, content: privateKey, completion: completion)
    }
  }

  override public func read(completion: @escaping (Result<String>) -> Void) {
    self.getFilename { result in
      if let error = result.error {
        completion(Result(error: error))
        return
      }

      self.rawRead(filename: result.data!, completion: completion)
    }
  }

  override public func delete(completion: @escaping (Result<Bool>) -> Void) {
    self.getFilename { result in
      if let error = result.error {
        completion(Result(error: error))
        return
      }

      self.rawDelete(filename: result.data!, completion: completion)
    }
  }

  public func validateOperations(callback: @escaping (Result<Bool>) -> Void) {
    let fileName = "test_file"
    let fileContent = "This is a test"

    self.rawWrite(filename: fileName, content: fileContent, inTestFolder: true) { writeResult in
      if writeResult.error != nil {
        callback(Result(error: writeResult.error!))
        return
      }

      self.rawRead(filename: fileName, fromTestFolder: true) { readResult in
        if readResult.error != nil {
          callback(Result(error: readResult.error!))
          return
        }

        if readResult.data != fileContent {
          callback(Result(error: iCloudStorageError.validationMismatch))
          return
        }

        self.rawDelete(filename: fileName, fromTestFolder: true) { deleteResult in
          if deleteResult.error != nil {
            callback(Result(error: deleteResult.error!))
          } else {
            callback(Result(data: true))
          }
        }
      }
    }
  }

  public func rawWrite(filename: String, content: String, inTestFolder: Bool = false, completion: @escaping (Result<Bool>) -> Void) {
    let containerURL = inTestFolder ? self.testUbiquityContainerURL : self.ubiquityContainerURL
    guard let folderURL = containerURL else {
      completion(Result(error: iCloudStorageError.noUbiquityContainer))
      return
    }

    let fileURL = folderURL.appendingPathComponent(filename)

    DispatchQueue.global().async {
      do {
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        completion(Result(data: true))
      } catch {
        print(error)
        completion(Result(error: iCloudStorageError.writeError))
      }
    }
  }

  public func rawRead(filename: String, fromTestFolder: Bool = false, completion: @escaping (Result<String>) -> Void) {
    let containerURL = fromTestFolder ? self.testUbiquityContainerURL : self.ubiquityContainerURL
    guard let folderURL = containerURL else {
      completion(Result(error: iCloudStorageError.noUbiquityContainer))
      return
    }

    let fileURL = folderURL.appendingPathComponent(filename)

    DispatchQueue.global().async {
      do {
        let content = try String(contentsOf: fileURL)
        completion(Result(data: content))
      } catch {
        print(error)
        completion(Result(error: iCloudStorageError.readError))
      }
    }
  }

  public func rawDelete(filename: String, fromTestFolder: Bool = false, completion: @escaping (Result<Bool>) -> Void) {
    let containerURL = fromTestFolder ? self.testUbiquityContainerURL : self.ubiquityContainerURL
    guard let folderURL = containerURL else {
      completion(Result(error: iCloudStorageError.noUbiquityContainer))
      return
    }

    let fileURL = folderURL.appendingPathComponent(filename)

    DispatchQueue.global().async {
      do {
        try FileManager.default.removeItem(at: fileURL)
        completion(Result(data: true))
      } catch {
        print(error)
        completion(Result(error: iCloudStorageError.deleteError))
      }
    }
  }

  private func getFilename(completion: @escaping (Result<String>) -> Void) {
    if self.key.count > 0 {
      completion(Result(data: self.key))
      return
    }

    if self.api == nil {
      completion(Result(error: iCloudStorageError.noAPIKeyProvided))
      return
    }

    do {
      try self.api!.getClient { (result: Result<Client>) in
        if result.error != nil {
          completion(Result(error: result.error!))
          return
        }
        let key = self.createFilename(client: result.data!)
        completion(Result(data: key))
      }
    } catch {
      completion(Result(error: iCloudStorageError.unableToRetrieveClient))
    }
  }

  private func createFilename(client: Client) -> String {
    return ICloudDocuments.hash("\(client.custodian.id)\(client.id).txt")
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
