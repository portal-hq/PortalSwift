//
//  PortalAuthOAuthVerifierTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import AuthenticationServices
import Foundation
@testable import PortalSwift
import XCTest

/// A settable clock for the 15-minute verifier lifetime. Lock-guarded because `PortalAuth`
/// reads it from whatever executor runs the exchange.
private final class TestClock: @unchecked Sendable {
  private let lock = NSLock()
  private var _now = AuthTestFixtures.now

  var now: Date {
    get {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._now
    }
    set {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._now = newValue
    }
  }
}

/// Covers binding Google and Apple sign-ins to the device with a PKCE code verifier: what
/// `loginWith*` / `signInWith*` store and send, what `handleRedirect(_:)` refuses without a
/// request, when the verifier is spent or kept, and how `clearPersistedSession()` cancels a
/// sign-in in progress.
///
/// The verifier storage is a `MockOAuthVerifierStorage`, empty by default, so every case states
/// whether a sign-in is in progress. The transport answers by path, so a case can interleave a
/// start and an exchange deterministically. No case reaches the network or presents UI.
final class PortalAuthOAuthVerifierTests: XCTestCase {
  private var requests = RecordingPortalRequests()
  private var storage = MockAuthSessionStorage()
  private var verifierStorage = MockOAuthVerifierStorage()
  private var web = FakeAuthWebSession()
  private var logger = RecordingLogger()
  private var anchor = MockAuthenticationAnchor()
  private var clock = TestClock()
  private var auth = AuthTestFixtures.makeAuth(requests: RecordingPortalRequests())

  override func setUpWithError() throws {
    try super.setUpWithError()
    CredentialInvalidationRegistry.shared.resetForTesting()

    self.requests = RecordingPortalRequests()
    self.storage = MockAuthSessionStorage()
    self.verifierStorage = MockOAuthVerifierStorage()
    self.web = try FakeAuthWebSession(results: [.success(AuthTestFixtures.url(Self.sheetCallback))])
    self.logger = RecordingLogger()
    // `ASPresentationAnchor` is a `UIWindow`, built here in the synchronous set-up.
    self.anchor = MockAuthenticationAnchor()
    self.clock = TestClock()
    self.answerByPath()
    self.auth = self.makeSubject()
  }

  override func tearDownWithError() throws {
    self.logger.uninstall()
    CredentialInvalidationRegistry.shared.resetForTesting()
    try super.tearDownWithError()
  }

  // MARK: - Fixtures

  private static let sheetCallback = "\(AuthTestFixtures.redirectUrl)?token=sheet-grant&login_type=GOOGLE"

  private func makeSubject(apiHost: String = AuthTestFixtures.apiHost) -> PortalAuth {
    let clock = self.clock
    let auth = AuthTestFixtures.makeAuth(
      requests: self.requests,
      storage: self.storage,
      verifierStorage: self.verifierStorage,
      clock: { clock.now },
      logger: self.logger,
      apiHost: apiHost,
      webSessionFactory: self.web.factory
    )
    auth.setAuthPresentationAnchor(self.anchor)
    return auth
  }

  /// Answers `/oauth/urls` with both providers and every exchange with a completed login.
  private func answerByPath(grant: Data = AuthTestFixtures.grantResponse()) {
    self.requests.responder = { request in
      if request.matches(path: PortalAuthApi.oauthUrlsPath) {
        return AuthTestFixtures.oauthUrls()
      }
      return grant
    }
  }

  private func seedPendingSignIn(ageMillis: Int64 = 0) {
    self.verifierStorage.stored = AuthTestFixtures.pendingVerifier(ageMillis: ageMillis)
  }

  private var urlRequests: [RecordedRequest] {
    self.requests.requests(toPath: PortalAuthApi.oauthUrlsPath)
  }

  private var tokenRequests: [RecordedRequest] {
    self.requests.requests(toPath: PortalAuthApi.oauthTokensPath)
  }

  /// The `codeChallenge` query value of a recorded `/oauth/urls` request.
  private func challenge(of request: RecordedRequest?) -> String? {
    guard let query = request?.query else {
      return nil
    }
    for pair in query.split(separator: "&") {
      let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
      if parts.count == 2, parts[0] == "codeChallenge" {
        return parts[1]
      }
    }
    return nil
  }

  private func authenticated(_ result: AuthResult?, file: StaticString = #filePath, line: UInt = #line) throws -> AuthenticatedResult {
    guard case let .authenticated(value)? = result else {
      XCTFail("Expected AuthResult.authenticated.", file: file, line: line)
      throw PortalAuthError.invalidGrantResponse
    }
    return value
  }

  // MARK: - Starting a sign-in

  func test_loginWithGoogle_willStoreAFreshVerifierAndSendItsChallenge() async throws {
    _ = try await self.auth.loginWithGoogle()

    let stored = try XCTUnwrap(self.verifierStorage.stored)
    XCTAssertTrue(PkceCodeVerifier.isWellFormed(stored.verifier))
    XCTAssertEqual(stored.verifier.count, 43)
    XCTAssertEqual(stored.createdAt, AuthTestFixtures.nowMillis)

    let request = try XCTUnwrap(self.urlRequests.first)
    XCTAssertEqual(self.challenge(of: request), PkceCodeVerifier.challenge(for: stored.verifier))
    XCTAssertTrue(try XCTUnwrap(request.query).contains("&codeChallengeMethod=S256"))
  }

  func test_loginWithApple_willStoreAFreshVerifierAndSendItsChallenge() async throws {
    let result = try await self.auth.loginWithApple()

    XCTAssertEqual(result.authorizeUrl, AuthTestFixtures.appleAuthorizeUrl)
    let stored = try XCTUnwrap(self.verifierStorage.stored)
    XCTAssertEqual(self.challenge(of: self.urlRequests.first), PkceCodeVerifier.challenge(for: stored.verifier))
  }

