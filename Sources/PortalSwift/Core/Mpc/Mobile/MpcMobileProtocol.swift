//
//  MpcMobileProtocol.swift
//  PortalSwift
//
//  Created by Rami Shahatit on 8/2/23.
//

import Foundation

public struct MpcMetadata: Codable {
  var backupMethod: BackupMethods.RawValue?
  var clientPlatform: String
  var isMultiBackupEnabled: Bool? = nil
  var mpcServerVersion: String
  var optimized: Bool
}

extension MpcMetadata {
  func jsonString() -> String? {
    let encoder = JSONEncoder()
    if let jsonData = try? encoder.encode(self) {
      return String(data: jsonData, encoding: .utf8)
    }
    return nil
  }
}

public protocol Mobile {
  func MobileGenerate(_ apiKey: String, _ host: String, _ apiHost: String, _ metadata: String) -> String

  func MobileBackup(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) -> String

  func MobileRecoverSigning(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) -> String

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
