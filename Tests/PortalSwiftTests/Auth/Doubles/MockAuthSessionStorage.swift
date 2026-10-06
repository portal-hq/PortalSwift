//
//  MockAuthSessionStorage.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift

/// An in-memory `AuthSessionStorage` that keeps the raw persisted string, counts every call and
/// mirrors the one behaviour of `KeychainAuthSessionStorage` that `PortalAuth` and
/// `KeychainPortalSession` depend on: **self-heal**. A stored value the codec rejects is
/// deleted and read as `nil`, so a "corrupt entry reads as signed out and is cleared" test
/// runs against the same contract the real storage keeps.
///
/// Counting rules, because the tests assert on them:
/// - `getCalls` counts only the public `getSession()`. The read inside `deleteIfCurrent(_:)`
///   runs the `onGet` hook and the self-heal, but is not a `getSession()` call, so a session
///   invalidating itself leaves `getCalls == 0`.
/// - `deleteCalls` counts `delete()` **and** the self-heal delete inside a read (that is a real
///   delete the storage performed). `deleteIfCurrent(_:)`'s own clear is counted only in
///   `deleteIfCurrentCalls`.
/// - Every counter is bumped on entry, so a call that then throws from a hook still counts.
///
/// Hooks run outside the lock, so a hook may block, re-enter the mock (`storage.stored = …`
/// inside `onGet` models a login landing mid-read) or throw to simulate a Keychain fault: a
/// throwing `onGet`/`onSet`/`onDelete` propagates as is and leaves `stored` unchanged;
/// `onDeleteIfCurrent` runs right before the compare-and-delete would clear the entry (never
/// when a newer token spares it); `onDeleteAttempted` fires on entry to every delete path.
final class MockAuthSessionStorage: AuthSessionStorage, @unchecked Sendable {
  /// The storage operations, in the order they were entered.
  enum Event: Equatable {
    case get
    case set
    case delete
    case deleteIfCurrent
  }

  private let lock = NSLock()
  private var _stored: String?
  private var _getCalls = 0
  private var _setCalls = 0
  private var _deleteCalls = 0
  private var _deleteIfCurrentCalls = 0
  private var _deleteIfCurrentTokens: [String] = []
  private var _setValues: [String] = []
  private var _events: [Event] = []

  private var _onGet: (() throws -> Void)?
  private var _onSet: ((String) throws -> Void)?
  private var _onDelete: (() throws -> Void)?
  private var _onDeleteIfCurrent: ((String) throws -> Void)?
  private var _onDeleteAttempted: (() -> Void)?

  /// - Parameters:
  ///   - stored: The raw persisted value to start with (use
  ///     `AuthTestFixtures.persistedSession(token:endUserId:)` for a valid one, or any string
  ///     to model corruption). `nil` models an empty slot.
  ///   - onDelete: Installed as the `onDelete` hook; a throwing one models an entry that cannot
  ///     be cleared.
  init(stored: String? = nil, onDelete: (() throws -> Void)? = nil) {
    self._stored = stored
    self._onDelete = onDelete
  }

  // MARK: State

  /// The raw persisted value. Settable so a test can pre-seed a slot or model a newer login
  /// landing behind a session's back.
  var stored: String? {
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

  /// `stored` parsed as a JSON object, or `nil` when empty or not a JSON object. For asserting
  /// the exact persisted shape (`["clientSessionToken": …, "endUserId": …]`, two keys).
  var storedJSON: [String: Any]? {
    guard let raw = self.stored else {
      return nil
    }
    return (try? JSONSerialization.jsonObject(with: Data(raw.utf8))) as? [String: Any]
  }

  /// `stored` decoded through `PersistedSessionCodec`, or `nil` when empty or undecodable.
  /// Does not count as a call and does not self-heal.
  var storedSession: PersistedSession? {
    guard let raw = self.stored else {
      return nil
    }
    return try? PersistedSessionCodec.decode(raw)
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

  /// The token argument of every `deleteIfCurrent(_:)` call, in order.
  var deleteIfCurrentTokens: [String] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._deleteIfCurrentTokens
  }

  /// The raw value of every `set(_:)` call, in order (including calls whose `onSet` threw).
  var setValues: [String] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._setValues
  }

