//
//  KeychainPortalSessionTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

/// Covers `KeychainPortalSession`, the session `PortalAuth` hands back, against the in-memory
/// `MockAuthSessionStorage`.
///
/// Four invariants carry the whole type and every case here pins one of them:
/// `getToken()` is a lock-guarded in-memory read that never touches storage (it sits on the
/// hot path of every request); `invalidate()` clears the in-memory token *before* it asks
/// storage to delete, so a slow, failing or superseded Keychain can never hand the token back
/// out; the persisted delete is a compare-and-delete, so a stale session can never remove the
/// entry a newer login already re-keyed; and the whole thing is idempotent and safe under
/// overlap, so eight subsystems reacting to the same 401 produce exactly one storage delete.
///
/// Concurrency cases use real threads (`runConcurrently`, and `DispatchQueue.concurrentPerform`
/// for the mixed read/invalidate race) because the production synchronisation is an `NSLock`;
/// both helpers double as deadlock detectors. The invalidation registry is reset around every
/// case because `invalidateCredentials(_:)` records a per-credential monitor, and a
/// `RecordingLogger` is installed throughout so a case can prove the token never reached a log.
final class KeychainPortalSessionTests: XCTestCase {
  /// The token the default `subject` holds and the default `storage` has persisted.
  private static let sessionToken = "session-token"
  /// The end user the default `subject` authenticates.
  private static let endUserId = "user-1"

  private var storage = MockAuthSessionStorage()
  private var subject = KeychainPortalSession(
    clientSessionToken: KeychainPortalSessionTests.sessionToken,
    endUserId: KeychainPortalSessionTests.endUserId,
    storage: MockAuthSessionStorage()
  )
  private var logger = RecordingLogger()

  // MARK: - Helpers

  /// A lock-guarded counter for hooks that run on whatever thread the storage call came in on.
  private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0

    var value: Int {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._value
    }

