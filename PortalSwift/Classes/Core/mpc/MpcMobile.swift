//
//  MpcMobile.swift
//  PortalSwift
//
//  Created by Rami Shahatit on 8/2/23.
//

import Foundation
import Mpc

class MobileWrapper: Mobile {
  public func MobileGenerate(_ apiKey: String, _ host: String, _ version: String, _ apiHost: String, _ metadata: MpcMetadata) -> String {
    return Mpc.MobileGenerate(apiKey, host, version, apiHost, metadata)
  }

  func MobileBackup(_ apiKey: String, _ host: String, _ signingShare: String, _ version: String, _ apiHost: String, _ metadata: MpcMetadata) -> String {
    return Mpc.MobileBackup(apiKey, host, signingShare, version, apiHost, metadata)
  }

  func MobileRecoverSigning(_ apiKey: String, _ host: String, _ signingShare: String, _ version: String, _ apiHost: String, _ metadata: MpcMetadata) -> String {
    return Mpc.MobileRecoverSigning(apiKey, host, signingShare, version, apiHost, metadata)
  }

  func MobileRecoverBackup(_ apiKey: String, _ host: String, _ signingShare: String, _ version: String, _ apiHost: String, _ metadata: MpcMetadata) -> String {
    return Mpc.MobileRecoverBackup(apiKey, host, signingShare, version, apiHost, metadata)
  }

  func MobileDecrypt(_ key: String, _ dkgCipherText: String) -> String {
    return Mpc.MobileDecrypt(key, dkgCipherText)
  }

  func MobileEncrypt(_ value: String) -> String {
    return Mpc.MobileEncrypt(value)
  }

  func MobileGetMe(_ url: String, _ token: String, _ metadata: MpcMetadata) -> String {
    return Mpc.MobileGetMe(url, token, metadata)
  }

  func MobileGetVersion() -> String {
    return Mpc.MobileGetVersion()
  }

  func MobileSign(_ apiKey: String?, _ host: String?, _ signingShare: String?, _ method: String?, _ params: String?, _ rpcURL: String?, _ chainId: String?, _ version: String?, _ metadata: MpcMetadata?) -> String {
    Mpc.MobileSign(apiKey, host, signingShare, method, params, rpcURL, chainId, version, metadata)
  }
}
