//
//  KeychainAuthSessionStorageTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import Security
import XCTest

/// Covers `KeychainAuthSessionStorage`, the `PersistedSessionCodec` it persists through, and
/// the exact `SecItem*` dictionaries it builds — all against `InMemoryAuthKeychainItemStore`,
/// so the fault taxonomy (which `OSStatus` self-heals and which one throws) can be exercised
/// without the simulator Keychain or an entitlement.
///
/// Three properties are load-bearing and get the most cases: a permanent fault (an entry that
/// cannot be decoded) clears the entry and reads as signed out, a transient fault (a locked
/// Keychain, a missing entitlement, an I/O error) throws and leaves the entry alone, and every
/// operation runs under one process-global lock per service so a sign-out can never delete the
/// session a newer login has already persisted. Concurrency is driven with real `Thread`s
/// released through a barrier because the production code is `NSLock`-guarded, never `async`.
///
/// The logger sink is captured for every case: the storage self-heals by deleting a payload it
/// could not parse, and that path must never echo the payload — which holds the client session
/// token — into a log line.
final class KeychainAuthSessionStorageTests: XCTestCase {
  /// A lock-guarded set of the ids concurrent callers saw.
  private final class IdSet: @unchecked Sendable {
    private let lock = NSLock()
    private var _values: Set<String> = []

    var values: Set<String> {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._values
    }

    func insert(_ value: String) {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._values.insert(value)
    }
  }

  /// A lock-guarded slot for an error raised on a `Thread`, which cannot `throw`.
  private final class ErrorBox: @unchecked Sendable {
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
  private var installIds = InMemoryAuthInstallIdStore()
  private var logger = RecordingLogger()
  private var subject = KeychainAuthSessionStorage(
    authEnvironmentId: AuthTestFixtures.authEnvironmentId,
    store: InMemoryAuthKeychainItemStore()
  )

  override func setUpWithError() throws {
    try super.setUpWithError()
    CredentialInvalidationRegistry.shared.resetForTesting()
    self.store = InMemoryAuthKeychainItemStore()
    self.installIds = InMemoryAuthInstallIdStore()
    self.subject = self.storage()
    self.logger = RecordingLogger()
    self.logger.install()
  }

  override func tearDownWithError() throws {
    self.store.operationHook = nil
    self.store.statusOverride = nil
    self.logger.uninstall()
    CredentialInvalidationRegistry.shared.resetForTesting()
    try super.tearDownWithError()
  }

  // MARK: - Helpers

  /// A sibling storage on the same in-memory store, so two instances (or two environments)
  /// can be raced against one another.
  private func storage(_ authEnvironmentId: String = AuthTestFixtures.authEnvironmentId) -> KeychainAuthSessionStorage {
    KeychainAuthSessionStorage(authEnvironmentId: authEnvironmentId, store: self.store, installIds: self.installIds)
  }

  /// A storage on the same Keychain as `subject` after the app was deleted and installed again:
  /// the item survives, the install id does not.
  private func reinstalledStorage(installIds: InMemoryAuthInstallIdStore = InMemoryAuthInstallIdStore()) -> KeychainAuthSessionStorage {
    KeychainAuthSessionStorage(authEnvironmentId: AuthTestFixtures.authEnvironmentId, store: self.store, installIds: installIds)
  }

  /// The Keychain service `authEnvironmentId` maps to.
  private func service(for authEnvironmentId: String) -> String {
    "\(KeychainAuthSessionStorage.servicePrefix).\(authEnvironmentId)"
  }

  /// The service the default subject reads and writes.
  private var expectedService: String {
    self.service(for: AuthTestFixtures.authEnvironmentId)
  }

  /// The exact payload the storage persists for a session.
  private func session(_ token: String, _ endUserId: String = AuthTestFixtures.endUserId) -> String {
    AuthTestFixtures.persistedSession(token: token, endUserId: endUserId)
  }

  /// The decoded form of `session(_:_:)`.
  private func parsed(_ token: String, _ endUserId: String = AuthTestFixtures.endUserId) -> PersistedSession {
    PersistedSession(clientSessionToken: token, endUserId: endUserId)
  }

  /// Asserts `error` is a `PortalAuthError.sessionStorageFailure` and returns its description
  /// so a caller can check what the message does (and does not) carry.
  @discardableResult
  private func assertSessionStorageFailure(
    _ error: Error,
    file: StaticString = #filePath,
    line: UInt = #line
  ) -> String {
    guard let authError = error as? PortalAuthError else {
      XCTFail("Expected a PortalAuthError, got \(type(of: error)).", file: file, line: line)
      return ""
    }
    guard case .sessionStorageFailure = authError else {
      XCTFail("Expected .sessionStorageFailure, got another PortalAuthError case.", file: file, line: line)
      return ""
    }
    return authError.localizedDescription
  }

  /// Fails when any recorded dictionary carries an attribute the session item must never have.
  private func assertNoForbiddenAttributes(file: StaticString = #filePath, line: UInt = #line) {
    for dictionary in self.store.recordedDictionaries {
      XCTAssertNil(
        dictionary[kSecAttrSynchronizable as String],
        "A Keychain dictionary carried kSecAttrSynchronizable; the session must never sync to iCloud.",
        file: file,
        line: line
      )
      XCTAssertNil(
        dictionary[kSecAttrAccessGroup as String],
        "A Keychain dictionary carried kSecAttrAccessGroup; the session must never be shared with siblings.",
        file: file,
        line: line
      )
    }
  }

  // MARK: - getSession

  func test_getSession_willRoundTripASession() throws {
    try self.subject.set(self.session("token"))

    XCTAssertEqual(try self.subject.getSession(), self.parsed("token"))
    XCTAssertEqual(self.store.opCounts[.add], 1)
    XCTAssertEqual(self.store.opCounts[.copyMatching], 1)
    XCTAssertEqual(self.store.opCounts[.delete], 0)
  }

  func test_getSession_willReturnNil_whenItemNotFound() throws {
    XCTAssertNil(try self.subject.getSession())
    XCTAssertEqual(self.store.opCounts[.delete], 0)
    XCTAssertTrue(self.logger.messages(at: .warn).isEmpty, "Nothing stored is the normal signed-out state, not a warning.")
  }

  func test_getSession_willReturnNil_afterDelete() throws {
    try self.subject.set(self.session("token"))
    try self.subject.delete()

    XCTAssertNil(try self.subject.getSession())
    XCTAssertTrue(self.store.isEmpty)
  }

  func test_getSession_willThrowAndKeepItem_whenInteractionNotAllowed() throws {
    try self.subject.set(self.session("token"))
    self.store.nextCopyStatuses = [errSecInteractionNotAllowed]

    XCTAssertThrowsError(try self.subject.getSession()) { error in
      self.assertSessionStorageFailure(error)
    }
    XCTAssertEqual(self.store.item()?.string, self.session("token"), "A locked Keychain must never sign the user out.")
    XCTAssertEqual(self.store.opCounts[.delete], 0)
  }

