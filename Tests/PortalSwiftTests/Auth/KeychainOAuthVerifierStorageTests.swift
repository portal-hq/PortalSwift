//
//  KeychainOAuthVerifierStorageTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import Security
import XCTest

/// Covers `KeychainOAuthVerifierStorage` and `PendingOAuthVerifierCodec` against
/// `InMemoryAuthKeychainItemStore`, so the fault taxonomy can be exercised without the simulator
/// Keychain or an entitlement.
///
/// The properties that matter most: an unusable entry is cleared and reads as "no sign-in in
/// progress"; a transient fault throws and keeps the entry, so the same redirect can be retried;
/// `deleteIfCurrent(_:)` never deletes a newer sign-in's verifier, not even when its read fails;
/// and the item lives outside the session's service, so clearing one never touches the other.
final class KeychainOAuthVerifierStorageTests: XCTestCase {
  /// A lock-guarded slot for an error raised on a `Thread`, which cannot `throw`.
  private final class LockedErrorBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Error?

    var value: Error? {
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

  private var store = InMemoryAuthKeychainItemStore()
  private var logger = RecordingLogger()
  private var subject = KeychainOAuthVerifierStorage(
    authEnvironmentId: AuthTestFixtures.authEnvironmentId,
    store: InMemoryAuthKeychainItemStore()
  )

  override func setUpWithError() throws {
    try super.setUpWithError()
    self.store = InMemoryAuthKeychainItemStore()
    self.subject = self.storage()
    self.logger = RecordingLogger()
    self.logger.install()
  }

  override func tearDownWithError() throws {
    self.store.operationHook = nil
    self.store.statusOverride = nil
    self.logger.uninstall()
    try super.tearDownWithError()
  }

  // MARK: - Helpers

  private func storage(_ authEnvironmentId: String = AuthTestFixtures.authEnvironmentId) -> KeychainOAuthVerifierStorage {
    KeychainOAuthVerifierStorage(authEnvironmentId: authEnvironmentId, store: self.store)
  }

  private func service(for authEnvironmentId: String = AuthTestFixtures.authEnvironmentId) -> String {
    "PortalSwift.auth.oauthVerifier.\(authEnvironmentId)"
  }

  private let account = "oauthVerifier"

  private func pending(_ verifier: String = AuthTestFixtures.rfcCodeVerifier, createdAt: Int64 = 1_700_000_000_000) -> PendingOAuthVerifier {
    PendingOAuthVerifier(verifier: verifier, createdAt: createdAt)
  }

  /// The stored item's payload as a JSON object.
  private func storedJSON(_ authEnvironmentId: String = AuthTestFixtures.authEnvironmentId) -> [String: Any]? {
    guard let data = self.store.item(service: self.service(for: authEnvironmentId), account: self.account)?.data else {
      return nil
    }
    return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
  }

  /// Seeds a raw payload into the verifier's item.
  private func seedRaw(_ payload: String) {
    self.store.seed(service: self.service(), account: self.account, data: payload)
  }

  private func assertSessionStorageFailure(_ error: Error, file: StaticString = #filePath, line: UInt = #line) {
    guard case .sessionStorageFailure? = error as? PortalAuthError else {
      XCTFail("Expected PortalAuthError.sessionStorageFailure, got \(type(of: error)).", file: file, line: line)
      return
    }
  }

  // MARK: - Round trip

  func test_get_willRoundTripAPendingVerifier() throws {
    try self.subject.set(self.pending())

    XCTAssertEqual(try self.subject.get(), self.pending())
  }

  func test_get_willReturnNil_whenNothingIsStored() throws {
    XCTAssertNil(try self.subject.get())
    XCTAssertEqual(self.store.opCounts[.delete], 0)
    XCTAssertTrue(self.logger.messages(at: .warn).isEmpty, "No sign-in in progress is the normal state, not a warning.")
  }

  func test_set_willReplaceThePreviousVerifier() throws {
    try self.subject.set(self.pending(createdAt: 1))
    try self.subject.set(self.pending(AuthTestFixtures.otherCodeVerifier, createdAt: 2))

    XCTAssertEqual(try self.subject.get(), self.pending(AuthTestFixtures.otherCodeVerifier, createdAt: 2))
    XCTAssertEqual(self.store.count, 1)
  }

  func test_set_willStoreTheAndroidAndReactNativeShape() throws {
    try self.subject.set(self.pending(createdAt: 1_700_000_000_123))

    let json = try XCTUnwrap(self.storedJSON())
    XCTAssertEqual(json.count, 2)
    XCTAssertEqual(json["verifier"] as? String, AuthTestFixtures.rfcCodeVerifier)
    XCTAssertEqual((json["createdAt"] as? NSNumber)?.int64Value, 1_700_000_000_123)
  }

  // MARK: - Exact Keychain dictionaries

  func test_set_willAddItemWithExactAttributes() throws {
    try self.subject.set(self.pending())

    let add = try XCTUnwrap(self.store.addQueries.first)
    XCTAssertEqual(add[kSecClass as String] as? String, kSecClassGenericPassword as String)
    XCTAssertEqual(add[kSecAttrService as String] as? String, self.service())
    XCTAssertEqual(add[kSecAttrAccount as String] as? String, self.account)
    XCTAssertEqual(add[kSecAttrAccessible as String] as? String, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    XCTAssertEqual(add[kSecValueData as String] as? Data, try PendingOAuthVerifierCodec.encode(self.pending()))
    XCTAssertEqual(add.count, 5)
  }

  func test_set_willFallBackToUpdateWithAccessibility_whenDuplicateItem() throws {
    try self.subject.set(self.pending(createdAt: 1))
    try self.subject.set(self.pending(createdAt: 2))

    XCTAssertEqual(self.store.opCounts[.add], 2)
    let update = try XCTUnwrap(self.store.updateCalls.first)
    XCTAssertEqual(update.query[kSecClass as String] as? String, kSecClassGenericPassword as String)
    XCTAssertEqual(update.query[kSecAttrService as String] as? String, self.service())
    XCTAssertEqual(update.query[kSecAttrAccount as String] as? String, self.account)
    XCTAssertEqual(update.query.count, 3)
    XCTAssertEqual(update.attributes[kSecAttrAccessible as String] as? String, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    XCTAssertEqual(update.attributes[kSecValueData as String] as? Data, try PendingOAuthVerifierCodec.encode(self.pending(createdAt: 2)))
    XCTAssertEqual(update.attributes.count, 2)
    XCTAssertEqual(try self.subject.get()?.createdAt, 2)
  }

  func test_storage_willNeverSetSynchronizableOrAnExplicitAccessGroup() throws {
    try self.subject.set(self.pending(createdAt: 1))
    try self.subject.set(self.pending(createdAt: 2))
    _ = try self.subject.get()
    try self.subject.deleteIfCurrent(AuthTestFixtures.rfcCodeVerifier)
    try self.subject.delete()

    XCTAssertGreaterThanOrEqual(self.store.recordedDictionaries.count, 6)
    for dictionary in self.store.recordedDictionaries {
      XCTAssertNil(dictionary[kSecAttrSynchronizable as String], "The verifier must never sync through iCloud Keychain.")
      XCTAssertNil(dictionary[kSecAttrAccessGroup as String], "No explicit access group is set.")
    }
  }

  func test_set_willMigrateAnItemWrittenUnderAnotherProtectionClass() throws {
    self.store.seed(
      service: self.service(),
      account: self.account,
      data: "{\"createdAt\":1,\"verifier\":\"\(AuthTestFixtures.rfcCodeVerifier)\"}",
      accessible: kSecAttrAccessibleWhenUnlocked as String
    )

    try self.subject.set(self.pending(createdAt: 2))

    XCTAssertEqual(
      self.store.item(service: self.service(), account: self.account)?.accessible,
      kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String
    )
  }

  func test_get_willUseExactReadQuery() throws {
    _ = try self.subject.get()

    let query = try XCTUnwrap(self.store.copyQueries.first)
    XCTAssertEqual(query[kSecClass as String] as? String, kSecClassGenericPassword as String)
    XCTAssertEqual(query[kSecAttrService as String] as? String, self.service())
    XCTAssertEqual(query[kSecAttrAccount as String] as? String, self.account)
    XCTAssertEqual(query[kSecReturnData as String] as? Bool, true)
    XCTAssertEqual(query[kSecMatchLimit as String] as? String, kSecMatchLimitOne as String)
    XCTAssertNil(
      query[kSecAttrAccessible as String],
      "The read must not filter on accessibility, or an item written under another protection class is never found."
    )
    XCTAssertEqual(query.count, 5)
  }

  func test_delete_willUseExactQuery() throws {
    try self.subject.delete()

    let query = try XCTUnwrap(self.store.deleteQueries.first)
    XCTAssertEqual(query[kSecClass as String] as? String, kSecClassGenericPassword as String)
    XCTAssertEqual(query[kSecAttrService as String] as? String, self.service())
    XCTAssertEqual(query[kSecAttrAccount as String] as? String, self.account)
    XCTAssertEqual(query.count, 3)
  }

  func test_set_willRetryTheAddOnce_whenTheUpdateReportsTheItemGone() throws {
    try self.subject.set(self.pending(createdAt: 1))
    self.store.nextUpdateStatuses = [errSecItemNotFound]
    // The first add sees the duplicate; the retried add must land.
    self.store.statusOverride = { [weak self] operation, _ in
      guard operation == .add, (self?.store.opCounts[.add] ?? 0) == 3 else {
        return nil
      }
      return errSecSuccess
    }

    try self.subject.set(self.pending(createdAt: 2))

    XCTAssertEqual(self.store.opCounts[.add], 3, "One add, one update, then exactly one retried add.")
    XCTAssertEqual(try self.subject.get()?.createdAt, 2)
  }

  func test_set_willThrowRatherThanLoop_whenTheRetriedAddIsADuplicateAgain() throws {
    try self.subject.set(self.pending(createdAt: 1))
    self.store.nextUpdateStatuses = [errSecItemNotFound]

    XCTAssertThrowsError(try self.subject.set(self.pending(createdAt: 2))) { error in
      self.assertSessionStorageFailure(error)
    }
    XCTAssertEqual(self.store.opCounts[.add], 3)
  }

  // MARK: - Unusable entries self-heal

  func test_get_willClearAndReturnNil_forEveryUnusableEntry() throws {
    let unusable = [
      "not json",
      "null",
      "[]",
      "{}",
      "{\"createdAt\":1}",
      "{\"verifier\":\"\(AuthTestFixtures.rfcCodeVerifier)\"}",
      "{\"createdAt\":1,\"verifier\":\"short\"}",
      "{\"createdAt\":1,\"verifier\":\"\(String(repeating: "a", count: 129))\"}",
      "{\"createdAt\":1,\"verifier\":\"\(String(repeating: "a", count: 42))+\"}",
      "{\"createdAt\":1,\"verifier\":42}",
      "{\"createdAt\":\"1\",\"verifier\":\"\(AuthTestFixtures.rfcCodeVerifier)\"}",
      "{\"createdAt\":true,\"verifier\":\"\(AuthTestFixtures.rfcCodeVerifier)\"}",
      "{\"createdAt\":1.5,\"verifier\":\"\(AuthTestFixtures.rfcCodeVerifier)\"}"
    ]

    for payload in unusable + ["{\"createdAt\":null,\"verifier\":\"\(AuthTestFixtures.rfcCodeVerifier)\"}"] {
      self.store.reset()
      self.seedRaw(payload)

      XCTAssertNil(try self.subject.get(), "Expected \(payload) to read as no sign-in in progress.")
      XCTAssertTrue(self.store.isEmpty, "Expected \(payload) to be cleared.")
    }

    for bytes in [Data(), Data([0xFF, 0xFE, 0xC0])] {
      self.store.reset()
      self.store.seed(service: self.service(), account: self.account, data: bytes)

      XCTAssertNil(try self.subject.get(), "Expected \(Array(bytes)) to read as no sign-in in progress.")
      XCTAssertTrue(self.store.isEmpty)
    }
  }

  func test_get_willRoundTripVerifiersAtBothLengthBounds() throws {
    for verifier in [String(repeating: "a", count: 42) + "~", String(repeating: "Z", count: 124) + "._~-"] {
      try self.subject.set(self.pending(verifier))
      XCTAssertEqual(try self.subject.get(), self.pending(verifier))
    }
  }

  func test_get_willTreatItemNotFoundOnTheSelfHealDeleteAsSuccess() throws {
    self.seedRaw("not json")
    self.store.nextDeleteStatuses = [errSecItemNotFound]

    XCTAssertNil(try self.subject.get())
    XCTAssertEqual(self.logger.messages(at: .warn).count, 1)
  }

  func test_get_willAcceptUnknownKeys() throws {
    self.seedRaw("{\"createdAt\":5,\"verifier\":\"\(AuthTestFixtures.rfcCodeVerifier)\",\"extra\":true}")

    XCTAssertEqual(try self.subject.get(), self.pending(createdAt: 5))
  }

  func test_get_willClearAndReturnNil_whenCopyReturnsSuccessWithoutData() throws {
    try self.subject.set(self.pending())
    self.store.nextCopyStatuses = [errSecSuccess]

    XCTAssertNil(try self.subject.get())
    XCTAssertTrue(self.store.isEmpty)
  }

  func test_get_willWarnOnlyAfterTheUnusableEntryIsCleared() throws {
    self.seedRaw("not json")
    self.store.nextDeleteStatuses = [errSecIO]

    XCTAssertThrowsError(try self.subject.get()) { error in
      self.assertSessionStorageFailure(error)
    }
    XCTAssertTrue(self.logger.messages(at: .warn).isEmpty, "Nothing was cleared, so nothing may say it was.")

    XCTAssertNil(try self.subject.get())
    XCTAssertEqual(self.logger.messages(at: .warn).count, 1)
  }

  // MARK: - Transient faults throw and keep the entry

  func test_get_willThrowAndKeepTheEntry_forEveryTransientStatus() throws {
    for status in [errSecInteractionNotAllowed, errSecMissingEntitlement, errSecIO, errSecAuthFailed, OSStatus(-1)] {
      self.store.reset()
      try self.subject.set(self.pending())
      self.store.nextCopyStatuses = [status]

      XCTAssertThrowsError(try self.subject.get()) { error in
        self.assertSessionStorageFailure(error)
        XCTAssertTrue(error.localizedDescription.contains("OSStatus \(status)"))
      }
      XCTAssertEqual(try self.subject.get(), self.pending(), "A transient fault must keep the sign-in in progress (status \(status)).")
    }
  }

  func test_set_willThrow_whenTheWriteFails() {
    self.store.nextAddStatuses = [errSecIO]

    XCTAssertThrowsError(try self.subject.set(self.pending())) { error in
      self.assertSessionStorageFailure(error)
    }
    XCTAssertTrue(self.store.isEmpty)
  }

  func test_set_willThrow_whenTheUpdateFailsAfterADuplicate() throws {
    try self.subject.set(self.pending(createdAt: 1))
    self.store.nextUpdateStatuses = [errSecIO]

    XCTAssertThrowsError(try self.subject.set(self.pending(createdAt: 2))) { error in
      self.assertSessionStorageFailure(error)
    }
    XCTAssertEqual(try self.subject.get()?.createdAt, 1)
  }

  func test_set_willRefuseAMalformedVerifier_withoutWriting() {
    XCTAssertThrowsError(try self.subject.set(self.pending("not a verifier"))) { error in
      self.assertSessionStorageFailure(error)
      XCTAssertFalse(error.localizedDescription.contains("not a verifier"))
    }
    XCTAssertEqual(self.store.opCounts[.add], 0)
  }

  // MARK: - delete

  func test_delete_willRemoveTheEntry() throws {
    try self.subject.set(self.pending())
    try self.subject.delete()

    XCTAssertNil(try self.subject.get())
    XCTAssertTrue(self.store.isEmpty)
  }

  func test_delete_willSucceed_whenNothingIsStored() {
    XCTAssertNoThrow(try self.subject.delete())
  }

  func test_delete_willThrow_whenTheDeleteFails() throws {
    try self.subject.set(self.pending())
    self.store.nextDeleteStatuses = [errSecIO]

    XCTAssertThrowsError(try self.subject.delete()) { error in
      self.assertSessionStorageFailure(error)
    }
    XCTAssertEqual(try self.subject.get(), self.pending())
  }

  // MARK: - deleteIfCurrent

  func test_deleteIfCurrent_willRemoveTheVerifierItNames() throws {
    try self.subject.set(self.pending())
    try self.subject.deleteIfCurrent(AuthTestFixtures.rfcCodeVerifier)

    XCTAssertNil(try self.subject.get())
  }

  func test_deleteIfCurrent_willKeepAVerifierANewerSignInStored() throws {
    try self.subject.set(self.pending(AuthTestFixtures.otherCodeVerifier))
    try self.subject.deleteIfCurrent(AuthTestFixtures.rfcCodeVerifier)

    XCTAssertEqual(try self.subject.get(), self.pending(AuthTestFixtures.otherCodeVerifier))
    XCTAssertEqual(self.store.opCounts[.delete], 0)
  }

  func test_deleteIfCurrent_willCompareTheVerifierExactly() throws {
    try self.subject.set(self.pending())
    let nearMisses = [
      AuthTestFixtures.rfcCodeVerifier.uppercased(),
      String(AuthTestFixtures.rfcCodeVerifier.dropLast()),
      AuthTestFixtures.rfcCodeVerifier + " ",
      " " + AuthTestFixtures.rfcCodeVerifier
    ]

    for nearMiss in nearMisses {
      try self.subject.deleteIfCurrent(nearMiss)
    }

    XCTAssertEqual(try self.subject.get(), self.pending())
    XCTAssertEqual(self.store.opCounts[.delete], 0)
  }

  func test_deleteIfCurrent_willThrowWithoutWarning_whenAnUnusableEntryCannotBeCleared() {
    self.seedRaw("not json")
    self.store.nextDeleteStatuses = [errSecIO]

    XCTAssertThrowsError(try self.subject.deleteIfCurrent(AuthTestFixtures.rfcCodeVerifier)) { error in
      self.assertSessionStorageFailure(error)
    }
    XCTAssertEqual(self.store.opCounts[.delete], 1)
    XCTAssertTrue(self.logger.messages(at: .warn).isEmpty, "Nothing was cleared, so nothing may say it was.")
  }

  func test_deleteIfCurrent_willNoOp_whenNothingIsStored() {
    XCTAssertNoThrow(try self.subject.deleteIfCurrent(AuthTestFixtures.rfcCodeVerifier))
    XCTAssertEqual(self.store.opCounts[.delete], 0)
  }

  func test_deleteIfCurrent_willClearAnUnusableEntryOnce() throws {
    self.seedRaw("not json")

    try self.subject.deleteIfCurrent(AuthTestFixtures.rfcCodeVerifier)

    XCTAssertTrue(self.store.isEmpty)
    XCTAssertEqual(self.store.opCounts[.delete], 1, "The self-heal already cleared it; a second delete is a second chance to fail.")
  }

  func test_deleteIfCurrent_willThrowAndKeepTheEntry_whenTheReadFails() throws {
    try self.subject.set(self.pending(AuthTestFixtures.otherCodeVerifier))
    self.store.nextCopyStatuses = [errSecInteractionNotAllowed]

    XCTAssertThrowsError(try self.subject.deleteIfCurrent(AuthTestFixtures.rfcCodeVerifier)) { error in
      self.assertSessionStorageFailure(error)
    }
    XCTAssertEqual(self.store.opCounts[.delete], 0, "A read that failed has not said whose verifier is stored.")
    XCTAssertEqual(try self.subject.get(), self.pending(AuthTestFixtures.otherCodeVerifier))
  }

  func test_deleteIfCurrent_willThrow_whenTheDeleteFails() throws {
    try self.subject.set(self.pending())
    self.store.nextDeleteStatuses = [errSecIO]

    XCTAssertThrowsError(try self.subject.deleteIfCurrent(AuthTestFixtures.rfcCodeVerifier)) { error in
      self.assertSessionStorageFailure(error)
    }
    XCTAssertEqual(try self.subject.get(), self.pending(), "A failed delete leaves the entry in place.")
  }

  func test_deleteIfCurrent_willHoldTheLockAcrossReadAndDelete() throws {
    try self.subject.set(self.pending())

    let racerStarted = DispatchSemaphore(value: 0)
    let racerFinished = DispatchSemaphore(value: 0)
    let racerError = LockedErrorBox()
    let subject = self.subject
    let newer = self.pending(AuthTestFixtures.otherCodeVerifier)

    self.store.operationHook = { [weak self] operation, _ in
      guard operation == .copyMatching else {
        return
      }
      self?.store.operationHook = nil

      let thread = Thread {
        racerStarted.signal()
        do {
          try subject.set(newer)
        } catch {
          racerError.value = error
        }
        racerFinished.signal()
      }
      thread.start()

      XCTAssertEqual(racerStarted.wait(timeout: .now() + 2), .success, "The racing set never started.")
      XCTAssertEqual(
        racerFinished.wait(timeout: .now() + 0.1),
        .timedOut,
        "set() completed while deleteIfCurrent held the lock; the compare-and-delete is not atomic."
      )
    }

    try self.subject.deleteIfCurrent(AuthTestFixtures.rfcCodeVerifier)

    XCTAssertEqual(racerFinished.wait(timeout: .now() + 2), .success)
    XCTAssertNil(racerError.value)
    XCTAssertEqual(try self.subject.get(), newer, "The newer sign-in that landed after the delete must survive.")
    XCTAssertEqual(self.store.overlaps, 0)
  }

  // MARK: - Locking and isolation

  func test_storage_willShareOneLockAcrossInstancesOnOneEnvironment() throws {
    let first = self.storage()
    let second = self.storage()
    try first.set(self.pending())
    self.store.holdWindow = 0.005

    try runConcurrently(8, timeout: 2) { index in
      let instance = index % 2 == 0 ? first : second
      if index % 3 == 0 {
        try instance.set(self.pending(createdAt: Int64(index)))
      } else {
        _ = try instance.get()
      }
    }

    XCTAssertEqual(self.store.overlaps, 0, "The lock is process-global per service, not per instance.")
  }

  func test_storage_willNotTouchTheSessionItem() throws {
    let sessionStorage = KeychainAuthSessionStorage(authEnvironmentId: AuthTestFixtures.authEnvironmentId, store: self.store)
    try sessionStorage.set(AuthTestFixtures.persistedSession())
    try self.subject.set(self.pending())

    try self.subject.delete()

    XCTAssertNotNil(try sessionStorage.getSession(), "Clearing the sign-in in progress must not sign the user out.")
  }

  func test_storage_willSurviveTheSessionBeingDeleted() throws {
    let sessionStorage = KeychainAuthSessionStorage(authEnvironmentId: AuthTestFixtures.authEnvironmentId, store: self.store)
    try sessionStorage.set(AuthTestFixtures.persistedSession())
    try self.subject.set(self.pending())

    try sessionStorage.delete()

    XCTAssertEqual(try self.subject.get(), self.pending(), "Clearing a session must not cancel the sign-in replacing it.")
  }

  func test_storage_willKeepEnvironmentsSeparate() throws {
    let first = self.storage("env-1")
    let second = self.storage("env-12")
    try first.set(self.pending())
    try second.set(self.pending(AuthTestFixtures.otherCodeVerifier))

    try first.delete()

    XCTAssertNil(try first.get())
    XCTAssertEqual(try second.get(), self.pending(AuthTestFixtures.otherCodeVerifier))
  }

  func test_storage_willUseItsOwnServiceOutsideTheSessionAndOtherSdkNamespaces() {
    XCTAssertEqual(self.subject.service, "PortalSwift.auth.oauthVerifier.\(AuthTestFixtures.authEnvironmentId)")
    XCTAssertFalse(self.subject.service.hasPrefix(KeychainAuthSessionStorage.servicePrefix))
    XCTAssertFalse(self.subject.service.hasPrefix("PortalAuth."), "The React Native and Android SDKs' prefix.")
    XCTAssertFalse(self.subject.service.hasPrefix("PortalMpc"))
  }

  // MARK: - Secrets

  func test_storage_willNeverLogOrReportTheVerifier() throws {
    try self.subject.set(self.pending())
    self.store.nextCopyStatuses = [errSecIO]
    XCTAssertThrowsError(try self.subject.get()) { error in
      XCTAssertFalse(error.localizedDescription.contains(AuthTestFixtures.rfcCodeVerifier))
    }
    self.store.nextDeleteStatuses = [errSecIO]
    XCTAssertThrowsError(try self.subject.delete()) { error in
      XCTAssertFalse(error.localizedDescription.contains(AuthTestFixtures.rfcCodeVerifier))
    }

    self.seedRaw("{\"createdAt\":1,\"verifier\":\"\(AuthTestFixtures.rfcCodeVerifier)!\"}")
    XCTAssertNil(try self.subject.get())

    self.logger.assertNoSecret(AuthTestFixtures.rfcCodeVerifier)
  }

  func test_pendingVerifier_willRedactTheVerifierWhenPrinted() {
    let pending = self.pending()
    for rendering in [String(describing: pending), String(reflecting: pending), "\(pending)"] {
      XCTAssertFalse(rendering.contains(AuthTestFixtures.rfcCodeVerifier), rendering)
    }
    var dumped = ""
    dump(pending, to: &dumped)
    XCTAssertFalse(dumped.contains(AuthTestFixtures.rfcCodeVerifier))
  }
}
