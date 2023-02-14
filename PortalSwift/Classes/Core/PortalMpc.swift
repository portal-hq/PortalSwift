//
//  PortalMpc.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation
import Security
import Mpc

/// A MPC share that includes a variable number of fields, depending on the MPC version being used
/// GG18 shares will only contain: bks, pubkey, and share
/// CGGMP shares will contain all fields except: pubkey.
public struct MpcShare: Codable {
  public var share: String
  public var allY: PartialPublicKey
  public var bks: Berkhoffs
  public var p: String
  public var partialPubkey: PartialPublicKey
  public var pederson: Pedersons
  public var q: String
  public var ssid: String
  public var clientId: String
  public var pubkey: PublicKey
}

/// In the bks dictionary for an MPC share, Berkhoff is the value.
public struct Berkhoff: Codable {
  public var X: String
  public var Rank: Int
}

/// A partial public key for client and server (x, y)
public struct PartialPublicKey: Codable {
  public var client: PublicKey
  public var server: PublicKey
}

/// A berhkoff coefficient mapping for client and server (x, rank)
public struct Berkhoffs: Codable {
  public var client: Berkhoff
  public var server: Berkhoff
}

public struct Pederson: Codable {
  public var n: String
  public var s: String
  public var t: String
}

public struct Pedersons: Codable {
  public var client: Pederson
  public var server: Pederson
}

/// A public key's coordinates (x, y).
public struct PublicKey: Codable {
  public var X: String
  public var Y: String
}

private struct DecryptResult: Codable {
  public var data: DecryptData?
  public var error: String?
}

private struct DecryptData: Codable {
  public var plaintext: String
}

/// The response from encrypting.
private struct EncryptData: Codable {
  public var key: String
  public var cipherText: String
}

private struct EncryptResult: Codable {
  public var data: EncryptData?
  public var error: String?
}

/// The data for GenerateResult.
public struct GenerateData: Codable {
  public var address: String
  public var dkgResult: MpcShare
}

/// The response from generating.
private struct GenerateResult: Codable {
  public var data: GenerateData?
  public var error: String?
}

/// The data for RotateResult.
public struct RotateData: Codable {
  public var address: String
  public var dkgResult: MpcShare
}

/// The response from rotating.
private struct RotateResult: Codable {
  public var data: RotateData?
  public var error: String?
}

/// The data for SignResult.
public struct SignData: Codable {
  public var R: String
  public var S: String
}

/// The response from signing.
public struct SignResult: Codable {
  public var data: String?
  public var error: String?
}



/// A list of errors MPC can throw.
public enum MpcError: Error {
  case backupNoLongerSupported(message: String)
  case generateNoLongerSupported(message: String)
  case recoverNoLongerSupported(message: String)
  case noSigningSharePresent
  case signingRecoveryError(message: String)
  case unexpectedErrorOnBackup(message: String)
  case unexpectedErrorOnDecrypt(message: String)
  case unexpectedErrorOnEncrypt(message: String)
  case unexpectedErrorOnGenerate(message: String)
  case unexpectedErrorOnRecoverBackup(message: String)
  case unexpectedErrorOnSign(message: String)
  case unableToRetrieveClient(String)
  case unableToDecodeShare
  case unableToAuthenticate
  case unableToWriteToKeychain
  case unsupportedStorageMethod
  case failedToGetBackupFromStorage
}

/// A list of errors RSA can throw.
public enum RsaError: Error {
  case unableToCreatePrivateKey(message: String)
  case incompatibleKeyWithAlgorithm
  case dataIsTooLongForKey
  case unableToGetPublicKey
  case incorrectCipherTextFormat
}

/// The main interface with Portal's MPC service.
public class PortalMpc {
  public var address: String?
  public var apiKey: String
  public var chainId: Int
  public var mpcHost: String
  public var isSimulator: Bool
  public var keychain: PortalKeychain
  public var gatewayUrl: String
  public var portal: Portal?
  public var storage: BackupOptions
  public var api: PortalApi
  public var version: String
  private var rsaHeader = "-----BEGIN RSA KEY-----\n"
  private var rsaFooter = "\n-----END RSA KEY-----"

