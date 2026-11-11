//
//  PortalAuthReplayTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

// MARK: - Test support

/// Raised by the result helpers so a case that got the wrong `AuthResult` stops at the
/// assertion instead of continuing against a value it cannot use.
private enum ReplayTestError: LocalizedError {
  case unexpectedResult(String)

  var errorDescription: String? {
    switch self {
    case let .unexpectedResult(actual):
      return "PortalAuthReplayTests: unexpected auth result \(actual)."
    }
  }
}

/// A Keychain fault for the persist-failure cases. `PortalAuth` wraps any non-`PortalAuthError`
/// storage error into `sessionStorageFailure`, so the concrete type only has to be distinct.
private struct KeychainFault: Error {}

/// An `NSLock`-guarded slot for an `AuthResult` produced inside a `Task`.
///
/// The results under test are class-backed and not `Sendable`, so they are handed back through
/// a guarded box rather than a `Task`'s `Success` type — which would force a `Sendable`
/// conformance the SDK deliberately does not claim.
private final class ResultBox: @unchecked Sendable {
  private let lock = NSLock()
  private var _result: AuthResult?

  var result: AuthResult? {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._result
  }

  func store(_ result: AuthResult?) {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._result = result
  }
}

/// `ResultBox` for the `AuthenticatedResult` `verifyTotp` returns.
private final class AuthenticatedBox: @unchecked Sendable {
  private let lock = NSLock()
  private var _result: AuthenticatedResult?

  var result: AuthenticatedResult? {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._result
  }

  func store(_ result: AuthenticatedResult) {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._result = result
  }
}

/// A one-way flag a storage hook flips from whatever thread ran it.
private final class Flag: @unchecked Sendable {
  private let lock = NSLock()
  private var _isSet = false

  var isSet: Bool {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._isSet
  }

  func set() {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._isSet = true
  }
}

/// A guarded call tally for hooks that must fail only on their first invocation.
private final class CallCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var _count = 0

  var count: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._count
  }

  /// Increments and returns the new count, so a hook can branch on "first call".
  func next() -> Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._count += 1
    return self._count
  }
}

// MARK: - PortalAuthReplayTests

/// Covers the replay memo and `grantMutex` of `PortalAuth` — the pair that makes a
/// re-delivered redirect safe.
///
/// A Client Auth grant is single-use: the backend rejects the second exchange of one token, and
/// iOS re-delivers a deep link routinely (a cold launch that also fires `onOpenURL`, a scene
/// restoring, a host that forwards the same URL from two places). So `handleRedirect` remembers
/// the last grant it exchanged and replays that result — the *same* `PortalSession` instance —
/// instead of spending the grant twice, and it holds one lock from reading the memo through the
/// exchange to the Keychain write so two concurrent deliveries collapse into a single exchange
/// and a sign-out cannot land between an exchange and its persist.
///
/// The cases below pin all four halves of that contract: what is remembered (only a successful
/// exchange, byte-exact on the token, one slot, per instance), what forgets it
/// (`clearPersistedSession`, a failed exchange), how a TOTP step is advanced to the session it
/// resolved to, and the locking behaviour under concurrency — including the two places where
/// the lock must be released on the way out (a throwing exchange, a throwing persist) and the
/// documented decision that a cancelled caller still finishes the exchange the backend has
/// already burned.
///
/// Concurrency cases gate the transport (`RecordingPortalRequests.gateFirstRequest`) so a
/// second delivery provably starts while the first is inside the exchange, and every wait is a
/// bounded poll of at most 2 s — a re-entrancy or deadlock regression then fails as an
/// assertion rather than hanging the suite.
final class PortalAuthReplayTests: XCTestCase {
  private var requests = RecordingPortalRequests()
  private var storage = MockAuthSessionStorage()
  private var logger = RecordingLogger()
  private var auth = AuthTestFixtures.makeAuth(requests: RecordingPortalRequests())

  override func setUpWithError() throws {
    try super.setUpWithError()
    CredentialInvalidationRegistry.shared.resetForTesting()
    self.requests = RecordingPortalRequests()
    self.storage = MockAuthSessionStorage()
    self.logger = RecordingLogger()
    self.auth = AuthTestFixtures.makeAuth(requests: self.requests, storage: self.storage, logger: self.logger)
  }

  override func tearDownWithError() throws {
    self.logger.uninstall()
    CredentialInvalidationRegistry.shared.resetForTesting()
    try super.tearDownWithError()
  }

