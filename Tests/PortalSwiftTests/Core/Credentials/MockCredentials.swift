//
//  MockCredentials.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift

/// A scriptable `PortalCredentials` for host and SDK tests.
///
/// It records how often the SDK resolved and invalidated it, lets a test change the token
/// between calls (to prove the SDK never caches), and exposes two hooks that run inside
/// `getToken()` / `invalidate()` so a test can make either one throw an arbitrary error or
/// block on a semaphore to stage a race. `maxConcurrentInvalidations` records the highest
/// number of `invalidate()` calls that were ever in flight at once, which is how the
/// "one storage delete however many requesters 401 together" guarantee is asserted.
/// Every property is guarded by one lock so the mock can be driven from several threads,
/// and the hooks run outside that lock so a blocking hook cannot deadlock the counters.
final class MockCredentials: PortalCredentials {
  private let lock = NSLock()
  private var _tokenValue: String
  private var _onGetToken: (() throws -> Void)?
  private var _onInvalidate: (() throws -> Void)?
  private var _getTokenCalls = 0
  private var _invalidateCalls = 0
  private var _activeInvalidations = 0
  private var _maxConcurrentInvalidations = 0

  /// The token `getToken()` returns. Reassign it between calls to prove the SDK resolves
  /// the credential again on every request rather than caching the first value.
  var tokenValue: String {
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

  /// Runs inside `getToken()` after the call is counted and before the token is returned.
  /// Throw to simulate a failing provider; block to hold a request mid-resolution.
  var onGetToken: (() throws -> Void)? {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._onGetToken
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._onGetToken = newValue
    }
  }

  /// Runs inside `invalidate()` after the call is counted. Throw to simulate a persisted
  /// copy that could not be deleted; block to widen the window in which a second caller
  /// would overlap, so serialisation can be observed through `maxConcurrentInvalidations`.
  var onInvalidate: (() throws -> Void)? {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._onInvalidate
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._onInvalidate = newValue
    }
  }

  /// How many times `getToken()` has been called, including calls whose hook threw.
  var getTokenCalls: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._getTokenCalls
  }

  /// How many times `invalidate()` has been called, including calls whose hook threw.
  var invalidateCalls: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._invalidateCalls
  }

  /// The highest number of `invalidate()` calls that were in flight simultaneously. Stays
  /// at `1` when the SDK serialises invalidation correctly, however many callers overlap.
  var maxConcurrentInvalidations: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._maxConcurrentInvalidations
  }

  /// Creates a mock that hands out `tokenValue` (the shared mock API key by default) and
  /// optionally runs the given hooks. The hooks are also settable later, so a test can
  /// arm a failure only after the happy-path calls it needs have gone through.
  init(
    tokenValue: String = MockConstants.mockApiKey,
    onGetToken: (() throws -> Void)? = nil,
    onInvalidate: (() throws -> Void)? = nil
  ) {
    self._tokenValue = tokenValue
    self._onGetToken = onGetToken
    self._onInvalidate = onInvalidate
  }

  /// Counts the call, runs `onGetToken` (which may throw or block), then returns the
  /// current `tokenValue` — read after the hook so a hook that rotates the token is honoured.
  func getToken() throws -> String {
    self.lock.lock()
    self._getTokenCalls += 1
    let hook = self._onGetToken
    self.lock.unlock()

    try hook?()
    return self.tokenValue
  }

  /// Counts the call and tracks how many invalidations are in flight while `onInvalidate`
  /// runs, then lets the hook throw or block. Does not clear `tokenValue`: whether an
  /// invalidated mock keeps answering is the test's choice, made through the hook.
  func invalidate() throws {
    self.lock.lock()
    self._invalidateCalls += 1
    self._activeInvalidations += 1
    self._maxConcurrentInvalidations = max(self._maxConcurrentInvalidations, self._activeInvalidations)
    let hook = self._onInvalidate
    self.lock.unlock()

    defer {
      self.lock.lock()
      self._activeInvalidations -= 1
      self.lock.unlock()
    }

    try hook?()
  }
}