  func test_getSession_willThrowAndKeepItem_whenMissingEntitlement() throws {
    try self.subject.set(self.session("token"))
    self.store.nextCopyStatuses = [errSecMissingEntitlement]

    XCTAssertThrowsError(try self.subject.getSession()) { error in
      self.assertSessionStorageFailure(error)
    }
    XCTAssertEqual(self.store.item()?.string, self.session("token"))
    XCTAssertEqual(self.store.opCounts[.delete], 0)
  }

  func test_getSession_willThrowAndKeepItem_whenIOError() throws {
    try self.subject.set(self.session("token"))
    self.store.nextCopyStatuses = [errSecIO]

    XCTAssertThrowsError(try self.subject.getSession()) { error in
      self.assertSessionStorageFailure(error)
    }
    XCTAssertEqual(self.store.item()?.string, self.session("token"))
    XCTAssertEqual(self.store.opCounts[.delete], 0)
  }

  func test_getSession_willThrowAndKeepItem_whenUnknownStatus() throws {
    // Only errSecItemNotFound and a decode failure are permanent; everything else is treated
    // as transient, including a status this SDK version has never seen.
    for status in [errSecAuthFailed, errSecNotAvailable, errSecDecode, OSStatus(-1)] {
      self.store.reset()
      self.store.seed(data: self.session("token"))
      self.store.nextCopyStatuses = [status]

      XCTAssertThrowsError(try self.subject.getSession(), "OSStatus \(status) must be treated as transient") { error in
        self.assertSessionStorageFailure(error)
      }
      XCTAssertEqual(self.store.item()?.string, self.session("token"), "OSStatus \(status) must leave the item alone")
      XCTAssertEqual(self.store.opCounts[.delete], 0, "OSStatus \(status) must not delete")
    }
  }

  func test_getSession_willClearAndReturnNil_whenPayloadIsNotJson() throws {
    self.store.seed(data: "{not json")

    XCTAssertNil(try self.subject.getSession())
    XCTAssertTrue(self.store.isEmpty)
    XCTAssertEqual(self.store.opCounts[.delete], 1)
  }

  func test_getSession_willClearAndReturnNil_whenPayloadIsIncomplete() throws {
    self.store.seed(data: "{\"clientSessionToken\":\"token\"}")

    XCTAssertNil(try self.subject.getSession())
    XCTAssertTrue(self.store.isEmpty)
    XCTAssertEqual(self.store.opCounts[.delete], 1)
  }

  func test_getSession_willClearAndReturnNil_whenTokenIsEmpty() throws {
    self.store.seed(data: "{\"clientSessionToken\":\"\",\"endUserId\":\"u\"}")

    XCTAssertNil(try self.subject.getSession())
    XCTAssertTrue(self.store.isEmpty)
  }

  func test_getSession_willClearAndReturnNil_whenEndUserIdIsEmpty() throws {
    self.store.seed(data: "{\"clientSessionToken\":\"t\",\"endUserId\":\"\"}")

    XCTAssertNil(try self.subject.getSession())
    XCTAssertTrue(self.store.isEmpty)
  }

  func test_getSession_willClearAndReturnNil_whenTokenIsNotAString() throws {
    self.store.seed(data: "{\"clientSessionToken\":1,\"endUserId\":\"x\"}")

    XCTAssertNil(try self.subject.getSession())
    XCTAssertTrue(self.store.isEmpty)
  }

  func test_getSession_willClearAndReturnNil_whenDataIsNotUTF8() throws {
    self.store.seed(data: Data([0xFF, 0xFE, 0xC0]))

    XCTAssertNil(try self.subject.getSession())
    XCTAssertTrue(self.store.isEmpty)
    XCTAssertEqual(self.store.opCounts[.delete], 1)
  }

  func test_getSession_willClearAndReturnNil_whenDataIsEmpty() throws {
    self.store.seed(data: Data())

    XCTAssertNil(try self.subject.getSession())
    XCTAssertTrue(self.store.isEmpty)
  }

  func test_getSession_willClearAndReturnNil_whenCopyReturnsSuccessWithNilResult() throws {
    // SecItemCopyMatching promises data on errSecSuccess; a violation must not force-unwrap.
    self.store.seed(data: self.session("token"))
    self.store.statusOverride = { operation, _ in
      operation == .copyMatching ? errSecSuccess : nil
    }

    XCTAssertNil(try self.subject.getSession())
    XCTAssertEqual(self.store.opCounts[.delete], 1)
  }

  func test_getSession_willThrow_whenUnusableEntryCannotBeCleared() throws {
    self.store.seed(data: "{not json")
    self.store.nextDeleteStatuses = [errSecInteractionNotAllowed]

    XCTAssertThrowsError(try self.subject.getSession()) { error in
      self.assertSessionStorageFailure(error)
    }
    XCTAssertEqual(self.store.item()?.string, "{not json", "A failed self-heal must not be reported as signed out.")
  }

  func test_getSession_willTreatItemNotFoundOnSelfHealDeleteAsSuccess() throws {
    self.store.seed(data: "{not json")
    self.store.nextDeleteStatuses = [errSecItemNotFound]

    XCTAssertNil(try self.subject.getSession(), "Another party removing the entry first is still a successful self-heal.")
  }

  func test_getSession_willLogWarningOnlyAfterSuccessfulClear() throws {
    self.store.seed(data: "{not json")
    self.logger.reset()

    XCTAssertNil(try self.subject.getSession())

    let warnings = self.logger.messages(at: .warn)
    XCTAssertEqual(warnings.count, 1)
    XCTAssertTrue(warnings.first?.contains("cleared") == true, "The warning must say the entry was cleared.")

    self.store.reset()
    self.store.seed(data: "{not json")
    self.store.nextDeleteStatuses = [errSecIO]
    self.logger.reset()

    XCTAssertThrowsError(try self.subject.getSession())
    XCTAssertTrue(
      self.logger.messages(at: .warn).isEmpty,
      "Nothing was cleared, so claiming it was cleared would be a lie."
    )
  }

  func test_getSession_willNotLogPayload_whenSelfHealing() throws {
    let payload = "{\"clientSessionToken\":\"SECRET-TOKEN-XYZ\"}"
    self.store.seed(data: payload)

    XCTAssertNil(try self.subject.getSession())

    self.logger.assertNoSecret("SECRET-TOKEN-XYZ")
    XCTAssertFalse(self.logger.contains(payload), "The raw payload must never be logged.")
  }

  func test_getSession_willRoundTripASessionPersistedAfterSelfHeal() throws {
    self.store.seed(data: "{not json")
    XCTAssertNil(try self.subject.getSession())

    try self.subject.set(self.session("fresh-token"))

    XCTAssertEqual(try self.subject.getSession(), self.parsed("fresh-token"))
  }

