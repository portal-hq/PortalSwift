//
//  PortalAuthCompleteOAuthLoginTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

/// Covers `PortalAuth.completeOAuthLogin(_:)`, which completes a `loginWithGoogle()` /
/// `loginWithApple()` redirect read by `parseRedirect(_:)`.
///
/// It shares the exchange machinery with `confirmMagicLink(_:)` and the deprecated
/// `handleRedirect(_:)` — one grant mutex, one remembered result keyed by sign-in kind and token,
/// an exchange shielded from the caller's cancellation — but keeps a refused grant as the
/// transport's `PortalRequestsError.unauthorized`, as `signInWith*` reports it.
///
/// Every case starts with a Google or Apple sign-in in progress, as `loginWith*` leaves it, so the
/// exchange can be reached; the device binding itself is covered by `PortalAuthOAuthVerifierTests`,
/// and only pinned here for this method.
final class PortalAuthCompleteOAuthLoginTests: XCTestCase {
  private static let token = AuthTestFixtures.grantToken

  private var requests = RecordingPortalRequests()
  private var storage = MockAuthSessionStorage()
  private var verifierStorage = MockOAuthVerifierStorage()
  private var logger = RecordingLogger()
  private var auth = AuthTestFixtures.makeAuth(requests: RecordingPortalRequests())

  override func setUpWithError() throws {
    try super.setUpWithError()
    CredentialInvalidationRegistry.shared.resetForTesting()
    self.requests = RecordingPortalRequests()
    self.storage = MockAuthSessionStorage()
    self.verifierStorage = MockOAuthVerifierStorage(stored: AuthTestFixtures.pendingVerifier())
    self.logger = RecordingLogger()
    self.auth = AuthTestFixtures.makeAuth(
      requests: self.requests,
      storage: self.storage,
      verifierStorage: self.verifierStorage,
      logger: self.logger
    )
  }

  override func tearDownWithError() throws {
    self.logger.uninstall()
    CredentialInvalidationRegistry.shared.resetForTesting()
    try super.tearDownWithError()
  }

  // MARK: - Helpers

  /// The `.oauth` payload of a redirect, read the way a host reads it.
  private func oauth(_ token: String = PortalAuthCompleteOAuthLoginTests.token, loginType: String = "GOOGLE") throws -> AuthRedirect.OAuth {
    try expectOAuthRedirect(self.auth.parseRedirect(AuthTestFixtures.oauthRedirect(token, loginType: loginType)))
  }

  // MARK: - The exchange

  func test_completeOAuthLogin_willExchangeAtOauthTokens_andPersist() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    let redirect = try self.oauth()

    let result = try expectAuthenticatedResult(await self.auth.completeOAuthLogin(redirect))

