//
//  PortalAuthMagicLinkTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

/// Covers the two-step magic link: `getMagicLinkDetails(_:)` reads the email a link signs in to
/// without spending it, and `confirmMagicLink(_:)` exchanges it once the user confirms.
///
/// The details call holds no lock and remembers nothing; a rejected link is `grantRejected`.
/// The confirmation shares the redirect machinery with the rest of `PortalAuth` — one grant
/// mutex, one remembered result keyed by sign-in kind and token, an exchange shielded from the
/// caller's cancellation — so the cases below pin each of those for this entry point: what is
/// sent, what is remembered and replayed, what stays retryable, what a sign-out does to a
/// confirmation in flight, and that no token, session token or email reaches a log.
final class PortalAuthMagicLinkTests: XCTestCase {
  private static let token = AuthTestFixtures.grantToken
  private static let email = AuthTestFixtures.magicLinkEmail
  private static let grantRejectedText =
    "[PortalAuth] The authentication grant was rejected. It may already have been used, expired, or been issued for a different auth environment. Start a new sign-in."

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

  // MARK: - Helpers

  /// Answers the details call with the fixture email and every grant exchange with a session.
  private func installMagicLinkResponder(clientSessionToken: String = AuthTestFixtures.clientSessionToken) {
    self.requests.responder = { request in
      if request.matches(path: PortalAuthApi.magicLinkDetailsPath) {
        return AuthTestFixtures.magicLinkDetailsResponse()
      }
      if request.matches(path: PortalAuthApi.totpValidationsPath) {
        return AuthTestFixtures.totpResponse()
      }
      return AuthTestFixtures.grantResponse(clientSessionToken: clientSessionToken)
    }
  }

  private var paths: [String] {
    self.requests.recorded.map { $0.path }
  }

  // MARK: - getMagicLinkDetails

  func test_getMagicLinkDetails_willReturnEmail_withoutSpendingOrPersisting() async throws {
    self.requests.enqueue(AuthTestFixtures.magicLinkDetailsResponse(email: Self.email))

    let details = try await self.auth.getMagicLinkDetails(Self.token)

    XCTAssertEqual(details, MagicLinkDetails(email: Self.email))
    XCTAssertEqual(self.paths, [PortalAuthApi.magicLinkDetailsPath])
    XCTAssertEqual(self.requests.lastRequest?.bearerToken, Self.token)
    XCTAssertEqual(self.requests.lastRequest?.method, .get)
    XCTAssertEqual(self.storage.setCalls, 0)
    XCTAssertEqual(self.storage.deleteCalls, 0)
  }

  func test_getMagicLinkDetails_willLeaveTheLinkConfirmable() async throws {
    self.installMagicLinkResponder()

    _ = try await self.auth.getMagicLinkDetails(Self.token)
    _ = try await self.auth.getMagicLinkDetails(Self.token)
    let result = try expectAuthenticatedResult(await self.auth.confirmMagicLink(Self.token))

    // Each lookup is its own request — nothing is remembered — and neither used up the link.
    XCTAssertEqual(self.paths, [PortalAuthApi.magicLinkDetailsPath, PortalAuthApi.magicLinkDetailsPath, PortalAuthApi.magicLinkValidationsPath])
    XCTAssertEqual(try result.session.getToken(), AuthTestFixtures.clientSessionToken)
  }

  func test_getMagicLinkDetails_willThrowGrantRejected_when401() async {
    self.requests.failWith = PortalRequestsError.unauthorized

    let thrown = await XCTAssertThrowsAsync(
      try await self.auth.getMagicLinkDetails(Self.token),
      expected: PortalAuthError.grantRejected
    )

    XCTAssertEqual((thrown as? PortalAuthError)?.errorDescription, Self.grantRejectedText)
    XCTAssertEqual(self.requests.unauthorizedHookInvocations, 0, "The grant's 401 must not invalidate any credential")
  }

  func test_getMagicLinkDetails_willPassThrough429And5xxAndURLError() async {
    // A 429 means the link was looked up too many times. It is not `grantRejected` (Android,
    // React Native and Web pass it through too), and it is never a reason to confirm without
    // showing the email.
    let tooMany = AuthTestFixtures.clientError(status: 429, body: "{\"error\":\"Too many requests\"}", url: AuthTestFixtures.apiBase + "/magic-links/details")
    self.requests.failWith = tooMany
    await XCTAssertThrowsAsync(try await self.auth.getMagicLinkDetails(Self.token), expected: tooMany)

    let serverError = AuthTestFixtures.serverError503
    self.requests.failWith = serverError
    await XCTAssertThrowsAsync(try await self.auth.getMagicLinkDetails(Self.token), expected: serverError)

    let offline = URLError(.notConnectedToInternet)
    self.requests.failWith = offline
    await XCTAssertThrowsAsync(try await self.auth.getMagicLinkDetails(Self.token), expected: offline)
  }

