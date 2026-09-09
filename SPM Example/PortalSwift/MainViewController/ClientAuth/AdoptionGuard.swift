//
//  AdoptionGuard.swift
//  SPM Example
//
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// Serializes session adoptions, and joins a redelivery of the very same session onto the run
/// already in flight for it.
///
/// Runs are keyed by session identity — the caller passes `ObjectIdentifier(session)`, never the
/// end user id. The distinction is the whole point: a launch-time restore and a redirect landing
/// milliseconds apart for the *same* user carry two different sessions (the persisted token and a
/// freshly minted one). Keyed by user they would join, the fresh login's own adoption would never
/// run, and a stale restored credential's 401 would fail the valid login with it. Keyed by session
/// the second is queued and runs on its own credential once the first settles.
///
/// Serial, never concurrent: two adoptions running side by side could each call `createWallet()`
/// for the same client. Running one after the other cannot, because the adoption pipeline looks
/// the wallet up before creating and reuses what the earlier run left behind — so a second run is
/// a few redundant reads, not a second wallet. A different *user*'s run is queued for the same
/// reason, plus one more: its completion must be the last writer, so the earlier user's data never
/// lands on a screen that already holds the newcomer's session and Portal.
///
/// Two deliveries with the same key join one run — including a delivery that lands while that run
/// sits queued behind another, which is why the live runs are tracked in a dictionary rather than
/// as a single "current key": with A running and B queued, a third delivery of A must find A's
/// run, not walk past it and enqueue a second one. No call site currently delivers the same
/// session object twice; the join is a backstop, and serialization is the protection.
///
/// The task's failure is captured into a `Result` rather than thrown out of the shared `Task`,
/// for two reasons: a joiner awaiting the value must see the failure instead of inheriting a
/// cancellation, and a `Task` that never throws cannot take a caller's surrounding work down
/// with it.
final class AdoptionGuard<T> {
  private let lock = NSLock()

  /// Guarded by `lock`. Every run in flight or queued, by key. A key present here has a run a
  /// duplicate delivery can join.
  private var runs: [AnyHashable: Task<Result<T, Error>, Never>] = [:]

  /// Guarded by `lock`. Identifies each key's current run so a late release cannot clear a newer
  /// run registered under the same key.
  private var runIds: [AnyHashable: UUID] = [:]

  /// Guarded by `lock`. The most recently enqueued run: what the next run of a *different* key
  /// waits on, which is what keeps adoptions strictly serial however many are outstanding.
  private var tail: Task<Result<T, Error>, Never>?

  /// Guarded by `lock`. Identifies `tail`, so only the run that is still last clears it.
  private var tailRun: UUID?

  var isBusy: Bool {
    self.lock.lock()
    defer { self.lock.unlock() }
    return !self.runs.isEmpty
  }

  /// Starts `task` for `key`, hands back the run already live for the same `key` (calling
  /// `onBusy`), or queues `task` behind the runs already outstanding for other keys (calling
  /// `onQueued`).
  ///
  /// The guard is claimed synchronously, before the task body gets a chance to run: two
  /// deliveries landing on the main thread in the same turn must not both see a free guard.
  ///
  /// The returned `Task` is unstructured and shared by every caller, so a joiner that stops
  /// awaiting — or whose own task is cancelled — never cancels the run itself.
  @discardableResult
  func start(
    key: AnyHashable,
    onBusy: () -> Void = {},
    onQueued: () -> Void = {},
    task: @escaping () async throws -> T
  ) -> Task<Result<T, Error>, Never> {
    self.lock.lock()

    if let existing = self.runs[key] {
      self.lock.unlock()
      onBusy()
      return existing
    }

    let predecessor = self.tail
    let run = UUID()

    // Created while `lock` is held: the body's `release` blocks on the same lock until the
    // registration below has happened, so a task that finishes immediately cannot clear the
    // slot before it was filled.
    let started = Task<Result<T, Error>, Never> { [weak self] in
      if let predecessor = predecessor {
        // The preceding run's outcome is its own callers' business; only its completion
        // matters here, so the two adoptions never overlap.
        _ = await predecessor.value
      }
      let result: Result<T, Error>
      do {
        let value = try await task()
        result = .success(value)
      } catch {
        result = .failure(error)
      }
      self?.release(key: key, run: run)
      return result
    }

    self.runs[key] = started
    self.runIds[key] = run
    self.tail = started
    self.tailRun = run
    self.lock.unlock()

    if predecessor != nil {
      onQueued()
    }
    return started
  }

  /// Frees `key`'s slot once its run has settled, and clears the tail if this run was still it.
  /// A run that has been superseded under either name leaves that name alone: `runIds` and
  /// `tailRun` already point at its successor.
  private func release(key: AnyHashable, run: UUID) {
    self.lock.lock()
    defer { self.lock.unlock() }

    if self.runIds[key] == run {
      self.runs[key] = nil
      self.runIds[key] = nil
    }

    if self.tailRun == run {
      self.tail = nil
      self.tailRun = nil
    }
  }
}
