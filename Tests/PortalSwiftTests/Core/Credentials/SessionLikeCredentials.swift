//
//  SessionLikeCredentials.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift

/// A credential shaped like a persisted session, built to expose the race the SDK's
/// per-credential monitor exists to prevent.
///
/// A real session's `invalidate()` is check-then-act: it looks at whether a token is held,
/// clears it, and deletes the persisted copy. Two callers that overlap both see the token and
/// both delete. This double reproduces that non-atomic shape on purpose — the "is there a
/// token" read happens before the `onInvalidate` hook (where a test parks the caller for a
/// few milliseconds) and the `storageDeletes` increment happens after it — so a test can
/// prove that `PortalCredentialSupport.invalidate(_:)` serialises the callers: eight overlapping callers
/// must produce eight `invalidateCalls`, one `storageDeletes` and a `maxConcurrentCallers`
/// of one. After invalidation `getToken()` reports no token, either as `""` or, when
/// `throwsWhenInvalidated` is set, as `PortalCredentialError.sessionInvalidated`, so both
/// conforming styles are covered. All counters are lock-guarded; the hook runs outside the
/// lock so a blocking hook cannot deadlock the counters.
final class SessionLikeCredentials: PortalCredentials, @unchecked Sendable {
  private let lock = NSLock()
  private var token: String?
  private var _invalidateCalls = 0
  private var _getTokenCalls = 0
  private var _storageDeletes = 0
  private var _concurrentCallers = 0
  private var _maxConcurrentCallers = 0

  /// When `true`, `getToken()` throws `PortalCredentialError.sessionInvalidated` after the
  /// session has been invalidated; otherwise it returns `""`.
  let throwsWhenInvalidated: Bool

  /// Runs inside `invalidate()` between the "token present" check and the storage delete.
  /// Throw to simulate a failed persisted delete; sleep to widen the race window.
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

  private var _onInvalidate: (() throws -> Void)?

  /// How many times `invalidate()` was called, whether or not it deleted anything.
  var invalidateCalls: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._invalidateCalls
  }

  /// How many times `getToken()` was called, including calls that threw.
  var getTokenCalls: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._getTokenCalls
  }

  /// How many times the (simulated) persisted copy was deleted. Exactly one when the SDK
  /// serialises invalidation; more when overlapping callers each saw the token.
  var storageDeletes: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._storageDeletes
  }

  /// How many `invalidate()` calls are in flight right now.
  var concurrentCallers: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._concurrentCallers
  }

  /// The highest number of `invalidate()` calls that were ever in flight at once.
  var maxConcurrentCallers: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._maxConcurrentCallers
  }

  /// `true` once the token has been cleared.
  var isInvalidated: Bool {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self.token == nil
  }

  /// Creates a live session holding `token` (`"session-token"` by default).
  init(
    token: String = "session-token",
    throwsWhenInvalidated: Bool = false,
    onInvalidate: (() throws -> Void)? = nil
  ) {
    self.token = token
    self.throwsWhenInvalidated = throwsWhenInvalidated
    self._onInvalidate = onInvalidate
  }

  /// Returns the token while the session is live; afterwards reports no token in the
  /// configured style.
  func getToken() throws -> String {
    self.lock.lock()
    self._getTokenCalls += 1
    let current = self.token
    self.lock.unlock()

    if let current = current {
      return current
    }
    if self.throwsWhenInvalidated {
      throw PortalCredentialError.sessionInvalidated
    }
    return ""
  }

  /// Check-then-act invalidation: reads whether a token is held, runs the hook (the race
  /// window), then clears the token and counts a storage delete only if one was held at the
  /// start — exactly the shape that double-deletes when two callers overlap.
  func invalidate() throws {
    self.lock.lock()
    self._invalidateCalls += 1
    self._concurrentCallers += 1
    self._maxConcurrentCallers = max(self._maxConcurrentCallers, self._concurrentCallers)
    let hadToken = self.token != nil
    let hook = self._onInvalidate
    self.lock.unlock()

    defer {
      self.lock.lock()
      self._concurrentCallers -= 1
      self.lock.unlock()
    }

    try hook?()

    if hadToken {
      self.lock.lock()
      self.token = nil
      self._storageDeletes += 1
      self.lock.unlock()
    }
  }
}
