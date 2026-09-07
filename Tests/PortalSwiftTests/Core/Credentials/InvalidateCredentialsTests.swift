//
//  InvalidateCredentialsTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
import ObjectiveC
@testable import PortalSwift
import XCTest

/// Covers `invalidateCredentials(_:)` and the per-credential monitor it takes from
/// `CredentialInvalidationRegistry`: one storage delete however many callers overlap, a
/// guard that is released after success and failure alike, identity (not value) keying,
/// re-entrancy without deadlock, pruning of dead entries, and the silence of the
/// host-initiated path.
///
/// Concurrency cases run on real threads through `runConcurrently`, which also doubles as the
/// deadlock detector: a body that never returns surfaces as `RunConcurrentlyError.timedOut`
/// instead of hanging the suite.
final class InvalidateCredentialsTests: XCTestCase {
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

  /// A credential whose `invalidate()` takes the Objective-C runtime monitor on itself — the
  /// synchronisation a host written with `@synchronized(self)` would use. The SDK must never
  /// take that same monitor, or a host holding it while calling the SDK would deadlock.
  private final class ObjcSyncingCredentials: PortalCredentials {
    private let lock = NSLock()
    private var _invalidateCalls = 0

    var invalidateCalls: Int {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._invalidateCalls
    }

    func getToken() throws -> String {
      "host-token"
    }

    func invalidate() throws {
      objc_sync_enter(self)
      defer { objc_sync_exit(self) }
      Thread.sleep(forTimeInterval: 0.02)
      self.lock.lock()
      self._invalidateCalls += 1
      self.lock.unlock()
    }
  }

  /// A lock-guarded flag for "only do this once" hooks.
  private final class OnceFlag {
    private let lock = NSLock()
    private var fired = false

    /// Returns `true` the first time only.
    func trip() -> Bool {
      self.lock.lock()
      defer { self.lock.unlock() }
      if self.fired {
        return false
      }
      self.fired = true
      return true
    }
  }

  // MARK: - invalidateCredentials

  func test_invalidateCredentials_willCallInvalidateOnce() throws {
    let credentials = MockCredentials()

    XCTAssertNoThrow(try invalidateCredentials(credentials))

    XCTAssertEqual(credentials.invalidateCalls, 1)
  }

  func test_invalidateCredentials_willProduceOneStorageDelete_whenEightCallersOverlap() throws {
    let credentials = SessionLikeCredentials(onInvalidate: { Thread.sleep(forTimeInterval: 0.02) })

    try runConcurrently(8) {
      try invalidateCredentials(credentials)
    }

    XCTAssertEqual(credentials.invalidateCalls, 8)
    XCTAssertEqual(credentials.storageDeletes, 1, "Serialised callers must find the token already cleared")
  }

  func test_invalidateCredentials_willSerializeInvalidations_soNeverTwoAtOnce() throws {
    let credentials = SessionLikeCredentials(onInvalidate: { Thread.sleep(forTimeInterval: 0.02) })

    try runConcurrently(8) {
      try invalidateCredentials(credentials)
    }

    XCTAssertEqual(credentials.maxConcurrentCallers, 1, "Two invalidations of one credential must never overlap")
    XCTAssertEqual(credentials.concurrentCallers, 0)
  }

  func test_invalidateCredentials_willRunAgain_afterPriorInvalidationSettles() throws {
    let credentials = MockCredentials()

    try invalidateCredentials(credentials)
    try invalidateCredentials(credentials)

    XCTAssertEqual(credentials.invalidateCalls, 2, "The guard is a monitor, not a once-only flag; idempotence is the credential's job")
  }

  func test_invalidateCredentials_willReleaseGuard_whenInvalidationFails() throws {
    let firstCall = OnceFlag()
    let credentials = MockCredentials(onInvalidate: {
      if firstCall.trip() {
        throw NSError(domain: "ks", code: 1)
      }
    })

    XCTAssertThrowsError(try invalidateCredentials(credentials))
    XCTAssertNoThrow(try invalidateCredentials(credentials))

    XCTAssertEqual(credentials.invalidateCalls, 2)
  }

