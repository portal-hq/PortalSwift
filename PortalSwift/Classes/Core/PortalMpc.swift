//
//  PortalMpc.swift
//  FBSnapshotTestCase
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation
import Security
import Mpc

public struct Birkhoff: Codable {
  public var X: String
  public var Rank: Int
}

public struct MpcShare: Codable {
  public var share: String
  public var pubkey: PublicKey?
  public var bks:  [String: Birkhoff]?
}

public struct PublicKey: Codable {
  public var X: String
  public var Y: String
}

public struct GenerateData: Codable {
  public var address: String
  public var dkgResult: MpcShare
}
public struct RotateData: Codable {
  public var share: String
}

public struct SignData: Codable {
  public var R: String
  public var S: String
}

private struct GenerateResult: Codable {
  public var data: GenerateData?
  public var error: String?
}

private struct RotateResult: Codable {
  public var data: RotateData?
  public var error: String?
}

private struct SignResult: Codable {
  public var data: SignData?
  public var error: String?
}

private struct EncryptedResult: Codable {
  public var privateKey: String
  public var cipherText: String
}

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
}

public enum RsaError: Error {
  case unableToCreatePrivateKey(message: String)
  case incompatibleKeyWithAlgorithm
  case dataIsTooLongForKey
  case unableToGetPublicKey
  case incorrectCipherTextFormat
}

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
  
  init(
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
  }
  
  /// Creates a backup share, encrypts it, stores the private key in cloud storage, returns the cipherText of the encrypted share.
  /// - Parameter method: either gdrive or icloud
  /// - Returns: cipherText of the encrypted backup share
  public func backup(method: BackupMethods.RawValue) throws -> String {
    let signingShare = try keychain.getSigningShare()
    let storage = self.storage[method] as? Storage

    if (storage == nil) {
      throw MpcError.unsupportedStorageMethod
    }

    if (method == BackupMethods.GoogleDrive.rawValue) {
      (storage as! GDriveStorage).assignAccessToken()

      if ((storage as! GDriveStorage).accessToken == nil) {
        throw MpcError.unableToAuthenticate
      }
    }
    
    let res = ClientBackup(apiKey, mpcHost, signingShare)
    
    let jsonData = res.data(using: .utf8)!
    let rotateResult: RotateResult  = try JSONDecoder().decode(RotateResult.self, from: jsonData)
    guard rotateResult.error == "" else {
      throw MpcError.unexpectedErrorOnBackup(message: rotateResult.error!)
    }
    
    let backupShare = rotateResult.data!.share
    
    var signingShareJson = try JSONParseShare(shareString: signingShare)
    signingShareJson.share = backupShare
    
    let encryptedResult = try encryptShare(mpcShare: signingShareJson)
    
    try storage?.write(privateKey: encryptedResult.privateKey)
        
    return encryptedResult.cipherText
  }
  
  /// Generates an mpc wallet and signing share for a client
  /// - Returns: The address of the newly created mpc wallet
  public func generate() throws -> String {
    let res = ClientGenerate(apiKey, mpcHost)

    let jsonData = res.data(using: .utf8)!
    let generateResult: GenerateResult = try JSONDecoder().decode(GenerateResult.self, from: jsonData)
    guard generateResult.error == "" else {
      throw MpcError.unexpectedErrorOnGenerate(message: generateResult.error!)
    }
    
    let address = generateResult.data!.address
    let mpcShare = generateResult.data!.dkgResult
    try keychain.setAddress(address: address)
    
    let mpcShareData = try JSONEncoder().encode(mpcShare)
    let mpcShareString = String(data: mpcShareData, encoding: .utf8 )!
    try keychain.setSigningShare(signingShare: mpcShareString )
    
    self.address = address
    self.portal?.address = address
    return address
  }
  
  /// Signs a message using mpc
  /// - Parameters:
  ///   - method: the specific rpc method to use when signing
  ///   - params: specific params for the corresponding rpc method
  /// - Returns: the R and S values of the signature
  public func sign(method: String, params: String) throws -> SignData {
    let signingShare = try keychain.getSigningShare()
    
    let res = ClientSign(apiKey, mpcHost, signingShare, method, params, gatewayUrl, String(chainId))

    let jsonData = res.data(using: .utf8)!
    let signResult: SignResult = try JSONDecoder().decode(SignResult.self, from: jsonData)
    guard signResult.error == "" else {
      throw MpcError.unexpectedErrorOnSign(message: signResult.error!)
    }
    
    return SignData(R: signResult.data!.R, S: signResult.data!.S)
  }
  
  /// Uses the backup share to create a new signing share and a new backup share, encrypts the new backup share, stores the private key in cloud storage
  /// - Parameters:
  ///   - cipherText: the cipherText of the backup share (should be passed in from the custodian)
  ///   - method: the speific backup storage option
  /// - Returns: cipherText of the new backup share
  public func recover(
    cipherText: String,
    method: BackupMethods.RawValue,
    completion: @escaping (Result<String>) -> Void
  ) -> Void {
    var storage = self.storage[method] as? Storage
    
    if (storage == nil) {
      return completion(Result(error: MpcError.unsupportedStorageMethod))
    }
    
    getBackupShare(cipherText: cipherText, method: method) {
      (result: Result<String>) -> Void in
      
      do {
        let newSigningShare = try self.recoverSigning(backupShare: result.data!)
        let jsonSigningShare = try JSONEncoder().encode(newSigningShare)
        let stringifiedSigningShare = String(data: jsonSigningShare, encoding: .utf8)
        
        let newBackupShare = try self.recoverBackup(signingShare: stringifiedSigningShare!)
        
        let newBackupShare = try recoverBackup(signingShare: stringifiedSigningShare!)
        let encryptedResult = try encryptShare(mpcShare: newBackupShare)
        
        try storage?.write(privateKey: encryptedResult.privateKey)
 
        
        return completion(Result(data: encryptedResult.cipherText))
      } catch {
        return completion(Result(error: error))
      }
    }
  }
  
  /// Decrypts cipherText using a private key
  /// - Parameters:
  ///   - cipherText: a base64 encoded string of the cipherText
  ///   - privateKey: a base64 encoded string; PEM key format
  /// - Returns: a string of the backupShare object
  private func decryptShare(cipherText: String, privateKey: String) throws -> String {
    let algorithm: SecKeyAlgorithm = .rsaEncryptionOAEPSHA512AESGCM
    
    let options: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
                                  kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
                                  kSecAttrKeySizeInBits as String: 2048,]
    var error: Unmanaged<CFError>?
    let privateKeyBase64 = privateKey.replacingOccurrences(of: rsaHeader, with: "").replacingOccurrences(of: rsaFooter, with: "")
    
    let privateKeyData = Data(base64Encoded: privateKeyBase64)! as CFData
    guard let key = SecKeyCreateWithData(privateKeyData,
                                         options as CFDictionary,
                                         &error) else {
                                            throw error!.takeRetainedValue() as Error
    }
    
    guard SecKeyIsAlgorithmSupported(key, .decrypt, algorithm) else {
      throw RsaError.incompatibleKeyWithAlgorithm
    }
    guard let cipherTextData = Data(base64Encoded: cipherText, options: .ignoreUnknownCharacters) else {throw RsaError.incorrectCipherTextFormat }

    var decryptError: Unmanaged<CFError>?
    guard let clearText = SecKeyCreateDecryptedData(key,
                                                    algorithm,
                                                    cipherTextData as CFData,
                                                    &decryptError) as Data? else {
                                                        throw decryptError!.takeRetainedValue() as Error
    }
    return String(data: clearText, encoding: .utf8)!
                  
  }
  
  /// Encrypts the backup share using a public key that it creates
  /// - Parameter mpcShare: the share to encrypt
  /// - Returns: the cipherText and the private key
  private func encryptShare(mpcShare: MpcShare) throws -> EncryptedResult {
    let mpcShareData = try JSONEncoder().encode(mpcShare)
    let mpcShareString = String(data: mpcShareData, encoding: .utf8 )!
    
    // https://developer.apple.com/documentation/security/certificate_key_and_trust_services/keys/generating_new_cryptographic_keys
    let attributes: CFDictionary =
    [kSecAttrKeyType as String: kSecAttrKeyTypeRSA, // 1
     kSecAttrKeySizeInBits as String: 2048,
     kSecPrivateKeyAttrs as String:
      [kSecAttrIsPermanent as String: false]
    ] as CFDictionary
    
    var error: Unmanaged<CFError>?
    guard let privateKey = SecKeyCreateRandomKey(attributes, &error) else {
        throw error!.takeRetainedValue() as Error
    }
     

    guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
      throw RsaError.unableToGetPublicKey
    }
    
    // https://developer.apple.com/documentation/security/certificate_key_and_trust_services/keys/using_keys_for_encryption
    let algorithm: SecKeyAlgorithm = .rsaEncryptionOAEPSHA512AESGCM
    
    guard SecKeyIsAlgorithmSupported(publicKey, .encrypt, algorithm) else {
      throw RsaError.incompatibleKeyWithAlgorithm
    }
    
    var encyrptDataError: Unmanaged<CFError>?
    guard let cipherText = SecKeyCreateEncryptedData(publicKey,
                                                     algorithm,
                                                     mpcShareString.data(using: .utf8)! as CFData,
                                                     &encyrptDataError) as Data? else {
                                                        throw encyrptDataError!.takeRetainedValue() as Error
    }
    
    var createKeyStringError: Unmanaged<CFError>?
    guard let data = SecKeyCopyExternalRepresentation(privateKey, &createKeyStringError) as? Data else {
        throw createKeyStringError!.takeRetainedValue() as Error
    }
    let base64String = data.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0))

    
    let privateKeyString = "\(rsaHeader)\(base64String)\(rsaFooter)"
    
    return EncryptedResult(privateKey: privateKeyString, cipherText: cipherText.base64EncodedString(options: .lineLength64Characters))
  }
  
  /// Loads the private key from cloud storage, uses that to decrypt the cipherText and returns the string of the backup share
  /// - Parameters:
  ///   - cipherText: the cipherText of the backup share
  ///   - method: the cloud storage method
  /// - Returns: string of the backup share
  private func getBackupShare(
    cipherText: String,
    method: BackupMethods.RawValue,
    completion: @escaping (Result<String>) -> Void
  ) -> Void {
    var storage = self.storage[method] as? Storage
    
    if (storage == nil) {
      return completion(Result(error: MpcError.unsupportedStorageMethod))
    }

    storage!.read() {
      (result: Result<String>) -> Void in
      if (result.data != nil) {
        do {
          let backupShare = try self.decryptShare(cipherText: cipherText, privateKey: result.data!)
          
          return completion(Result(data: backupShare))
        } catch {
          return completion(Result(error: error))
        }
      } else {
        return completion(result)
      }
    }
  }
  
  /// uses the signing share to create a new backup share and returns that share in json format
  /// - Parameter signingShare: the stringied share
  /// - Returns: <#description#>
  private func recoverBackup(signingShare: String) throws -> MpcShare {
    let res = ClientRecoverBackup(apiKey, mpcHost, signingShare)
    
    let jsonData = res.data(using: .utf8)!
    let rotateResult: RotateResult  = try JSONDecoder().decode(RotateResult.self, from: jsonData)
    guard rotateResult.error == "" else {
      throw MpcError.unexpectedErrorOnRecoverBackup(message: rotateResult.error!)
    }
    var newBackup = try JSONParseShare(shareString: signingShare)
    newBackup.share = rotateResult.data!.share
    return newBackup
  }
  
  /// Uses the backup share to create a new signing share and stores it in the keychain
  /// - Parameter backupShare: backup share in string form
  /// - Returns: the new signing share
  private func recoverSigning(backupShare: String) throws -> MpcShare {
    var share = try JSONDecoder().decode(MpcShare.self, from: backupShare.data(using: .utf8)!)
    let result = ClientRecoverSigning(apiKey, mpcHost, backupShare)
    let rotateResult = try JSONDecoder().decode(RotateResult.self, from: result.data(using: .utf8)!)
    
    if (rotateResult.error != nil) {
      throw MpcError.signingRecoveryError(message: rotateResult.error!)
    }
    
    if (rotateResult.data == nil) {
      throw MpcError.signingRecoveryError(message: "Could not read recovery data")
    }
    
    share.share = rotateResult.data!.share
    
    let jsonEncodedShare = try JSONEncoder().encode(share)
    let stringifiedShare = String(data: jsonEncodedShare, encoding: .utf8)
    
    do {
      try keychain.setSigningShare(signingShare: stringifiedShare!)
    } catch {
      throw MpcError.unableToWriteToKeychain
    }
    
    return share
  }
  
  /// Helper function to json parse the mpc share string
  /// - Parameter shareString: string of the mpc share
  /// - Returns: json object of the mpc share
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