  func test_getSession_willUseExactReadQuery() throws {
    try self.subject.set(self.session("token"))
    _ = try self.subject.getSession()

    let query = try XCTUnwrap(self.store.copyQueries.last)
    XCTAssertEqual(query[kSecClass as String] as? String, kSecClassGenericPassword as String)
    XCTAssertEqual(query[kSecAttrService as String] as? String, self.expectedService)
    XCTAssertEqual(query[kSecAttrAccount as String] as? String, KeychainAuthSessionStorage.accountName)
    XCTAssertEqual(query[kSecReturnData as String] as? Bool, true)
    XCTAssertEqual(query[kSecReturnAttributes as String] as? Bool, true, "The install tag is an attribute, so the read must return attributes.")
    XCTAssertEqual(query[kSecMatchLimit as String] as? String, kSecMatchLimitOne as String)
    XCTAssertNil(query[kSecAttrSynchronizable as String])
    XCTAssertNil(query[kSecAttrAccessGroup as String])
    XCTAssertNil(query[kSecAttrAccessible as String], "Filtering the read by protection class would hide a migratable item.")
    XCTAssertNil(query[kSecAttrGeneric as String], "Filtering the read by install tag would hide another install's item instead of clearing it.")
  }

  func test_getSession_willFindItemWrittenUnderOlderProtectionClass() throws {
    self.store.seed(
      service: self.expectedService,
      account: KeychainAuthSessionStorage.accountName,
      data: self.session("t"),
      accessible: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly as String
    )

    XCTAssertEqual(try self.subject.getSession(), self.parsed("t"))
  }

  // MARK: - set

  func test_set_willAddItemWithExactAttributes() throws {
    try self.subject.set(self.session("token"))

    let attributes = try XCTUnwrap(self.store.addQueries.last)
    XCTAssertEqual(attributes[kSecClass as String] as? String, kSecClassGenericPassword as String)
    XCTAssertEqual(attributes[kSecAttrService as String] as? String, self.expectedService)
    XCTAssertEqual(attributes[kSecAttrAccount as String] as? String, KeychainAuthSessionStorage.accountName)
    XCTAssertEqual(attributes[kSecValueData as String] as? Data, Data(self.session("token").utf8))
    XCTAssertEqual(
      attributes[kSecAttrAccessible as String] as? String,
      kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String
    )
    XCTAssertEqual(attributes[kSecAttrGeneric as String] as? Data, self.installIds.tag)
    XCTAssertNil(attributes[kSecAttrSynchronizable as String])
    XCTAssertNil(attributes[kSecAttrAccessGroup as String])
  }

  func test_set_willFallBackToUpdate_whenDuplicateItem() throws {
    self.store.seed(data: self.session("old-token"))
    self.store.nextAddStatuses = [errSecDuplicateItem]

    try self.subject.set(self.session("new-token"))

    XCTAssertEqual(self.store.updateCalls.count, 1)
    let call = try XCTUnwrap(self.store.updateCalls.last)
    XCTAssertEqual(call.query[kSecClass as String] as? String, kSecClassGenericPassword as String)
    XCTAssertEqual(call.query[kSecAttrService as String] as? String, self.expectedService)
    XCTAssertEqual(call.query[kSecAttrAccount as String] as? String, KeychainAuthSessionStorage.accountName)
    XCTAssertEqual(call.attributes[kSecValueData as String] as? Data, Data(self.session("new-token").utf8))
    XCTAssertEqual(
      call.attributes[kSecAttrAccessible as String] as? String,
      kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String
    )
    XCTAssertEqual(call.attributes[kSecAttrGeneric as String] as? Data, self.installIds.tag)
    XCTAssertEqual(try self.subject.getSession(), self.parsed("new-token"))
  }

