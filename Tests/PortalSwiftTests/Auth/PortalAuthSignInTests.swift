//
//  PortalAuthSignInTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import AuthenticationServices
import Foundation
@testable import PortalSwift
import XCTest

// MARK: - Fixtures

/// The constants the SDK-owned sign-in flow is driven with.
///
/// Deliberately separate from `AuthTestFixtures.redirectUrl`: `signInWith*` is the only flow
/// that cares about the *shape* of the redirect (it must be a custom scheme, and its scheme
/// becomes `ASWebAuthenticationSession`'s `callbackURLScheme`), so this file pins a short,
/// obviously-custom `myapp://auth/callback` and derives every callback URL from it. The grant
/// token, session token and authorize URLs are distinct strings so a log-leak assertion can
/// look for each one individually.
private enum SignInFixtures {
  static let authEnvironmentId = "env-1"
  static let redirectUrl = "myapp://auth/callback"
  static let callbackScheme = "myapp"
  static let endUserId = "user-1"
  static let clientId = "client-1"
  static let clientSessionToken = "sign-in-session-token"
  static let grantToken = "grant-123"
  static let secondGrantToken = "grant-456"
  static let thirdGrantToken = "grant-789"
  static let totpSecret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"

  static let googleAuthorizeUrl = AuthTestFixtures.googleAuthorizeUrl
  static let appleAuthorizeUrl = AuthTestFixtures.appleAuthorizeUrl

  /// The Google callback the fake browser hands back by default.
  static let googleCallback = "\(redirectUrl)?token=\(grantToken)&login_type=GOOGLE"
  /// The Apple callback: same endpoint, different marker.
  static let appleCallback = "\(redirectUrl)?token=\(grantToken)&login_type=APPLE"
  /// An `otpauth://` link that embeds a TOTP secret and an email — never loggable.
  static let totpLink = "otpauth://totp/Portal:user@example.com?secret=\(totpSecret)&issuer=Portal"

  /// A callback carrying `token`, marked as coming from `loginType`.
  static func callback(token: String, loginType: String = "GOOGLE") -> String {
    "\(redirectUrl)?token=\(token)&login_type=\(loginType)"
  }

  /// The `GET /oauth/urls` body with both providers enabled.
  static var oauthUrlsBody: Data {
    AuthTestFixtures.oauthUrls(google: self.googleAuthorizeUrl, apple: self.appleAuthorizeUrl)
  }

  /// The grant-exchange body of a completed login.
  static var grantBody: Data {
    AuthTestFixtures.grant(cst: self.clientSessionToken, endUserId: self.endUserId, clientId: self.clientId)
  }
}

// MARK: - Test helpers

/// Failures raised by this file's own bounded-wait and result-shape helpers, so a hang or an
/// unexpected `AuthResult` case ends the test instead of trapping.
private enum SignInTestError: LocalizedError {
  case timedOut(String)
  case unexpectedResult(String)

  var errorDescription: String? {
    switch self {
    case let .timedOut(what):
      return "PortalAuthSignInTests: \(what) did not finish within 2 s."
    case let .unexpectedResult(what):
      return "PortalAuthSignInTests: \(what)."
    }
  }
}

/// An ordered, lock-guarded log of named moments, for the ordering assertions ("persist
/// happened before the value was returned") the storage double cannot express on its own.
private final class RecordedEvents: @unchecked Sendable {
  private let lock = NSLock()
  private var _entries: [String] = []

  func append(_ entry: String) {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._entries.append(entry)
  }

  var entries: [String] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._entries
  }
}

/// Collects the outcome of concurrently started sign-ins. Lock-guarded because the attempts
/// finish on whatever executor resumed them.
private final class SignInOutcomes: @unchecked Sendable {
  private let lock = NSLock()
  private var _results: [AuthResult] = []
  private var _errors: [Error] = []

  func record(_ result: AuthResult) {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._results.append(result)
  }

  func record(_ error: Error) {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._errors.append(error)
  }

  var results: [AuthResult] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._results
  }

  var errors: [Error] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._errors
  }

  var successCount: Int {
    self.results.count
  }

  var failureCount: Int {
    self.errors.count
  }

  var total: Int {
    self.successCount + self.failureCount
  }
}

/// A lock-guarded weak box.
///
/// The retention tests have to read a `weak` reference from inside an escaping poll closure,
/// which a local `weak var` cannot be captured into; boxing it also keeps the read under one
/// lock so the polling task and the completion handler cannot race on it.
private final class WeakRef<T: AnyObject>: @unchecked Sendable {
  private let lock = NSLock()
  private weak var _value: T?

  var value: T? {
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

/// Keeps every fake session handle the adapter built alive for the length of a test.
///
/// `FakeWebAuthenticationSessionHandle.Recorder` holds its handles *weakly* on purpose (that
/// is what makes the retention tests meaningful), so any case that asserts on a handle after
/// the adapter has finished with it — `cancelCalls`, `startedOnMainThread` — needs its own
/// strong reference.
private final class RetainedHandles: @unchecked Sendable {
  private let lock = NSLock()
  private var _handles: [FakeWebAuthenticationSessionHandle] = []

  func append(_ handle: FakeWebAuthenticationSessionHandle) {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._handles.append(handle)
  }

  var handles: [FakeWebAuthenticationSessionHandle] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._handles
  }

  var latest: FakeWebAuthenticationSessionHandle? {
    self.handles.last
  }

  var count: Int {
    self.handles.count
  }
}

// MARK: - PortalAuthSignInTests

/// Covers the browser-owning sign-in path: `PortalAuth.signInWithGoogle()` /
/// `signInWithApple()`, the anchor and ephemeral-session preferences that feed it, and the
/// `ASWebAuthenticationSessionAdapter` that talks to `ASWebAuthenticationSession`.
///
/// No test presents UI or reaches the network. `FakeAuthWebSession` stands in for the browser
/// through `PortalAuth`'s `webSessionFactory` seam and can park an attempt mid-flight, which
/// is how the in-flight guard, the ephemeral snapshot, cancellation and "the grant mutex is
/// not held while the browser is open" are observed. The adapter cases drive the real adapter
/// through its `sessionFactory` seam with `FakeWebAuthenticationSessionHandle`, so the
/// ordering contracts it exists to keep — provider and ephemeral flag assigned *before*
/// `start()`, `start()` on the main thread, the session and its
/// `AuthPresentationAnchorProvider` retained until the completion fires, the continuation
/// resumed exactly once — are asserted rather than assumed.
///
/// Every `await` on the module is bounded at 2 s (`awaitSignIn` / `awaitBounded`) so a lock or
/// continuation regression fails the case instead of hanging the suite, and every wait for
/// state a test cannot `await` is a bounded poll. The logger sink is captured for every case,
/// so the "never logs a secret" assertions are real.
final class PortalAuthSignInTests: XCTestCase {
  private var requests = RecordingPortalRequests()
  private var storage = MockAuthSessionStorage()
  private var web = FakeAuthWebSession()
  private var logger = RecordingLogger()
  private var anchor = MockAuthenticationAnchor()
  private var subject = PortalAuthSignInTests.makePlaceholderAuth()

  override func setUpWithError() throws {
    try super.setUpWithError()
    CredentialInvalidationRegistry.shared.resetForTesting()

    self.requests = RecordingPortalRequests()
    self.storage = MockAuthSessionStorage()
    self.web = try FakeAuthWebSession(results: [.success(AuthTestFixtures.url(SignInFixtures.googleCallback))])
    self.logger = RecordingLogger()
    // Created here rather than in a test body: `ASPresentationAnchor` is a `UIWindow`, whose
    // initializer is main-actor isolated, and `setUpWithError` is the synchronous context
    // where building one is free of an actor hop.
    self.anchor = MockAuthenticationAnchor()

    self.installResponder()
    self.subject = self.makeAuth()
  }

  override func tearDownWithError() throws {
    self.logger.uninstall()
    CredentialInvalidationRegistry.shared.resetForTesting()
    try super.tearDownWithError()
  }

  // MARK: - Fixtures and factories

  /// A throwaway instance so `subject` can be a non-optional `let`-like property without a
  /// force unwrap; `setUpWithError` replaces it with one wired to this case's doubles.
  private static func makePlaceholderAuth() -> PortalAuth {
    PortalAuth(
      redirectUrl: SignInFixtures.redirectUrl,
      api: PortalAuthApi(
        authEnvironmentId: SignInFixtures.authEnvironmentId,
        apiHost: AuthTestFixtures.apiHost,
        requests: RecordingPortalRequests()
      ),
      storage: MockAuthSessionStorage()
    )
  }

  /// A `PortalAuth` over this case's transport, storage, logger and fake browser.
  ///
  /// - Parameters:
  ///   - redirectUrl: The configured redirect; vary it to exercise the custom-scheme rule.
  ///   - anchored: Whether `setAuthPresentationAnchor(_:)` is called with this case's anchor.
  private func makeAuth(redirectUrl: String = SignInFixtures.redirectUrl, anchored: Bool = true) -> PortalAuth {
    let auth = AuthTestFixtures.makeAuth(
      requests: self.requests,
      storage: self.storage,
      logger: self.logger,
      redirectUrl: redirectUrl,
      authEnvironmentId: SignInFixtures.authEnvironmentId,
      webSessionFactory: self.web.factory
    )
    if anchored {
      auth.setAuthPresentationAnchor(self.anchor)
    }
    return auth
  }

