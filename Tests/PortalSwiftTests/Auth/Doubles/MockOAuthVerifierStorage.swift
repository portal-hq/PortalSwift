//
//  MockOAuthVerifierStorage.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift

/// An in-memory `OAuthVerifierStorage` that counts every call and mirrors the contract
/// `KeychainOAuthVerifierStorage` keeps: `set(_:)` refuses a malformed verifier without storing
/// it, `deleteIfCurrent(_:)` spares a positively different verifier, never deletes (or runs its
/// delete hook) when nothing is stored, and propagates a read failure instead of deleting blind.
///
/// Counting rules, because the tests assert on them:
/// - `getCalls` counts only the public `get()`. The read inside `deleteIfCurrent(_:)` runs the
///   `onGet` hook but is not a `get()` call.
/// - Every counter is bumped on entry, so a call that then throws from a hook still counts.
///
/// Hooks run outside the lock, so a hook may block, re-enter the mock (`storage.stored = …` inside
/// `onGet` models a newer sign-in landing mid-read) or throw to simulate a Keychain fault. A
/// throwing hook leaves `stored` unchanged.
final class MockOAuthVerifierStorage: OAuthVerifierStorage, @unchecked Sendable {
  /// The storage operations, in the order they were entered.
  enum Event: Equatable {
    case get
    case set
    case delete
    case deleteIfCurrent
  }

  private let lock = NSLock()
  private var _stored: PendingOAuthVerifier?
  private var _getCalls = 0
  private var _setCalls = 0
  private var _deleteCalls = 0
  private var _deleteIfCurrentCalls = 0
  private var _setValues: [PendingOAuthVerifier] = []
  private var _deleteIfCurrentArguments: [String] = []
  private var _events: [Event] = []

  private var _onGet: (() throws -> Void)?
  private var _onSet: ((PendingOAuthVerifier) throws -> Void)?
  private var _onDelete: (() throws -> Void)?
  private var _onDeleteIfCurrent: ((String) throws -> Void)?

  /// - Parameter stored: The pending verifier to start with; `nil` models no sign-in in progress.
  init(stored: PendingOAuthVerifier? = nil) {
    self._stored = stored
  }

  // MARK: State

  /// The pending verifier. Settable so a test can seed a sign-in or model a newer one landing.
  var stored: PendingOAuthVerifier? {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._stored
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._stored = newValue
    }
  }

  // MARK: Counters

  var getCalls: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._getCalls
  }

  var setCalls: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._setCalls
  }

  var deleteCalls: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._deleteCalls
  }

  var deleteIfCurrentCalls: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._deleteIfCurrentCalls
  }

  /// Every value passed to `set(_:)`, in order (including calls whose `onSet` threw).
  var setValues: [PendingOAuthVerifier] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._setValues
  }

  /// The verifier argument of every `deleteIfCurrent(_:)` call, in order.
  var deleteIfCurrentArguments: [String] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._deleteIfCurrentArguments
  }

  /// Every operation entered, in order.
  var events: [Event] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._events
  }

  // MARK: Hooks

  /// Runs at the start of every read (`get()` and the read inside `deleteIfCurrent(_:)`). Throw to
  /// model a transient read fault.
  var onGet: (() throws -> Void)? {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._onGet
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._onGet = newValue
    }
  }

  /// Runs inside `set(_:)` before the value is stored. Throw to model a write fault.
  var onSet: ((PendingOAuthVerifier) throws -> Void)? {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._onSet
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._onSet = newValue
    }
  }

  /// Runs inside `delete()` before the slot is cleared. Throw to model a failed delete.
  var onDelete: (() throws -> Void)? {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._onDelete
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._onDelete = newValue
    }
  }

  /// Runs inside `deleteIfCurrent(_:)` right before the slot would be cleared (never when a newer
  /// verifier spares it). Throw to model a failed delete.
  var onDeleteIfCurrent: ((String) throws -> Void)? {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._onDeleteIfCurrent
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._onDeleteIfCurrent = newValue
    }
  }

  // MARK: OAuthVerifierStorage

  func get() throws -> PendingOAuthVerifier? {
    self.lock.lock()
    self._getCalls += 1
    self._events.append(.get)
    self.lock.unlock()

    return try self.read()
  }

  func set(_ value: PendingOAuthVerifier) throws {
    self.lock.lock()
    self._setCalls += 1
    self._setValues.append(value)
    self._events.append(.set)
    let hook = self._onSet
    self.lock.unlock()

    // The real storage encodes before any Keychain I/O, and refuses a malformed verifier there.
    _ = try PendingOAuthVerifierCodec.encode(value)
    try hook?(value)

    self.lock.lock()
    self._stored = value
    self.lock.unlock()
  }

  func delete() throws {
    self.lock.lock()
    self._deleteCalls += 1
    self._events.append(.delete)
    let hook = self._onDelete
    self.lock.unlock()

    try hook?()

    self.lock.lock()
    self._stored = nil
    self.lock.unlock()
  }

  func deleteIfCurrent(_ verifier: String) throws {
    self.lock.lock()
    self._deleteIfCurrentCalls += 1
    self._deleteIfCurrentArguments.append(verifier)
    self._events.append(.deleteIfCurrent)
    self.lock.unlock()

    // A read failure propagates, exactly like the real storage. Nothing stored, or a newer
    // verifier, means there is nothing to delete — so the delete hook cannot fail either.
    guard let current = try self.read(), current.verifier == verifier else {
      return
    }

    self.lock.lock()
    let hook = self._onDeleteIfCurrent
    self.lock.unlock()

    try hook?(verifier)

    self.lock.lock()
    if self._stored?.verifier == verifier {
      self._stored = nil
    }
    self.lock.unlock()
  }

  // MARK: Private

  private func read() throws -> PendingOAuthVerifier? {
    self.lock.lock()
    let hook = self._onGet
    self.lock.unlock()

    try hook?()

    self.lock.lock()
    defer { self.lock.unlock() }
    return self._stored
  }
}
