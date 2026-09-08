//
//  ReportUnauthorizedTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

/// Covers the host-notification half of the credentials layer: `PortalCredentialSupport.reportUnauthorized(_:)`,
/// `PortalCredentialSupport.onInvalidated(_:listener:)`, the `CredentialInvalidationRegistry` behind both,
/// and the `PortalSessionInvalidationHandle` a host holds.
///
/// The contract under test is the one hosts build sign-out UI on: a reported credential is
/// invalidated first and announced second, the announcement happens at most once per
/// credential however many requesters saw the 401, it is delivered asynchronously on the main
/// actor, it never happens for a Client API Key, and a listener may cancel itself, cancel
/// others or subscribe more listeners from inside the callback without deadlocking — which is
/// only possible because the registry lock is never held while a listener runs.
///
/// Delivery is asynchronous (`Task { @MainActor in … }`), so "runs once" is asserted in two
/// steps: `waitUntil` the expected count arrives, then `flushPendingDeliveries()` so any extra
/// delivery that was queued would have run too before the count is read a final time. The
/// registry is reset around each case because its once-ever reported flags would otherwise
/// leak into the next test, and the logger sink is recorded so the secret-leak case is real.
final class ReportUnauthorizedTests: XCTestCase {
  private var logger = RecordingLogger()

  override func setUpWithError() throws {
    try super.setUpWithError()
    CredentialInvalidationRegistry.shared.resetForTesting()
    self.logger = RecordingLogger()
    self.logger.install()
  }

  override func tearDownWithError() throws {
    self.logger.uninstall()
    CredentialInvalidationRegistry.shared.resetForTesting()
    try super.tearDownWithError()
  }

  // MARK: - Helpers

  /// A lock-guarded integer for listeners that are plain closures rather than recorders,
  /// so the same closure value can be subscribed twice and counted from the main actor.
  private final class LockedCounter {
    private let lock = NSLock()
    private var _value = 0

    var value: Int {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._value
    }

    func increment() {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._value += 1
    }
  }

  /// A lock-guarded slot for a value a listener produces on the main actor and the test reads
  /// from its own thread (a handle returned mid-callback, an error thrown on a worker).
  private final class LockedBox<Value> {
    private let lock = NSLock()
    private var _value: Value?

    var value: Value? {
      get {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self._value
      }
      set {
        self.lock.lock()
        defer { self.lock.unlock() }
        self._value = newValue
      }
    }
  }

  /// Drains the main actor so every listener delivery queued before this call has run.
  ///
  /// Two independent mechanisms are used because "nothing else was delivered" cannot be
  /// awaited directly: a hop through `MainActor.run` (which runs behind every job already
  /// enqueued) and a sentinel credential whose own listener is awaited. Once the sentinel's
  /// listener has fired, any delivery for a credential reported earlier has fired too.
  private func flushPendingDeliveries(file: StaticString = #filePath, line: UInt = #line) async {
    await MainActor.run {}
    let sentinel = MockCredentials(tokenValue: "sentinel")
    let recorder = InvalidationListenerRecorder(credentials: sentinel)
    do {
      try PortalCredentialSupport.reportUnauthorized(sentinel)
    } catch {
      XCTFail("The sentinel report threw: \(error)", file: file, line: line)
    }
    let delivered = await waitUntil { recorder.deliveries == 1 }
    XCTAssertTrue(delivered, "The sentinel delivery never arrived; the main actor may be blocked", file: file, line: line)
  }

  // MARK: - reportUnauthorized

  func test_reportUnauthorized_willInvalidateCredentialAndNotifyHost() async throws {
    let credentials = MockCredentials()
    let recorder = InvalidationListenerRecorder(credentials: credentials)

    try PortalCredentialSupport.reportUnauthorized(credentials)

    XCTAssertEqual(credentials.invalidateCalls, 1)
    let delivered = await waitUntil { recorder.deliveries == 1 }
    XCTAssertTrue(delivered, "The host listener must run after a report")
    await self.flushPendingDeliveries()
    XCTAssertEqual(recorder.deliveries, 1, "The listener runs exactly once")
  }