  /// Answers the transport **by path** rather than from a FIFO queue.
  ///
  /// A queue would hand the next scripted body to whichever request happened to arrive first,
  /// and several cases here deliberately interleave a second attempt, a concurrent
  /// `loginWithGoogle()` or a magic-link redirect with a parked sign-in; answering by path
  /// keeps every one of them deterministic. Cases that need a *sequence* use
  /// `RecordingPortalRequests.fail(with:onPath:)` or re-install this responder between
  /// attempts.
  private func installResponder(
    oauthUrls: Data = SignInFixtures.oauthUrlsBody,
    grant: Data = SignInFixtures.grantBody
  ) {
    self.requests.responder = { request in
      if request.matches(path: PortalAuthApi.oauthUrlsPath) {
        return oauthUrls
      }
      return grant
    }
  }

  /// The recorded `GET /oauth/urls` calls.
  private var oauthUrlRequests: [RecordedRequest] {
    self.requests.requests(toPath: PortalAuthApi.oauthUrlsPath)
  }

  /// The recorded `POST /oauth/tokens` calls — the grant exchanges.
  private var tokenExchangeRequests: [RecordedRequest] {
    self.requests.requests(toPath: PortalAuthApi.oauthTokensPath)
  }

  // MARK: - Waiting

  /// Awaits a sign-in with a 2 s ceiling, so a regression in the in-flight guard or in
  /// `AsyncMutex` fails this case instead of hanging the suite. Errors propagate unchanged.
  @discardableResult
  private func awaitSignIn(
    file: StaticString = #filePath,
    line: UInt = #line,
    _ operation: @escaping @Sendable () async throws -> AuthResult
  ) async throws -> AuthResult {
    try await self.awaitBounded("The sign-in", file: file, line: line, operation)
  }

  /// `awaitSignIn` for any awaited value.
  @discardableResult
  private func awaitBounded<T>(
    _ description: String,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ operation: @escaping @Sendable () async throws -> T
  ) async throws -> T {
    guard let value = try await withTimeout(2, operation) else {
      XCTFail("\(description) did not finish within 2 s.", file: file, line: line)
      throw SignInTestError.timedOut(description)
    }
    return value
  }

  /// Starts a sign-in as an unstructured task, so the test can observe the module while the
  /// attempt is parked in the fake browser.
  private func startSignIn(_ method: AuthMethod = .google) -> Task<AuthResult, Error> {
    let subject = self.subject
    return Task {
      if method == .apple {
        return try await subject.signInWithApple()
      }
      return try await subject.signInWithGoogle()
    }
  }

  /// Bounded poll until the fake browser has been reached `calls` times.
  private func waitForBrowser(calls: Int = 1, file: StaticString = #filePath, line: UInt = #line) async {
    let arrived = await waitUntil { self.web.calls.count >= calls }
    XCTAssertTrue(arrived, "The browser session was not reached \(calls) time(s) within 2 s.", file: file, line: line)
  }

  // MARK: - Result shape

  /// Unwraps an `.authenticated` result, failing the case (rather than trapping) otherwise.
  private func authenticated(
    _ result: AuthResult,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws -> AuthenticatedResult {
    guard case let .authenticated(authenticated) = result else {
      XCTFail("Expected an authenticated result, got \(result).", file: file, line: line)
      throw SignInTestError.unexpectedResult("the result was not .authenticated")
    }
    return authenticated
  }

  /// Unwraps a `.totpRequired` result.
  private func totpRequired(
    _ result: AuthResult,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws -> TotpRequiredResult {
    guard case let .totpRequired(step) = result else {
      XCTFail("Expected a totpRequired result, got \(result).", file: file, line: line)
      throw SignInTestError.unexpectedResult("the result was not .totpRequired")
    }
    return step
  }
}

// MARK: - Preconditions

extension PortalAuthSignInTests {
  func test_signInWithGoogle_willThrowUnavailable_whenNoAnchor() async throws {
    let auth = self.makeAuth(anchored: false)

    await XCTAssertThrowsAsync(
      try await self.awaitSignIn { try await auth.signInWithGoogle() },
      expected: PortalAuthSignInError.unavailable
    )

    XCTAssertEqual(self.requests.count, 0, "The authorize URL must not be fetched without an anchor")
    XCTAssertTrue(self.web.calls.isEmpty)
    XCTAssertEqual(self.web.factoryInvocations, 0, "No browser session may be built")
  }

  func test_signInWithApple_willThrowUnavailable_whenNoAnchor() async throws {
    let auth = self.makeAuth(anchored: false)

    await XCTAssertThrowsAsync(
      try await self.awaitSignIn { try await auth.signInWithApple() },
      expected: PortalAuthSignInError.unavailable
    )

    XCTAssertEqual(self.requests.count, 0)
    XCTAssertTrue(self.web.calls.isEmpty)
    XCTAssertEqual(self.web.factoryInvocations, 0)
  }

  func test_signInWithGoogle_willThrowUnavailable_whenAnchorDeallocated() async throws {
    let auth = self.makeAuth(anchored: false)
    let anchorRef = WeakRef<MockAuthenticationAnchor>()

    // The anchor is held weakly, so a window the host has released must fail the sign-in
    // rather than resurrect it. Built and dropped on the main actor because it is a `UIWindow`.
    await MainActor.run {
      autoreleasepool {
        let localAnchor = MockAuthenticationAnchor()
        anchorRef.value = localAnchor
        auth.setAuthPresentationAnchor(localAnchor)
      }
    }

    let released = await waitUntil { autoreleasepool { anchorRef.value == nil } }
    XCTAssertTrue(released, "The local anchor was still alive; the case cannot prove the weak reference")

    await XCTAssertThrowsAsync(
      try await self.awaitSignIn { try await auth.signInWithGoogle() },
      expected: PortalAuthSignInError.unavailable
    )
    XCTAssertEqual(self.requests.count, 0)
    XCTAssertTrue(self.web.calls.isEmpty)
  }

  func test_signInWithGoogle_willThrowUnavailable_whenRedirectUrlIsHttps() async throws {
    let auth = self.makeAuth(redirectUrl: "https://app.example/cb")

    await XCTAssertThrowsAsync(
      try await self.awaitSignIn { try await auth.signInWithGoogle() },
      expected: PortalAuthSignInError.unavailable
    )

    XCTAssertEqual(self.requests.count, 0, "A Universal Link redirect fails before any request")
    XCTAssertTrue(self.web.calls.isEmpty)
  }

  func test_signInWithGoogle_willThrowUnavailable_whenRedirectUrlIsHttp() async throws {
    let auth = self.makeAuth(redirectUrl: "http://localhost/cb")

    await XCTAssertThrowsAsync(
      try await self.awaitSignIn { try await auth.signInWithGoogle() },
      expected: PortalAuthSignInError.unavailable
    )

    XCTAssertEqual(self.requests.count, 0)
    XCTAssertTrue(self.web.calls.isEmpty)
  }

  func test_signInWithGoogle_willThrowUnavailable_whenRedirectUrlHasNoScheme() async throws {
    // Accepted by `init` (it is not blank) but `RedirectUrl.customScheme(of:)` yields `nil`.
    let auth = self.makeAuth(redirectUrl: "myapp/auth/callback")

    await XCTAssertThrowsAsync(
      try await self.awaitSignIn { try await auth.signInWithGoogle() },
      expected: PortalAuthSignInError.unavailable
    )

    XCTAssertEqual(self.requests.count, 0)
    XCTAssertTrue(self.web.calls.isEmpty)
  }

  func test_signInWithGoogle_willLowercaseCallbackScheme() async throws {
    let auth = self.makeAuth(redirectUrl: "MyApp://Auth/Callback")
    self.web.results = try [.success(AuthTestFixtures.url("MyApp://Auth/Callback?token=\(SignInFixtures.grantToken)&login_type=GOOGLE"))]

    let result = try await self.awaitSignIn { try await auth.signInWithGoogle() }

    _ = try self.authenticated(result)
    XCTAssertEqual(self.web.calls.first?.callbackURLScheme, "myapp", "The callback scheme is lowercased for ASWebAuthenticationSession")
  }

  func test_signInWithGoogle_willNotLeaveGuardHeld_whenPreconditionFails() async throws {
    let auth = self.makeAuth(anchored: false)

    await XCTAssertThrowsAsync(
      try await self.awaitSignIn { try await auth.signInWithGoogle() },
      expected: PortalAuthSignInError.unavailable
    )

    auth.setAuthPresentationAnchor(self.anchor)
    let result = try await self.awaitSignIn { try await auth.signInWithGoogle() }

    _ = try self.authenticated(result)
    XCTAssertEqual(self.web.calls.count, 1, "The failed precondition released the in-flight guard")
  }
}

// MARK: - Authorize URL

extension PortalAuthSignInTests {
  func test_signInWithGoogle_willPassFreshAuthorizeUrlToSession() async throws {
    let subject = self.subject

    let result = try await self.awaitSignIn { try await subject.signInWithGoogle() }

    _ = try self.authenticated(result)
    XCTAssertEqual(self.web.calls.first?.url.absoluteString, SignInFixtures.googleAuthorizeUrl)
    let first = try XCTUnwrap(self.requests.recorded.first)
    XCTAssertEqual(first.path, PortalAuthApi.oauthUrlsPath)
    XCTAssertEqual(first.method, .get)
  }

  func test_signInWithApple_willPassAppleUrlToSession() async throws {
    let subject = self.subject
    self.web.results = try [.success(AuthTestFixtures.url(SignInFixtures.appleCallback))]

    let result = try await self.awaitSignIn { try await subject.signInWithApple() }

    _ = try self.authenticated(result)
    XCTAssertEqual(self.web.calls.first?.url.absoluteString, SignInFixtures.appleAuthorizeUrl)
  }

  func test_signInWithGoogle_willFetchFreshUrlPerAttempt() async throws {
    let subject = self.subject
    self.web.results = try [
      .success(AuthTestFixtures.url(SignInFixtures.googleCallback)),
      .success(AuthTestFixtures.url(SignInFixtures.callback(token: SignInFixtures.secondGrantToken)))
    ]

    _ = try await self.awaitSignIn { try await subject.signInWithGoogle() }
    _ = try await self.awaitSignIn { try await subject.signInWithGoogle() }

    XCTAssertEqual(self.oauthUrlRequests.count, 2, "The single-use state means one URL per attempt")
    XCTAssertEqual(self.web.calls.count, 2)
  }

  func test_signInWithGoogle_willRequestOauthUrlsWithEncodedRedirectAndHeader() async throws {
    let subject = self.subject

    _ = try await self.awaitSignIn { try await subject.signInWithGoogle() }

    let request = try XCTUnwrap(self.oauthUrlRequests.first)
    XCTAssertEqual(request.query, "redirectUrl=myapp%3A%2F%2Fauth%2Fcallback", "The backend matches the redirect byte-for-byte")
    XCTAssertEqual(request.header(PortalAuthApi.authEnvironmentIdHeader), SignInFixtures.authEnvironmentId)
    XCTAssertNil(request.bearerToken)
  }

  func test_signInWithGoogle_willThrowAuthMethodUnavailable_whenGoogleMissing() async throws {
    let subject = self.subject
    self.installResponder(oauthUrls: AuthTestFixtures.oauthUrls(google: nil, apple: SignInFixtures.appleAuthorizeUrl))

    await XCTAssertThrowsAsync(
      try await self.awaitSignIn { try await subject.signInWithGoogle() },
      expected: PortalAuthError.authMethodUnavailable(.google)
    )
    XCTAssertTrue(self.web.calls.isEmpty, "No browser opens for a provider the environment has not enabled")

    // The guard was released: a later attempt against a healthy environment proceeds.
    self.installResponder()
    let result = try await self.awaitSignIn { try await subject.signInWithGoogle() }
    _ = try self.authenticated(result)
  }

  func test_signInWithApple_willThrowAuthMethodUnavailable_whenAppleBlank() async throws {
    let subject = self.subject
    self.installResponder(oauthUrls: AuthTestFixtures.oauthUrls(google: SignInFixtures.googleAuthorizeUrl, apple: ""))

    await XCTAssertThrowsAsync(
      try await self.awaitSignIn { try await subject.signInWithApple() },
      expected: PortalAuthError.authMethodUnavailable(.apple)
    )
    XCTAssertTrue(self.web.calls.isEmpty)
  }

  func test_signInWithGoogle_willPropagateTransportError_whenUrlFetchFails() async throws {
    let subject = self.subject
    self.requests.fail(with: URLError(.notConnectedToInternet), onPath: PortalAuthApi.oauthUrlsPath)

    await XCTAssertThrowsAsync(try await self.awaitSignIn { try await subject.signInWithGoogle() }) { error in
      XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet, "A transport failure is not remapped")
    }

    XCTAssertTrue(self.web.calls.isEmpty)
    XCTAssertEqual(self.storage.setCalls, 0)
  }
}

// MARK: - Browser session configuration

extension PortalAuthSignInTests {
  func test_signInWithGoogle_willDeriveCallbackSchemeFromRedirectUrl() async throws {
    let subject = self.subject

    _ = try await self.awaitSignIn { try await subject.signInWithGoogle() }

    XCTAssertEqual(self.web.calls.first?.callbackURLScheme, SignInFixtures.callbackScheme)
  }

