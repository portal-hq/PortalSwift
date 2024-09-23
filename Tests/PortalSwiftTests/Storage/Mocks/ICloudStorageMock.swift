//
//  ICloudStorageMock.swift
//
//
//  Created by Ahmed Ragab on 19/09/2024.
//

import Foundation
@testable import PortalSwift

class ICloudStorageMock: PortalStorage {
  var api: PortalSwift.PortalApiProtocol? = nil

  var encryption: PortalSwift.PortalEncryptionProtocol = PortalEncryption()

  var deleteReturnValue: Bool = true
  var deleteCallsCount: Int = 0
  func delete() async throws -> Bool {
    deleteCallsCount += 1
    return deleteReturnValue
  }

  var decryptReturnValue: String = ""
  var decryptCallsCount: Int = 0
  func decrypt(_: String, withKey _: String) async throws -> String {
    decryptCallsCount += 1
    return decryptReturnValue
  }

  var encryptReturnValue: EncryptData = MockConstants.mockEncryptData
  var encryptCallsCount: Int = 0
  func encrypt(_: String) async throws -> EncryptData {
    encryptCallsCount += 1
    return encryptReturnValue
  }

  var readReturnValue: String = ""
  var readCallsCount: Int = 0
  func read() async throws -> String {
    readCallsCount += 1
    return readReturnValue
  }

  var validateOperationsReturnValue: Bool = true
  var validateOperationsCallsCount: Int = 0
  func validateOperations() async throws -> Bool {
    validateOperationsCallsCount += 1
    return validateOperationsReturnValue
  }

  var writeReturnValue: Bool = true
  var writeCallsCount: Int = 0
  func write(_: String) async throws -> Bool {
    writeCallsCount += 1
    return writeReturnValue
  }
}
