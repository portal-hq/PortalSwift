//
//  PortalStorageSpy.swift
//
//
//  Created by Ahmed Ragab on 07/09/2024.
//

import Foundation
@testable import PortalSwift

public final class PortalStorageSpy: PortalStorage {
  // MARK: - Properties

  public var api: PortalApiProtocol?
  public var encryption: PortalEncryptionProtocol = PortalEncryption()

  // MARK: - Decrypt Method Spy Properties

  private(set) var decryptCallsCount = 0
  private(set) var decryptValueParam: String?
  private(set) var decryptKeyParam: String?
  var decryptReturnValue: String = ""
  var decryptError: Error?

  public func decrypt(_ value: String, withKey: String) async throws -> String {
    decryptCallsCount += 1
    decryptValueParam = value
    decryptKeyParam = withKey
    if let error = decryptError {
      throw error
    }
    return decryptReturnValue
  }

  // MARK: - Delete Method Spy Properties

  private(set) var deleteCallsCount = 0
  var deleteReturnValue: Bool = true
  var deleteError: Error?

  public func delete() async throws -> Bool {
    deleteCallsCount += 1
    if let error = deleteError {
      throw error
    }
    return deleteReturnValue
  }

  // MARK: - Encrypt Method Spy Properties

  private(set) var encryptCallsCount = 0
  private(set) var encryptValueParam: String?
  var encryptReturnValue: EncryptData? = EncryptData(key: "", cipherText: "")
  var encryptError: Error?

  public func encrypt(_ value: String) async throws -> EncryptData {
    encryptCallsCount += 1
    encryptValueParam = value
    if let error = encryptError {
      throw error
    }
    guard let returnValue = encryptReturnValue else {
      throw NSError(domain: "Encrypt Error", code: -1, userInfo: nil)
    }
    return returnValue
  }

  // MARK: - Read Method Spy Properties

  private(set) var readCallsCount = 0
  var readReturnValue: String = ""
  var readError: Error?

  public func read() async throws -> String {
    readCallsCount += 1
    if let error = readError {
      throw error
    }
    return readReturnValue
  }

  // MARK: - Validate Operations Method Spy Properties

  private(set) var validateOperationsCallsCount = 0
  var validateOperationsReturnValue: Bool = true
  var validateOperationsError: Error?

  public func validateOperations() async throws -> Bool {
    validateOperationsCallsCount += 1
    if let error = validateOperationsError {
      throw error
    }
    return validateOperationsReturnValue
  }

  // MARK: - Write Method Spy Properties

  private(set) var writeCallsCount = 0
  private(set) var writeValueParam: String?
  var writeReturnValue: Bool = true
  var writeError: Error?

  public func write(_ value: String) async throws -> Bool {
    writeCallsCount += 1
    writeValueParam = value
    if let error = writeError {
      throw error
    }
    return writeReturnValue
  }
}
