//
//  MpcMobile.swift
//  PortalSwift
//
//  Created by Rami Shahatit on 8/2/23.
//

import Foundation
import Mpc

public class MobileWrapper: Mobile {
  public func MobileGenerate(_ apiKey: String, _ host: String, _ version: String) -> String {
    return Mpc.MobileGenerate(apiKey, host, version)
  }

  public func MobileBackup(_ apiKey: String, _ host: String, _ signingShare: String, _ version: String) -> String {
    return Mpc.MobileBackup(apiKey, host, signingShare, version)
  }

  public func MobileRecoverSigning(_ apiKey: String, _ host: String, _ signingShare: String, _ version: String) -> String {
    return Mpc.MobileRecoverSigning(apiKey, host, signingShare, version)
  }

  public func MobileRecoverBackup(_ apiKey: String, _ host: String, _ signingShare: String, _ version: String) -> String {
    return Mpc.MobileRecoverBackup(apiKey, host, signingShare, version)
  }

  public func MobileDecrypt(_ key: String, _ dkgCipherText: String) -> String {
    return Mpc.MobileDecrypt(key, dkgCipherText)
  }

  public func MobileEncrypt(_ value: String) -> String {
    return Mpc.MobileEncrypt(value)
  }

  public func MobileGetMe(_ url: String, _ token: String) -> String {
    return Mpc.MobileGetMe(url, token)
  }

  public func MobileGetVersion() -> String {
    return Mpc.MobileGetVersion()
  }
}
