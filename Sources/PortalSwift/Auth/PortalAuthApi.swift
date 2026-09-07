//
//  PortalAuthApi.swift
//  PortalSwift
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// Thin transport for the six Client Auth endpoints — no session, storage or sequencing logic.
///
/// Every call carries `x-portal-auth-environment-id`; the `Accept`/`Content-Type` headers and
/// a fresh trace id come from `PortalAPIRequest`. No call carries a bearer except
/// `validateTotp`, whose bearer is the short-lived `userJwt`. The transport's `onUnauthorized`
/// hook is deliberately never installed here: a `401` from a grant exchange means the *grant*
/// was rejected, and there is no credential yet to invalidate.
///
/// Transport failures propagate unchanged as `PortalRequestsError` so a rejected grant keeps
/// the backend's own signal, with two deliberate exceptions where a status code carries an
/// actionable meaning: a `429` from `POST /magic-links` becomes `PortalAuthError.rateLimited`,
/// and a `400` from `POST /magic-links` or `GET /oauth/urls` whose body is `{"error": …}`
/// becomes `PortalAuthError.accountAbstractionUnavailable(message:)`. Only a malformed
/// `{ "data": … }` envelope, or a field the flow cannot continue without, is translated to
/// `PortalAuthError.malformedResponse`.
final class PortalAuthApi {
  /// The production API host, also the default of `PortalAuth.init`.
  static let defaultApiHost = "api.portalhq.io"
  /// Required on every Client Auth endpoint; identifies the auth environment.
  static let authEnvironmentIdHeader = "x-portal-auth-environment-id"

  static let basePath = "/api/v3/auth"
  static let methodsPath = basePath + "/methods"
  static let magicLinksPath = basePath + "/magic-links"
  static let magicLinkValidationsPath = basePath + "/magic-links/validations"
  static let oauthUrlsPath = basePath + "/oauth/urls"
  static let oauthTokensPath = basePath + "/oauth/tokens"
  static let totpValidationsPath = basePath + "/totps/validations"

  /// Upper bound on server text copied into `accountAbstractionUnavailable(message:)`.
  private static let maxServerMessageLength = 200

  /// The scheme-qualified base URL, e.g. `https://api.portalhq.io`, with no trailing slash.
  let apiUrl: String

  private let authEnvironmentId: String
  private let requests: PortalRequestsProtocol

  /// - Parameters:
  ///   - authEnvironmentId: Sent on every call as `x-portal-auth-environment-id`.
  ///   - apiHost: Host, or scheme-qualified origin, of connect-api. See `resolveApiUrl(_:)`.
  ///   - requests: The transport. A `PortalRequests()` in production; a recording double in tests.
  init(authEnvironmentId: String, apiHost: String = PortalAuthApi.defaultApiHost, requests: PortalRequestsProtocol = PortalRequests()) {
    self.authEnvironmentId = authEnvironmentId
    self.apiUrl = Self.resolveApiUrl(apiHost)
    self.requests = requests
  }

  // MARK: - URL resolution

  /// Prepends the scheme a host implies, matching the rule the rest of the SDK uses: a host
  /// given with an explicit `http://`/`https://` is honoured as-is, loopback (`localhost`,
  /// `127.0.0.1`) gets `http://`, everything else `https://`. Trailing slashes are removed so
  /// paths can be appended without producing `//`.
  ///
  /// The loopback check compares the host component exactly — not `hasPrefix` — so
  /// `localhost.attacker.com` stays `https://` (hardening over the Android SDK).
  static func resolveApiUrl(_ apiHost: String) -> String {
    let trimmed = RedirectUrl.stripTrailingSlashes(apiHost.trimmingCharacters(in: .whitespacesAndNewlines))
    let lowercased = trimmed.lowercased()

    if lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") {
      return trimmed
    }

    // The host component ends at the first `/` (a path) or `:` (a port).
    var hostEnd = lowercased.endIndex
    if let slash = lowercased.firstIndex(of: "/") {
      hostEnd = slash
    }
    if let colon = lowercased[..<hostEnd].firstIndex(of: ":") {
      hostEnd = colon
    }
    let host = lowercased[..<hostEnd]

