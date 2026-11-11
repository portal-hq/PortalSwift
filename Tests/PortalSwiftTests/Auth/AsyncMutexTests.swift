//
//  AsyncMutexTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

// MARK: - Test doubles

/// Thrown by the body of a `withLock` case that has to fail on purpose.
private enum AsyncMutexTestError: Error, Equatable {
  case body
}

/// An `NSLock`-guarded tally of what happened inside the critical sections.
///
/// The mutex is the thing under test, so nothing here may lean on it: every field is guarded
/// by its own lock, and `maxInside` is the assertion that matters — it can only exceed `1` if
/// two bodies were inside `withLock` at the same moment.
private final class ConcurrencyCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var _inside = 0
  private var _maxInside = 0
  private var _completed = 0
  private var _order: [Int] = []

  /// The highest number of bodies observed inside the lock at once.
  var maxInside: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._maxInside
  }

  /// How many bodies ran to completion (`enter()` followed by `exit()`).
  var completed: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._completed
  }

  /// The ids `record(_:)` was called with, in the order ownership was granted.
  var order: [Int] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._order
  }

  func enter() {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._inside += 1
    self._maxInside = max(self._maxInside, self._inside)
  }

  func exit() {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._inside -= 1
    self._completed += 1
  }

  func record(_ value: Int) {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._order.append(value)
  }
}

/// Samples `AsyncMutex.isLocked` from a dedicated `Thread` for as long as it is running, and
/// remembers whether it ever saw the lock free.
///
/// A hand-off must move ownership from the outgoing holder straight to the next waiter with no
/// unlocked instant in between, and that instant — if it existed — would be far too short for a
/// 10 ms poll to catch. A tight spin on a real thread samples continuously while the hand-off
/// happens, without taking a slot in the cooperative pool the tasks under test need.
private final class UnlockObserver: @unchecked Sendable {
  private let mutex: AsyncMutex
  private let lock = NSLock()
  private var _sawUnlocked = false
  private var _isStopped = false
  private let finished = DispatchSemaphore(value: 0)

  init(mutex: AsyncMutex) {
    self.mutex = mutex
  }

  /// `true` when at least one sample found the lock free.
  var sawUnlocked: Bool {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._sawUnlocked
  }

  func start() {
    let thread = Thread { [self] in
      while true {
        self.lock.lock()
        let isStopped = self._isStopped
        self.lock.unlock()
        if isStopped {
          break
        }

        if !self.mutex.isLocked {
          self.lock.lock()
          self._sawUnlocked = true
          self.lock.unlock()
        }
      }
      self.finished.signal()
    }
    thread.name = "AsyncMutexTests.UnlockObserver"
    thread.start()
  }

  /// Stops sampling and waits (bounded) for the sampling thread to exit, so no observer
  /// outlives its test case.
  func stop() {
    self.lock.lock()
    self._isStopped = true
    self.lock.unlock()
    _ = self.finished.wait(timeout: .now() + 2)
  }
}

// MARK: - AsyncMutexTests

/// Covers `AsyncMutex`, the FIFO lock `PortalAuth` holds from "read the replay memo" through
/// the grant exchange to the Keychain write.
///
/// Everything asserted here is a property `PortalAuth` depends on and neither an `actor` nor an
/// `NSLock` would give it: mutual exclusion across an `await` (an actor is reentrant at every
/// suspension point, which would let a second delivery of the same single-use grant run the
/// same critical section), FIFO grant order, release on the throwing path, hand-off without an
/// unlocked gap (so a sign-out cannot slip between an exchange and its persist), and the two
/// documented sharp edges — non-reentrancy and cancellation-obliviousness — pinned as
/// behaviour rather than left to drift.
///
/// Every wait is bounded (`AuthTestFixtures.pollUntil` / `withTimeout`, at most 2 s) so a
/// regression that would deadlock the lock fails as an assertion instead of hanging the suite,
/// and every parked task is released before the case ends.
final class AsyncMutexTests: XCTestCase {
  private var mutex = AsyncMutex()
  private var logger = RecordingLogger()

  override func setUpWithError() throws {
    try super.setUpWithError()
    CredentialInvalidationRegistry.shared.resetForTesting()
    self.mutex = AsyncMutex()
    self.logger = RecordingLogger()
    self.logger.install()
  }

  override func tearDownWithError() throws {
    self.logger.uninstall()
    CredentialInvalidationRegistry.shared.resetForTesting()
    try super.tearDownWithError()
  }

  // MARK: - withLock

  func test_withLock_willReturnBodyValue() async throws {
    let value = try await self.mutex.withLock { 42 }

    XCTAssertEqual(value, 42, "withLock returns whatever the body returns")
    XCTAssertFalse(self.mutex.isLocked, "The lock is free again once the body has returned")
    XCTAssertFalse(self.mutex.isContended)
  }