  func test_signInWithGoogle_willPassConfiguredAnchor() async throws {
    let subject = self.subject

    _ = try await self.awaitSignIn { try await subject.signInWithGoogle() }

    let call = try XCTUnwrap(self.web.calls.first)
    XCTAssertTrue(call.anchor === self.anchor, "The sheet is presented from the registered anchor")
  }

  func test_signInWithGoogle_willDefaultPrefersEphemeralToFalse() async throws {
    let subject = self.subject
    XCTAssertFalse(subject.prefersEphemeralWebBrowserSession, "One-tap sign-in is the default")

    _ = try await self.awaitSignIn { try await subject.signInWithGoogle() }

    XCTAssertEqual(self.web.calls.first?.prefersEphemeral, false)
  }

  func test_signInWithGoogle_willPassPrefersEphemeralTrue_whenSet() async throws {
    let subject = self.subject
    subject.prefersEphemeralWebBrowserSession = true

    _ = try await self.awaitSignIn { try await subject.signInWithGoogle() }

    XCTAssertEqual(self.web.calls.first?.prefersEphemeral, true)
  }

  func test_signInWithGoogle_willSnapshotEphemeralAtCallTime() async throws {
    let subject = self.subject
    subject.prefersEphemeralWebBrowserSession = false
    self.web.results = try [
      .success(AuthTestFixtures.url(SignInFixtures.googleCallback)),
      .success(AuthTestFixtures.url(SignInFixtures.callback(token: SignInFixtures.secondGrantToken)))
    ]
    self.web.holdUntilReleased = true

    let task = self.startSignIn(.google)
    await self.waitForBrowser()
    // Flipped while the browser is open: the running attempt keeps the value it started with.
    subject.prefersEphemeralWebBrowserSession = true
    self.web.release()
    _ = try await self.awaitBounded("The first sign-in") { try await task.value }

    XCTAssertEqual(self.web.calls.first?.prefersEphemeral, false)

    _ = try await self.awaitSignIn { try await subject.signInWithGoogle() }
    XCTAssertEqual(self.web.calls.count, 2)
    XCTAssertEqual(self.web.calls.last?.prefersEphemeral, true, "The next attempt reads the new value")
  }
}

// MARK: - Results and persistence

extension PortalAuthSignInTests {
  func test_signInWithGoogle_willReturnAuthenticated_andPersistSession() async throws {
    let subject = self.subject

    let result = try await self.awaitSignIn { try await subject.signInWithGoogle() }

    let authenticated = try self.authenticated(result)
    XCTAssertEqual(authenticated.clientId, SignInFixtures.clientId)
    XCTAssertEqual(authenticated.session.endUserId, SignInFixtures.endUserId)
    XCTAssertEqual(try authenticated.session.getToken(), SignInFixtures.clientSessionToken)

    XCTAssertEqual(self.storage.setCalls, 1)
    let stored = try XCTUnwrap(self.storage.storedJSON)
    XCTAssertEqual(stored["clientSessionToken"] as? String, SignInFixtures.clientSessionToken)
    XCTAssertEqual(stored["endUserId"] as? String, SignInFixtures.endUserId)
    XCTAssertEqual(stored.count, 2, "Only the two persisted fields are written")

    XCTAssertEqual(self.tokenExchangeRequests.count, 1)
    let exchange = try XCTUnwrap(self.tokenExchangeRequests.first)
    XCTAssertEqual(exchange.method, .post)
    XCTAssertEqual(exchange.payloadJSON?["token"] as? String, SignInFixtures.grantToken)
    XCTAssertEqual(exchange.payloadJSON?.count, 1)
  }

  func test_signInWithApple_willReturnAuthenticated() async throws {
    let subject = self.subject
    self.web.results = try [.success(AuthTestFixtures.url(SignInFixtures.appleCallback))]

    let result = try await self.awaitSignIn { try await subject.signInWithApple() }

    let authenticated = try self.authenticated(result)
    XCTAssertEqual(try authenticated.session.getToken(), SignInFixtures.clientSessionToken)
    XCTAssertEqual(self.tokenExchangeRequests.count, 1, "Apple grants go to the same endpoint as Google ones")
  }

  func test_signInWithGoogle_willPersistBeforeReturning() async throws {
    let subject = self.subject
    let events = RecordedEvents()
    self.storage.onSet = { _ in events.append("set") }

    let result = try await self.awaitSignIn { try await subject.signInWithGoogle() }
    events.append("returned")

    XCTAssertEqual(events.entries, ["set", "returned"], "A session is persisted before it is handed back")
    let authenticated = try self.authenticated(result)
    XCTAssertEqual(try authenticated.session.getToken(), SignInFixtures.clientSessionToken)
  }

  func test_signInWithGoogle_willThrowSessionStorageFailure_whenPersistFails() async throws {
    let subject = self.subject
    let failure = PortalAuthError.sessionStorageFailure(message: "The session could not be persisted.")
    self.storage.onSet = { _ in throw failure }

    await XCTAssertThrowsAsync(
      try await self.awaitSignIn { try await subject.signInWithGoogle() },
      expected: failure
    )
    XCTAssertEqual(self.tokenExchangeRequests.count, 1)

    // The backend burned the grant when it answered, so the issued session was memoised before
    // the write: a re-delivered callback retries the Keychain write — still failing here — and
    // never re-sends a token the backend has already spent.
    await XCTAssertThrowsAsync(
      try await self.awaitBounded("The replayed redirect") { try await subject.handleRedirect(SignInFixtures.googleCallback) },
      expected: failure
    )
    XCTAssertEqual(self.tokenExchangeRequests.count, 1, "A spent grant is never exchanged twice")

    // Once the Keychain recovers, the same redirect completes the login the first attempt
    // could not, again without going back to the backend.
    self.storage.onSet = nil
    let result = try await self.awaitBounded("The recovered redirect") { try await subject.handleRedirect(SignInFixtures.googleCallback) }
    let authenticated = try self.authenticated(XCTUnwrap(result, "The recovered redirect must still be recognised as ours"))
    XCTAssertEqual(try authenticated.session.getToken(), SignInFixtures.clientSessionToken)
    XCTAssertEqual(self.tokenExchangeRequests.count, 1)
  }

