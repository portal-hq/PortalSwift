//
//  AuthTestFixtures.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

/// Thrown by the fixture helpers that refuse to force-unwrap.
enum AuthTestFixturesError: LocalizedError {
  case invalidUrl(String)

  var errorDescription: String? {
    switch self {
    case let .invalidUrl(value):
      return "AuthTestFixtures: `\(value)` is not a valid URL."
    }
  }
}

/// The constants, wire bodies, JWTs, redirects, transport errors and factories every
/// `PortalAuth` test shares, so a test file never hand-writes a backend response shape or a
/// `PortalRequestsError` message and drifts from the contract the module actually parses.
///
/// Response builders return the exact `{ "data": … }` envelope connect-api sends and omit a
/// key whenever its argument is `nil` — the backend omits keys it has nothing to say about,
/// and "omitted" is the case the module must read as absent. For a deliberate `null`, build the
/// body by hand (`Data("{\"data\":{\"endUserId\":null,…}}".utf8)`) or through `envelope(_:)`
/// with an `NSNull()` value.
///
/// Transport errors are built in the format `PortalRequests.buildError` uses
/// (`"<status> - <body>"`) because `PortalAuthApi` parses that string to map a 429 and the
/// account-abstraction 400.
enum AuthTestFixtures {
  // MARK: - Constants

  /// The auth environment every fixture-built `PortalAuth` talks to.
  static let authEnvironmentId = "env-1234"
  /// A custom-scheme redirect, so `signInWith*` is usable and `RedirectUrl.customScheme(of:)`
  /// yields `"portalexample"`.
  static let redirectUrl = "portalexample://auth/callback"
  /// The production host; resolves to `https://api.portalhq.io`.
  static let apiHost = "api.portalhq.io"
  /// The scheme-qualified base of the six endpoints.
  static let apiBase = "https://api.portalhq.io/api/v3/auth"
  /// The magic-link config `makeAuth` installs by default, so `sendMagicLink` works out of the
  /// box and the four backend-required body fields have known values.
  static let magicLink = MagicLinkConfig(fromEmail: "login@example.com", templateId: "template-1")

  /// Default end user of `grantResponse` / `userJwt` / `persistedSession`.
  static let endUserId = "user-1"
  /// Default session token of `grantResponse` / `persistedSession`.
  static let clientSessionToken = "session-token"
  /// Default session token of `totpResponse` — distinct from `clientSessionToken` so a test can
  /// tell which exchange produced a persisted session.
  static let totpClientSessionToken = "totp-session-token"
  /// Default grant token of the redirect builders.
  static let grantToken = "grant-token"
  /// Authorize URLs for `oauthUrlsResponse`; each carries a `state` so a log-leak check can
  /// look for it.
  static let googleAuthorizeUrl = "https://accounts.google.com/o/oauth2/v2/auth?state=google-state"
  static let appleAuthorizeUrl = "https://appleid.apple.com/auth/authorize?state=apple-state"

  // MARK: - JSON bodies

  /// `Data` for any JSON object/array, with sorted keys so bodies are deterministic. A value
  /// `JSONSerialization` cannot encode is a fixture bug and fails the current test.
  static func json(_ object: Any, file: StaticString = #filePath, line: UInt = #line) -> Data {
    do {
      return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    } catch {
      XCTFail("AuthTestFixtures.json: the object is not valid JSON (\(type(of: error))).", file: file, line: line)
      return Data()
    }
  }

  /// `{ "data": <payload> }`. Pass `NSNull()` for `{ "data": null }`.
  static func envelope(_ payload: Any, file: StaticString = #filePath, line: UInt = #line) -> Data {
    self.json(["data": payload], file: file, line: line)
  }

  /// A grant-exchange response (`/magic-links/validations`, `/oauth/tokens`). Every `nil`
  /// argument omits its key. The defaults describe a completed login for `user-1` with the
  /// session token `session-token` and no client metadata.
  static func grantResponse(
    clientSessionToken: String? = AuthTestFixtures.clientSessionToken,
    endUserId: String? = AuthTestFixtures.endUserId,
    clientId: String? = nil,
    isAccountAbstracted: Bool? = nil,
    userJwt: String? = nil,
    totpLink: String? = nil
  ) -> Data {
    var payload: [String: Any] = [:]
    if let clientSessionToken = clientSessionToken {
      payload["clientSessionToken"] = clientSessionToken
    }
    if let endUserId = endUserId {
      payload["endUserId"] = endUserId
    }
    if let clientId = clientId {
      payload["clientId"] = clientId
    }
    if let isAccountAbstracted = isAccountAbstracted {
      payload["isAccountAbstracted"] = isAccountAbstracted
    }
    if let userJwt = userJwt {
      payload["userJwt"] = userJwt
    }
    if let totpLink = totpLink {
      payload["totpLink"] = totpLink
    }
    return self.envelope(payload)
  }

