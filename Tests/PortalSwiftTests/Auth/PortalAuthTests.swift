//
//  PortalAuthTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

/// Drives `PortalAuth` through the real internal stack — `PortalAuthApi`, `RedirectUrl`,
/// `UserJwt`, `PersistedSessionCodec` and `KeychainPortalSession` — with only the transport
/// and the session storage replaced by doubles.
///
/// Testing through the whole stack rather than against a mocked `PortalAuthApi` is deliberate:
/// almost every rule that matters here (which endpoint a redirect routes to, what exactly gets
/// persisted, which failures are remapped and which pass through untouched, what never reaches
/// a log) lives in the seam *between* those types, and a mocked API would assert the seam away.
///
/// Every case installs a `RecordingLogger` into `PortalLogger.shared.sink`, so the "never logs
/// a secret" assertions see every message at every level, and resets
/// `CredentialInvalidationRegistry.shared` so once-ever flags cannot leak between cases.
final class PortalAuthTests: XCTestCase {
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
    // The sink sees every message regardless of the level, but the level is raised anyway so a
    // "never logs the token" case exercises the same code path a debugging host would.
    PortalLogger.shared.setLogLevel(.debug)
    self.auth = AuthTestFixtures.makeAuth(requests: self.requests, storage: self.storage, logger: self.logger)
  }

  override func tearDownWithError() throws {
    self.logger.uninstall()
    PortalLogger.shared.setLogLevel(.none)
    self.requests = RecordingPortalRequests()
    self.storage = MockAuthSessionStorage()
    self.auth = AuthTestFixtures.makeAuth(requests: self.requests)
    CredentialInvalidationRegistry.shared.resetForTesting()
    try super.tearDownWithError()
  }

  // MARK: - Helpers

  /// Raised by the result extractors so a mismatched `AuthResult` fails the case and stops it,
  /// rather than reading a field off the wrong case.
  private enum SubjectError: LocalizedError {
    case notAuthenticated
    case notTotpRequired
    case cannotBuildFixture(String)

    var errorDescription: String? {
      switch self {
      case .notAuthenticated:
        return "Expected AuthResult.authenticated."
      case .notTotpRequired:
        return "Expected AuthResult.totpRequired."
      case let .cannotBuildFixture(detail):
        return "The fixture could not be built: \(detail)."
      }
    }
  }

  /// A one-way, lock-guarded flag: a storage hook runs on whatever executor resumed the
  /// exchange, so a plain `var` captured by the closure would be a data race.
  private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false

    var value: Bool {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self.flag
    }

    func set() {
      self.lock.lock()
      defer { self.lock.unlock() }
      self.flag = true
    }
  }

  /// A `PortalAuth` over fresh doubles, sharing this case's logger so the secret assertions
  /// still cover it.
  private func makeSubject(
    requests: RecordingPortalRequests,
    storage: MockAuthSessionStorage = MockAuthSessionStorage(),
    magicLink: MagicLinkConfig? = AuthTestFixtures.magicLink,
    isAccountAbstracted: Bool? = nil,
    apiHost: String = AuthTestFixtures.apiHost,
    webSessionFactory: (() -> AuthWebSessionProviding)? = nil
  ) -> PortalAuth {
    AuthTestFixtures.makeAuth(
      requests: requests,
      storage: storage,
      logger: self.logger,
      magicLink: magicLink,
      isAccountAbstracted: isAccountAbstracted,
      apiHost: apiHost,
      webSessionFactory: webSessionFactory
    )
  }

  /// The `AuthenticatedResult` of a successful login, or a failed assertion.
  private func authenticated(_ result: AuthResult?, file: StaticString = #filePath, line: UInt = #line) throws -> AuthenticatedResult {
    guard case let .authenticated(value)? = result else {
      XCTFail("Expected AuthResult.authenticated.", file: file, line: line)
      throw SubjectError.notAuthenticated
    }
    return value
  }

  /// The `TotpRequiredResult` of a login that stopped at the TOTP step, or a failed assertion.
  private func totpRequired(_ result: AuthResult?, file: StaticString = #filePath, line: UInt = #line) throws -> TotpRequiredResult {
    guard case let .totpRequired(value)? = result else {
      XCTFail("Expected AuthResult.totpRequired.", file: file, line: line)
      throw SubjectError.notTotpRequired
    }
    return value
  }

  /// The JSON body of the most recent request, or a failed assertion.
  private func lastPayload(file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
    let request = try XCTUnwrap(self.requests.lastRequest, "No request was recorded.", file: file, line: line)
    return try XCTUnwrap(request.payloadJSON, "The request carried no JSON body.", file: file, line: line)
  }

  /// A magic-link redirect padded with `/` in the path so the whole URL measures exactly
  /// `totalUtf16` UTF-16 units — the unit `PortalAuth.maxRedirectUrlLength` is expressed in.
  /// Trailing slashes are dropped by the matcher, so padding there keeps the URL valid.
  private func paddedMagicLinkRedirect(totalUtf16: Int) throws -> String {
    let base = AuthTestFixtures.redirectUrl
    let query = "?token=\(AuthTestFixtures.grantToken)&authMethod=\(AuthMethod.emailMagicLink.rawValue)"
    let padding = totalUtf16 - base.utf16.count - query.utf16.count
    guard padding >= 0 else {
      throw SubjectError.cannotBuildFixture("the redirect is already longer than \(totalUtf16) UTF-16 units")
    }
    let url = base + String(repeating: "/", count: padding) + query
    XCTAssertEqual(url.utf16.count, totalUtf16)
    return url
  }

  /// Fails the case if any of `secrets` reached the logger. A loop rather than one call so the
  /// failure names the exact value that leaked.
  private func assertNoSecrets(_ secrets: [String], file: StaticString = #filePath, line: UInt = #line) {
    for secret in secrets {
      self.logger.assertNoSecret(secret, file: file, line: line)
    }
  }

  // MARK: - init

  func test_init_willThrowInvalidArgument_whenAuthEnvironmentIdEmpty() throws {
    XCTAssertThrowsError(try PortalAuth(authEnvironmentId: "", redirectUrl: AuthTestFixtures.redirectUrl)) { error in
      XCTAssertEqual(error as? PortalAuthError, .invalidArgument(name: "authEnvironmentId"))
      XCTAssertEqual((error as? PortalAuthError)?.errorDescription, "[PortalAuth] `authEnvironmentId` is required.")
    }
  }

  func test_init_willThrowInvalidArgument_whenAuthEnvironmentIdWhitespace() throws {
    XCTAssertThrowsError(try PortalAuth(authEnvironmentId: "  \n\t", redirectUrl: AuthTestFixtures.redirectUrl)) { error in
      XCTAssertEqual(error as? PortalAuthError, .invalidArgument(name: "authEnvironmentId"))
    }
  }

  func test_init_willThrowInvalidArgument_whenRedirectUrlEmpty() throws {
    XCTAssertThrowsError(try PortalAuth(authEnvironmentId: AuthTestFixtures.authEnvironmentId, redirectUrl: "")) { error in
      XCTAssertEqual(error as? PortalAuthError, .invalidArgument(name: "redirectUrl"))
      XCTAssertEqual((error as? PortalAuthError)?.errorDescription, "[PortalAuth] `redirectUrl` is required.")
    }
  }

  func test_init_willThrowInvalidArgument_whenRedirectUrlWhitespace() throws {
    XCTAssertThrowsError(try PortalAuth(authEnvironmentId: AuthTestFixtures.authEnvironmentId, redirectUrl: "   ")) { error in
      XCTAssertEqual(error as? PortalAuthError, .invalidArgument(name: "redirectUrl"))
    }
  }

  func test_init_willReportAuthEnvironmentIdBeforeRedirectUrl_whenBothBlank() throws {
    XCTAssertThrowsError(try PortalAuth(authEnvironmentId: "  ", redirectUrl: "  ")) { error in
      XCTAssertEqual(error as? PortalAuthError, .invalidArgument(name: "authEnvironmentId"))
    }
  }

  func test_init_willPerformNoRequestAndNoStorageRead() throws {
    let subject = self.makeSubject(requests: self.requests, storage: self.storage, magicLink: nil, isAccountAbstracted: nil)

    XCTAssertFalse(subject.prefersEphemeralWebBrowserSession)
    XCTAssertEqual(self.requests.callCount, 0)
    XCTAssertEqual(self.storage.getCalls, 0)
    XCTAssertEqual(self.storage.setCalls, 0)
    XCTAssertFalse(self.logger.contains(AuthTestFixtures.redirectUrl))
  }

  func test_init_willAcceptOptionalConfigDefaults() throws {
    let subject = try PortalAuth(authEnvironmentId: AuthTestFixtures.authEnvironmentId, redirectUrl: AuthTestFixtures.redirectUrl)

    XCTAssertFalse(subject.prefersEphemeralWebBrowserSession)
  }

  // MARK: - getMethods

  func test_getMethods_willReturnEnabledMethods() async throws {
    self.requests.enqueue(AuthTestFixtures.methodsResponse(["EMAIL_MAGIC_LINK"], autoCreateWallet: true))

    let result = try await self.auth.getMethods()

    XCTAssertEqual(result.allowedAuthMethods, [.emailMagicLink])
    XCTAssertTrue(result.autoCreateWallet)
    XCTAssertEqual(self.requests.callCount, 1)
    let request = try XCTUnwrap(self.requests.lastRequest)
    XCTAssertEqual(request.method, .get)
    XCTAssertEqual(request.path, "/api/v3/auth/methods")
  }

  func test_getMethods_willSendEnvHeaderAndNoBearer() async throws {
    self.requests.enqueue(AuthTestFixtures.methodsResponse(["EMAIL_MAGIC_LINK"]))

    _ = try await self.auth.getMethods()

    let request = try XCTUnwrap(self.requests.lastRequest)
    XCTAssertEqual(request.headers["x-portal-auth-environment-id"], "env-1234")
    XCTAssertNil(request.bearerToken)
  }

  func test_getMethods_willDropUnknownMethods() async throws {
    self.requests.enqueue(AuthTestFixtures.methodsResponse(["EMAIL_MAGIC_LINK", "PASSKEY", "GOOGLE"]))

    let result = try await self.auth.getMethods()

    XCTAssertEqual(result.allowedAuthMethods, [.emailMagicLink, .google])
  }

  func test_getMethods_willReturnEmptyList_whenAllMethodsUnknown() async throws {
    self.requests.enqueue(AuthTestFixtures.methodsResponse(["PASSKEY"]))

    let result = try await self.auth.getMethods()

    XCTAssertEqual(result.allowedAuthMethods, [])
  }

  func test_getMethods_willReadMissingAutoCreateWalletAsFalse() async throws {
    self.requests.enqueue(AuthTestFixtures.envelope(["allowedAuthMethods": ["EMAIL_MAGIC_LINK"]]))

    let result = try await self.auth.getMethods()

    XCTAssertFalse(result.autoCreateWallet)
  }

  func test_getMethods_willThrowMalformedResponse_whenEnvelopeMissingData() async throws {
    self.requests.enqueue(AuthTestFixtures.json(["meta": [String: String]()]))

    await XCTAssertThrowsAsync(
      try await self.auth.getMethods(),
      expected: PortalAuthError.malformedResponse(path: "/api/v3/auth/methods", missing: nil)
    )
  }

  func test_getMethods_willPassThroughUnauthorized() async throws {
    self.requests.failWith = AuthTestFixtures.unauthorized

    await XCTAssertThrowsAsync(try await self.auth.getMethods(), expected: PortalRequestsError.unauthorized)
    XCTAssertEqual(self.requests.unauthorizedHookInvocations, 0)
    XCTAssertNil(self.requests.onUnauthorized)
  }

  // MARK: - sendMagicLink

  func test_sendMagicLink_willThrowMagicLinkNotConfigured_withoutRequest() async throws {
    let subject = self.makeSubject(requests: self.requests, storage: self.storage, magicLink: nil)

    let error = await XCTAssertThrowsAsync(
      try await subject.sendMagicLink("user@example.com"),
      expected: PortalAuthError.magicLinkNotConfigured
    )

    XCTAssertEqual(
      (error as? PortalAuthError)?.errorDescription,
      "[PortalAuth] sendMagicLink() requires `magicLink` (fromEmail, templateId) to be passed to the PortalAuth constructor."
    )
    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_sendMagicLink_willPostConfiguredRedirectUrl() async throws {
    self.requests.enqueue(AuthTestFixtures.sentResponse)

    try await self.auth.sendMagicLink("user@example.com")

    XCTAssertEqual(self.requests.callCount, 1)
    let request = try XCTUnwrap(self.requests.lastRequest)
    XCTAssertEqual(request.method, .post)
    XCTAssertEqual(request.path, "/api/v3/auth/magic-links")
    XCTAssertEqual(try self.lastPayload()["redirectUrl"] as? String, AuthTestFixtures.redirectUrl)
  }

  func test_sendMagicLink_willForwardFromEmailAndTemplateId() async throws {
    self.requests.enqueue(AuthTestFixtures.sentResponse)

    try await self.auth.sendMagicLink("user@example.com")

    let payload = try self.lastPayload()
    XCTAssertEqual(payload["email"] as? String, "user@example.com")
    XCTAssertEqual(payload["fromEmail"] as? String, "login@example.com")
    XCTAssertEqual(payload["templateId"] as? String, "template-1")
    XCTAssertEqual(payload["redirectUrl"] as? String, AuthTestFixtures.redirectUrl)
    XCTAssertEqual(Set(payload.keys), ["email", "redirectUrl", "fromEmail", "templateId"])
  }

  func test_sendMagicLink_willTrimAndLowercaseEmail() async throws {
    self.requests.enqueue(AuthTestFixtures.sentResponse)

    try await self.auth.sendMagicLink("  User@Example.COM \n")

    XCTAssertEqual(try self.lastPayload()["email"] as? String, "user@example.com")
  }

  func test_sendMagicLink_willThrowInvalidArgument_withoutRequest_whenEmailBlank() async throws {
    for email in ["", "   "] {
      await XCTAssertThrowsAsync(
        try await self.auth.sendMagicLink(email),
        expected: PortalAuthError.invalidArgument(name: "email")
      )
    }

    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_sendMagicLink_willForwardIsAccountAbstractedTrue() async throws {
    let subject = self.makeSubject(requests: self.requests, storage: self.storage, isAccountAbstracted: true)
    self.requests.enqueue(AuthTestFixtures.sentResponse)

    try await subject.sendMagicLink("user@example.com")

    let payload = try self.lastPayload()
    XCTAssertEqual(payload["isAccountAbstracted"] as? Bool, true)
    XCTAssertNil(payload["isAccountAbstracted"] as? String)
  }

  func test_sendMagicLink_willForwardIsAccountAbstractedFalse() async throws {
    let subject = self.makeSubject(requests: self.requests, storage: self.storage, isAccountAbstracted: false)
    self.requests.enqueue(AuthTestFixtures.sentResponse)

    try await subject.sendMagicLink("user@example.com")

    let payload = try self.lastPayload()
    XCTAssertTrue(payload.keys.contains("isAccountAbstracted"))
    XCTAssertEqual(payload["isAccountAbstracted"] as? Bool, false)
  }

  func test_sendMagicLink_willOmitIsAccountAbstracted_whenNil() async throws {
    self.requests.enqueue(AuthTestFixtures.sentResponse)

    try await self.auth.sendMagicLink("user@example.com")

    XCTAssertFalse(try self.lastPayload().keys.contains("isAccountAbstracted"))
  }

  func test_sendMagicLink_willIgnoreResponseBody() async throws {
    let bodies = [
      AuthTestFixtures.envelope(["sent": true]),
      Data("{}".utf8),
      Data(),
      Data("<html>".utf8)
    ]
    for body in bodies {
      self.requests.enqueue(body)
    }

    for _ in bodies {
      try await self.auth.sendMagicLink("user@example.com")
    }

    XCTAssertEqual(self.requests.callCount, bodies.count)
  }

  func test_sendMagicLink_willThrowRateLimited_when429_andNotRetry() async throws {
    self.requests.failWith = AuthTestFixtures.rateLimited429

    let error = await XCTAssertThrowsAsync(
      try await self.auth.sendMagicLink("user@example.com"),
      expected: PortalAuthError.rateLimited
    )

    XCTAssertEqual(
      (error as? PortalAuthError)?.errorDescription,
      "[PortalAuth] Too many magic links were sent to this address. Wait a minute before trying again."
    )
    XCTAssertEqual(self.requests.callCount, 1)
  }

  func test_sendMagicLink_willThrowAccountAbstractionUnavailable_when400WithErrorBody() async throws {
    let subject = self.makeSubject(requests: self.requests, storage: self.storage, isAccountAbstracted: true)
    self.requests.failWith = AuthTestFixtures.clientError(status: 400, body: "{\"error\":\"Account abstraction is not enabled\"}")

    await XCTAssertThrowsAsync(
      try await subject.sendMagicLink("user@example.com"),
      expected: PortalAuthError.accountAbstractionUnavailable(message: "Account abstraction is not enabled")
    )
  }

  func test_sendMagicLink_willBoundAccountAbstractionMessageTo200Chars() async throws {
    // The mapping only applies when the request asked for account abstraction.
    let subject = self.makeSubject(requests: self.requests, storage: self.storage, isAccountAbstracted: true)
    let longMessage = String(repeating: "x", count: 500)
    self.requests.failWith = AuthTestFixtures.clientError(status: 400, body: "{\"error\":\"\(longMessage)\"}")

    await XCTAssertThrowsAsync(try await subject.sendMagicLink("user@example.com")) { error in
      guard case let .accountAbstractionUnavailable(message)? = error as? PortalAuthError else {
        XCTFail("Expected PortalAuthError.accountAbstractionUnavailable, got \(type(of: error)).")
        return
      }
      XCTAssertEqual(message.count, 200)
      XCTAssertEqual(message, String(repeating: "x", count: 200))
      XCTAssertFalse(message.contains(String(repeating: "x", count: 201)))
    }
  }

  func test_sendMagicLink_willPassThrough400_whenBodyLacksErrorKey() async throws {
    let transportError = AuthTestFixtures.clientError(status: 400, body: "{\"message\":\"bad\"}")
    self.requests.failWith = transportError

    await XCTAssertThrowsAsync(try await self.auth.sendMagicLink("user@example.com"), expected: transportError)
  }

  func test_sendMagicLink_willPassThroughUnauthorized() async throws {
    self.requests.failWith = AuthTestFixtures.unauthorized

    await XCTAssertThrowsAsync(try await self.auth.sendMagicLink("user@example.com"), expected: PortalRequestsError.unauthorized)
    XCTAssertEqual(self.requests.unauthorizedHookInvocations, 0)
  }

  func test_sendMagicLink_willPassThrough5xx() async throws {
    let transportError = AuthTestFixtures.serverError503
    self.requests.failWith = transportError

    await XCTAssertThrowsAsync(try await self.auth.sendMagicLink("user@example.com"), expected: transportError)
    XCTAssertEqual(self.requests.callCount, 1)
  }

  func test_sendMagicLink_willNotLogEmail() async throws {
    self.requests.enqueue(AuthTestFixtures.sentResponse)

    try await self.auth.sendMagicLink("Secret.Person@Example.com")

    self.assertNoSecrets(["secret.person@example.com", "Secret.Person"])
  }

  // MARK: - loginWithGoogle / loginWithApple

  func test_loginWithGoogle_willReturnGoogleUrl() async throws {
    let googleUrl = "https://accounts.google.com/o/oauth2/v2/auth?state=abc"
    self.requests.enqueue(AuthTestFixtures.oauthUrlsResponse(google: googleUrl))

    let result = try await self.auth.loginWithGoogle()

    XCTAssertEqual(result.authorizeUrl, googleUrl)
    XCTAssertEqual(self.requests.callCount, 1)
    XCTAssertEqual(self.requests.lastRequest?.method, .get)
  }

  func test_loginWithGoogleAndApple_willEachReturnOwnKeyFromSameResponse() async throws {
    let googleUrl = "https://accounts.google.com/o/oauth2/v2/auth?state=shared"
    let appleUrl = "https://appleid.apple.com/auth/authorize?state=shared"
    let body = AuthTestFixtures.oauthUrlsResponse(google: googleUrl, apple: appleUrl)
    self.requests.enqueue(body)
    self.requests.enqueue(body)

    let google = try await self.auth.loginWithGoogle()
    let apple = try await self.auth.loginWithApple()

    XCTAssertEqual(google.authorizeUrl, googleUrl)
    XCTAssertEqual(apple.authorizeUrl, appleUrl)
  }

  func test_loginWithApple_willThrowAuthMethodUnavailableApple_whenOnlyGoogleEnabled() async throws {
    self.requests.enqueue(AuthTestFixtures.oauthUrlsResponse(google: AuthTestFixtures.googleAuthorizeUrl, apple: nil))

    let error = await XCTAssertThrowsAsync(
      try await self.auth.loginWithApple(),
      expected: PortalAuthError.authMethodUnavailable(.apple)
    )

    XCTAssertEqual(
      (error as? PortalAuthError)?.errorDescription,
      "[PortalAuth] APPLE is not an enabled auth method for this auth environment."
    )
  }

  func test_loginWithGoogle_willThrowAuthMethodUnavailableGoogle_whenOnlyAppleEnabled() async throws {
    self.requests.enqueue(AuthTestFixtures.oauthUrlsResponse(google: nil, apple: AuthTestFixtures.appleAuthorizeUrl))

    await XCTAssertThrowsAsync(
      try await self.auth.loginWithGoogle(),
      expected: PortalAuthError.authMethodUnavailable(.google)
    )
  }

  func test_loginWithGoogle_willThrowAuthMethodUnavailable_whenDataEmpty() async throws {
    self.requests.enqueue(AuthTestFixtures.envelope([String: String]()))

    let error = await XCTAssertThrowsAsync(
      try await self.auth.loginWithGoogle(),
      expected: PortalAuthError.authMethodUnavailable(.google)
    )

    let description = try XCTUnwrap((error as? PortalAuthError)?.errorDescription)
    XCTAssertTrue(description.contains("GOOGLE"), description)
  }

  func test_loginWithGoogle_willThrowAuthMethodUnavailable_whenUrlBlank() async throws {
    for blank in ["", "   ", "\n"] {
      let requests = RecordingPortalRequests()
      let subject = self.makeSubject(requests: requests)
      requests.enqueue(AuthTestFixtures.oauthUrlsResponse(google: blank))

      await XCTAssertThrowsAsync(
        try await subject.loginWithGoogle(),
        expected: PortalAuthError.authMethodUnavailable(.google)
      )
    }
  }

  func test_loginWithApple_willThrowAuthMethodUnavailable_whenUrlBlank() async throws {
    self.requests.enqueue(AuthTestFixtures.oauthUrlsResponse(apple: "  "))

    await XCTAssertThrowsAsync(
      try await self.auth.loginWithApple(),
      expected: PortalAuthError.authMethodUnavailable(.apple)
    )
  }

  func test_loginWithGoogle_willTrimAuthorizeUrl() async throws {
    self.requests.enqueue(AuthTestFixtures.oauthUrlsResponse(google: "  https://google/auth  "))

    let result = try await self.auth.loginWithGoogle()

    XCTAssertEqual(result.authorizeUrl, "https://google/auth")
  }

  func test_loginWithGoogle_willFetchFreshUrlOnEveryCall() async throws {
    self.requests.enqueue(AuthTestFixtures.oauthUrls())
    self.requests.enqueue(AuthTestFixtures.oauthUrls())

    _ = try await self.auth.loginWithGoogle()
    _ = try await self.auth.loginWithGoogle()

    XCTAssertEqual(self.requests.callCount, 2)
  }

  func test_loginWithGoogle_willSendEncodedRedirectUrl() async throws {
    self.requests.enqueue(AuthTestFixtures.oauthUrls())

    _ = try await self.auth.loginWithGoogle()

    XCTAssertEqual(
      self.requests.lastRequest?.absoluteString,
      "https://api.portalhq.io/api/v3/auth/oauth/urls?redirectUrl=portalexample%3A%2F%2Fauth%2Fcallback"
    )
  }

  func test_loginWithGoogle_willOmitIsAccountAbstracted_whenNil() async throws {
    self.requests.enqueue(AuthTestFixtures.oauthUrls())

    _ = try await self.auth.loginWithGoogle()

    let url = try XCTUnwrap(self.requests.lastRequest?.absoluteString)
    XCTAssertFalse(url.contains("isAccountAbstracted"), url)
  }

  func test_loginWithGoogle_willAppendIsAccountAbstractedLiteralTrueAndFalse() async throws {
    for isAccountAbstracted in [true, false] {
      let requests = RecordingPortalRequests()
      let subject = self.makeSubject(requests: requests, isAccountAbstracted: isAccountAbstracted)
      requests.enqueue(AuthTestFixtures.oauthUrls())

      _ = try await subject.loginWithGoogle()

      let url = try XCTUnwrap(requests.lastRequest?.absoluteString)
      XCTAssertTrue(url.hasSuffix("&isAccountAbstracted=\(isAccountAbstracted ? "true" : "false")"), url)
    }
  }

  func test_loginWithApple_willPassThroughUnauthorized() async throws {
    self.requests.failWith = AuthTestFixtures.unauthorized

    await XCTAssertThrowsAsync(try await self.auth.loginWithApple(), expected: PortalRequestsError.unauthorized)
    XCTAssertEqual(self.requests.unauthorizedHookInvocations, 0)
  }

  func test_loginWithGoogle_willThrowAccountAbstractionUnavailable_when400WithErrorBody() async throws {
    let subject = self.makeSubject(requests: self.requests, isAccountAbstracted: true)
    self.requests.failWith = AuthTestFixtures.clientError(status: 400, body: "{\"error\":\"AA not configured\"}")

    await XCTAssertThrowsAsync(
      try await subject.loginWithGoogle(),
      expected: PortalAuthError.accountAbstractionUnavailable(message: "AA not configured")
    )
  }

  func test_loginWithGoogle_willPassThrough5xx() async throws {
    let transportError = AuthTestFixtures.serverError503
    self.requests.failWith = transportError

    await XCTAssertThrowsAsync(try await self.auth.loginWithGoogle(), expected: transportError)
    XCTAssertEqual(self.requests.callCount, 1)
  }

  func test_loginWithGoogle_willNotInvokeWebSessionFactory() async throws {
    let webSession = FakeAuthWebSession()
    let subject = self.makeSubject(requests: self.requests, webSessionFactory: webSession.factory)
    self.requests.enqueue(AuthTestFixtures.oauthUrls())
    self.requests.enqueue(AuthTestFixtures.oauthUrls())

    _ = try await subject.loginWithGoogle()
    _ = try await subject.loginWithApple()

    XCTAssertEqual(webSession.factoryInvocations, 0)
  }

  func test_loginWithGoogle_willNotLogAuthorizeUrl() async throws {
    let googleUrl = "https://accounts.google.com/o/oauth2/v2/auth?state=SECRET-STATE"
    self.requests.enqueue(AuthTestFixtures.oauthUrlsResponse(google: googleUrl))

    _ = try await self.auth.loginWithGoogle()

    self.assertNoSecrets(["SECRET-STATE", "accounts.google.com"])
  }

  // MARK: - handleRedirect(String) — matching and parsing

  func test_handleRedirect_willReturnNil_whenEmpty() async throws {
    let result = try await self.auth.handleRedirect("")

    XCTAssertNil(result)
    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_handleRedirect_willReturnNil_whenWhitespaceOnly() async throws {
    let result = try await self.auth.handleRedirect("   \n")

    XCTAssertNil(result)
    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_handleRedirect_willReturnNil_whenOversized_withoutParsing() async throws {
    let url = AuthTestFixtures.redirectUrl + "?authMethod=EMAIL_MAGIC_LINK&token=" + String(repeating: "a", count: 9000)

    let result = try await self.auth.handleRedirect(url)

    XCTAssertNil(result)
    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_handleRedirect_willReturnNil_whenExactly8193Utf16Units() async throws {
    let url = try self.paddedMagicLinkRedirect(totalUtf16: 8193)

    let result = try await self.auth.handleRedirect(url)

    XCTAssertNil(result)
    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_handleRedirect_willExchange_whenExactly8192Utf16Units() async throws {
    let url = try self.paddedMagicLinkRedirect(totalUtf16: 8192)
    self.requests.enqueue(AuthTestFixtures.grantResponse())

    let result = try await self.auth.handleRedirect(url)

    _ = try self.authenticated(result)
    XCTAssertEqual(self.requests.callCount, 1)
  }

  func test_handleRedirect_willMeasureUtf16Units_notCharacters() async throws {
    let token = String(repeating: "😀", count: 4100)
    let url = "\(AuthTestFixtures.redirectUrl)?token=\(token)&authMethod=\(AuthMethod.emailMagicLink.rawValue)"
    XCTAssertLessThan(url.count, 8192)
    XCTAssertGreaterThan(url.utf16.count, 8192)

    let result = try await self.auth.handleRedirect(url)

    XCTAssertNil(result)
    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_handleRedirect_willReturnNil_whenTargetsOtherHandler() async throws {
    let result = try await self.auth.handleRedirect("otherapp://auth/callback?token=grant&authMethod=EMAIL_MAGIC_LINK")

    XCTAssertNil(result)
    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_handleRedirect_willReturnNil_whenPathCaseDiffers() async throws {
    let result = try await self.auth.handleRedirect("portalexample://auth/Callback?token=g&authMethod=EMAIL_MAGIC_LINK")

    XCTAssertNil(result)
    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_handleRedirect_willReturnNil_whenNoToken() async throws {
    let result = try await self.auth.handleRedirect(AuthTestFixtures.redirectUrl + "?authMethod=EMAIL_MAGIC_LINK")

    XCTAssertNil(result)
    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_handleRedirect_willReturnNil_whenTokenEmpty() async throws {
    let urls = [
      AuthTestFixtures.redirectUrl + "?token=&authMethod=EMAIL_MAGIC_LINK",
      AuthTestFixtures.redirectUrl + "?token&authMethod=EMAIL_MAGIC_LINK"
    ]

    for url in urls {
      let result = try await self.auth.handleRedirect(url)
      XCTAssertNil(result, url)
    }

    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_handleRedirect_willReturnNil_whenNoMarker() async throws {
    let result = try await self.auth.handleRedirect(AuthTestFixtures.redirectUrl + "?token=grant-token")

    XCTAssertNil(result)
    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_handleRedirect_willReturnNil_whenMarkerUnknownOrWrongCase() async throws {
    let markers = ["login_type=FACEBOOK", "login_type=google", "authMethod=GOOGLE", "authMethod=email_magic_link"]

    for marker in markers {
      let result = try await self.auth.handleRedirect("\(AuthTestFixtures.redirectUrl)?token=grant-token&\(marker)")
      XCTAssertNil(result, marker)
    }

    XCTAssertEqual(self.requests.callCount, 0)
  }

  // MARK: - handleRedirect(String) — error parameter

  func test_handleRedirect_willThrowAuthenticationFailed_whenErrorParam_withoutRequest() async throws {
    let error = await XCTAssertThrowsAsync(
      try await self.auth.handleRedirect(AuthTestFixtures.redirectUrl + "?error=oauth_failed"),
      expected: PortalAuthError.authenticationFailed(error: "oauth_failed")
    )

    XCTAssertEqual((error as? PortalAuthError)?.errorDescription, "[PortalAuth] Authentication failed: oauth_failed")
    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_handleRedirect_willTruncateErrorToExactly100() async throws {
    let url = AuthTestFixtures.redirectUrl + "?error=" + String(repeating: "x", count: 500)

    await XCTAssertThrowsAsync(try await self.auth.handleRedirect(url)) { error in
      guard case let .authenticationFailed(reported)? = error as? PortalAuthError else {
        XCTFail("Expected PortalAuthError.authenticationFailed, got \(type(of: error)).")
        return
      }
      XCTAssertEqual(reported.count, 100)
      let description = (error as? PortalAuthError)?.errorDescription ?? ""
      XCTAssertTrue(description.contains(String(repeating: "x", count: 100)))
      XCTAssertFalse(description.contains(String(repeating: "x", count: 101)))
    }
  }

  func test_handleRedirect_willNotTruncateError_whenExactly100() async throws {
    let reported = String(repeating: "x", count: 100)

    await XCTAssertThrowsAsync(
      try await self.auth.handleRedirect(AuthTestFixtures.redirectUrl + "?error=" + reported),
      expected: PortalAuthError.authenticationFailed(error: reported)
    )
  }

  func test_handleRedirect_willTruncateErrorByCharacters_forMultiByte() async throws {
    let url = AuthTestFixtures.redirectUrl + "?error=" + String(repeating: "%C3%A9", count: 200)

    await XCTAssertThrowsAsync(try await self.auth.handleRedirect(url)) { error in
      guard case let .authenticationFailed(reported)? = error as? PortalAuthError else {
        XCTFail("Expected PortalAuthError.authenticationFailed, got \(type(of: error)).")
        return
      }
      XCTAssertEqual(reported.count, 100)
      XCTAssertEqual(reported, String(repeating: "é", count: 100))
    }
  }

  func test_handleRedirect_willDecodeErrorBeforeTruncating() async throws {
    await XCTAssertThrowsAsync(
      try await self.auth.handleRedirect(AuthTestFixtures.redirectUrl + "?error=oauth%5Ffailed+now"),
      expected: PortalAuthError.authenticationFailed(error: "oauth_failed now")
    )
  }

  func test_handleRedirect_willPreferErrorOverToken() async throws {
    let url = AuthTestFixtures.redirectUrl + "?token=grant-token&authMethod=EMAIL_MAGIC_LINK&error=denied"

    await XCTAssertThrowsAsync(
      try await self.auth.handleRedirect(url),
      expected: PortalAuthError.authenticationFailed(error: "denied")
    )
    XCTAssertEqual(self.requests.callCount, 0)
    XCTAssertEqual(self.storage.setCalls, 0)
  }

  func test_handleRedirect_willThrowAuthenticationFailed_whenErrorEmpty() async throws {
    let url = AuthTestFixtures.redirectUrl + "?error=&token=grant-token&authMethod=EMAIL_MAGIC_LINK"

    await XCTAssertThrowsAsync(
      try await self.auth.handleRedirect(url),
      expected: PortalAuthError.authenticationFailed(error: "")
    )
    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_handleRedirect_willReturnNil_whenErrorOnOtherTarget() async throws {
    let result = try await self.auth.handleRedirect("otherapp://auth/callback?error=oauth_failed")

    XCTAssertNil(result)
    XCTAssertEqual(self.requests.callCount, 0)
  }

  // MARK: - handleRedirect(String) — routing

  func test_handleRedirect_willRouteAuthMethodToMagicLinkValidations() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse())

    _ = try await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect())

    XCTAssertEqual(self.requests.callCount, 1)
    let request = try XCTUnwrap(self.requests.lastRequest)
    XCTAssertEqual(request.method, .post)
    XCTAssertEqual(request.absoluteString, "https://api.portalhq.io/api/v3/auth/magic-links/validations")
    let payload = try self.lastPayload()
    XCTAssertEqual(payload["token"] as? String, "grant-token")
    XCTAssertEqual(payload.count, 1)
  }

  func test_handleRedirect_willRouteLoginTypeGoogleToOauthTokens() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse())

    _ = try await self.auth.handleRedirect(AuthTestFixtures.oauthRedirect())

    let request = try XCTUnwrap(self.requests.lastRequest)
    XCTAssertEqual(request.method, .post)
    XCTAssertEqual(request.absoluteString, "https://api.portalhq.io/api/v3/auth/oauth/tokens")
    XCTAssertEqual(try self.lastPayload()["token"] as? String, "grant-token")
  }

  func test_handleRedirect_willRouteLoginTypeAppleToOauthTokens() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse())

    let result = try await self.auth.handleRedirect(AuthTestFixtures.oauthRedirect(loginType: "APPLE"))

    let authenticated = try self.authenticated(result)
    XCTAssertEqual(self.requests.lastRequest?.path, "/api/v3/auth/oauth/tokens")
    XCTAssertEqual(try authenticated.session.getToken(), "session-token")
    XCTAssertEqual(self.storage.setCalls, 1)
  }

  func test_handleRedirect_willRouteBothMarkers_onOneInstance() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse())
    self.requests.enqueue(AuthTestFixtures.grantResponse())

    _ = try await self.auth.handleRedirect(AuthTestFixtures.oauthRedirect("oauth-grant"))
    _ = try await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect("magic-link-grant"))

    XCTAssertEqual(self.requests.requestedPaths, ["/api/v3/auth/oauth/tokens", "/api/v3/auth/magic-links/validations"])
  }

  func test_handleRedirect_willPreferAuthMethod_whenBothMarkersPresent() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse())

    _ = try await self.auth.handleRedirect(AuthTestFixtures.redirectUrl + "?token=g&authMethod=EMAIL_MAGIC_LINK&login_type=GOOGLE")

    XCTAssertEqual(self.requests.requestedPaths, ["/api/v3/auth/magic-links/validations"])
  }

  func test_handleRedirect_willDecodePercentEncodedToken_andTolerateRedirectOwnQuery() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse())

    _ = try await self.auth.handleRedirect(AuthTestFixtures.redirectUrl + "?source=email&token=grant%2Btoken&authMethod=EMAIL_MAGIC_LINK")

    XCTAssertEqual(try self.lastPayload()["token"] as? String, "grant+token")
  }

  func test_handleRedirect_willUseLastDuplicatedToken_magicLink() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse())

    _ = try await self.auth.handleRedirect(AuthTestFixtures.redirectUrl + "?token=configured&authMethod=EMAIL_MAGIC_LINK&token=live-grant")

    XCTAssertEqual(try self.lastPayload()["token"] as? String, "live-grant")
  }

  func test_handleRedirect_willUseLastDuplicatedToken_oauth() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse())

    _ = try await self.auth.handleRedirect(AuthTestFixtures.redirectUrl + "?token=stale&token=real-grant&login_type=GOOGLE")

    XCTAssertEqual(try self.lastPayload()["token"] as? String, "real-grant")
  }

  func test_handleRedirect_willMatch_whenSchemeCaseAndTrailingSlashDiffer() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse())

    let result = try await self.auth.handleRedirect("PortalExample://auth/callback/?token=grant-token&authMethod=EMAIL_MAGIC_LINK")

    _ = try self.authenticated(result)
    XCTAssertEqual(self.requests.callCount, 1)
  }

  func test_handleRedirect_willMatch_whenFragmentPresent() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse())

    let result = try await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect() + "#state=xyz")

    _ = try self.authenticated(result)
    XCTAssertEqual(try self.lastPayload()["token"] as? String, "grant-token")
  }

  func test_handleRedirect_willReturnNil_whenQueryLivesInFragment() async throws {
    let result = try await self.auth.handleRedirect(AuthTestFixtures.redirectUrl + "#?token=grant&authMethod=EMAIL_MAGIC_LINK")

    XCTAssertNil(result)
    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_handleRedirect_willMatch_whenSurroundingWhitespace() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse())

    let result = try await self.auth.handleRedirect("  " + AuthTestFixtures.magicLinkRedirect() + "\n")

    _ = try self.authenticated(result)
    XCTAssertEqual(self.requests.callCount, 1)
  }

  // MARK: - handleRedirect(String) — persistence and results

  func test_handleRedirect_willReturnAuthenticated_andPersistExactJson_magicLink() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse())

    let result = try self.authenticated(await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect()))

    XCTAssertEqual(try result.session.getToken(), "session-token")
    XCTAssertEqual(result.session.endUserId, "user-1")
    XCTAssertEqual(self.storage.setCalls, 1)
    let stored = try XCTUnwrap(self.storage.storedJSON)
    XCTAssertEqual(stored.count, 2)
    XCTAssertEqual(stored["clientSessionToken"] as? String, "session-token")
    XCTAssertEqual(stored["endUserId"] as? String, "user-1")
  }

  func test_handleRedirect_willReturnAuthenticated_andPersist_oauth() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse())

    let result = try self.authenticated(await self.auth.handleRedirect(AuthTestFixtures.oauthRedirect()))

    XCTAssertEqual(result.session.endUserId, "user-1")
    XCTAssertEqual(try result.session.getToken(), "session-token")
    XCTAssertEqual(self.storage.setCalls, 1)
    let stored = try XCTUnwrap(self.storage.storedJSON)
    XCTAssertEqual(stored.count, 2)
    XCTAssertEqual(stored["clientSessionToken"] as? String, "session-token")
    XCTAssertEqual(stored["endUserId"] as? String, "user-1")
  }

  func test_handleRedirect_willPersistBeforeReturning() async throws {
    let persistObserved = LockedFlag()
    self.storage.onSet = { _ in persistObserved.set() }
    self.requests.enqueue(AuthTestFixtures.grantResponse())

    let result = try self.authenticated(await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect()))

    XCTAssertTrue(persistObserved.value, "The session was returned without ever being written to storage.")
    XCTAssertNotNil(self.storage.stored)
    XCTAssertEqual(self.storage.events, [.set])

    let restored = try await self.auth.restoreSession()
    XCTAssertEqual(try XCTUnwrap(restored).getToken(), try result.session.getToken())
  }

  func test_handleRedirect_willSurfaceClientMetadata_bothEndpoints() async throws {
    let redirects = [AuthTestFixtures.magicLinkRedirect(), AuthTestFixtures.oauthRedirect()]

    for redirect in redirects {
      let requests = RecordingPortalRequests()
      let subject = self.makeSubject(requests: requests)
      requests.enqueue(AuthTestFixtures.grantResponse(clientId: "client-9", isAccountAbstracted: true))

      let result = try self.authenticated(await subject.handleRedirect(redirect))

      XCTAssertEqual(result.clientId, "client-9", redirect)
      XCTAssertEqual(result.isAccountAbstracted, true, redirect)
    }
  }

  func test_handleRedirect_willReportNilMetadata_whenOmitted() async throws {
    let redirects = [AuthTestFixtures.magicLinkRedirect(), AuthTestFixtures.oauthRedirect()]

    for redirect in redirects {
      let requests = RecordingPortalRequests()
      let subject = self.makeSubject(requests: requests)
      requests.enqueue(AuthTestFixtures.grantResponse())

      let result = try self.authenticated(await subject.handleRedirect(redirect))

      XCTAssertNil(result.clientId, redirect)
      XCTAssertNil(result.isAccountAbstracted, redirect)
    }
  }

  func test_handleRedirect_willReportIsAccountAbstractedFalse_whenFalse() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse(isAccountAbstracted: false))

    let result = try self.authenticated(await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect()))

    XCTAssertEqual(result.isAccountAbstracted, false)
    XCTAssertNotNil(result.isAccountAbstracted)
  }

  func test_handleRedirect_willThrowSessionStorageFailure_andMemoiseTheIssuedSession_whenPersistFails() async throws {
    let redirect = AuthTestFixtures.magicLinkRedirect()
    self.storage.onSet = { _ in throw PortalAuthError.sessionStorageFailure(message: "keystore write failed") }
    self.requests.enqueue(AuthTestFixtures.grantResponse())

    await XCTAssertThrowsAsync(
      try await self.auth.handleRedirect(redirect),
      expected: PortalAuthError.sessionStorageFailure(message: "keystore write failed")
    )

    // The backend burned the grant when it answered, so re-sending it could only fail with 401.
    // The issued session was memoised before the write; the replay retries the write instead.
    self.storage.onSet = nil

    let result = try self.authenticated(await self.auth.handleRedirect(redirect))

    XCTAssertEqual(try result.session.getToken(), "session-token")
    XCTAssertEqual(self.requests.callCount, 1, "A spent grant is never re-sent to the backend.")
    XCTAssertEqual(self.storage.setCalls, 2, "The replay performed the Keychain write the first delivery could not.")
  }

  func test_handleRedirect_willThrowAgain_andKeepTheMemo_whenPersistKeepsFailing() async throws {
    let redirect = AuthTestFixtures.magicLinkRedirect()
    self.storage.onSet = { _ in throw PortalAuthError.sessionStorageFailure(message: "keystore write failed") }
    self.requests.enqueue(AuthTestFixtures.grantResponse())

    for _ in 0 ..< 2 {
      await XCTAssertThrowsAsync(
        try await self.auth.handleRedirect(redirect),
        expected: PortalAuthError.sessionStorageFailure(message: "keystore write failed")
      )
    }

    XCTAssertEqual(self.requests.callCount, 1, "Every retry goes to the Keychain, never back to the backend.")
    XCTAssertEqual(self.storage.setCalls, 2)
  }

  func test_handleRedirect_willNotReplayAnInvalidatedSession() async throws {
    let redirect = AuthTestFixtures.magicLinkRedirect()
    self.requests.enqueue(AuthTestFixtures.grantResponse())
    let first = try self.authenticated(await self.auth.handleRedirect(redirect))

    // A 401 elsewhere (or a host sign-out) ended the session behind the memo.
    try first.session.invalidate()

    // Handing back `.authenticated` with a session whose `getToken()` throws would leave the
    // host signed in against a dead credential; the redirect fails like a spent grant instead.
    await XCTAssertThrowsAsync(
      try await self.auth.handleRedirect(redirect),
      expected: PortalRequestsError.unauthorized
    )
    XCTAssertEqual(self.requests.callCount, 1, "The spent grant is not re-sent after eviction either.")
  }

  func test_handleRedirect_willThrowInvalidGrantResponse_whenUserJwtIsBlank() async throws {
    // A whitespace-only `userJwt` is as absent as a missing one: accepting it would hand the host
    // a TOTP step whose code can never be verified.
    self.requests.enqueue(AuthTestFixtures.grantResponse(clientSessionToken: nil, userJwt: "   "))

    await XCTAssertThrowsAsync(
      try await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect()),
      expected: PortalAuthError.invalidGrantResponse
    )
  }

  func test_handleRedirect_willThrowMalformedResponse_whenCstPresentButEndUserIdMissingOrBlank() async throws {
    let nullEndUserId: [String: Any] = ["clientSessionToken": "session", "endUserId": NSNull()]
    let bodies: [Data] = [
      AuthTestFixtures.grantResponse(clientSessionToken: "session", endUserId: nil),
      AuthTestFixtures.envelope(nullEndUserId),
      AuthTestFixtures.grantResponse(clientSessionToken: "session", endUserId: ""),
      AuthTestFixtures.grantResponse(clientSessionToken: "session", endUserId: "   ")
    ]

    for body in bodies {
      let requests = RecordingPortalRequests()
      let storage = MockAuthSessionStorage()
      let subject = self.makeSubject(requests: requests, storage: storage)
      requests.enqueue(body)

      await XCTAssertThrowsAsync(
        try await subject.handleRedirect(AuthTestFixtures.magicLinkRedirect()),
        expected: PortalAuthError.malformedResponse(path: "/api/v3/auth/magic-links/validations", missing: "endUserId")
      )
      XCTAssertEqual(storage.setCalls, 0)
    }
  }

  func test_handleRedirect_willThrowInvalidGrantResponse_whenNeitherCstNorJwt() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse(clientSessionToken: nil, endUserId: "user-1"))

    let error = await XCTAssertThrowsAsync(
      try await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect()),
      expected: PortalAuthError.invalidGrantResponse
    )

    XCTAssertEqual(
      (error as? PortalAuthError)?.errorDescription,
      "[PortalAuth] The auth grant response carried neither a session token nor a userJwt."
    )
    XCTAssertEqual(self.storage.setCalls, 0)
  }

  func test_handleRedirect_willThrowInvalidGrantResponse_whenBothEmptyStrings() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse(clientSessionToken: "", endUserId: "user-1", userJwt: ""))

    await XCTAssertThrowsAsync(
      try await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect()),
      expected: PortalAuthError.invalidGrantResponse
    )
    XCTAssertEqual(self.storage.setCalls, 0)
  }

  func test_handleRedirect_willThrowInvalidGrantResponse_whenCstWhitespaceOnly_andNoJwt() async throws {
    // `PersistedSessionCodec` and `resolveCredentialToken` both reject a whitespace-only token, so
    // persisting one would hand back a session that fails its first request and is cleared on the
    // next restore. Blank is treated as absent at the source instead.
    self.requests.enqueue(AuthTestFixtures.grantResponse(clientSessionToken: "  \n", endUserId: "user-1"))

    await XCTAssertThrowsAsync(
      try await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect()),
      expected: PortalAuthError.invalidGrantResponse
    )
    XCTAssertEqual(self.storage.setCalls, 0)
    XCTAssertNil(self.storage.stored)
  }

  func test_handleRedirect_willReturnTotpRequired_whenCstWhitespaceOnlyAndJwtPresent() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse(clientSessionToken: "   ", userJwt: AuthTestFixtures.userJwt()))

    let step = try self.totpRequired(await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect()))

    XCTAssertEqual(step.userJwt, AuthTestFixtures.userJwt())
    XCTAssertEqual(self.storage.setCalls, 0)
  }

  func test_handleRedirect_willReturnTotpRequired_whenCstEmptyStringAndJwtPresent() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse(clientSessionToken: "", userJwt: AuthTestFixtures.userJwt()))

    let step = try self.totpRequired(await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect()))

    XCTAssertEqual(step.userJwt, AuthTestFixtures.userJwt())
    XCTAssertEqual(self.storage.setCalls, 0)
  }

  func test_handleRedirect_willReturnTotpRequired_withLink_persistingNothing() async throws {
    let userJwt = AuthTestFixtures.userJwt()
    let totpLink = "otpauth://totp/Portal:user@example.com?secret=GEZDGNBVGY3TQOJQ"
    self.requests.enqueue(AuthTestFixtures.grantResponse(clientSessionToken: nil, userJwt: userJwt, totpLink: totpLink))

    let step = try self.totpRequired(await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect()))

    XCTAssertEqual(step.userJwt, userJwt)
    XCTAssertEqual(step.totpLink, totpLink)
    XCTAssertEqual(step.endUserId, "user-1")
    XCTAssertEqual(self.storage.setCalls, 0)
    XCTAssertNil(self.storage.stored)
  }

  func test_handleRedirect_willReturnTotpRequired_withNilLink_forEnrolledUser() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse(clientSessionToken: nil, userJwt: AuthTestFixtures.userJwt(), totpLink: nil))

    let step = try self.totpRequired(await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect()))

    XCTAssertNil(step.totpLink)
    XCTAssertEqual(self.storage.setCalls, 0)
  }

  func test_handleRedirect_willReturnTotpRequired_forOauthAndApple() async throws {
    let redirects = [AuthTestFixtures.oauthRedirect(), AuthTestFixtures.oauthRedirect(loginType: "APPLE")]

    for redirect in redirects {
      let requests = RecordingPortalRequests()
      let storage = MockAuthSessionStorage()
      let subject = self.makeSubject(requests: requests, storage: storage)
      requests.enqueue(AuthTestFixtures.grantResponse(
        clientSessionToken: nil,
        userJwt: "user-jwt",
        totpLink: "otpauth://totp/Portal:user@example.com?secret=GEZDGNBVGY3TQOJQ"
      ))

      let step = try self.totpRequired(await subject.handleRedirect(redirect))

      XCTAssertEqual(step.userJwt, "user-jwt", redirect)
      XCTAssertEqual(storage.setCalls, 0, redirect)
    }
  }

  func test_handleRedirect_willReturnTotpRequired_withEmptyEndUserId_whenOmitted() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse(clientSessionToken: nil, endUserId: nil, userJwt: AuthTestFixtures.userJwt()))

    let step = try self.totpRequired(await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect()))

    XCTAssertEqual(step.endUserId, "")
  }

  // MARK: - handleRedirect(String) — transport failures and secrecy

  func test_handleRedirect_willPassThroughUnauthorized_persistingNothing() async throws {
    self.requests.failWith = AuthTestFixtures.unauthorized

    await XCTAssertThrowsAsync(
      try await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect()),
      expected: PortalRequestsError.unauthorized
    )
    XCTAssertEqual(self.storage.setCalls, 0)
    XCTAssertEqual(self.requests.unauthorizedHookInvocations, 0)
  }

  func test_handleRedirect_willPassThrough400() async throws {
    let transportError = AuthTestFixtures.clientError(status: 400, body: "{\"error\":\"token already used\"}")
    self.requests.failWith = transportError

    await XCTAssertThrowsAsync(try await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect())) { error in
      XCTAssertEqual(error as? PortalRequestsError, transportError)
      XCTAssertNil(error as? PortalAuthError, "A grant-exchange 400 must not be mapped to accountAbstractionUnavailable.")
    }
    XCTAssertEqual(self.storage.setCalls, 0)
  }

  func test_handleRedirect_willPassThrough5xxAndURLError() async throws {
    let failures: [Error] = [AuthTestFixtures.serverError503, URLError(.notConnectedToInternet)]

    for failure in failures {
      let requests = RecordingPortalRequests()
      let storage = MockAuthSessionStorage()
      let subject = self.makeSubject(requests: requests, storage: storage)
      requests.failWith = failure

      await XCTAssertThrowsAsync(try await subject.handleRedirect(AuthTestFixtures.magicLinkRedirect())) { error in
        if let expected = failure as? PortalRequestsError {
          XCTAssertEqual(error as? PortalRequestsError, expected)
        } else {
          XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
        }
      }
      XCTAssertEqual(storage.setCalls, 0)
      XCTAssertEqual(requests.callCount, 1, "A grant must be exchanged at most once — a retry could burn it.")
    }
  }

  func test_handleRedirect_willSendGrantOnlyToConfiguredHost() async throws {
    let subject = self.makeSubject(requests: self.requests, storage: self.storage, apiHost: "localhost:3000")
    self.requests.enqueue(AuthTestFixtures.grantResponse())

    _ = try await subject.handleRedirect(AuthTestFixtures.magicLinkRedirect())

    XCTAssertEqual(self.requests.requestedUrls, ["http://localhost:3000/api/v3/auth/magic-links/validations"])
  }

  func test_handleRedirect_willNotLogTokenUrlOrCst() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse(clientSessionToken: "CST-SECRET"))

    _ = try await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect("GRANT-SECRET"))

    self.assertNoSecrets(["GRANT-SECRET", "CST-SECRET", "portalexample://auth/callback?"])
  }

  func test_handleRedirect_willNotLogUserJwtOrTotpLink() async throws {
    let userJwt = AuthTestFixtures.userJwt()
    let totpLink = "otpauth://totp/Portal:user@example.com?secret=GEZDGNBVGY3TQOJQ"
    self.requests.enqueue(AuthTestFixtures.grantResponse(clientSessionToken: nil, userJwt: userJwt, totpLink: totpLink))

    _ = try await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect())

    self.assertNoSecrets([userJwt, "GEZDGNBVGY3TQOJQ", "otpauth://"])
  }

  func test_handleRedirect_willNotPutTokensInErrorMessages() async throws {
    let secrets = ["GRANT-SECRET", "CST-SECRET"]

    let failingStorage = MockAuthSessionStorage()
    failingStorage.onSet = { _ in throw PortalAuthError.sessionStorageFailure(message: "keystore write failed") }
    let persistRequests = RecordingPortalRequests()
    let persistSubject = self.makeSubject(requests: persistRequests, storage: failingStorage)
    persistRequests.enqueue(AuthTestFixtures.grantResponse(clientSessionToken: "CST-SECRET"))

    await XCTAssertThrowsAsync(try await persistSubject.handleRedirect(AuthTestFixtures.magicLinkRedirect("GRANT-SECRET"))) { error in
      let description = (error as? LocalizedError)?.errorDescription ?? "\(error)"
      for secret in secrets {
        XCTAssertFalse(description.contains(secret), description)
      }
    }

    let malformedRequests = RecordingPortalRequests()
    let malformedSubject = self.makeSubject(requests: malformedRequests)
    malformedRequests.enqueue(AuthTestFixtures.grantResponse(clientSessionToken: "CST-SECRET", endUserId: nil))

    await XCTAssertThrowsAsync(try await malformedSubject.handleRedirect(AuthTestFixtures.magicLinkRedirect("GRANT-SECRET"))) { error in
      let description = (error as? LocalizedError)?.errorDescription ?? "\(error)"
      for secret in secrets {
        XCTAssertFalse(description.contains(secret), description)
      }
    }
  }

  func test_handleRedirect_willNotExposeCstInSessionDescription() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse())

    let result = try self.authenticated(await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect()))

    XCTAssertFalse(String(describing: result.session).contains("session-token"), String(describing: result.session))
    XCTAssertFalse(String(reflecting: result.session).contains("session-token"), String(reflecting: result.session))
  }

  // MARK: - handleRedirect(URL)

  func test_handleRedirectURL_willExchangeLikeStringOverload() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse())
    let url = try AuthTestFixtures.url(AuthTestFixtures.magicLinkRedirect())

    let result = try await self.auth.handleRedirect(url)

    _ = try self.authenticated(result)
    XCTAssertEqual(try self.lastPayload()["token"] as? String, "grant-token")
    XCTAssertEqual(self.requests.callCount, 1)
  }

  func test_handleRedirectURL_willReturnNil_whenOtherTarget() async throws {
    let url = try AuthTestFixtures.url("otherapp://auth/callback?token=g&authMethod=EMAIL_MAGIC_LINK")

    let result = try await self.auth.handleRedirect(url)

    XCTAssertNil(result)
    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_handleRedirectURL_willThrow_whenErrorParam() async throws {
    let url = try AuthTestFixtures.url(AuthTestFixtures.redirectUrl + "?error=oauth_failed")

    await XCTAssertThrowsAsync(
      try await self.auth.handleRedirect(url),
      expected: PortalAuthError.authenticationFailed(error: "oauth_failed")
    )
  }

  func test_handleRedirectURL_willReturnNil_whenNoQuery() async throws {
    let url = try AuthTestFixtures.url(AuthTestFixtures.redirectUrl)

    let result = try await self.auth.handleRedirect(url)

    XCTAssertNil(result)
    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_handleRedirectURL_willDecodePercentEncodedToken() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse())
    let url = try AuthTestFixtures.url(AuthTestFixtures.redirectUrl + "?token=grant%2Btoken&authMethod=EMAIL_MAGIC_LINK")

    _ = try await self.auth.handleRedirect(url)

    XCTAssertEqual(try self.lastPayload()["token"] as? String, "grant+token")
  }

  func test_handleRedirectURL_willReturnNil_whenOversized() async throws {
    let url = try AuthTestFixtures.url(
      AuthTestFixtures.redirectUrl + "?authMethod=EMAIL_MAGIC_LINK&token=" + String(repeating: "a", count: 9000)
    )

    let result = try await self.auth.handleRedirect(url)

    XCTAssertNil(result)
    XCTAssertEqual(self.requests.callCount, 0)
  }

  // MARK: - verifyTotp

  func test_verifyTotp_willThrowInvalidUserJwt_beforeAnyRequest_whenMalformed() async throws {
    self.requests.enqueue(AuthTestFixtures.totpResponse())

    await XCTAssertThrowsAsync(
      try await self.auth.verifyTotp("777870", userJwt: "not-a-jwt"),
      expected: PortalAuthError.invalidUserJwt(detail: "The provided userJwt is malformed.")
    )
    XCTAssertEqual(self.requests.callCount, 0)
    XCTAssertEqual(self.storage.setCalls, 0)
  }

  func test_verifyTotp_willThrowInvalidUserJwt_beforeAnyRequest_whenEmptyOrBlank() async throws {
    for userJwt in ["", "   "] {
      await XCTAssertThrowsAsync(try await self.auth.verifyTotp("777870", userJwt: userJwt)) { error in
        guard case .invalidUserJwt? = error as? PortalAuthError else {
          XCTFail("Expected PortalAuthError.invalidUserJwt, got \(type(of: error)).")
          return
        }
      }
    }

    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_verifyTotp_willThrowInvalidUserJwt_beforeAnyRequest_whenNoEndUserIdClaim() async throws {
    let userJwt = AuthTestFixtures.jwt(claims: ["nonce": "n"])

    await XCTAssertThrowsAsync(
      try await self.auth.verifyTotp("777870", userJwt: userJwt),
      expected: PortalAuthError.invalidUserJwt(detail: "The userJwt does not carry an endUserId.")
    )
    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_verifyTotp_willThrowInvalidUserJwt_beforeAnyRequest_whenClaimsNotJsonOrNotBase64() async throws {
    let userJwts = [AuthTestFixtures.jwt(claims: "not-json"), "header.not*valid*base64.sig"]

    for userJwt in userJwts {
      await XCTAssertThrowsAsync(try await self.auth.verifyTotp("777870", userJwt: userJwt)) { error in
        guard case .invalidUserJwt? = error as? PortalAuthError else {
          XCTFail("Expected PortalAuthError.invalidUserJwt, got \(type(of: error)).")
          return
        }
      }
    }

    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_verifyTotp_willPostCodeWithBearerJwtAndEnvHeader() async throws {
    let userJwt = AuthTestFixtures.userJwt()
    self.requests.enqueue(AuthTestFixtures.totpResponse())

    _ = try await self.auth.verifyTotp("777870", userJwt: userJwt)

    let request = try XCTUnwrap(self.requests.lastRequest)
    XCTAssertEqual(request.method, .post)
    XCTAssertEqual(request.absoluteString, "https://api.portalhq.io/api/v3/auth/totps/validations")
    let payload = try self.lastPayload()
    XCTAssertEqual(payload["code"] as? String, "777870")
    XCTAssertEqual(payload.count, 1)
    XCTAssertEqual(request.headers["Authorization"], "Bearer " + userJwt)
    XCTAssertEqual(request.headers["x-portal-auth-environment-id"], "env-1234")
  }

  func test_verifyTotp_willPersistWithEndUserIdFromJwt() async throws {
    self.requests.enqueue(AuthTestFixtures.totpResponse(clientSessionToken: "totp-session-token"))

    let result = try await self.auth.verifyTotp("777870", userJwt: AuthTestFixtures.userJwt(endUserId: "user-from-jwt"))

    XCTAssertEqual(result.session.endUserId, "user-from-jwt")
    XCTAssertEqual(try result.session.getToken(), "totp-session-token")
    XCTAssertEqual(self.storage.setCalls, 1)
    let stored = try XCTUnwrap(self.storage.storedJSON)
    XCTAssertEqual(stored.count, 2)
    XCTAssertEqual(stored["clientSessionToken"] as? String, "totp-session-token")
    XCTAssertEqual(stored["endUserId"] as? String, "user-from-jwt")
  }

  func test_verifyTotp_willSurfaceClientMetadata() async throws {
    self.requests.enqueue(AuthTestFixtures.totpResponse(clientId: "client-1", isAccountAbstracted: true))

    let result = try await self.auth.verifyTotp("777870", userJwt: AuthTestFixtures.userJwt())

    XCTAssertEqual(result.clientId, "client-1")
    XCTAssertEqual(result.isAccountAbstracted, true)
  }

  func test_verifyTotp_willReportNilMetadata_whenOmitted() async throws {
    self.requests.enqueue(AuthTestFixtures.totpResponse())

    let result = try await self.auth.verifyTotp("777870", userJwt: AuthTestFixtures.userJwt())

    XCTAssertNil(result.clientId)
    XCTAssertNil(result.isAccountAbstracted)
  }

  func test_verifyTotp_willThrowMalformedResponse_whenCstMissing() async throws {
    self.requests.enqueue(AuthTestFixtures.totpResponse(clientSessionToken: nil))

    await XCTAssertThrowsAsync(
      try await self.auth.verifyTotp("777870", userJwt: AuthTestFixtures.userJwt()),
      expected: PortalAuthError.malformedResponse(path: "/api/v3/auth/totps/validations", missing: "clientSessionToken")
    )
    XCTAssertEqual(self.storage.setCalls, 0)
    XCTAssertNil(self.storage.stored)
  }

  func test_verifyTotp_willNeverPersistEmptyCst() async throws {
    self.requests.enqueue(AuthTestFixtures.totpResponse(clientSessionToken: ""))

    await XCTAssertThrowsAsync(
      try await self.auth.verifyTotp("777870", userJwt: AuthTestFixtures.userJwt()),
      expected: PortalAuthError.malformedResponse(path: "/api/v3/auth/totps/validations", missing: "clientSessionToken")
    )
    XCTAssertEqual(self.storage.setCalls, 0)
  }

  func test_verifyTotp_willNeverPersistWhitespaceOnlyCst() async throws {
    self.requests.enqueue(AuthTestFixtures.totpResponse(clientSessionToken: " \t "))

    await XCTAssertThrowsAsync(
      try await self.auth.verifyTotp("777870", userJwt: AuthTestFixtures.userJwt()),
      expected: PortalAuthError.malformedResponse(path: "/api/v3/auth/totps/validations", missing: "clientSessionToken")
    )
    XCTAssertEqual(self.storage.setCalls, 0)
    XCTAssertNil(self.storage.stored)
  }

  func test_verifyTotp_willThrowMalformedResponse_whenEnvelopeMalformed() async throws {
    self.requests.enqueue(AuthTestFixtures.json(["error": "nope"]))

    await XCTAssertThrowsAsync(
      try await self.auth.verifyTotp("777870", userJwt: AuthTestFixtures.userJwt()),
      expected: PortalAuthError.malformedResponse(path: "/api/v3/auth/totps/validations", missing: nil)
    )
  }

  func test_verifyTotp_willPassThroughRejectedCode_persistingNothing() async throws {
    let userJwt = AuthTestFixtures.userJwt()

    self.requests.failWith = AuthTestFixtures.unauthorized
    await XCTAssertThrowsAsync(try await self.auth.verifyTotp("000000", userJwt: userJwt), expected: PortalRequestsError.unauthorized)

    let rejected = AuthTestFixtures.clientError(status: 400, body: "{\"error\":\"invalid code\"}")
    self.requests.failWith = rejected
    await XCTAssertThrowsAsync(try await self.auth.verifyTotp("000000", userJwt: userJwt)) { error in
      XCTAssertEqual(error as? PortalRequestsError, rejected)
      let message = (error as? PortalRequestsError)?.dataStr ?? ""
      XCTAssertTrue(message.contains("invalid code"), message)
    }

    XCTAssertEqual(self.storage.setCalls, 0)
    XCTAssertNil(self.storage.stored)
  }

  func test_verifyTotp_willAllowRetryWithSameJwt_afterRejectedCode() async throws {
    let userJwt = AuthTestFixtures.userJwt()
    self.requests.queuedResponses = [.failure(AuthTestFixtures.unauthorized), .success(AuthTestFixtures.totpResponse())]

    await XCTAssertThrowsAsync(try await self.auth.verifyTotp("000000", userJwt: userJwt), expected: PortalRequestsError.unauthorized)
    let result = try await self.auth.verifyTotp("123456", userJwt: userJwt)

    XCTAssertEqual(try result.session.getToken(), "totp-session-token")
    XCTAssertEqual(self.requests.callCount, 2)
    XCTAssertEqual(self.storage.setCalls, 1)
  }

  func test_verifyTotp_willThrowSessionStorageFailure_whenPersistFails() async throws {
    self.storage.onSet = { _ in throw PortalAuthError.sessionStorageFailure(message: "keystore write failed") }
    self.requests.enqueue(AuthTestFixtures.totpResponse())

    await XCTAssertThrowsAsync(
      try await self.auth.verifyTotp("777870", userJwt: AuthTestFixtures.userJwt()),
      expected: PortalAuthError.sessionStorageFailure(message: "keystore write failed")
    )
    XCTAssertNil(self.storage.stored)
  }

  func test_verifyTotp_willPostCodeVerbatim_whenBlank() async throws {
    let userJwt = AuthTestFixtures.userJwt()
    self.requests.enqueue(AuthTestFixtures.totpResponse())
    self.requests.enqueue(AuthTestFixtures.totpResponse())

    _ = try await self.auth.verifyTotp("", userJwt: userJwt)
    XCTAssertEqual(try self.lastPayload()["code"] as? String, "")

    _ = try await self.auth.verifyTotp(" 777870 ", userJwt: userJwt)
    XCTAssertEqual(try self.lastPayload()["code"] as? String, " 777870 ")
  }

  func test_verifyTotp_willNotLogJwtCodeOrCst() async throws {
    let userJwt = AuthTestFixtures.userJwt()
    self.requests.enqueue(AuthTestFixtures.totpResponse())

    _ = try await self.auth.verifyTotp("777870", userJwt: userJwt)

    self.assertNoSecrets([userJwt, "777870", "totp-session-token"])
  }

  // MARK: - restoreSession

  func test_restoreSession_willReturnNil_whenStorageEmpty() async throws {
    self.storage.stored = nil

    let session = try await self.auth.restoreSession()

    XCTAssertNil(session)
    XCTAssertEqual(self.requests.callCount, 0)
    XCTAssertEqual(self.storage.getCalls, 1)
  }

  func test_restoreSession_willReturnWorkingSession() async throws {
    self.storage.stored = AuthTestFixtures.persistedSession(token: "stored-token", endUserId: "user-7")

    let restored = try await self.auth.restoreSession()
    let session = try XCTUnwrap(restored)

    XCTAssertEqual(try session.getToken(), "stored-token")
    XCTAssertEqual(session.endUserId, "user-7")
  }

  func test_restoreSession_willRestoreSessionJustPersisted() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse())
    _ = try await self.auth.handleRedirect(AuthTestFixtures.magicLinkRedirect())

    let restored = try await self.auth.restoreSession()
    let session = try XCTUnwrap(restored)

    XCTAssertEqual(try session.getToken(), "session-token")
    XCTAssertEqual(session.endUserId, "user-1")
  }

  func test_restoreSession_willMakeNoNetworkCall() async throws {
    self.storage.stored = AuthTestFixtures.persistedSession()

    _ = try await self.auth.restoreSession()

    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_restoreSession_willThrowSessionStorageFailure_whenReadTransientlyFails() async throws {
    let stored = AuthTestFixtures.persistedSession()
    self.storage.stored = stored
    self.storage.onGet = { throw PortalAuthError.sessionStorageFailure(message: "keystore unreadable") }

    await XCTAssertThrowsAsync(
      try await self.auth.restoreSession(),
      expected: PortalAuthError.sessionStorageFailure(message: "keystore unreadable")
    )
    XCTAssertEqual(self.storage.stored, stored)
    XCTAssertEqual(self.storage.deleteCalls, 0)
  }

  func test_restoreSession_willReturnNil_andClear_whenCorrupt() async throws {
    self.storage.stored = "{not json"

    let session = try await self.auth.restoreSession()

    XCTAssertNil(session)
    XCTAssertNil(self.storage.stored)
    XCTAssertEqual(self.storage.deleteCalls, 1)
  }

  func test_restoreSession_willReturnNil_andClear_whenIncomplete() async throws {
    self.storage.stored = "{\"clientSessionToken\":\"stored-token\"}"

    let session = try await self.auth.restoreSession()

    XCTAssertNil(session)
    XCTAssertNil(self.storage.stored)
    XCTAssertEqual(self.storage.deleteCalls, 1)
  }

  func test_restoreSession_willReturnNil_andClear_whenTokenEmpty() async throws {
    self.storage.stored = "{\"clientSessionToken\":\"\",\"endUserId\":\"u\"}"

    let session = try await self.auth.restoreSession()

    XCTAssertNil(session)
    XCTAssertNil(self.storage.stored)
    XCTAssertEqual(self.storage.deleteCalls, 1)
  }

  func test_restoreSession_willThrow_whenCorruptButUnclearable() async throws {
    let storage = MockAuthSessionStorage(
      stored: "{not json",
      onDelete: { throw PortalAuthError.sessionStorageFailure(message: "delete failed") }
    )
    let subject = self.makeSubject(requests: self.requests, storage: storage)

    await XCTAssertThrowsAsync(
      try await subject.restoreSession(),
      expected: PortalAuthError.sessionStorageFailure(message: "delete failed")
    )
  }

  func test_restoreSession_willNotLogToken() async throws {
    self.storage.stored = AuthTestFixtures.persistedSession(token: "STORED-SECRET")

    _ = try await self.auth.restoreSession()

    self.assertNoSecrets(["STORED-SECRET"])
  }

  // MARK: - clearPersistedSession

  func test_clearPersistedSession_willDeleteStored() async throws {
    self.storage.stored = AuthTestFixtures.persistedSession()

    try await self.auth.clearPersistedSession()

    XCTAssertEqual(self.storage.deleteCalls, 1)
    XCTAssertNil(self.storage.stored)
    let session = try await self.auth.restoreSession()
    XCTAssertNil(session)
    XCTAssertEqual(self.requests.callCount, 0)
  }

  func test_clearPersistedSession_willPropagateDeleteFailure() async throws {
    self.storage.stored = AuthTestFixtures.persistedSession()
    self.storage.onDelete = { throw PortalAuthError.sessionStorageFailure(message: "delete failed") }

    await XCTAssertThrowsAsync(
      try await self.auth.clearPersistedSession(),
      expected: PortalAuthError.sessionStorageFailure(message: "delete failed")
    )
  }

  func test_clearPersistedSession_willSucceed_whenNothingStored() async throws {
    self.storage.stored = nil

    try await self.auth.clearPersistedSession()

    XCTAssertEqual(self.storage.deleteCalls, 1)
  }
}
