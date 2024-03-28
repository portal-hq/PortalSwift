//
//  MpcMobile.swift
//  PortalSwift
//
//  Created by Rami Shahatit on 8/2/23.
//

import Foundation
import Mpc

class MobileWrapper: Mobile {
  public func MobileGenerate(_ apiKey: String, _ host: String, _ apiHost: String, _ metadata: String) -> String {
    return Mpc.MobileGenerate(apiKey, host, apiHost, metadata)
  }

  func MobileBackup(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) -> String {
    return Mpc.MobileBackup(apiKey, host, signingShare, apiHost, metadata)
  }

  func MobileRecoverSigning(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) -> String {
    return Mpc.MobileRecoverSigning(apiKey, host, signingShare, apiHost, metadata)
  }

  func MobileRecoverBackup(_ apiKey: String, _ host: String, _ signingShare: String, _ apiHost: String, _ metadata: String) -> String {
    return Mpc.MobileRecoverBackup(apiKey, host, signingShare, apiHost, metadata)
  }

  func MobileDecrypt(_ key: String, _ dkgCipherText: String) -> String {
    return Mpc.MobileDecrypt(key, dkgCipherText)
  }

  func MobileDecryptWithPassword(_ key: String, _ dkgCipherText: String) -> String {
    return Mpc.MobileDecryptWithPassword(key, dkgCipherText)
  }

  func MobileEncrypt(_ value: String) -> String {
    return Mpc.MobileEncrypt(value)
  }

  func MobileEncryptWithPassword(data value: String, password: String) -> String {
    return Mpc.MobileEncryptWithPassword(value, password)
  }

  func MobileGetMe(_ url: String, _ token: String) -> String {
    return Mpc.MobileGetMe(url, token)
  }

  func MobileGetVersion() -> String {
    return Mpc.MobileGetVersion()
  }

  func MobileSign(_ apiKey: String?, _ host: String?, _ signingShare: String?, _ method: String?, _ params: String?, _ rpcURL: String?, _ chainId: String?, _ metadata: String?) -> String {
    Mpc.MobileSign(apiKey, host, signingShare, method, params, rpcURL, chainId, metadata)
  }

  func MobileEjectWalletAndDiscontinueMPC(_ clientDkgCipherText: String, _ serverDkgCipherText: String) -> String {
    return Mpc.MobileEjectWalletAndDiscontinueMPC(clientDkgCipherText, serverDkgCipherText)
  }
}