  /// `grantResponse` under the short name the sign-in tests use.
  static func grant(
    cst: String? = AuthTestFixtures.clientSessionToken,
    endUserId: String? = AuthTestFixtures.endUserId,
    clientId: String? = nil,
    isAccountAbstracted: Bool? = nil,
    userJwt: String? = nil,
    totpLink: String? = nil
  ) -> Data {
    self.grantResponse(
      clientSessionToken: cst,
      endUserId: endUserId,
      clientId: clientId,
      isAccountAbstracted: isAccountAbstracted,
      userJwt: userJwt,
      totpLink: totpLink
    )
  }

  /// A `/totps/validations` response. Carries no `endUserId` — the module reads it from the JWT.
  static func totpResponse(
    clientSessionToken: String? = AuthTestFixtures.totpClientSessionToken,
    clientId: String? = nil,
    isAccountAbstracted: Bool? = nil
  ) -> Data {
    var payload: [String: Any] = [:]
    if let clientSessionToken = clientSessionToken {
      payload["clientSessionToken"] = clientSessionToken
    }
    if let clientId = clientId {
      payload["clientId"] = clientId
    }
    if let isAccountAbstracted = isAccountAbstracted {
      payload["isAccountAbstracted"] = isAccountAbstracted
    }
    return self.envelope(payload)
  }

  /// A `/oauth/urls` response with a key per enabled provider; both `nil` yields `{"data":{}}`.
  static func oauthUrlsResponse(google: String? = nil, apple: String? = nil) -> Data {
    var payload: [String: Any] = [:]
    if let google = google {
      payload["google"] = google
    }
    if let apple = apple {
      payload["apple"] = apple
    }
    return self.envelope(payload)
  }

  /// `oauthUrlsResponse` under the short name the sign-in tests use; defaults to both providers
  /// enabled with the fixture authorize URLs.
  static func oauthUrls(
    google: String? = AuthTestFixtures.googleAuthorizeUrl,
    apple: String? = AuthTestFixtures.appleAuthorizeUrl
  ) -> Data {
    self.oauthUrlsResponse(google: google, apple: apple)
  }

  /// A `/methods` response. `methods` are raw wire strings so an unknown one can be sent;
  /// `autoCreateWallet == nil` omits the key (the module reads that as `false`).
  static func methodsResponse(_ methods: [String], autoCreateWallet: Bool? = nil) -> Data {
    var payload: [String: Any] = ["allowedAuthMethods": methods]
    if let autoCreateWallet = autoCreateWallet {
      payload["autoCreateWallet"] = autoCreateWallet
    }
    return self.envelope(payload)
  }

  /// `methodsResponse` taking the SDK enum.
  static func methodsResponse(_ methods: [AuthMethod], autoCreateWallet: Bool? = nil) -> Data {
    self.methodsResponse(methods.map { $0.rawValue }, autoCreateWallet: autoCreateWallet)
  }

  /// The `POST /magic-links` success body. The module ignores it; only the status matters.
  static var sentResponse: Data {
    self.envelope(["sent": true])
  }

  // MARK: - Persisted session

  /// The exact string `KeychainAuthSessionStorage` holds for a session:
  /// `{"clientSessionToken":"…","endUserId":"…"}` with sorted keys.
  static func persistedSession(
    token: String = AuthTestFixtures.clientSessionToken,
    endUserId: String = AuthTestFixtures.endUserId
  ) -> String {
    let data = self.json(["clientSessionToken": token, "endUserId": endUserId])
    return String(data: data, encoding: .utf8) ?? ""
  }

  // MARK: - JWTs

  /// Which base64 alphabet `jwt(claims:alphabet:padded:)` encodes segments with.
  enum Base64Alphabet {
    /// `-` and `_` (RFC 4648 §5), what a real JWT uses.
    case base64url
    /// `+` and `/` (RFC 4648 §4), which the decoder also accepts.
    case standard
  }

  /// The header segment every fixture JWT carries: `{"alg":"HS256","typ":"JWT"}`.
  static let jwtHeaderJSON = "{\"alg\":\"HS256\",\"typ\":\"JWT\"}"

  /// Encodes `data` as base64 in `alphabet`, with or without `=` padding.
  static func base64Encode(_ data: Data, alphabet: Base64Alphabet = .base64url, padded: Bool = false) -> String {
    var encoded = data.base64EncodedString()
    if alphabet == .base64url {
      encoded = encoded.replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
    }
    if !padded {
      while encoded.hasSuffix("=") {
        encoded.removeLast()
      }
    }
    return encoded
  }

