//
//  MockPortalSession.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift

/// A scriptable `PortalSession` for host and SDK tests.
///
/// It mirrors the contract of the session `PortalAuth` produces without touching the
/// Keychain: `getToken()` returns `tokenValue` until the session is invalidated and then
/// throws `PortalCredentialError.sessionInvalidated`, and `invalidate()` clears the token
/// *before* it can fail, so a test can prove the SDK treats a failed persisted delete as a
/// session that is nonetheless over. `getTokenError` / `invalidateError` let a test inject
/// any failure at either step. Every property is guarded by one lock so the mock can be
/// driven from the SDK's background work and asserted on from the test thread.
final class MockPortalSession: PortalSession, @unchecked Sendable {
  private let lock = NSLock()
  private var _tokenValue: String?
  private var _getTokenError: Error?
  private var _invalidateError: Error?
  private var _getTokenCalls = 0
  private var _invalidateCalls = 0
  private var _isInvalidated = false

  /// The end user this session belongs to. Fixed for the life of the mock, like a real session.
  let endUserId: String

  /// The client session token `getToken()` hands out, or `nil` once the session has been
  /// invalidated (or when a test wants to start from a dead session).
  var tokenValue: String? {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._tokenValue
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._tokenValue = newValue
    }
  }

  /// When set, `getToken()` throws this instead of returning a token. Checked before the
  /// invalidated state so a test can simulate any provider failure on a live session.
  var getTokenError: Error? {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._getTokenError
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._getTokenError = newValue
    }
  }

  /// When set, `invalidate()` throws this after it has already cleared the token, which is
  /// how a real session behaves when the persisted copy cannot be deleted.
  var invalidateError: Error? {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._invalidateError
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._invalidateError = newValue
    }
  }

  /// How many times `getToken()` has been called, including calls that threw.
  var getTokenCalls: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._getTokenCalls
  }

  /// How many times `invalidate()` has been called, including calls that threw.
  var invalidateCalls: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._invalidateCalls
  }

  /// `true` once `invalidate()` has run, even if it then threw `invalidateError`.
  var isInvalidated: Bool {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._isInvalidated
  }

  /// Creates a live session for `endUserId` holding `tokenValue`; both default to the shared
  /// mock constants so most tests need no arguments.
  init(
    tokenValue: String = MockConstants.mockClientSessionToken,
    endUserId: String = MockConstants.mockEndUserId
  ) {
    self._tokenValue = tokenValue
    self.endUserId = endUserId
  }

  /// Counts the call, throws `getTokenError` if one is set, throws
  /// `PortalCredentialError.sessionInvalidated` when the token has been cleared, and
  /// otherwise returns the token.
  func getToken() throws -> String {
    self.lock.lock()
    self._getTokenCalls += 1
    let error = self._getTokenError
    let token = self._tokenValue
    self.lock.unlock()

    if let error = error {
      throw error
    }
    guard let token = token else {
      throw PortalCredentialError.sessionInvalidated
    }
    return token
  }

  /// Counts the call, clears the token and marks the session invalidated first, then throws
  /// `invalidateError` if one is set — clear-first parity with the real session.
  func invalidate() throws {
    self.lock.lock()
    self._invalidateCalls += 1
    self._tokenValue = nil
    self._isInvalidated = true
    let error = self._invalidateError
    self.lock.unlock()

    if let error = error {
      throw error
    }
  }
}
