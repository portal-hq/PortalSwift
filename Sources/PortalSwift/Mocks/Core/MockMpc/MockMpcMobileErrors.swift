//
//  MockMpcMobileErrors.swift
//  PortalSwift
//
//  Created by Rami Shahatit on 8/25/23.
//

import Foundation
import Mpc

class MockMobileErrorWrapper: Mobile {
  func MobileGenerateEd25519(_: String, _: String, _: String, _: String) -> String {
    return mockDataResult
  }

  func MobileGenerateSecp256k1(_: String, _: String, _: String, _: String) -> String {
    return mockDataResult
  }

  func MobileBackupEd25519(_: String, _: String, _: String, _: String, _: String) -> String {
    return mockBackupResult
  }

  func MobileBackupSecp256k1(_: String, _: String, _: String, _: String, _: String) -> String {
    return mockBackupResult
  }

  func MobileRecoverSigningEd25519(_: String, _: String, _: String, _: String, _: String) -> String {
    return mockDataResult
  }

  func MobileRecoverSigningSecp256k1(_: String, _: String, _: String, _: String, _: String) -> String {
    return mockDataResult
  }

  func MobileGenerate(_: String, _: String, _: String, _: String) -> String {
    return mockDataResult
  }

  func MobileBackup(_: String, _: String, _: String, _: String, _: String) -> String {
    return mockBackupResult
  }

  func MobileRecoverSigning(_: String, _: String, _: String, _: String, _: String) -> String {
    return mockDataResult
  }

  func MobileRecoverBackup(_: String, _: String, _: String, _: String, _: String) -> String {
    return mockDataResult
  }

  func MobileEncryptWithPassword(data _: String, password _: String) -> String {
    return mockEncryptWithPasswordResult
  }

  func MobileDecryptWithPassword(_: String, _: String) -> String {
    return mockDecryptResult
  }

  func MobileDecrypt(_: String, _: String) -> String {
    return mockDecryptResult
  }

  func MobileEncrypt(_: String) -> String {
    return mockEncryptResult
  }

  func MobileGetMe(_: String, _: String) -> String {
    return mockClientResult
  }

  func MobileGetVersion() -> String {
    return "4.0.1"
  }

  func MobileSign(_: String?, _: String?, _: String?, _: String?, _: String?, _: String?, _: String?, _: String?) -> String {
    return mockClientSignResultWithError
  }

  func MobileEjectWalletAndDiscontinueMPC(_: String, _: String) -> String {
    return mockEjectWalletAndDiscontinueMPC
  }
}
