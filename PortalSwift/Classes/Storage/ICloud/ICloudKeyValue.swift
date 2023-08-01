//
//  ICloudKeyValue.swift
//  PortalSwift
//
//  Created by Kelson Adams on 7/31/23.
//

import CommonCrypto
import Foundation

/// A storage class that uses iCloud's key-value store to store/retrieve private keys.
public class ICloudKeyValue: Storage {
  enum ICloudKeyValueError: Error {
    case noAPIProvided(String)
    case noAccessToICloud(String)
    case notSignedIntoICloud(String)
    case unableToDeriveKey(String)
    case unableToRetrieveClient(String)
    case failedValidateOperations(String)
    case unknownError
  }

  enum ICloudKeyValueStatus: String {
    case available
    case notSignedIn
    case noAccess
  }

  /// The Portal API instance to retrieve the client's and custodian's IDs.
  public var api: PortalApi?

  private let isSimulator = TARGET_OS_SIMULATOR != 0

  /// Initializes a new ICloudKeyValue instance.
  public init(api: PortalApi?) {
    self.api = api
    super.init()
  }

  /// Reads the private key stored in iCloud's key-value store.
  /// - Parameter completion: Resolves as a Result which can include the private key stored in iCloud's key-value store.
  /// - Returns: Void
  override public func read(completion: @escaping (Result<String>) -> Void) {
    self.getKey { (result: Result<String>) in
      // Escape early if we can't get the key.
      if result.error != nil {
        completion(Result(error: result.error!))
        return
      }

      // Read from iCloud.
      NSUbiquitousKeyValueStore.default.synchronize()
      completion(Result(data: NSUbiquitousKeyValueStore.default.string(forKey: result.data!) ?? ""))
    }
  }

  /// Writes the private key to iCloud's key-value store.
  /// - Parameters:
  ///   - privateKey: The private key to write to iCloud's key-value store.
  ///   - completion: Resolves as a Result<Bool>.
  /// - Returns: Void
  override public func write(privateKey: String, completion: @escaping (Result<Bool>) -> Void) {
    self.getKey { (result: Result<String>) in
      // Escape early if we can't get the key.
      if result.error != nil {
        completion(Result(error: result.error!))
        return
      }

      // Write to iCloud.
      NSUbiquitousKeyValueStore.default.synchronize()
      NSUbiquitousKeyValueStore.default.set(privateKey, forKey: result.data!)
      NSUbiquitousKeyValueStore.default.synchronize()
      completion(Result(data: true))
    }
  }

  /// Deletes the private key stored in iCloud's key-value store.
  /// - Parameter completion: Resolves as a Result<Bool>.
  /// - Returns: Void
  override public func delete(completion: @escaping (Result<Bool>) -> Void) {
    self.getKey { (result: Result<String>) in
      // Escape early if we can't get the key.
      if result.error != nil {
        completion(Result(error: result.error!))
        return
      }

      // Delete from iCloud.
      NSUbiquitousKeyValueStore.default.synchronize()
      NSUbiquitousKeyValueStore.default.removeObject(forKey: result.data!)
      NSUbiquitousKeyValueStore.default.synchronize()
      completion(Result(data: true))
    }
  }

  private func getKey(completion: @escaping (Result<String>) -> Void) {
    if self.api == nil {
      completion(Result(error: ICloudKeyValueError.noAPIProvided("No API provided")))
      return
    }

    do {
      try self.api!.getClient { (result: Result<Client>) in
        if result.error != nil {
          completion(Result(error: result.error!))
          return
        }
        let label = self.createLabel(client: result.data!)
        completion(Result(data: label))
      }
    } catch {
      completion(Result(error: ICloudKeyValueError.unableToRetrieveClient("Unable to retrieve client from API")))
    }
  }

  private func createLabel(client: Client) -> String {
    return ICloudKeyValue.hash("\(client.custodian.id)\(client.id)")
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
