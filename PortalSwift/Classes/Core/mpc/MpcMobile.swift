//
//  MpcMobile.swift
//  PortalSwift
//
//  Created by Rami Shahatit on 8/2/23.
//

import Foundation
import Mpc

class MobileWrapper: Mobile {
  func MobileGenerate(_ apiKey: String, _ host: String, _ version: String) -> String {
    return Mpc.MobileGenerate(apiKey, host, version)
  }

  func MobileBackup(_ apiKey: String, _ host: String, _ signingShare: String, _ version: String) -> String {
    return Mpc.MobileBackup(apiKey, host, signingShare, version)
  }

  func MobileRecoverSigning(_ apiKey: String, _ host: String, _ signingShare: String, _ version: String) -> String {
    return Mpc.MobileRecoverSigning(apiKey, host, signingShare, version)
  }

  func MobileRecoverBackup(_ apiKey: String, _ host: String, _ signingShare: String, _ version: String) -> String {
    return Mpc.MobileRecoverBackup(apiKey, host, signingShare, version)
  }

  func MobileDecrypt(_ key: String, _ dkgCipherText: String) -> String {
    return Mpc.MobileDecrypt(key, dkgCipherText)
  }

  func MobileEncrypt(_ value: String) -> String {
    return Mpc.MobileEncrypt(value)
  }

  func MobileGetMe(_ url: String, _ token: String) -> String {
    return Mpc.MobileGetMe(url, token)
  }

  func MobileGetVersion() -> String {
    return Mpc.MobileGetVersion()
  }
}