  func test_reportUnauthorized_willNotifyOnce_whenEightRequestersReportConcurrently() async throws {
    let credentials = MockCredentials()
    credentials.onInvalidate = { Thread.sleep(forTimeInterval: 0.02) }
    let recorder = InvalidationListenerRecorder(credentials: credentials)

    try runConcurrently(8) {
      try PortalCredentialSupport.reportUnauthorized(credentials)
    }

    let delivered = await waitUntil { recorder.deliveries == 1 }
    XCTAssertTrue(delivered, "Exactly one host notification is expected for eight concurrent 401s")
    await self.flushPendingDeliveries()
    XCTAssertEqual(recorder.deliveries, 1)
    XCTAssertEqual(credentials.invalidateCalls, 8, "Every requester still invalidates; only the announcement is deduplicated")
  }

  func test_reportUnauthorized_willNotifyOnce_whenReportedSequentially() async throws {
    let credentials = MockCredentials()
    let recorder = InvalidationListenerRecorder(credentials: credentials)

    try PortalCredentialSupport.reportUnauthorized(credentials)
    try PortalCredentialSupport.reportUnauthorized(credentials)

    XCTAssertEqual(credentials.invalidateCalls, 2)
    let delivered = await waitUntil { recorder.deliveries == 1 }
    XCTAssertTrue(delivered)
    await self.flushPendingDeliveries()
    XCTAssertEqual(recorder.deliveries, 1, "A second report of the same credential is silent")
  }

  func test_reportUnauthorized_willNotifyEverySubscriber() async throws {
    let credentials = MockCredentials()
    let first = InvalidationListenerRecorder(credentials: credentials)
    let second = InvalidationListenerRecorder(credentials: credentials)

    try PortalCredentialSupport.reportUnauthorized(credentials)

    let delivered = await waitUntil { first.deliveries == 1 && second.deliveries == 1 }
    XCTAssertTrue(delivered, "Both subscribers must be notified")
    await self.flushPendingDeliveries()
    XCTAssertEqual(first.deliveries, 1)
    XCTAssertEqual(second.deliveries, 1)
  }

  func test_reportUnauthorized_willNotNotify_whenHandleCancelled() async throws {
    let credentials = MockCredentials()
    let recorder = InvalidationListenerRecorder(credentials: credentials)

    recorder.cancel()
    try PortalCredentialSupport.reportUnauthorized(credentials)

    await self.flushPendingDeliveries()
    XCTAssertEqual(recorder.deliveries, 0, "A cancelled subscription must not be notified")
    XCTAssertEqual(credentials.invalidateCalls, 1, "Cancelling a listener does not stop the invalidation itself")
  }

  func test_reportUnauthorized_willKeepOtherSubscribers_whenOneCancelled() async throws {
    let credentials = MockCredentials()
    let dropped = InvalidationListenerRecorder(credentials: credentials)
    let kept = InvalidationListenerRecorder(credentials: credentials)

    dropped.cancel()
    try PortalCredentialSupport.reportUnauthorized(credentials)

    let delivered = await waitUntil { kept.deliveries == 1 }
    XCTAssertTrue(delivered, "The remaining subscriber must still be notified")
    await self.flushPendingDeliveries()
    XCTAssertEqual(kept.deliveries, 1)
    XCTAssertEqual(dropped.deliveries, 0)
  }

  func test_reportUnauthorized_willNeverNotify_forStaticCredentials() async throws {
    let credentials = StaticCredentials("client-api-key")
    let recorder = InvalidationListenerRecorder(credentials: credentials)

    try PortalCredentialSupport.reportUnauthorized(credentials)

    await self.flushPendingDeliveries()
    XCTAssertEqual(recorder.deliveries, 0, "A Client API Key has no session for a 401 to have ended")
    XCTAssertTrue(recorder.handle === PortalSessionInvalidationHandle.spent, "Subscribing on a static key returns the shared spent handle")
    XCTAssertEqual(try credentials.getToken(), "client-api-key", "A static key stays usable after a report")
  }

  func test_reportUnauthorized_willLeaveListenerOnOtherCredentialAlone() async throws {
    let spent = MockCredentials(tokenValue: "spent-token")
    let fresh = MockCredentials(tokenValue: "fresh-token")
    let onSpent = InvalidationListenerRecorder(credentials: spent)
    let onFresh = InvalidationListenerRecorder(credentials: fresh)

    try PortalCredentialSupport.reportUnauthorized(spent)

    let delivered = await waitUntil { onSpent.deliveries == 1 }
    XCTAssertTrue(delivered)
    await self.flushPendingDeliveries()
    XCTAssertEqual(onSpent.deliveries, 1)
    XCTAssertEqual(onFresh.deliveries, 0, "A report is scoped to the credential it was made for")
    XCTAssertEqual(fresh.invalidateCalls, 0)
    XCTAssertEqual(spent.invalidateCalls, 1)
  }