  func test_set_willMigrateAccessibility_whenExistingItemHasOlderProtectionClass() throws {
    self.store.seed(data: self.session("t1"), accessible: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly as String)

    try self.subject.set(self.session("t2"))

    let item = try XCTUnwrap(self.store.item())
    XCTAssertEqual(item.accessible, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    XCTAssertEqual(item.string, self.session("t2"))
  }

  func test_set_willThrowSessionStorageFailure_whenAddFails() {
    self.store.nextAddStatuses = [errSecInteractionNotAllowed]

    XCTAssertThrowsError(try self.subject.set(self.session("token"))) { error in
      self.assertSessionStorageFailure(error)
    }
    XCTAssertTrue(self.store.isEmpty)
    XCTAssertEqual(self.store.updateCalls.count, 0, "An add that failed for a reason other than a duplicate must not update.")
  }

  func test_set_willThrowSessionStorageFailure_whenUpdateFailsAfterDuplicate() throws {
    self.store.seed(data: self.session("old-token"))
    self.store.nextAddStatuses = [errSecDuplicateItem]
    self.store.nextUpdateStatuses = [errSecIO]

    XCTAssertThrowsError(try self.subject.set(self.session("new-token"))) { error in
      self.assertSessionStorageFailure(error)
    }
    XCTAssertEqual(self.store.item()?.string, self.session("old-token"), "A failed update must not half-write the item.")
  }

  func test_set_willTerminate_whenUpdateReportsItemNotFoundAfterDuplicate() throws {
    // The item vanished between the add and the update: the retry must not ping-pong.
    self.store.nextAddStatuses = [errSecDuplicateItem]
    self.store.nextUpdateStatuses = [errSecItemNotFound]

    let started = Date()
    var thrown: Error?
    do {
      try self.subject.set(self.session("token"))
    } catch {
      thrown = error
    }
    let elapsed = Date().timeIntervalSince(started)

    XCTAssertLessThan(elapsed, 2, "set() must terminate rather than loop between add and update.")
    XCTAssertLessThanOrEqual(self.store.opCounts[.add] ?? 0, 2)
    XCTAssertEqual(self.store.opCounts[.update], 1)
    if let thrown = thrown {
      self.assertSessionStorageFailure(thrown)
    } else {
      XCTAssertEqual(try self.subject.getSession(), self.parsed("token"))
    }
  }

  func test_set_willOverwriteExistingSession() throws {
    try self.subject.set(self.session("a"))
    try self.subject.set(self.session("b", "user-2"))

    XCTAssertEqual(try self.subject.getSession(), self.parsed("b", "user-2"))
    XCTAssertEqual(self.store.count, 1)
  }

  func test_set_willPersistVerbatim() throws {
    let raw = "  {\"clientSessionToken\":\"t\",\"endUserId\":\"u\",\"extra\":1}  "

    try self.subject.set(raw)

    XCTAssertEqual(self.store.item()?.data, Data(raw.utf8), "The storage must not reformat what it was handed.")
    XCTAssertEqual(try self.subject.getSession(), self.parsed("t", "u"))
  }

  func test_set_willNotIncludeValueInErrorMessage() {
    let token = "client-session-token-must-never-appear"
    self.store.nextAddStatuses = [errSecIO]

    XCTAssertThrowsError(try self.subject.set(self.session(token))) { error in
      let localized = error.localizedDescription
      let described = String(describing: error)
      XCTAssertFalse(localized.contains(token), "The failure message leaked the session token.")
      XCTAssertFalse(described.contains(token), "The failure value leaked the session token.")
      XCTAssertFalse(localized.contains(AuthTestFixtures.endUserId), "The failure message leaked the stored value.")
      XCTAssertFalse(described.contains(AuthTestFixtures.endUserId), "The failure value leaked the stored value.")
      XCTAssertTrue(localized.contains("\(errSecIO)"), "The OSStatus is on the allow-list and must be reported.")
    }
  }

  func test_set_willNotLogTheValue() throws {
    try self.subject.set(self.session("SECRET-TOKEN"))

    self.store.nextAddStatuses = [errSecIO]
    self.store.nextUpdateStatuses = [errSecIO]
    XCTAssertThrowsError(try self.subject.set(self.session("SECRET-TOKEN")))

    self.logger.assertNoSecret("SECRET-TOKEN")
  }

  func test_set_willRoundTripLargePayload() throws {
    let token = String(repeating: "t", count: 8192)
    let endUserId = String(repeating: "u", count: 1024)

    try self.subject.set(self.session(token, endUserId))

    XCTAssertEqual(try self.subject.getSession(), self.parsed(token, endUserId))
  }

  func test_set_willStoreEmptyString_andGetSessionSelfHeals() throws {
    try self.subject.set("")

    XCTAssertNil(try self.subject.getSession())
    XCTAssertTrue(self.store.isEmpty)
  }

  func test_set_willStoreWhitespaceOnly_andGetSessionSelfHeals() throws {
    try self.subject.set("   \n")

    XCTAssertNil(try self.subject.getSession())
    XCTAssertTrue(self.store.isEmpty)
  }

  // MARK: - delete

  func test_delete_willRemoveItem() throws {
    try self.subject.set(self.session("t"))

    try self.subject.delete()

    XCTAssertTrue(self.store.isEmpty)
    XCTAssertEqual(self.store.opCounts[.delete], 1)
  }

  func test_delete_willUseExactQuery() throws {
    try self.subject.delete()

    let query = try XCTUnwrap(self.store.deleteQueries.last)
    XCTAssertEqual(query[kSecClass as String] as? String, kSecClassGenericPassword as String)
    XCTAssertEqual(query[kSecAttrService as String] as? String, self.expectedService)
    XCTAssertEqual(query[kSecAttrAccount as String] as? String, KeychainAuthSessionStorage.accountName)
    XCTAssertNil(query[kSecReturnData as String])
    XCTAssertNil(query[kSecMatchLimit as String])
    XCTAssertNil(query[kSecAttrSynchronizable as String])
    XCTAssertNil(query[kSecAttrAccessGroup as String])
  }

  func test_delete_willSucceed_whenItemNotFound() {
    XCTAssertNoThrow(try self.subject.delete(), "Deleting nothing is the desired end state, not a failure.")
  }

  func test_delete_willThrowSessionStorageFailure_whenDeleteFails() throws {
    try self.subject.set(self.session("t"))
    self.store.nextDeleteStatuses = [errSecInteractionNotAllowed]

    XCTAssertThrowsError(try self.subject.delete()) { error in
      self.assertSessionStorageFailure(error)
    }
    XCTAssertEqual(self.store.item()?.string, self.session("t"))
  }

  func test_delete_willNotTouchOtherEnvironments() throws {
    let envA = self.storage("env-a")
    let envB = self.storage("env-b")
    try envA.set(self.session("a-token"))
    try envB.set(self.session("b-token", "user-b"))

    try envA.delete()

    XCTAssertNil(try envA.getSession())
    XCTAssertEqual(try envB.getSession(), self.parsed("b-token", "user-b"))
  }

  func test_delete_willNotTouchPortalMpcItems() throws {
    self.store.seed(
      service: "PortalMpc.\(AuthTestFixtures.authEnvironmentId)",
      account: AuthTestFixtures.authEnvironmentId,
      data: "share"
    )
    try self.subject.set(self.session("token"))

    try self.subject.delete()

    let mpcItem = self.store.item(
      service: "PortalMpc.\(AuthTestFixtures.authEnvironmentId)",
      account: AuthTestFixtures.authEnvironmentId
    )
    XCTAssertEqual(mpcItem?.string, "share", "The auth session must never share a namespace with the MPC shares.")
  }

  // MARK: - deleteIfCurrent

  func test_deleteIfCurrent_willRemoveNamedSession() throws {
    try self.subject.set(self.session("token"))

    try self.subject.deleteIfCurrent("token")

    XCTAssertNil(try self.subject.getSession())
    XCTAssertEqual(self.store.opCounts[.delete], 1)
  }

  func test_deleteIfCurrent_willSpareNewerSession() throws {
    try self.subject.set(self.session("old-token"))
    try self.subject.set(self.session("fresh-token", "user-2"))

    try self.subject.deleteIfCurrent("old-token")

    XCTAssertEqual(try self.subject.getSession(), self.parsed("fresh-token", "user-2"))
    XCTAssertEqual(self.store.opCounts[.delete], 0)
  }

  func test_deleteIfCurrent_willSpareNewerSessionWithSameEndUser() throws {
    try self.subject.set(self.session("old", "user-1"))
    try self.subject.set(self.session("new", "user-1"))

    try self.subject.deleteIfCurrent("old")

    XCTAssertEqual(try self.subject.getSession(), self.parsed("new", "user-1"), "The comparison is on the token, not the user.")
  }

  func test_deleteIfCurrent_willCompareTokenExactly() throws {
    try self.subject.set(self.session("token"))

    try self.subject.deleteIfCurrent("TOKEN")
    try self.subject.deleteIfCurrent("token ")
    try self.subject.deleteIfCurrent("")

    XCTAssertEqual(try self.subject.getSession(), self.parsed("token"), "No case folding, no trimming, no empty-token special case.")
    XCTAssertEqual(self.store.opCounts[.delete], 0)
  }

  func test_deleteIfCurrent_willClearUnparseableEntry() throws {
    self.store.seed(data: "{not json")

    XCTAssertNoThrow(try self.subject.deleteIfCurrent("token"))
    XCTAssertTrue(self.store.isEmpty)
  }

  func test_deleteIfCurrent_willThrowAndPreserveEntry_whenReadFails() throws {
    try self.subject.set(self.session("token"))
    self.store.nextCopyStatuses = [errSecInteractionNotAllowed]

    XCTAssertThrowsError(try self.subject.deleteIfCurrent("token")) { error in
      self.assertSessionStorageFailure(error)
    }
    XCTAssertEqual(self.store.item()?.string, self.session("token"), "A compare-and-delete that cannot compare must not delete blind: the entry may belong to a newer login")
    XCTAssertEqual(self.store.opCounts[.delete], 0)
  }

  func test_deleteIfCurrent_willNoOp_whenEmpty() {
    XCTAssertNoThrow(try self.subject.deleteIfCurrent("token"))
    XCTAssertTrue(self.store.isEmpty)
  }

  func test_deleteIfCurrent_willThrow_whenDeleteFails() throws {
    try self.subject.set(self.session("token"))
    self.store.nextDeleteStatuses = [errSecIO]

    XCTAssertThrowsError(try self.subject.deleteIfCurrent("token")) { error in
      self.assertSessionStorageFailure(error)
    }
    XCTAssertEqual(self.store.item()?.string, self.session("token"))
  }

  func test_deleteIfCurrent_willSpareNewerSession_evenWhenTheReadThatWouldRevealItFails() throws {
    // The scenario the contract exists for: a stale session signs out while a newer login owns
    // the slot, and the Keychain happens to be unreadable at that moment.
    try self.subject.set(self.session("new-token"))
    self.store.nextCopyStatuses = [errSecIO]

    XCTAssertThrowsError(try self.subject.deleteIfCurrent("old-token")) { error in
      self.assertSessionStorageFailure(error)
    }
    XCTAssertEqual(self.store.opCounts[.delete], 0)
    XCTAssertEqual(try self.subject.getSession(), self.parsed("new-token"), "The newer login survives the stale sign-out")
  }

  func test_deleteIfCurrent_willNotSelfHealTwice_whenEntryUnparseable() throws {
    self.store.seed(data: "{not json")

    try self.subject.deleteIfCurrent("x")

    XCTAssertEqual(self.store.opCounts[.delete], 1, "The self-heal delete and the sign-out delete must not both run.")
    XCTAssertTrue(self.store.isEmpty)
  }

  func test_deleteIfCurrent_willHoldLockAcrossReadAndDelete() throws {
    try self.subject.set(self.session("old-token"))

    let racerStarted = DispatchSemaphore(value: 0)
    let racerFinished = DispatchSemaphore(value: 0)
    let racerError = ErrorBox()
    let subject = self.subject
    let fresh = self.session("fresh-token", "user-2")

    self.store.operationHook = { [weak self] operation, _ in
      guard operation == .copyMatching else {
        return
      }
      // Once only: the final read must not spawn a second racer.
      self?.store.operationHook = nil

      let thread = Thread {
        racerStarted.signal()
        do {
          try subject.set(fresh)
        } catch {
          racerError.value = error
        }
        racerFinished.signal()
      }
      thread.name = "deleteIfCurrent-racer"
      thread.start()

      XCTAssertEqual(racerStarted.wait(timeout: .now() + 2), .success, "The racing set never started.")
      XCTAssertEqual(
        racerFinished.wait(timeout: .now() + 0.1),
        .timedOut,
        "set() completed while deleteIfCurrent held the lock; the compare-and-delete is not atomic."
      )
    }

    try self.subject.deleteIfCurrent("old-token")

    XCTAssertEqual(racerFinished.wait(timeout: .now() + 2), .success, "The racing set never finished.")
    XCTAssertNil(racerError.value)
    XCTAssertEqual(try self.subject.getSession(), self.parsed("fresh-token", "user-2"))
    XCTAssertEqual(self.store.overlaps, 0)
  }

  // MARK: - Locking and isolation

  func test_storage_willNeverRunTwoKeychainOperationsAtOnce() throws {
    try self.subject.set(self.session("token"))
    self.store.holdWindow = 0.005

    let started = Date()
    try runConcurrently(8, timeout: 2) { index in
      if index % 4 == 0 {
        try self.subject.set(self.session("token-\(index)"))
      } else {
        _ = try self.subject.getSession()
      }
    }

    XCTAssertLessThan(Date().timeIntervalSince(started), 2, "The eight threads must all join well inside the budget.")
    XCTAssertEqual(self.store.overlaps, 0)
    XCTAssertEqual(self.store.maxInFlight, 1)
  }

  func test_storage_willShareOneLockAcrossInstancesOnOneEnvironment() throws {
    let first = self.storage()
    let second = self.storage()
    try first.set(self.session("token"))
    self.store.holdWindow = 0.005

    try runConcurrently(8, timeout: 2) { index in
      let instance = index % 2 == 0 ? first : second
      if index % 3 == 0 {
        try instance.set(self.session("token-\(index)"))
      } else {
        _ = try instance.getSession()
      }
    }

    XCTAssertEqual(self.store.overlaps, 0, "The lock is process-global per service, not per instance.")
    XCTAssertEqual(self.store.maxInFlight, 1)
  }

  func test_storage_willNotBlockOtherEnvironments() throws {
    let envA = self.storage("env-a")
    let envB = self.storage("env-b")
    let serviceA = self.service(for: "env-a")

    let arrived = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    let finished = DispatchSemaphore(value: 0)
    let readError = ErrorBox()

    self.store.operationHook = { operation, dictionary in
      guard operation == .copyMatching,
            (dictionary[kSecAttrService as String] as? String) == serviceA
      else {
        return
      }
      arrived.signal()
      _ = release.wait(timeout: .now() + 2)
    }

    let thread = Thread {
      do {
        _ = try envA.getSession()
      } catch {
        readError.value = error
      }
      finished.signal()
    }
    thread.name = "env-a-reader"
    thread.start()

    XCTAssertEqual(arrived.wait(timeout: .now() + 2), .success, "env-a's read never reached the store.")

    let started = Date()
    let sessionB = try envB.getSession()
    let elapsed = Date().timeIntervalSince(started)

    XCTAssertNil(sessionB)
    XCTAssertLessThan(elapsed, 0.5, "env-b waited on env-a; the locks are per service, not one global lock.")

    release.signal()
    XCTAssertEqual(finished.wait(timeout: .now() + 2), .success)
    XCTAssertNil(readError.value)
  }

  func test_storage_willKeepLoginAliveWhenRacingInvalidation_100Rounds() throws {
    for round in 0 ..< 100 {
      self.store.reset()
      try self.subject.set(self.session("old-token"))

      try runConcurrently(2, timeout: 2) { index in
        if index == 0 {
          try self.subject.deleteIfCurrent("old-token")
        } else {
          try self.subject.set(self.session("fresh-token", "user-2"))
        }
      }

      XCTAssertEqual(
        try self.subject.getSession(),
        self.parsed("fresh-token", "user-2"),
        "Round \(round): a sign-out deleted the session a newer login had already persisted."
      )
    }
  }

  func test_storage_willKeepLoginAliveWhenRacingUnparseableClear_100Rounds() throws {
    for round in 0 ..< 100 {
      self.store.reset()
      self.store.seed(data: "{not json")

      try runConcurrently(2, timeout: 2) { index in
        if index == 0 {
          _ = try self.subject.getSession()
        } else {
          try self.subject.set(self.session("fresh-token", "user-2"))
        }
      }

      XCTAssertEqual(
        try self.subject.getSession(),
        self.parsed("fresh-token", "user-2"),
        "Round \(round): the self-heal of an unparseable entry deleted a fresh login."
      )
    }
  }

  // MARK: - Namespacing

  func test_storage_willKeySessionByAuthEnvironmentId() throws {
    try self.subject.set(self.session("token"))

    let keys = Array(self.store.snapshot().keys)
    XCTAssertEqual(keys.count, 1)
    let key = try XCTUnwrap(keys.first)
    XCTAssertTrue(key.service.contains(AuthTestFixtures.authEnvironmentId))
    XCTAssertEqual(key.service, self.expectedService)
  }

  func test_storage_willIsolateEnvironments() throws {
    let envA = self.storage("env-a")
    let envB = self.storage("env-b")

    try envA.set(self.session("a-token", "user-a"))
    try envB.set(self.session("b-token", "user-b"))

    XCTAssertEqual(try envA.getSession(), self.parsed("a-token", "user-a"))
    XCTAssertEqual(try envB.getSession(), self.parsed("b-token", "user-b"))
    XCTAssertEqual(self.store.count, 2)
  }

  func test_storage_willNotUsePortalMpcOrRNNamespace() throws {
    XCTAssertEqual(KeychainAuthSessionStorage.servicePrefix, "PortalSwift.auth.session")
    XCTAssertEqual(KeychainAuthSessionStorage.accountName, "session")

    try self.subject.set(self.session("token"))

    let attributes = try XCTUnwrap(self.store.addQueries.last)
    let service = try XCTUnwrap(attributes[kSecAttrService as String] as? String)
    XCTAssertTrue(service.hasPrefix("PortalSwift.auth.session."))
    XCTAssertFalse(service.hasPrefix("PortalMpc"), "The MPC shares own that namespace.")
    XCTAssertFalse(service.hasPrefix("PortalAuth.session"), "That slot belongs to the React Native SDK.")
    XCTAssertEqual(attributes[kSecAttrAccount as String] as? String, "session")
  }

  func test_storage_willBuildServiceVerbatim_whenEnvironmentIdHasSpecialChars() throws {
    let odd = self.storage("a.b/c d")
    let sibling = self.storage("a.b/c")

    try odd.set(self.session("odd-token"))
    try sibling.set(self.session("sibling-token"))

    XCTAssertEqual(odd.service, "PortalSwift.auth.session.a.b/c d", "The Keychain service is opaque; no encoding is applied.")
    XCTAssertEqual(try odd.getSession(), self.parsed("odd-token"))
    XCTAssertEqual(try sibling.getSession(), self.parsed("sibling-token"))
  }

  func test_storage_willNeverSetSynchronizableOrAccessGroup() throws {
    try self.subject.set(self.session("token"))
    try self.subject.set(self.session("token-2"))
    _ = try self.subject.getSession()
    try self.subject.deleteIfCurrent("token-2")
    try self.subject.set(self.session("token-3"))
    try self.subject.delete()

    XCTAssertGreaterThan(self.store.updateCalls.count, 0, "The duplicate/update leg must be exercised too.")
    self.assertNoForbiddenAttributes()
  }

  // MARK: - Install binding

  func test_set_willCreateTheInstallIdAndTagTheItem() throws {
    XCTAssertNil(self.installIds.tag)

    try self.subject.set(self.session("token"))

    XCTAssertEqual(self.installIds.createCount, 1)
    let tag = try XCTUnwrap(self.installIds.tag)
    XCTAssertEqual(self.store.item()?.generic, tag)
  }

  func test_set_willReuseTheInstallId() throws {
    try self.subject.set(self.session("a"))
    try self.storage("env-other").set(self.session("b"))
    try self.subject.set(self.session("c"))

    XCTAssertEqual(self.installIds.createCount, 1, "One id serves every write and every auth environment.")
    XCTAssertEqual(self.store.item()?.generic, self.installIds.tag)
    XCTAssertEqual(self.store.item(service: self.service(for: "env-other"))?.generic, self.installIds.tag)
  }

  func test_getSession_willReturnTheSessionThisInstallPersisted() throws {
    try self.subject.set(self.session("token"))

    XCTAssertEqual(try self.subject.getSession(), self.parsed("token"))
    XCTAssertEqual(self.store.opCounts[.update], 0, "A tagged item is never re-tagged on read.")
    XCTAssertEqual(self.store.opCounts[.delete], 0)
  }

  func test_getSession_willReturnNilAndKeepTheItem_afterReinstall() throws {
    try self.subject.set(self.session("previous-install-token"))
    let previousTag = self.installIds.tag
    let reinstalledIds = InMemoryAuthInstallIdStore()
    let reinstalled = self.reinstalledStorage(installIds: reinstalledIds)

    XCTAssertNil(try reinstalled.getSession())
    XCTAssertNil(try reinstalled.getSession(), "Every read ignores it, not just the first.")

    XCTAssertEqual(self.store.item()?.generic, previousTag, "The item is ignored, not deleted or re-tagged.")
    XCTAssertEqual(self.store.opCounts[.delete], 0)
    XCTAssertEqual(self.store.opCounts[.update], 0)
    XCTAssertNil(reinstalledIds.tag, "Reading must not create an install id.")
  }

  func test_getSession_willReturnNil_whenTaggedByAnotherInstall() throws {
    self.installIds = InMemoryAuthInstallIdStore(id: "this-install")
    self.subject = self.storage()
    self.store.seed(data: self.session("token"), generic: Data("another-install".utf8))

    XCTAssertNil(try self.subject.getSession())
    XCTAssertNotNil(self.store.item())
    XCTAssertEqual(self.store.opCounts[.delete], 0)
  }

  func test_getSession_willReturnNil_forAnotherInstallsEntry_evenWhenItIsUnparseable() throws {
    // Whose it is decides first: another install's entry is left alone, parseable or not.
    self.store.seed(data: "not json", generic: Data("another-install".utf8))

    XCTAssertNil(try self.subject.getSession())
    XCTAssertEqual(self.store.item()?.string, "not json")
    XCTAssertEqual(self.store.opCounts[.delete], 0)
  }

  func test_getSession_willLogAnotherInstallsSessionWithoutThePayload() throws {
    try self.subject.set(self.session("secret-token-value"))

    _ = try self.reinstalledStorage().getSession()

    let lines = self.logger.messages
    XCTAssertTrue(lines.contains { $0.contains("another install") }, "Reading as signed out must be logged.")
    XCTAssertFalse(lines.contains { $0.contains("secret-token-value") }, "No log line may carry the token.")
  }

  func test_storage_willNotDeleteEachOthersSession_whenTwoProcessesShareTheAccessGroup() throws {
    // A host whose first keychain-access-groups entry is shared with an extension: both processes
    // see one item, each with its own container and so its own install id.
    let appIds = InMemoryAuthInstallIdStore()
    let extensionIds = InMemoryAuthInstallIdStore()
    let app = self.reinstalledStorage(installIds: appIds)
    let appExtension = self.reinstalledStorage(installIds: extensionIds)
    try app.set(self.session("app-token"))

    XCTAssertNil(try appExtension.getSession(), "The extension never uses the app's session.")
    try appExtension.deleteIfCurrent("extension-token")

    XCTAssertEqual(try app.getSession(), self.parsed("app-token"), "Neither read nor invalidate may sign the app out.")
    XCTAssertEqual(self.store.opCounts[.delete], 0)
    XCTAssertNil(extensionIds.tag)
  }

  func test_getSession_willThrowAndKeepItem_whenTheReadFails_withoutComparingTags() throws {
    try self.subject.set(self.session("token"))
    self.store.nextCopyStatuses = [errSecInteractionNotAllowed]

    XCTAssertThrowsError(try self.reinstalledStorage().getSession()) { error in
      self.assertSessionStorageFailure(error)
    }
    XCTAssertNotNil(self.store.item(), "A locked Keychain is transient: the item must survive it.")
  }

  func test_set_afterReinstall_willReplaceAndRetagTheItem() throws {
    try self.subject.set(self.session("old"))
    let reinstalledIds = InMemoryAuthInstallIdStore()
    let reinstalled = self.reinstalledStorage(installIds: reinstalledIds)

    try reinstalled.set(self.session("new"))

    XCTAssertEqual(self.store.item()?.generic, reinstalledIds.tag)
    XCTAssertEqual(try reinstalled.getSession(), self.parsed("new"))
    XCTAssertNil(try self.subject.getSession(), "Seen from the old install's id the item is now another install's.")
  }

  func test_getSession_willKeepAndTagAnUntaggedSession() throws {
    // Written by an SDK version that did not tag sessions: an update and a reinstall look the
    // same, and signing every user out on update is the worse outcome.
    self.store.seed(data: self.session("legacy-token"))

    XCTAssertEqual(try self.subject.getSession(), self.parsed("legacy-token"))

    let tag = try XCTUnwrap(self.installIds.tag, "Adopting the session creates this install's id.")
    XCTAssertEqual(self.store.item()?.generic, tag)
    let call = try XCTUnwrap(self.store.updateCalls.last)
    XCTAssertEqual(call.query[kSecAttrService as String] as? String, self.expectedService)
    XCTAssertEqual(call.query[kSecAttrAccount as String] as? String, KeychainAuthSessionStorage.accountName)
    XCTAssertEqual(call.attributes.count, 1, "Tagging must change only the tag, never the session or its protection class.")
    XCTAssertEqual(call.attributes[kSecAttrGeneric as String] as? Data, tag)
    XCTAssertEqual(self.store.item()?.string, self.session("legacy-token"))
  }

  func test_getSession_afterAdoptingAnUntaggedSession_willReturnNilAfterReinstall() throws {
    self.store.seed(data: self.session("legacy-token"))
    _ = try self.subject.getSession()

    XCTAssertNil(try self.reinstalledStorage().getSession())
    XCTAssertEqual(self.store.item()?.generic, self.installIds.tag, "Still the adopting install's item.")
  }

  func test_getSession_willStillReturnAnUntaggedSession_whenTaggingFails() throws {
    self.store.seed(data: self.session("legacy-token"))
    self.store.nextUpdateStatuses = [errSecInteractionNotAllowed]

    XCTAssertEqual(try self.subject.getSession(), self.parsed("legacy-token"))
    XCTAssertNil(self.store.item()?.generic)
    XCTAssertTrue(self.logger.entries.contains { $0.level == .warn && $0.message.contains("could not be tagged") })

    // Retried on the next read.
    XCTAssertEqual(try self.subject.getSession(), self.parsed("legacy-token"))
    XCTAssertEqual(self.store.item()?.generic, self.installIds.tag)
  }

  func test_deleteIfCurrent_willSpareAnotherInstallsSession_whateverItsToken() throws {
    try self.subject.set(self.session("token"))
    let reinstalled = self.reinstalledStorage()

    try reinstalled.deleteIfCurrent("token")

    XCTAssertEqual(try self.subject.getSession(), self.parsed("token"), "Not this install's to delete, even with the same token.")
    XCTAssertEqual(self.store.opCounts[.delete], 0)
  }

  func test_delete_willRemoveAnotherInstallsSession() throws {
    // `clearPersistedSession()` still clears whatever is stored.
    try self.subject.set(self.session("token"))

    try self.reinstalledStorage().delete()

    XCTAssertTrue(self.store.isEmpty)
  }

  func test_deleteIfCurrent_willDeleteAnUntaggedSessionWithoutTaggingIt() throws {
    self.store.seed(data: self.session("legacy-token"))

    try self.subject.deleteIfCurrent("legacy-token")

    XCTAssertTrue(self.store.isEmpty)
    XCTAssertEqual(self.store.opCounts[.update], 0)
    XCTAssertNil(self.installIds.tag, "Deleting must not create an install id.")
  }

  func test_deleteIfCurrent_willSpareAnUntaggedNewerSessionWithoutTaggingIt() throws {
    self.store.seed(data: self.session("newer-token"))

    try self.subject.deleteIfCurrent("older-token")

    XCTAssertEqual(self.store.item()?.string, self.session("newer-token"))
    XCTAssertEqual(self.store.opCounts[.update], 0)
  }

  func test_getSession_willThrowAndKeepItem_whenTheInstallIdCannotBeRead() throws {
    // A host whose id exists but is unreadable right now (a locked device) must not be read as a
    // fresh install: that would delete a session that belongs to it.
    try self.subject.set(self.session("token"))
    self.installIds.readError = PortalAuthError.sessionStorageFailure(message: "locked")

    XCTAssertThrowsError(try self.subject.getSession()) { error in
      self.assertSessionStorageFailure(error)
    }
    XCTAssertEqual(self.store.opCounts[.delete], 0)

    self.installIds.readError = nil
    XCTAssertEqual(try self.subject.getSession(), self.parsed("token"), "Once the id is readable the session is back.")
  }

  func test_set_willThrowAndWriteNothing_whenTheInstallIdCannotBeSaved() throws {
    self.installIds.createError = CocoaError(.fileWriteOutOfSpace)

    XCTAssertThrowsError(try self.subject.set(self.session("token"))) { error in
      self.assertSessionStorageFailure(error)
    }
    XCTAssertTrue(self.store.isEmpty, "An untagged write would be adopted by whichever install reads it next.")
    XCTAssertEqual(self.store.opCounts[.add], 0)
  }

  func test_getSession_willStillReturnAnUntaggedSession_whenTheInstallIdCannotBeSaved() throws {
    self.store.seed(data: self.session("legacy-token"))
    self.installIds.createError = CocoaError(.fileWriteOutOfSpace)

    XCTAssertEqual(try self.subject.getSession(), self.parsed("legacy-token"))
    XCTAssertNil(self.store.item()?.generic)
    XCTAssertEqual(self.store.opCounts[.update], 0)

    self.installIds.createError = nil
    XCTAssertEqual(try self.subject.getSession(), self.parsed("legacy-token"))
    XCTAssertEqual(self.store.item()?.generic, self.installIds.tag, "Tagged on the next read.")
  }

  // MARK: - FileAuthInstallIdStore

  /// A fresh base directory, removed after `body`.
  private func withBaseDirectory(_ body: (URL) throws -> Void) throws {
    let base = FileManager.default.temporaryDirectory
      .appendingPathComponent("PortalSwiftTests.installId.\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: base) }
    try body(base)
  }

  func test_fileInstallIdStore_willLiveUnderApplicationSupportByDefault() throws {
    let ids = FileAuthInstallIdStore()

    XCTAssertEqual(ids.fileURL.lastPathComponent, FileAuthInstallIdStore.fileName)
    XCTAssertEqual(ids.fileURL.deletingLastPathComponent().lastPathComponent, FileAuthInstallIdStore.directoryName)
    XCTAssertEqual(ids.fileURL.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent, "Application Support")
  }

  func test_fileInstallIdStore_willReturnNil_beforeTheIdIsCreated_withoutCreatingAnything() throws {
    try self.withBaseDirectory { base in
      let ids = FileAuthInstallIdStore(baseDirectory: base)

      XCTAssertNil(try ids.current())
      XCTAssertFalse(FileManager.default.fileExists(atPath: base.path), "current() must never create the id or its directory.")
    }
  }

  func test_fileInstallIdStore_willCreateOnceAndKeepTheId() throws {
    try self.withBaseDirectory { base in
      let ids = FileAuthInstallIdStore(baseDirectory: base)

      let created = try ids.currentOrCreate()

      XCTAssertNotNil(UUID(uuidString: created))
      XCTAssertEqual(try ids.current(), created)
      XCTAssertEqual(try ids.currentOrCreate(), created)
      XCTAssertEqual(try String(contentsOf: ids.fileURL, encoding: .utf8), created)
      XCTAssertEqual(try FileAuthInstallIdStore(baseDirectory: base).current(), created, "Another instance reads the same id.")
    }
  }

  func test_fileInstallIdStore_willReadAnEmptyFileAsNoId_andReplaceIt() throws {
    try self.withBaseDirectory { base in
      let ids = FileAuthInstallIdStore(baseDirectory: base)
      try FileManager.default.createDirectory(at: ids.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try Data(" \n".utf8).write(to: ids.fileURL)

      XCTAssertNil(try ids.current())
      let created = try ids.currentOrCreate()
      XCTAssertEqual(try ids.current(), created)
    }
  }

  func test_fileInstallIdStore_willThrow_whenTheIdExistsButCannotBeRead_andNeverReplaceIt() throws {
    try self.withBaseDirectory { base in
      let ids = FileAuthInstallIdStore(baseDirectory: base)
      // A directory where the file should be: it exists, and reading it fails, as a protected file
      // does while the device is locked.
      try FileManager.default.createDirectory(at: ids.fileURL, withIntermediateDirectories: true)

      XCTAssertThrowsError(try ids.current()) { error in
        let message = self.assertSessionStorageFailure(error)
        XCTAssertFalse(message.contains(base.path), "The error must not carry the file path.")
      }
      XCTAssertThrowsError(try ids.currentOrCreate()) { error in
        self.assertSessionStorageFailure(error)
      }
      var isDirectory: ObjCBool = false
      XCTAssertTrue(FileManager.default.fileExists(atPath: ids.fileURL.path, isDirectory: &isDirectory))
      XCTAssertTrue(isDirectory.boolValue, "An id that cannot be read must never be overwritten.")
    }
  }

  func test_fileInstallIdStore_willThrow_whenTheIdCannotBeSaved() throws {
    try self.withBaseDirectory { base in
      // A file where the directory should be, so the directory cannot be created.
      try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
      try Data("x".utf8).write(to: base.appendingPathComponent(FileAuthInstallIdStore.directoryName))
      let ids = FileAuthInstallIdStore(baseDirectory: base)

      XCTAssertThrowsError(try ids.currentOrCreate()) { error in
        self.assertSessionStorageFailure(error)
      }
    }
  }

  func test_fileInstallIdStore_willCreateOneId_whenCreatingConcurrently() throws {
    try self.withBaseDirectory { base in
      let instances = (0 ..< 8).map { _ in FileAuthInstallIdStore(baseDirectory: base) }
      let ids = IdSet()

      DispatchQueue.concurrentPerform(iterations: 64) { index in
        if let id = try? instances[index % instances.count].currentOrCreate() {
          ids.insert(id)
        }
      }

      XCTAssertEqual(ids.values.count, 1)
      XCTAssertEqual(try FileAuthInstallIdStore(baseDirectory: base).current(), ids.values.first)
    }
  }

  func test_storage_withFileInstallIds_willStartSignedOutAfterReinstall() throws {
    // End to end over the real file: deleting the app deletes the file, while the Keychain item
    // survives.
    try self.withBaseDirectory { base in
      let storage = KeychainAuthSessionStorage(
        authEnvironmentId: AuthTestFixtures.authEnvironmentId,
        store: self.store,
        installIds: FileAuthInstallIdStore(baseDirectory: base)
      )
      try storage.set(self.session("old-install-token"))
      XCTAssertEqual(try storage.getSession(), self.parsed("old-install-token"))

      try FileManager.default.removeItem(at: base)

      XCTAssertNil(try storage.getSession())
      XCTAssertFalse(FileManager.default.fileExists(atPath: base.path), "Reading must not create the id.")

      // The reinstalled app's own sign-in replaces the leftover and is restored from then on.
      try storage.set(self.session("new-install-token"))
      XCTAssertEqual(try storage.getSession(), self.parsed("new-install-token"))
    }
  }

  // MARK: - Error messages

  func test_getSession_willNotIncludeStoredValueInErrorMessage() throws {
    self.store.seed(data: "{\"clientSessionToken\":\"SECRET\"}")
    self.store.nextDeleteStatuses = [errSecIO]

    XCTAssertThrowsError(try self.subject.getSession()) { error in
      XCTAssertFalse(error.localizedDescription.contains("SECRET"), "The unclearable-entry failure leaked the stored token.")
      XCTAssertFalse(String(describing: error).contains("SECRET"))
    }

    self.store.reset()
    self.store.seed(data: self.session("SECRET"))
    self.store.nextCopyStatuses = [errSecIO]

    XCTAssertThrowsError(try self.subject.getSession()) { error in
      XCTAssertFalse(error.localizedDescription.contains("SECRET"), "The read failure leaked the stored token.")
      XCTAssertFalse(String(describing: error).contains("SECRET"))
    }

    self.logger.assertNoSecret("SECRET")
  }

  func test_storage_willIncludeOSStatusInErrorMessage() throws {
    XCTAssertEqual(errSecInteractionNotAllowed, -25308, "The taxonomy documents this status by number.")
    try self.subject.set(self.session("token"))
    self.store.nextCopyStatuses = [errSecInteractionNotAllowed]

    XCTAssertThrowsError(try self.subject.getSession()) { error in
      let description = self.assertSessionStorageFailure(error)
      XCTAssertTrue(description.contains("-25308"), "The OSStatus is on the log allow-list and is what makes the failure diagnosable.")
    }
  }

  // MARK: - PersistedSessionCodec

  func test_persistedSessionCodec_willEncodeExactlyTwoKeys() throws {
    let raw = try PersistedSessionCodec.encode(PersistedSession(clientSessionToken: "t", endUserId: "u"))

    let json = try JSONSerialization.jsonObject(with: Data(raw.utf8), options: [])
    let object = try XCTUnwrap(json as? [String: Any])
    XCTAssertEqual(Set(object.keys), ["clientSessionToken", "endUserId"])
    XCTAssertEqual(object["clientSessionToken"] as? String, "t")
    XCTAssertEqual(object["endUserId"] as? String, "u")
  }

  func test_persistedSessionCodec_willDecodeRNAndAndroidPayloadShape() throws {
    let expected = PersistedSession(clientSessionToken: "t", endUserId: "u")

    XCTAssertEqual(try PersistedSessionCodec.decode("{\"clientSessionToken\":\"t\",\"endUserId\":\"u\"}"), expected)
    XCTAssertEqual(try PersistedSessionCodec.decode("{\"endUserId\":\"u\",\"clientSessionToken\":\"t\"}"), expected)
  }

  func test_persistedSessionCodec_willRejectNullFields() {
    XCTAssertThrowsError(try PersistedSessionCodec.decode("{\"clientSessionToken\":null,\"endUserId\":\"u\"}")) { error in
      self.assertSessionStorageFailure(error)
    }
  }
}