  func test_loginWith_willReplaceThePreviousVerifier_onEveryStart() async throws {
    _ = try await self.auth.loginWithGoogle()
    _ = try await self.auth.loginWithApple()

    let values = self.verifierStorage.setValues
    XCTAssertEqual(values.count, 2)
    XCTAssertNotEqual(values[0].verifier, values[1].verifier, "A verifier is never reused")
    XCTAssertEqual(self.verifierStorage.stored, values[1], "The newest sign-in wins")
    XCTAssertEqual(self.challenge(of: self.urlRequests[0]), PkceCodeVerifier.challenge(for: values[0].verifier))
    XCTAssertEqual(self.challenge(of: self.urlRequests[1]), PkceCodeVerifier.challenge(for: values[1].verifier))
  }

  func test_loginWithGoogle_willReturnNoUrl_whenTheVerifierCannotBeStored() async throws {
    let failure = PortalAuthError.sessionStorageFailure(message: "The sign-in in progress could not be stored (OSStatus -25308).")
    self.verifierStorage.onSet = { _ in throw failure }

    await XCTAssertThrowsAsync(try await self.auth.loginWithGoogle(), expected: failure)
    XCTAssertNil(self.verifierStorage.stored)
  }

  func test_loginWithGoogle_willReportAForeignStorageErrorAsSessionStorageFailure() async throws {
    self.verifierStorage.onSet = { _ in throw NSError(domain: "test", code: 1) }

    await XCTAssertThrowsAsync(
      try await self.auth.loginWithGoogle(),
      expected: PortalAuthError.sessionStorageFailure(message: "The sign-in in progress could not be stored.")
    )
  }

  func test_loginWithGoogle_willStoreNothing_whenTheProviderIsNotEnabled() async throws {
    self.requests.responder = { _ in AuthTestFixtures.oauthUrls(google: nil) }

    await XCTAssertThrowsAsync(try await self.auth.loginWithGoogle(), expected: PortalAuthError.authMethodUnavailable(.google))
    XCTAssertEqual(self.verifierStorage.setCalls, 0)
  }

  func test_loginWithGoogle_willStoreNothing_whenTheRequestFails() async throws {
    self.requests.failWith = AuthTestFixtures.serverError503

    await XCTAssertThrowsAsync(try await self.auth.loginWithGoogle())
    XCTAssertEqual(self.verifierStorage.setCalls, 0)
  }

  func test_loginWithGoogle_willStartNothing_whenCancelledWhileWaitingForAnotherStart() async throws {
    let auth = self.auth
    self.requests.gateFirstRequest = true
    let first = Task { _ = try await auth.loginWithGoogle() }
    let arrived = await self.requests.waitUntilArrived()
    XCTAssertTrue(arrived)

    let second = Task { _ = try await auth.loginWithApple() }
    let waiting = await AuthTestFixtures.pollUntil { auth.flowMutex.isContended }
    XCTAssertTrue(waiting, "The second start must wait for the first")
    second.cancel()
    self.requests.release()

    try await first.value
    await XCTAssertThrowsAsync(try await second.value) { error in
      XCTAssertTrue(error is CancellationError, "Expected CancellationError, got \(type(of: error)).")
    }
    XCTAssertEqual(self.urlRequests.count, 1)
    XCTAssertEqual(self.verifierStorage.setCalls, 1)
  }

  func test_loginWithGoogle_willStoreNothing_whenCancelledOnceTheUrlIsInHand() async throws {
    self.seedPendingSignIn()
    self.requests.responder = { _ in
      // The response arrives, but the caller is cancelled before the verifier is stored.
      withUnsafeCurrentTask { $0?.cancel() }
      return AuthTestFixtures.oauthUrls()
    }

    await XCTAssertThrowsAsync(try await self.auth.loginWithGoogle()) { error in
      XCTAssertTrue(error is CancellationError, "Expected CancellationError, got \(type(of: error)).")
    }
    XCTAssertEqual(self.verifierStorage.setCalls, 0)
    XCTAssertEqual(self.verifierStorage.stored, AuthTestFixtures.pendingVerifier(), "The sign-in in progress must survive")
  }

  func test_loginWithGoogle_willKeepTheVerifierOfTheUrlReturnedLast_whenStartsRace() async throws {
    let auth = self.auth
    self.requests.gateFirstRequest = true
    let first = Task { _ = try await auth.loginWithGoogle() }
    let arrived = await self.requests.waitUntilArrived()
    XCTAssertTrue(arrived)

    let second = Task { _ = try await auth.loginWithGoogle() }
    let waiting = await AuthTestFixtures.pollUntil { auth.flowMutex.isContended }
    XCTAssertTrue(waiting)
    self.requests.release()
    try await first.value
    try await second.value

    let values = self.verifierStorage.setValues
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(self.verifierStorage.stored, values[1])
    XCTAssertEqual(
      self.challenge(of: self.urlRequests.last),
      PkceCodeVerifier.challenge(for: values[1].verifier),
      "The stored verifier belongs to the URL returned last"
    )
  }

  // MARK: - Completing a sign-in

  func test_handleRedirect_willSendThePendingVerifierWithTheGrant() async throws {
    self.seedPendingSignIn()

    _ = try await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect())