  func test_invalidateCredentials_willPropagateInvalidationFailure() {
    let credentials = MockCredentials(onInvalidate: { throw NSError(domain: "ks", code: 9) })

    XCTAssertThrowsError(try invalidateCredentials(credentials)) { error in
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, "ks")
      XCTAssertEqual(nsError.code, 9)
      XCTAssertFalse(error is PortalCredentialError, "The credential's own error must reach the caller unchanged")
    }
  }

  func test_invalidateCredentials_willInvalidateDistinctCredentialsIndependently() throws {
    let first = SessionLikeCredentials()
    let second = SessionLikeCredentials()

    try invalidateCredentials(first)

    XCTAssertEqual(first.storageDeletes, 1)
    XCTAssertEqual(first.invalidateCalls, 1)
    XCTAssertEqual(second.invalidateCalls, 0)
    XCTAssertEqual(second.storageDeletes, 0)
    XCTAssertEqual(try second.getToken(), "session-token")
  }

  func test_invalidateCredentials_willNotCollapseEqualByValueCredentials() throws {
    let first = MockCredentials(tokenValue: "same")
    let second = MockCredentials(tokenValue: "same")

    try invalidateCredentials(first)
    try invalidateCredentials(second)

    XCTAssertEqual(first.invalidateCalls, 1)
    XCTAssertEqual(second.invalidateCalls, 1, "Keyed by identity, not by token value")
  }

  func test_invalidateCredentials_willLeaveSessionReportingNoToken() throws {
    let silent = SessionLikeCredentials()
    let throwing = SessionLikeCredentials(throwsWhenInvalidated: true)
    XCTAssertEqual(try silent.getToken(), "session-token")
    XCTAssertEqual(try throwing.getToken(), "session-token")

    try invalidateCredentials(silent)
    try invalidateCredentials(throwing)

    XCTAssertEqual(try silent.getToken(), "")
    XCTAssertTrue(silent.isInvalidated)
    XCTAssertThrowsError(try throwing.getToken()) { error in
      XCTAssertEqual(error as? PortalCredentialError, .sessionInvalidated)
    }
    XCTAssertThrowsError(try resolveCredentialToken(silent)) { error in
      XCTAssertEqual(error as? PortalCredentialError, .unavailable, "A blank token after invalidation surfaces as .unavailable at the boundary")
    }
  }

  func test_invalidateCredentials_willBeNoOp_forStaticCredentials() throws {
    let credentials = StaticCredentials("k")

    XCTAssertNoThrow(try invalidateCredentials(credentials))

    XCTAssertEqual(try credentials.getToken(), "k")
    XCTAssertEqual(try resolveCredentialToken(credentials), "k")
  }

  func test_invalidateCredentials_willNotDeadlock_whenInvalidateReentersForSameCredential() throws {
    let credentials = MockCredentials()
    let reentered = OnceFlag()
    credentials.onInvalidate = { [weak credentials] in
      guard let credentials = credentials, reentered.trip() else {
        return
      }
      try invalidateCredentials(credentials)
    }

    // A single worker with a 2 s cap: a non-recursive monitor would park here forever.
    XCTAssertNoThrow(try runConcurrently(1, timeout: 2) {
      try invalidateCredentials(credentials)
    })

    XCTAssertEqual(credentials.invalidateCalls, 2)
  }

  func test_invalidateCredentials_willNotDeadlock_whenInvalidateInvalidatesAnotherCredential() throws {
    let credentialB = MockCredentials(tokenValue: "b", onInvalidate: { Thread.sleep(forTimeInterval: 0.02) })
    let credentialA = MockCredentials(tokenValue: "a")
    credentialA.onInvalidate = { [weak credentialB] in
      Thread.sleep(forTimeInterval: 0.02)
      guard let credentialB = credentialB else {
        return
      }
      try invalidateCredentials(credentialB)
    }

    XCTAssertNoThrow(try runConcurrently(2, timeout: 2) { index in
      if index == 0 {
        try invalidateCredentials(credentialA)
      } else {
        try invalidateCredentials(credentialB)
      }
    })

    XCTAssertEqual(credentialA.invalidateCalls, 1)
    XCTAssertEqual(credentialB.invalidateCalls, 2, "A's invalidation reached B once, plus the direct call")
    XCTAssertEqual(credentialB.maxConcurrentInvalidations, 1)
  }

  func test_invalidateCredentials_willPruneMonitor_whenCredentialDeallocates() throws {
    let registry = CredentialInvalidationRegistry.shared

    func invalidateScopedCredential() throws {
      let scoped = MockCredentials()
      try invalidateCredentials(scoped)
    }

    try invalidateScopedCredential()
    for _ in 0 ..< 50 {
      try invalidateScopedCredential()
    }

    XCTAssertLessThanOrEqual(registry.monitorCount, 1, "Dead monitors must be pruned as credentials come and go")

    // One live credential forces a prune of whatever was left and must be the only entry.
    let anchor = MockCredentials()
    try invalidateCredentials(anchor)
    XCTAssertEqual(registry.monitorCount, 1)
    XCTAssertEqual(anchor.invalidateCalls, 1)
  }

  func test_invalidateCredentials_willNotAliasReusedObjectIdentifier() async throws {
    // Report (and thereby "spend") a credential, keep only its identity, and let it die.
    func spendScopedCredential() throws -> ObjectIdentifier {
      let scoped = MockCredentials(tokenValue: "a")
      try reportUnauthorized(scoped)
      return ObjectIdentifier(scoped)
    }
    let staleIdentity = try spendScopedCredential()

    // Allocate until the allocator hands back the same address; keep the misses alive so it
    // cannot keep recycling one other slot.
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

    // A fresh credential at a stale address must not inherit the reported flag ...
    let recorder = InvalidationListenerRecorder(credentials: credentialB)
    XCTAssertFalse(recorder.handle === PortalSessionInvalidationHandle.spent, "A reused address must not read as already reported")

    // ... nor a stale monitor: two overlapping callers are still serialised on a fresh one.
    credentialB.onInvalidate = { Thread.sleep(forTimeInterval: 0.02) }
    try runConcurrently(2, timeout: 2) {
      try invalidateCredentials(credentialB)
    }
    XCTAssertEqual(credentialB.invalidateCalls, 2)
    XCTAssertEqual(credentialB.maxConcurrentInvalidations, 1)

    // ... and it can be reported exactly once like any fresh credential.
    try reportUnauthorized(credentialB)
    let delivered = await waitUntil { recorder.deliveries == 1 }
    XCTAssertTrue(delivered, "A fresh credential at a reused address must still be reportable")
    XCTAssertEqual(recorder.deliveries, 1)
    withExtendedLifetime(retained) {}
  }

  func test_invalidateCredentials_willNotFireInvalidationListeners() async throws {
    let credentials = MockCredentials()
    let recorder = InvalidationListenerRecorder(credentials: credentials)

    try invalidateCredentials(credentials)

    // Flush the main-actor delivery queue with a sentinel report on another credential: once
    // its listener has run, any delivery for `credentials` would have run too.
    let sentinel = MockCredentials(tokenValue: "sentinel")
    let sentinelRecorder = InvalidationListenerRecorder(credentials: sentinel)
    try reportUnauthorized(sentinel)
    let sentinelDelivered = await waitUntil { sentinelRecorder.deliveries == 1 }
    XCTAssertTrue(sentinelDelivered)

    XCTAssertEqual(recorder.deliveries, 0, "A host-initiated invalidation is silent")
    XCTAssertEqual(credentials.invalidateCalls, 1)
    XCTAssertFalse(recorder.handle === PortalSessionInvalidationHandle.spent, "The subscription is still live: the credential was never reported")
  }

  func test_invalidateCredentials_willNotUseHostObjectMonitor() throws {
    let credentials = ObjcSyncingCredentials()

    // Worker 0 plays a host holding @synchronized(credentials) while the other four run the
    // SDK's invalidation; the SDK's private monitor must not interact with the host's.
    XCTAssertNoThrow(try runConcurrently(5, timeout: 2) { index in
      if index == 0 {
        objc_sync_enter(credentials)
        Thread.sleep(forTimeInterval: 0.05)
        objc_sync_exit(credentials)
      } else {
        try invalidateCredentials(credentials)
      }
    })

    XCTAssertEqual(credentials.invalidateCalls, 4)
  }
}