  /// Create an instance of Portal's MPC service.
  /// - Parameters:
  ///   - apiKey: A Client API key.
  ///   - chainId: A specific EVM network.
  ///   - keychain: An instance of PortalKeychain.
  ///   - storage: An instance of BackupOptions.
  ///   - gatewayUrl: The Gateway URL to use.
  ///   - isSimulator: (optional) Whether or not we are on an iOS simulator.
  ///   - mpcHost: The hostname for Portal's MPC service.
  public init(
    apiKey: String,
    chainId: Int,
    keychain: PortalKeychain,
    storage: BackupOptions,
    gatewayUrl: String,
    api: PortalApi,
    isSimulator: Bool = false,
    mpcHost: String = "mpc.portalhq.io",
    version: String = "v1"
  ) {
    // Basic setup
    self.apiKey = apiKey
    self.chainId = chainId
    self.gatewayUrl = gatewayUrl
    self.keychain = keychain
    self.storage = storage
    self.api = api
    self.version = version

    // Other stuff
    self.isSimulator = isSimulator
    self.mpcHost = mpcHost

    // Attempt to get the address
    do {
      self.address = try self.keychain.getAddress()
    } catch {
      self.address = nil
    }
  }

  /// Creates a backup share, encrypts it, and stores the private key in cloud storage.
  /// - Parameters:
  ///   - method: Either gdrive or icloud.
  ///   - completion: The callback which includes the cipherText of the backed up share.
  public func backup(method: BackupMethods.RawValue, completion: @escaping (Result<String>) -> Void) -> Void {
    if version != "v1" {
      return completion(Result(error: MpcError.backupNoLongerSupported(message: "[PortalMpc] Backup is no longer supported for this version of MPC. Please use `version = v1` to generate a new wallet using CGGMP.")))
    }
    
    do {
      // Obtain the signing share.
      let signingShare = try keychain.getSigningShare()
      // Derive the storage and throw an error if none was provided.
      let storage = self.storage[method] as? Storage
      if (storage == nil) {
        return completion(Result(error: MpcError.unsupportedStorageMethod))
      }

      // Authenticate with Google Drive or throw an error if we can't.
//      if (method == BackupMethods.GoogleDrive.rawValue) {
//        (storage as! GDriveStorage).assignAccessToken()
//
//        if ((storage as! GDriveStorage).accessToken == nil) {
//          return completion(Result(error: MpcError.unableToAuthenticate))
//        }
//      }

      // Check if we are authenticated with iCloud or throw an error if we are not.
      if (method == BackupMethods.iCloud.rawValue) {
        (storage as! ICloudStorage).checkAvailability { (result: Result<Any>) -> Void in
          if (result.error != nil) {
            print("❌ iCloud is not available:")
            print(result)
            return completion(Result(error: result.error!))
          } else {
            print("Running backup since iCloud is available! 🎉")
            do {
              // Call the MPC service to generate a backup share.
              let response = ClientBackup(self.apiKey, self.mpcHost, signingShare, self.version)
              let jsonData = response.data(using: .utf8)!
              let rotateResult: RotateResult  = try JSONDecoder().decode(RotateResult.self, from: jsonData)
              
              // Throw if there is an error getting the backup share.
              guard rotateResult.error == "" else {
                return completion(Result(error: MpcError.unexpectedErrorOnBackup(message: rotateResult.error!)))
              }
              
              // Attach the backup share to the signing share JSON.
              let backupShare = rotateResult.data!.dkgResult
              
              // Encrypt the share.
              let encryptedResult = try self.encryptShare(mpcShare: backupShare)
              
              // Attempt to write the encrypted share to storage.
              storage?.write(privateKey: encryptedResult.key)  { (result: Result<Bool>) -> Void in
                // Throw an error if we can't write to storage.
                if result.error != nil {
                  return completion(Result(error: result.error!))
                }
                
                // Return the cipherText.
                return completion(Result(data: encryptedResult.cipherText))
              }
            } catch {
              print("Backup Failed: ", error)
              return completion(Result(error: MpcError.unexpectedErrorOnBackup(message: "Backup failed")))
            }
          }
        }
      }
      
      // Check if we are authenticated with iCloud or throw an error if we are not.
      if (method == BackupMethods.GoogleDrive.rawValue) {
        print("Running backup since Google Drive is available! 🎉")
        do {
          // Call the MPC service to generate a backup share.
          let response = ClientBackup(self.apiKey, self.mpcHost, signingShare, self.version)
          let jsonData = response.data(using: .utf8)!
          let rotateResult: RotateResult  = try JSONDecoder().decode(RotateResult.self, from: jsonData)
          
          // Throw if there is an error getting the backup share.
          guard rotateResult.error == "" else {
            return completion(Result(error: MpcError.unexpectedErrorOnBackup(message: rotateResult.error!)))
          }
          
          // Attach the backup share to the signing share JSON.
          let backupShare = rotateResult.data!.dkgResult
          
          // Encrypt the share.
          let encryptedResult = try self.encryptShare(mpcShare: backupShare)
          
          // Attempt to write the encrypted share to storage.
          storage?.write(privateKey: encryptedResult.key)  { (result: Result<Bool>) -> Void in
            // Throw an error if we can't write to storage.
            if result.error != nil {
              return completion(Result(error: result.error!))
            }
            
            // Return the cipherText.
            return completion(Result(data: encryptedResult.cipherText))
          }
        } catch {
          print("Backup Failed: ", error)
          return completion(Result(error: MpcError.unexpectedErrorOnBackup(message: "Backup failed")))
        }
      }
      
      return completion(Result(error: MpcError.unsupportedStorageMethod))
    } catch {
      print("Backup Failed: ", error)
      return completion(Result(error: MpcError.unexpectedErrorOnBackup(message: "Backup failed")))
    }
  }