    let body = try XCTUnwrap(self.tokenRequests.first?.payloadJSON)
    XCTAssertEqual(body["token"] as? String, AuthTestFixtures.grantToken)
    XCTAssertEqual(body["codeVerifier"] as? String, AuthTestFixtures.rfcCodeVerifier)
    XCTAssertEqual(body.count, 2)
  }

  func test_handleRedirect_willCompleteASignInStartedByLoginWithGoogle() async throws {
    _ = try await self.auth.loginWithGoogle()
    let started = try XCTUnwrap(self.verifierStorage.stored)

    let result = try self.authenticated(await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()))

    XCTAssertEqual(try result.session.getToken(), AuthTestFixtures.clientSessionToken)
    let sent = try XCTUnwrap(self.tokenRequests.first?.payloadJSON?["codeVerifier"] as? String)
    XCTAssertEqual(sent, started.verifier)
    XCTAssertEqual(self.challenge(of: self.urlRequests.first), PkceCodeVerifier.challenge(for: sent))
    XCTAssertNil(self.verifierStorage.stored, "A completed sign-in leaves nothing in progress")
  }

  func test_handleRedirect_willNeitherSendNorTouchTheVerifier_forAMagicLink() async throws {
    self.seedPendingSignIn()

    _ = try await self.auth.legacy.handleRedirect(AuthTestFixtures.magicLinkRedirect())

    let request = try XCTUnwrap(self.requests.lastRequest)
    XCTAssertEqual(request.path, PortalAuthApi.magicLinkValidationsPath)
    XCTAssertEqual(request.payloadJSON?.count, 1)
    XCTAssertNil(request.payloadJSON?["codeVerifier"])
    XCTAssertTrue(self.verifierStorage.events.isEmpty)
    XCTAssertEqual(self.verifierStorage.stored, AuthTestFixtures.pendingVerifier())
  }

  func test_handleRedirect_willRefuseAnOAuthRedirect_withNoSignInInProgress_sendingNothing() async throws {
    for loginType in ["GOOGLE", "APPLE"] {
      await XCTAssertThrowsAsync(
        try await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect(loginType: loginType)),
        expected: PortalAuthError.oauthFlowNotStarted
      )
    }

    XCTAssertEqual(self.requests.callCount, 0, "An unsolicited grant must never reach /oauth/tokens")
    XCTAssertEqual(self.storage.setCalls, 0)
  }

  func test_handleRedirect_willRefuseAndDelete_aVerifierFifteenMinutesOld() async throws {
    self.seedPendingSignIn(ageMillis: PortalAuth.verifierLifetimeMillis)

    await XCTAssertThrowsAsync(
      try await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()),
      expected: PortalAuthError.oauthFlowNotStarted
    )
    XCTAssertEqual(self.requests.callCount, 0)
    XCTAssertNil(self.verifierStorage.stored)
  }

  func test_handleRedirect_willExchange_aVerifierJustUnderFifteenMinutesOld() async throws {
    self.seedPendingSignIn(ageMillis: PortalAuth.verifierLifetimeMillis - 1)

    _ = try self.authenticated(await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()))

    XCTAssertEqual(self.tokenRequests.count, 1)
  }

  func test_handleRedirect_willMeasureTheLifetimeWithTheInjectedClock() async throws {
    _ = try await self.auth.loginWithGoogle()
    self.clock.now = AuthTestFixtures.now.addingTimeInterval(15 * 60)

    await XCTAssertThrowsAsync(
      try await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()),
      expected: PortalAuthError.oauthFlowNotStarted
    )
    XCTAssertEqual(self.tokenRequests.count, 0)
  }

  func test_handleRedirect_willRefuseAndDelete_aVerifierDatedInTheFuture() async throws {
    self.seedPendingSignIn(ageMillis: -1)

    await XCTAssertThrowsAsync(
      try await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()),
      expected: PortalAuthError.oauthFlowNotStarted
    )
    XCTAssertEqual(self.requests.callCount, 0)
    XCTAssertNil(self.verifierStorage.stored)
  }

  func test_handleRedirect_willRefuse_aVerifierWhoseAgeWouldOverflow() async throws {
    self.verifierStorage.stored = PendingOAuthVerifier(verifier: AuthTestFixtures.rfcCodeVerifier, createdAt: .min)

    await XCTAssertThrowsAsync(
      try await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()),
      expected: PortalAuthError.oauthFlowNotStarted
    )
    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_handleRedirect_willSendNothingAndKeepTheVerifier_whenTheSignInCannotBeRead() async throws {
    self.seedPendingSignIn()
    let failure = PortalAuthError.sessionStorageFailure(message: "The sign-in in progress could not be read (OSStatus -25308).")
    self.verifierStorage.onGet = { throw failure }

    await XCTAssertThrowsAsync(try await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()), expected: failure)
    XCTAssertEqual(self.requests.callCount, 0)
    XCTAssertEqual(self.verifierStorage.stored, AuthTestFixtures.pendingVerifier())

    self.verifierStorage.onGet = nil
    _ = try self.authenticated(await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()))
    XCTAssertEqual(self.tokenRequests.count, 1, "The same redirect completes once the Keychain can be read")
  }

  func test_handleRedirect_willReportAForeignReadErrorAsSessionStorageFailure() async throws {
    self.verifierStorage.onGet = { throw NSError(domain: "test", code: 1) }

    await XCTAssertThrowsAsync(
      try await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()),
      expected: PortalAuthError.sessionStorageFailure(message: "The sign-in in progress could not be read.")
    )
  }

  func test_handleRedirect_willDeleteTheVerifier_afterASuccessfulExchange() async throws {
    self.seedPendingSignIn()

    _ = try await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect())

    XCTAssertNil(self.verifierStorage.stored)
    XCTAssertEqual(self.verifierStorage.deleteIfCurrentArguments, [AuthTestFixtures.rfcCodeVerifier])
  }

  func test_handleRedirect_willDeleteTheVerifier_whenTheExchangeRequiresTotp() async throws {
    self.seedPendingSignIn()
    self.answerByPath(grant: AuthTestFixtures.grantResponse(clientSessionToken: nil, userJwt: AuthTestFixtures.userJwt()))

    let result = try await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect())

    guard case .totpRequired? = result else {
      return XCTFail("Expected AuthResult.totpRequired.")
    }
    XCTAssertNil(self.verifierStorage.stored, "Portal accepted the grant, so the verifier is spent")
  }

  func test_handleRedirect_willDeleteTheVerifier_whenAnAcceptedExchangeReturnsAMalformedBody() async throws {
    let malformed: [(Data, PortalAuthError)] = [
      (Data("{}".utf8), .malformedResponse(path: PortalAuthApi.oauthTokensPath, missing: nil)),
      (AuthTestFixtures.grantResponse(endUserId: nil), .malformedResponse(path: PortalAuthApi.oauthTokensPath, missing: "endUserId"))
    ]

    for (body, expected) in malformed {
      self.seedPendingSignIn()
      self.answerByPath(grant: body)

      await XCTAssertThrowsAsync(try await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()), expected: expected)
      XCTAssertNil(self.verifierStorage.stored, "A 2xx spent the grant, so the verifier goes with it")
    }
  }

  func test_handleRedirect_willDeleteTheVerifier_whenTheGrantResponseIsInvalid() async throws {
    self.seedPendingSignIn()
    self.answerByPath(grant: AuthTestFixtures.grantResponse(clientSessionToken: nil, userJwt: nil))

    await XCTAssertThrowsAsync(
      try await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()),
      expected: PortalAuthError.invalidGrantResponse
    )
    XCTAssertNil(self.verifierStorage.stored)
  }

  func test_handleRedirect_willDeleteTheVerifier_whenTheSessionCannotBePersisted() async throws {
    self.seedPendingSignIn()
    self.storage.onSet = { _ in throw PortalAuthError.sessionStorageFailure(message: "write failed") }

    await XCTAssertThrowsAsync(try await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()))
    XCTAssertNil(self.verifierStorage.stored)

    // The grant is spent, so the re-delivered redirect finishes the write from the memo: no
    // second exchange, and no verifier is needed for it.
    self.storage.onSet = nil
    _ = try self.authenticated(await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()))
    XCTAssertEqual(self.tokenRequests.count, 1)
  }

  func test_handleRedirect_willCompleteTheSignIn_whenTheSpentVerifierCannotBeDeleted() async throws {
    self.seedPendingSignIn()
    self.verifierStorage.onDeleteIfCurrent = { _ in throw PortalAuthError.sessionStorageFailure(message: "delete failed") }

    let result = try self.authenticated(await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()))

    XCTAssertEqual(try result.session.getToken(), AuthTestFixtures.clientSessionToken)
    XCTAssertEqual(self.logger.messages(at: .warn).count, 1)
  }

  func test_handleRedirect_willKeepTheVerifier_afterARejectedExchange_soThisDevicesOwnRedirectCompletes() async throws {
    self.seedPendingSignIn()
    self.requests.fail(with: PortalRequestsError.unauthorized, onPath: PortalAuthApi.oauthTokensPath)

    // A crafted redirect carrying a grant this device did not ask for: Portal refuses it.
    await XCTAssertThrowsAsync(
      try await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect("attacker-grant")),
      expected: PortalRequestsError.unauthorized
    )
    XCTAssertEqual(self.verifierStorage.stored, AuthTestFixtures.pendingVerifier())

    self.requests.fail(with: nil, onPath: PortalAuthApi.oauthTokensPath)
    _ = try self.authenticated(await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect("own-grant")))
    XCTAssertEqual(self.tokenRequests.last?.payloadJSON?["codeVerifier"] as? String, AuthTestFixtures.rfcCodeVerifier)
  }

  func test_handleRedirect_willKeepTheVerifier_afterAServerError_soTheSameRedirectCanBeRetried() async throws {
    self.seedPendingSignIn()
    self.requests.fail(with: AuthTestFixtures.serverError503, onPath: PortalAuthApi.oauthTokensPath)

    await XCTAssertThrowsAsync(try await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()))
    XCTAssertEqual(self.tokenRequests.count, 1, "No automatic retry")
    XCTAssertNotNil(self.verifierStorage.stored)

    self.requests.fail(with: nil, onPath: PortalAuthApi.oauthTokensPath)
    _ = try self.authenticated(await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()))
    XCTAssertEqual(self.tokenRequests.count, 2)
  }

  func test_handleRedirect_willKeepTheVerifier_afterADroppedConnection() async throws {
    self.seedPendingSignIn()
    self.requests.fail(with: URLError(.networkConnectionLost), onPath: PortalAuthApi.oauthTokensPath)

    await XCTAssertThrowsAsync(try await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect())) { error in
      XCTAssertEqual((error as? URLError)?.code, .networkConnectionLost)
    }
    XCTAssertEqual(self.verifierStorage.stored, AuthTestFixtures.pendingVerifier())
  }

  func test_handleRedirect_willKeepTheVerifier_whenTheRequestCannotBeBuilt() async throws {
    let subject = self.makeSubject(apiHost: "not a host")
    self.seedPendingSignIn()

    await XCTAssertThrowsAsync(
      try await subject.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()),
      expected: PortalAuthError.invalidArgument(name: "apiHost")
    )
    XCTAssertEqual(self.verifierStorage.stored, AuthTestFixtures.pendingVerifier(), "Nothing was sent, so nothing was spent")
  }

  func test_handleRedirect_willNotReadTheVerifier_forAnErrorRedirect() async throws {
    self.seedPendingSignIn()

    await XCTAssertThrowsAsync(
      try await self.auth.legacy.handleRedirect(AuthTestFixtures.redirectUrl + "?token=x&login_type=GOOGLE&error=oauth_failed"),
      expected: PortalAuthError.authenticationFailed(error: "oauth_failed")
    )
    XCTAssertTrue(self.verifierStorage.events.isEmpty)
  }

  func test_handleRedirect_willReplayARedeliveredRedirect_afterItsVerifierWasDeleted() async throws {
    self.seedPendingSignIn()

    let first = try self.authenticated(await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()))
    let second = try self.authenticated(await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()))

    XCTAssertTrue(first.session as AnyObject === second.session as AnyObject, "The re-delivered redirect replays the same session")
    XCTAssertEqual(self.tokenRequests.count, 1)
  }

  func test_loginWithGoogle_willKeepItsOwnVerifier_whenStartedWhileAnExchangeIsInFlight() async throws {
    self.seedPendingSignIn()
    let auth = self.auth
    self.requests.gateFirstRequest = true
    let exchange = Task { _ = try await auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()) }
    let arrived = await self.requests.waitUntilArrived()
    XCTAssertTrue(arrived)

    _ = try await auth.loginWithGoogle()
    let newer = try XCTUnwrap(self.verifierStorage.stored)
    XCTAssertNotEqual(newer.verifier, AuthTestFixtures.rfcCodeVerifier)

    self.requests.release()
    try await exchange.value

    XCTAssertEqual(self.verifierStorage.stored, newer, "The finished exchange must not delete the newer sign-in")
  }

  func test_sessionInvalidation_willKeepTheSignInInProgress() async throws {
    let result = try self.authenticated(await self.auth.legacy.handleRedirect(AuthTestFixtures.magicLinkRedirect()))
    self.seedPendingSignIn()

    try XCTUnwrap(result.session as? KeychainPortalSession).invalidate()

    XCTAssertEqual(self.verifierStorage.stored, AuthTestFixtures.pendingVerifier())
  }

  // MARK: - Sign-in sheet

  func test_signInWithGoogle_willOpenNoSheet_whenTheVerifierCannotBeStored() async throws {
    self.verifierStorage.onSet = { _ in throw PortalAuthError.sessionStorageFailure(message: "write failed") }

    await XCTAssertThrowsAsync(
      try await self.auth.signInWithGoogle(),
      expected: PortalAuthError.sessionStorageFailure(message: "write failed")
    )
    XCTAssertEqual(self.web.calls.count, 0)
  }

  func test_signInWithGoogle_willDeleteItsVerifier_whenTheUserClosesTheSheet() async throws {
    self.web.results = [.failure(PortalAuthSignInError.closed)]

    await XCTAssertThrowsAsync(try await self.auth.signInWithGoogle(), expected: PortalAuthSignInError.closed)
    XCTAssertNil(self.verifierStorage.stored)
    XCTAssertEqual(self.verifierStorage.deleteIfCurrentArguments.count, 1)
  }

  func test_signInWithGoogle_willDeleteItsVerifier_whenTheCallbackIsIncomplete() async throws {
    self.web.results = try [.success(AuthTestFixtures.url("\(AuthTestFixtures.redirectUrl)?login_type=GOOGLE"))]

    await XCTAssertThrowsAsync(try await self.auth.signInWithGoogle(), expected: PortalAuthSignInError.callbackIncomplete)
    XCTAssertNil(self.verifierStorage.stored)
  }

  func test_signInWithGoogle_willDeleteItsVerifier_whenTheCallbackReportsAnError() async throws {
    self.web.results = try [.success(AuthTestFixtures.url("\(AuthTestFixtures.redirectUrl)?error=oauth_failed"))]

    await XCTAssertThrowsAsync(
      try await self.auth.signInWithGoogle(),
      expected: PortalAuthError.authenticationFailed(error: "oauth_failed")
    )
    XCTAssertNil(self.verifierStorage.stored)
  }

  func test_signInWithGoogle_willDeleteItsVerifier_whenTheTaskIsCancelled() async throws {
    self.web.holdUntilReleased = true
    let auth = self.auth
    let task = Task { try await auth.signInWithGoogle() }
    let reached = await AuthTestFixtures.pollUntil { self.web.calls.count == 1 }
    XCTAssertTrue(reached)

    task.cancel()
    await XCTAssertThrowsAsync(try await task.value)

    XCTAssertNil(self.verifierStorage.stored)
    XCTAssertEqual(self.tokenRequests.count, 0)
  }

  // MARK: - clearPersistedSession

  func test_clearPersistedSession_willCancelASignInInProgress() async throws {
    _ = try await self.auth.loginWithGoogle()

    try await self.auth.clearPersistedSession()

    XCTAssertNil(self.verifierStorage.stored)
    await XCTAssertThrowsAsync(
      try await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()),
      expected: PortalAuthError.oauthFlowNotStarted
    )
    XCTAssertEqual(self.tokenRequests.count, 0)
  }

  func test_clearPersistedSession_willSucceed_withNoSignInInProgress() async throws {
    try await self.auth.clearPersistedSession()

    XCTAssertEqual(self.verifierStorage.deleteCalls, 1)
    XCTAssertEqual(self.storage.deleteCalls, 1)
  }

  func test_clearPersistedSession_willDeleteTheSession_evenWhenTheVerifierCannotBeDeleted() async throws {
    // A completed magic-link login, so the replay memo holds a grant.
    _ = try self.authenticated(await self.auth.legacy.handleRedirect(AuthTestFixtures.magicLinkRedirect()))
    self.seedPendingSignIn()
    let failure = PortalAuthError.sessionStorageFailure(message: "The sign-in in progress could not be deleted (OSStatus -25308).")
    self.verifierStorage.onDelete = { throw failure }

    await XCTAssertThrowsAsync(try await self.auth.clearPersistedSession(), expected: failure)

    XCTAssertNil(self.storage.stored, "Both deletes are attempted")
    let restored = try await self.auth.restoreSession()
    XCTAssertNil(restored)

    // The memo was dropped too: the re-delivered link is exchanged again, not replayed.
    _ = try await self.auth.legacy.handleRedirect(AuthTestFixtures.magicLinkRedirect())
    XCTAssertEqual(self.requests.requests(toPath: PortalAuthApi.magicLinkValidationsPath).count, 2)
  }

  func test_clearPersistedSession_willThrowTheSessionFailure_andLogTheOther_whenBothDeletesFail() async throws {
    let sessionFailure = PortalAuthError.sessionStorageFailure(message: "The persisted session could not be deleted (OSStatus -25308).")
    self.storage.onDelete = { throw sessionFailure }
    self.verifierStorage.onDelete = { throw PortalAuthError.sessionStorageFailure(message: "verifier") }

    await XCTAssertThrowsAsync(try await self.auth.clearPersistedSession(), expected: sessionFailure)

    XCTAssertTrue(
      self.logger.messages(at: .error).contains { $0.contains("sign-in in progress could not be deleted either") },
      "The verifier failure is logged rather than dropped"
    )
  }

  func test_clearPersistedSession_willNotWaitForAStartWhoseUrlIsInFlight() async throws {
    let auth = self.auth
    self.requests.gateFirstRequest = true
    let start = Task { _ = try await auth.loginWithGoogle() }
    let arrived = await self.requests.waitUntilArrived()
    XCTAssertTrue(arrived)

    // The start holds `flowMutex` across its request; the clear must not wait on it.
    let cleared = try await AuthTestFixtures.withTimeout { try await auth.clearPersistedSession() }
    XCTAssertNotNil(cleared, "clearPersistedSession() stalled behind a sign-in being started")

    // The start finishes after the clear, so it counts as a sign-in started after it.
    self.requests.release()
    try await start.value
    XCTAssertNotNil(self.verifierStorage.stored)
  }

  func test_clearPersistedSession_willCancelASheetThatIsOpen() async throws {
    self.web.holdUntilReleased = true
    let auth = self.auth
    let signIn = Task { _ = try await auth.signInWithGoogle() }
    let reached = await AuthTestFixtures.pollUntil { self.web.calls.count == 1 }
    XCTAssertTrue(reached)

    try await auth.clearPersistedSession()
    self.web.release()

    await XCTAssertThrowsAsync(try await signIn.value, expected: PortalAuthError.oauthFlowNotStarted)
    XCTAssertEqual(self.tokenRequests.count, 0, "The cancelled sheet's grant is never sent")
  }

  // MARK: - clearPersistedSession cancels an exchange in flight

  func test_clearPersistedSession_willCancelAnOAuthExchangeInFlight() async throws {
    self.seedPendingSignIn()
    let auth = self.auth
    self.requests.gateFirstRequest = true
    let exchange = Task { try await auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()) }
    let arrived = await self.requests.waitUntilArrived()
    XCTAssertTrue(arrived)

    let clear = Task { try await auth.clearPersistedSession() }
    let waiting = await AuthTestFixtures.pollUntil { auth.grantMutex.isContended }
    XCTAssertTrue(waiting, "The clear waits for the exchange holding the lock")
    self.requests.release()

    await XCTAssertThrowsAsync(try await exchange.value, expected: PortalAuthError.oauthFlowNotStarted)
    try await clear.value
    XCTAssertEqual(self.storage.setCalls, 0, "No session is written for a cancelled login")
    XCTAssertNil(self.verifierStorage.stored)
    XCTAssertEqual(
      self.verifierStorage.deleteIfCurrentArguments,
      [AuthTestFixtures.rfcCodeVerifier],
      "Portal accepted the grant, so the cancelled login forgets its spent verifier itself"
    )

    // A re-delivered redirect after the clear is refused without a second request.
    await XCTAssertThrowsAsync(
      try await auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()),
      expected: PortalAuthError.oauthFlowNotStarted
    )
    XCTAssertEqual(self.tokenRequests.count, 1)
  }

  func test_clearPersistedSession_willCancelALoginWhoseSessionIsBeingWritten_andLeaveNoSession() async throws {
    self.seedPendingSignIn()
    let auth = self.auth
    // A clear lands while the session is being written. Only the generation moves here, so this
    // also proves the cancelled login removes its own write even if the clear never deletes it.
    self.storage.onSet = { _ in auth.advanceOAuthGeneration() }

    await XCTAssertThrowsAsync(
      try await auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()),
      expected: PortalAuthError.oauthFlowNotStarted
    )

    XCTAssertEqual(self.storage.setCalls, 1)
    XCTAssertNil(self.storage.stored, "The cancelled login removed the session it wrote")
    XCTAssertEqual(self.storage.deleteIfCurrentTokens, [AuthTestFixtures.clientSessionToken])
    self.storage.onSet = nil
    await XCTAssertThrowsAsync(
      try await auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()),
      expected: PortalAuthError.oauthFlowNotStarted,
      "The cancelled login was not memoised, so it does not replay"
    )
    XCTAssertEqual(self.tokenRequests.count, 1)
  }

  func test_clearPersistedSession_willCancelATotpStepInFlight() async throws {
    self.seedPendingSignIn()
    self.answerByPath(grant: AuthTestFixtures.grantResponse(clientSessionToken: nil, userJwt: AuthTestFixtures.userJwt()))
    let auth = self.auth
    self.requests.gateFirstRequest = true
    let exchange = Task { try await auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()) }
    let arrived = await self.requests.waitUntilArrived()
    XCTAssertTrue(arrived)

    let clear = Task { try await auth.clearPersistedSession() }
    let waiting = await AuthTestFixtures.pollUntil { auth.grantMutex.isContended }
    XCTAssertTrue(waiting)
    self.requests.release()

    await XCTAssertThrowsAsync(try await exchange.value, expected: PortalAuthError.oauthFlowNotStarted)
    try await clear.value
    await XCTAssertThrowsAsync(
      try await auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()),
      expected: PortalAuthError.oauthFlowNotStarted,
      "A re-delivered redirect after the clear is refused"
    )
    XCTAssertEqual(self.tokenRequests.count, 1)
  }

  func test_clearPersistedSession_willCancelAnOAuthRedirectWaitingForTheLock() async throws {
    self.seedPendingSignIn()
    let auth = self.auth
    self.requests.gateFirstRequest = true
    let magicLink = Task { try await auth.legacy.handleRedirect(AuthTestFixtures.magicLinkRedirect()) }
    let arrived = await self.requests.waitUntilArrived()
    XCTAssertTrue(arrived)

    // A grant of its own, so only the entry check (not a memo replay of the magic link) can stop it.
    let oauth = Task { try await auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect("oauth-grant")) }
    let oauthWaiting = await AuthTestFixtures.pollUntil { auth.grantMutex.waiterCount == 1 }
    XCTAssertTrue(oauthWaiting)
    let clear = Task { try await auth.clearPersistedSession() }
    let clearWaiting = await AuthTestFixtures.pollUntil { auth.grantMutex.waiterCount == 2 }
    XCTAssertTrue(clearWaiting)
    self.requests.release()

    _ = try self.authenticated(await magicLink.value)
    await XCTAssertThrowsAsync(try await oauth.value, expected: PortalAuthError.oauthFlowNotStarted)
    try await clear.value
    XCTAssertEqual(self.tokenRequests.count, 0, "The redirect queued before the clear never reached /oauth/tokens")
  }

  func test_clearPersistedSession_willNotCancelAMagicLinkExchangeInFlight() async throws {
    let auth = self.auth
    self.requests.gateFirstRequest = true
    let magicLink = Task { try await auth.legacy.handleRedirect(AuthTestFixtures.magicLinkRedirect()) }
    let arrived = await self.requests.waitUntilArrived()
    XCTAssertTrue(arrived)

    let clear = Task { try await auth.clearPersistedSession() }
    let waiting = await AuthTestFixtures.pollUntil { auth.grantMutex.isContended }
    XCTAssertTrue(waiting)
    self.requests.release()

    _ = try self.authenticated(await magicLink.value)
    try await clear.value
    XCTAssertNil(self.storage.stored, "The clear waited for the magic link, then deleted what it persisted")
  }

  func test_clearPersistedSession_willCancelAReplayItLandsDuring() async throws {
    self.seedPendingSignIn()
    let auth = self.auth
    // The first delivery's write fails, so the memo keeps the session to write on a replay.
    self.storage.onSet = { _ in throw PortalAuthError.sessionStorageFailure(message: "write failed") }
    await XCTAssertThrowsAsync(try await auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()))

    // The replay's write is where the clear lands.
    self.storage.onSet = { _ in auth.advanceOAuthGeneration() }
    await XCTAssertThrowsAsync(
      try await auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()),
      expected: PortalAuthError.oauthFlowNotStarted
    )
    XCTAssertEqual(self.tokenRequests.count, 1, "The replay never re-sent the grant")
    XCTAssertNil(self.storage.stored, "The write the cancelled replay made was removed")

    // The memo went with it: a third delivery is refused instead of replaying.
    self.storage.onSet = nil
    await XCTAssertThrowsAsync(
      try await auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()),
      expected: PortalAuthError.oauthFlowNotStarted
    )
    XCTAssertEqual(self.tokenRequests.count, 1)
  }

  func test_clearPersistedSession_willCancelAReplayWhoseWriteFails_withNothingKeptToRetry() async throws {
    self.seedPendingSignIn()
    let auth = self.auth
    // The first delivery's write fails, leaving the memo with a write pending for a replay.
    self.storage.onSet = { _ in throw PortalAuthError.sessionStorageFailure(message: "write failed") }
    await XCTAssertThrowsAsync(try await auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()))

    // The replay's write fails too, and a clear lands during it.
    self.storage.onSet = { _ in
      auth.advanceOAuthGeneration()
      throw PortalAuthError.sessionStorageFailure(message: "write failed")
    }
    await XCTAssertThrowsAsync(
      try await auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()),
      expected: PortalAuthError.oauthFlowNotStarted
    )

    // Had the pending write survived, this delivery (captured after the clear) would finish it.
    self.storage.onSet = nil
    await XCTAssertThrowsAsync(
      try await auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()),
      expected: PortalAuthError.oauthFlowNotStarted
    )
    XCTAssertNil(self.storage.stored)
    XCTAssertEqual(self.tokenRequests.count, 1)
  }

  func test_clearPersistedSession_willCancelALoginWhoseWriteFails_withNothingKeptToRetry() async throws {
    self.seedPendingSignIn()
    let auth = self.auth
    self.storage.onSet = { _ in
      auth.advanceOAuthGeneration()
      throw PortalAuthError.sessionStorageFailure(message: "write failed")
    }

    await XCTAssertThrowsAsync(
      try await auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()),
      expected: PortalAuthError.oauthFlowNotStarted
    )

    self.storage.onSet = nil
    await XCTAssertThrowsAsync(
      try await auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()),
      expected: PortalAuthError.oauthFlowNotStarted,
      "The cancelled login kept no pending write for a replay to finish"
    )
    XCTAssertNil(self.storage.stored)
  }

  func test_clearPersistedSession_landingAfterTheResponse_willRecordNoTotpStep() async throws {
    self.seedPendingSignIn()
    self.answerByPath(grant: AuthTestFixtures.grantResponse(clientSessionToken: nil, userJwt: AuthTestFixtures.userJwt()))
    let auth = self.auth
    // Forgetting the spent verifier runs between the post-request check and the memo; land the
    // clear exactly there, with only the generation moving, so only the TOTP check can stop it.
    self.verifierStorage.onDeleteIfCurrent = { _ in auth.advanceOAuthGeneration() }

    await XCTAssertThrowsAsync(
      try await auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()),
      expected: PortalAuthError.oauthFlowNotStarted
    )

    // Had the step been memoised, this delivery (captured after the clear) would replay it.
    self.verifierStorage.onDeleteIfCurrent = nil
    await XCTAssertThrowsAsync(
      try await auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()),
      expected: PortalAuthError.oauthFlowNotStarted
    )
    XCTAssertEqual(self.tokenRequests.count, 1)
  }

  func test_clearPersistedSession_landingAfterTheResponse_willWriteNoSession() async throws {
    self.seedPendingSignIn()
    let auth = self.auth
    self.verifierStorage.onDeleteIfCurrent = { _ in auth.advanceOAuthGeneration() }

    await XCTAssertThrowsAsync(
      try await auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()),
      expected: PortalAuthError.oauthFlowNotStarted
    )
    XCTAssertEqual(self.storage.setCalls, 0, "Refused before the memo and the write")

    self.verifierStorage.onDeleteIfCurrent = nil
    await XCTAssertThrowsAsync(
      try await auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()),
      expected: PortalAuthError.oauthFlowNotStarted
    )
  }

  func test_clearPersistedSession_willStillCancel_whenTheCancelledWriteCannotBeRemoved() async throws {
    self.seedPendingSignIn()
    let auth = self.auth
    self.storage.onSet = { _ in auth.advanceOAuthGeneration() }
    self.storage.onDeleteIfCurrent = { _ in throw PortalAuthError.sessionStorageFailure(message: "delete failed") }

    await XCTAssertThrowsAsync(
      try await auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()),
      expected: PortalAuthError.oauthFlowNotStarted
    )
    XCTAssertTrue(self.logger.messages(at: .warn).contains { $0.contains("could not be removed") })
  }

  func test_signInAfterAFinishedClear_willComplete() async throws {
    try await self.auth.clearPersistedSession()

    _ = try await self.auth.loginWithGoogle()
    let result = try self.authenticated(await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()))

    XCTAssertEqual(try result.session.getToken(), AuthTestFixtures.clientSessionToken, "A clear never cancels a sign-in started after it")
  }

  func test_clearPersistedSession_willStopARedeliveredOAuthRedirectFromReplaying() async throws {
    self.seedPendingSignIn()
    _ = try self.authenticated(await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()))

    try await self.auth.clearPersistedSession()

    await XCTAssertThrowsAsync(
      try await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect()),
      expected: PortalAuthError.oauthFlowNotStarted
    )
    XCTAssertEqual(self.tokenRequests.count, 1)
  }

  func test_clearPersistedSession_willAdvanceTheGeneration_evenWhenTheDeletesFail() async throws {
    self.storage.onDelete = { throw PortalAuthError.sessionStorageFailure(message: "delete failed") }
    let before = self.auth.currentOAuthGeneration()

    await XCTAssertThrowsAsync(try await self.auth.clearPersistedSession())

    XCTAssertEqual(self.auth.currentOAuthGeneration(), before + 1)
  }

  // MARK: - Secrets

  func test_oauthSignIn_willSendTheVerifierOnlyInTheExchangeBody_andNeverLogIt() async throws {
    PortalLogger.shared.setLogLevel(.debug)
    defer { PortalLogger.shared.setLogLevel(.none) }

    _ = try await self.auth.loginWithGoogle()
    let started = try XCTUnwrap(self.verifierStorage.stored)
    let challenge = PkceCodeVerifier.challenge(for: started.verifier)
    _ = try await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect())
    await XCTAssertThrowsAsync(try await self.auth.legacy.handleRedirect(AuthTestFixtures.oauthRedirect("unsolicited")))

    for request in self.requests.recorded {
      XCTAssertFalse(request.absoluteString.contains(started.verifier), "The verifier must never travel in a URL")
      XCTAssertFalse(request.headers.values.contains { $0.contains(started.verifier) }, "The verifier must never travel in a header")
    }
    XCTAssertEqual(self.tokenRequests.count, 1)
    self.logger.assertNoSecret(started.verifier)
    self.logger.assertNoSecret(challenge)
  }

  func test_oauthGrantTokenRequest_willRedactWhenPrinted() {
    let request = OAuthGrantTokenRequest(token: "grant-secret", codeVerifier: AuthTestFixtures.rfcCodeVerifier)

    var dumped = ""
    dump(request, to: &dumped)
    for rendering in [String(describing: request), String(reflecting: request), dumped] {
      XCTAssertFalse(rendering.contains("grant-secret"), rendering)
      XCTAssertFalse(rendering.contains(AuthTestFixtures.rfcCodeVerifier), rendering)
    }
  }

  func test_oauthFlowNotStarted_willDescribeItselfWithoutASecret() {
    XCTAssertEqual(
      PortalAuthError.oauthFlowNotStarted.errorDescription,
      "[PortalAuth] The login could not be completed. Start a new login."
    )
  }
}
