//
//  AdoptionGuard.swift
//  SPM Example
//
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// Joins duplicate adoptions of one session onto a single run, and queues the adoption of a
/// different session behind whatever is in flight.
///
/// A mutex would be the wrong primitive: it serializes but still runs the task twice, and on the
/// race this exists for — a launch-time session restore and a redirect landing milliseconds
/// apart for the *same* login — twice means two `createWallet()` calls.
///
/// Runs are keyed by session identity (the caller passes the end user id). Two deliveries with
/// the same key join one run. A different key — launch restores user A while a redirect signs in
/// user B — must not join A's run, because A's completion would then write A's user data into an
/// app that already holds B's session and Portal; nor may it run alongside A, or two wallets
/// could be created at once. It runs after A settles, so B's completion is the last writer.
///
/// The task's failure is captured into a `Result` rather than thrown out of the shared `Task`,
/// for two reasons: a joiner awaiting the value must see the failure instead of inheriting a
/// cancellation, and a `Task` that never throws cannot take a caller's surrounding work down
/// with it.
final class AdoptionGuard<T> {
  private let lock = NSLock()

  /// Guarded by `lock`. Non-nil exactly while a run is in flight or queued.
  private var inFlight: Task<Result<T, Error>, Never>?

  /// Guarded by `lock`. The key of the run `inFlight` is for.
  private var currentKey: AnyHashable?

  /// Guarded by `lock`. Identifies the current run so a late release cannot clear a newer one.
  private var currentRun: UUID?

  var isBusy: Bool {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self.inFlight != nil
  }

  /// Starts `task` for `key`, hands back the run already in flight for the same `key` (calling
  /// `onBusy`), or queues `task` behind the run in flight for a different key (calling
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

    let predecessor: Task<Result<T, Error>, Never>?
    if let existing = self.inFlight {
      if self.currentKey == key {
        self.lock.unlock()
        onBusy()
        return existing
      }
      predecessor = existing
    } else {
      predecessor = nil
    }

    let run = UUID()
    self.currentRun = run
    self.currentKey = key

    // Created while `lock` is held: the body's `release(run)` blocks on the same lock until the
    // assignment below has happened, so a task that finishes immediately cannot clear the slot
    // before it was filled.
    let started = Task<Result<T, Error>, Never> { [weak self] in
      if let predecessor = predecessor {
        // The superseded run's outcome is its own callers' business; only its completion
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
      self?.release(run)
      return result
    }

    self.inFlight = started
    self.lock.unlock()

    if predecessor != nil {
      onQueued()
    }
    return started
  }

  /// Frees the guard once `run` has settled. A superseded run's release is ignored: `currentRun`
  /// already names its successor.
  private func release(_ run: UUID) {
    self.lock.lock()
    defer { self.lock.unlock() }
    guard self.currentRun == run else { return }
    self.inFlight = nil
    self.currentKey = nil
    self.currentRun = nil
  }
}