  // MARK: - Replaying a successful exchange

  func test_handleRedirect_willReplayFirstExchange_withSameSessionInstance() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    let redirect = AuthTestFixtures.magicLinkRedirect()

    let first = try self.expectAuthenticated(await self.auth.handleRedirect(redirect))
    let replay = try self.expectAuthenticated(await self.auth.handleRedirect(redirect))

    XCTAssertTrue(first.session === replay.session, "The replay hands back the very session the first exchange produced")
    XCTAssertEqual(self.requests.callCount, 1, "The grant was exchanged once; the second delivery never reached the backend")
    XCTAssertEqual(self.storage.setCalls, 1, "The session was persisted once")
    self.logger.assertNoSecret(AuthTestFixtures.grantToken)
    self.logger.assertNoSecret(AuthTestFixtures.clientSessionToken)
  }

  func test_handleRedirect_willReplay_whenDifferentUrlCarriesSameGrant() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()

    let first = try self.expectAuthenticated(await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect()))
    // Same grant, different spelling of the same target: a different scheme case and a trailing
    // slash, both of which the redirect matcher normalises away.
    let replay = try self.expectAuthenticated(
      await self.auth.handleRedirect("PortalExample://auth/callback/?token=grant-token&authMethod=EMAIL_MAGIC_LINK")
    )

    XCTAssertTrue(first.session === replay.session, "The memo is keyed on the grant, not on the URL it arrived in")
    XCTAssertEqual(self.requests.callCount, 1)
  }

  func test_handleRedirect_willReplayTotpStep() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse(
      clientSessionToken: nil,
      userJwt: AuthTestFixtures.userJwt()
    )
    let redirect = AuthTestFixtures.magicLinkRedirect()

    let first = try self.expectTotpRequired(await self.auth.handleRedirect(redirect))
    let replay = try self.expectTotpRequired(await self.auth.handleRedirect(redirect))

    XCTAssertEqual(replay, first, "A re-delivered redirect resumes the same TOTP step")
    XCTAssertEqual(self.requests.callCount, 1, "The grant was exchanged once")
    XCTAssertEqual(self.storage.setCalls, 0, "Nothing is persisted while a TOTP step is pending")
  }

  func test_handleRedirect_willReplayAuthenticated_afterVerifyTotpAdvancedStep() async throws {
    self.requests.queuedResponses = [
      .success(AuthTestFixtures.grantResponse(clientSessionToken: nil, userJwt: AuthTestFixtures.userJwt())),
      .success(AuthTestFixtures.totpResponse())
    ]
    let redirect = AuthTestFixtures.magicLinkRedirect()

    let step = try self.expectTotpRequired(await self.auth.handleRedirect(redirect))
    let verified = try await self.auth.verifyTotp("777870", userJwt: step.userJwt)
    let replay = try self.expectAuthenticated(await self.auth.handleRedirect(redirect))

    XCTAssertTrue(replay.session === verified.session, "The memo advanced to the session the step resolved to, not the step")
    XCTAssertEqual(self.requests.callCount, 2, "One exchange and one TOTP validation; the redelivery cost no request")
    XCTAssertEqual(self.storage.setCalls, 1, "Only the TOTP validation persisted a session")
  }

  // MARK: - Advancing the memo through verifyTotp

  func test_verifyTotp_willLeaveMemo_whenUnrelatedJwtVerified() async throws {
    self.requests.queuedResponses = [
      .success(AuthTestFixtures.grantResponse(clientSessionToken: nil, userJwt: AuthTestFixtures.userJwt(endUserId: "user-1"))),
      .success(AuthTestFixtures.totpResponse())
    ]
    let redirect = AuthTestFixtures.magicLinkRedirect()

    let step = try self.expectTotpRequired(await self.auth.handleRedirect(redirect))
    // A different step's JWT: matching nothing in the memo, it must leave the remembered step
    // alone rather than invent an entry no redirect can replay.
    _ = try await self.auth.verifyTotp("777870", userJwt: AuthTestFixtures.userJwt(endUserId: "user-2"))
    let redelivery = try self.expectTotpRequired(await self.auth.handleRedirect(redirect))

    XCTAssertEqual(redelivery, step, "The remembered step still replays as a step")
    XCTAssertEqual(self.requests.callCount, 2, "One exchange and one TOTP validation; the redelivery cost no request")
  }

  func test_verifyTotp_willNotCreateMemo_whenNoPendingStep() async throws {
    self.requests.queuedResponses = [
      .success(AuthTestFixtures.totpResponse()),
      .success(AuthTestFixtures.grantResponse())
    ]

    _ = try await self.auth.verifyTotp("777870", userJwt: AuthTestFixtures.userJwt())
    let result = try self.expectAuthenticated(await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect()))

    XCTAssertEqual(try result.session.getToken(), AuthTestFixtures.clientSessionToken)
    XCTAssertEqual(self.requests.callCount, 2, "Verifying with no pending step records nothing, so the redirect is still exchanged")
  }

  // MARK: - Grant identity

  func test_handleRedirect_willExchangeDifferentGrant() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()

    _ = try self.expectAuthenticated(await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect("first-grant")))
    _ = try self.expectAuthenticated(await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect("second-grant")))

    XCTAssertEqual(self.requests.callCount, 2, "A different grant is a different login and is exchanged")
    XCTAssertEqual(self.requests.lastRequest?.payloadJSON?["token"] as? String, "second-grant")
  }

  func test_handleRedirect_willReplayOnlyMostRecentGrant() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()

    _ = try self.expectAuthenticated(await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect("grant-a")))
    _ = try self.expectAuthenticated(await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect("grant-b")))
    _ = try self.expectAuthenticated(await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect("grant-a")))

    XCTAssertEqual(
      self.requests.callCount,
      3,
      "The memo is a single slot: grant B evicted grant A, so A is exchanged again rather than kept alive as a spent token"
    )
  }

  func test_handleRedirect_willNotReplay_whenTokenDiffersOnlyByCase() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()

    _ = try self.expectAuthenticated(await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect("grant-token")))
    _ = try self.expectAuthenticated(await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect("Grant-Token")))

    XCTAssertEqual(self.requests.callCount, 2, "The memo key is byte-exact: a token differing only in case is a different token")
  }

  // MARK: - Forgetting a failed exchange

  func test_handleRedirect_willForgetGrant_whenExchangeFailed400() async throws {
    let redirect = AuthTestFixtures.magicLinkRedirect()
    let failure = AuthTestFixtures.clientError(status: 400, body: "{\"error\":\"bad request\"}")
    self.requests.failWith = failure

    await XCTAssertThrowsAsync(try await self.auth.handleRedirect(redirect)) { error in
      XCTAssertEqual(error as? PortalRequestsError, failure, "The transport error reaches the host unmapped")
    }

    self.requests.failWith = nil
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    let retry = try self.expectAuthenticated(await self.auth.handleRedirect(redirect))

    XCTAssertEqual(try retry.session.getToken(), AuthTestFixtures.clientSessionToken)
    XCTAssertEqual(self.requests.callCount, 2, "Only a successful exchange is remembered, so the redirect stayed retryable")
  }

  func test_handleRedirect_willForgetGrant_whenExchangeFailedTransiently503() async throws {
    let redirect = AuthTestFixtures.magicLinkRedirect()
    self.requests.failWith = AuthTestFixtures.serverError503

    await XCTAssertThrowsAsync(try await self.auth.handleRedirect(redirect)) { error in
      XCTAssertEqual(error as? PortalRequestsError, AuthTestFixtures.serverError503)
    }

    self.requests.failWith = nil
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    _ = try self.expectAuthenticated(await self.auth.handleRedirect(redirect))

    XCTAssertEqual(self.requests.callCount, 2, "A grant lost to a transient failure is exchanged again, not written off")
  }

  func test_handleRedirect_willForgetGrant_whenExchangeRejected401() async throws {
    let redirect = AuthTestFixtures.magicLinkRedirect()
    self.requests.failWith = AuthTestFixtures.unauthorized

    await XCTAssertThrowsAsync(try await self.auth.handleRedirect(redirect)) { error in
      XCTAssertEqual(error as? PortalRequestsError, .unauthorized, "A rejected grant surfaces as the backend's own 401")
    }

    self.requests.failWith = nil
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    _ = try self.expectAuthenticated(await self.auth.handleRedirect(redirect))

    XCTAssertEqual(self.requests.callCount, 2, "A rejected exchange is not remembered")
    XCTAssertEqual(self.requests.unauthorizedHookInvocations, 0, "The auth module installs no 401 hook: there is no credential yet to invalidate")
  }

  func test_handleRedirect_willForgetGrant_whenInvalidGrantResponse() async throws {
    let redirect = AuthTestFixtures.magicLinkRedirect()
    self.requests.queuedResponses = [
      .success(AuthTestFixtures.grantResponse(clientSessionToken: nil, userJwt: nil)),
      .success(AuthTestFixtures.grantResponse())
    ]

    await XCTAssertThrowsAsync(try await self.auth.handleRedirect(redirect)) { error in
      XCTAssertEqual(error as? PortalAuthError, .invalidGrantResponse)
    }

    _ = try self.expectAuthenticated(await self.auth.handleRedirect(redirect))

    XCTAssertEqual(self.requests.callCount, 2, "A protocol error is not a completed exchange, so nothing was memoised")
  }

  // MARK: - Memo lifecycle

  func test_clearPersistedSession_willForgetMemo_soRedeliveryReExchanges() async throws {
    self.requests.queuedResponses = [
      .success(AuthTestFixtures.grantResponse(clientSessionToken: "session-token-1")),
      .success(AuthTestFixtures.grantResponse(clientSessionToken: "session-token-2"))
    ]
    let redirect = AuthTestFixtures.magicLinkRedirect()

    let first = try self.expectAuthenticated(await self.auth.handleRedirect(redirect))
    try await self.auth.clearPersistedSession()
    let second = try self.expectAuthenticated(await self.auth.handleRedirect(redirect))

    XCTAssertEqual(self.requests.callCount, 2, "A redirect re-delivered after a sign-out cannot replay the session that was just cleared")
    XCTAssertEqual(self.storage.setCalls, 2)
    XCTAssertFalse(first.session === second.session, "The second exchange produced a new session")
    XCTAssertEqual(self.storage.storedSession?.clientSessionToken, "session-token-2")
    XCTAssertEqual(try second.session.getToken(), "session-token-2")
  }

  func test_handleRedirect_willRememberPerInstance() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    // Same transport, same storage, same auth environment — only the instance differs.
    let other = AuthTestFixtures.makeAuth(requests: self.requests, storage: self.storage)
    let redirect = AuthTestFixtures.magicLinkRedirect()

    _ = try self.expectAuthenticated(await self.auth.handleRedirect(redirect))
    _ = try self.expectAuthenticated(await other.handleRedirect(redirect))

    XCTAssertEqual(
      self.requests.callCount,
      2,
      "The memo lives on the instance, which is why the host must hold one long-lived PortalAuth"
    )
  }

  func test_handleRedirect_willKeepMemo_acrossRestoreSession() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    let redirect = AuthTestFixtures.magicLinkRedirect()

    let first = try self.expectAuthenticated(await self.auth.handleRedirect(redirect))
    let restored = try await self.auth.restoreSession()
    let replay = try self.expectAuthenticated(await self.auth.handleRedirect(redirect))

    XCTAssertNotNil(restored, "The login persisted a session for restoreSession() to find")
    XCTAssertEqual(self.requests.callCount, 1, "restoreSession() is a read and does not touch the memo")
    XCTAssertTrue(replay.session === first.session, "The replay is still the session the exchange produced")
  }

  // MARK: - Overloads

  func test_handleRedirectURL_willReplayStringLogin_withinTimeout() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    let auth = self.auth
    let first = try self.expectAuthenticated(await auth.handleRedirect(AuthTestFixtures.magicLinkRedirect()))
    let url = try AuthTestFixtures.url(AuthTestFixtures.magicLinkRedirect())
    let box = ResultBox()

    // Both overloads forward into one locked body; a re-entrant lock regression would deadlock
    // here, so it is bounded and fails as a timeout rather than hanging the suite.
    let completed = try await AuthTestFixtures.withTimeout(2) { () -> Bool in
      try box.store(await auth.handleRedirect(url))
      return true
    }

    XCTAssertEqual(completed, true, "The URL overload completed; it is a non-locking forwarder")
    let replay = try self.expectAuthenticated(box.result)
    XCTAssertTrue(replay.session === first.session)
    XCTAssertEqual(self.requests.callCount, 1)
  }

  func test_handleRedirectURL_willCompleteTwice_withinTimeout() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    let auth = self.auth
    let firstUrl = try AuthTestFixtures.url(AuthTestFixtures.magicLinkRedirect("grant-a"))
    let secondUrl = try AuthTestFixtures.url(AuthTestFixtures.magicLinkRedirect("grant-b"))
    let firstBox = ResultBox()
    let secondBox = ResultBox()

    let firstCompleted = try await AuthTestFixtures.withTimeout(2) { () -> Bool in
      try firstBox.store(await auth.handleRedirect(firstUrl))
      return true
    }
    let secondCompleted = try await AuthTestFixtures.withTimeout(2) { () -> Bool in
      try secondBox.store(await auth.handleRedirect(secondUrl))
      return true
    }

    XCTAssertEqual(firstCompleted, true)
    XCTAssertEqual(secondCompleted, true, "The lock was released by the first call, so a second one is not blocked")
    _ = try self.expectAuthenticated(firstBox.result)
    _ = try self.expectAuthenticated(secondBox.result)
    XCTAssertEqual(self.requests.callCount, 2)
  }

  // MARK: - Concurrency

  func test_handleRedirect_willCollapseTwoConcurrentDeliveriesIntoOneExchange() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    self.requests.gateFirstRequest = true
    let auth = self.auth
    let requests = self.requests
    let redirect = AuthTestFixtures.magicLinkRedirect()
    let firstBox = ResultBox()
    let secondBox = ResultBox()

    let first = Task<Void, Error> {
      try firstBox.store(await auth.handleRedirect(redirect))
    }
    let didArrive = await requests.waitUntilArrived()
    XCTAssertTrue(didArrive, "The first delivery reached the transport")

    let second = Task<Void, Error> {
      try secondBox.store(await auth.handleRedirect(redirect))
    }
    let didPark = await AuthTestFixtures.pollUntil { auth.grantMutex.isContended }
    XCTAssertTrue(didPark, "The second delivery parked on the grant mutex instead of starting its own exchange")

    requests.release()
    try await first.value
    try await second.value

    let firstResult = try self.expectAuthenticated(firstBox.result)
    let secondResult = try self.expectAuthenticated(secondBox.result)
    XCTAssertTrue(firstResult.session === secondResult.session, "Both deliveries resolved to the one session")
    XCTAssertEqual(requests.callCount, 1, "One grant, one exchange")
    XCTAssertEqual(self.storage.setCalls, 1)
  }

  func test_clearPersistedSession_willWaitForInFlightLogin_thenClear() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    self.requests.gateFirstRequest = true
    let auth = self.auth
    let requests = self.requests
    let deleteAttempted = Flag()
    self.storage.onDeleteAttempted = { deleteAttempted.set() }
    let box = ResultBox()

    let login = Task<Void, Error> {
      try box.store(await auth.handleRedirect(AuthTestFixtures.magicLinkRedirect()))
    }
    let didArrive = await requests.waitUntilArrived()
    XCTAssertTrue(didArrive, "The login reached the transport")

    let signOut = Task<Void, Error> {
      try await auth.clearPersistedSession()
    }
    let didPark = await AuthTestFixtures.pollUntil { auth.grantMutex.isContended }
    XCTAssertTrue(didPark, "The sign-out parked behind the login")

    let deletedEarly = await AuthTestFixtures.pollUntil(timeout: 0.5) { deleteAttempted.isSet }
    XCTAssertFalse(deletedEarly, "The sign-out did not delete while the login was still in flight")

    requests.release()
    try await login.value
    try await signOut.value

    XCTAssertEqual(self.storage.events, [.set, .delete], "The login persisted first; the sign-out cleared afterwards")
    XCTAssertEqual(self.storage.setCalls, 1)
    XCTAssertEqual(self.storage.deleteCalls, 1)
    XCTAssertNil(self.storage.stored, "No login could write a session back in after the delete")
    let restored = try await auth.restoreSession()
    XCTAssertNil(restored, "The user is signed out")
  }

  func test_handleRedirect_willRunOauthAndMagicLinkConcurrently_withoutCrossTalk() async throws {
    self.requests.responder = { request in
      if request.matches(path: PortalAuthApi.oauthTokensPath) {
        return AuthTestFixtures.grantResponse(clientSessionToken: "oauth-session-token", endUserId: "user-oauth")
      }
      if request.matches(path: PortalAuthApi.magicLinkValidationsPath) {
        return AuthTestFixtures.grantResponse(clientSessionToken: "magic-link-session-token", endUserId: "user-magic")
      }
      XCTFail("An unexpected endpoint was called: \(request.path)")
      return Data()
    }
    let auth = self.auth
    let oauthRedirect = AuthTestFixtures.oauthRedirect("oauth-grant")
    let magicLinkRedirect = AuthTestFixtures.magicLinkRedirect("magic-link-grant")
    let oauthBox = ResultBox()
    let magicLinkBox = ResultBox()

    let oauth = Task<Void, Error> {
      try oauthBox.store(await auth.handleRedirect(oauthRedirect))
    }
    let magicLink = Task<Void, Error> {
      try magicLinkBox.store(await auth.handleRedirect(magicLinkRedirect))
    }
    try await oauth.value
    try await magicLink.value

    let oauthResult = try self.expectAuthenticated(oauthBox.result)
    let magicLinkResult = try self.expectAuthenticated(magicLinkBox.result)
    XCTAssertEqual(try oauthResult.session.getToken(), "oauth-session-token", "The OAuth delivery kept its own endpoint's session")
    XCTAssertEqual(try magicLinkResult.session.getToken(), "magic-link-session-token")
    XCTAssertEqual(oauthResult.session.endUserId, "user-oauth")
    XCTAssertEqual(magicLinkResult.session.endUserId, "user-magic")
    XCTAssertEqual(self.requests.callCount, 2)
    XCTAssertEqual(self.requests.maxInFlight, 1, "The two exchanges were serialised under the grant mutex")
  }

  func test_handleRedirect_willSerialiseConcurrentDifferentGrants() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    self.requests.gateFirstRequest = true
    let auth = self.auth
    let requests = self.requests
    let firstBox = ResultBox()
    let secondBox = ResultBox()

    let first = Task<Void, Error> {
      try firstBox.store(await auth.handleRedirect(AuthTestFixtures.magicLinkRedirect("grant-a")))
    }
    let didArrive = await requests.waitUntilArrived()
    XCTAssertTrue(didArrive, "The first exchange reached the transport")

    let second = Task<Void, Error> {
      try secondBox.store(await auth.handleRedirect(AuthTestFixtures.magicLinkRedirect("grant-b")))
    }
    let didPark = await AuthTestFixtures.pollUntil { auth.grantMutex.isContended }
    XCTAssertTrue(didPark, "The second grant parked on the mutex")
    XCTAssertEqual(requests.callCount, 1, "The lock spans the exchange and the persist, so the second request has not been sent")

    requests.release()
    try await first.value
    try await second.value

    _ = try self.expectAuthenticated(firstBox.result)
    _ = try self.expectAuthenticated(secondBox.result)
    XCTAssertEqual(requests.callCount, 2, "The second request was sent only after the first released the lock")
    XCTAssertEqual(requests.maxInFlight, 1)
  }

  func test_verifyTotp_willWaitForInFlightRedirect_thenAdvanceMemo() async throws {
    let userJwt = AuthTestFixtures.userJwt()
    self.requests.queuedResponses = [
      .success(AuthTestFixtures.grantResponse(clientSessionToken: nil, userJwt: userJwt)),
      .success(AuthTestFixtures.totpResponse())
    ]
    self.requests.gateFirstRequest = true
    let auth = self.auth
    let requests = self.requests
    let redirect = AuthTestFixtures.magicLinkRedirect()
    let stepBox = ResultBox()
    let verifiedBox = AuthenticatedBox()

    let exchange = Task<Void, Error> {
      try stepBox.store(await auth.handleRedirect(redirect))
    }
    let didArrive = await requests.waitUntilArrived()
    XCTAssertTrue(didArrive, "The grant exchange reached the transport")

    let verify = Task<Void, Error> {
      try verifiedBox.store(await auth.verifyTotp("777870", userJwt: userJwt))
    }
    let didPark = await AuthTestFixtures.pollUntil { auth.grantMutex.isContended }
    XCTAssertTrue(didPark, "verifyTotp parked behind the in-flight redirect")

    requests.release()
    try await exchange.value
    try await verify.value

    XCTAssertEqual(
      requests.requestedPaths,
      [PortalAuthApi.magicLinkValidationsPath, PortalAuthApi.totpValidationsPath],
      "The TOTP validation was sent only after the exchange that produced the step"
    )
    _ = try self.expectTotpRequired(stepBox.result)
    guard let verified = verifiedBox.result else {
      return XCTFail("verifyTotp produced no result")
    }

    let replay = try self.expectAuthenticated(await auth.handleRedirect(redirect))
    XCTAssertTrue(replay.session === verified.session, "The memo advanced to the verified session")
    XCTAssertEqual(requests.callCount, 2, "The redelivery replayed and cost no request")
  }

  func test_handleRedirect_willReleaseLock_whenExchangeThrows() async throws {
    let auth = self.auth
    let redirect = AuthTestFixtures.magicLinkRedirect()
    self.requests.failWith = AuthTestFixtures.serverError503

    await XCTAssertThrowsAsync(try await auth.handleRedirect(redirect)) { error in
      XCTAssertEqual(error as? PortalRequestsError, AuthTestFixtures.serverError503)
    }

    self.requests.failWith = nil
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    let box = ResultBox()
    let completed = try await AuthTestFixtures.withTimeout(2) { () -> Bool in
      try box.store(await auth.handleRedirect(redirect))
      return true
    }

    XCTAssertEqual(completed, true, "A throwing exchange released the lock; the retry is not deadlocked behind it")
    _ = try self.expectAuthenticated(box.result)
    XCTAssertEqual(self.requests.callCount, 2)
  }

  func test_handleRedirect_willReleaseLock_whenPersistThrows() async throws {
    let auth = self.auth
    let redirect = AuthTestFixtures.magicLinkRedirect()
    let setCalls = CallCounter()
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    self.storage.onSet = { _ in
      if setCalls.next() == 1 {
        throw KeychainFault()
      }
    }

    await XCTAssertThrowsAsync(try await auth.handleRedirect(redirect)) { error in
      XCTAssertEqual(
        error as? PortalAuthError,
        .sessionStorageFailure(message: "The session could not be persisted."),
        "A failed persist rejects the login"
      )
    }

    let box = ResultBox()
    let completed = try await AuthTestFixtures.withTimeout(2) { () -> Bool in
      try box.store(await auth.handleRedirect(redirect))
      return true
    }

    XCTAssertEqual(completed, true, "A throwing persist released the lock too")
    _ = try self.expectAuthenticated(box.result)
    XCTAssertEqual(self.storage.setCalls, 2, "The second delivery re-exchanged and persisted, because the failed one was never memoised")
  }

  func test_handleRedirect_willCompleteExchange_whenCallerCancelled() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    self.requests.gateFirstRequest = true
    let auth = self.auth
    let requests = self.requests
    let redirect = AuthTestFixtures.magicLinkRedirect()
    let box = ResultBox()

    let cancelled = Task<Void, Error> {
      try box.store(await auth.handleRedirect(redirect))
    }
    let didArrive = await requests.waitUntilArrived()
    XCTAssertTrue(didArrive, "The exchange reached the transport")

    // The grant is already spent at the backend by this point, so abandoning the exchange would
    // strand the user with a session that exists everywhere except on this device. The transport
    // double aborts a parked request on cancellation exactly as `URLSession` would, so this only
    // passes if the exchange runs shielded from the caller's cancellation.
    cancelled.cancel()
    requests.release()
    try await cancelled.value

    XCTAssertEqual(requests.callCount, 1)
    XCTAssertEqual(self.storage.setCalls, 1, "The cancelled call still finished exchanging and persisting")
    let first = try self.expectAuthenticated(box.result)

    let followUpBox = ResultBox()
    let completed = try await AuthTestFixtures.withTimeout(2) { () -> Bool in
      try followUpBox.store(await auth.handleRedirect(redirect))
      return true
    }

    XCTAssertEqual(completed, true, "The cancelled call released the lock on its way out")
    let followUp = try self.expectAuthenticated(followUpBox.result)
    XCTAssertTrue(followUp.session === first.session, "The follow-up replayed the memo the cancelled call recorded")
    XCTAssertEqual(requests.callCount, 1, "The follow-up cost no request")
  }

  func test_handleRedirect_willNotExchange_whenCalledFromAnAlreadyCancelledTask() async throws {
    // Shielding starts only once the exchange has begun. A caller that is cancelled before it
    // asks must not spend the single-use grant on a login nobody is waiting for.
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    let auth = self.auth
    let redirect = AuthTestFixtures.magicLinkRedirect()

    let task = Task<AuthResult?, Error> {
      withUnsafeCurrentTask { $0?.cancel() }
      return try await auth.handleRedirect(redirect)
    }

    await XCTAssertThrowsAsync(try await task.value) { error in
      XCTAssertTrue(error is CancellationError, "Expected CancellationError, got \(type(of: error))")
    }
    XCTAssertEqual(self.requests.callCount, 0, "Nothing is sent for a caller that is already gone")
    XCTAssertEqual(self.storage.setCalls, 0)
  }

  func test_verifyTotp_willCompleteVerification_whenCallerCancelled() async throws {
    // The TOTP endpoint retires the userJwt before it answers, so an aborted verification would
    // strand the issued session just like an aborted grant exchange.
    self.requests.defaultResponse = AuthTestFixtures.totpResponse(clientSessionToken: "totp-session-token")
    self.requests.gateFirstRequest = true
    let auth = self.auth
    let requests = self.requests
    let userJwt = AuthTestFixtures.userJwt()
    let box = ResultBox()

    let cancelled = Task<Void, Error> {
      box.store(.authenticated(try await auth.verifyTotp("777870", userJwt: userJwt)))
    }
    let didArrive = await requests.waitUntilArrived()
    XCTAssertTrue(didArrive, "The verification reached the transport")

    cancelled.cancel()
    requests.release()
    try await cancelled.value

    XCTAssertEqual(requests.callCount, 1)
    XCTAssertEqual(self.storage.setCalls, 1, "The cancelled call still finished verifying and persisting")
    let result = try self.expectAuthenticated(box.result)
    XCTAssertEqual(try result.session.getToken(), "totp-session-token")
  }

  func test_verifyTotp_willNotSend_whenCalledFromAnAlreadyCancelledTask() async throws {
    self.requests.defaultResponse = AuthTestFixtures.totpResponse()
    let auth = self.auth
    let userJwt = AuthTestFixtures.userJwt()

    let task = Task<AuthenticatedResult, Error> {
      withUnsafeCurrentTask { $0?.cancel() }
      return try await auth.verifyTotp("777870", userJwt: userJwt)
    }

    await XCTAssertThrowsAsync(try await task.value) { error in
      XCTAssertTrue(error is CancellationError, "Expected CancellationError, got \(type(of: error))")
    }
    XCTAssertEqual(self.requests.callCount, 0, "A code is never spent for a caller that is already gone")
  }

  func test_handleRedirect_willBeIdempotent_underTenConcurrentDeliveries() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    self.requests.gateFirstRequest = true
    let auth = self.auth
    let requests = self.requests
    let redirect = AuthTestFixtures.magicLinkRedirect()

    var boxes: [ResultBox] = []
    var deliveries: [Task<Void, Error>] = []
    for _ in 0 ..< 10 {
      let box = ResultBox()
      boxes.append(box)
      deliveries.append(Task<Void, Error> {
        try box.store(await auth.handleRedirect(redirect))
      })
    }

    let didArrive = await requests.waitUntilArrived()
    XCTAssertTrue(didArrive, "One delivery reached the transport")
    let didPark = await AuthTestFixtures.pollUntil { auth.grantMutex.waiterCount == 9 }
    XCTAssertTrue(didPark, "The other nine deliveries parked on the grant mutex")

    requests.release()
    for delivery in deliveries {
      try await delivery.value
    }

    XCTAssertEqual(requests.callCount, 1, "Ten deliveries of one grant cost one exchange")
    XCTAssertEqual(self.storage.setCalls, 1)
    let sessions = try boxes.map { try self.expectAuthenticated($0.result).session }
    guard let expected = sessions.first else {
      return XCTFail("No delivery produced a session")
    }
    for session in sessions {
      XCTAssertTrue(session === expected, "Every delivery resolved to the same session instance")
    }
  }

  // MARK: - Helpers

  /// Unwraps an `.authenticated` result, failing the case (and stopping it) on anything else.
  /// `AuthResult` is not `Equatable` — its session is a class-backed existential compared with
  /// `===` — so every case unwraps rather than asserting on the enum itself.
  private func expectAuthenticated(
    _ result: AuthResult?,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws -> AuthenticatedResult {
    guard case let .authenticated(authenticated)? = result else {
      XCTFail("Expected an .authenticated result but got \(Self.describe(result)).", file: file, line: line)
      throw ReplayTestError.unexpectedResult(Self.describe(result))
    }
    return authenticated
  }

  /// Unwraps a `.totpRequired` result. `TotpRequiredResult` *is* `Equatable`, so the step cases
  /// compare the whole value.
  private func expectTotpRequired(
    _ result: AuthResult?,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws -> TotpRequiredResult {
    guard case let .totpRequired(step)? = result else {
      XCTFail("Expected a .totpRequired result but got \(Self.describe(result)).", file: file, line: line)
      throw ReplayTestError.unexpectedResult(Self.describe(result))
    }
    return step
  }

  /// Names a result for a failure message without printing anything it carries — a session
  /// token, a `userJwt` or a `totpLink` must never reach the test log either.
  private static func describe(_ result: AuthResult?) -> String {
    switch result {
    case .none:
      return "nil"
    case .authenticated:
      return ".authenticated"
    case .totpRequired:
      return ".totpRequired"
    }
  }
}
