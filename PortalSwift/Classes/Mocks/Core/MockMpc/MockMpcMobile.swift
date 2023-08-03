//
//  MockMpcMobile.swift
//  PortalSwift
//
//  Created by Rami Shahatit on 8/2/23.
//

import Foundation
import Mpc

class MockMobileWrapper: Mobile {
  func MobileGenerate(_: String, _: String, _: String) -> String {
    return mockDataResult
  }

  func MobileBackup(_: String, _: String, _: String, _: String) -> String {
    return mockDataResult
  }

  func MobileRecoverSigning(_: String, _: String, _: String, _: String) -> String {
    return mockDataResult
  }

  func MobileRecoverBackup(_: String, _: String, _: String, _: String) -> String {
    return mockDataResult
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
}