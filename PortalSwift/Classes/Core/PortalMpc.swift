//
//  PortalMpc.swift
//  FBSnapshotTestCase
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation
import Mpc

public struct Birkhoff: Codable {
  public var X: String
  public var Rank: Int
}

public struct MpcShare: Codable {
  public var share: String
  public var pubkey: PublicKey
  public var bks: [Birkhoff]
}

public struct PublicKey: Codable {
  public var X: String
  public var Y: String
}

public struct RotateData: Codable {
  public var share: String
}

private struct RotateResult: Codable {
  public var data: RotateData?
  public var error: String?
}

private enum MpcError: Error {
  case noSigningSharePresent
  case signingRecoveryError(message: String)
  case unableToAuthenticate
  case unableToWriteToKeychain
  case unsupportedStorageMethod
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
    self.mpcHost = String(format: "https://%@", mpcHost)
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
  
  public func recover(cipherText: String, method: BackupMethods.RawValue) throws -> String {
    var storage = self.storage[method] as? Storage
    
    if (storage == nil) {
      throw MpcError.unsupportedStorageMethod
    }
    
    let backupShare = try getBackupShare(cipherText: cipherText, method: method)
    let newSigningShare = try recoverSigning(backupShare: backupShare)
    let jsonSigningShare = try JSONEncoder().encode(newSigningShare)
    let stringifiedSigningShare = String(data: jsonSigningShare, encoding: .utf8)
    
    let newBackupShare = try recoverBackup(signingShare: stringifiedSigningShare!)
    
    // TODO:
    // - Parse newBackupShare
    
    return ""
  }
  
  private func decryptShare(cipherText: String, privateKey: String) throws -> String {
    // TODO: Handle share decryption here
    return ""
  }
  
  private func encryptShare(dkgData: MpcShare) throws -> String {
    // TODO: Handle share encryption here
    return ""
  }
  
  private func getBackupShare(cipherText: String, method: BackupMethods.RawValue) throws -> String {
    var storage = self.storage[method] as? Storage

    if (storage == nil) {
      throw MpcError.unsupportedStorageMethod
    }

    let privateKey = try storage!.read()
    let backupShare = try decryptShare(cipherText: cipherText, privateKey: privateKey)

    return backupShare
  }
  
  private func recoverBackup(signingShare: String) throws -> Any { // <-- Have this return an MpcShare
    let _ = ClientRecoverBackup(apiKey, mpcHost, signingShare)
    
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
    
    let success = try keychain.setSigningShare(signingShare: stringifiedShare!)
    
    if (!success) {
      throw MpcError.unableToWriteToKeychain
    }
    
    return share
  }
}