  func test_signInWithGoogle_willReturnTotpRequired_whenGrantYieldsUserJwt() async throws {
    let subject = self.subject
    let userJwt = AuthTestFixtures.userJwt(endUserId: SignInFixtures.endUserId)
    self.installResponder(grant: AuthTestFixtures.grant(
      cst: nil,
      endUserId: SignInFixtures.endUserId,
      userJwt: userJwt,
      totpLink: SignInFixtures.totpLink
    ))

    let result = try await self.awaitSignIn { try await subject.signInWithGoogle() }

    let step = try self.totpRequired(result)
    XCTAssertEqual(step.userJwt, userJwt)
    XCTAssertEqual(step.totpLink, SignInFixtures.totpLink)
    XCTAssertEqual(step.endUserId, SignInFixtures.endUserId)
    XCTAssertEqual(self.storage.setCalls, 0, "Nothing is persisted until the code is verified")
  }
}

// MARK: - Callback handling

extension PortalAuthSignInTests {
  func test_signInWithGoogle_willHandCallbackToHandleRedirectVerbatim() async throws {
    let subject = self.subject
    self.web.results = try [.success(AuthTestFixtures.url("\(SignInFixtures.redirectUrl)?next=%2Fhome&token=a%2Bb&login_type=GOOGLE"))]

    let result = try await self.awaitSignIn { try await subject.signInWithGoogle() }

    _ = try self.authenticated(result)
    XCTAssertEqual(self.tokenExchangeRequests.count, 1)
    XCTAssertEqual(
      self.tokenExchangeRequests.first?.payloadJSON?["token"] as? String,
      "a+b",
      "The grant is decoded exactly once, as handleRedirect would"
    )
  }

  func test_signInWithGoogle_willNotExchangeTwice_whenCallbackRedelivered() async throws {
    let subject = self.subject

    let result = try await self.awaitSignIn { try await subject.signInWithGoogle() }
    let first = try self.authenticated(result)

    let replayed = try await self.awaitBounded("The replayed redirect") {
      try await subject.handleRedirect(SignInFixtures.googleCallback)
    }

    let second = try self.authenticated(XCTUnwrap(replayed))
    XCTAssertTrue(first.session === second.session, "A re-delivered callback replays the same session instance")
    XCTAssertEqual(self.tokenExchangeRequests.count, 1, "The single-use grant is spent once")
  }

  func test_signInWithGoogle_willThrowCallbackIncomplete_whenCallbackHasNoToken() async throws {
    let subject = self.subject
    self.web.results = try [.success(AuthTestFixtures.url(SignInFixtures.redirectUrl))]

    await XCTAssertThrowsAsync(
      try await self.awaitSignIn { try await subject.signInWithGoogle() },
      expected: PortalAuthSignInError.callbackIncomplete
    )

    XCTAssertEqual(self.tokenExchangeRequests.count, 0)
    XCTAssertEqual(self.storage.setCalls, 0)
    XCTAssertEqual(self.storage.deleteCalls, 0)
  }

  func test_signInWithGoogle_willThrowCallbackIncomplete_whenTokenHasNoLoginType() async throws {
    let subject = self.subject
    self.web.results = try [.success(AuthTestFixtures.url("\(SignInFixtures.redirectUrl)?token=x"))]

    await XCTAssertThrowsAsync(
      try await self.awaitSignIn { try await subject.signInWithGoogle() },
      expected: PortalAuthSignInError.callbackIncomplete
    )

    XCTAssertEqual(self.tokenExchangeRequests.count, 0, "Without an auth-method marker there is no endpoint to send the grant to")
  }

  func test_signInWithGoogle_willThrowCallbackIncomplete_whenCallbackTargetsAnotherPath() async throws {
    let subject = self.subject
    self.web.results = try [.success(AuthTestFixtures.url("myapp://other/path?token=x&login_type=GOOGLE"))]

    await XCTAssertThrowsAsync(
      try await self.awaitSignIn { try await subject.signInWithGoogle() },
      expected: PortalAuthSignInError.callbackIncomplete
    )

    XCTAssertEqual(self.tokenExchangeRequests.count, 0, "A callback for another target never reaches the exchange")
  }

  func test_signInWithGoogle_willNotExchange_whenCallbackHostDiffers() async throws {
    let subject = self.subject
    self.web.results = try [.success(AuthTestFixtures.url("myapp://attacker/callback?token=stolen&login_type=GOOGLE"))]

    await XCTAssertThrowsAsync(
      try await self.awaitSignIn { try await subject.signInWithGoogle() },
      expected: PortalAuthSignInError.callbackIncomplete
    )

    XCTAssertEqual(self.tokenExchangeRequests.count, 0)
    for request in self.requests.recorded {
      XCTAssertFalse(request.absoluteString.contains("stolen"), "A foreign grant is never put on the wire")
      XCTAssertFalse(request.payloadString?.contains("stolen") ?? false, "A foreign grant is never put on the wire")
    }
  }

  func test_signInWithGoogle_willNotExchange_whenCallbackExceeds8192Chars() async throws {
    let subject = self.subject
    let base = "\(SignInFixtures.redirectUrl)?token=\(SignInFixtures.grantToken)&login_type=GOOGLE&pad="
    let padding = String(repeating: "a", count: 8193 - base.utf16.count)
    let oversized = base + padding
    XCTAssertEqual(oversized.utf16.count, 8193)
    self.web.results = try [.success(AuthTestFixtures.url(oversized))]

    await XCTAssertThrowsAsync(
      try await self.awaitSignIn { try await subject.signInWithGoogle() },
      expected: PortalAuthSignInError.callbackIncomplete
    )

    XCTAssertEqual(self.tokenExchangeRequests.count, 0, "An oversized callback is dropped before it is parsed")
  }

  func test_signInWithGoogle_willThrowAuthenticationFailed_whenCallbackCarriesError() async throws {
    let subject = self.subject
    self.web.results = try [
      .success(AuthTestFixtures.url("\(SignInFixtures.redirectUrl)?error=oauth_failed")),
      .success(AuthTestFixtures.url(SignInFixtures.googleCallback))
    ]

    await XCTAssertThrowsAsync(
      try await self.awaitSignIn { try await subject.signInWithGoogle() },
      expected: PortalAuthError.authenticationFailed(error: "oauth_failed")
    )
    XCTAssertEqual(self.tokenExchangeRequests.count, 0)

    // The guard was released by the throw.
    let result = try await self.awaitSignIn { try await subject.signInWithGoogle() }
    _ = try self.authenticated(result)
  }

  func test_signInWithGoogle_willPreferErrorOverToken_onSameCallback() async throws {
    let subject = self.subject
    self.web.results = try [.success(AuthTestFixtures.url("\(SignInFixtures.redirectUrl)?token=x&login_type=GOOGLE&error=oauth_failed"))]

    await XCTAssertThrowsAsync(
      try await self.awaitSignIn { try await subject.signInWithGoogle() },
      expected: PortalAuthError.authenticationFailed(error: "oauth_failed")
    )

    XCTAssertEqual(self.tokenExchangeRequests.count, 0, "An error wins over a token on the same redirect")
  }

  func test_signInWithGoogle_willTruncateCallbackErrorTo100Chars() async throws {
    let subject = self.subject
    let longError = String(repeating: "a", count: 250)
    self.web.results = try [.success(AuthTestFixtures.url("\(SignInFixtures.redirectUrl)?error=\(longError)"))]

    await XCTAssertThrowsAsync(try await self.awaitSignIn { try await subject.signInWithGoogle() }) { error in
      guard case let .authenticationFailed(reported)? = error as? PortalAuthError else {
        XCTFail("Expected authenticationFailed, got \(type(of: error)).")
        return
      }
      XCTAssertEqual(reported.count, 100)
      XCTAssertEqual(reported, String(repeating: "a", count: 100))
    }
  }
}

// MARK: - Exchange and browser failures

extension PortalAuthSignInTests {
  func test_signInWithGoogle_willPropagateUnauthorized_whenGrantRejected() async throws {
    let subject = self.subject
    self.requests.fail(with: PortalRequestsError.unauthorized, onPath: PortalAuthApi.oauthTokensPath)

    await XCTAssertThrowsAsync(
      try await self.awaitSignIn { try await subject.signInWithGoogle() },
      expected: PortalRequestsError.unauthorized
    )
    XCTAssertEqual(self.storage.setCalls, 0)
    XCTAssertEqual(self.tokenExchangeRequests.count, 1)

    // A failed exchange is not memoised: the same callback is retried on the wire, and the
    // in-flight guard was released by the throw.
    self.requests.fail(with: nil, onPath: PortalAuthApi.oauthTokensPath)
    let replayed = try await self.awaitBounded("The retried redirect") {
      try await subject.handleRedirect(SignInFixtures.googleCallback)
    }
    _ = try self.authenticated(XCTUnwrap(replayed))
    XCTAssertEqual(self.tokenExchangeRequests.count, 2)
  }