  func test_withLock_willSerialiseCriticalSections() async throws {
    let mutex = self.mutex
    let counter = ConcurrencyCounter()

    let completed = try await AuthTestFixtures.withTimeout(2) { () -> Int in
      await withTaskGroup(of: Void.self) { group in
        for _ in 0 ..< 20 {
          group.addTask {
            _ = try? await mutex.withLock {
              counter.enter()
              // A real suspension inside the critical section: this is exactly where an
              // `actor` would let the next caller in.
              await Task.yield()
              counter.exit()
            }
          }
        }
        await group.waitForAll()
      }
      return counter.completed
    }

    XCTAssertEqual(completed, 20, "All 20 critical sections finished within 2 s")
    XCTAssertEqual(counter.maxInside, 1, "Never two bodies inside the lock at once, even across an await")
    XCTAssertFalse(mutex.isLocked)
    XCTAssertFalse(mutex.isContended)
  }

  func test_withLock_willGrantInFifoOrder() async throws {
    let mutex = self.mutex
    let counter = ConcurrencyCounter()
    let holderGate = AsyncGate()

    let holder = Task<Void, Error> {
      try await mutex.withLock {
        await holderGate.wait()
      }
    }
    let didAcquire = await AuthTestFixtures.pollUntil { mutex.isLocked }
    XCTAssertTrue(didAcquire, "The holder took the lock")

    // Started one at a time, each provably parked before the next one arrives, so the queue's
    // arrival order is the order this loop created them in and nothing is left to the scheduler.
    var waiters: [Task<Void, Error>] = []
    for index in 1 ... 3 {
      waiters.append(Task<Void, Error> {
        try await mutex.withLock {
          counter.record(index)
        }
      })
      let didPark = await AuthTestFixtures.pollUntil { mutex.waiterCount == index }
      XCTAssertTrue(didPark, "Waiter \(index) parked before the next one was started")
    }

    holderGate.open()
    try await holder.value
    for waiter in waiters {
      try await waiter.value
    }

    XCTAssertEqual(counter.order, [1, 2, 3], "Ownership is handed on in arrival order, not scheduler order")
    XCTAssertFalse(mutex.isLocked)
    XCTAssertFalse(mutex.isContended)
  }

  func test_withLock_willReleaseOnThrow() async throws {
    let mutex = self.mutex

    await XCTAssertThrowsAsync(try await mutex.withLock { () throws in
      throw AsyncMutexTestError.body
    }) { error in
      XCTAssertEqual(error as? AsyncMutexTestError, .body, "The body's error passes through untouched")
    }

    let value = try await AuthTestFixtures.withTimeout(2) {
      try await mutex.withLock { 1 }
    }

    XCTAssertEqual(value, 1, "A throwing body still released the lock, so the next caller acquires it")
    XCTAssertFalse(mutex.isLocked)
    XCTAssertFalse(mutex.isContended)
  }

  func test_withLock_willHandOffToNextWaiterWithoutReleasing() async throws {
    let mutex = self.mutex
    let counter = ConcurrencyCounter()
    let holderGate = AsyncGate()
    let waiterGate = AsyncGate()

    let holder = Task<Void, Error> {
      try await mutex.withLock {
        await holderGate.wait()
      }
    }
    let didAcquire = await AuthTestFixtures.pollUntil { mutex.isLocked }
    XCTAssertTrue(didAcquire, "The holder took the lock")

    let waiter = Task<Void, Error> {
      try await mutex.withLock {
        counter.record(1)
        await waiterGate.wait()
      }
    }
    let didPark = await AuthTestFixtures.pollUntil { mutex.waiterCount == 1 }
    XCTAssertTrue(didPark, "The waiter parked behind the holder")

    // Samples continuously across the hand-off: `isLocked` must never read `false` between the
    // holder's body returning and the waiter's body starting, or a third caller could slip in
    // between an exchange and its persist.
    let observer = UnlockObserver(mutex: mutex)
    observer.start()
    holderGate.open()
    let waiterStarted = await AuthTestFixtures.pollUntil { counter.order.count == 1 }
    observer.stop()

    XCTAssertTrue(waiterStarted, "The waiter's body ran once the holder returned")
    XCTAssertFalse(observer.sawUnlocked, "Ownership moved to the waiter without the lock ever reading free")
    XCTAssertTrue(mutex.isLocked, "The waiter owns the lock while its body is still running")

    waiterGate.open()
    try await holder.value
    try await waiter.value

    XCTAssertEqual(counter.order, [1], "The waiter's body ran exactly once")
    let didRelease = await AuthTestFixtures.pollUntil { !mutex.isLocked }
    XCTAssertTrue(didRelease, "The lock is free once the waiter's body returned")
  }

