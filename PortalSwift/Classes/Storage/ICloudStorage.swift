//
//  ICloudStorage.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation
import CommonCrypto

/// A storage class that uses iCloud's key-value store to store/retrieve private keys.
public class ICloudStorage: Storage {
  enum ICloudStorageError: Error {
    case noAPIKeyProvided(String)
    case noAccessToICloud(String)
    case notSignedIntoICloud(String)
    case unableToDeriveKey(String)
    case unableToRetrieveClient(String)
    case unknownError
  }

  enum ICloudStatus: String {
    case available
    case notSignedIn
    case noAccess
  }

  /// The Portal API instance to retrieve the client's and custodian's IDs.
  public var api: PortalApi?
  /// The key used to store the private key in iCloud.
  public var key: String = ""

  private let isSimulator = TARGET_OS_SIMULATOR != 0

  /// Initializes a new ICloudStorage instance.
  public override init() {}

  /// Reads the private key stored in iCloud's key-value store.
  /// - Parameter completion: Resolves as a Result which can include the private key stored in iCloud's key-value store.
  /// - Returns: Void
  public override func read(completion: @escaping (Result<String>) -> Void) -> Void {
    self.getKey() { (result: Result<String>) -> Void in
      // Escape early if we can't get the key.
      if (result.error != nil) {
        completion(Result(error: result.error!))
        return
      }

      // Check if we have access to iCloud.
      self.checkAvailability() { (statusResult: Result<Any>) -> Void in
        if (statusResult.error != nil) {
          completion(Result(error: statusResult.error!))
          return
        }

        // Read from iCloud.
        NSUbiquitousKeyValueStore.default.synchronize()
        completion(Result(data: NSUbiquitousKeyValueStore.default.string(forKey: result.data!) ?? ""))
      }
    }
  }

  /// Writes the private key to iCloud's key-value store.
  /// - Parameters:
  ///   - privateKey: The private key to write to iCloud's key-value store.
  ///   - completion: Resolves as a Result<Bool>.
  /// - Returns: Void
  public override func write(privateKey: String, completion: @escaping (Result<Bool>) -> Void) -> Void {
    getKey() { (result: Result<String>) -> Void in
      // Escape early if we can't get the key.
      if (result.error != nil) {
        completion(Result(error: result.error!))
        return
      }

      // Check if we have access to iCloud.
      self.checkAvailability() { (statusResult: Result<Any>) -> Void in
        if (statusResult.error != nil) {
          completion(Result(error: statusResult.error!))
          return
        }

        // Write to iCloud.
        NSUbiquitousKeyValueStore.default.synchronize()
        NSUbiquitousKeyValueStore.default.set(privateKey, forKey: result.data!)
        NSUbiquitousKeyValueStore.default.synchronize()
        completion(Result(data: true))
      }
    }
  }

  /// Deletes the private key stored in iCloud's key-value store.
  /// - Parameter completion: Resolves as a Result<Bool>.
  /// - Returns: Void
  public override func delete(completion: @escaping (Result<Bool>) -> Void) -> Void {
    getKey() { (result: Result<String>) -> Void in
      // Escape early if we can't get the key.
      if (result.error != nil) {
        completion(Result(error: result.error!))
        return
      }

      // Check if we have access to iCloud.
      self.checkAvailability() { (statusResult: Result<Any>) -> Void in
        if (statusResult.error != nil) {
          completion(Result(error: statusResult.error!))
          return
        }

        // Delete from iCloud.
        NSUbiquitousKeyValueStore.default.synchronize()
        NSUbiquitousKeyValueStore.default.removeObject(forKey: result.data!)
        NSUbiquitousKeyValueStore.default.synchronize()
        completion(Result(data: true))
      }
    }
  }

  /// Checks if the user is signed into iCloud and has iCloud Key-Value Storage enabled.
  /// - Returns: An ICloudStatus.
  public func getAvailability() -> String {
    // Check ubiquityIdentityToken from FileManager to see if the user is signed in.
    if FileManager.default.ubiquityIdentityToken == nil {
      return ICloudStatus.notSignedIn.rawValue
    }

    // Skip the other checks if we are on a simulator.
    if isSimulator {
      print("""

⚠️ iCloud key-value storage does not synchronize on some iOS simulator versions.

If you test recovery by uninstalling your app on an iOS simulator and reinstalling your app on a different device, recovery can fail.
We highly recommend using real devices to test the recovery process.

""")
      return ICloudStatus.available.rawValue
    }

    // Check if the user has iCloud Key-Value Storage enabled.
    if NSUbiquitousKeyValueStore.default.synchronize() == false {
      return ICloudStatus.noAccess.rawValue
    }

    return ICloudStatus.available.rawValue
  }

  public func checkAvailability(completion: @escaping (Result<Any>) -> Void) -> Void {
    let status = getAvailability()

    if status == ICloudStatus.noAccess.rawValue {
      completion(Result(error: ICloudStorageError.noAccessToICloud("No access to iCloud")))
    } else if status == ICloudStatus.notSignedIn.rawValue {
      completion(Result(error: ICloudStorageError.notSignedIntoICloud("Not signed into iCloud")))
    } else {
      completion(Result(data: true))
    }
  }

  private func getKey(completion: @escaping (Result<String>) -> Void) -> Void {
    if self.key.count > 0 {
      completion(Result(data: self.key))
      return
    }

    if self.api == nil {
      completion(Result(error: ICloudStorageError.noAPIKeyProvided("No API key provided")))
      return
    }

    do {
      try self.api!.getClient() { (result: Result<Any>) -> Void in
        if (result.error != nil) {
          completion(Result(error: result.error!))
          return
        }
        let key = self.createKey(client: result.data as! Dictionary<String, Any>)
        completion(Result(data: key))
      }
    } catch {
      completion(Result(error: ICloudStorageError.unableToRetrieveClient("Unable to retrieve client from API")))
    }
  }

  private func createKey(client: Dictionary<String, Any>) -> String {
    let clientID = client["id"] as! String
    let custodian = client["custodian"] as! Dictionary<String, Any>
    let custodianID = custodian["id"] as! String

    return ICloudStorage.hash("\(custodianID)\(clientID)")
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
