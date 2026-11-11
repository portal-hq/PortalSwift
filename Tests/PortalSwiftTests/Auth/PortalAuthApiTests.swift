//
//  PortalAuthApiTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

/// Covers `PortalAuthApi`, the thin transport for the six Client Auth endpoints.
///
/// Everything asserted here is wire contract: the exact URL each endpoint targets, the headers
/// that ride on every call (`x-portal-auth-environment-id`, `Accept`, `Content-Type`, a fresh
/// trace id), which call may carry a bearer (only `POST /totps/validations`, and only the
/// short-lived `userJwt`), the JSON body shape, and how a non-conforming response or an
/// actionable status code is translated. The backend matches `redirectUrl` byte-for-byte
/// against the environment's allow list, so the percent-encoding vectors are pinned
/// individually rather than trusted to `URLQueryItem`.
///
/// The 401 hook is deliberately never installed on this transport — a `401` from a grant
/// exchange means the *grant* was rejected and there is no credential to invalidate — so every
/// case runs against a `RecordingPortalRequests` that counts hook installations and
/// invocations, and the security case asserts both stay at zero.
final class PortalAuthApiTests: XCTestCase {
  // MARK: - Fixtures

  /// The auth environment header value every request must carry.
  private static let authEnvironmentId = "env-1234"
  /// The production host, so the resolved base is `https://api.portalhq.io`.
  private static let apiHost = "api.portalhq.io"
  /// The scheme-qualified base every exact-URL assertion is written against.
  private static let apiBase = "https://api.portalhq.io/api/v3/auth"
  /// The redirect the Appendix A cases use; its encoding is `myapp%3A%2F%2Fauth%2Fcallback`.
  private static let redirectUrl = "myapp://auth/callback"
  /// The encoded form of `redirectUrl`, spelled out so a regression in `formUrlEncode` shows up
  /// as a URL mismatch rather than as a passing test that encodes both sides the same wrong way.
  private static let encodedRedirectUrl = "myapp%3A%2F%2Fauth%2Fcallback"
  /// A grant token; single-use in production, a literal here.
  private static let grantToken = "grant-token"
  /// The bearer `validateTotp` sends. Short-lived in production; a literal here.
  private static let userJwt = "user-jwt"
  /// A six-digit TOTP code, posted verbatim by the module.
  private static let totpCode = "777870"

  private var requests = RecordingPortalRequests()
  private var api = PortalAuthApi(
    authEnvironmentId: PortalAuthApiTests.authEnvironmentId,
    apiHost: PortalAuthApiTests.apiHost,
    requests: RecordingPortalRequests()
  )
  private let logger = RecordingLogger()

  override func setUpWithError() throws {
    try super.setUpWithError()
    CredentialInvalidationRegistry.shared.resetForTesting()
    self.logger.install()
    self.requests = RecordingPortalRequests()
    self.api = PortalAuthApi(
      authEnvironmentId: Self.authEnvironmentId,
      apiHost: Self.apiHost,
      requests: self.requests
    )
  }

  override func tearDownWithError() throws {
    self.logger.uninstall()
    CredentialInvalidationRegistry.shared.resetForTesting()
    try super.tearDownWithError()
  }

  // MARK: - Helpers

  /// Answers each of the six endpoints with the minimal body it must be able to parse, keyed by
  /// the exact path so one `callAll()` can drive all six without depending on call order.
  private func installEndpointResponder() {
    self.requests.responder = { request in
      switch request.path {
      case PortalAuthApi.methodsPath:
        return AuthTestFixtures.methodsResponse(["EMAIL_MAGIC_LINK"], autoCreateWallet: true)
      case PortalAuthApi.magicLinksPath:
        return AuthTestFixtures.sentResponse
      case PortalAuthApi.magicLinkValidationsPath:
        return AuthTestFixtures.grantResponse()
      case PortalAuthApi.oauthUrlsPath:
        return AuthTestFixtures.oauthUrlsResponse(google: AuthTestFixtures.googleAuthorizeUrl)
      case PortalAuthApi.oauthTokensPath:
        return AuthTestFixtures.grantResponse()
      case PortalAuthApi.totpValidationsPath:
        return AuthTestFixtures.totpResponse()
      default:
        return Data()
      }
    }
  }

  /// Invokes all six endpoints once, in path order, against minimal valid bodies and returns the
  /// recorded requests. The shared arrangement for every "on every call" assertion.
  @discardableResult
  private func callAll(redirectUrl: String = PortalAuthApiTests.redirectUrl) async throws -> [RecordedRequest] {
    self.installEndpointResponder()

    _ = try await self.api.getMethods()
    try await self.api.sendMagicLink(
      email: "user@example.com",
      redirectUrl: redirectUrl,
      magicLink: AuthTestFixtures.magicLink,
      isAccountAbstracted: nil
    )
    _ = try await self.api.validateMagicLink(token: Self.grantToken)
    _ = try await self.api.getOAuthUrls(redirectUrl: redirectUrl, isAccountAbstracted: nil)
    _ = try await self.api.validateOAuthToken(token: Self.grantToken)
    _ = try await self.api.validateTotp(code: Self.totpCode, userJwt: Self.userJwt)

    return self.requests.recorded
  }

  /// `sendMagicLink` with the fixture magic-link config, so a case only states what it varies.
  private func sendMagicLink(
    email: String = "user@example.com",
    redirectUrl: String = PortalAuthApiTests.redirectUrl,
    isAccountAbstracted: Bool? = nil
  ) async throws {
    try await self.api.sendMagicLink(
      email: email,
      redirectUrl: redirectUrl,
      magicLink: AuthTestFixtures.magicLink,
      isAccountAbstracted: isAccountAbstracted
    )
  }

  /// The `errorDescription` of a thrown `PortalAuthError`, or `nil` (with a failure) when the
  /// error is of another type. Keeps the message assertions free of casts and force unwraps.
  private func authErrorDescription(
    _ error: Error?,
    file: StaticString = #filePath,
    line: UInt = #line
  ) -> String? {
    guard let authError = error as? PortalAuthError else {
      XCTFail("Expected a PortalAuthError but got \(error.map { String(describing: type(of: $0)) } ?? "no error").", file: file, line: line)
      return nil
    }
    return authError.errorDescription
  }

  // MARK: - Headers, methods and URLs (all endpoints)

