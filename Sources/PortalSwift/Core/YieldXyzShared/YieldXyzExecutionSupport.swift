//
//  YieldXyzExecutionSupport.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Ids of the actions an instance is executing. Two overlapping executions of one action would
/// both read a transaction awaiting a signature and both sign it.
final class YieldXyzInFlightActions {
  private let lock = NSLock()
  private var actionIds = Set<String>()

  /// Claims `actionId` for one execution; `false` when another execution holds it.
  func claim(_ actionId: String) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return actionIds.insert(actionId).inserted
  }

  func release(_ actionId: String) {
    lock.lock()
    defer { lock.unlock() }
    actionIds.remove(actionId)
  }
}

/// What one tick of `YieldXyzPollLoop` decided.
enum YieldXyzPollStep<T> {
  /// Stop polling and return the value.
  case stop(T)
  /// Poll again after the next interval.
  case `continue`
}

/// `YieldXyzPollLoop` reached its deadline before a tick returned `.stop`.
struct YieldXyzPollLoopTimeout: Error {}

/// A domain-agnostic poll loop (sleep, monotonic deadline, backoff), ported from the React Native
/// SDK's `internal/pollLoop.ts`. Callers classify each read in `tick`.
enum YieldXyzPollLoop {
  /// Runs `tick` until it returns `.stop` (the value is returned) or throws (the error is
  /// rethrown). The first tick runs at once, even with a zero timeout; between ticks the loop
  /// sleeps `interval`, never past the deadline, and the interval grows by 1.5× up to
  /// `maxIntervalSeconds`. Throws `YieldXyzPollLoopTimeout` once the deadline passes.
  static func run<T>(
    intervalSeconds: TimeInterval,
    timeoutSeconds: TimeInterval,
    minIntervalSeconds: TimeInterval = 0,
    maxIntervalSeconds: TimeInterval,
    tick: () async throws -> YieldXyzPollStep<T>
  ) async throws -> T {
    // Monotonic: a wall-clock change must not cut a wait short or stretch it.
    let deadline = YieldXyzExecutionClock.now() + max(0, timeoutSeconds)
    var interval = max(minIntervalSeconds, intervalSeconds)

    // The deadline is checked after each tick, so a zero timeout still reads once.
    while true {
      if case let .stop(value) = try await tick() {
        return value
      }

      let remaining = deadline - YieldXyzExecutionClock.now()
      if remaining <= 0 {
        break
      }
      try await YieldXyzExecutionClock.sleep(seconds: min(interval, remaining))
      interval = min(interval * 1.5, maxIntervalSeconds)
    }

    throw YieldXyzPollLoopTimeout()
  }
}

/// The clock and sleep of the Yield.xyz execution runners.
enum YieldXyzExecutionClock {
  /// Seconds on a monotonic clock.
  static func now() -> TimeInterval {
    ProcessInfo.processInfo.systemUptime
  }

  /// Sleeps `seconds`, honouring task cancellation.
  static func sleep(seconds: TimeInterval) async throws {
    guard seconds > 0, !seconds.isNaN else {
      try Task.checkCancellation()
      return
    }
    // Clamped so the nanosecond conversion cannot overflow UInt64 (about 584 years).
    let nanoseconds = min(seconds, 18_000_000_000) * 1_000_000_000
    try await Task.sleep(nanoseconds: UInt64(nanoseconds))
  }
}

/// Idempotency keys of the on-chain legs the Yield.xyz runners broadcast.
enum YieldXyzIdempotency {
  /// `prefix + transactionId`, or `nil` when the transaction id cannot form a valid key (1–255
  /// characters of `A-Z a-z 0-9 . _ ~ -`).
  static func key(prefix: String, transactionId: String) -> String? {
    let key = prefix + transactionId
    guard !transactionId.isEmpty, (try? validateIdempotencyKey(key)) == key else {
      return nil
    }
    return key
  }
}
