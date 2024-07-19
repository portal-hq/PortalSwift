//
//  PasswordStorage.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public enum PasswordStorageError: Error {
  case passwordMissing(String)
  case unableToEncodeData
}

/// Responsible for CRUD actions for items in the specified storage.
public class PasswordStorage: Storage, PortalStorage {
  public var api: PortalApi?
  public let encryption: PortalEncryption
  public var password: String?

  public init(encryption: PortalEncryption = PortalEncryption()) {
    self.encryption = encryption
  }

  public func decrypt(_ value: String, withKey: String) async throws -> String {
    let decryptedValue = try await encryption.decrypt(value, withPassword: withKey)

    return decryptedValue
  }

  public func delete() async throws -> Bool {
    return true
  }

  public func encrypt(_ value: String) async throws -> EncryptData {
    do {
      guard let password = self.password else {
        throw PasswordStorageError.passwordMissing("Please set the password before running backup using `portal.setPassword()`.")
      }

      let cipherText = try await encryption.encrypt(value, withPassword: password)

      self.password = nil

      return EncryptData(
        key: password,
        cipherText: cipherText
      )
    } catch {
      self.password = nil
      throw error
    }
  }

  public func read() async throws -> String {
    guard let password = self.password else {
      throw PasswordStorageError.passwordMissing("Please set the password before running recover.")
    }

    self.password = nil

    return password
  }

  public func validateOperations() async throws -> Bool {
    return true
  }

  public func write(_: String) async throws -> Bool {
    return true
  }
}