  /// Generates a MPC wallet and signing share for a client.
  /// - Returns: The address of the newly created MPC wallet.
  public func generate() throws -> String {
    if version != "v1" {
      throw MpcError.generateNoLongerSupported(message: "[PortalMpc] Generate is no longer supported for this version of MPC. Please use `version = v1` to generate a new wallet using CGGMP.")
    }
    
    // Call the MPC service to generate a new wallet.
    let response = ClientGenerate(apiKey, mpcHost, version)
    let jsonData = response.data(using: .utf8)!
    let generateResult: GenerateResult = try JSONDecoder().decode(GenerateResult.self, from: jsonData)

    // Throw if there was an error generating the wallet.
    guard generateResult.error == "" else {
      throw MpcError.unexpectedErrorOnGenerate(message: generateResult.error!)
    }

    // Set the client's address.
    let address = generateResult.data!.address
    try keychain.setAddress(address: address)

    // Set the client's signing share.
    let mpcShare = generateResult.data!.dkgResult
    let mpcShareData = try JSONEncoder().encode(mpcShare)
    let mpcShareString = String(data: mpcShareData, encoding: .utf8 )!
    try keychain.setSigningShare(signingShare: mpcShareString )

    // Assign the address to the class.
    self.address = address

    // Return the address.
    return address
  }

  /// Uses the backup share to create a new signing share and a new backup share, encrypts the new backup share, and stores the private key in storage.
  /// - Parameters:
  ///   - cipherText: the cipherText of the backup share (should be passed in from the custodian).
  ///   - method: The specific backup storage option.
  ///   - completion: The callback which includes the cipherText of the new backup share.
  public func recover(
    cipherText: String,
    method: BackupMethods.RawValue,
    completion: @escaping (Result<String>) -> Void
  ) -> Void {
    if version != "v1" {
      return completion(Result(error: MpcError.recoverNoLongerSupported(message: "[PortalMpc] Recover is no longer supported for this version of MPC. Please use `version = v1` to generate a new wallet using CGGMP.")))
    }
    
    // Derive the storage and throw an error if none was provided.
    let storage = self.storage[method] as? Storage
    if (storage == nil) {
      return completion(Result(error: MpcError.unsupportedStorageMethod))
    }
    
    (storage as! ICloudStorage).checkAvailability { (result: Result<Any>) -> Void in
      if (result.error != nil) {
        print("❌ iCloud is not available:")
        print(result)
        return completion(Result(error: result.error!))
      } else {
        print("Running recovery since iCloud is available! 🎉")
        // Call the MPC service to get the backup share.
        self.getBackupShare(cipherText: cipherText, method: method) { (result: Result<String>) -> Void in
          do {
            // Throw if there was an error getting the backup share.
            guard result.error == nil else {
              return completion(Result(error: result.error!))
            }
            
            // Encrypt the new backup share.
            _ = try self.recoverSigning(backupShare: result.data!)
            let newBackupShare = try self.recoverBackup(signingShare: result.data!)
            let encryptedResult = try self.encryptShare(mpcShare: newBackupShare)
            
            // Attempt to write the encrypted share to storage.
            storage?.write(privateKey: encryptedResult.key) { (result: Result<Bool>) -> Void in
              // Throw an error if we can't write to storage.
              if !result.data! {
                return completion(Result(error: result.error!))
              }
              
              // Return the cipherText.
              return completion(Result(data: encryptedResult.cipherText))
            }
          } catch {
            return completion(Result(error: error))
          }
        }
      }
    }
  }
  
  private func decryptShare(cipherText: String, privateKey: String) throws -> String {
    let result = ClientDecrypt(privateKey, cipherText)
    let jsonResult = result.data(using: .utf8)!
    let decryptResult: DecryptResult = try JSONDecoder().decode(DecryptResult.self, from: jsonResult)
    
    // Throw if there was an error decrypting the value.
    guard decryptResult.error == "" else {
      throw MpcError.unexpectedErrorOnDecrypt(message: decryptResult.error!)
    }
    
    return decryptResult.data!.plaintext
  }

