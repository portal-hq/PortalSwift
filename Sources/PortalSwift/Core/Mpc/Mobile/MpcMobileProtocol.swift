//
//  MpcMobileProtocol.swift
//  PortalSwift
//
//  Created by Rami Shahatit on 8/2/23.
//

import Foundation

public struct MpcMetadata: Codable {
  var backupMethod: BackupMethods.RawValue?
  var chainId: String?
  var clientPlatform: String
  var clientPlatformVersion: String?
  var curve: PortalCurve?
  var isMultiBackupEnabled: Bool? = nil
  var mpcServerVersion: String
  var optimized: Bool = true
}

extension MpcMetadata {
  func jsonString() throws -> String {
    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(self)

    guard let jsonString = String(data: jsonData, encoding: .utf8) else {
      throw MpcMetadataError.unableToEncodeJsonString
    }

    return jsonString
  }
}

public enum MpcMetadataError: Error, Equatable {
  case unableToEncodeJsonString
}

public protocol Mobile {
  func MobileGenerate(_ apiKey: String, _ host: String, _ apiHost: String, _ metadata: String) async -> String

  func MobileGenerateEd25519(_ apiKey: String, _ host: String, _ apiHost: String, _ metadata: String) async -> String

  func MobileGenerateSecp256k1(_ apiKey: String, _ host: String, _ apiHost: String, _ metadata: String) async -> String

  func MobileBackup(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) async -> String

  func MobileBackupEd25519(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) async -> String

  func MobileBackupSecp256k1(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) async -> String

  func MobileRecoverSigning(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) async -> String

  func MobileRecoverSigningEd25519(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) async -> String

  func MobileRecoverSigningSecp256k1(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) async -> String

  func MobileRecoverBackup(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) async -> String

  func MobileDecrypt(_ key: String, _ dkgCipherText: String) async -> String

  func MobileEncrypt(_ value: String) async -> String

  func MobileEncryptWithPassword(data value: String, password: String) async -> String

  func MobileDecryptWithPassword(_ key: String, _ dkgCipherText: String) async -> String

  func MobileGetMe(_ url: String, _ token: String) -> String

  func MobileGetVersion() -> String

  func MobileSign(_ apiKey: String?, _ host: String?, _ signingShare: String?, _ method: String?, _ params: String?, _ rpcURL: String?, _ chainId: String?, _ metadata: String?) async -> String

  func MobileEjectWalletAndDiscontinueMPCSecp265K1(_ clientBackupShare: String, _ custodianBackupShare: String) async -> String

  func MobileEjectWalletAndDiscontinueMPCEd25519(_ clientBackupShare: String, _ custodianBackupShare: String) async -> String
}
