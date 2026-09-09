//
//  AsyncMutex.swift
//  PortalSwift
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// A FIFO mutual-exclusion lock whose critical section may `await`.
///
/// `PortalAuth` must hold one lock from "read the replay memo" through "exchange the grant
/// over the network" to "write the session to the Keychain", so that two deliveries of the
/// same single-use grant collapse into one exchange and a sign-out cannot land between an
/// exchange and its persist. Neither of Swift's built-in tools fits: an `actor` is reentrant
/// at every suspension point, so a second caller would run the same critical section while
/// the first is awaiting the network; and an `NSLock` cannot be held across an `await`
/// because the continuation may resume on a different thread.
///
/// This type is the smallest sound alternative: an `NSLock`-guarded `isLocked` flag plus a
/// FIFO queue of `CheckedContinuation`s. `withLock` acquires synchronously when the lock is
/// free; otherwise it parks a continuation, appended under the lock so the enqueue and the
/// ownership check are one atomic step. `release` hands ownership to the next waiter by
/// resuming it *without* clearing `isLocked`, so no third party can slip in between.
///
/// Deliberately **non-reentrant** (a body that calls `withLock` on the same mutex deadlocks —
/// `PortalAuth` keeps every locked body in a private `_`-prefixed function that never calls a
/// public lock-taking method) and **not cancellation-aware** (a cancelled waiter still
/// acquires the lock in turn, runs its body and releases). That covers the wait only: the body
/// still runs in the caller's task, so a cancellation-aware call inside it — `URLSession` —
/// would still be aborted. `PortalAuth` therefore also runs its locked bodies in a task of their
/// own (`_shieldedFromCancellation`), so a cancelled sign-in still finishes exchanging and
/// persisting a grant the backend has already burned.
final class AsyncMutex: @unchecked Sendable {
  private let lock = NSLock()
  private var _isLocked = false
  private var waiters: [CheckedContinuation<Void, Never>] = []

  init() {}

  /// `true` while some caller owns the lock, including the instant between a release and the
  /// resumed waiter's body starting (ownership is handed off, never dropped and re-taken).
  var isLocked: Bool {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._isLocked
  }

  /// `true` when at least one caller is parked waiting for the lock. A test seam for proving
  /// that a second delivery of a grant really did wait on the first.
  var isContended: Bool {
    self.waiterCount > 0
  }

  /// The number of parked callers, in FIFO order of arrival.
  var waiterCount: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self.waiters.count
  }

  /// Runs `body` while holding the lock and returns its value, releasing on both the normal
  /// and the throwing path.
  ///
  /// `throws` rather than `rethrows` because the lock itself never throws and the callers in
  /// this module always pass throwing bodies; a single spelling keeps the call sites uniform.
  func withLock<T>(_ body: () async throws -> T) async throws -> T {
    await self.acquire()
    defer { self.release() }
    return try await body()
  }

  /// Takes ownership immediately when the lock is free, otherwise parks until `release`
  /// resumes this caller. The ownership check and the enqueue happen together in
  /// `acquireOrEnqueue`, a synchronous body that runs on the calling thread before the
  /// suspension, so the "check then enqueue" pair cannot be split by a concurrent `release`
  /// and the `NSLock` is never held across an `await`.
  private func acquire() async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      self.acquireOrEnqueue(continuation)
    }
  }

  /// Under the guard: take the lock and resume `continuation` at once when it is free, or park
  /// it at the back of the FIFO queue. Resuming inside the guard is safe because the resumed
  /// body runs only after this closure returns and the guard is released.
  private func acquireOrEnqueue(_ continuation: CheckedContinuation<Void, Never>) {
    self.lock.lock()
    if !self._isLocked {
      self._isLocked = true
      self.lock.unlock()
      continuation.resume()
      return
    }

    self.waiters.append(continuation)
    self.lock.unlock()
  }

  /// Hands the lock to the oldest waiter, or marks it free when nobody is waiting. The waiter
  /// is resumed outside the `NSLock` so its body cannot deadlock on the mutex's own guard.
  private func release() {
    self.lock.lock()
    guard !self.waiters.isEmpty else {
      self._isLocked = false
      self.lock.unlock()
      return
    }

    let next = self.waiters.removeFirst()
    // `_isLocked` stays `true`: ownership moves to `next` without an unlocked gap.
    self.lock.unlock()
    next.resume()
  }
}