  /// Encrypts the backup share using a public key that it creates.
  /// - Parameter
  ///   - mpcShare: The share to encrypt.
  /// - Returns: The cipherText and the private key.
  private func encryptShare(mpcShare: MpcShare) throws -> EncryptData {
    let mpcShareData = try JSONEncoder().encode(mpcShare)
    let mpcShareString = String(data: mpcShareData, encoding: .utf8 )!
    
    let result = ClientEncrypt(mpcShareString)
    let jsonResult = result.data(using: .utf8)!
    let encryptResult: EncryptResult = try JSONDecoder().decode(EncryptResult.self, from: jsonResult)
    
    guard encryptResult.error == "" else {
      throw MpcError.unexpectedErrorOnEncrypt(message: encryptResult.error!)
    }
    
    return encryptResult.data!
  }

  /// Loads the private key from cloud storage, uses that to decrypt the cipherText, and returns the string of the backup share.
  /// - Parameters:
  ///   - cipherText: The cipherText of the backup share.
  ///   - method: The storage method.
  ///   - completion: The completion handler that includes the backup share string.
  private func getBackupShare(
    cipherText: String,
    method: BackupMethods.RawValue,
    completion: @escaping (Result<String>) -> Void
  ) -> Void {
    // Derive the storage and throw an error if none was provided.
    let storage = self.storage[method] as? Storage
    if (storage == nil) {
      return completion(Result(error: MpcError.unsupportedStorageMethod))
    }

    // Attempt to read the private key from storage.
    storage!.read() { (result: Result<String>) -> Void in
      // If the private key was not found, return an error.
      if (result.data == nil) {
        return completion(Result(error: MpcError.failedToGetBackupFromStorage))
      }

      // Attempt to decrypt the cipherText.
      do {
        let backupShare = try self.decryptShare(cipherText: cipherText, privateKey: result.data!)
        return completion(Result(data: backupShare))
      } catch {
        return completion(Result(error: error))
      }
    }
  }

  /// Uses the signing share to create a new backup share and returns that share in JSON format.
  /// - Parameter
  ///   - signingShare: The signing share as a string.
  /// - Returns: The backup share.
  private func recoverBackup(signingShare: String) throws -> MpcShare {
    // Call the MPC service to recover the backup share.
    let res = ClientRecoverBackup(apiKey, mpcHost, signingShare, version)
    let jsonData = res.data(using: .utf8)!
    let rotateResult: RotateResult  = try JSONDecoder().decode(RotateResult.self, from: jsonData)

    // Throw an error if the MPC service returned an error.
    guard rotateResult.error!.isEmpty else {
      throw MpcError.unexpectedErrorOnRecoverBackup(message: rotateResult.error!)
    }

    // Return the new backup share.
    return rotateResult.data!.dkgResult
  }

  /// Uses the backup share to create a new signing share and stores it in the keychain.
  /// - Parameter
  ///   - backupShare: The backup share.
  /// - Returns: The new signing share.
  private func recoverSigning(backupShare: String) throws -> MpcShare {
    // Call the MPC service to recover the signing share.
    let result = ClientRecoverSigning(apiKey, mpcHost, backupShare, version)
    let rotateResult = try JSONDecoder().decode(RotateResult.self, from: result.data(using: .utf8)!)

    // Throw an error if the MPC service returned an error.
    if (!rotateResult.error!.isEmpty) {
      throw MpcError.signingRecoveryError(message: rotateResult.error!)
    }
    if (rotateResult.data == nil) {
      throw MpcError.signingRecoveryError(message: "Could not read recovery data")
    }

    // Store the signing share in the keychain.
    do {
      let encodedShare = try JSONEncoder().encode(rotateResult.data!.dkgResult)
      let shareString = String(data: encodedShare, encoding: .utf8)
      try keychain.setSigningShare(signingShare: shareString!)
      try keychain.setAddress(address: rotateResult.data!.address)
    } catch {
      throw MpcError.unableToWriteToKeychain
    }

    // Return the new signing share.
    return rotateResult.data!.dkgResult
  }

  /// Helper function to parse the MPC share from a JSON string.
  /// - Parameter
  ///   - shareString: The JSON string of the MPC share.
  /// - Returns: An MPC share.
  private func JSONParseShare(shareString: String) throws -> MpcShare {
    var shareJson: MpcShare
    do {
      let jsonString = shareString.data(using: .utf8)!
      shareJson = try JSONDecoder().decode(MpcShare.self, from: jsonString)
    } catch  {
      throw MpcError.unableToDecodeShare
    }

    return shareJson
  }
}