    if host == "localhost" || host == "127.0.0.1" {
      return "http://" + trimmed
    }
    return "https://" + trimmed
  }

  /// The absolute URL for `path` (which may carry a query string).
  ///
  /// Validates that the result has a scheme and a well-formed host before returning it: a
  /// blank `apiHost`, or one containing spaces or other characters no hostname can contain,
  /// yields `PortalAuthError.invalidArgument(name: "apiHost")` rather than a request to
  /// nowhere. Never force-unwraps.
  func urlFor(_ path: String) throws -> URL {
    let absolute = self.apiUrl + path
    guard let components = URLComponents(string: absolute),
          let scheme = components.scheme, !scheme.isEmpty,
          let host = components.percentEncodedHost, Self.isWellFormedHost(host),
          let url = URL(string: absolute)
    else {
      throw PortalAuthError.invalidArgument(name: "apiHost")
    }
    return url
  }

  /// Percent-encodes a query value the way Java's `URLEncoder` does, with `+` replaced by
  /// `%20`.
  ///
  /// Unreserved characters (`A-Z a-z 0-9 - _ . *`) pass through; everything else — including
  /// `:`, `/`, `~` and non-ASCII — is percent-encoded as uppercase UTF-8 hex. The backend
  /// matches `redirectUrl` **byte-for-byte** against the auth environment's allow list and the
  /// other SDKs all send this exact form, so `URLQueryItem` (which leaves `:` and `/` alone)
  /// would silently produce a `401`.
  static func formUrlEncode(_ value: String) -> String {
    var output = ""
    output.reserveCapacity(value.utf8.count)

    for byte in value.utf8 {
      switch byte {
      case UInt8(ascii: "A") ... UInt8(ascii: "Z"),
           UInt8(ascii: "a") ... UInt8(ascii: "z"),
           UInt8(ascii: "0") ... UInt8(ascii: "9"),
           UInt8(ascii: "-"), UInt8(ascii: "_"), UInt8(ascii: "."), UInt8(ascii: "*"):
        output.unicodeScalars.append(Unicode.Scalar(byte))
      default:
        output.append("%")
        output.append(Self.hexDigit(byte >> 4))
        output.append(Self.hexDigit(byte & 0x0F))
      }
    }

    return output
  }

  // MARK: - Endpoints

  /// `GET /methods`: the auth methods enabled for the environment plus the wallet hint.
  /// Unknown method strings are dropped, never a failure.
  func getMethods() async throws -> AuthMethodsResult {
    let request = try self.makeRequest(path: Self.methodsPath, method: .get)
    let data = try await self.requests.execute(request: request)
    let body = try Self.unwrap(data, path: Self.methodsPath, as: AuthMethodsResponse.self)

    return AuthMethodsResult(
      allowedAuthMethods: (body.allowedAuthMethods ?? []).compactMap { AuthMethod(rawValue: $0) },
      autoCreateWallet: body.autoCreateWallet ?? false
    )
  }

  /// `POST /magic-links`: sends the email. The response body is ignored — only the status
  /// matters. `isAccountAbstracted` is omitted from the body when `nil`.
  ///
  /// - Throws: `PortalAuthError.rateLimited` on `429`; `.accountAbstractionUnavailable` on a
  ///   `400` carrying `{"error": …}`; every other transport error unchanged.
  func sendMagicLink(email: String, redirectUrl: String, magicLink: MagicLinkConfig, isAccountAbstracted: Bool?) async throws {
    let body = SendMagicLinkRequest(
      email: email,
      redirectUrl: redirectUrl,
      fromEmail: magicLink.fromEmail,
      templateId: magicLink.templateId,
      isAccountAbstracted: isAccountAbstracted
    )
    let request = try self.makeRequest(path: Self.magicLinksPath, method: .post, payload: body)

    do {
      _ = try await self.requests.execute(request: request)
    } catch {
      throw Self.mapMagicLinkError(error)
    }
  }

  /// `POST /magic-links/validations`: exchanges a magic-link grant.
  func validateMagicLink(token: String) async throws -> AuthGrantValidationResponse {
    try await self.exchangeGrant(path: Self.magicLinkValidationsPath, token: token)
  }

  /// `GET /oauth/urls?redirectUrl=…[&isAccountAbstracted=true|false]`: the provider authorize
  /// URLs. A key is present only for a provider the environment has enabled.
  ///
  /// The `state` embedded in these URLs is single-use and shared across both providers in one
  /// response, so callers must fetch fresh per tap and never cache. A `401` here is
  /// deliberately untranslated: it can mean an invalid environment, a `redirectUrl` that is
  /// not allow-listed, or a half-configured provider, and the SDK cannot tell them apart.
  ///
  /// - Throws: `PortalAuthError.accountAbstractionUnavailable` on a `400` carrying
  ///   `{"error": …}`; every other transport error unchanged.
  func getOAuthUrls(redirectUrl: String, isAccountAbstracted: Bool?) async throws -> OAuthUrlsResponse {
    var query = "?redirectUrl=" + Self.formUrlEncode(redirectUrl)
    if let isAccountAbstracted = isAccountAbstracted {
      query += "&isAccountAbstracted=" + (isAccountAbstracted ? "true" : "false")
    }

    let request = try self.makeRequest(path: Self.oauthUrlsPath + query, method: .get)
    let data: Data
    do {
      data = try await self.requests.execute(request: request)
    } catch {
      throw Self.mapOAuthUrlsError(error)
    }

    // The bare path, not the query-bearing one: the error names an endpoint, and the redirect
    // URL adds nothing a reader needs.
    return try Self.unwrap(data, path: Self.oauthUrlsPath, as: OAuthUrlsResponse.self)
  }

  /// `POST /oauth/tokens`: exchanges an OAuth grant. Both providers share the endpoint.
  func validateOAuthToken(token: String) async throws -> AuthGrantValidationResponse {
    try await self.exchangeGrant(path: Self.oauthTokensPath, token: token)
  }

  /// `POST /totps/validations` with `Authorization: Bearer <userJwt>`: submits a TOTP code.
  ///
  /// The only Client Auth call that carries a bearer, so the only one that could ever reach
  /// `PortalRequests.onUnauthorized` — which is why that hook is never installed on this
  /// transport. The code is posted verbatim; a wrong code does not burn the JWT.
  ///
  /// - Throws: `PortalAuthError.malformedResponse(path, "clientSessionToken")` when the
  ///   response carries no session token, or an empty or whitespace-only one — the same
  ///   non-blank rule `PersistedSessionCodec` and `resolveCredentialToken` apply, so a token
  ///   that could never be used is rejected here rather than persisted.
  func validateTotp(code: String, userJwt: String) async throws -> TotpValidation {
    let request = try self.makeRequest(
      path: Self.totpValidationsPath,
      method: .post,
      payload: TotpCodeRequest(code: code),
      bearerToken: userJwt
    )
    let data = try await self.requests.execute(request: request)
    let body = try Self.unwrap(data, path: Self.totpValidationsPath, as: TotpValidationResponse.self)

    guard let clientSessionToken = body.clientSessionToken, !Self.isBlank(clientSessionToken) else {
      throw PortalAuthError.malformedResponse(path: Self.totpValidationsPath, missing: "clientSessionToken")
    }

    return TotpValidation(
      clientId: body.clientId,
      clientSessionToken: clientSessionToken,
      isAccountAbstracted: body.isAccountAbstracted
    )
  }

  // MARK: - Private: requests

  /// Exchanges a single-use grant for a session, or for the `userJwt` of a pending TOTP step.
  ///
  /// Both grant endpoints take the same request and answer in the same shape, so they share
  /// this body — including the `endUserId` guard: a completed grant must name the end user
  /// the session belongs to, and catching it here (where the path is known) beats persisting a
  /// session that would be rejected as incomplete on the next restore.
  private func exchangeGrant(path: String, token: String) async throws -> AuthGrantValidationResponse {
    let request = try self.makeRequest(path: path, method: .post, payload: GrantTokenRequest(token: token))
    let data = try await self.requests.execute(request: request)
    let grant = try Self.unwrap(data, path: path, as: AuthGrantValidationResponse.self)

    if let clientSessionToken = grant.clientSessionToken, !Self.isBlank(clientSessionToken),
       Self.isBlank(grant.endUserId ?? "")
    {
      throw PortalAuthError.malformedResponse(path: path, missing: "endUserId")
    }

    return grant
  }

  /// `true` for an empty or whitespace-only value — unusable as a bearer either way, which is why
  /// a session token is only "present" when this is `false`.
  private static func isBlank(_ value: String) -> Bool {
    value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  /// Builds the request: `PortalAPIRequest` supplies `Accept`, `Content-Type`, a fresh trace
  /// id and (when given) the bearer; this adds the auth environment header.
  private func makeRequest(path: String, method: HttpMethod, payload: (any Codable)? = nil, bearerToken: String? = nil) throws -> PortalAPIRequest {
    let request = try PortalAPIRequest(url: self.urlFor(path), method: method, payload: payload, bearerToken: bearerToken)
    request.headers[Self.authEnvironmentIdHeader] = self.authEnvironmentId
    return request
  }

  // MARK: - Private: decoding

  /// Unwraps `{ "data": … }` with a fresh `JSONDecoder`.
  ///
  /// A body that is not JSON, is JSON without a usable `data`, or has `data` in the wrong
  /// shape is the same failure from the caller's point of view — an endpoint that did not
  /// answer in the documented shape — so every decode failure maps to `malformedResponse`.
  private static func unwrap<T: Decodable>(_ data: Data, path: String, as _: T.Type) throws -> T {
    guard let envelope = try? JSONDecoder().decode(AuthEnvelope<T>.self, from: data),
          let payload = envelope.data
    else {
      throw PortalAuthError.malformedResponse(path: path, missing: nil)
    }
    return payload
  }

  // MARK: - Private: error mapping

  private static func mapMagicLinkError(_ error: Error) -> Error {
    guard let (status, body) = self.clientErrorParts(of: error) else {
      return error
    }
    if status == 429 {
      return PortalAuthError.rateLimited
    }
    if status == 400, let message = self.serverErrorMessage(in: body) {
      return PortalAuthError.accountAbstractionUnavailable(message: message)
    }
    return error
  }

  private static func mapOAuthUrlsError(_ error: Error) -> Error {
    guard let (status, body) = self.clientErrorParts(of: error), status == 400,
          let message = self.serverErrorMessage(in: body)
    else {
      return error
    }
    return PortalAuthError.accountAbstractionUnavailable(message: message)
  }

  /// Splits a `PortalRequestsError.clientError` message, whose format is `"<status> - <body>"`,
  /// into its status code and body. The status is the leading integer and the body is
  /// everything after the first `" - "`, so a body that itself contains `" - "` survives
  /// intact (unlike `components(separatedBy:)`).
  private static func clientErrorParts(of error: Error) -> (status: Int, body: String)? {
    guard case let .clientError(message, _)? = error as? PortalRequestsError else {
      return nil
    }
    guard let separator = message.range(of: " - "),
          let status = Int(message[..<separator.lowerBound])
    else {
      return nil
    }
    return (status, String(message[separator.upperBound...]))
  }

  /// The `error` string of a `{"error": String}` body, bounded to 200 characters, or `nil`
  /// when the body is not that shape (not JSON, no `error` key, or a non-string value).
  private static func serverErrorMessage(in body: String) -> String? {
    struct ErrorBody: Decodable {
      let error: String?
    }

    guard let data = body.data(using: .utf8),
          let decoded = try? JSONDecoder().decode(ErrorBody.self, from: data),
          let message = decoded.error
    else {
      return nil
    }
    return String(message.prefix(self.maxServerMessageLength))
  }

  // MARK: - Private: helpers

  /// `true` for a host made only of characters a hostname or IP literal can contain. Rejects
  /// whitespace, residual percent-encoding and path/query characters, so a mistyped `apiHost`
  /// fails at `urlFor` instead of being silently "fixed" by a lenient URL parser.
  private static func isWellFormedHost(_ host: String) -> Bool {
    guard !host.isEmpty else {
      return false
    }
    for scalar in host.unicodeScalars {
      switch scalar {
      case "a" ... "z", "A" ... "Z", "0" ... "9", ".", "-", ":", "[", "]":
        continue
      default:
        return false
      }
    }
    return true
  }

  private static func hexDigit(_ nibble: UInt8) -> Character {
    let digits: [Character] = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"]
    return digits[Int(nibble & 0x0F)]
  }
}
