//
//  AdoptionGuard.swift
//  SPM Example
//
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// Joins overlapping adoptions onto a single run.
///
/// A mutex would be the wrong primitive: it serializes but still runs the task twice, and on the
/// race this exists for — a launch-time session restore and a redirect landing milliseconds
/// apart — twice means two `createWallet()` calls.
///
/// The task's failure is captured into a `Result` rather than thrown out of the shared `Task`,
/// for two reasons: a joiner awaiting the value must see the failure instead of inheriting a
/// cancellation, and a `Task` that never throws cannot take a caller's surrounding work down
/// with it.
final class AdoptionGuard<T> {
  private let lock = NSLock()

  /// Guarded by `lock`. Non-nil exactly while a run is in flight.
  private var inFlight: Task<Result<T, Error>, Never>?

  /// Guarded by `lock`. Identifies the current run so a late release cannot clear a newer one.
  private var currentRun: UUID?

  var isBusy: Bool {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self.inFlight != nil
  }

  /// Starts `task`, or hands back the run already in flight and calls `onBusy`.
  ///
  /// The guard is claimed synchronously, before the task body gets a chance to run: two
  /// deliveries landing on the main thread in the same turn must not both see a free guard.
  ///
  /// The returned `Task` is unstructured and shared by every caller, so a joiner that stops
  /// awaiting — or whose own task is cancelled — never cancels the run itself.
  @discardableResult
  func start(onBusy: () -> Void = {}, task: @escaping () async throws -> T) -> Task<Result<T, Error>, Never> {
    self.lock.lock()

    if let existing = self.inFlight {
      self.lock.unlock()
      onBusy()
      return existing
    }

    let run = UUID()
    self.currentRun = run

    // Created while `lock` is held: the body's `release(run)` blocks on the same lock until the
    // assignment below has happened, so a task that finishes immediately cannot clear the slot
    // before it was filled.
    let started = Task<Result<T, Error>, Never> { [weak self] in
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

    return started
  }

  /// Frees the guard once `run` has settled.
  private func release(_ run: UUID) {
    self.lock.lock()
    defer { self.lock.unlock() }
    guard self.currentRun == run else { return }
    self.inFlight = nil
    self.currentRun = nil
  }
}