  /// Every operation entered, in order. A self-heal delete inside a read appends `.delete`.
  var events: [Event] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._events
  }

  // MARK: Hooks

  /// Runs at the start of every read (public `getSession()` and the read inside
  /// `deleteIfCurrent(_:)`), before the stored value is looked at. Throw to model a transient
  /// read fault.
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

  /// Runs inside `set(_:)` with the raw value, before it is stored. Throw to model a write fault;
  /// nothing is stored then.
  var onSet: ((String) throws -> Void)? {
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

  /// Runs inside `delete()` and inside the self-heal delete, before the slot is cleared. Throw to
  /// model an entry that cannot be cleared; the value stays.
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

  /// Runs inside `deleteIfCurrent(_:)` right before the slot would be cleared — after the read
  /// and compare, so it never fires when a newer token spares the entry. Throw to model a failed
  /// delete; the value stays.
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

  /// Fires on entry to every path that is about to clear the slot (`delete()`, the self-heal
  /// delete, and `deleteIfCurrent(_:)` once it has decided to delete), before the throwing hook.
  /// The way to prove a sign-out waited for an in-flight login.
  var onDeleteAttempted: (() -> Void)? {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._onDeleteAttempted
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._onDeleteAttempted = newValue
    }
  }

  // MARK: AuthSessionStorage

  func getSession() throws -> PersistedSession? {
    self.lock.lock()
    self._getCalls += 1
    self._events.append(.get)
    self.lock.unlock()

    return try self.read()
  }

  func set(_ raw: String) throws {
    self.lock.lock()
    self._setCalls += 1
    self._setValues.append(raw)
    self._events.append(.set)
    let hook = self._onSet
    self.lock.unlock()

    try hook?(raw)

    self.lock.lock()
    self._stored = raw
    self.lock.unlock()
  }

  func delete() throws {
    try self.performDelete()
  }

  func deleteIfCurrent(_ token: String) throws {
    self.lock.lock()
    self._deleteIfCurrentCalls += 1
    self._deleteIfCurrentTokens.append(token)
    self._events.append(.deleteIfCurrent)
    self.lock.unlock()

    // A read failure propagates, exactly like the real storage: a compare-and-delete that cannot
    // compare must not delete blind, or a stale sign-out could erase a newer login's session.
    let current = try self.read()
    if let current = current, current.clientSessionToken != token {
      // Positively different: a newer login owns the slot. Spare it.
      return
    }

    self.lock.lock()
    let attempted = self._onDeleteAttempted
    let hook = self._onDeleteIfCurrent
    self.lock.unlock()

    attempted?()
    try hook?(token)

    self.lock.lock()
    self._stored = nil
    self.lock.unlock()
  }

  // MARK: Private

  /// The shared read: `onGet`, then decode; a value the codec rejects is deleted (self-heal) and
  /// read as `nil`. Does not count as a `getSession()` call.
  private func read() throws -> PersistedSession? {
    self.lock.lock()
    let hook = self._onGet
    self.lock.unlock()

    try hook?()

    self.lock.lock()
    let raw = self._stored
    self.lock.unlock()

    guard let raw = raw else {
      return nil
    }

    do {
      return try PersistedSessionCodec.decode(raw)
    } catch {
      try self.performDelete()
      return nil
    }
  }

  /// `delete()` and the self-heal delete share this body so both count in `deleteCalls`.
  private func performDelete() throws {
    self.lock.lock()
    self._deleteCalls += 1
    self._events.append(.delete)
    let attempted = self._onDeleteAttempted
    let hook = self._onDelete
    self.lock.unlock()

    attempted?()
    try hook?()

    self.lock.lock()
    self._stored = nil
    self.lock.unlock()
  }
}