  /// A three-segment JWT whose claims segment is `claims` encoded verbatim (JSON or not), so a
  /// test can build a payload that is not JSON, not an object, or not UTF-8 (`claimsBytes`).
  /// The signature is a fixed literal; the module never verifies it.
  static func jwt(
    claims: String,
    alphabet: Base64Alphabet = .base64url,
    padded: Bool = false,
    header: String = AuthTestFixtures.jwtHeaderJSON
  ) -> String {
    self.jwt(claimsBytes: Data(claims.utf8), alphabet: alphabet, padded: padded, header: header)
  }

  /// `jwt(claims:alphabet:padded:header:)` with the claims serialised from a JSON object.
  static func jwt(
    claims: [String: Any],
    alphabet: Base64Alphabet = .base64url,
    padded: Bool = false,
    header: String = AuthTestFixtures.jwtHeaderJSON
  ) -> String {
    self.jwt(claimsBytes: self.json(claims), alphabet: alphabet, padded: padded, header: header)
  }

  /// `jwt(claims:…)` over raw claim bytes, for a payload that is not valid UTF-8.
  static func jwt(
    claimsBytes: Data,
    alphabet: Base64Alphabet = .base64url,
    padded: Bool = false,
    header: String = AuthTestFixtures.jwtHeaderJSON
  ) -> String {
    let headerSegment = self.base64Encode(Data(header.utf8), alphabet: alphabet, padded: padded)
    let claimsSegment = self.base64Encode(claimsBytes, alphabet: alphabet, padded: padded)
    return "\(headerSegment).\(claimsSegment).signature"
  }

  /// A realistic `userJwt` for `endUserId`: the claim the module reads plus the other claims a
  /// backend-issued one carries (`environmentId`, `iat`, `exp`, `aud`, `iss`), base64url, unpadded.
  static func userJwt(endUserId: String = AuthTestFixtures.endUserId) -> String {
    self.jwt(claims: [
      "endUserId": endUserId,
      "environmentId": self.authEnvironmentId,
      "iat": 1_700_000_000,
      "exp": 1_700_000_600,
      "aud": "portal-client-auth",
      "iss": "https://api.portalhq.io"
    ])
  }

  /// `userJwt(endUserId:)` under the name the UserJwt tests use.
  static func jwt(for endUserId: String) -> String {
    self.userJwt(endUserId: endUserId)
  }

  // MARK: - Redirects

  /// A magic-link completion redirect: `<redirectUrl>?token=<token>&authMethod=EMAIL_MAGIC_LINK`.
  /// `token` is inserted verbatim (pre-encode it yourself to test decoding).
  static func magicLinkRedirect(
    _ token: String = AuthTestFixtures.grantToken,
    redirectUrl: String = AuthTestFixtures.redirectUrl
  ) -> String {
    "\(redirectUrl)?token=\(token)&authMethod=\(AuthMethod.emailMagicLink.rawValue)"
  }

  /// An OAuth completion redirect: `<redirectUrl>?token=<token>&login_type=<loginType>`.
  /// `loginType` is a raw wire string so an unknown provider can be sent.
  static func oauthRedirect(
    _ token: String = AuthTestFixtures.grantToken,
    loginType: String = AuthMethod.google.rawValue,
    redirectUrl: String = AuthTestFixtures.redirectUrl
  ) -> String {
    "\(redirectUrl)?token=\(token)&login_type=\(loginType)"
  }

  /// `URL(string:)` that throws instead of force-unwrapping.
  static func url(_ string: String) throws -> URL {
    guard let url = URL(string: string) else {
      throw AuthTestFixturesError.invalidUrl(string)
    }
    return url
  }

  // MARK: - Transport errors

  /// A 4xx as `PortalRequests.buildError` produces it: `.clientError("<status> - <body>", url:)`.
  static func clientError(
    status: Int,
    body: String,
    url: String = AuthTestFixtures.apiBase + "/magic-links"
  ) -> PortalRequestsError {
    .clientError("\(status) - \(body)", url: url)
  }

  /// A 5xx in the same format.
  static func serverError(
    status: Int,
    body: String,
    url: String = AuthTestFixtures.apiBase + "/magic-links"
  ) -> PortalRequestsError {
    .internalServerError("\(status) - \(body)", url: url)
  }

  /// The `429` `POST /magic-links` returns when an address hit the per-minute limit.
  static var rateLimited429: PortalRequestsError {
    self.clientError(status: 429, body: "{\"error\":\"Too many requests\"}")
  }

  /// A transient `503`.
  static var serverError503: PortalRequestsError {
    self.serverError(status: 503, body: "Service Unavailable")
  }

  /// The bare `401` a rejected grant, code or environment produces. Never remapped by the module.
  static var unauthorized: PortalRequestsError {
    .unauthorized
  }

  // MARK: - Factories

