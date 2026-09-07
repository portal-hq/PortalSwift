//
//  RecordingSleeper.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift

/// A stand-in for `Task.sleep` injected into `WebSocketClient` through its `sleep:` seam, so the
/// reconnect back-off can be asserted on instead of waited for.
///
/// Every call records the requested delay (`recordedNanoseconds`) and returns immediately, which
/// turns "0.5 s, 1 s, 2 s, 4 s, 8 s" into an array equality instead of a fifteen-second test.
/// Three controls cover what the reconnect tests need beyond that: `onSleep` runs inside the
/// call so a test can change state "during the delay" (rotate or invalidate the credential),
/// `errorToThrow` (typically `CancellationError()`) makes the sleep fail the way a cancelled
/// `Task.sleep` would, and the hold gate (`isHolding` / `resumeAll()` / `release()`) suspends
/// the reconnect inside the delay so a test can send a second drop while the first reconnect is
/// still in flight and prove only one runs. Held sleeps honour task cancellation like the real
/// thing. All state is lock-guarded; the reconnect `Task` runs off the test's thread.
final class RecordingSleeper: @unchecked Sendable {
  private let lock = NSLock()
  private var _recordedNanoseconds: [UInt64] = []
  private var _onSleep: ((UInt64) throws -> Void)?
  private var _errorToThrow: Error?
  private var _isHolding = false
  private var held: [UUID: CheckedContinuation<Void, Error>] = [:]
  private var cancelledBeforeParking: Set<UUID> = []

  init(isHolding: Bool = false) {
    self._isHolding = isHolding
  }

  // MARK: - Recording

  /// The delay requested by each `sleep(_:)` call, in call order, including calls that threw or
  /// are still held.
  var recordedNanoseconds: [UInt64] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._recordedNanoseconds
  }

  /// How many times `sleep(_:)` was called.
  var sleepCallsCount: Int {
    self.recordedNanoseconds.count
  }

  /// The most recently requested delay, if any.
  var lastNanoseconds: UInt64? {
    self.recordedNanoseconds.last
  }

  /// How many sleeps are suspended behind the hold gate right now.
  var pendingSleepCount: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self.held.count
  }

  // MARK: - Configuration

  /// Runs inside every `sleep(_:)` call after the delay is recorded and before anything else.
  /// An error thrown here propagates to the caller (the reconnect task) as the sleep's failure.
  /// Invoked outside the lock so the hook may read this sleeper's own counters.
  var onSleep: ((UInt64) throws -> Void)? {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._onSleep
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._onSleep = newValue
    }
  }

  /// When set, every `sleep(_:)` throws this after recording and running `onSleep`, without
  /// consulting the hold gate. `CancellationError()` reproduces a cancelled `Task.sleep`.
  var errorToThrow: Error? {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._errorToThrow
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._errorToThrow = newValue
    }
  }

  /// While `true`, every `sleep(_:)` suspends until `resumeAll()` or `release()`. Setting it to
  /// `false` does not wake sleeps that are already held; call `resumeAll()` for that.
  var isHolding: Bool {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._isHolding
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._isHolding = newValue
    }
  }

  // MARK: - Hold gate

  /// Resumes every sleep currently held. `isHolding` is unchanged, so the next sleep is held
  /// again — use this to step a test through reconnect attempts one at a time.
  func resumeAll() {
    self.lock.lock()
    let pending = Array(self.held.values)
    self.held.removeAll()
    self.lock.unlock()

    for continuation in pending {
      continuation.resume()
    }
  }

  /// Opens the gate for good: stops holding and resumes every held sleep.
  func release() {
    self.lock.lock()
    self._isHolding = false
    self.lock.unlock()

    self.resumeAll()
  }

  /// Polls until at least `count` sleeps are suspended behind the gate, or `timeout` elapses.
  /// Returns whether the condition was met, so the caller can assert on it by name.
  func waitUntilHeld(_ count: Int = 1, timeout: TimeInterval = 2) async -> Bool {
    await waitUntil(timeout: timeout) { [weak self] in
      (self?.pendingSleepCount ?? 0) >= count
    }
  }

  /// Forgets every recorded delay and resumes anything still held, so no reconnect task is left
  /// suspended into the next test. `onSleep`, `errorToThrow` and `isHolding` are kept.
  func reset() {
    self.lock.lock()
    self._recordedNanoseconds.removeAll()
    self.lock.unlock()

    self.resumeAll()
  }

  // MARK: - The injected sleep

  /// The function handed to `WebSocketClient(sleep:)`. Records `nanoseconds`, runs `onSleep`,
  /// throws `errorToThrow` if set, then either returns at once or suspends behind the hold gate.
  /// Throws `CancellationError` when the calling task is already cancelled, or becomes cancelled
  /// while held, matching `Task.sleep`.
  func sleep(_ nanoseconds: UInt64) async throws {
    self.lock.lock()
    self._recordedNanoseconds.append(nanoseconds)
    let hook = self._onSleep
    let error = self._errorToThrow
    self.lock.unlock()

    try Task.checkCancellation()
    try hook?(nanoseconds)
    if let error = error {
      throw error
    }
    try await self.holdIfNeeded()
  }

  // MARK: - Private

  private func holdIfNeeded() async throws {
    let id = UUID()
    defer {
      self.lock.lock()
      self.cancelledBeforeParking.remove(id)
      self.lock.unlock()
    }

    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        self.lock.lock()
        guard self._isHolding else {
          self.lock.unlock()
          continuation.resume()
          return
        }
        if self.cancelledBeforeParking.remove(id) != nil {
          self.lock.unlock()
          continuation.resume(throwing: CancellationError())
          return
        }
        self.held[id] = continuation
        self.lock.unlock()
      }
    } onCancel: {
      self.lock.lock()
      if let continuation = self.held.removeValue(forKey: id) {
        self.lock.unlock()
        continuation.resume(throwing: CancellationError())
      } else {
        self.cancelledBeforeParking.insert(id)
        self.lock.unlock()
      }
    }
  }
}