  func test_signInWithGoogle_willThrowClosed_whenSessionReportsClosed() async throws {
    let subject = self.subject
    self.web.results = [.failure(PortalAuthSignInError.closed)]

    await XCTAssertThrowsAsync(
      try await self.awaitSignIn { try await subject.signInWithGoogle() },
      expected: PortalAuthSignInError.closed
    )

    XCTAssertEqual(PortalAuthSignInError.closed.rawValue, "POPUP_CLOSED")
    XCTAssertEqual(self.tokenExchangeRequests.count, 0)
  }

  func test_signInWithGoogle_willThrowUnavailable_whenSessionReportsUnavailable() async throws {
    let subject = self.subject
    self.web.results = [.failure(PortalAuthSignInError.unavailable)]

    await XCTAssertThrowsAsync(
      try await self.awaitSignIn { try await subject.signInWithGoogle() },
      expected: PortalAuthSignInError.unavailable
    )

    XCTAssertEqual(self.tokenExchangeRequests.count, 0)
  }

  func test_signInWithGoogle_willPropagateUnknownSessionError() async throws {
    let subject = self.subject
    let unknown = NSError(domain: "com.test", code: 7)
    self.web.results = try [
      .failure(unknown),
      .success(AuthTestFixtures.url(SignInFixtures.googleCallback))
    ]

    await XCTAssertThrowsAsync(try await self.awaitSignIn { try await subject.signInWithGoogle() }) { error in
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, "com.test", "An unrecognised session error passes through unchanged")
      XCTAssertEqual(nsError.code, 7)
    }

    // The guard was released by the throw.
    let result = try await self.awaitSignIn { try await subject.signInWithGoogle() }
    _ = try self.authenticated(result)
  }
}

// MARK: - Concurrency and the in-flight guard

extension PortalAuthSignInTests {
  func test_signInWithApple_willThrowSignInInProgress_whileGoogleInFlight() async throws {
    let subject = self.subject
    self.web.holdUntilReleased = true

    let task = self.startSignIn(.google)
    await self.waitForBrowser()

    await XCTAssertThrowsAsync(
      try await self.awaitBounded("The concurrent Apple sign-in") { try await subject.signInWithApple() },
      expected: PortalAuthSignInError.signInInProgress
    )
    XCTAssertEqual(PortalAuthSignInError.signInInProgress.rawValue, "SIGN_IN_ALREADY_IN_PROGRESS")
    XCTAssertEqual(self.oauthUrlRequests.count, 1, "The rejected attempt never fetched a URL")
    XCTAssertEqual(self.web.calls.count, 1)

    self.web.release()
    let result = try await self.awaitBounded("The running sign-in") { try await task.value }
    _ = try self.authenticated(result)
  }

  func test_signInWithGoogle_willThrowSignInInProgress_whileGoogleInFlight() async throws {
    let subject = self.subject
    self.web.holdUntilReleased = true

    let task = self.startSignIn(.google)
    await self.waitForBrowser()

    await XCTAssertThrowsAsync(
      try await self.awaitBounded("The concurrent Google sign-in") { try await subject.signInWithGoogle() },
      expected: PortalAuthSignInError.signInInProgress
    )
    XCTAssertEqual(self.web.calls.count, 1, "A second window is never opened")

    self.web.release()
    _ = try await self.awaitBounded("The running sign-in") { try await task.value }
  }

  func test_signInWithGoogle_willNotDisturbRunningAttempt_whenSecondRejected() async throws {
    let subject = self.subject
    self.web.holdUntilReleased = true

    let task = self.startSignIn(.google)
    await self.waitForBrowser()
    await XCTAssertThrowsAsync(
      try await self.awaitBounded("The rejected attempt") { try await subject.signInWithGoogle() },
      expected: PortalAuthSignInError.signInInProgress
    )

    self.web.release()
    let result = try await self.awaitBounded("The running sign-in") { try await task.value }

    let authenticated = try self.authenticated(result)
    XCTAssertEqual(try authenticated.session.getToken(), SignInFixtures.clientSessionToken)
    XCTAssertEqual(self.web.calls.count, 1)
  }

  func test_signInWithGoogle_willRejectAllButOne_when8ConcurrentAttempts() async throws {
    let subject = self.subject
    let web = self.web
    let outcomes = SignInOutcomes()
    web.holdUntilReleased = true

    let finished = try await self.awaitBounded("The 8 concurrent attempts") {
      await withTaskGroup(of: Void.self) { group in
        for index in 0 ..< 8 {
          let useApple = index % 2 == 1
          group.addTask {
            do {
              let result: AuthResult
              if useApple {
                result = try await subject.signInWithApple()
              } else {
                result = try await subject.signInWithGoogle()
              }
              outcomes.record(result)
            } catch {
              outcomes.record(error)
            }
          }
        }
        // Releases the one attempt that won the guard, once the other seven have been rejected.
        group.addTask {
          _ = await waitUntil { outcomes.failureCount == 7 }
          web.release()
        }
      }
      return true
    }

    XCTAssertTrue(finished)
    XCTAssertEqual(outcomes.successCount, 1, "Exactly one attempt owns the single-use state")
    XCTAssertEqual(outcomes.failureCount, 7)
    for error in outcomes.errors {
      XCTAssertEqual(error as? PortalAuthSignInError, .signInInProgress)
    }
    XCTAssertEqual(self.oauthUrlRequests.count, 1)
    XCTAssertEqual(self.web.calls.count, 1)
  }

  func test_signInWithGoogle_willAllowNewSignIn_afterSuccess() async throws {
    let subject = self.subject
    self.web.results = try [
      .success(AuthTestFixtures.url(SignInFixtures.googleCallback)),
      .success(AuthTestFixtures.url(SignInFixtures.callback(token: SignInFixtures.secondGrantToken, loginType: "APPLE")))
    ]

    _ = try await self.awaitSignIn { try await subject.signInWithGoogle() }
    let second = try await self.awaitSignIn { try await subject.signInWithApple() }

    _ = try self.authenticated(second)
    XCTAssertEqual(self.tokenExchangeRequests.count, 2)
  }

  func test_signInWithGoogle_willAllowNewSignIn_afterClosed() async throws {
    let subject = self.subject
    self.web.results = try [
      .failure(PortalAuthSignInError.closed),
      .success(AuthTestFixtures.url(SignInFixtures.googleCallback))
    ]

    await XCTAssertThrowsAsync(
      try await self.awaitSignIn { try await subject.signInWithGoogle() },
      expected: PortalAuthSignInError.closed
    )
    let second = try await self.awaitSignIn { try await subject.signInWithGoogle() }

    _ = try self.authenticated(second)
  }

  func test_signInWithGoogle_willAllowNewSignIn_afterUrlFetchFailure() async throws {
    let subject = self.subject
    self.requests.fail(with: URLError(.timedOut), onPath: PortalAuthApi.oauthUrlsPath)

    await XCTAssertThrowsAsync(try await self.awaitSignIn { try await subject.signInWithGoogle() })
    self.requests.fail(with: nil, onPath: PortalAuthApi.oauthUrlsPath)

    let second = try await self.awaitSignIn { try await subject.signInWithGoogle() }

    _ = try self.authenticated(second)
    XCTAssertEqual(self.web.calls.count, 1, "Only the second attempt reached the browser")
  }

  func test_signInWithGoogle_willAllowNewSignIn_afterGrantRejected() async throws {
    let subject = self.subject
    self.web.results = try [
      .success(AuthTestFixtures.url(SignInFixtures.googleCallback)),
      .success(AuthTestFixtures.url(SignInFixtures.callback(token: SignInFixtures.secondGrantToken)))
    ]
    self.requests.fail(with: PortalRequestsError.unauthorized, onPath: PortalAuthApi.oauthTokensPath)

    await XCTAssertThrowsAsync(
      try await self.awaitSignIn { try await subject.signInWithGoogle() },
      expected: PortalRequestsError.unauthorized
    )
    self.requests.fail(with: nil, onPath: PortalAuthApi.oauthTokensPath)

    let second = try await self.awaitSignIn { try await subject.signInWithGoogle() }

    _ = try self.authenticated(second)
    XCTAssertEqual(self.tokenExchangeRequests.count, 2)
  }

  func test_signInWithGoogle_willAllowNewSignIn_afterPersistFailure() async throws {
    let subject = self.subject
    let failure = PortalAuthError.sessionStorageFailure(message: "The session could not be persisted.")
    self.storage.onSet = { _ in throw failure }
    self.web.results = try [
      .success(AuthTestFixtures.url(SignInFixtures.googleCallback)),
      .success(AuthTestFixtures.url(SignInFixtures.callback(token: SignInFixtures.secondGrantToken)))
    ]

    await XCTAssertThrowsAsync(
      try await self.awaitSignIn { try await subject.signInWithGoogle() },
      expected: failure
    )
    self.storage.onSet = nil

    let second = try await self.awaitSignIn { try await subject.signInWithGoogle() }

    _ = try self.authenticated(second)
    XCTAssertEqual(self.storage.setCalls, 2)
    XCTAssertEqual(self.storage.storedSession?.clientSessionToken, SignInFixtures.clientSessionToken)
  }

  func test_signInWithGoogle_willAllowNewSignIn_afterCancellation() async throws {
    let subject = self.subject
    self.web.holdUntilReleased = true

    let task = self.startSignIn(.google)
    await self.waitForBrowser()
    task.cancel()

    await XCTAssertThrowsAsync(try await self.awaitBounded("The cancelled sign-in") { try await task.value })

    // The scripted callback was never consumed by the cancelled attempt.
    self.web.holdUntilReleased = false
    let second = try await self.awaitSignIn { try await subject.signInWithGoogle() }

    _ = try self.authenticated(second)
    XCTAssertEqual(self.web.calls.count, 2)
  }