  /// A `PortalAuthApi` over `requests` for the fixture environment.
  static func makeApi(
    requests: PortalRequestsProtocol,
    authEnvironmentId: String = AuthTestFixtures.authEnvironmentId,
    apiHost: String = AuthTestFixtures.apiHost
  ) -> PortalAuthApi {
    PortalAuthApi(authEnvironmentId: authEnvironmentId, apiHost: apiHost, requests: requests)
  }

  /// A `PortalAuth` over the internal init, with the fixture defaults.
  ///
  /// `logger`, when given, is installed into `PortalLogger.shared.sink` (the production
  /// module has no logger parameter — it logs through the shared logger); the test must call
  /// `logger.uninstall()` in `tearDown`. `magicLink` defaults to `AuthTestFixtures.magicLink`;
  /// pass `nil` explicitly to test `magicLinkNotConfigured`. When `webSessionFactory` is `nil`
  /// the module's production default (a real `ASWebAuthenticationSessionAdapter`) is kept.
  static func makeAuth(
    requests: PortalRequestsProtocol,
    storage: AuthSessionStorage = MockAuthSessionStorage(),
    logger: RecordingLogger? = nil,
    magicLink: MagicLinkConfig? = AuthTestFixtures.magicLink,
    isAccountAbstracted: Bool? = nil,
    apiHost: String = AuthTestFixtures.apiHost,
    redirectUrl: String = AuthTestFixtures.redirectUrl,
    authEnvironmentId: String = AuthTestFixtures.authEnvironmentId,
    webSessionFactory: (() -> AuthWebSessionProviding)? = nil
  ) -> PortalAuth {
    logger?.install()

    let api = self.makeApi(requests: requests, authEnvironmentId: authEnvironmentId, apiHost: apiHost)

    if let webSessionFactory = webSessionFactory {
      return PortalAuth(
        redirectUrl: redirectUrl,
        api: api,
        storage: storage,
        magicLink: magicLink,
        isAccountAbstracted: isAccountAbstracted,
        webSessionFactory: webSessionFactory
      )
    }
    return PortalAuth(
      redirectUrl: redirectUrl,
      api: api,
      storage: storage,
      magicLink: magicLink,
      isAccountAbstracted: isAccountAbstracted
    )
  }

  // MARK: - Waiting

  /// Polls `condition` every 10 ms until it holds or `timeout` seconds pass; returns whether it
  /// held. The only sanctioned way to wait on state a test cannot `await` directly — never a
  /// fixed sleep.
  static func pollUntil(timeout: TimeInterval = 2, _ condition: @escaping () -> Bool) async -> Bool {
    await waitUntil(timeout: timeout, condition)
  }

  /// Runs `operation` and returns its value, or `nil` once `seconds` have passed without it
  /// finishing (the loser is cancelled). An error from `operation` propagates unchanged. Keeps a
  /// re-entrancy or deadlock regression in `grantMutex` a failed assertion, not a hung suite.
  static func withTimeout<T>(
    _ seconds: TimeInterval = 2,
    _ operation: @escaping @Sendable () async throws -> T
  ) async throws -> T? {
    try await withThrowingTaskGroup(of: T?.self) { group in
      group.addTask {
        try await operation()
      }
      group.addTask {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        return nil
      }
      let first = try await group.next() ?? nil
      group.cancelAll()
      return first
    }
  }
}

// MARK: - XCTAssertThrowsAsync

/// `XCTAssertThrowsError` for an `async` expression: fails the test when `expression` returns
/// normally, otherwise hands the thrown error to `errorHandler` for further assertions.
func XCTAssertThrowsAsync<T>(
  _ expression: @autoclosure () async throws -> T,
  _ message: @autoclosure () -> String = "",
  file: StaticString = #filePath,
  line: UInt = #line,
  _ errorHandler: (Error) -> Void = { _ in }
) async {
  do {
    _ = try await expression()
    let detail = message()
    XCTFail(detail.isEmpty ? "Expected the expression to throw, but it returned normally." : detail, file: file, line: line)
  } catch {
    errorHandler(error)
  }
}

/// `XCTAssertThrowsAsync` that also asserts the thrown error equals `expected` (same type and
/// value). Returns the thrown error for any extra checks, or `nil` when nothing was thrown.
@discardableResult
func XCTAssertThrowsAsync<T, E: Error & Equatable>(
  _ expression: @autoclosure () async throws -> T,
  expected: E,
  _ message: @autoclosure () -> String = "",
  file: StaticString = #filePath,
  line: UInt = #line
) async -> Error? {
  do {
    _ = try await expression()
    let detail = message()
    XCTFail(detail.isEmpty ? "Expected \(expected) to be thrown, but the expression returned normally." : detail, file: file, line: line)
    return nil
  } catch {
    guard let typed = error as? E else {
      XCTFail("Expected \(expected) but a \(type(of: error)) was thrown. \(message())", file: file, line: line)
      return error
    }
    XCTAssertEqual(typed, expected, message(), file: file, line: line)
    return error
  }
}