  func test_getMagicLinkDetails_willThrowInvalidArgument_withoutRequest_whenTokenBlank() async {
    for token in ["", " ", "\n\t"] {
      await XCTAssertThrowsAsync(
        try await self.auth.getMagicLinkDetails(token),
        expected: PortalAuthError.invalidArgument(name: "token")
      )
    }

    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_getMagicLinkDetails_willThrowGrantRejected_withoutRequest_whenTokenCannotBeABearer() async {
    // The details call is the only place a grant goes into a header. Portal's grants are JWTs,
    // so a token outside the bearer alphabet did not come from Portal, and it is refused before
    // it can reach a header — a CR/LF must never be able to start a header of its own.
    for token in ["a\r\nX-Injected: 1", "a b", "jwt\u{0}", "токен", "a\tb", "a,b", "a\"b"] {
      await XCTAssertThrowsAsync(
        try await self.auth.getMagicLinkDetails(token),
        expected: PortalAuthError.grantRejected,
        "\(token.debugDescription) was not refused"
      )
    }

    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_getMagicLinkDetails_willAcceptEveryBearerCharacter() async throws {
    // RFC 6750 `b64token`: letters, digits, `-._~+/` and trailing `=`. A JWT uses a subset.
    self.requests.defaultResponse = AuthTestFixtures.magicLinkDetailsResponse()
    let token = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.sig-_~+/Az09=="

    _ = try await self.auth.getMagicLinkDetails(token)

    XCTAssertEqual(self.requests.lastRequest?.bearerToken, token)
  }

  func test_getMagicLinkDetails_willThrowMalformedResponse_whenEmailMissing() async {
    self.requests.enqueue(AuthTestFixtures.magicLinkDetailsResponse(email: nil))

    await XCTAssertThrowsAsync(
      try await self.auth.getMagicLinkDetails(Self.token),
      expected: PortalAuthError.malformedResponse(path: PortalAuthApi.magicLinkDetailsPath, missing: "email")
    )
  }

  func test_getMagicLinkDetails_willAskPortal_aboutALinkAlreadyConfirmed() async throws {
    // A confirmed link is spent, and the lookup never answers from memory: it asks Portal, which
    // rejects it. A host that sees the same link again after confirming it goes straight to
    // `confirmMagicLink(_:)` instead, which replays.
    self.installMagicLinkResponder()
    _ = try expectAuthenticatedResult(await self.auth.confirmMagicLink(Self.token))
    self.requests.fail(with: PortalRequestsError.unauthorized, onPath: PortalAuthApi.magicLinkDetailsPath)

    await XCTAssertThrowsAsync(try await self.auth.getMagicLinkDetails(Self.token), expected: PortalAuthError.grantRejected)
    let replay = try expectAuthenticatedResult(await self.auth.confirmMagicLink(Self.token))

    XCTAssertEqual(self.paths, [PortalAuthApi.magicLinkValidationsPath, PortalAuthApi.magicLinkDetailsPath])
    XCTAssertEqual(try replay.session.getToken(), AuthTestFixtures.clientSessionToken)
  }

  func test_getMagicLinkDetails_willNotWaitOnGrantMutex() async throws {
    // The lookup takes no lock, so it is never queued behind a confirmation in flight.
    self.installMagicLinkResponder()
    self.requests.gateFirstRequest = true
    let auth = self.auth
    let requests = self.requests

    let confirmation = Task<AuthResult, Error> { try await auth.confirmMagicLink("other-grant") }
    let didArrive = await requests.waitUntilArrived()
    XCTAssertTrue(didArrive, "The confirmation reached the transport")

    let details = try await AuthTestFixtures.withTimeout(2) { try await auth.getMagicLinkDetails(Self.token) }
    XCTAssertEqual(details?.email, Self.email, "The lookup completed while the confirmation still held the lock")

    requests.release()
    _ = try await confirmation.value
  }

  func test_getMagicLinkDetails_willNotSend_whenCalledFromAnAlreadyCancelledTask() async {
    // Lookups are limited per link, so a caller that is already gone must not spend one.
    self.requests.defaultResponse = AuthTestFixtures.magicLinkDetailsResponse()
    let auth = self.auth

    let task = Task<MagicLinkDetails, Error> {
      withUnsafeCurrentTask { $0?.cancel() }
      return try await auth.getMagicLinkDetails(Self.token)
    }

    await XCTAssertThrowsAsync(try await task.value) { error in
      XCTAssertTrue(error is CancellationError, "Expected CancellationError, got \(type(of: error))")
    }
    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_getMagicLinkDetails_willNotLogTokenOrEmail() async throws {
    self.requests.enqueue(AuthTestFixtures.magicLinkDetailsResponse(email: "secret-user@example.com"))
    _ = try await self.auth.getMagicLinkDetails("secret-grant")
    self.requests.failWith = PortalRequestsError.unauthorized
    await XCTAssertThrowsAsync(try await self.auth.getMagicLinkDetails("secret-grant"))

    self.logger.assertNoSecret("secret-grant")
    self.logger.assertNoSecret("secret-user@example.com")
  }

  func test_getMagicLinkDetails_willNotPutTokenOrEmailInErrorMessages() async {
    let token = "secret-grant"
    let failures: [Data] = [
      AuthTestFixtures.magicLinkDetailsResponse(email: nil),
      Data("{\"email\":\"secret-user@example.com\"}".utf8)
    ]

    for body in failures {
      self.requests.enqueue(body)
      await XCTAssertThrowsAsync(try await self.auth.getMagicLinkDetails(token)) { error in
        let message = error.localizedDescription
        XCTAssertFalse(message.contains(token))
        XCTAssertFalse(message.contains("secret-user@example.com"))
      }
    }
  }

  // MARK: - confirmMagicLink: the exchange

  func test_confirmMagicLink_willExchangeAtMagicLinkValidations_andPersist() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()

    let result = try expectAuthenticatedResult(await self.auth.confirmMagicLink(Self.token))

    let request = try XCTUnwrap(self.requests.lastRequest)
    XCTAssertEqual(request.absoluteString, AuthTestFixtures.apiBase + "/magic-links/validations")
    XCTAssertEqual(request.method, .post)
    XCTAssertNil(request.bearerToken, "The confirmation posts the grant in the body, exactly as before")
    let payload = try XCTUnwrap(request.payloadJSON)
    XCTAssertEqual(payload.count, 1)
    XCTAssertEqual(payload["token"] as? String, Self.token)

    XCTAssertEqual(try result.session.getToken(), AuthTestFixtures.clientSessionToken)
    XCTAssertEqual(result.session.endUserId, AuthTestFixtures.endUserId)
    XCTAssertEqual(self.storage.storedSession, PersistedSession(clientSessionToken: AuthTestFixtures.clientSessionToken, endUserId: AuthTestFixtures.endUserId))
  }

  func test_confirmMagicLink_willNotRequireDetailsFirst() async throws {
    // Portal does not require a lookup before the exchange, and neither does the SDK: calling
    // the lookup first is the documented contract, not an enforced one.
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()

    _ = try expectAuthenticatedResult(await self.auth.confirmMagicLink(Self.token))

    XCTAssertEqual(self.paths, [PortalAuthApi.magicLinkValidationsPath])
  }

  func test_confirmMagicLink_willReturnTotpRequired_persistingNothing() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse(clientSessionToken: nil, userJwt: AuthTestFixtures.userJwt())

    let step = try expectTotpRequiredResult(await self.auth.confirmMagicLink(Self.token))

    XCTAssertEqual(step.userJwt, AuthTestFixtures.userJwt())
    XCTAssertEqual(self.storage.setCalls, 0)
  }

  func test_confirmMagicLink_willThrowGrantRejected_when401_persistingNothing() async {
    self.requests.failWith = PortalRequestsError.unauthorized

    let thrown = await XCTAssertThrowsAsync(try await self.auth.confirmMagicLink(Self.token), expected: PortalAuthError.grantRejected)

    XCTAssertEqual((thrown as? PortalAuthError)?.errorDescription, Self.grantRejectedText)
    XCTAssertEqual(self.storage.setCalls, 0)
    XCTAssertEqual(self.requests.unauthorizedHookInvocations, 0)
  }

  func test_confirmMagicLink_willThrowInvalidArgument_withoutRequest_whenTokenBlank() async {
    for token in ["", " ", "\n\t"] {
      await XCTAssertThrowsAsync(try await self.auth.confirmMagicLink(token), expected: PortalAuthError.invalidArgument(name: "token"))
    }

    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_confirmMagicLink_willPassThrough400And5xxAndURLError_unmapped() async {
    let badRequest = AuthTestFixtures.clientError(status: 400, body: "{\"error\":\"x\"}", url: AuthTestFixtures.apiBase + "/magic-links/validations")
    self.requests.failWith = badRequest
    await XCTAssertThrowsAsync(try await self.auth.confirmMagicLink(Self.token), expected: badRequest)

    let serverError = AuthTestFixtures.serverError503
    self.requests.failWith = serverError
    await XCTAssertThrowsAsync(try await self.auth.confirmMagicLink(Self.token), expected: serverError)

    let offline = URLError(.networkConnectionLost)
    self.requests.failWith = offline
    await XCTAssertThrowsAsync(try await self.auth.confirmMagicLink(Self.token), expected: offline)
  }

  func test_confirmMagicLink_willThrowInvalidGrantResponse_whenNeitherSessionNorJwt() async {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse(clientSessionToken: nil, userJwt: nil)

    await XCTAssertThrowsAsync(try await self.auth.confirmMagicLink(Self.token), expected: PortalAuthError.invalidGrantResponse)
  }

  // MARK: - confirmMagicLink: replay and retry

  func test_confirmMagicLink_willReplayASecondConfirmation_withSameSessionInstance() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()

    let first = try expectAuthenticatedResult(await self.auth.confirmMagicLink(Self.token))
    let second = try expectAuthenticatedResult(await self.auth.confirmMagicLink(Self.token))

    XCTAssertTrue(first.session === second.session, "A repeated confirmation hands back the session the first one produced")
    XCTAssertEqual(self.requests.callCount, 1, "The link was exchanged once")
    XCTAssertEqual(self.storage.setCalls, 1)
  }

  func test_confirmMagicLink_willStayRetryable_whenExchangeFailed503() async throws {
    // A failure is never remembered: calling again sends the link again.
    self.requests.enqueue(failure: AuthTestFixtures.serverError503)
    self.requests.enqueue(AuthTestFixtures.grantResponse())

    await XCTAssertThrowsAsync(try await self.auth.confirmMagicLink(Self.token), expected: AuthTestFixtures.serverError503)
    _ = try expectAuthenticatedResult(await self.auth.confirmMagicLink(Self.token))

    XCTAssertEqual(self.requests.callCount, 2)
  }

  func test_confirmMagicLink_willStayRetryable_whenRejected401() async throws {
    self.requests.enqueue(failure: PortalRequestsError.unauthorized)
    self.requests.enqueue(AuthTestFixtures.grantResponse())

    await XCTAssertThrowsAsync(try await self.auth.confirmMagicLink(Self.token), expected: PortalAuthError.grantRejected)
    _ = try expectAuthenticatedResult(await self.auth.confirmMagicLink(Self.token))

    XCTAssertEqual(self.requests.callCount, 2, "A rejection is not remembered as a rejection either")
  }

  func test_confirmMagicLink_willThrowGrantRejected_withoutRequest_whenRememberedSessionInvalidated() async throws {
    // After the session ends (here through the credential itself, as `portal.clearSession()`
    // does), a repeated confirmation must not hand it back: the link is spent, so it is rejected.
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    let first = try expectAuthenticatedResult(await self.auth.confirmMagicLink(Self.token))
    try first.session.invalidate()

    await XCTAssertThrowsAsync(try await self.auth.confirmMagicLink(Self.token), expected: PortalAuthError.grantRejected)

    XCTAssertEqual(self.requests.callCount, 1, "The invalidated memo is refused without a request")
  }

  func test_confirmMagicLink_willRetryThePersist_notTheRequest_whenPersistFailed() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    let counter = AuthCallCounter()
    self.storage.onSet = { _ in
      if counter.next() == 1 {
        throw AuthTestKeychainFault()
      }
    }

    await XCTAssertThrowsAsync(try await self.auth.confirmMagicLink(Self.token)) { error in
      guard case .sessionStorageFailure? = error as? PortalAuthError else {
        return XCTFail("Expected sessionStorageFailure, got \(type(of: error))")
      }
    }
    let retried = try expectAuthenticatedResult(await self.auth.confirmMagicLink(Self.token))

    XCTAssertEqual(self.requests.callCount, 1, "The spent link was not sent again")
    XCTAssertEqual(self.storage.setCalls, 2, "The retry finished the write")
    XCTAssertEqual(try retried.session.getToken(), AuthTestFixtures.clientSessionToken)
  }