  func test_allEndpoints_willSendAuthEnvironmentIdHeader() async throws {
    let recorded = try await self.callAll()

    XCTAssertEqual(PortalAuthApi.authEnvironmentIdHeader, "x-portal-auth-environment-id")
    XCTAssertEqual(recorded.count, 6)
    for request in recorded {
      XCTAssertEqual(
        request.headers[PortalAuthApi.authEnvironmentIdHeader],
        Self.authEnvironmentId,
        "\(request.path) did not carry the auth environment header."
      )
    }
  }

  func test_allEndpoints_willSendAcceptAndContentTypeJson() async throws {
    let recorded = try await self.callAll()

    XCTAssertEqual(recorded.count, 6)
    for request in recorded {
      XCTAssertEqual(request.headers["Accept"], "application/json", "\(request.path) Accept")
      XCTAssertEqual(request.headers["Content-Type"], "application/json", "\(request.path) Content-Type")
    }
  }

  func test_allEndpoints_willSendNonBlankTraceId() async throws {
    let recorded = try await self.callAll()

    XCTAssertEqual(recorded.count, 6)
    for request in recorded {
      let traceId = try XCTUnwrap(request.traceId, "\(request.path) carried no trace id.")
      XCTAssertFalse(traceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(request.path) trace id was blank.")
      XCTAssertEqual(traceId, traceId.lowercased(), "\(request.path) trace id was not lowercase.")
      XCTAssertNotNil(UUID(uuidString: traceId), "\(request.path) trace id was not a UUID.")
    }
  }

  func test_getMethods_willSendFreshTraceIdPerCall() async throws {
    let body = AuthTestFixtures.methodsResponse([AuthMethod.emailMagicLink])
    self.requests.enqueue(body)
    self.requests.enqueue(body)

    _ = try await self.api.getMethods()
    _ = try await self.api.getMethods()

    let recorded = self.requests.recorded
    XCTAssertEqual(recorded.count, 2)
    let first = try XCTUnwrap(recorded.first?.traceId)
    let second = try XCTUnwrap(recorded.last?.traceId)
    XCTAssertNotEqual(first, second, "Two calls reused one trace id; correlation would collapse.")
  }

  func test_nonTotpEndpoints_willSendNoAuthorizationHeader() async throws {
    let recorded = try await self.callAll()

    let nonTotp = recorded.filter { $0.path != PortalAuthApi.totpValidationsPath }
    XCTAssertEqual(nonTotp.count, 5)
    for request in nonTotp {
      XCTAssertNil(request.headers["Authorization"], "\(request.path) carried an Authorization header.")
      XCTAssertNil(request.header("Authorization"), "\(request.path) carried an Authorization header.")
      XCTAssertNil(request.bearerToken, "\(request.path) carried a bearer token.")
    }
  }

  func test_allEndpoints_willUseExpectedHttpMethod() async throws {
    let recorded = try await self.callAll()

    let methodsByPath = Dictionary(uniqueKeysWithValues: recorded.map { ($0.path, $0.method) })
    XCTAssertEqual(methodsByPath[PortalAuthApi.methodsPath], HttpMethod.get)
    XCTAssertEqual(methodsByPath[PortalAuthApi.oauthUrlsPath], HttpMethod.get)
    XCTAssertEqual(methodsByPath[PortalAuthApi.magicLinksPath], HttpMethod.post)
    XCTAssertEqual(methodsByPath[PortalAuthApi.magicLinkValidationsPath], HttpMethod.post)
    XCTAssertEqual(methodsByPath[PortalAuthApi.oauthTokensPath], HttpMethod.post)
    XCTAssertEqual(methodsByPath[PortalAuthApi.totpValidationsPath], HttpMethod.post)
  }

  func test_allEndpoints_willTargetExactUrls() async throws {
    // The paths are pinned as literals: they are a wire contract with connect-api, not an
    // implementation detail the tests may re-derive from the constants they are checking.
    XCTAssertEqual(PortalAuthApi.basePath, "/api/v3/auth")
    XCTAssertEqual(PortalAuthApi.methodsPath, "/api/v3/auth/methods")
    XCTAssertEqual(PortalAuthApi.magicLinksPath, "/api/v3/auth/magic-links")
    XCTAssertEqual(PortalAuthApi.magicLinkValidationsPath, "/api/v3/auth/magic-links/validations")
    XCTAssertEqual(PortalAuthApi.oauthUrlsPath, "/api/v3/auth/oauth/urls")
    XCTAssertEqual(PortalAuthApi.oauthTokensPath, "/api/v3/auth/oauth/tokens")
    XCTAssertEqual(PortalAuthApi.totpValidationsPath, "/api/v3/auth/totps/validations")

    let recorded = try await self.callAll(redirectUrl: Self.redirectUrl)

    XCTAssertEqual(recorded.map { $0.absoluteString }, [
      "https://api.portalhq.io/api/v3/auth/methods",
      "https://api.portalhq.io/api/v3/auth/magic-links",
      "https://api.portalhq.io/api/v3/auth/magic-links/validations",
      "https://api.portalhq.io/api/v3/auth/oauth/urls?redirectUrl=myapp%3A%2F%2Fauth%2Fcallback",
      "https://api.portalhq.io/api/v3/auth/oauth/tokens",
      "https://api.portalhq.io/api/v3/auth/totps/validations"
    ])
  }

  func test_api_willNotInstallOnUnauthorizedHook() async {
    XCTAssertNil(self.requests.onUnauthorized, "PortalAuthApi installed a 401 hook at construction.")
    XCTAssertEqual(self.requests.onUnauthorizedSetCount, 0)

    self.requests.failWith = PortalRequestsError.unauthorized
    await XCTAssertThrowsAsync(
      try await self.api.validateTotp(code: Self.totpCode, userJwt: Self.userJwt),
      expected: PortalRequestsError.unauthorized
    )

    XCTAssertNil(self.requests.onUnauthorized, "A 401 caused a hook to be installed.")
    XCTAssertEqual(self.requests.onUnauthorizedSetCount, 0)
    XCTAssertEqual(self.requests.unauthorizedHookInvocations, 0)
  }

  func test_api_willUseRequestObjectTransportOnly() async throws {
    // `RecordingPortalRequests` fails the test from inside any deprecated verb, so reaching six
    // recorded `execute(request:)` calls is the assertion that none of them was used.
    let recorded = try await self.callAll()

    XCTAssertEqual(recorded.count, 6)
    XCTAssertEqual(self.requests.callCount, 6)
    XCTAssertEqual(Set(recorded.map { $0.path }).count, 6)
  }

  // MARK: - getMethods

  func test_getMethods_willUnwrapEnvelope() async throws {
    self.requests.enqueue(AuthTestFixtures.methodsResponse(["EMAIL_MAGIC_LINK", "GOOGLE"], autoCreateWallet: true))

    let result = try await self.api.getMethods()

    XCTAssertEqual(result.allowedAuthMethods, [.emailMagicLink, .google])
    XCTAssertTrue(result.autoCreateWallet)
  }

  func test_getMethods_willDropUnknownMethod() async throws {
    self.requests.enqueue(AuthTestFixtures.methodsResponse(["EMAIL_MAGIC_LINK", "PASSKEY"], autoCreateWallet: false))

    let result = try await self.api.getMethods()

    XCTAssertEqual(result.allowedAuthMethods, [.emailMagicLink])
    XCTAssertFalse(result.autoCreateWallet)
  }

  func test_getMethods_willReadMissingAutoCreateWalletAsFalse() async throws {
    self.requests.enqueue(AuthTestFixtures.methodsResponse(["EMAIL_MAGIC_LINK"]))

    let result = try await self.api.getMethods()

    XCTAssertEqual(result.allowedAuthMethods, [.emailMagicLink])
    XCTAssertFalse(result.autoCreateWallet)
  }

  func test_getMethods_willReadMissingAllowedAuthMethodsAsEmpty() async throws {
    self.requests.enqueue(AuthTestFixtures.envelope(["autoCreateWallet": true]))

    let result = try await self.api.getMethods()

    XCTAssertEqual(result.allowedAuthMethods, [])
    XCTAssertTrue(result.autoCreateWallet)
  }

  func test_getMethods_willThrowMalformed_whenAllowedAuthMethodsNotArray() async {
    // A type mismatch inside `data` is a malformed response, never a crash.
    self.requests.enqueue(AuthTestFixtures.envelope(["allowedAuthMethods": "GOOGLE"]))

    await XCTAssertThrowsAsync(
      try await self.api.getMethods(),
      expected: PortalAuthError.malformedResponse(path: PortalAuthApi.methodsPath, missing: nil)
    )
  }

  func test_getMethods_willThrowMalformedNamingPathAndData_whenNoData() async {
    self.requests.enqueue(Data("{\"meta\":{}}".utf8))

    let thrown = await XCTAssertThrowsAsync(
      try await self.api.getMethods(),
      expected: PortalAuthError.malformedResponse(path: PortalAuthApi.methodsPath, missing: nil)
    )

    XCTAssertEqual(
      self.authErrorDescription(thrown),
      "[PortalAuth] Malformed response from /api/v3/auth/methods: missing \"data\"."
    )
  }

  func test_getMethods_willThrowMalformed_whenDataNull() async {
    self.requests.enqueue(AuthTestFixtures.envelope(NSNull()))

    await XCTAssertThrowsAsync(
      try await self.api.getMethods(),
      expected: PortalAuthError.malformedResponse(path: PortalAuthApi.methodsPath, missing: nil)
    )
  }

  func test_getMethods_willThrowMalformed_whenNotJson() async {
    self.requests.enqueue(Data("<html>gateway error</html>".utf8))

    await XCTAssertThrowsAsync(
      try await self.api.getMethods(),
      expected: PortalAuthError.malformedResponse(path: PortalAuthApi.methodsPath, missing: nil)
    )
  }

  func test_getMethods_willThrowMalformed_whenBodyEmpty() async {
    self.requests.enqueue(Data())

    await XCTAssertThrowsAsync(
      try await self.api.getMethods(),
      expected: PortalAuthError.malformedResponse(path: PortalAuthApi.methodsPath, missing: nil)
    )
  }

  func test_getMethods_willPassThroughUnauthorized() async {
    self.requests.failWith = PortalRequestsError.unauthorized

    await XCTAssertThrowsAsync(try await self.api.getMethods(), expected: PortalRequestsError.unauthorized)
    XCTAssertEqual(self.requests.callCount, 1)
  }

  // MARK: - sendMagicLink

  func test_sendMagicLink_willPostAllFourFields() async throws {
    self.requests.enqueue(AuthTestFixtures.sentResponse)

    try await self.sendMagicLink()

    let request = try XCTUnwrap(self.requests.lastRequest)
    XCTAssertEqual(request.absoluteString, Self.apiBase + "/magic-links")
    let payload = try XCTUnwrap(request.payloadJSON)
    XCTAssertEqual(Set(payload.keys), ["email", "redirectUrl", "fromEmail", "templateId"])
    XCTAssertEqual(payload["email"] as? String, "user@example.com")
    XCTAssertEqual(payload["redirectUrl"] as? String, Self.redirectUrl)
    XCTAssertEqual(payload["fromEmail"] as? String, "login@example.com")
    XCTAssertEqual(payload["templateId"] as? String, "template-1")
  }

  func test_sendMagicLink_willOmitIsAccountAbstracted_whenNil() async throws {
    self.requests.enqueue(AuthTestFixtures.sentResponse)

    try await self.sendMagicLink(isAccountAbstracted: nil)

    let payload = try XCTUnwrap(self.requests.lastRequest?.payloadJSON)
    XCTAssertNil(payload["isAccountAbstracted"])
    XCTAssertEqual(payload.count, 4)
  }

  func test_sendMagicLink_willIncludeIsAccountAbstractedAsBool() async throws {
    self.requests.enqueue(AuthTestFixtures.sentResponse)
    self.requests.enqueue(AuthTestFixtures.sentResponse)

    try await self.sendMagicLink(isAccountAbstracted: true)
    let truthy = try XCTUnwrap(self.requests.lastRequest)
    let truthyPayload = try XCTUnwrap(truthy.payloadJSON)
    XCTAssertEqual(truthyPayload["isAccountAbstracted"] as? Bool, true)
    XCTAssertNil(truthyPayload["isAccountAbstracted"] as? String, "The flag was encoded as a string, not a JSON boolean.")
    XCTAssertEqual(truthy.payloadString?.contains("\"isAccountAbstracted\":true"), true)

    try await self.sendMagicLink(isAccountAbstracted: false)
    let falsy = try XCTUnwrap(self.requests.lastRequest)
    let falsyPayload = try XCTUnwrap(falsy.payloadJSON)
    XCTAssertEqual(falsyPayload["isAccountAbstracted"] as? Bool, false)
    XCTAssertNil(falsyPayload["isAccountAbstracted"] as? String, "The flag was encoded as a string, not a JSON boolean.")
    XCTAssertEqual(falsy.payloadString?.contains("\"isAccountAbstracted\":false"), true)
  }

  func test_sendMagicLink_willIgnoreResponseBody() async throws {
    // Only the status matters; the body is never parsed.
    for body in [Data(), Data("{}".utf8), Data("<html>".utf8)] {
      self.requests.enqueue(body)
      try await self.sendMagicLink()
    }

    XCTAssertEqual(self.requests.callCount, 3)
  }

  func test_sendMagicLink_willMapRateLimited_when429() async {
    self.requests.failWith = AuthTestFixtures.clientError(status: 429, body: "{\"error\":\"Too many requests\"}")

    let thrown = await XCTAssertThrowsAsync(try await self.sendMagicLink(), expected: PortalAuthError.rateLimited)

    XCTAssertEqual(
      self.authErrorDescription(thrown),
      "[PortalAuth] Too many magic links were sent to this address. Wait a minute before trying again."
    )
    XCTAssertEqual(self.requests.callCount, 1, "A 429 must not be retried on the host's behalf.")
  }

  func test_sendMagicLink_willMapAccountAbstractionUnavailable_when400ErrorBody() async {
    let serverText = "Account abstraction is not enabled for this custodian"
    self.requests.failWith = AuthTestFixtures.clientError(status: 400, body: "{\"error\":\"\(serverText)\"}")

    await XCTAssertThrowsAsync(
      try await self.sendMagicLink(isAccountAbstracted: true),
      expected: PortalAuthError.accountAbstractionUnavailable(message: serverText)
    )
  }

  func test_sendMagicLink_willBoundAccountAbstractionMessageTo200() async {
    let serverText = String(repeating: "a", count: 500)
    self.requests.failWith = AuthTestFixtures.clientError(status: 400, body: "{\"error\":\"\(serverText)\"}")

    let thrown = await XCTAssertThrowsAsync(
      try await self.sendMagicLink(isAccountAbstracted: true),
      expected: PortalAuthError.accountAbstractionUnavailable(message: String(repeating: "a", count: 200))
    )

    guard case let .accountAbstractionUnavailable(message)? = thrown as? PortalAuthError else {
      return XCTFail("Expected accountAbstractionUnavailable but got \(String(describing: thrown)).")
    }
    XCTAssertEqual(message.count, 200)
  }

  func test_sendMagicLink_willPassThrough400ErrorBody_whenAccountAbstractionNotRequested() async {
    // The same status and body shape is how ordinary validation failures come back. Only a
    // request that asked for account abstraction may read it as an account-abstraction problem.
    let error = AuthTestFixtures.clientError(status: 400, body: "{\"error\":\"redirectUrl is not allow-listed\"}")

    self.requests.failWith = error
    await XCTAssertThrowsAsync(try await self.sendMagicLink(isAccountAbstracted: nil), expected: error)

    self.requests.failWith = error
    await XCTAssertThrowsAsync(try await self.sendMagicLink(isAccountAbstracted: false), expected: error)
  }

  func test_sendMagicLink_willPassThrough400_whenBodyLacksErrorKey() async {
    let error = AuthTestFixtures.clientError(status: 400, body: "{\"message\":\"x\"}")
    self.requests.failWith = error

    await XCTAssertThrowsAsync(try await self.sendMagicLink(), expected: error)
  }

  func test_sendMagicLink_willPassThrough400_whenBodyNotJson() async {
    let error = AuthTestFixtures.clientError(status: 400, body: "<html>")
    self.requests.failWith = error

    await XCTAssertThrowsAsync(try await self.sendMagicLink(), expected: error)
  }

  func test_sendMagicLink_willPassThroughUnauthorizedAnd5xx() async {
    self.requests.failWith = PortalRequestsError.unauthorized
    await XCTAssertThrowsAsync(try await self.sendMagicLink(), expected: PortalRequestsError.unauthorized)

    let serverError = AuthTestFixtures.serverError503
    self.requests.failWith = serverError
    await XCTAssertThrowsAsync(try await self.sendMagicLink(), expected: serverError)
  }

  // MARK: - validateMagicLink

  func test_validateMagicLink_willPostTokenToValidations() async throws {
    self.requests.enqueue(Data("{\"data\":{\"clientSessionToken\":\"session\",\"endUserId\":\"user-1\",\"totpLink\":null,\"userJwt\":null}}".utf8))

    let grant = try await self.api.validateMagicLink(token: Self.grantToken)

    XCTAssertEqual(grant.clientSessionToken, "session")
    XCTAssertEqual(grant.endUserId, "user-1")
    XCTAssertNil(grant.userJwt)
    XCTAssertNil(grant.totpLink)

    let request = try XCTUnwrap(self.requests.lastRequest)
    XCTAssertEqual(request.absoluteString, Self.apiBase + "/magic-links/validations")
    XCTAssertEqual(request.method, .post)
    let payload = try XCTUnwrap(request.payloadJSON)
    XCTAssertEqual(payload.count, 1)
    XCTAssertEqual(payload["token"] as? String, Self.grantToken)
  }

  func test_validateMagicLink_willSurfaceClientMetadata() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse(clientId: "client-9", isAccountAbstracted: true))