  func test_signInWithGoogle_willNotGateLoginWithGoogle_whileInFlight() async throws {
    let subject = self.subject
    self.web.holdUntilReleased = true

    let task = self.startSignIn(.google)
    await self.waitForBrowser()

    let urlResult = try await self.awaitBounded("loginWithGoogle during a sign-in") {
      try await subject.loginWithGoogle()
    }

    XCTAssertEqual(urlResult.authorizeUrl, SignInFixtures.googleAuthorizeUrl, "The URL-only path is the manual escape hatch and is never gated")
    XCTAssertEqual(self.oauthUrlRequests.count, 2)

    self.web.release()
    _ = try await self.awaitBounded("The running sign-in") { try await task.value }
  }

  func test_signInWithGoogle_willNotHoldGrantMutex_whileBrowserOpen() async throws {
    let subject = self.subject
    self.web.holdUntilReleased = true

    let task = self.startSignIn(.google)
    await self.waitForBrowser()

    let magicLinkRedirect = "\(SignInFixtures.redirectUrl)?token=m&authMethod=\(AuthMethod.emailMagicLink.rawValue)"
    let redirectResult = try await self.awaitBounded("handleRedirect during a sign-in") {
      try await subject.handleRedirect(magicLinkRedirect)
    }

    _ = try self.authenticated(XCTUnwrap(redirectResult))
    XCTAssertEqual(
      self.requests.requests(toPath: PortalAuthApi.magicLinkValidationsPath).count,
      1,
      "Only _handleRedirect takes the grant mutex, so a magic link still completes while the browser is open"
    )
    XCTAssertEqual(self.web.calls.count, 1, "The sign-in is still parked in the browser")

    self.web.release()
    _ = try await self.awaitBounded("The running sign-in") { try await task.value }
  }
}

// MARK: - Cancellation

extension PortalAuthSignInTests {
  func test_signInWithGoogle_willCancelSession_whenTaskCancelled() async throws {
    self.web.holdUntilReleased = true

    let task = self.startSignIn(.google)
    await self.waitForBrowser()
    task.cancel()

    let cancelled = await waitUntil { self.web.cancelCalls == 1 }
    XCTAssertTrue(cancelled, "Cancelling the task dismisses the sheet")

    await XCTAssertThrowsAsync(try await self.awaitBounded("The cancelled sign-in") { try await task.value }) { error in
      if let signInError = error as? PortalAuthSignInError {
        XCTAssertEqual(signInError, .closed)
      } else {
        XCTAssertTrue(error is CancellationError, "Expected .closed or CancellationError, got \(type(of: error)).")
      }
    }
    XCTAssertEqual(self.tokenExchangeRequests.count, 0)
  }

  func test_signInWithGoogle_willNotExchange_whenCancelledBeforeCallback() async throws {
    self.web.holdUntilReleased = true

    let task = self.startSignIn(.google)
    await self.waitForBrowser()
    task.cancel()
    let cancelled = await waitUntil { self.web.cancelCalls == 1 }
    XCTAssertTrue(cancelled)
    // The callback arrives after the cancellation; the grant must not be spent.
    self.web.release()

    await XCTAssertThrowsAsync(try await self.awaitBounded("The cancelled sign-in") { try await task.value })

    XCTAssertEqual(self.tokenExchangeRequests.count, 0)
    XCTAssertEqual(self.storage.setCalls, 0)
  }
}

// MARK: - Security

extension PortalAuthSignInTests {
  func test_signInWithGoogle_willNotLogSecrets() async throws {
    let subject = self.subject
    let userJwt = AuthTestFixtures.userJwt(endUserId: SignInFixtures.endUserId)

    // 1. A completed sign-in.
    _ = try await self.awaitSignIn { try await subject.signInWithGoogle() }

    // 2. A grant that resolves to a TOTP step, so the JWT and the enrollment link are logged
    //    against too.
    self.installResponder(grant: AuthTestFixtures.grant(
      cst: nil,
      endUserId: SignInFixtures.endUserId,
      userJwt: userJwt,
      totpLink: SignInFixtures.totpLink
    ))
    self.web.results = try [.success(AuthTestFixtures.url(SignInFixtures.callback(token: SignInFixtures.secondGrantToken)))]
    _ = try await self.awaitSignIn { try await subject.signInWithGoogle() }

    // 3. A rejected grant.
    self.requests.fail(with: PortalRequestsError.unauthorized, onPath: PortalAuthApi.oauthTokensPath)
    self.web.results = try [.success(AuthTestFixtures.url(SignInFixtures.callback(token: SignInFixtures.thirdGrantToken)))]
    await XCTAssertThrowsAsync(
      try await self.awaitSignIn { try await subject.signInWithGoogle() },
      expected: PortalRequestsError.unauthorized
    )
    self.requests.fail(with: nil, onPath: PortalAuthApi.oauthTokensPath)

    // 4. A redirect that reports an OAuth error.
    self.web.results = try [.success(AuthTestFixtures.url("\(SignInFixtures.redirectUrl)?error=oauth_failed"))]
    await XCTAssertThrowsAsync(
      try await self.awaitSignIn { try await subject.signInWithGoogle() },
      expected: PortalAuthError.authenticationFailed(error: "oauth_failed")
    )

    // 5. A dismissed browser.
    self.web.results = [.failure(PortalAuthSignInError.closed)]
    await XCTAssertThrowsAsync(
      try await self.awaitSignIn { try await subject.signInWithGoogle() },
      expected: PortalAuthSignInError.closed
    )

    for secret in [
      SignInFixtures.grantToken,
      SignInFixtures.secondGrantToken,
      SignInFixtures.thirdGrantToken,
      SignInFixtures.clientSessionToken,
      SignInFixtures.googleAuthorizeUrl,
      SignInFixtures.googleCallback,
      SignInFixtures.totpLink,
      SignInFixtures.totpSecret,
      "oauth_failed",
      userJwt
    ] {
      self.logger.assertNoSecret(secret)
    }

    // Not vacuous: the sink did capture this flow's own log lines.
    XCTAssertTrue(self.logger.contains("GOOGLE sign-in completed."))
    XCTAssertTrue(self.logger.contains(SignInFixtures.endUserId), "The end user id is not a secret and stays loggable")
  }

  func test_signInWithGoogle_willNotSendBearer_onOauthUrlsOrTokens() async throws {
    let subject = self.subject

    _ = try await self.awaitSignIn { try await subject.signInWithGoogle() }

    XCTAssertEqual(self.requests.count, 2)
    for request in self.requests.recorded {
      XCTAssertNil(request.bearerToken, "No Client Auth call but the TOTP one carries a bearer")
      XCTAssertNil(request.header("Authorization"))
    }
  }

  func test_signInWithGoogle_willNotIncludeUrlInCallbackIncompleteDescription() async throws {
    let subject = self.subject
    self.web.results = try [.success(AuthTestFixtures.url("myapp://other/path?token=\(SignInFixtures.grantToken)&login_type=GOOGLE"))]

    await XCTAssertThrowsAsync(try await self.awaitSignIn { try await subject.signInWithGoogle() }) { error in
      XCTAssertEqual(error as? PortalAuthSignInError, .callbackIncomplete)
      let description = (error as? PortalAuthSignInError)?.errorDescription ?? ""
      XCTAssertFalse(description.isEmpty)
      XCTAssertFalse(description.contains(SignInFixtures.grantToken))
      XCTAssertFalse(description.contains("://"))
      XCTAssertFalse(description.contains("myapp"))
      XCTAssertFalse(description.contains("other/path"))
    }
  }
}

// MARK: - ASWebAuthenticationSessionAdapter: error mapping

extension PortalAuthSignInTests {
  func test_adapterMapError_willMapCanceledLoginToClosed() {
    let mapped = ASWebAuthenticationSessionAdapter.mapError(ASWebAuthenticationSessionError(.canceledLogin))

    XCTAssertEqual(mapped as? PortalAuthSignInError, .closed)
  }

  func test_adapterMapError_willMapPresentationContextNotProvidedToUnavailable() {
    let mapped = ASWebAuthenticationSessionAdapter.mapError(ASWebAuthenticationSessionError(.presentationContextNotProvided))

    XCTAssertEqual(mapped as? PortalAuthSignInError, .unavailable)
  }

  func test_adapterMapError_willMapPresentationContextInvalidToUnavailable() {
    let mapped = ASWebAuthenticationSessionAdapter.mapError(ASWebAuthenticationSessionError(.presentationContextInvalid))

    XCTAssertEqual(mapped as? PortalAuthSignInError, .unavailable)
  }

  func test_adapterMapError_willPassThroughUnknownError() {
    let foreign = NSError(domain: "x", code: 1)
    let mappedForeign = ASWebAuthenticationSessionAdapter.mapError(foreign) as NSError
    XCTAssertEqual(mappedForeign.domain, "x")
    XCTAssertEqual(mappedForeign.code, 1)
    XCTAssertNil(ASWebAuthenticationSessionAdapter.mapError(foreign) as? PortalAuthSignInError)

    let cancelled = ASWebAuthenticationSessionAdapter.mapError(URLError(.cancelled))
    XCTAssertEqual((cancelled as? URLError)?.code, .cancelled)
    XCTAssertNil(cancelled as? PortalAuthSignInError)
  }

