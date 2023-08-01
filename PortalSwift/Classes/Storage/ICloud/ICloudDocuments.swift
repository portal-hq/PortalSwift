//
//  ICloudDocuments.swift
//  PortalSwift
//
//  Created by Kelson Adams on 7/31/23.
//

import CommonCrypto
import Foundation

public class ICloudDocuments: Storage {
  /// The Portal API instance to retrieve the client's and custodian's IDs.
  public var api: PortalApi?

  public init(api: PortalApi?) {
    self.api = api
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
      .appendingPathComponent("_PORTAL_TEST_TEMP_")
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
    let fileName = "test_file.txt"
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
        // Create the directory if it does not exist yet.
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        #if targetEnvironment(simulator)
          print("On SIMULATOR, skipping check to confirm file was stored on iCloud servers...")
          completion(Result(data: true))
        #else
          // Create NSMetadataQuery and register notification.
          let query = NSMetadataQuery()
          query.predicate = NSPredicate(format: "%K == %@", NSMetadataItemURLKey, fileURL as CVarArg)
          query.valueListAttributes = [NSMetadataUbiquitousItemIsUploadedKey]
          let observer = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: query, queue: OperationQueue.main) { _ in
            query.stop()
            NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidFinishGathering, object: query)

            if let metadataItem = query.results as? [NSMetadataItem],
               let attributeValue = metadataItem.first?.value(forAttribute: NSMetadataUbiquitousItemIsUploadedKey) as? NSNumber,
               attributeValue.boolValue
            {
              completion(Result(data: true))
              return
            } else {
              completion(Result(error: iCloudStorageError.uploadError))
              return
            }
          }

          query.start()

          // Timeout if we never get confirmation of the file being stored in iCloud's servers.
          let timeoutInSeconds: Int = 10
          DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(timeoutInSeconds)) {
            if query.isStarted {
              query.stop()
              NotificationCenter.default.removeObserver(observer)
              completion(Result(error: iCloudStorageError.uploadError))
              return
            }
          }
        #endif
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
      // Check if the file exists
      let fileManager = FileManager.default
      if !fileManager.fileExists(atPath: fileURL.path) {
        completion(Result(error: iCloudStorageError.fileDoesNotExist))
        return
      }

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
    if self.api == nil {
      completion(Result(error: iCloudStorageError.noAPIProvided))
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
    return "\(ICloudDocuments.hash("\(client.custodian.id)\(client.id)")).txt"
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