    let grant = try await self.api.validateMagicLink(token: Self.grantToken)

    XCTAssertEqual(grant.clientId, "client-9")
    XCTAssertEqual(grant.isAccountAbstracted, true)
  }

  func test_validateMagicLink_willReadTotpChallenge() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse(
      clientSessionToken: nil,
      endUserId: nil,
      userJwt: "jwt",
      totpLink: "otpauth://totp/Portal"
    ))

    let grant = try await self.api.validateMagicLink(token: Self.grantToken)

    XCTAssertNil(grant.clientSessionToken)
    XCTAssertEqual(grant.userJwt, "jwt")
    XCTAssertEqual(grant.totpLink, "otpauth://totp/Portal")
  }

  func test_validateMagicLink_willThrowMalformedNamingEndUserId_whenCompletedGrantLacksIt() async {
    let expected = PortalAuthError.malformedResponse(path: PortalAuthApi.magicLinkValidationsPath, missing: "endUserId")

    self.requests.enqueue(Data("{\"data\":{\"clientSessionToken\":\"session\",\"endUserId\":null}}".utf8))
    let thrown = await XCTAssertThrowsAsync(try await self.api.validateMagicLink(token: Self.grantToken), expected: expected)

    let description = self.authErrorDescription(thrown)
    XCTAssertEqual(description?.contains("endUserId"), true)
    XCTAssertEqual(description?.contains("missing \"data\""), false)

    // A blank id is rejected as firmly as an absent one — a session keyed on "  " is unusable.
    self.requests.enqueue(AuthTestFixtures.grantResponse(clientSessionToken: "session", endUserId: "  "))
    await XCTAssertThrowsAsync(try await self.api.validateMagicLink(token: Self.grantToken), expected: expected)
  }

  func test_validateMagicLink_willNotGuardEndUserId_whenNoCst() async throws {
    // The guard exists to protect a *completed* grant; a TOTP challenge names no end user yet.
    self.requests.enqueue(AuthTestFixtures.grantResponse(clientSessionToken: nil, endUserId: nil, userJwt: "jwt"))

    let grant = try await self.api.validateMagicLink(token: Self.grantToken)

    XCTAssertNil(grant.endUserId)
    XCTAssertNil(grant.clientSessionToken)
    XCTAssertEqual(grant.userJwt, "jwt")
  }

  func test_validateMagicLink_willNotGuardEndUserId_whenCstBlank() async throws {
    // A whitespace-only token is not a completed grant either: `PortalAuth` treats it as absent,
    // so the `endUserId` guard must not fire on it.
    self.requests.enqueue(AuthTestFixtures.grantResponse(clientSessionToken: "  ", endUserId: nil, userJwt: "jwt"))

    let grant = try await self.api.validateMagicLink(token: Self.grantToken)

    XCTAssertEqual(grant.clientSessionToken, "  ")
    XCTAssertEqual(grant.userJwt, "jwt")
  }

  func test_validateMagicLink_willThrowMalformedNamingPath_whenNoData() async {
    self.requests.enqueue(Data("{\"error\":\"Unauthorized\"}".utf8))

    await XCTAssertThrowsAsync(
      try await self.api.validateMagicLink(token: Self.grantToken),
      expected: PortalAuthError.malformedResponse(path: PortalAuthApi.magicLinkValidationsPath, missing: nil)
    )
  }

  func test_validateMagicLink_willPassThroughUnauthorized_andNotMap400() async {
    self.requests.failWith = PortalRequestsError.unauthorized
    await XCTAssertThrowsAsync(try await self.api.validateMagicLink(token: Self.grantToken), expected: PortalRequestsError.unauthorized)

    // The account-abstraction mapping belongs to /magic-links and /oauth/urls, never to a
    // validations call: a 400 there is a rejected grant, not a misconfigured environment.
    let clientError = AuthTestFixtures.clientError(status: 400, body: "{\"error\":\"x\"}")
    self.requests.failWith = clientError
    await XCTAssertThrowsAsync(try await self.api.validateMagicLink(token: Self.grantToken), expected: clientError)
  }

  // MARK: - getOAuthUrls

  func test_getOAuthUrls_willTargetEndpointWithEncodedRedirectUrl() async throws {
    self.requests.enqueue(AuthTestFixtures.oauthUrlsResponse())

    _ = try await self.api.getOAuthUrls(redirectUrl: Self.redirectUrl, isAccountAbstracted: nil)

    XCTAssertEqual(
      self.requests.lastRequest?.absoluteString,
      "https://api.portalhq.io/api/v3/auth/oauth/urls?redirectUrl=" + Self.encodedRedirectUrl
    )
  }

  func test_getOAuthUrls_willEncodeSpaceAsPercent20() async throws {
    self.requests.enqueue(AuthTestFixtures.oauthUrlsResponse())

    _ = try await self.api.getOAuthUrls(redirectUrl: "https://example.com/a b", isAccountAbstracted: nil)

    let url = try XCTUnwrap(self.requests.lastRequest?.absoluteString)
    XCTAssertTrue(url.hasSuffix("https%3A%2F%2Fexample.com%2Fa%20b"), url)
    XCTAssertFalse(url.contains("+"), "A `+` would be decoded as a space by the backend.")
  }

  func test_getOAuthUrls_willEncodeRedirectOwnQuery() async throws {
    self.requests.enqueue(AuthTestFixtures.oauthUrlsResponse())

    _ = try await self.api.getOAuthUrls(redirectUrl: "https://example.com/cb?x=1&y=2", isAccountAbstracted: nil)

    let url = try XCTUnwrap(self.requests.lastRequest?.absoluteString)
    XCTAssertTrue(url.contains("%3Fx%3D1%26y%3D2"), url)
    XCTAssertEqual(url.filter { $0 == "?" }.count, 1, "The redirect's own query leaked into the request's query.")
  }

  func test_getOAuthUrls_willOmitIsAccountAbstracted_whenNil() async throws {
    self.requests.enqueue(AuthTestFixtures.oauthUrlsResponse())

    _ = try await self.api.getOAuthUrls(redirectUrl: Self.redirectUrl, isAccountAbstracted: nil)

    let url = try XCTUnwrap(self.requests.lastRequest?.absoluteString)
    XCTAssertFalse(url.contains("isAccountAbstracted"), url)
  }

  func test_getOAuthUrls_willSendLiteralTrueOrFalse() async throws {
    self.requests.enqueue(AuthTestFixtures.oauthUrlsResponse())
    self.requests.enqueue(AuthTestFixtures.oauthUrlsResponse())

    _ = try await self.api.getOAuthUrls(redirectUrl: Self.redirectUrl, isAccountAbstracted: true)
    let truthy = try XCTUnwrap(self.requests.lastRequest?.absoluteString)
    XCTAssertTrue(truthy.hasSuffix("&isAccountAbstracted=true"), truthy)

    _ = try await self.api.getOAuthUrls(redirectUrl: Self.redirectUrl, isAccountAbstracted: false)
    let falsy = try XCTUnwrap(self.requests.lastRequest?.absoluteString)
    XCTAssertTrue(falsy.hasSuffix("&isAccountAbstracted=false"), falsy)
  }

  func test_getOAuthUrls_willSendEnvHeaderTraceIdAndNoBearer() async throws {
    self.requests.enqueue(AuthTestFixtures.envelope([String: Any]()))

    _ = try await self.api.getOAuthUrls(redirectUrl: Self.redirectUrl, isAccountAbstracted: nil)

    let request = try XCTUnwrap(self.requests.lastRequest)
    XCTAssertEqual(request.headers[PortalAuthApi.authEnvironmentIdHeader], Self.authEnvironmentId)
    let traceId = try XCTUnwrap(request.traceId)
    XCTAssertNotNil(UUID(uuidString: traceId))
    XCTAssertNil(request.bearerToken)
  }

  func test_getOAuthUrls_willReadOnlyEnabledProviders() async throws {
    self.requests.enqueue(AuthTestFixtures.oauthUrlsResponse(google: "https://accounts.google.com/o/oauth2/v2/auth"))

    let urls = try await self.api.getOAuthUrls(redirectUrl: Self.redirectUrl, isAccountAbstracted: nil)

    XCTAssertEqual(urls.google, "https://accounts.google.com/o/oauth2/v2/auth")
    XCTAssertNil(urls.apple)
  }

  func test_getOAuthUrls_willReadEmptyObject() async throws {
    self.requests.enqueue(AuthTestFixtures.envelope([String: Any]()))

    let urls = try await self.api.getOAuthUrls(redirectUrl: Self.redirectUrl, isAccountAbstracted: nil)

    XCTAssertNil(urls.google)
    XCTAssertNil(urls.apple)
  }

  func test_getOAuthUrls_willTreatNullProviderAsAbsent() async throws {
    self.requests.enqueue(Data("{\"data\":{\"google\":null,\"apple\":\"https://appleid.apple.com/auth/authorize\"}}".utf8))

    let urls = try await self.api.getOAuthUrls(redirectUrl: Self.redirectUrl, isAccountAbstracted: nil)

    XCTAssertNil(urls.google)
    XCTAssertEqual(urls.apple, "https://appleid.apple.com/auth/authorize")
  }

  func test_getOAuthUrls_willThrowMalformedNamingBarePath_whenNoData() async {
    self.requests.enqueue(Data("{\"error\":\"Unauthorized\"}".utf8))

    let thrown = await XCTAssertThrowsAsync(
      try await self.api.getOAuthUrls(redirectUrl: Self.redirectUrl, isAccountAbstracted: nil),
      expected: PortalAuthError.malformedResponse(path: PortalAuthApi.oauthUrlsPath, missing: nil)
    )

    // The error names an endpoint; the redirect URL adds nothing a reader needs and is the kind
    // of value that must not travel in an error message.
    XCTAssertEqual(self.authErrorDescription(thrown)?.contains("redirectUrl"), false)
  }

  func test_getOAuthUrls_willMapAccountAbstractionUnavailable_when400ErrorBody() async {
    self.requests.failWith = AuthTestFixtures.clientError(status: 400, body: "{\"error\":\"AA not configured\"}")

    await XCTAssertThrowsAsync(
      try await self.api.getOAuthUrls(redirectUrl: Self.redirectUrl, isAccountAbstracted: true),
      expected: PortalAuthError.accountAbstractionUnavailable(message: "AA not configured")
    )
  }

  func test_getOAuthUrls_willPassThrough400ErrorBody_whenAccountAbstractionNotRequested() async {
    let error = AuthTestFixtures.clientError(status: 400, body: "{\"error\":\"redirectUrl is not allow-listed\"}")

    self.requests.failWith = error
    await XCTAssertThrowsAsync(
      try await self.api.getOAuthUrls(redirectUrl: Self.redirectUrl, isAccountAbstracted: nil),
      expected: error
    )

    self.requests.failWith = error
    await XCTAssertThrowsAsync(
      try await self.api.getOAuthUrls(redirectUrl: Self.redirectUrl, isAccountAbstracted: false),
      expected: error
    )
  }

  func test_getOAuthUrls_willPassThroughUnauthorized() async {
    self.requests.failWith = PortalRequestsError.unauthorized

    await XCTAssertThrowsAsync(
      try await self.api.getOAuthUrls(redirectUrl: Self.redirectUrl, isAccountAbstracted: nil),
      expected: PortalRequestsError.unauthorized
    )
  }

  // MARK: - validateOAuthToken

  func test_validateOAuthToken_willPostTokenToOauthTokens() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse(
      clientSessionToken: "session",
      endUserId: "user-1",
      clientId: "client-9",
      isAccountAbstracted: false
    ))

    let grant = try await self.api.validateOAuthToken(token: Self.grantToken)

    XCTAssertEqual(grant.clientSessionToken, "session")
    XCTAssertEqual(grant.endUserId, "user-1")
    XCTAssertEqual(grant.clientId, "client-9")
    XCTAssertEqual(grant.isAccountAbstracted, false)

    let request = try XCTUnwrap(self.requests.lastRequest)
    XCTAssertEqual(request.absoluteString, Self.apiBase + "/oauth/tokens")
    XCTAssertEqual(request.method, .post)
    XCTAssertEqual(try XCTUnwrap(request.payloadJSON)["token"] as? String, Self.grantToken)
    XCTAssertEqual(request.headers[PortalAuthApi.authEnvironmentIdHeader], Self.authEnvironmentId)
    XCTAssertNil(request.bearerToken)
  }

  func test_validateOAuthToken_willReadTotpChallenge() async throws {
    self.requests.enqueue(AuthTestFixtures.grantResponse(
      clientSessionToken: nil,
      endUserId: nil,
      userJwt: "jwt",
      totpLink: "otpauth://totp/Portal"
    ))

    let grant = try await self.api.validateOAuthToken(token: Self.grantToken)

    XCTAssertNil(grant.clientSessionToken)
    XCTAssertEqual(grant.userJwt, "jwt")
    XCTAssertEqual(grant.totpLink, "otpauth://totp/Portal")
  }

  func test_validateOAuthToken_willThrowMalformedNamingEndUserId() async {
    self.requests.enqueue(Data("{\"data\":{\"clientSessionToken\":\"session\",\"endUserId\":null}}".utf8))

    await XCTAssertThrowsAsync(
      try await self.api.validateOAuthToken(token: Self.grantToken),
      expected: PortalAuthError.malformedResponse(path: PortalAuthApi.oauthTokensPath, missing: "endUserId")
    )
  }

  func test_validateOAuthToken_willThrowMalformedNamingPath_whenNoData() async {
    self.requests.enqueue(Data("{\"error\":\"Bad Request\"}".utf8))

    await XCTAssertThrowsAsync(
      try await self.api.validateOAuthToken(token: Self.grantToken),
      expected: PortalAuthError.malformedResponse(path: PortalAuthApi.oauthTokensPath, missing: nil)
    )
  }

  // MARK: - validateTotp

  func test_validateTotp_willPostCodeWithBearerJwt() async throws {
    self.requests.enqueue(AuthTestFixtures.totpResponse(clientSessionToken: "session"))

    let validation = try await self.api.validateTotp(code: Self.totpCode, userJwt: Self.userJwt)

    XCTAssertEqual(validation.clientSessionToken, "session")

    let request = try XCTUnwrap(self.requests.lastRequest)
    XCTAssertEqual(request.absoluteString, Self.apiBase + "/totps/validations")
    XCTAssertEqual(request.method, .post)
    let payload = try XCTUnwrap(request.payloadJSON)
    XCTAssertEqual(payload.count, 1)
    XCTAssertEqual(payload["code"] as? String, Self.totpCode)
    XCTAssertEqual(request.headers["Authorization"], "Bearer " + Self.userJwt)
    XCTAssertEqual(request.bearerToken, Self.userJwt)
  }

  func test_validateTotp_willSendEnvHeaderAlongsideBearer() async throws {
    self.requests.enqueue(AuthTestFixtures.totpResponse(clientSessionToken: "session"))

    _ = try await self.api.validateTotp(code: Self.totpCode, userJwt: Self.userJwt)

    let request = try XCTUnwrap(self.requests.lastRequest)
    XCTAssertEqual(request.headers[PortalAuthApi.authEnvironmentIdHeader], Self.authEnvironmentId)
    XCTAssertEqual(request.headers["Authorization"], "Bearer " + Self.userJwt)
  }

  func test_validateTotp_willSurfaceClientMetadata() async throws {
    self.requests.enqueue(AuthTestFixtures.totpResponse(
      clientSessionToken: "session",
      clientId: "client-9",
      isAccountAbstracted: true
    ))

    let validation = try await self.api.validateTotp(code: Self.totpCode, userJwt: Self.userJwt)

    XCTAssertEqual(validation.clientId, "client-9")
    XCTAssertEqual(validation.isAccountAbstracted, true)
  }

  func test_validateTotp_willReturnNilMetadata_whenOmitted() async throws {
    self.requests.enqueue(AuthTestFixtures.totpResponse(clientSessionToken: "session"))

    let validation = try await self.api.validateTotp(code: Self.totpCode, userJwt: Self.userJwt)

    XCTAssertNil(validation.clientId)
    XCTAssertNil(validation.isAccountAbstracted)
  }

  func test_validateTotp_willThrowMalformedNamingClientSessionToken_whenMissing() async {
    self.requests.enqueue(AuthTestFixtures.envelope(["clientId": "client-9"]))

    let thrown = await XCTAssertThrowsAsync(
      try await self.api.validateTotp(code: Self.totpCode, userJwt: Self.userJwt),
      expected: PortalAuthError.malformedResponse(path: PortalAuthApi.totpValidationsPath, missing: "clientSessionToken")
    )

    let description = self.authErrorDescription(thrown)
    XCTAssertEqual(description?.contains("clientSessionToken"), true)
    XCTAssertEqual(description?.contains("missing \"data\""), false)
  }

  func test_validateTotp_willRejectEmptyCst() async {
    self.requests.enqueue(AuthTestFixtures.envelope(["clientSessionToken": ""]))

    await XCTAssertThrowsAsync(
      try await self.api.validateTotp(code: Self.totpCode, userJwt: Self.userJwt),
      expected: PortalAuthError.malformedResponse(path: PortalAuthApi.totpValidationsPath, missing: "clientSessionToken")
    )
  }

  func test_validateTotp_willRejectWhitespaceOnlyCst() async {
    // The same non-blank rule `PersistedSessionCodec` and `resolveCredentialToken` apply: a
    // whitespace-only token would be persisted only to fail on first use.
    self.requests.enqueue(AuthTestFixtures.envelope(["clientSessionToken": " \n "]))

    await XCTAssertThrowsAsync(
      try await self.api.validateTotp(code: Self.totpCode, userJwt: Self.userJwt),
      expected: PortalAuthError.malformedResponse(path: PortalAuthApi.totpValidationsPath, missing: "clientSessionToken")
    )
  }

  func test_validateTotp_willThrowMalformedNamingPathAndData_whenNoData() async {
    self.requests.enqueue(Data("{\"error\":\"nope\"}".utf8))

    let thrown = await XCTAssertThrowsAsync(
      try await self.api.validateTotp(code: Self.totpCode, userJwt: Self.userJwt),
      expected: PortalAuthError.malformedResponse(path: PortalAuthApi.totpValidationsPath, missing: nil)
    )

    XCTAssertEqual(
      self.authErrorDescription(thrown),
      "[PortalAuth] Malformed response from /api/v3/auth/totps/validations: missing \"data\"."
    )
  }

  func test_validateTotp_willPassThroughUnauthorized_whenCodeRejected() async {
    self.requests.failWith = PortalRequestsError.unauthorized

    await XCTAssertThrowsAsync(
      try await self.api.validateTotp(code: Self.totpCode, userJwt: Self.userJwt),
      expected: PortalRequestsError.unauthorized
    )
    XCTAssertEqual(self.requests.unauthorizedHookInvocations, 0, "A wrong code must not invalidate a credential.")
  }

  // MARK: - Decoding across endpoints

  func test_allJsonEndpoints_willThrowMalformed_whenBodyNotJson() async {
    let notJson = Data("<html>gateway error</html>".utf8)
    let endpoints: [(path: String, call: () async throws -> Void)] = [
      (PortalAuthApi.methodsPath, { _ = try await self.api.getMethods() }),
      (PortalAuthApi.magicLinkValidationsPath, { _ = try await self.api.validateMagicLink(token: Self.grantToken) }),
      (PortalAuthApi.oauthUrlsPath, { _ = try await self.api.getOAuthUrls(redirectUrl: Self.redirectUrl, isAccountAbstracted: nil) }),
      (PortalAuthApi.oauthTokensPath, { _ = try await self.api.validateOAuthToken(token: Self.grantToken) }),
      (PortalAuthApi.totpValidationsPath, { _ = try await self.api.validateTotp(code: Self.totpCode, userJwt: Self.userJwt) })
    ]

    for endpoint in endpoints {
      self.requests.enqueue(notJson)
      await XCTAssertThrowsAsync(
        try await endpoint.call(),
        expected: PortalAuthError.malformedResponse(path: endpoint.path, missing: nil),
        "\(endpoint.path) did not report a malformed response naming its own path."
      )
    }

    XCTAssertEqual(self.requests.callCount, endpoints.count)
  }

  // MARK: - resolveApiUrl

  func test_resolveApiUrl_willDefaultToHttpsProduction() {
    let api = PortalAuthApi(authEnvironmentId: Self.authEnvironmentId, requests: self.requests)

    XCTAssertEqual(PortalAuthApi.defaultApiHost, "api.portalhq.io")
    XCTAssertEqual(api.apiUrl, "https://api.portalhq.io")
  }

  func test_resolveApiUrl_willUseHttp_forLocalhostAndLoopback() {
    XCTAssertEqual(PortalAuthApi.resolveApiUrl("localhost:3000"), "http://localhost:3000")
    XCTAssertEqual(PortalAuthApi.resolveApiUrl("127.0.0.1:3000"), "http://127.0.0.1:3000")
    XCTAssertEqual(PortalAuthApi.resolveApiUrl("localhost"), "http://localhost")
  }

  func test_resolveApiUrl_willUseHttps_forAndroidEmulatorAlias() {
    // Deliberate divergence from Android, which special-cases its emulator's host alias. iOS
    // simulators reach the developer machine as `localhost`, so `10.0.2.2` is just another host
    // and must not be downgraded to cleartext.
    XCTAssertEqual(PortalAuthApi.resolveApiUrl("10.0.2.2:3000"), "https://10.0.2.2:3000")
  }

  func test_resolveApiUrl_willHonourExplicitScheme() {
    XCTAssertEqual(PortalAuthApi.resolveApiUrl("http://staging.example.com"), "http://staging.example.com")
    XCTAssertEqual(PortalAuthApi.resolveApiUrl("https://staging.example.com"), "https://staging.example.com")
  }

  func test_resolveApiUrl_willUseHttps_forOtherHosts() {
    XCTAssertEqual(PortalAuthApi.resolveApiUrl("api.portalhq.dev"), "https://api.portalhq.dev")
  }

  func test_resolveApiUrl_willNotUseHttp_forLocalhostLookalike() {
    // The host component is compared as a whole, never with `hasPrefix`, so an attacker-controlled
    // domain that merely starts with a loopback name cannot force a cleartext base URL.
    XCTAssertTrue(PortalAuthApi.resolveApiUrl("localhost.attacker.com").hasPrefix("https://"))
    XCTAssertTrue(PortalAuthApi.resolveApiUrl("127.0.0.1.attacker.com").hasPrefix("https://"))
  }

  // MARK: - urlFor

  func test_urlFor_willThrow_whenApiHostUnusable() async {
    // PLAN Appendix A leaves the choice to the implementer; the module raises
    // `invalidArgument(name: "apiHost")`, and the case that matters is that nothing crashes and
    // no request is made.
    for host in ["", "bad host with spaces"] {
      let requests = RecordingPortalRequests()
      let api = PortalAuthApi(authEnvironmentId: Self.authEnvironmentId, apiHost: host, requests: requests)

      await XCTAssertThrowsAsync(
        try await api.getMethods(),
        expected: PortalAuthError.invalidArgument(name: "apiHost"),
        "apiHost `\(host)` should have been rejected before any request."
      )
      XCTAssertEqual(requests.callCount, 0, "A request was sent for an unusable apiHost `\(host)`.")
    }
  }

  func test_urlFor_willNotDoubleSlash_whenApiHostHasTrailingSlash() async throws {
    let requests = RecordingPortalRequests()
    let api = PortalAuthApi(authEnvironmentId: Self.authEnvironmentId, apiHost: "api.portalhq.io/", requests: requests)
    requests.enqueue(AuthTestFixtures.methodsResponse([AuthMethod.emailMagicLink]))

    _ = try await api.getMethods()

    XCTAssertEqual(api.apiUrl, "https://api.portalhq.io")
    XCTAssertEqual(requests.lastRequest?.absoluteString, "https://api.portalhq.io/api/v3/auth/methods")
  }

  // MARK: - formUrlEncode

  func test_formUrlEncode_willLeaveUnreservedUntouched() {
    XCTAssertEqual(PortalAuthApi.formUrlEncode("AZaz09-_.*"), "AZaz09-_.*")
  }

  func test_formUrlEncode_willEncodeColonAndSlash() {
    XCTAssertEqual(PortalAuthApi.formUrlEncode("myapp://auth/callback"), "myapp%3A%2F%2Fauth%2Fcallback")
  }

  func test_formUrlEncode_willEncodeSpaceAsPercent20_andPlusAsPercent2B() {
    XCTAssertEqual(PortalAuthApi.formUrlEncode("a b+c"), "a%20b%2Bc")
  }

  func test_formUrlEncode_willEncodeTilde() {
    XCTAssertEqual(PortalAuthApi.formUrlEncode("~"), "%7E")
  }

  func test_formUrlEncode_willEncodeUnicodeAsUppercaseUtf8Percent() {
    XCTAssertEqual(PortalAuthApi.formUrlEncode("é"), "%C3%A9")
    XCTAssertEqual(PortalAuthApi.formUrlEncode("😀"), "%F0%9F%98%80")
  }

  func test_formUrlEncode_willEncodeReservedQueryChars() {
    XCTAssertEqual(PortalAuthApi.formUrlEncode("?&=#%"), "%3F%26%3D%23%25")
  }

  func test_formUrlEncode_willReturnEmpty_forEmpty() {
    XCTAssertEqual(PortalAuthApi.formUrlEncode(""), "")
  }
}
