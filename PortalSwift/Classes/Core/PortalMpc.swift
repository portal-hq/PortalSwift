//
//  PortalMpc.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation
import Security
import Mpc

/// In the bks dictionary for an MPC share, Berkhoff is the value.
public struct Berkhoff: Codable {
  public var X: String
  public var Rank: Int
}

/// A MPC share that includes the share, the public key, and bks.
public struct MpcShare: Codable {
  public var share: String
  public var pubkey: PublicKey?
  public var bks:  [String: Berkhoff]?
}

/// A public key's coordinates (x, y).
public struct PublicKey: Codable {
  public var X: String
  public var Y: String
}

/// The data for GenerateResult.
public struct GenerateData: Codable {
  public var address: String
  public var dkgResult: MpcShare
}

/// The data for RotateResult.
public struct RotateData: Codable {
  public var share: String
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

/// The response from generating.
private struct GenerateResult: Codable {
  public var data: GenerateData?
  public var error: String?
}

/// The response from rotating.
private struct RotateResult: Codable {
  public var data: RotateData?
  public var error: String?
}

/// The response from encrypting.
private struct EncryptedResult: Codable {
  public var privateKey: String
  public var cipherText: String
}

/// A list of errors MPC can throw.
public enum MpcError: Error {
  case noSigningSharePresent
  case signingRecoveryError(message: String)
  case unexpectedErrorOnGenerate(message: String)
  case unexpectedErrorOnBackup(message: String)
  case unexpectedErrorOnSign(message: String)
  case unexpectedErrorOnRecoverBackup(message: String)
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
    isSimulator: Bool = false,
    mpcHost: String = "mpc.portalhq.io"
  ) {
    // Basic setup
    self.apiKey = apiKey
    self.chainId = chainId
    self.gatewayUrl = gatewayUrl
    self.keychain = keychain
    self.storage = storage

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
              let response = ClientBackup(self.apiKey, self.mpcHost, signingShare)
              let jsonData = response.data(using: .utf8)!
              let rotateResult: RotateResult  = try JSONDecoder().decode(RotateResult.self, from: jsonData)
              
              // Throw if there is an error getting the backup share.
              guard rotateResult.error == "" else {
                return completion(Result(error: MpcError.unexpectedErrorOnBackup(message: rotateResult.error!)))
              }
              
              // Attach the backup share to the signing share JSON.
              let backupShare = rotateResult.data!.share
              var signingShareJSON = try self.JSONParseShare(shareString: signingShare)
              signingShareJSON.share = backupShare
              
              // Encrypt the share.
              let encryptedResult = try self.encryptShare(mpcShare: signingShareJSON)
              
              // Attempt to write the encrypted share to storage.
              storage?.write(privateKey: encryptedResult.privateKey)  { (result: Result<Bool>) -> Void in
                // Throw an error if we can't write to storage.
                if result.error != nil {
                  return completion(Result(error: result.error!))
                }
                
                // Return the cipherText.
                return completion(Result(data: encryptedResult.cipherText))
              }
            } catch {
              return completion(Result(error: MpcError.unexpectedErrorOnBackup(message: "Backup failed")))
            }
          }
        }
      }
    } catch {
      return completion(Result(error: MpcError.unexpectedErrorOnBackup(message: "Backup failed")))
    }
  }

  /// Generates a MPC wallet and signing share for a client.
  /// - Returns: The address of the newly created MPC wallet.
  public func generate() throws -> String {
    // Call the MPC service to generate a new wallet.
    let response = ClientGenerate(apiKey, mpcHost)
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
            storage?.write(privateKey: encryptedResult.privateKey) { (result: Result<Bool>) -> Void in
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

  /// Decrypts cipherText using a private key.
  /// - Parameters:
  ///   - cipherText: A string of the cipherText.
  ///   - privateKey: A string of the private key (PEM key format).
  /// - Returns: A string of the backupShare object.
  private func decryptShare(cipherText: String, privateKey: String) throws -> String {
    // Prepare our algorithm, our key creation options, and an error if one occurs.
    let algorithm: SecKeyAlgorithm = .rsaEncryptionOAEPSHA512AESGCM
    let options: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
      kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
      kSecAttrKeySizeInBits as String: 2048
    ]
    var error: Unmanaged<CFError>?

    // Base64 encode the private key.
    let privateKeyBase64 = privateKey.replacingOccurrences(of: rsaHeader, with: "").replacingOccurrences(of: rsaFooter, with: "")
    let privateKeyData = Data(base64Encoded: privateKeyBase64)! as CFData

    // Create the private key and throw an error if it fails.
    guard let key = SecKeyCreateWithData(privateKeyData, options as CFDictionary, &error) else {
      throw error!.takeRetainedValue() as Error
    }

    // Check if the algorithm is supported and throw an error if it isn't.
    guard SecKeyIsAlgorithmSupported(key, .decrypt, algorithm) else {
      throw RsaError.incompatibleKeyWithAlgorithm
    }

    // Base64 decode the cipherText and throw an error if it fails.
    guard let cipherTextData = Data(base64Encoded: cipherText, options: .ignoreUnknownCharacters) else {
      throw RsaError.incorrectCipherTextFormat
    }

    // Decrypt the cipherText and throw an error if it fails.
    var decryptError: Unmanaged<CFError>?
    guard let clearText = SecKeyCreateDecryptedData(key, algorithm, cipherTextData as CFData, &decryptError) as Data? else {
      throw decryptError!.takeRetainedValue() as Error
    }

    // Return the decrypted cipherText as a string.
    return String(data: clearText, encoding: .utf8)!
  }

  /// Encrypts the backup share using a public key that it creates.
  /// - Parameter
  ///   - mpcShare: The share to encrypt.
  /// - Returns: The cipherText and the private key.
  private func encryptShare(mpcShare: MpcShare) throws -> EncryptedResult {
    // Format the MPC share as a string.
    let mpcShareData = try JSONEncoder().encode(mpcShare)
    let mpcShareString = String(data: mpcShareData, encoding: .utf8 )!

    // https://developer.apple.com/documentation/security/certificate_key_and_trust_services/keys/generating_new_cryptographic_keys
    let attributes: CFDictionary = [
      kSecAttrKeyType as String: kSecAttrKeyTypeRSA, // 1
      kSecAttrKeySizeInBits as String: 2048,
      kSecPrivateKeyAttrs as String: [kSecAttrIsPermanent as String: false]
    ] as CFDictionary
    var error: Unmanaged<CFError>?

    // Create a private key and throw an error if it fails.
    guard let privateKey = SecKeyCreateRandomKey(attributes, &error) else {
      throw error!.takeRetainedValue() as Error
    }

    // Get the public key from the private key and throw an error if it fails.
    guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
      throw RsaError.unableToGetPublicKey
    }

    // Derive the algorithm to use: https://developer.apple.com/documentation/security/certificate_key_and_trust_services/keys/using_keys_for_encryption
    let algorithm: SecKeyAlgorithm = .rsaEncryptionOAEPSHA512AESGCM

    // Check if the algorithm is supported and throw an error if it isn't.
    guard SecKeyIsAlgorithmSupported(publicKey, .encrypt, algorithm) else {
      throw RsaError.incompatibleKeyWithAlgorithm
    }

    // Encrypt the MPC share and throw an error if it fails.
    var encryptDataError: Unmanaged<CFError>?
    guard let cipherText = SecKeyCreateEncryptedData(publicKey, algorithm, mpcShareString.data(using: .utf8)! as CFData, &encryptDataError) as Data? else {
      throw encryptDataError!.takeRetainedValue() as Error
    }

    // Create a base64 encoded string of the cipherText and throw an error if it fails.
    var createKeyStringError: Unmanaged<CFError>?
    guard let data = SecKeyCopyExternalRepresentation(privateKey, &createKeyStringError) as? Data else {
      throw createKeyStringError!.takeRetainedValue() as Error
    }
    let base64String = data.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0))

    // Create a PEM formatted string of the private key.
    let privateKeyString = "\(rsaHeader)\(base64String)\(rsaFooter)"

    // Return the private key and the cipherText.
    return EncryptedResult(privateKey: privateKeyString, cipherText: cipherText.base64EncodedString(options: .lineLength64Characters))
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
    let res = ClientRecoverBackup(apiKey, mpcHost, signingShare)
    let jsonData = res.data(using: .utf8)!
    let rotateResult: RotateResult  = try JSONDecoder().decode(RotateResult.self, from: jsonData)

    // Throw an error if the MPC service returned an error.
    guard rotateResult.error!.isEmpty else {
      throw MpcError.unexpectedErrorOnRecoverBackup(message: rotateResult.error!)
    }

    // Return the new backup share.
    var newBackup = try JSONParseShare(shareString: signingShare)
    newBackup.share = rotateResult.data!.share
    return newBackup
  }

  /// Uses the backup share to create a new signing share and stores it in the keychain.
  /// - Parameter
  ///   - backupShare: The backup share.
  /// - Returns: The new signing share.
  private func recoverSigning(backupShare: String) throws -> MpcShare {
    // Decode the backup share.
    var share = try JSONDecoder().decode(MpcShare.self, from: backupShare.data(using: .utf8)!)

    // Call the MPC service to recover the signing share.
    let result = ClientRecoverSigning(apiKey, mpcHost, backupShare)
    let rotateResult = try JSONDecoder().decode(RotateResult.self, from: result.data(using: .utf8)!)

    // Throw an error if the MPC service returned an error.
    if (!rotateResult.error!.isEmpty) {
      throw MpcError.signingRecoveryError(message: rotateResult.error!)
    }
    if (rotateResult.data == nil) {
      throw MpcError.signingRecoveryError(message: "Could not read recovery data")
    }

    // Update the signing share.
    share.share = rotateResult.data!.share
    let jsonEncodedShare = try JSONEncoder().encode(share)
    let stringifiedShare = String(data: jsonEncodedShare, encoding: .utf8)

    // Store the signing share in the keychain.
    do {
      try keychain.setSigningShare(signingShare: stringifiedShare!)
    } catch {
      throw MpcError.unableToWriteToKeychain
    }

    // Return the new signing share.
    return share
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
