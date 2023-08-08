import CloudKit
import CommonCrypto
import Foundation

public class CloudKitStorage: Storage {
  public var api: PortalApi?
  public var privateDB: CKDatabase

  private var container: CKContainer

  public init(api: PortalApi?) {
    self.api = api
    self.container = CKContainer(identifier: "iCloud.io.portalhq.demo")
    self.privateDB = self.container.privateCloudDatabase
    super.init()
  }

  override public func write(privateKey: String, completion: @escaping (Result<Bool>) -> Void) {
    self.getClientIdentifier { result in
      guard let id = result.data else {
        completion(Result(error: result.error!))
        return
      }
      let recordID = CKRecord.ID(recordName: id)
      let record = CKRecord(recordType: "PortalBackupKey", recordID: recordID)
      record["clientIdentifier"] = id as CKRecordValue
      record["decryptionKey"] = privateKey as CKRecordValue
      self.privateDB.save(record) { _, error in
        if let error = error as? CKError, error.code == .serverRecordChanged {
          completion(Result(error: iCloudStorageError.modelNotFound))
        } else if let error = error {
          completion(Result(error: error))
        } else {
          completion(Result(data: true))
        }
      }
    }
  }

  override public func read(completion: @escaping (Result<String>) -> Void) {
    self.getClientIdentifier { result in
      guard let id = result.data else {
        completion(Result(error: result.error!))
        return
      }
      let recordID = CKRecord.ID(recordName: id)
      self.privateDB.fetch(withRecordID: recordID) { record, error in
        if let error = error {
          completion(Result(error: error))
        } else if let content = record?["content"] as? String {
          completion(Result(data: content))
        } else {
          completion(Result(error: iCloudStorageError.readError))
        }
      }
    }
  }

  override public func delete(completion: @escaping (Result<Bool>) -> Void) {
    self.getClientIdentifier { result in
      guard let id = result.data else {
        completion(Result(error: result.error!))
        return
      }
      let recordID = CKRecord.ID(recordName: id)
      self.privateDB.delete(withRecordID: recordID) { _, error in
        if let error = error {
          completion(Result(error: error))
        } else {
          completion(Result(data: true))
        }
      }
    }
  }

  public func rawWrite(id: String, data: String, completion: @escaping (Result<Bool>) -> Void) {
    let recordID = CKRecord.ID(recordName: id)
    let record = CKRecord(recordType: "PortalBackupKey", recordID: recordID)
    record["clientIdentifier"] = id as CKRecordValue
    record["decryptionKey"] = data as CKRecordValue
    self.privateDB.save(record) { _, error in
      if let error = error as? CKError, error.code == .serverRecordChanged {
        completion(Result(error: iCloudStorageError.modelNotFound))
      } else if let error = error {
        completion(Result(error: error))
      } else {
        completion(Result(data: true))
      }
    }
  }

  public func rawRead(id: String, completion: @escaping (Result<String>) -> Void) {
    let recordID = CKRecord.ID(recordName: id)
    self.privateDB.fetch(withRecordID: recordID) { record, error in
      if let error = error {
        completion(Result(error: error))
      } else if let content = record?["decryptionKey"] as? String {
        completion(Result(data: content))
      } else {
        completion(Result(error: iCloudStorageError.readError))
      }
    }
  }

  public func rawDelete(id: String, completion: @escaping (Result<Bool>) -> Void) {
    let recordID = CKRecord.ID(recordName: id)
    self.privateDB.delete(withRecordID: recordID) { _, error in
      if let error = error {
        completion(Result(error: error))
      } else {
        completion(Result(data: true))
      }
    }
  }

  private func getClientIdentifier(completion: @escaping (Result<String>) -> Void) {
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
        let key = self.createClientIdentifier(client: result.data!)
        completion(Result(data: key))
      }
    } catch {
      completion(Result(error: iCloudStorageError.unableToRetrieveClient))
    }
  }

  private func createClientIdentifier(client: Client) -> String {
    return "\(CloudKitStorage.hash("\(client.custodian.id)\(client.id)"))"
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