  func test_withLock_willStillRunCancelledWaiter_thenRelease() async throws {
    let mutex = self.mutex
    let counter = ConcurrencyCounter()
    let holderGate = AsyncGate()

    let holder = Task<Void, Error> {
      try await mutex.withLock {
        await holderGate.wait()
      }
    }
    let didAcquire = await AuthTestFixtures.pollUntil { mutex.isLocked }
    XCTAssertTrue(didAcquire, "The holder took the lock")

    let waiter = Task<Void, Error> {
      try await mutex.withLock {
        counter.record(2)
      }
    }
    let didPark = await AuthTestFixtures.pollUntil { mutex.waiterCount == 1 }
    XCTAssertTrue(didPark, "The waiter parked behind the holder")

    // The mutex is documented as not cancellation-aware: `PortalAuth` relies on a cancelled
    // sign-in still finishing the persist of a grant the backend has already burned.
    waiter.cancel()
    holderGate.open()
    try await holder.value
    try await waiter.value

    XCTAssertEqual(counter.order, [2], "The cancelled waiter still acquired the lock and ran its body")

    let value = try await AuthTestFixtures.withTimeout(2) {
      try await mutex.withLock { 7 }
    }

    XCTAssertEqual(value, 7, "The cancelled waiter released the lock on its way out")
    XCTAssertFalse(mutex.isLocked)
    XCTAssertFalse(mutex.isContended)
  }

  func test_withLock_willNotStarve_underFiftyAcquirers() async throws {
    let mutex = self.mutex
    let counter = ConcurrencyCounter()

    let completed = try await AuthTestFixtures.withTimeout(2) { () -> Int in
      await withTaskGroup(of: Void.self) { group in
        for _ in 0 ..< 50 {
          group.addTask {
            _ = try? await mutex.withLock {
              counter.enter()
              counter.exit()
            }
          }
        }
        await group.waitForAll()
      }
      return counter.completed
    }

    XCTAssertEqual(completed, 50, "Every acquirer got the lock within 2 s; none was starved")
    XCTAssertEqual(counter.maxInside, 1)
    XCTAssertFalse(mutex.isLocked, "The queue drained completely")
    XCTAssertFalse(mutex.isContended)
  }

  // MARK: - Reentrancy

  func test_withLock_willDetectReentrancyAsTimeout() async throws {
    let mutex = self.mutex
    let counter = ConcurrencyCounter()
    var child: Task<Void, Error>?
    var childParked = false
    var childAcquiredWhileHeld = true
    var waitersWhileHeld = 0

    try await mutex.withLock {
      let task = Task<Void, Error> {
        try await mutex.withLock {
          counter.record(1)
        }
      }
      child = task

      childParked = await AuthTestFixtures.pollUntil { mutex.waiterCount == 1 }
      // Bounded, and deliberately not `await task.value`: awaiting an unstructured task's value
      // ignores the awaiting task's cancellation, so a timeout race around it would deadlock
      // this very test rather than fail it.
      childAcquiredWhileHeld = await AuthTestFixtures.pollUntil(timeout: 0.5) { counter.order.count == 1 }
      waitersWhileHeld = mutex.waiterCount
    }

    XCTAssertTrue(childParked, "The nested acquire parked instead of re-entering")
    XCTAssertFalse(childAcquiredWhileHeld, "AsyncMutex is non-reentrant: the inner body never ran while the outer held the lock")
    XCTAssertEqual(waitersWhileHeld, 1)

    guard let child = child else {
      return XCTFail("The nested task was never created")
    }
    try await child.value

    XCTAssertEqual(counter.order, [1], "The nested body ran once the outer body released the lock")
    XCTAssertFalse(mutex.isLocked, "No task was leaked holding the lock")
    XCTAssertFalse(mutex.isContended)
  }

  // MARK: - Observation seams

  func test_isContended_willReflectQueuedWaiters() async throws {
    let mutex = self.mutex
    let holderGate = AsyncGate()

    XCTAssertFalse(mutex.isContended, "An idle mutex has no waiters")

    let holder = Task<Void, Error> {
      try await mutex.withLock {
        await holderGate.wait()
      }
    }
    let didAcquire = await AuthTestFixtures.pollUntil { mutex.isLocked }
    XCTAssertTrue(didAcquire, "The holder took the lock")
    XCTAssertFalse(mutex.isContended, "A held but unqueued mutex is not contended")

    let waiter = Task<Void, Error> {
      try await mutex.withLock {}
    }
    let didPark = await AuthTestFixtures.pollUntil { mutex.waiterCount == 1 }
    XCTAssertTrue(didPark, "The waiter parked")
    XCTAssertTrue(mutex.isContended, "A parked waiter makes the mutex contended")

    holderGate.open()
    try await holder.value
    try await waiter.value

    let didDrain = await AuthTestFixtures.pollUntil { !mutex.isContended }
    XCTAssertTrue(didDrain, "The queue drained")
    XCTAssertFalse(mutex.isLocked)
  }

  func test_isLocked_willReflectOwnership() async throws {
    XCTAssertFalse(self.mutex.isLocked, "An untouched mutex is free")

    var lockedInsideBody = false
    try await self.mutex.withLock {
      lockedInsideBody = self.mutex.isLocked
    }

    XCTAssertTrue(lockedInsideBody, "The lock reads as held while the body runs")
    XCTAssertFalse(self.mutex.isLocked, "The lock reads as free once the body has returned")
  }
}