  func test_adapterMapError_willPassThroughUnknownASWebCode() {
    let unknown = NSError(domain: ASWebAuthenticationSessionErrorDomain, code: 9999)

    let mapped = ASWebAuthenticationSessionAdapter.mapError(unknown) as NSError

    XCTAssertNil(ASWebAuthenticationSessionAdapter.mapError(unknown) as? PortalAuthSignInError, "An unknown code in the same domain is not a dismissal")
    XCTAssertEqual(mapped.domain, ASWebAuthenticationSessionErrorDomain)
    XCTAssertEqual(mapped.code, 9999)
  }
}

// MARK: - ASWebAuthenticationSessionAdapter

extension PortalAuthSignInTests {
  /// The adapter under its `sessionFactory` seam.
  ///
  /// - Parameter retaining: When given, every handle the factory builds is retained for the
  ///   length of the case. The recorder itself holds handles weakly, so any assertion made
  ///   *after* the adapter has finished with a handle needs this; the two retention cases
  ///   deliberately pass `nil`.
  private func makeAdapter(
    recorder: FakeWebAuthenticationSessionHandle.Recorder,
    retaining: RetainedHandles? = nil
  ) -> ASWebAuthenticationSessionAdapter {
    if let retaining = retaining {
      recorder.onCreate = { handle in retaining.append(handle) }
    }
    return ASWebAuthenticationSessionAdapter(sessionFactory: FakeWebAuthenticationSessionHandle.factory(recording: recorder))
  }

  /// Starts `authenticate` on a detached task, so nothing about the call inherits the test's
  /// executor and the main-actor hop the adapter performs is the real thing.
  private func startAuthenticate(
    _ adapter: ASWebAuthenticationSessionAdapter,
    url: URL,
    scheme: String = SignInFixtures.callbackScheme,
    prefersEphemeral: Bool = false,
    anchor: ASPresentationAnchor
  ) -> Task<URL, Error> {
    Task.detached {
      try await adapter.authenticate(
        url: url,
        callbackURLScheme: scheme,
        anchor: anchor,
        prefersEphemeralWebBrowserSession: prefersEphemeral
      )
    }
  }

  func test_adapter_willNotPresent_whenEnteredOnAnAlreadyCancelledTask() async throws {
    let recorder = FakeWebAuthenticationSessionHandle.Recorder()
    let adapter = self.makeAdapter(recorder: recorder)
    let authorizeUrl = try AuthTestFixtures.url(SignInFixtures.googleAuthorizeUrl)
    let anchor = self.anchor
    // Parks the task *before* `authenticate` so the cancellation is guaranteed to land first. A
    // held sleep resumes by throwing `CancellationError`, which the task swallows on purpose so
    // that `authenticate` is entered on a task that is already cancelled.
    let gate = RecordingSleeper(isHolding: true)

    let task = Task.detached { () throws -> URL in
      do { try await gate.sleep(1) } catch {}
      return try await adapter.authenticate(
        url: authorizeUrl,
        callbackURLScheme: SignInFixtures.callbackScheme,
        anchor: anchor,
        prefersEphemeralWebBrowserSession: false
      )
    }
    let parked = await gate.waitUntilHeld()
    XCTAssertTrue(parked, "The task never reached the gate")

    task.cancel()

    await XCTAssertThrowsAsync(try await task.value, expected: PortalAuthSignInError.closed)
    XCTAssertNil(
      recorder.latest,
      "No browser session may be created, let alone presented, for a sign-in nobody is waiting for — the caller would otherwise be stuck until the user dismissed it"
    )
  }

  func test_adapter_willRetainProviderAndSessionUntilCompletion() async throws {
    let recorder = FakeWebAuthenticationSessionHandle.Recorder()
    let adapter = self.makeAdapter(recorder: recorder)
    let authorizeUrl = try AuthTestFixtures.url(SignInFixtures.googleAuthorizeUrl)
    let callback = try AuthTestFixtures.url(SignInFixtures.googleCallback)
    let handleRef = WeakRef<FakeWebAuthenticationSessionHandle>()
    let providerRef = WeakRef<AuthPresentationAnchorProvider>()

    let task = self.startAuthenticate(adapter, url: authorizeUrl, anchor: self.anchor)
    let started = await waitUntil { recorder.latest?.startCalls == 1 }
    XCTAssertTrue(started, "The session was not started within 2 s")

    autoreleasepool {
      let handle = recorder.latest
      handleRef.value = handle
      providerRef.value = handle?.presentationContextProvider as? AuthPresentationAnchorProvider
    }
    // Read inside a pool: an autoreleased strong temporary escaping into the enclosing pool
    // would keep the provider alive and make the release assertion below meaningless.
    let heldWhilePending = autoreleasepool { handleRef.value != nil && providerRef.value != nil }
    XCTAssertTrue(heldWhilePending, "The adapter holds the session and the provider while the call is pending; the system property is weak")

    autoreleasepool {
      recorder.latest?.complete(url: callback, error: nil)
    }
    let returned = try await self.awaitBounded("adapter.authenticate") { try await task.value }
    XCTAssertEqual(returned, callback)

    let released = await waitUntil { autoreleasepool { handleRef.value == nil && providerRef.value == nil } }
    XCTAssertTrue(released, "Both are released once the call has finished")
  }

  func test_adapter_willDismissSession_whenCancelledBetweenRunningAndStart() async throws {
    // The race: `cancel()` lands after the adapter has moved to `.running` but before `start()`.
    // It cancels a session that has not started — a no-op on `ASWebAuthenticationSession` — and
    // fails the call with `.closed`; `start()` then presents the browser anyway. The adapter must
    // notice and dismiss it, or the sheet stays up with every callback ignored.
    let recorder = FakeWebAuthenticationSessionHandle.Recorder()
    let retained = RetainedHandles()
    let adapter = self.makeAdapter(recorder: recorder)
    recorder.onCreate = { handle in
      retained.append(handle)
      handle.onStart = { adapter.cancel() }
    }
    let authorizeUrl = try AuthTestFixtures.url(SignInFixtures.googleAuthorizeUrl)

    let task = self.startAuthenticate(adapter, url: authorizeUrl, anchor: self.anchor)

    await XCTAssertThrowsAsync(try await self.awaitBounded("adapter.authenticate") { try await task.value }) { error in
      XCTAssertEqual(error as? PortalAuthSignInError, .closed)
    }
    let handle = try XCTUnwrap(retained.latest)
    XCTAssertEqual(handle.startCalls, 1)
    XCTAssertEqual(handle.cancelCallsAfterStart, 1, "The session `start()` presented after the cancellation must be dismissed")
    // A late completion from the dismissed session changes nothing.
    let callback = try AuthTestFixtures.url(SignInFixtures.googleCallback)
    handle.complete(url: callback, error: nil)
  }

  func test_adapter_willReleaseProviderAndSession_afterFailure() async throws {
    let recorder = FakeWebAuthenticationSessionHandle.Recorder()
    let adapter = self.makeAdapter(recorder: recorder)
    let authorizeUrl = try AuthTestFixtures.url(SignInFixtures.googleAuthorizeUrl)
    let handleRef = WeakRef<FakeWebAuthenticationSessionHandle>()
    let providerRef = WeakRef<AuthPresentationAnchorProvider>()

    let task = self.startAuthenticate(adapter, url: authorizeUrl, anchor: self.anchor)
    let started = await waitUntil { recorder.latest?.startCalls == 1 }
    XCTAssertTrue(started)

    autoreleasepool {
      let handle = recorder.latest
      handleRef.value = handle
      providerRef.value = handle?.presentationContextProvider as? AuthPresentationAnchorProvider
    }
    autoreleasepool {
      recorder.latest?.complete(url: nil, error: ASWebAuthenticationSessionError(.canceledLogin))
    }

    await XCTAssertThrowsAsync(
      try await self.awaitBounded("adapter.authenticate") { try await task.value },
      expected: PortalAuthSignInError.closed
    )

    let released = await waitUntil { autoreleasepool { handleRef.value == nil && providerRef.value == nil } }
    XCTAssertTrue(released, "A failed call releases the session and the provider too")
  }

  func test_adapter_willSetProviderAndEphemeralBeforeStart() async throws {
    let recorder = FakeWebAuthenticationSessionHandle.Recorder()
    let retained = RetainedHandles()
    let adapter = self.makeAdapter(recorder: recorder, retaining: retained)
    let authorizeUrl = try AuthTestFixtures.url(SignInFixtures.googleAuthorizeUrl)
    let callback = try AuthTestFixtures.url(SignInFixtures.googleCallback)

    let task = self.startAuthenticate(adapter, url: authorizeUrl, prefersEphemeral: true, anchor: self.anchor)
    let started = await waitUntil { retained.latest?.startCalls == 1 }
    XCTAssertTrue(started)

    let handle = try XCTUnwrap(retained.latest)
    XCTAssertEqual(handle.providerWasSetAtStart, true, "start() must never run before the provider is assigned")
    XCTAssertEqual(handle.ephemeralAtStart, true)

    retained.latest?.complete(url: callback, error: nil)
    _ = try await self.awaitBounded("adapter.authenticate") { try await task.value }
  }

