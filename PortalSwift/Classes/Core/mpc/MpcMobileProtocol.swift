//
//  MpcMobile.swift
//  PortalSwift
//
//  Created by Rami Shahatit on 8/2/23.
//

import Foundation

public protocol Mobile {
  func MobileGenerate(_ apiKey: String, _ host: String, _ version: String) -> String

  func MobileBackup(_ apiKey: String, _ host: String, _ signingShare: String, _ version: String) -> String

  func MobileRecoverSigning(_ apiKey: String, _ host: String, _ signingShare: String, _ version: String) -> String

  func MobileRecoverBackup(_ apiKey: String, _ host: String, _ signingShare: String, _ version: String) -> String

  func MobileDecrypt(_ key: String, _ dkgCipherText: String) -> String

  func MobileEncrypt(_ value: String) -> String

  func MobileGetMe(_ url: String, _ token: String) -> String

  func MobileGetVersion() -> String
}
