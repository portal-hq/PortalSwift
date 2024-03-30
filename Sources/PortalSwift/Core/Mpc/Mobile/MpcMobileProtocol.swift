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
  var curve: PortalCurve?
  var isMultiBackupEnabled: Bool? = nil
  var mpcServerVersion: String
  var optimized: Bool
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
  func MobileGenerate(_ apiKey: String, _ host: String, _ apiHost: String, _ metadata: String) -> String

  func MobileGenerateEd25519(_ apiKey: String, _ host: String, _ apiHost: String, _ metadata: String) -> String

  func MobileGenerateSecp256k1(_ apiKey: String, _ host: String, _ apiHost: String, _ metadata: String) -> String

  func MobileBackup(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) -> String

  func MobileBackupEd25519(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) -> String

  func MobileBackupSecp256k1(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) -> String

  func MobileRecoverSigning(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) -> String

  func MobileRecoverSigningEd25519(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) -> String

  func MobileRecoverSigningSecp256k1(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) -> String

  func MobileRecoverBackup(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) -> String

  func MobileDecrypt(_ key: String, _ dkgCipherText: String) -> String

  func MobileEncrypt(_ value: String) -> String

  func MobileEncryptWithPassword(data value: String, password: String) -> String

  func MobileDecryptWithPassword(_ key: String, _ dkgCipherText: String) -> String

  func MobileGetMe(_ url: String, _ token: String) -> String

  func MobileGetVersion() -> String

  func MobileSign(_ apiKey: String?, _ host: String?, _ signingShare: String?, _ method: String?, _ params: String?, _ rpcURL: String?, _ chainId: String?, _ metadata: String?) -> String

  func MobileEjectWalletAndDiscontinueMPC(_ clientDkgCipherText: String, _ serverDkgCipherText: String) -> String
}