  func test_adapter_willStartOnMainThread() async throws {
    let recorder = FakeWebAuthenticationSessionHandle.Recorder()
    let retained = RetainedHandles()
    let adapter = self.makeAdapter(recorder: recorder, retaining: retained)
    let authorizeUrl = try AuthTestFixtures.url(SignInFixtures.googleAuthorizeUrl)
    let callback = try AuthTestFixtures.url(SignInFixtures.googleCallback)

    let task = self.startAuthenticate(adapter, url: authorizeUrl, anchor: self.anchor)
    let started = await waitUntil { retained.latest?.startCalls == 1 }
    XCTAssertTrue(started)

    let handle = try XCTUnwrap(retained.latest)
    XCTAssertEqual(handle.startedOnMainThread, true, "The session presents UI and must start on the main thread")

    retained.latest?.complete(url: callback, error: nil)
    _ = try await self.awaitBounded("adapter.authenticate") { try await task.value }
  }

  func test_adapter_willPassUrlAndSchemeToSessionFactory() async throws {
    let recorder = FakeWebAuthenticationSessionHandle.Recorder()
    let retained = RetainedHandles()
    let adapter = self.makeAdapter(recorder: recorder, retaining: retained)
    let authorizeUrl = try AuthTestFixtures.url(SignInFixtures.googleAuthorizeUrl)
    let callback = try AuthTestFixtures.url(SignInFixtures.googleCallback)

    let task = self.startAuthenticate(adapter, url: authorizeUrl, anchor: self.anchor)
    let started = await waitUntil { retained.latest?.startCalls == 1 }
    XCTAssertTrue(started)

    XCTAssertEqual(recorder.invocations.count, 1)
    XCTAssertEqual(recorder.invocations.first?.url, authorizeUrl)
    XCTAssertEqual(recorder.invocations.first?.callbackURLScheme, SignInFixtures.callbackScheme)

    retained.latest?.complete(url: callback, error: nil)
    _ = try await self.awaitBounded("adapter.authenticate") { try await task.value }
  }

  func test_adapter_willProvideAnchorFromProvider() async throws {
    let recorder = FakeWebAuthenticationSessionHandle.Recorder()
    let retained = RetainedHandles()
    let adapter = self.makeAdapter(recorder: recorder, retaining: retained)
    let authorizeUrl = try AuthTestFixtures.url(SignInFixtures.googleAuthorizeUrl)
    let callback = try AuthTestFixtures.url(SignInFixtures.googleCallback)

    let task = self.startAuthenticate(adapter, url: authorizeUrl, anchor: self.anchor)
    let started = await waitUntil { retained.latest?.startCalls == 1 }
    XCTAssertTrue(started)

    let provider = try XCTUnwrap(retained.latest?.presentationContextProvider)
    let dummySession = ASWebAuthenticationSession(url: authorizeUrl, callbackURLScheme: SignInFixtures.callbackScheme) { _, _ in }
    XCTAssertTrue(provider.presentationAnchor(for: dummySession) === self.anchor)

    retained.latest?.complete(url: callback, error: nil)
    _ = try await self.awaitBounded("adapter.authenticate") { try await task.value }
  }

  func test_adapter_willThrowUnavailable_whenStartReturnsFalse() async throws {
    let recorder = FakeWebAuthenticationSessionHandle.Recorder()
    recorder.startReturns = false
    let retained = RetainedHandles()
    let adapter = self.makeAdapter(recorder: recorder, retaining: retained)
    let authorizeUrl = try AuthTestFixtures.url(SignInFixtures.googleAuthorizeUrl)

    let task = self.startAuthenticate(adapter, url: authorizeUrl, anchor: self.anchor)

    await XCTAssertThrowsAsync(
      try await self.awaitBounded("adapter.authenticate") { try await task.value },
      expected: PortalAuthSignInError.unavailable
    )
    XCTAssertEqual(retained.latest?.startCalls, 1)
    XCTAssertEqual(retained.latest?.cancelCalls, 0, "A session the system refused to start is not cancelled")
  }

  func test_adapter_willReturnUrl_whenCompletionHasUrl() async throws {
    let recorder = FakeWebAuthenticationSessionHandle.Recorder()
    let retained = RetainedHandles()
    let adapter = self.makeAdapter(recorder: recorder, retaining: retained)
    let authorizeUrl = try AuthTestFixtures.url(SignInFixtures.googleAuthorizeUrl)
    let callback = try AuthTestFixtures.url(SignInFixtures.googleCallback)

    let task = self.startAuthenticate(adapter, url: authorizeUrl, anchor: self.anchor)
    let started = await waitUntil { retained.latest?.startCalls == 1 }
    XCTAssertTrue(started)
    retained.latest?.complete(url: callback, error: nil)

    let returned = try await self.awaitBounded("adapter.authenticate") { try await task.value }

    XCTAssertEqual(returned, callback)
  }

  func test_adapter_willThrowCallbackIncomplete_whenCompletionHasNilUrlAndNilError() async throws {
    let recorder = FakeWebAuthenticationSessionHandle.Recorder()
    let retained = RetainedHandles()
    let adapter = self.makeAdapter(recorder: recorder, retaining: retained)
    let authorizeUrl = try AuthTestFixtures.url(SignInFixtures.googleAuthorizeUrl)

    let task = self.startAuthenticate(adapter, url: authorizeUrl, anchor: self.anchor)
    let started = await waitUntil { retained.latest?.startCalls == 1 }
    XCTAssertTrue(started)
    retained.latest?.complete(url: nil, error: nil)

    await XCTAssertThrowsAsync(
      try await self.awaitBounded("adapter.authenticate") { try await task.value },
      expected: PortalAuthSignInError.callbackIncomplete
    )
  }

  func test_adapter_willMapErrorFromCompletion() async throws {
    let recorder = FakeWebAuthenticationSessionHandle.Recorder()
    let retained = RetainedHandles()
    let adapter = self.makeAdapter(recorder: recorder, retaining: retained)
    let authorizeUrl = try AuthTestFixtures.url(SignInFixtures.googleAuthorizeUrl)

    let task = self.startAuthenticate(adapter, url: authorizeUrl, anchor: self.anchor)
    let started = await waitUntil { retained.latest?.startCalls == 1 }
    XCTAssertTrue(started)
    retained.latest?.complete(url: nil, error: ASWebAuthenticationSessionError(.canceledLogin))

    await XCTAssertThrowsAsync(
      try await self.awaitBounded("adapter.authenticate") { try await task.value },
      expected: PortalAuthSignInError.closed
    )
  }

  func test_adapter_willResumeOnlyOnce_whenCompletionFiresTwice() async throws {
    let recorder = FakeWebAuthenticationSessionHandle.Recorder()
    let retained = RetainedHandles()
    let adapter = self.makeAdapter(recorder: recorder, retaining: retained)
    let authorizeUrl = try AuthTestFixtures.url(SignInFixtures.googleAuthorizeUrl)
    let firstCallback = try AuthTestFixtures.url(SignInFixtures.googleCallback)
    let secondCallback = try AuthTestFixtures.url(SignInFixtures.callback(token: SignInFixtures.secondGrantToken))

    let task = self.startAuthenticate(adapter, url: authorizeUrl, anchor: self.anchor)
    let started = await waitUntil { retained.latest?.startCalls == 1 }
    XCTAssertTrue(started)

    // The system may deliver more than once; the continuation must resume exactly once.
    retained.latest?.complete(url: firstCallback, error: nil)
    retained.latest?.complete(url: secondCallback, error: nil)
    retained.latest?.complete(url: nil, error: ASWebAuthenticationSessionError(.canceledLogin))

    let returned = try await self.awaitBounded("adapter.authenticate") { try await task.value }

    XCTAssertEqual(returned, firstCallback, "The first completion wins; the later ones are ignored")
  }

  func test_adapter_willCancelSession_onTaskCancellation() async throws {
    let recorder = FakeWebAuthenticationSessionHandle.Recorder()
    let retained = RetainedHandles()
    let adapter = self.makeAdapter(recorder: recorder, retaining: retained)
    let authorizeUrl = try AuthTestFixtures.url(SignInFixtures.googleAuthorizeUrl)

    let task = self.startAuthenticate(adapter, url: authorizeUrl, anchor: self.anchor)
    let started = await waitUntil { retained.latest?.startCalls == 1 }
    XCTAssertTrue(started)

    task.cancel()

    await XCTAssertThrowsAsync(
      try await self.awaitBounded("adapter.authenticate") { try await task.value },
      expected: PortalAuthSignInError.closed
    )
    let dismissed = await waitUntil { retained.latest?.cancelCalls == 1 }
    XCTAssertTrue(dismissed, "Cancelling the task dismisses the session")
  }

  func test_adapter_willTolerateCancelAfterCompletion() async throws {
    let recorder = FakeWebAuthenticationSessionHandle.Recorder()
    let retained = RetainedHandles()
    let adapter = self.makeAdapter(recorder: recorder, retaining: retained)
    let authorizeUrl = try AuthTestFixtures.url(SignInFixtures.googleAuthorizeUrl)
    let callback = try AuthTestFixtures.url(SignInFixtures.googleCallback)

    let task = self.startAuthenticate(adapter, url: authorizeUrl, anchor: self.anchor)
    let started = await waitUntil { retained.latest?.startCalls == 1 }
    XCTAssertTrue(started)
    retained.latest?.complete(url: callback, error: nil)
    let returned = try await self.awaitBounded("adapter.authenticate") { try await task.value }

    adapter.cancel()
    adapter.cancel()

    XCTAssertEqual(returned, callback, "A cancel after settlement changes nothing")
    XCTAssertEqual(retained.latest?.cancelCalls, 0, "The finished session is not dismissed again")
  }
}
