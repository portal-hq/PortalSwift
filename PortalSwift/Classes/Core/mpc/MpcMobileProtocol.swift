//
//  MpcMobile.swift
//  PortalSwift
//
//  Created by Rami Shahatit on 8/2/23.
//

import Foundation

public struct MpcMetadata {
  var clientPlatform: String
}

public protocol Mobile {
  func MobileGenerate(_ apiKey: String, _ host: String, _ version: String, _ apiHost: String, _ metadata: MpcMetadata) -> String

  func MobileBackup(_ apiKey: String, _ host: String, _ signingShare: String, _ version: String, _ apiHost: String, _ metadata: MpcMetadata) -> String

  func MobileRecoverSigning(_ apiKey: String, _ host: String, _ signingShare: String, _ version: String, _ apiHost: String, _ metadata: MpcMetadata) -> String

  func MobileRecoverBackup(_ apiKey: String, _ host: String, _ signingShare: String, _ version: String, _ apiHost: String, _ metadata: MpcMetadata) -> String

  func MobileDecrypt(_ key: String, _ dkgCipherText: String) -> String

  func MobileEncrypt(_ value: String) -> String

  func MobileGetMe(_ url: String, _ token: String, _ metadata: MpcMetadata) -> String

  func MobileGetVersion() -> String

  func MobileSign(_ apiKey: String?, _ host: String?, _ signingShare: String?, _ method: String?, _ params: String?, _ rpcURL: String?, _ chainId: String?, _ version: String?, _ metadata: MpcMetadata?) -> String
}
