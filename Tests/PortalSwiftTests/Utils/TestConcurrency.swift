//
//  TestConcurrency.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
import XCTest

// MARK: - waitUntil

/// Polls `condition` every 10 ms until it returns `true` or `timeout` seconds elapse.
///
/// This is the only way a test in this target is allowed to wait for asynchronous work it
/// cannot `await` directly (a listener hopping to the main actor, a refill `Task`, a hook
/// fired from a transport thread). A fixed sleep either wastes wall-clock time or flakes
/// under load; a bounded poll finishes as soon as the state is observed and still fails
/// deterministically when it never arrives. Returns whether the condition became true so the
/// caller can `XCTAssertTrue` it with a message that names what was expected.
func waitUntil(timeout: TimeInterval = 2, _ condition: @escaping () -> Bool) async -> Bool {
  let deadline = Date().addingTimeInterval(timeout)
  while true {
    if condition() {
      return true
    }
    if Date() >= deadline {
      return false
    }
    try? await Task.sleep(nanoseconds: 10_000_000)
  }
}

// MARK: - withTimeout

/// Runs `operation` and returns its value, or `nil` when it has not finished after `seconds`.
///
/// Used to keep a test that awaits a gated or possibly-deadlocked async operation from hanging
/// the whole suite: the loser of the race is cancelled, so a timed-out operation does not keep
/// running into the next test. An error thrown by the operation propagates unchanged so the
/// caller can still assert on the failure it expected.
func withTimeout<T>(
  _ seconds: TimeInterval = 2,
  _ operation: @escaping @Sendable () async throws -> T
) async throws -> T? {
  try await withThrowingTaskGroup(of: T?.self) { group in
    group.addTask {
      try await operation()
    }
    group.addTask {
      try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
      return nil
    }
    let first = try await group.next() ?? nil
    group.cancelAll()
    return first
  }
}

// MARK: - runConcurrently

/// Thrown by `runConcurrently` when the workers did not all start, or did not all finish,
/// within the hard cap — which is how a deadlock in NSLock-guarded production code shows up as
/// a failed assertion instead of a hung test process.
enum RunConcurrentlyError: LocalizedError {
  case timedOut(after: TimeInterval)

  var errorDescription: String? {
    switch self {
    case let .timedOut(after):
      return "runConcurrently: workers did not complete within \(after) s (possible deadlock)."
    }
  }
}

/// Runs `body` on `times` real threads that are released through one barrier, so every worker
/// is ready before any of them starts and the calls overlap as tightly as the scheduler allows.
///
/// `DispatchQueue.concurrentPerform` cannot promise that overlap — on a two-core CI box it may
/// run the iterations two at a time, which would make a "one storage delete for eight
/// concurrent callers" test pass for the wrong reason. Dedicated `Thread`s that block on a
/// semaphore until all `times` have checked in give the race a fair chance to happen.
/// The first error any worker throws is rethrown after all workers finish; if the workers do
/// not all start or all finish within `timeout` seconds (10 s by default, the suite's hard cap)
/// `RunConcurrentlyError.timedOut` is thrown instead, so a deadlock fails fast.
func runConcurrently(
  _ times: Int,
  timeout: TimeInterval = 10,
  _ body: @escaping (Int) throws -> Void
) throws {
  let ready = DispatchGroup()
  let finished = DispatchGroup()
  let start = DispatchSemaphore(value: 0)
  let lock = NSLock()
  var firstError: Error?

  for index in 0 ..< times {
    ready.enter()
    finished.enter()
    let thread = Thread {
      ready.leave()
      start.wait()
      do {
        try body(index)
      } catch {
        lock.lock()
        if firstError == nil {
          firstError = error
        }
        lock.unlock()
      }
      finished.leave()
    }
    thread.name = "runConcurrently-\(index)"
    thread.start()
  }

  let allReady = ready.wait(timeout: .now() + timeout) == .success
  // Release the workers even on a failed barrier so no thread is left parked forever.
  for _ in 0 ..< times {
    start.signal()
  }
  guard allReady else {
    throw RunConcurrentlyError.timedOut(after: timeout)
  }

  guard finished.wait(timeout: .now() + timeout) == .success else {
    throw RunConcurrentlyError.timedOut(after: timeout)
  }

  lock.lock()
  let error = firstError
  lock.unlock()
  if let error = error {
    throw error
  }
}

/// `runConcurrently(_:timeout:_:)` for a body that does not care which worker it is.
func runConcurrently(
  _ times: Int,
  timeout: TimeInterval = 10,
  _ body: @escaping () throws -> Void
) throws {
  try runConcurrently(times, timeout: timeout) { _ in
    try body()
  }
}

// MARK: - AsyncGate

/// A one-shot gate that suspends any number of async waiters until `open()` is called.
///
/// Built on `CheckedContinuation` rather than a semaphore so a waiting `Task` suspends instead
/// of blocking a cooperative-pool thread — blocking those threads is how async concurrency tests
/// deadlock themselves. `open()` is idempotent and may be called before anyone waits, in which
/// case `wait()` returns immediately. The lock is released before continuations are resumed so
/// a waiter that immediately re-enters the gate cannot deadlock it.
final class AsyncGate: @unchecked Sendable {
  private let lock = NSLock()
  private var _isOpen = false
  private var waiters: [CheckedContinuation<Void, Never>] = []

  init() {}

  /// Whether `open()` has been called.
  var isOpen: Bool {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._isOpen
  }

  /// How many tasks are currently suspended in `wait()`.
  var waiterCount: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self.waiters.count
  }

  /// Opens the gate and resumes every suspended waiter. Safe to call more than once.
  func open() {
    self.lock.lock()
    self._isOpen = true
    let pending = self.waiters
    self.waiters = []
    self.lock.unlock()

    for continuation in pending {
      continuation.resume()
    }
  }

  /// Suspends until the gate is open; returns immediately if it already is.
  func wait() async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      self.lock.lock()
      if self._isOpen {
        self.lock.unlock()
        continuation.resume()
        return
      }
      self.waiters.append(continuation)
      self.lock.unlock()
    }
  }
}