  func test_confirmMagicLink_willReplayAuthenticated_afterVerifyTotpAdvancedStep() async throws {
    self.requests.responder = { request in
      if request.matches(path: PortalAuthApi.totpValidationsPath) {
        return AuthTestFixtures.totpResponse()
      }
      return AuthTestFixtures.grantResponse(clientSessionToken: nil, userJwt: AuthTestFixtures.userJwt())
    }

    let step = try expectTotpRequiredResult(await self.auth.confirmMagicLink(Self.token))
    let verified = try await self.auth.verifyTotp("777870", userJwt: step.userJwt)
    let replay = try expectAuthenticatedResult(await self.auth.confirmMagicLink(Self.token))

    XCTAssertTrue(replay.session === verified.session, "Once the code is accepted, the link replays as the session")
    XCTAssertEqual(self.paths, [PortalAuthApi.magicLinkValidationsPath, PortalAuthApi.totpValidationsPath])
  }

  func test_confirmMagicLink_willSendTheLinkAgain_afterClearPersistedSession() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse())
    _ = try expectAuthenticatedResult(await self.auth.confirmMagicLink(Self.token))

    try await self.auth.clearPersistedSession()
    // Portal spent the link on the first exchange, so the repeat is rejected — not replayed.
    self.requests.failWith = PortalRequestsError.unauthorized
    await XCTAssertThrowsAsync(try await self.auth.confirmMagicLink(Self.token), expected: PortalAuthError.grantRejected)

    XCTAssertEqual(self.requests.callCount, 2)
  }

  // MARK: - confirmMagicLink: memory shared by kind

  func test_confirmMagicLink_willShareMemoryWithHandleRedirect() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()

    let viaRedirect = try expectAuthenticatedResult(await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect(Self.token)))
    let viaConfirm = try expectAuthenticatedResult(await self.auth.confirmMagicLink(Self.token))

    XCTAssertTrue(viaRedirect.session === viaConfirm.session)
    XCTAssertEqual(self.requests.callCount, 1)

    let other = AuthTestFixtures.makeAuth(requests: self.requests, storage: MockAuthSessionStorage())
    let confirmed = try expectAuthenticatedResult(await other.confirmMagicLink("grant-2"))
    let redelivered = try expectAuthenticatedResult(await other.handleRedirect(AuthTestFixtures.magicLinkRedirect("grant-2")))
    XCTAssertTrue(confirmed.session === redelivered.session, "A link confirmed first replays through the one-step path too")
    XCTAssertEqual(self.requests.callCount, 2)
  }

  func test_confirmMagicLink_willNotReplayAnOAuthExchange_withTheSameToken() async throws {
    self.requests.responder = { request in
      if request.matches(path: PortalAuthApi.oauthTokensPath) {
        return AuthTestFixtures.grantResponse(clientSessionToken: "oauth-session-token")
      }
      return AuthTestFixtures.grantResponse(clientSessionToken: "magic-link-session-token")
    }
    let oauth = try expectOAuthRedirect(self.auth.parseRedirect(AuthTestFixtures.oauthRedirect(Self.token)))

    let viaOAuth = try expectAuthenticatedResult(await self.auth.completeOAuthLogin(oauth))
    let viaConfirm = try expectAuthenticatedResult(await self.auth.confirmMagicLink(Self.token))

    // The memory is keyed by sign-in kind: a magic-link confirmation is only ever answered by a
    // magic-link exchange.
    XCTAssertFalse(viaOAuth.session === viaConfirm.session)
    XCTAssertEqual(try viaConfirm.session.getToken(), "magic-link-session-token")
    XCTAssertEqual(self.paths, [PortalAuthApi.oauthTokensPath, PortalAuthApi.magicLinkValidationsPath])
  }

  // MARK: - confirmMagicLink: concurrency and cancellation

  func test_confirmMagicLink_willCollapseTwoConcurrentConfirmationsIntoOneExchange() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    self.requests.gateFirstRequest = true
    let auth = self.auth
    let requests = self.requests
    let firstBox = AuthResultBox()
    let secondBox = AuthResultBox()

    let first = Task<Void, Error> { try firstBox.store(await auth.confirmMagicLink(Self.token)) }
    let didArrive = await requests.waitUntilArrived()
    XCTAssertTrue(didArrive, "The first confirmation reached the transport")

    let second = Task<Void, Error> { try secondBox.store(await auth.confirmMagicLink(Self.token)) }
    let didPark = await AuthTestFixtures.pollUntil { auth.grantMutex.isContended }
    XCTAssertTrue(didPark, "The second confirmation waited instead of sending the link again")

    requests.release()
    try await first.value
    try await second.value

    let firstResult = try expectAuthenticatedResult(firstBox.result)
    let secondResult = try expectAuthenticatedResult(secondBox.result)
    XCTAssertTrue(firstResult.session === secondResult.session)
    XCTAssertEqual(requests.callCount, 1, "A double tap costs one exchange")
    XCTAssertEqual(self.storage.setCalls, 1)
  }

  func test_confirmMagicLink_willCompleteTheExchange_andReplayOnRetry_whenCallerCancelled() async throws {
    // Portal spends the link before it answers, so an exchange the caller abandoned (a dismissed
    // screen, a cancelled task) still finishes and is remembered: the retry replays it instead of
    // being rejected as already used.
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    self.requests.gateFirstRequest = true
    let auth = self.auth
    let requests = self.requests
    let box = AuthResultBox()

    let cancelled = Task<Void, Error> { try box.store(await auth.confirmMagicLink(Self.token)) }
    let didArrive = await requests.waitUntilArrived()
    XCTAssertTrue(didArrive, "The exchange reached the transport")

    cancelled.cancel()
    requests.release()
    try await cancelled.value

    let first = try expectAuthenticatedResult(box.result)
    let retried = try expectAuthenticatedResult(await auth.confirmMagicLink(Self.token))
    XCTAssertTrue(retried.session === first.session)
    XCTAssertEqual(requests.callCount, 1, "One request")
    XCTAssertEqual(self.storage.setCalls, 1, "One persist")
  }

  func test_confirmMagicLink_willNotExchange_whenCalledFromAnAlreadyCancelledTask() async {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    let auth = self.auth

    let task = Task<AuthResult, Error> {
      withUnsafeCurrentTask { $0?.cancel() }
      return try await auth.confirmMagicLink(Self.token)
    }

    await XCTAssertThrowsAsync(try await task.value) { error in
      XCTAssertTrue(error is CancellationError, "Expected CancellationError, got \(type(of: error))")
    }
    XCTAssertEqual(self.requests.callCount, 0, "A link is never spent for a caller that is already gone")
  }

  func test_clearPersistedSession_willWaitForAnInFlightConfirmation_thenClearIt() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    self.requests.gateFirstRequest = true
    let auth = self.auth
    let requests = self.requests
    let box = AuthResultBox()

    let confirmation = Task<Void, Error> { try box.store(await auth.confirmMagicLink(Self.token)) }
    let didArrive = await requests.waitUntilArrived()
    XCTAssertTrue(didArrive, "The confirmation reached the transport")

    let signOut = Task<Void, Error> { try await auth.clearPersistedSession() }
    let didPark = await AuthTestFixtures.pollUntil { auth.grantMutex.isContended }
    XCTAssertTrue(didPark, "The sign-out waited for the confirmation")

    requests.release()
    try await confirmation.value
    try await signOut.value

    XCTAssertEqual(self.storage.events, [.set, .delete], "The confirmation persisted first; the sign-out cleared it afterwards")
    let restored = try await auth.restoreSession()
    XCTAssertNil(restored, "No confirmation can write a session back after the sign-out")

    // The memory went with the sign-out, so the same link is sent again, and Portal rejects it.
    requests.failWith = PortalRequestsError.unauthorized
    await XCTAssertThrowsAsync(try await auth.confirmMagicLink(Self.token), expected: PortalAuthError.grantRejected)
    XCTAssertEqual(requests.callCount, 2)
  }

  // MARK: - confirmMagicLink: logging

  func test_confirmMagicLink_willLogNoDeprecationWarning() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()

    _ = try await self.auth.confirmMagicLink(Self.token)
    _ = try await self.auth.confirmMagicLink(Self.token)

    XCTAssertTrue(self.logger.messages(at: .warn).filter { $0.contains("deprecated") }.isEmpty)
  }

  func test_confirmMagicLink_willNotLogTokenOrSessionToken() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse(clientSessionToken: "secret-session-token")
    _ = try await self.auth.confirmMagicLink("secret-grant")
    _ = try await self.auth.confirmMagicLink("secret-grant")
    self.requests.failWith = PortalRequestsError.unauthorized
    await XCTAssertThrowsAsync(try await self.auth.confirmMagicLink("another-secret-grant"))

    self.logger.assertNoSecret("secret-grant")
    self.logger.assertNoSecret("secret-session-token")
  }
}
