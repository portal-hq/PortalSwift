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

private struct GenerateResult: Codable {
  public var data: GenerateData?
  public var error: String?
}

private struct RotateResult: Codable {
  public var data: RotateData?
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
  case unexpectedErrorOnRecoverBackup(message: String)
  case unableToDecodeSigningShare
  case unableToAuthenticate
  case unableToWriteToKeychain
  case unsupportedStorageMethod
}

public enum RsaError: Error {
  case unableToCreatePrivateKey(message: String)
  case incompatibleKeyWithAlgorithm
  case dataIsTooLongForKey
  case unableToGetPublicKey
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
    print("Backup result", res)
    
    let jsonData = res.data(using: .utf8)!
    let rotateResult: RotateResult  = try JSONDecoder().decode(RotateResult.self, from: jsonData)
    guard rotateResult.error == "" else {
      throw MpcError.unexpectedErrorOnBackup(message: rotateResult.error!)
    }
    
    let backupShare = rotateResult.data!.share
    
    var signingShareJson = try decodeSigningShare(signingShareString: signingShare)
    signingShareJson.share = backupShare
    
    let encryptedResult = try encryptShare(mpcShare: signingShareJson)
    
    print(encryptedResult)
    print(try decryptShare(cipherText: encryptedResult.cipherText, privateKey: encryptedResult.privateKey))
//    try storage?.write(privateKey: encryptedResult.privateKey)
        
    return encryptedResult.cipherText
  }
  
  public func generate() throws -> String {
    let res = ClientGenerate(apiKey, mpcHost)
    print("genearte res", res)

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
  
  public func recover(cipherText: String, method: BackupMethods.RawValue) throws -> String {
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
    
    let _: String = ClientBackup(apiKey, mpcHost, signingShare)
    
    // TODO:
    // - Parse the result JSON string
    // - Build the backupShare
    // - Encrypt the new backupShare
    // - Store the privateKey in Cloud Storage
    // - Return the cipherText
    
    return ""
  }
  
  public func generate() throws -> String {
    let _ = ClientGenerate(apiKey, mpcHost)
    
    // TODO:
    // - Parse the result JSON string
    // - Pop off the address and signing share
    // - Store the values separately in the keychain
    // - Set the value of address on this instance
    // - Set the value of address on the Portal instance
    // - Return the address
    
    return ""
  }
  
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
        
        // TODO:
        // - Parse newBackupShare
        // - Encrypt the newBackupShare
        // - Write the newBackupShare to Cloud Storage
        // - Return the cipherText
        
        return completion(Result(data: ""))
      } catch {
        return completion(Result(error: error))
      }
    }
  }
  
  private func decryptShare(cipherText: String, privateKey: String) throws -> String {
    let algorithm: SecKeyAlgorithm = .rsaEncryptionOAEPSHA512AESGCM
    
    let options: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
                                  kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
                                  kSecAttrKeySizeInBits as String: 2048,]
    var error: Unmanaged<CFError>?
    let privateKeyData = CFData
    print("Data: !", privateKeyData)
    guard let key = SecKeyCreateWithData(privateKey,
                                         options as CFDictionary,
                                         &error) else {
                                            throw error!.takeRetainedValue() as Error
    }
    
    guard SecKeyIsAlgorithmSupported(key, .decrypt, algorithm) else {
      throw RsaError.incompatibleKeyWithAlgorithm
    }
    
    var decryptError: Unmanaged<CFError>?
    guard let clearText = SecKeyCreateDecryptedData(key,
                                                    algorithm,
                                                    cipherText.data(using: .utf8)! as CFData,
                                                    &decryptError) as Data? else {
                                                        throw decryptError!.takeRetainedValue() as Error
    }
    return String(data: clearText, encoding: .utf8)!
                  
  }
  
  private func encryptShare(mpcShare: MpcShare) throws -> EncryptedResult {
    let mpcShareData = try JSONEncoder().encode(mpcShare)
    let mpcShareString = String(data: mpcShareData, encoding: .utf8 )!
    
    //Generation of RSA private and public keys
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
    
    // encrypt dkgData
    // https://developer.apple.com/documentation/security/certificate_key_and_trust_services/keys/using_keys_for_encryption
    let algorithm: SecKeyAlgorithm = .rsaEncryptionOAEPSHA512AESGCM
    
    guard SecKeyIsAlgorithmSupported(publicKey, .encrypt, algorithm) else {
      throw RsaError.incompatibleKeyWithAlgorithm
    }
    
//    guard (mpcShareString.count < (SecKeyGetBlockSize(publicKey)-130)) else {
//      throw RsaError.dataIsTooLongForKey
//    }
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
    
    
    return EncryptedResult(privateKey: String(decoding: data, as: UTF8.self), cipherText: String(decoding: cipherText, as: UTF8.self))
  }
  
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
  
  private func recoverBackup(signingShare: String) throws -> Any {
    let res = ClientRecoverBackup(apiKey, mpcHost, signingShare)
    
    let jsonData = res.data(using: .utf8)!
    let rotateResult: RotateResult  = try JSONDecoder().decode(RotateResult.self, from: jsonData)
    guard rotateResult.error == "" else {
      throw MpcError.unexpectedErrorOnRecoverBackup(message: rotateResult.error!)
    }
    rotateResult.data!.share
    
    return ""
  }
  
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
  
  private func decodeSigningShare(signingShareString: String) throws -> MpcShare {
    var signingShareJson: MpcShare
    do {
      let jsonString = signingShareString.data(using: .utf8)!
      signingShareJson = try JSONDecoder().decode(MpcShare.self, from: jsonString)
    } catch  {
      throw MpcError.unableToDecodeSigningShare
    }
    
    return signingShareJson
  }
}
