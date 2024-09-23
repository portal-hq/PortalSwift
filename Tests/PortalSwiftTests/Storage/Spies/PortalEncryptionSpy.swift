//
//  PortalEncryptionSpy.swift
//
//
//  Created by Ahmed Ragab on 23/09/2024.
//

@testable import PortalSwift

class PortalEncryptionSpy: PortalEncryptionProtocol {
  var decryptWithPrivateKeyCallsCount: Int = 0
  var decryptWithPrivateKeyValueParam: String? = nil
  var decryptWithPrivateKeyPrivateKeyParam: String? = nil
  var decryptWithPrivateKeyReturnValue: String = ""

  func decrypt(_ value: String, withPrivateKey: String) async throws -> String {
    decryptWithPrivateKeyCallsCount += 1
    decryptWithPrivateKeyValueParam = value
    decryptWithPrivateKeyPrivateKeyParam = withPrivateKey
    return decryptWithPrivateKeyReturnValue
  }

  var decryptWithPasswordCallsCount: Int = 0
  var decryptWithPasswordValueParam: String? = nil
  var decryptWithPasswordPrivateKeyParam: String? = nil
  var decryptWithPasswordReturnValue: String = ""

  func decrypt(_ value: String, withPassword: String) async throws -> String {
    decryptWithPasswordCallsCount += 1
    decryptWithPasswordValueParam = value
    decryptWithPasswordPrivateKeyParam = withPassword
    return decryptWithPasswordReturnValue
  }

  var encryptCallsCount: Int = 0
  var encryptValueParam: String? = nil
  var encryptReturnValue: EncryptData = .init(key: "", cipherText: "")

  func encrypt(_ value: String) async throws -> PortalSwift.EncryptData {
    encryptCallsCount += 1
    encryptValueParam = value
    return encryptReturnValue
  }

  var encryptWithPasswordCallsCount: Int = 0
  var encryptWithPasswordValueParam: String? = nil
  var encryptWithPasswordPasswordParam: String? = nil
  var encryptWithPasswordReturnValue: String = ""

  func encrypt(_ value: String, withPassword: String) async throws -> String {
    encryptWithPasswordCallsCount += 1
    encryptWithPasswordValueParam = value
    encryptWithPasswordPasswordParam = withPassword
    return encryptWithPasswordReturnValue
  }
}