  func test_reportUnauthorized_willNotify_whenInvalidateThrows() async throws {
    struct StorageDeleteFailed: Error {}
    let credentials = MockCredentials()
    credentials.onInvalidate = { throw StorageDeleteFailed() }
    let recorder = InvalidationListenerRecorder(credentials: credentials)

    XCTAssertThrowsError(try PortalCredentialSupport.reportUnauthorized(credentials)) { error in
      XCTAssertTrue(error is StorageDeleteFailed, "Expected the invalidation failure to propagate, got \(error)")
    }

    let delivered = await waitUntil { recorder.deliveries == 1 }
    XCTAssertTrue(delivered, "The host must be told the session ended even when the persisted copy could not be deleted")
    await self.flushPendingDeliveries()
    XCTAssertEqual(recorder.deliveries, 1)
    XCTAssertEqual(credentials.invalidateCalls, 1)
  }

  func test_reportUnauthorized_willPropagateInvalidationFailure() {
    let credentials = MockCredentials()
    let failure = NSError(domain: "io.portalhq.tests", code: 9, userInfo: nil)
    credentials.onInvalidate = { throw failure }

    XCTAssertThrowsError(try PortalCredentialSupport.reportUnauthorized(credentials)) { error in
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, "io.portalhq.tests")
      XCTAssertEqual(nsError.code, 9, "The very same error must reach the caller, unwrapped")
    }
    XCTAssertEqual(credentials.invalidateCalls, 1)
  }

  func test_reportUnauthorized_willIsolateThrowingListener() async throws {
    // Swift listeners cannot throw, so the closest failure a listener can inflict on its
    // siblings is to tear down the registry entry while the registry is delivering: the
    // first listener cancels both subscriptions from inside its callback.
    let credentials = MockCredentials()
    let first = InvalidationListenerRecorder(credentials: credentials)
    let second = InvalidationListenerRecorder(credentials: credentials)
    first.onDeliver = { [weak first, weak second] in
      second?.cancel()
      first?.cancel()
    }

    try PortalCredentialSupport.reportUnauthorized(credentials)

    let delivered = await waitUntil { first.deliveries == 1 && second.deliveries == 1 }
    XCTAssertTrue(delivered, "The second listener must still run: deliveries are snapshotted before any listener is invoked")
    await self.flushPendingDeliveries()
    XCTAssertEqual(first.deliveries, 1)
    XCTAssertEqual(second.deliveries, 1)
    XCTAssertEqual(credentials.invalidateCalls, 1)
  }

  func test_reportUnauthorized_willKeepOnceOnlyGuard_whenListenerMutatesRegistry() async throws {
    let credentials = MockCredentials()
    let lateCounter = LockedCounter()
    let lateHandle = LockedBox<PortalSessionInvalidationHandle>()
    let original = InvalidationListenerRecorder(credentials: credentials)
    original.onDeliver = {
      lateHandle.value = PortalCredentialSupport.onInvalidated(credentials) {
        lateCounter.increment()
      }
    }

    try PortalCredentialSupport.reportUnauthorized(credentials)
    let delivered = await waitUntil { original.deliveries == 1 }
    XCTAssertTrue(delivered)
    try PortalCredentialSupport.reportUnauthorized(credentials)

    await self.flushPendingDeliveries()
    XCTAssertEqual(original.deliveries, 1, "The once-only guard holds: a second report does not re-run the original listener")
    XCTAssertEqual(lateCounter.value, 1, "A listener subscribed during the callback is a late subscriber: the report is replayed to it once, and the second report does not run it again")
    XCTAssertFalse(lateHandle.value === PortalSessionInvalidationHandle.spent, "The mid-callback subscription gets a live handle that could have cancelled its replay")
    XCTAssertEqual(credentials.invalidateCalls, 2)
  }

  func test_reportUnauthorized_willAllowListenerToCancelItself() async throws {
    let credentials = MockCredentials()
    let recorder = InvalidationListenerRecorder(credentials: credentials)
    recorder.onDeliver = { [weak recorder] in
      recorder?.cancel()
    }

    try PortalCredentialSupport.reportUnauthorized(credentials)

    let delivered = await waitUntil { recorder.deliveries == 1 }
    XCTAssertTrue(delivered, "A listener cancelling itself must not deadlock the registry")
    await self.flushPendingDeliveries()
    XCTAssertEqual(recorder.deliveries, 1)
  }

  func test_reportUnauthorized_willNotHoldLockWhileInvokingListener() async throws {
    let blocked = MockCredentials(tokenValue: "blocked")
    let gate = DispatchSemaphore(value: 0)
    defer { gate.signal() }
    let blockedRecorder = InvalidationListenerRecorder(credentials: blocked)
    blockedRecorder.onDeliver = {
      // Parks the main actor inside the listener. Bounded so a regression cannot wedge the
      // whole suite: the test fails on its own assertions instead.
      _ = gate.wait(timeout: .now() + 3)
    }

    try PortalCredentialSupport.reportUnauthorized(blocked)
    let entered = await waitUntil { blockedRecorder.deliveries == 1 }
    XCTAssertTrue(entered, "The blocking listener never started")

    // While that listener is parked, another thread subscribes and reports a different
    // credential. Both calls take the registry lock; they must complete because the lock is
    // not held across the listener invocation.
    let secondReportDone = DispatchSemaphore(value: 0)
    let secondError = LockedBox<Error>()
    let otherRecorder = LockedBox<InvalidationListenerRecorder>()
    DispatchQueue.global().async {
      let other = MockCredentials(tokenValue: "other")
      otherRecorder.value = InvalidationListenerRecorder(credentials: other)
      do {
        try PortalCredentialSupport.reportUnauthorized(other)
      } catch {
        secondError.value = error
      }
      secondReportDone.signal()
    }

    let completed = secondReportDone.wait(timeout: .now() + 2) == .success
    XCTAssertTrue(completed, "reportUnauthorized on another credential must not wait for a listener to return")
    XCTAssertNil(secondError.value)

    gate.signal()
    let bothDelivered = await waitUntil { otherRecorder.value?.deliveries == 1 }
    XCTAssertTrue(bothDelivered, "Once the main actor is released the second credential's listener runs")
    XCTAssertEqual(blockedRecorder.deliveries, 1)
  }

  func test_reportUnauthorized_willNeverLogToken() {
    let secret = "SECRET-CST"
    let credentials = MockCredentials(tokenValue: secret)
    let leakyFailure = NSError(
      domain: "io.portalhq.tests",
      code: 1,
      userInfo: [NSLocalizedDescriptionKey: "could not delete session \(secret) from storage"]
    )
    credentials.onInvalidate = { throw leakyFailure }

    XCTAssertThrowsError(try PortalCredentialSupport.reportUnauthorized(credentials)) { error in
      // The vector is real: the propagated error carries the token in its own description.
      XCTAssertTrue(error.localizedDescription.contains(secret))
    }

    self.logger.assertNoSecret(secret)
  }

  // MARK: - onCredentialsInvalidated

  func test_onCredentialsInvalidated_willTreatSameClosureTwiceAsTwoSubscriptions() async throws {
    let credentials = MockCredentials()
    let counter = LockedCounter()
    let listener: @MainActor () -> Void = { counter.increment() }

    let firstHandle = PortalCredentialSupport.onInvalidated(credentials, listener: listener)
    let secondHandle = PortalCredentialSupport.onInvalidated(credentials, listener: listener)
    XCTAssertFalse(firstHandle === secondHandle, "Each subscription gets its own handle")

    firstHandle.cancel()
    try PortalCredentialSupport.reportUnauthorized(credentials)

    let delivered = await waitUntil { counter.value == 1 }
    XCTAssertTrue(delivered, "The surviving subscription must still run")
    await self.flushPendingDeliveries()
    XCTAssertEqual(counter.value, 1, "Cancelling one of two subscriptions to the same closure leaves exactly one")
  }

  func test_onCredentialsInvalidated_willReplayReport_whenSubscribingAfterReport() async throws {
    let credentials = MockCredentials()
    try PortalCredentialSupport.reportUnauthorized(credentials)

    let recorder = InvalidationListenerRecorder(credentials: credentials)

    await self.flushPendingDeliveries()
    XCTAssertEqual(recorder.deliveries, 1, "A late subscriber on a reported credential is told once, as if it had subscribed in time")
    XCTAssertTrue(recorder.allDeliveredOnMainThread)
    XCTAssertFalse(recorder.handle === PortalSessionInvalidationHandle.spent, "The pending replay is cancellable")
  }

  func test_onCredentialsInvalidated_willNotReplay_whenLateSubscriptionCancelledFirst() async throws {
    let credentials = MockCredentials()
    try PortalCredentialSupport.reportUnauthorized(credentials)

    let recorder = InvalidationListenerRecorder(credentials: credentials)
    recorder.handle.cancel()

    await self.flushPendingDeliveries()
    XCTAssertEqual(recorder.deliveries, 0, "Cancelling before the main-actor hop suppresses the replay")
  }

  func test_onCredentialsInvalidated_willReplayToEachLateSubscriber() async throws {
    let credentials = MockCredentials()
    try PortalCredentialSupport.reportUnauthorized(credentials)

    let first = InvalidationListenerRecorder(credentials: credentials)
    let second = InvalidationListenerRecorder(credentials: credentials)

    await self.flushPendingDeliveries()
    XCTAssertEqual(first.deliveries, 1)
    XCTAssertEqual(second.deliveries, 1, "Each late subscription is its own once-only delivery")
  }

  func test_onCredentialsInvalidated_willReturnSpentHandle_forStaticCredentials() {
    let credentials = StaticCredentials("client-api-key")
    let counter = LockedCounter()

    let handle = PortalCredentialSupport.onInvalidated(credentials) {
      counter.increment()
    }

    XCTAssertTrue(handle === PortalSessionInvalidationHandle.spent)
    handle.cancel()
    handle.cancel()
    XCTAssertTrue(handle === PortalSessionInvalidationHandle.spent, "cancel() on the spent handle is a no-op")
    XCTAssertEqual(counter.value, 0)
    XCTAssertEqual(CredentialInvalidationRegistry.shared.entryCount, 0, "Nothing is retained for a subscription that can never fire")
  }

  func test_onCredentialsInvalidated_willDeliverOnMainActor() async throws {
    let credentials = MockCredentials()
    let recorder = InvalidationListenerRecorder(credentials: credentials)
    let reportError = LockedBox<Error>()
    let reported = DispatchSemaphore(value: 0)

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try PortalCredentialSupport.reportUnauthorized(credentials)
      } catch {
        reportError.value = error
      }
      reported.signal()
    }

    XCTAssertEqual(reported.wait(timeout: .now() + 2), .success)
    XCTAssertNil(reportError.value)
    let delivered = await waitUntil { recorder.deliveries == 1 }
    XCTAssertTrue(delivered)
    XCTAssertTrue(recorder.allDeliveredOnMainThread, "The listener must observe Thread.isMainThread == true regardless of the reporting thread")
    XCTAssertEqual(recorder.mainThreadDeliveries, 1)
  }

  func test_onCredentialsInvalidated_willNotDeliverSynchronously_whenReportedOnMain() async throws {
    let credentials = MockCredentials()
    let recorder = InvalidationListenerRecorder(credentials: credentials)

    // Report from the main actor and read the counter before yielding: the hop through a
    // Task means the listener cannot have run yet, even though it targets this same actor.
    let observedSynchronously = try await MainActor.run(resultType: Int.self) {
      try PortalCredentialSupport.reportUnauthorized(credentials)
      return recorder.deliveries
    }

    XCTAssertEqual(observedSynchronously, 0, "Delivery is asynchronous even when the report is made on the main thread")
    let delivered = await waitUntil { recorder.deliveries == 1 }
    XCTAssertTrue(delivered, "The listener must still run shortly afterwards")
    XCTAssertTrue(recorder.allDeliveredOnMainThread)
  }

  func test_onCredentialsInvalidated_willPruneEntry_whenCredentialDeallocates() async throws {
    let registry = CredentialInvalidationRegistry.shared

    func subscribeScopedCredential() {
      let scoped = MockCredentials(tokenValue: "scoped")
      _ = PortalCredentialSupport.onInvalidated(scoped) {}
      XCTAssertEqual(registry.entryCount, 1)
    }

    subscribeScopedCredential()
    // The entry outlives its credential only until the next registry operation.
    XCTAssertEqual(registry.entryCount, 1, "Pruning is lazy; the stale entry is still counted")

    let other = MockCredentials(tokenValue: "other")
    _ = registry.monitor(for: other)
    XCTAssertEqual(registry.entryCount, 0, "The next registry operation prunes the entry whose credential died")

    // Reporting another credential afterwards is unaffected by the stale entry.
    let recorder = InvalidationListenerRecorder(credentials: other)
    XCTAssertEqual(registry.entryCount, 1)
    try PortalCredentialSupport.reportUnauthorized(other)
    let delivered = await waitUntil { recorder.deliveries == 1 }
    XCTAssertTrue(delivered)
    XCTAssertEqual(registry.entryCount, 0, "A reported credential's entry is dropped: it can never be read again")
  }

  func test_onCredentialsInvalidated_willNotAliasReportedFlag_forReusedObjectIdentifier() async throws {
    // Spend a credential, keep only its identity, and let it die.
    func spendScopedCredential() throws -> ObjectIdentifier {
      let scoped = MockCredentials(tokenValue: "a")
      _ = PortalCredentialSupport.onInvalidated(scoped) {}
      try PortalCredentialSupport.reportUnauthorized(scoped)
      return ObjectIdentifier(scoped)
    }
    let staleIdentity = try spendScopedCredential()

    // Allocate until the allocator hands back the same address, retaining every miss so it
    // cannot keep recycling some other slot.
    var retained: [MockCredentials] = []
    var reused: MockCredentials?
    for _ in 0 ..< 5000 where reused == nil {
      let candidate = MockCredentials(tokenValue: "b")
      if ObjectIdentifier(candidate) == staleIdentity {
        reused = candidate
      } else {
        retained.append(candidate)
      }
    }
    guard let credentialB = reused else {
      throw XCTSkip("The allocator did not reuse the freed address; the aliasing scenario could not be staged.")
    }

    let recorder = InvalidationListenerRecorder(credentials: credentialB)
    XCTAssertFalse(recorder.handle === PortalSessionInvalidationHandle.spent, "A fresh credential at a stale address must not read as already reported")

    try PortalCredentialSupport.reportUnauthorized(credentialB)

    let delivered = await waitUntil { recorder.deliveries == 1 }
    XCTAssertTrue(delivered, "The reported set is keyed by weak box and re-checked with ===, so B is reportable")
    await self.flushPendingDeliveries()
    XCTAssertEqual(recorder.deliveries, 1)
    XCTAssertEqual(credentialB.invalidateCalls, 1)
    withExtendedLifetime(retained) {}
  }

  // MARK: - PortalSessionInvalidationHandle

  func test_PortalSessionInvalidationHandle_init_willInvokeOnCancelOnce() {
    let counter = LockedCounter()
    let handle = PortalSessionInvalidationHandle(onCancel: { counter.increment() })

    handle.cancel()
    handle.cancel()
    handle.cancel()

    XCTAssertEqual(counter.value, 1, "onCancel runs exactly once however many times cancel() is called")
  }

  func test_PortalSessionInvalidationHandle_cancel_willBeIdempotent() async throws {
    let credentials = MockCredentials()
    let recorder = InvalidationListenerRecorder(credentials: credentials)

    recorder.cancel()
    recorder.cancel()
    try PortalCredentialSupport.reportUnauthorized(credentials)

    await self.flushPendingDeliveries()
    XCTAssertEqual(recorder.deliveries, 0, "A twice-cancelled subscription stays cancelled and never runs")
    XCTAssertEqual(credentials.invalidateCalls, 1)
  }

  func test_PortalSessionInvalidationHandle_deinit_willNotAutoCancel() async throws {
    let credentials = MockCredentials()
    let counter = LockedCounter()

    func subscribeAndDropHandle() {
      _ = PortalCredentialSupport.onInvalidated(credentials) {
        counter.increment()
      }
    }
    subscribeAndDropHandle()

    try PortalCredentialSupport.reportUnauthorized(credentials)

    let delivered = await waitUntil { counter.value == 1 }
    XCTAssertTrue(delivered, "Dropping the handle must not unsubscribe: parity with React Native and Android")
    await self.flushPendingDeliveries()
    XCTAssertEqual(counter.value, 1)
  }

  func test_PortalSessionInvalidationHandle_spent_willBeSharedSingleton() {
    let first = PortalSessionInvalidationHandle.spent
    let second = PortalSessionInvalidationHandle.spent
    let fromStaticKey = PortalCredentialSupport.onInvalidated(StaticCredentials("client-api-key")) {}

    XCTAssertTrue(first === second, "spent is one shared instance")
    XCTAssertTrue(fromStaticKey === first, "Every subscription that can never fire returns the same handle")

    first.cancel()
    second.cancel()
    XCTAssertTrue(PortalSessionInvalidationHandle.spent === first, "cancel() on the spent handle is a no-op and leaves the singleton in place")
  }
}
