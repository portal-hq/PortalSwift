//
//  InMemoryAuthInstallIdStore.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift

/// An `AuthInstallIdStore` held in memory, so `KeychainAuthSessionStorage` tests never touch
/// the test host's files. A reinstall is modelled by handing a storage a fresh,
/// empty instance over the same `InMemoryAuthKeychainItemStore`: the Keychain item survives,
/// the install id does not — as on a device. `readError` / `createError` script an id that
/// exists but cannot be read (a locked device) and one that cannot be saved.
final class InMemoryAuthInstallIdStore: AuthInstallIdStore, @unchecked Sendable {
  private let lock = NSLock()
  private var id: String?
  private var _createCount = 0
  private var _readCount = 0
  private var _readError: Error?
  private var _createError: Error?

  /// - Parameter id: The id this install already has, or `nil` for one that has not created it.
  init(id: String? = nil) {
    self.id = id
  }

  /// How many times `currentOrCreate()` had to create an id.
  var createCount: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._createCount
  }

  /// How many times either method was called, failed calls included.
  var readCount: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._readCount
  }

  /// Thrown by both methods while set, as if the id existed but could not be read.
  var readError: Error? {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._readError
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._readError = newValue
    }
  }

  /// Thrown by `currentOrCreate()` when it would create an id, as if it could not be saved.
  var createError: Error? {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._createError
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._createError = newValue
    }
  }

  /// The id as `KeychainAuthSessionStorage` writes it to `kSecAttrGeneric`, or `nil`. Ignores
  /// `readError`.
  var tag: Data? {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self.id.map { Data($0.utf8) }
  }

  func current() throws -> String? {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._readCount += 1
    if let readError = self._readError {
      throw readError
    }
    return self.id
  }

  func currentOrCreate() throws -> String {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._readCount += 1
    if let readError = self._readError {
      throw readError
    }
    if let id = self.id {
      return id
    }
    if let createError = self._createError {
      throw createError
    }
    let created = "install-\(UUID().uuidString)"
    self.id = created
    self._createCount += 1
    return created
  }
}
