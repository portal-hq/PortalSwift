//
//  MpcMobile.swift
//  PortalSwift
//
//  Created by Rami Shahatit on 8/2/23.
//

import Foundation
import Mpc

class MobileWrapper: Mobile {
  func MobileGenerate(
    _ apiKey: String,
    _ host: String,
    _ apiHost: String,
    _ metadata: String
  ) async -> String {
    let result = await withCheckedContinuation { continuation in
      let generateResponse = Mpc.MobileGenerate(apiKey, host, apiHost, metadata)
      continuation.resume(returning: generateResponse)
    }

    return result
  }

  func MobileGenerateEd25519(
    _ apiKey: String,
    _ host: String,
    _ apiHost: String,
    _ metadata: String
  ) async -> String {
    let result = await withCheckedContinuation { continuation in
      let generateResponse = Mpc.MobileGenerateEd25519(apiKey, host, apiHost, metadata)
      continuation.resume(returning: generateResponse)
    }

    return result
  }

  func MobileGenerateSecp256k1(
    _ apiKey: String,
    _ host: String,
    _ apiHost: String,
    _ metadata: String
  ) async -> String {
    let result = await withCheckedContinuation { continuation in
      let generateResponse = Mpc.MobileGenerateSecp256k1(apiKey, host, apiHost, metadata)
      continuation.resume(returning: generateResponse)
    }

    return result
  }

  func MobileBackup(
    _ apiKey: String,
    _ host: String,
    _ signingShare: String,
    _ apiHost: String,
    _ metadata: String
  ) async -> String {
    let result = await withCheckedContinuation { continuation in
      let backupResponse = Mpc.MobileBackup(apiKey, host, signingShare, apiHost, metadata)
      continuation.resume(returning: backupResponse)
    }

    return result
  }

  func MobileBackupEd25519(
    _ apiKey: String,
    _ host: String,
    _ signingShare: String,
    _ apiHost: String,
    _ metadata: String
  ) async -> String {
    let result = await withCheckedContinuation { continuation in
      let backupResponse = Mpc.MobileBackupEd25519(apiKey, host, signingShare, apiHost, metadata)
      continuation.resume(returning: backupResponse)
    }

    return result
  }

  func MobileBackupSecp256k1(
    _ apiKey: String,
    _ host: String,
    _ signingShare: String,
    _ apiHost: String,
    _ metadata: String
  ) async -> String {
    let result = await withCheckedContinuation { continuation in
      let backupResponse = Mpc.MobileBackupSecp256k1(apiKey, host, signingShare, apiHost, metadata)
      continuation.resume(returning: backupResponse)
    }

    return result
  }

  func MobileRecoverBackup(
    _ apiKey: String,
    _ host: String,
    _ signingShare: String,
    _ apiHost: String,
    _ metadata: String
  ) async -> String {
    let result = await withCheckedContinuation { continuation in
      let recoverResponse = Mpc.MobileRecoverBackup(apiKey, host, signingShare, apiHost, metadata)
      continuation.resume(returning: recoverResponse)
    }

    return result
  }

  func MobileRecoverSigning(
    _ apiKey: String,
    _ host: String,
    _ signingShare: String,
    _ apiHost: String,
    _ metadata: String
  ) async -> String {
    let result = await withCheckedContinuation { continuation in
      let recoverResponse = Mpc.MobileRecoverSigning(apiKey, host, signingShare, apiHost, metadata)
      continuation.resume(returning: recoverResponse)
    }

    return result
  }

  func MobileRecoverSigningEd25519(
    _ apiKey: String,
    _ host: String,
    _ signingShare: String,
    _ apiHost: String,
    _ metadata: String
  ) async -> String {
    let result = await withCheckedContinuation { continuation in
      let recoverResponse = Mpc.MobileRecoverSigningEd25519(apiKey, host, signingShare, apiHost, metadata)
      continuation.resume(returning: recoverResponse)
    }

    return result
  }

  func MobileRecoverSigningSecp256k1(
    _ apiKey: String,
    _ host: String,
    _ signingShare: String,
    _ apiHost: String,
    _ metadata: String
  ) async -> String {
    let result = await withCheckedContinuation { continuation in
      let recoverResponse = Mpc.MobileRecoverSigningSecp256k1(apiKey, host, signingShare, apiHost, metadata)
      continuation.resume(returning: recoverResponse)
    }

    return result
  }

  func MobileDecrypt(_ key: String, _ dkgCipherText: String) async -> String {
    let result = await withCheckedContinuation { continuation in
      let decryptResponse = Mpc.MobileDecrypt(key, dkgCipherText)
      continuation.resume(returning: decryptResponse)
    }

    return result
  }

  func MobileDecryptWithPassword(_ key: String, _ dkgCipherText: String) async -> String {
    let result = await withCheckedContinuation { continuation in
      let decryptResponse = Mpc.MobileDecryptWithPassword(key, dkgCipherText)
      continuation.resume(returning: decryptResponse)
    }

    return result
  }

  func MobileEncrypt(_ value: String) async -> String {
    let result = await withCheckedContinuation { continuation in
      let encryptResponse = Mpc.MobileEncrypt(value)
      continuation.resume(returning: encryptResponse)
    }

    return result
  }

  func MobileEncryptWithPassword(data value: String, password: String) async -> String {
    let result = await withCheckedContinuation { continuation in
      let encryptResponse = Mpc.MobileEncryptWithPassword(value, password)
      continuation.resume(returning: encryptResponse)
    }

    return result
  }

  func MobileGetMe(_ url: String, _ token: String) -> String {
    return Mpc.MobileGetMe(url, token)
  }

  func MobileGetVersion() -> String {
    return Mpc.MobileGetVersion()
  }

  func MobileSign(
    _ apiKey: String?,
    _ host: String?,
    _ signingShare: String?,
    _ method: String?,
    _ params: String?,
    _ rpcURL: String?,
    _ chainId: String?,
    _ metadata: String?
  ) async -> String {
    let result = await withCheckedContinuation { continuation in
      let signResponse = Mpc.MobileSign(apiKey, host, signingShare, method, params, rpcURL, chainId, metadata)
      continuation.resume(returning: signResponse)
    }

    return result
  }

  func MobileEjectWalletAndDiscontinueMPC(_ clientDkgCipherText: String, _ serverDkgCipherText: String) async -> String {
    let result = await withCheckedContinuation { continuation in
      let ejectResponse = Mpc.MobileEjectWalletAndDiscontinueMPC(clientDkgCipherText, serverDkgCipherText)
      continuation.resume(returning: ejectResponse)
    }

    return result
  }

  func MobileEjectWalletAndDiscontinueMPCEd25519(_ clientDkgCipherText: String, _ serverDkgCipherText: String) async -> String {
    let result = await withCheckedContinuation { continuation in
      let ejectResponse = Mpc.MobileEjectWalletAndDiscontinueMPCEd25519(clientDkgCipherText, serverDkgCipherText)
      continuation.resume(returning: ejectResponse)
    }

    return result
  }
  
  func MobileGetCustodianIdClientIdHashes(_ custodianIdClientIdJSON: String) -> String {
    return Mpc.MobileGetCustodianIdClientIdHashes(custodianIdClientIdJSON)
  }

  func MobileFormatShares(_ sharesJSON: String) -> String {
    return Mpc.MobileFormatShares(sharesJSON)
  }
}