    let request = try XCTUnwrap(self.requests.lastRequest)
    XCTAssertEqual(request.absoluteString, AuthTestFixtures.apiBase + "/oauth/tokens")
    XCTAssertEqual(request.method, .post)
    XCTAssertNil(request.bearerToken)
    let payload = try XCTUnwrap(request.payloadJSON)
    XCTAssertEqual(payload.count, 2)
    XCTAssertEqual(payload["token"] as? String, Self.token)
    XCTAssertEqual(payload["codeVerifier"] as? String, AuthTestFixtures.rfcCodeVerifier, "Sent with the verifier of the sign-in in progress")
    XCTAssertEqual(try result.session.getToken(), AuthTestFixtures.clientSessionToken)
    XCTAssertEqual(self.storage.setCalls, 1)
    XCTAssertNil(self.verifierStorage.stored, "Portal accepted the grant, so its verifier is spent")
  }

  // MARK: - Bound to the device

  func test_completeOAuthLogin_willRefuseWithoutARequest_whenNoSignInIsInProgress() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    self.verifierStorage.stored = nil

    for loginType in ["GOOGLE", "APPLE"] {
      await XCTAssertThrowsAsync(
        try await self.auth.completeOAuthLogin(self.oauth(loginType: loginType)),
        expected: PortalAuthError.oauthFlowNotStarted
      )
    }

    XCTAssertEqual(self.requests.callCount, 0, "A grant this device never asked for must never reach /oauth/tokens")
    XCTAssertEqual(self.storage.setCalls, 0)
  }

  func test_completeOAuthLogin_willRefuseWithoutARequest_whenTheSignInIsFifteenMinutesOld() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    self.verifierStorage.stored = AuthTestFixtures.pendingVerifier(ageMillis: PortalAuth.verifierLifetimeMillis)

    await XCTAssertThrowsAsync(try await self.auth.completeOAuthLogin(self.oauth()), expected: PortalAuthError.oauthFlowNotStarted)

    XCTAssertEqual(self.requests.callCount, 0)
    XCTAssertNil(self.verifierStorage.stored, "An expired sign-in is cleared")
  }

  func test_completeOAuthLogin_willKeepTheSignInInProgress_whenPortalRefusesTheGrant() async throws {
    self.requests.failWith = PortalRequestsError.unauthorized

    await XCTAssertThrowsAsync(try await self.auth.completeOAuthLogin(self.oauth()), expected: PortalRequestsError.unauthorized)

    // A refused grant can be someone else's, sent with this device's verifier: the user's own
    // redirect, arriving next, must still complete.
    XCTAssertEqual(self.verifierStorage.stored, AuthTestFixtures.pendingVerifier())
  }

  func test_completeOAuthLogin_willThrowOAuthFlowNotStarted_whenClearPersistedSessionCancelsTheExchange() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    self.requests.gateFirstRequest = true
    let auth = self.auth
    let requests = self.requests
    let redirect = try self.oauth()

    let exchange = Task { try await auth.completeOAuthLogin(redirect) }
    let didArrive = await requests.waitUntilArrived()
    XCTAssertTrue(didArrive)

    let clear = Task { try await auth.clearPersistedSession() }
    let didPark = await AuthTestFixtures.pollUntil { auth.grantMutex.isContended }
    XCTAssertTrue(didPark, "The clear waits for the exchange holding the lock")
    requests.release()

    await XCTAssertThrowsAsync(try await exchange.value, expected: PortalAuthError.oauthFlowNotStarted)
    try await clear.value
    XCTAssertEqual(self.storage.setCalls, 0, "No session is written for a cancelled sign-in")
    XCTAssertNil(self.verifierStorage.stored)

    // Delivered again after the clear: refused without a second request.
    await XCTAssertThrowsAsync(try await auth.completeOAuthLogin(redirect), expected: PortalAuthError.oauthFlowNotStarted)
    XCTAssertEqual(requests.callCount, 1)
  }

  func test_completeOAuthLogin_willExchangeAppleAtTheSameEndpoint() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    let redirect = try self.oauth(loginType: "APPLE")
    XCTAssertEqual(redirect.provider, .apple)

    _ = try expectAuthenticatedResult(await self.auth.completeOAuthLogin(redirect))

    XCTAssertEqual(self.requests.recorded.map { $0.path }, [PortalAuthApi.oauthTokensPath])
  }

  func test_completeOAuthLogin_willReturnTotpRequired_persistingNothing() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse(clientSessionToken: nil, userJwt: AuthTestFixtures.userJwt())

    let step = try expectTotpRequiredResult(await self.auth.completeOAuthLogin(self.oauth()))

    XCTAssertEqual(step.userJwt, AuthTestFixtures.userJwt())
    XCTAssertEqual(self.storage.setCalls, 0)
  }

  func test_completeOAuthLogin_willPassThroughUnauthorized_notGrantRejected() async throws {
    self.requests.failWith = PortalRequestsError.unauthorized
    let redirect = try self.oauth()

    await XCTAssertThrowsAsync(try await self.auth.completeOAuthLogin(redirect), expected: PortalRequestsError.unauthorized)

    XCTAssertEqual(self.storage.setCalls, 0)
    XCTAssertEqual(self.requests.unauthorizedHookInvocations, 0)
  }

  // MARK: - Replay and retry

  func test_completeOAuthLogin_willReplayARedeliveredRedirect_withSameSessionInstance() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    let redirect = try self.oauth()

    let first = try expectAuthenticatedResult(await self.auth.completeOAuthLogin(redirect))
    let replay = try expectAuthenticatedResult(await self.auth.completeOAuthLogin(self.oauth()))

    XCTAssertTrue(first.session === replay.session)
    XCTAssertEqual(self.requests.callCount, 1)
    XCTAssertEqual(self.storage.setCalls, 1)
  }

  func test_completeOAuthLogin_willShareMemoryWithHandleRedirect() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()

    let viaRedirect = try expectAuthenticatedResult(await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect(Self.token)))
    let viaComplete = try expectAuthenticatedResult(await self.auth.completeOAuthLogin(self.oauth()))

    XCTAssertTrue(viaRedirect.session === viaComplete.session)
    XCTAssertEqual(self.requests.callCount, 1)
  }

  func test_completeOAuthLogin_willThrowUnauthorized_withoutRequest_whenRememberedSessionInvalidated() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    let first = try expectAuthenticatedResult(await self.auth.completeOAuthLogin(self.oauth()))
    try first.session.invalidate()

    await XCTAssertThrowsAsync(try await self.auth.completeOAuthLogin(self.oauth()), expected: PortalRequestsError.unauthorized)

    XCTAssertEqual(self.requests.callCount, 1)
  }

  func test_completeOAuthLogin_willStayRetryable_whenExchangeFailed() async throws {
    self.requests.enqueue(failure: AuthTestFixtures.serverError503)
    self.requests.enqueue(AuthTestFixtures.grantResponse())

    await XCTAssertThrowsAsync(try await self.auth.completeOAuthLogin(self.oauth()), expected: AuthTestFixtures.serverError503)
    _ = try expectAuthenticatedResult(await self.auth.completeOAuthLogin(self.oauth()))

    XCTAssertEqual(self.requests.callCount, 2)
  }

  func test_completeOAuthLogin_willNotReplayAMagicLinkExchange_withTheSameToken() async throws {
    self.requests.responder = { request in
      if request.matches(path: PortalAuthApi.oauthTokensPath) {
        return AuthTestFixtures.grantResponse(clientSessionToken: "oauth-session-token")
      }
      return AuthTestFixtures.grantResponse(clientSessionToken: "magic-link-session-token")
    }

    let viaConfirm = try expectAuthenticatedResult(await self.auth.confirmMagicLink(Self.token))
    let viaOAuth = try expectAuthenticatedResult(await self.auth.completeOAuthLogin(self.oauth()))

    XCTAssertFalse(viaConfirm.session === viaOAuth.session)
    XCTAssertEqual(try viaOAuth.session.getToken(), "oauth-session-token")
    XCTAssertEqual(self.requests.recorded.map { $0.path }, [PortalAuthApi.magicLinkValidationsPath, PortalAuthApi.oauthTokensPath])
  }

  // MARK: - Concurrency and cancellation

  func test_completeOAuthLogin_willCollapseTwoConcurrentCompletionsIntoOneExchange() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    self.requests.gateFirstRequest = true
    let auth = self.auth
    let requests = self.requests
    let redirect = try self.oauth()
    let firstBox = AuthResultBox()
    let secondBox = AuthResultBox()

    let first = Task<Void, Error> { try firstBox.store(await auth.completeOAuthLogin(redirect)) }
    let didArrive = await requests.waitUntilArrived()
    XCTAssertTrue(didArrive)

    let second = Task<Void, Error> { try secondBox.store(await auth.completeOAuthLogin(redirect)) }
    let didPark = await AuthTestFixtures.pollUntil { auth.grantMutex.isContended }
    XCTAssertTrue(didPark, "The second completion waited instead of spending the grant again")

    requests.release()
    try await first.value
    try await second.value

    XCTAssertTrue(try expectAuthenticatedResult(firstBox.result).session === expectAuthenticatedResult(secondBox.result).session)
    XCTAssertEqual(requests.callCount, 1)
  }

  func test_completeOAuthLogin_willCompleteTheExchange_andReplayOnRetry_whenCallerCancelled() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    self.requests.gateFirstRequest = true
    let auth = self.auth
    let requests = self.requests
    let redirect = try self.oauth()
    let box = AuthResultBox()

    let cancelled = Task<Void, Error> { try box.store(await auth.completeOAuthLogin(redirect)) }
    let didArrive = await requests.waitUntilArrived()
    XCTAssertTrue(didArrive)

    cancelled.cancel()
    requests.release()
    try await cancelled.value

    let first = try expectAuthenticatedResult(box.result)
    let retried = try expectAuthenticatedResult(await auth.completeOAuthLogin(redirect))
    XCTAssertTrue(retried.session === first.session)
    XCTAssertEqual(requests.callCount, 1)
    XCTAssertEqual(self.storage.setCalls, 1)
  }

  func test_completeOAuthLogin_willNotExchange_whenCalledFromAnAlreadyCancelledTask() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse()
    let auth = self.auth
    let redirect = try self.oauth()

    let task = Task<AuthResult, Error> {
      withUnsafeCurrentTask { $0?.cancel() }
      return try await auth.completeOAuthLogin(redirect)
    }

    await XCTAssertThrowsAsync(try await task.value) { error in
      XCTAssertTrue(error is CancellationError, "Expected CancellationError, got \(type(of: error))")
    }
    XCTAssertEqual(self.requests.callCount, 0)
  }

  // MARK: - Logging

  func test_completeOAuthLogin_willNotLogTokenOrSessionToken_orADeprecationWarning() async throws {
    self.requests.defaultResponse = AuthTestFixtures.grantResponse(clientSessionToken: "secret-session-token")

    _ = try await self.auth.completeOAuthLogin(self.oauth("secret-grant"))
    _ = try await self.auth.completeOAuthLogin(self.oauth("secret-grant"))

    self.logger.assertNoSecret("secret-grant")
    self.logger.assertNoSecret("secret-session-token")
    XCTAssertTrue(self.logger.messages(at: .warn).filter { $0.contains("deprecated") }.isEmpty)
  }
}