    func increment() {
      self.lock.lock()
      self._value += 1
      self.lock.unlock()
    }
  }

  /// What the mixed read/invalidate race observed, collected across threads.
  private final class RaceResults: @unchecked Sendable {
    private let lock = NSLock()
    private var _tokens: [String] = []
    private var _tokenErrors: [Error] = []
    private var _invalidateErrors: [Error] = []

    var tokens: [String] {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._tokens
    }

    var tokenErrors: [Error] {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._tokenErrors
    }

    var invalidateErrors: [Error] {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._invalidateErrors
    }

    func record(token: String) {
      self.lock.lock()
      self._tokens.append(token)
      self.lock.unlock()
    }

    func record(tokenError: Error) {
      self.lock.lock()
      self._tokenErrors.append(tokenError)
      self.lock.unlock()
    }

    func record(invalidateError: Error) {
      self.lock.lock()
      self._invalidateErrors.append(invalidateError)
      self.lock.unlock()
    }
  }

  /// The exact string the storage holds for a session, so a test seeds the slot the same way
  /// `PortalAuth` would.
  private func persisted(_ token: String, endUserId: String = KeychainPortalSessionTests.endUserId) -> String {
    AuthTestFixtures.persistedSession(token: token, endUserId: endUserId)
  }

  /// A session over `storage`, for the cases that need a token other than the default one.
  private func makeSession(
    token: String,
    endUserId: String = KeychainPortalSessionTests.endUserId,
    storage: MockAuthSessionStorage
  ) -> KeychainPortalSession {
    KeychainPortalSession(clientSessionToken: token, endUserId: endUserId, storage: storage)
  }

  override func setUpWithError() throws {
    try super.setUpWithError()
    CredentialInvalidationRegistry.shared.resetForTesting()
    self.logger = RecordingLogger()
    self.logger.install()
    self.storage = MockAuthSessionStorage(stored: self.persisted(Self.sessionToken))
    self.subject = KeychainPortalSession(
      clientSessionToken: Self.sessionToken,
      endUserId: Self.endUserId,
      storage: self.storage
    )
  }

  override func tearDownWithError() throws {
    self.logger.uninstall()
    CredentialInvalidationRegistry.shared.resetForTesting()
    try super.tearDownWithError()
  }

  // MARK: - getToken

  func test_getToken_willReturnTokenWithoutTouchingStorage() throws {
    let first = try self.subject.getToken()
    let second = try self.subject.getToken()

    XCTAssertEqual(first, Self.sessionToken)
    XCTAssertEqual(second, Self.sessionToken)
    XCTAssertEqual(self.storage.getCalls, 0, "getToken() sits on the hot path and must never read storage")
    XCTAssertTrue(self.storage.events.isEmpty, "No storage operation of any kind is performed by a read")
  }

  func test_getToken_willReturnSameValueRepeatedly() throws {
    for _ in 0 ..< 100 {
      XCTAssertEqual(try self.subject.getToken(), Self.sessionToken)
    }

    XCTAssertEqual(self.storage.getCalls, 0)
    XCTAssertTrue(self.storage.events.isEmpty)
  }

  func test_getToken_willThrowSessionInvalidated_afterInvalidate() throws {
    try self.subject.invalidate()

    XCTAssertThrowsError(try self.subject.getToken()) { error in
      let credentialError = error as? PortalCredentialError
      XCTAssertEqual(credentialError, .sessionInvalidated)
      XCTAssertEqual(credentialError?.reason, .sessionInvalidated)
      XCTAssertEqual(credentialError?.reason?.rawValue, "SESSION_INVALIDATED", "The wire string is shared with the other SDKs")
      XCTAssertEqual(credentialError?.requiresReauthentication, true)
    }
  }

  func test_getToken_willThrowSessionInvalidated_whenDeleteFailed() {
    self.storage.onDeleteIfCurrent = { _ in
      throw PortalAuthError.sessionStorageFailure(message: "keychain locked")
    }

    XCTAssertThrowsError(try self.subject.invalidate()) { error in
      XCTAssertEqual(error as? PortalAuthError, .sessionStorageFailure(message: "keychain locked"))
    }
    XCTAssertThrowsError(try self.subject.getToken()) { error in
      XCTAssertEqual(
        error as? PortalCredentialError,
        .sessionInvalidated,
        "The in-memory token is cleared before the delete, so a failed delete still ends this session"
      )
    }
  }

  func test_getToken_willNotTouchStorage_afterInvalidate() throws {
    try self.subject.invalidate()

    for _ in 0 ..< 3 {
      XCTAssertThrowsError(try self.subject.getToken())
    }

    XCTAssertEqual(self.storage.getCalls, 0, "An invalidated session never goes back to storage to re-check")
    XCTAssertEqual(self.storage.deleteIfCurrentCalls, 1)
  }

  func test_getToken_willBeThreadSafe_whileInvalidating() {
    let results = RaceResults()
    let session = self.subject

    DispatchQueue.concurrentPerform(iterations: 16) { index in
      if index.isMultiple(of: 2) {
        do {
          try session.invalidate()
        } catch {
          results.record(invalidateError: error)
        }
      } else {
        do {
          let token = try session.getToken()
          results.record(token: token)
        } catch {
          results.record(tokenError: error)
        }
      }
    }

    XCTAssertEqual(results.tokens.count + results.tokenErrors.count, 8, "Every reader produced exactly one outcome")
    for token in results.tokens {
      XCTAssertEqual(token, Self.sessionToken, "A reader never observes a partially cleared token")
    }
    for error in results.tokenErrors {
      XCTAssertEqual(error as? PortalCredentialError, .sessionInvalidated)
    }
    XCTAssertTrue(results.invalidateErrors.isEmpty)
    XCTAssertEqual(self.storage.deleteIfCurrentCalls, 1, "Eight overlapping invalidations produce one storage delete")
    XCTAssertNil(self.storage.stored)
  }

  // MARK: - endUserId

  func test_endUserId_willExposeTheEndUser() {
    let session = self.makeSession(token: "token-42", endUserId: "user-42", storage: MockAuthSessionStorage())

    XCTAssertEqual(session.endUserId, "user-42")
  }

  func test_endUserId_willStayReadableAfterInvalidate() throws {
    try self.subject.invalidate()

    XCTAssertEqual(self.subject.endUserId, Self.endUserId, "Hosts key sign-out UI and per-user state on the end user id")
  }

  // MARK: - invalidate

  func test_invalidate_willDeleteViaDeleteIfCurrentExactlyOnce() throws {
    try self.subject.invalidate()

    XCTAssertEqual(self.storage.deleteIfCurrentCalls, 1)
    XCTAssertEqual(self.storage.deleteCalls, 0, "A session never issues an unconditional delete")
    XCTAssertNil(self.storage.stored)
  }

  func test_invalidate_willPassOwnTokenToDeleteIfCurrent() throws {
    try self.subject.invalidate()

    XCTAssertEqual(self.storage.deleteIfCurrentTokens, [Self.sessionToken], "The compare-and-delete is keyed on this session's own token")
  }

  func test_invalidate_willBeIdempotent() throws {
    try self.subject.invalidate()
    try self.subject.invalidate()
    try self.subject.invalidate()

    XCTAssertEqual(self.storage.deleteIfCurrentCalls, 1)
    XCTAssertNil(self.storage.stored)
  }

  func test_invalidate_willProduceOneDelete_when8ConcurrentInvalidateCredentials() throws {
    let session = self.subject

    try runConcurrently(8) {
      try invalidateCredentials(session)
    }

    XCTAssertEqual(self.storage.deleteIfCurrentCalls, 1, "The registry monitor plus the session's early return collapse onto one delete")
    XCTAssertNil(self.storage.stored)
  }

  func test_invalidate_willProduceOneDelete_when8ConcurrentDirectCalls() throws {
    let session = self.subject

    try runConcurrently(8) {
      try session.invalidate()
    }

    XCTAssertEqual(self.storage.deleteIfCurrentCalls, 1, "The session's own lock suffices without the registry monitor")
    XCTAssertNil(self.storage.stored)
  }

  func test_invalidate_willClearTokenBeforeDelete() throws {
    let session = self.subject
    let hookCalls = CallCounter()
    self.storage.onDeleteIfCurrent = { _ in
      hookCalls.increment()
      XCTAssertThrowsError(try session.getToken()) { error in
        XCTAssertEqual(error as? PortalCredentialError, .sessionInvalidated, "The token is already gone when storage is asked to delete")
      }
    }

    try session.invalidate()

    XCTAssertEqual(hookCalls.value, 1)
  }

  func test_invalidate_willRethrowSessionStorageFailure_whenDeleteFails() {
    self.storage.onDeleteIfCurrent = { _ in
      throw PortalAuthError.sessionStorageFailure(message: "keychain locked")
    }

    XCTAssertThrowsError(try self.subject.invalidate()) { error in
      guard case let .sessionStorageFailure(message)? = error as? PortalAuthError else {
        XCTFail("Expected PortalAuthError.sessionStorageFailure but got \(type(of: error)).")
        return
      }
      XCTAssertEqual(message, "keychain locked", "A PortalAuthError from storage is rethrown unchanged")
    }
  }

  func test_invalidate_willWrapForeignError_asSessionStorageFailure() {
    self.storage.onDeleteIfCurrent = { _ in
      throw NSError(domain: Self.sessionToken, code: -25308)
    }

    XCTAssertThrowsError(try self.subject.invalidate()) { error in
      guard case let .sessionStorageFailure(message)? = error as? PortalAuthError else {
        XCTFail("Expected the foreign error to be wrapped as PortalAuthError.sessionStorageFailure, got \(type(of: error)).")
        return
      }
      XCTAssertFalse(message.contains(Self.sessionToken), "The wrapper names only the error's type, never anything the error carried")
    }
  }

  func test_invalidate_willNotRetryDelete_afterFailure() {
    self.storage.onDeleteIfCurrent = { _ in
      throw PortalAuthError.sessionStorageFailure(message: "keychain locked")
    }

    XCTAssertThrowsError(try self.subject.invalidate())
    XCTAssertNoThrow(try self.subject.invalidate(), "The token is already nil, so the second call returns early")
    XCTAssertEqual(self.storage.deleteIfCurrentCalls, 1)
  }

  func test_invalidate_willNotDeleteNewerSession() throws {
    let storage = MockAuthSessionStorage(stored: self.persisted("fresh-token", endUserId: "user-2"))
    let stale = self.makeSession(token: "old-token", storage: storage)

    try stale.invalidate()

    XCTAssertEqual(storage.deleteIfCurrentCalls, 1)
    XCTAssertEqual(
      storage.storedSession,
      PersistedSession(clientSessionToken: "fresh-token", endUserId: "user-2"),
      "A positively different token belongs to a newer login and is spared"
    )
  }

  func test_invalidate_willLeaveNewerSessionAcrossRepeatedInvalidate() throws {
    let storage = MockAuthSessionStorage(stored: self.persisted("token-a"))
    let sessionA = self.makeSession(token: "token-a", storage: storage)

    try sessionA.invalidate()
    XCTAssertNil(storage.stored)

    storage.stored = self.persisted("token-b", endUserId: "user-2")
    try sessionA.invalidate()

    XCTAssertEqual(storage.storedSession?.clientSessionToken, "token-b", "A repeated invalidate cannot reach a session persisted after it")
    XCTAssertEqual(storage.deleteIfCurrentCalls, 1)
  }

  func test_invalidate_willStillStopSupersededSessionHandingOutToken() throws {
    let storage = MockAuthSessionStorage(stored: self.persisted("token-b", endUserId: "user-2"))
    let stale = self.makeSession(token: "token-a", storage: storage)

    try stale.invalidate()

    XCTAssertThrowsError(try stale.getToken()) { error in
      XCTAssertEqual(error as? PortalCredentialError, .sessionInvalidated)
    }
    XCTAssertEqual(storage.storedSession?.clientSessionToken, "token-b")
  }

  func test_invalidate_willDelete_whenStorageStillHoldsThisSession() throws {
    XCTAssertEqual(self.storage.storedSession?.clientSessionToken, Self.sessionToken)

    try self.subject.invalidate()

    XCTAssertNil(self.storage.stored)
  }

  func test_invalidate_willThrowAndKeepEntry_whenStoredSessionUnreadable() throws {
    self.storage.onGet = {
      throw PortalAuthError.sessionStorageFailure(message: "The persisted session could not be read (OSStatus -25308).")
    }

    XCTAssertThrowsError(try self.subject.invalidate()) { error in
      XCTAssertTrue(error is PortalAuthError, "The storage failure reaches the caller, who now knows a stale copy may remain on disk")
    }

    XCTAssertEqual(self.storage.deleteIfCurrentCalls, 1)
    XCTAssertNotNil(self.storage.stored, "An entry that cannot be read may belong to a newer login and is never deleted blind")
    XCTAssertThrowsError(try self.subject.getToken()) { error in
      XCTAssertEqual(error as? PortalCredentialError, .sessionInvalidated, "The in-memory session is over either way")
    }
  }

  func test_invalidate_willDelete_whenStoredSessionCorrupt() throws {
    let storage = MockAuthSessionStorage(stored: "{not json")
    let session = self.makeSession(token: Self.sessionToken, storage: storage)

    try session.invalidate()

    XCTAssertEqual(storage.deleteIfCurrentCalls, 1)
    XCTAssertNil(storage.stored)
  }

  func test_invalidate_willCallDeleteIfCurrent_whenStorageEmpty() throws {
    let storage = MockAuthSessionStorage()
    let session = self.makeSession(token: Self.sessionToken, storage: storage)

    XCTAssertNoThrow(try session.invalidate())

    XCTAssertEqual(storage.deleteIfCurrentCalls, 1)
    XCTAssertNil(storage.stored)
  }

  func test_invalidate_willNotDeleteSessionPersistedDuringRead() throws {
    let storage = MockAuthSessionStorage(stored: self.persisted("token-a"))
    let sessionA = self.makeSession(token: "token-a", storage: storage)
    let newerSession = self.persisted("token-b", endUserId: "user-2")
    storage.onGet = { [weak storage] in
      // A login lands between the compare-and-delete's read and its decision.
      storage?.stored = newerSession
    }

    try sessionA.invalidate()

    XCTAssertEqual(storage.storedSession?.clientSessionToken, "token-b", "The session persisted mid-read is spared")
  }

  func test_invalidate_willStillStopRacingSessionHandingOutOwnToken() throws {
    let storage = MockAuthSessionStorage(stored: self.persisted("token-a"))
    let sessionA = self.makeSession(token: "token-a", storage: storage)
    let newerSession = self.persisted("token-b", endUserId: "user-2")
    storage.onGet = { [weak storage] in
      storage?.stored = newerSession
    }

    try sessionA.invalidate()

    XCTAssertThrowsError(try sessionA.getToken()) { error in
      XCTAssertEqual(error as? PortalCredentialError, .sessionInvalidated, "Sparing the newer entry never revives the old session")
    }
  }

  func test_invalidate_willNotIncludeTokenInThrownMessage() {
    let secretToken = "client-session-token-must-never-appear"
    let storage = MockAuthSessionStorage(stored: self.persisted(secretToken))
    let session = self.makeSession(token: secretToken, storage: storage)
    // The token is smuggled into the storage error itself: the wrapper must drop it.
    storage.onDeleteIfCurrent = { token in
      throw NSError(domain: token, code: -25308, userInfo: [NSLocalizedDescriptionKey: token])
    }

    XCTAssertThrowsError(try session.invalidate()) { error in
      let description = (error as? LocalizedError)?.errorDescription ?? "\(error)"
      XCTAssertFalse(description.contains(secretToken), "A thrown message never carries the client session token")
      XCTAssertFalse(error.localizedDescription.contains(secretToken))
    }
    self.logger.assertNoSecret(secretToken)
  }

  // MARK: - Credential helpers

  func test_resolveCredentialToken_willReturnToken_whenLive() throws {
    XCTAssertEqual(try resolveCredentialToken(self.subject), Self.sessionToken)
    XCTAssertEqual(self.storage.getCalls, 0)
    XCTAssertTrue(self.storage.events.isEmpty)
  }

  func test_resolveCredentialToken_willKeepSessionInvalidatedReason() throws {
    try self.subject.invalidate()

    XCTAssertThrowsError(try resolveCredentialToken(self.subject)) { error in
      let credentialError = error as? PortalCredentialError
      XCTAssertEqual(credentialError, .sessionInvalidated, "The boundary never downgrades a precise reason to .providerFailure")
      XCTAssertEqual(credentialError?.reason?.rawValue, "SESSION_INVALIDATED")
    }
  }

  func test_invalidateCredentials_willPropagateSessionStorageFailure_andReleaseGuard() async throws {
    let storage = self.storage
    let session = self.subject
    storage.onDeleteIfCurrent = { _ in
      throw PortalAuthError.sessionStorageFailure(message: "keychain locked")
    }

    XCTAssertThrowsError(try invalidateCredentials(session)) { error in
      XCTAssertEqual(error as? PortalAuthError, .sessionStorageFailure(message: "keychain locked"))
    }

    let finished = try await withTimeout(2) {
      try invalidateCredentials(session)
      return true
    }

    XCTAssertEqual(finished, true, "The per-credential monitor is released even when the invalidation throws")
    XCTAssertEqual(storage.deleteIfCurrentCalls, 1, "The second call returns early and makes no further delete")
  }

  func test_staticApiKeyOf_willReturnEmptyForSession() {
    XCTAssertEqual(staticApiKeyOf(self.subject), "", "A session is never a static Client API Key")
  }
}
