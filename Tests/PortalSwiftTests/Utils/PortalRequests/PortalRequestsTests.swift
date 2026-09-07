//
//  PortalRequestsTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

/// Drives the real `PortalRequests` pipeline end to end through `MockURLProtocol`, so every
/// assertion is about what the transport would actually put on the wire and how it reacts to
/// what comes back: request shaping (method, bearer, custom headers, body, `Content-Length`),
/// response mapping (`Data`, `String`, `Decodable`), the error family per status class, the
/// `onUnauthorized` 401 hook and its three-way gate (status, `Authorization` header present,
/// Portal-owned host), and the `X-Portal-Trace-Id` gating that keeps the correlation token off
/// third-party hosts.
///
/// The subject is constructed through the `init(urlSession:)` seam with an ephemeral session
/// whose only protocol is `MockURLProtocol`, so no test can reach the network. The logger sink
/// is captured for every case so the "never logs the bearer" assertion is real rather than
/// vacuous, and the invalidation registry is reset around each case because the swallowed-hook
/// case routes through `reportUnauthorized` and would otherwise leave a reported flag behind.
final class PortalRequestsTests: XCTestCase {
  private var session = MockURLProtocol.makeSession()
  private var sut = PortalRequests()
  private var logger = RecordingLogger()
  private var previousLogLevel: PortalLogLevel = .none

  private var portalUrl = URL(fileURLWithPath: "/")
  private var thirdPartyUrl = URL(fileURLWithPath: "/")
  private var rpcUrl = URL(fileURLWithPath: "/")

  override func setUpWithError() throws {
    try super.setUpWithError()
    CredentialInvalidationRegistry.shared.resetForTesting()
    MockURLProtocol.reset()
    self.session = MockURLProtocol.makeSession()
    self.sut = PortalRequests(urlSession: self.session)
    self.logger = RecordingLogger()
    self.logger.install()
    self.previousLogLevel = PortalLogger.shared.logLevel
    self.portalUrl = try XCTUnwrap(URL(string: "https://api.portalhq.io/api/v3/clients/me"))
    self.thirdPartyUrl = try XCTUnwrap(URL(string: "https://www.googleapis.com/drive/v3/files"))
    self.rpcUrl = try XCTUnwrap(URL(string: "https://eth.llamarpc.com/rpc"))
  }

  override func tearDownWithError() throws {
    PortalLogger.shared.setLogLevel(self.previousLogLevel)
    self.logger.uninstall()
    self.session.invalidateAndCancel()
    MockURLProtocol.reset()
    CredentialInvalidationRegistry.shared.resetForTesting()
    try super.tearDownWithError()
  }

  // MARK: - execute(request:)

  func test_execute_willReturnBody_on200() async throws {
    let body = "{\"ok\":true}"
    MockURLProtocol.respond(status: 200, body: body)

    let data = try await self.sut.execute(request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t"))

    XCTAssertEqual(data, Data(body.utf8))
    let recorded = MockURLProtocol.recordedRequests
    XCTAssertEqual(recorded.count, 1)
    let request = try XCTUnwrap(recorded.first)
    XCTAssertEqual(request.httpMethod, "GET")
    XCTAssertEqual(request.url, self.portalUrl)
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer t")
  }

  func test_execute_willThrowCouldNotParseHttpResponse_whenNotHTTPURLResponse() async throws {
    MockURLProtocol.respondWithNonHttpResponse(body: Data("not-http".utf8))
    let hook = self.installCountingHook()

    let error = await self.expectError {
      try await self.sut.execute(request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t"))
    }

    XCTAssertEqual(error as? PortalRequestsError, .couldNotParseHttpResponse)
    XCTAssertEqual(hook.value, 0, "A non-HTTP response is not a 401 and must not touch the hook")
  }

  func test_execute_willThrowRedirectError_on3xx() async throws {
    MockURLProtocol.respond(status: 302, body: "moved")
    let hook = self.installCountingHook()

    let error = await self.expectError {
      try await self.sut.execute(request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t"))
    }

    let requestsError = try XCTUnwrap(error as? PortalRequestsError)
    XCTAssertEqual(requestsError, .redirectError("302 - moved"))
    XCTAssertEqual(requestsError.dataStr, "moved")
    XCTAssertEqual(hook.value, 0)
  }

  func test_execute_willThrowClientErrorWithUrl_on400() async throws {
    MockURLProtocol.respond(status: 400, body: "{\"error\":\"x\"}")

    let error = await self.expectError {
      try await self.sut.execute(request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t"))
    }

    XCTAssertEqual(
      error as? PortalRequestsError,
      .clientError("400 - {\"error\":\"x\"}", url: self.portalUrl.absoluteString)
    )
  }

  func test_execute_willThrowUnauthorized_on401() async throws {
    MockURLProtocol.respond(status: 401, body: "{\"error\":\"Unauthorized\"}")

    let error = await self.expectError {
      try await self.sut.execute(request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t"))
    }

    let requestsError = try XCTUnwrap(error as? PortalRequestsError)
    XCTAssertEqual(requestsError, .unauthorized)
    XCTAssertNil(requestsError.dataStr, "The 401 body is discarded; .unauthorized carries no payload")
  }

  func test_execute_willThrowInternalServerError_on500() async throws {
    MockURLProtocol.respond(status: 500, body: "boom")

    let error = await self.expectError {
      try await self.sut.execute(request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t"))
    }

    XCTAssertEqual(
      error as? PortalRequestsError,
      .internalServerError("500 - boom", url: self.portalUrl.absoluteString)
    )
  }

  func test_execute_willRethrowURLError_onTransportFailure() async throws {
    MockURLProtocol.fail(with: URLError(.notConnectedToInternet))
    let hook = self.installCountingHook()

    let error = await self.expectError {
      try await self.sut.execute(request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t"))
    }

    let urlError = try XCTUnwrap(error as? URLError, "Expected the transport URLError to surface unchanged, got \(String(describing: error))")
    XCTAssertEqual(urlError.code, .notConnectedToInternet)
    XCTAssertNil(error as? PortalRequestsError, "A transport failure must not be rewrapped as a PortalRequestsError")
    XCTAssertEqual(hook.value, 0)
  }

  // MARK: - execute(request:mappingInResponse:)

  func test_executeMapping_willDecodeJson_on200() async throws {
    let stub = ClientResponse.stub(id: "client-42")
    try MockURLProtocol.respond(status: 200, body: JSONEncoder().encode(stub))

    let decoded = try await self.sut.execute(
      request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t"),
      mappingInResponse: ClientResponse.self
    )

    XCTAssertEqual(decoded.id, "client-42")
    XCTAssertEqual(decoded, stub)
  }

  func test_executeMapping_willReturnRawData_whenResponseTypeIsData() async throws {
    MockURLProtocol.respond(status: 200, body: "abc")

    let data = try await self.sut.execute(
      request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t"),
      mappingInResponse: Data.self
    )

    XCTAssertEqual(data, Data("abc".utf8))
  }

  func test_executeMapping_willReturnString_whenResponseTypeIsString() async throws {
    MockURLProtocol.respond(status: 200, body: "plain")

    let text = try await self.sut.execute(
      request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t"),
      mappingInResponse: String.self
    )
    XCTAssertEqual(text, "plain")

    // Bytes that are not valid UTF-8 map to the empty string rather than a decoding failure.
    MockURLProtocol.respond(status: 200, body: Data([0xFF, 0xFE, 0xFD]))

    let fallback = try await self.sut.execute(
      request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t"),
      mappingInResponse: String.self
    )
    XCTAssertEqual(fallback, "")
  }

  func test_executeMapping_willThrowDecodingError_whenBodyMalformed() async throws {
    MockURLProtocol.respond(status: 200, body: "{")
    let hook = self.installCountingHook()

    let error = await self.expectError {
      try await self.sut.execute(
        request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t"),
        mappingInResponse: ClientResponse.self
      )
    }

    XCTAssertTrue(error is DecodingError, "Expected a DecodingError, got \(String(describing: error))")
    XCTAssertEqual(hook.value, 0, "A malformed 200 body is not a 401 and must not touch the hook")
  }

  // MARK: - Request shaping (headers and body)

  func test_execute_willForwardAllCustomHeaders() async throws {
    MockURLProtocol.respond(status: 200, body: "{}")
    let request = PortalAPIRequest(url: self.portalUrl, bearerToken: "t")
    request.headers["x-portal-auth-environment-id"] = "env"

    _ = try await self.sut.execute(request: request)

    let recorded = try XCTUnwrap(MockURLProtocol.lastRequest)
    XCTAssertEqual(recorded.value(forHTTPHeaderField: "x-portal-auth-environment-id"), "env")
    XCTAssertEqual(recorded.value(forHTTPHeaderField: "Accept"), "application/json")
    XCTAssertEqual(recorded.value(forHTTPHeaderField: "Content-Type"), "application/json")
    XCTAssertEqual(recorded.value(forHTTPHeaderField: "Authorization"), "Bearer t")
  }

  func test_execute_willEncodePayloadAndContentLength() async throws {
    MockURLProtocol.respond(status: 200, body: "{}")
    let payload = TestPayload(k: "v")
    let request = PortalAPIRequest(url: self.portalUrl, method: .post, payload: payload, bearerToken: "t")

    _ = try await self.sut.execute(request: request)

    let recorded = try XCTUnwrap(MockURLProtocol.lastRequest)
    XCTAssertEqual(recorded.httpMethod, "POST")
    let body = try XCTUnwrap(recorded.httpBody, "The encoded payload must reach the wire as the request body")
    XCTAssertEqual(body, try JSONEncoder().encode(payload))
    XCTAssertEqual(try JSONDecoder().decode(TestPayload.self, from: body), payload)
    XCTAssertEqual(recorded.value(forHTTPHeaderField: "Content-Length"), "\(body.count)")
  }

  func test_execute_willSendNoBody_whenPayloadNil() async throws {
    MockURLProtocol.respond(status: 200, body: "{}")
    let request = PortalAPIRequest(url: self.portalUrl, method: .post, payload: nil, bearerToken: "t")

    _ = try await self.sut.execute(request: request)

    let recorded = try XCTUnwrap(MockURLProtocol.lastRequest)
    XCTAssertEqual(recorded.httpMethod, "POST")
    XCTAssertTrue((recorded.httpBody ?? Data()).isEmpty, "A nil payload must not produce a body")
    XCTAssertNil(recorded.value(forHTTPHeaderField: "Content-Length"), "No body means no Content-Length header")
  }

  func test_execute_willNotAddAuthorization_whenBearerNil() async throws {
    MockURLProtocol.respond(status: 200, body: "{}")

    _ = try await self.sut.execute(request: PortalAPIRequest(url: self.portalUrl, bearerToken: nil))

    let recorded = try XCTUnwrap(MockURLProtocol.lastRequest)
    XCTAssertNil(recorded.value(forHTTPHeaderField: "Authorization"))
  }

  func test_execute_willAddBearerHeader_whenBearerSupplied() async throws {
    MockURLProtocol.respond(status: 200, body: "{}")

    _ = try await self.sut.execute(request: PortalAPIRequest(url: self.portalUrl, bearerToken: "secret-token"))

    let recorded = try XCTUnwrap(MockURLProtocol.lastRequest)
    XCTAssertEqual(recorded.value(forHTTPHeaderField: "Authorization"), "Bearer secret-token")
  }

  // MARK: - onUnauthorized

  func test_onUnauthorized_willFire_when401WithBearerOnPortalHost() async throws {
    MockURLProtocol.respond(status: 401)
    let hook = self.installCountingHook()

    let error = await self.expectError {
      try await self.sut.execute(request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t"))
    }

    XCTAssertEqual(error as? PortalRequestsError, .unauthorized)
    XCTAssertEqual(hook.value, 1)
  }

  func test_onUnauthorized_willFireBeforeRethrow() async throws {
    MockURLProtocol.respond(status: 401)
    let events = HookEventLog()
    self.sut.onUnauthorized = { events.append("hook") }

    do {
      _ = try await self.sut.execute(request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t"))
      XCTFail("Expected .unauthorized to be thrown")
    } catch {
      events.append("caught")
    }

    XCTAssertEqual(events.events, ["hook", "caught"], "The hook must have run before the error reached the caller")
  }

  func test_onUnauthorized_willRethrowOriginalUnauthorized_afterHookRuns() async throws {
    MockURLProtocol.respond(status: 401)
    self.sut.onUnauthorized = {}

    let error = await self.expectError {
      try await self.sut.execute(request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t"))
    }

    let requestsError = try XCTUnwrap(error as? PortalRequestsError, "Expected a PortalRequestsError, got \(String(describing: error))")
    XCTAssertEqual(requestsError, .unauthorized)
  }

  /// The hook signature is non-throwing, so the "hook failure" is staged the way production
  /// does it: the closure routes through `reportUnauthorizedAndLog` with a credential whose
  /// `invalidate()` throws. The caller must still see the original `.unauthorized`, and the
  /// failure must leave exactly one error line behind and nothing else.
  func test_onUnauthorized_willSwallowHookFailure_andStillThrowUnauthorized() async throws {
    MockURLProtocol.respond(status: 401)
    let hookRuns = HookCounter()
    let credentials = MockCredentials(onInvalidate: { throw NSError(domain: "keystore", code: 9) })
    self.sut.onUnauthorized = {
      hookRuns.increment()
      reportUnauthorizedAndLog(credentials, context: "PortalRequestsTests.hook")
    }

    let error = await self.expectError {
      try await self.sut.execute(request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t"))
    }

    XCTAssertEqual(error as? PortalRequestsError, .unauthorized, "The hook failure must never replace the transport error")
    XCTAssertEqual(hookRuns.value, 1)
    XCTAssertEqual(credentials.invalidateCalls, 1)
    let errorLines = self.logger.messages(at: .error)
    XCTAssertEqual(errorLines.count, 1, "Expected exactly one error log line, got \(errorLines)")
    XCTAssertTrue(errorLines.first?.contains("PortalRequestsTests.hook") ?? false, "The error line must carry the hook's context")
  }

  func test_onUnauthorized_willNotFire_whenNoBearer() async throws {
    MockURLProtocol.respond(status: 401)
    let hook = self.installCountingHook()

    let error = await self.expectError {
      try await self.sut.execute(request: PortalAPIRequest(url: self.portalUrl, bearerToken: nil))
    }

    XCTAssertEqual(error as? PortalRequestsError, .unauthorized)
    XCTAssertEqual(hook.value, 0, "A 401 on a request that never carried a credential says nothing about the session")
  }

  /// PLAN 4.2 / 9.5 pin the gate on the *presence* of an `Authorization` header, whatever its
  /// scheme, so a `Basic` credential on a Portal host still counts as "this request was
  /// authenticated by us" and the hook fires. The matrix name records the question that was
  /// open when the case was written; the assertion records the decision.
  func test_onUnauthorized_willNotFire_whenAuthorizationHeaderIsNonBearer() async throws {
    MockURLProtocol.respond(status: 401)
    let hook = self.installCountingHook()
    let request = BareRequest(
      url: self.portalUrl,
      headers: ["Accept": "application/json", "Authorization": "Basic abc"]
    )

    let error = await self.expectError {
      try await self.sut.execute(request: request)
    }

    XCTAssertEqual(error as? PortalRequestsError, .unauthorized)
    XCTAssertEqual(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Basic abc")
    XCTAssertEqual(hook.value, 1, "The gate keys on any Authorization header, not on the Bearer prefix (PLAN 9.5)")
  }

  func test_onUnauthorized_willNotFire_whenHostIsNotPortal() async throws {
    MockURLProtocol.respond(status: 401)
    let hook = self.installCountingHook()

    let error = await self.expectError {
      try await self.sut.execute(request: PortalAPIRequest(url: self.rpcUrl, bearerToken: "t"))
    }

    XCTAssertEqual(error as? PortalRequestsError, .unauthorized, "The error itself is unchanged for third-party hosts")
    XCTAssertEqual(hook.value, 0)
  }

  func test_onUnauthorized_willNotFire_forGoogleApis401() async throws {
    MockURLProtocol.respond(status: 401)
    let hook = self.installCountingHook()

    let error = await self.expectError {
      try await self.sut.execute(request: PortalAPIRequest(url: self.thirdPartyUrl, bearerToken: "google-drive-token"))
    }

    XCTAssertEqual(error as? PortalRequestsError, .unauthorized)
    XCTAssertEqual(hook.value, 0, "A Google Drive 401 is about the Google token, never the Portal session")
  }

  func test_onUnauthorized_willNotFire_forLookalikeHost() async throws {
    MockURLProtocol.respond(status: 401)
    let hook = self.installCountingHook()
    let lookalike = try XCTUnwrap(URL(string: "https://api.portalhq.io.attacker.com/x"))

    let error = await self.expectError {
      try await self.sut.execute(request: PortalAPIRequest(url: lookalike, bearerToken: "t"))
    }

    XCTAssertEqual(error as? PortalRequestsError, .unauthorized)
    XCTAssertEqual(hook.value, 0, "A host that merely starts with api.portalhq.io must not be able to invalidate the session")
  }

  func test_onUnauthorized_willNotFire_on400() async throws {
    MockURLProtocol.respond(status: 400, body: "bad")
    let hook = self.installCountingHook()

    let error = await self.expectError {
      try await self.sut.execute(request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t"))
    }

    XCTAssertEqual(error as? PortalRequestsError, .clientError("400 - bad", url: self.portalUrl.absoluteString))
    XCTAssertEqual(hook.value, 0)
  }

  func test_onUnauthorized_willNotFire_on403_404_429() async throws {
    let hook = self.installCountingHook()

    for status in [403, 404, 429] {
      MockURLProtocol.respond(status: status, body: "denied")

      let error = await self.expectError {
        try await self.sut.execute(request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t"))
      }

      guard case .clientError(let message, let url)? = error as? PortalRequestsError else {
        XCTFail("Expected .clientError for \(status), got \(String(describing: error))")
        continue
      }
      XCTAssertEqual(message, "\(status) - denied")
      XCTAssertEqual(url, self.portalUrl.absoluteString)
      XCTAssertEqual(hook.value, 0, "Status \(status) must not fire the hook")
    }
  }

  func test_onUnauthorized_willNotFire_on500_503() async throws {
    let hook = self.installCountingHook()

    for status in [500, 503] {
      MockURLProtocol.respond(status: status, body: "down")

      let error = await self.expectError {
        try await self.sut.execute(request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t"))
      }

      guard case .internalServerError(let message, let url)? = error as? PortalRequestsError else {
        XCTFail("Expected .internalServerError for \(status), got \(String(describing: error))")
        continue
      }
      XCTAssertEqual(message, "\(status) - down")
      XCTAssertEqual(url, self.portalUrl.absoluteString)
      XCTAssertEqual(hook.value, 0, "Status \(status) must not fire the hook")
    }
  }

  func test_onUnauthorized_willNotFire_onSuccess() async throws {
    MockURLProtocol.respond(status: 200, body: "{}")
    let hook = self.installCountingHook()

    _ = try await self.sut.execute(request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t"))

    XCTAssertEqual(hook.value, 0)
  }

  func test_onUnauthorized_willNotFire_onTransportError() async throws {
    MockURLProtocol.fail(with: URLError(.timedOut))
    let hook = self.installCountingHook()

    let error = await self.expectError {
      try await self.sut.execute(request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t"))
    }

    XCTAssertEqual((error as? URLError)?.code, .timedOut)
    XCTAssertEqual(hook.value, 0, "No HTTP response means no status to react to")
  }

  func test_execute_willStaySilent_whenNoHookRegistered() async throws {
    MockURLProtocol.respond(status: 401)
    XCTAssertNil(self.sut.onUnauthorized, "Precondition: a fresh transport has no hook")

    let error = await self.expectError {
      try await self.sut.execute(request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t"))
    }

    XCTAssertEqual(error as? PortalRequestsError, .unauthorized)
    XCTAssertNil(self.sut.onUnauthorized, "The transport must not synthesise a hook on its own")
  }

  func test_onUnauthorized_willFire_forExecuteReturningData() async throws {
    MockURLProtocol.respond(status: 401)
    let hook = self.installCountingHook()

    let error = await self.expectError { () async throws -> Data in
      try await self.sut.execute(request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t"))
    }

    XCTAssertEqual(error as? PortalRequestsError, .unauthorized)
    XCTAssertEqual(hook.value, 1)
  }

  func test_onUnauthorized_willFire_forExecuteMapping() async throws {
    MockURLProtocol.respond(status: 401)
    let hook = self.installCountingHook()

    let error = await self.expectError {
      try await self.sut.execute(
        request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t"),
        mappingInResponse: ClientResponse.self
      )
    }

    XCTAssertEqual(error as? PortalRequestsError, .unauthorized)
    XCTAssertEqual(hook.value, 1)
  }

  func test_onUnauthorized_willFire_forDeprecatedGetPostPutPatchDelete() async throws {
    MockURLProtocol.respond(status: 401)
    let hook = self.installCountingHook()
    let payload = TestPayload(k: "v")

    let getError = await self.expectError { try await self.sut.get(self.portalUrl, withBearerToken: "t") }
    let postError = await self.expectError { try await self.sut.post(self.portalUrl, withBearerToken: "t", andPayload: payload) }
    let putError = await self.expectError { try await self.sut.put(self.portalUrl, withBearerToken: "t", andPayload: payload) }
    let patchError = await self.expectError { try await self.sut.patch(self.portalUrl, withBearerToken: "t", andPayload: payload) }
    let deleteError = await self.expectError { try await self.sut.delete(self.portalUrl, withBearerToken: "t") }

    for (verb, error) in [("get", getError), ("post", postError), ("put", putError), ("patch", patchError), ("delete", deleteError)] {
      XCTAssertEqual(error as? PortalRequestsError, .unauthorized, "Deprecated \(verb) must surface .unauthorized")
    }
    XCTAssertEqual(hook.value, 5, "Every deprecated verb goes through the same 401 gate")
    XCTAssertEqual(MockURLProtocol.recordedRequests.map { $0.httpMethod }, ["GET", "POST", "PUT", "PATCH", "DELETE"])
    for recorded in MockURLProtocol.recordedRequests {
      XCTAssertEqual(recorded.value(forHTTPHeaderField: "Authorization"), "Bearer t")
    }
  }

  func test_onUnauthorized_willFire_forPostMultiPartData() async throws {
    MockURLProtocol.respond(status: 401)
    let hook = self.installCountingHook()
    let boundary = "portal-boundary-123"
    let payload = "--\(boundary)\r\nContent-Type: application/json\r\n\r\n{}\r\n--\(boundary)--"

    let error = await self.expectError {
      try await self.sut.postMultiPartData(self.portalUrl, withBearerToken: "t", andPayload: payload, usingBoundary: boundary)
    }

    XCTAssertEqual(error as? PortalRequestsError, .unauthorized)
    XCTAssertEqual(hook.value, 1)
    let recorded = try XCTUnwrap(MockURLProtocol.lastRequest)
    XCTAssertEqual(recorded.httpMethod, "POST")
    XCTAssertEqual(recorded.value(forHTTPHeaderField: "Content-Type"), "multipart/related; boundary=\(boundary)")
    XCTAssertEqual(recorded.value(forHTTPHeaderField: "Authorization"), "Bearer t")
    XCTAssertEqual(recorded.httpBody, Data(payload.utf8), "The multipart body must reach the wire byte for byte")
  }

  func test_onUnauthorized_willFire_forRequestCarryingAuthEnvironmentHeader() async throws {
    MockURLProtocol.respond(status: 401)
    let hook = self.installCountingHook()
    let request = PortalAPIRequest(url: self.portalUrl, bearerToken: "t")
    request.headers["x-portal-auth-environment-id"] = "env-1234"

    let error = await self.expectError {
      try await self.sut.execute(request: request)
    }

    XCTAssertEqual(error as? PortalRequestsError, .unauthorized)
    XCTAssertEqual(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "x-portal-auth-environment-id"), "env-1234")
    XCTAssertEqual(hook.value, 1, "The transport is agnostic to the auth-environment header; PortalAuth simply never installs a hook")
  }

  func test_onUnauthorized_willFireOncePerRequest_whenEightConcurrent401s() async throws {
    MockURLProtocol.respond(status: 401)
    let hook = self.installCountingHook()
    let sut = self.sut
    let url = self.portalUrl

    let unauthorizedCount = await withTaskGroup(of: Bool.self) { group -> Int in
      for _ in 0 ..< 8 {
        group.addTask {
          do {
            _ = try await sut.execute(request: PortalAPIRequest(url: url, bearerToken: "t"))
            return false
          } catch {
            return (error as? PortalRequestsError) == .unauthorized
          }
        }
      }
      var count = 0
      for await sawUnauthorized in group where sawUnauthorized {
        count += 1
      }
      return count
    }

    XCTAssertEqual(unauthorizedCount, 8, "Every concurrent caller must see its own .unauthorized")
    XCTAssertEqual(hook.value, 8, "The transport fires once per rejected request; deduplication is the registry's job")
    XCTAssertEqual(MockURLProtocol.recordedRequests.count, 8)
  }

  func test_onUnauthorized_setter_willBeThreadSafe() async throws {
    MockURLProtocol.respond(status: 401)
    let hookInvocations = HookCounter()
    let finishedThreads = HookCounter()
    let sut = self.sut
    let url = self.portalUrl

    // Keep eight 401s in flight while eight threads hammer the setter and getter.
    let inFlight: [Task<Void, Never>] = (0 ..< 8).map { _ in
      Task {
        _ = try? await sut.execute(request: PortalAPIRequest(url: url, bearerToken: "t"))
      }
    }
    for index in 0 ..< 8 {
      let thread = Thread {
        for round in 0 ..< 100 {
          sut.onUnauthorized = { hookInvocations.increment() }
          _ = sut.onUnauthorized
          if index.isMultiple(of: 2), round.isMultiple(of: 3) {
            sut.onUnauthorized = nil
          }
        }
        finishedThreads.increment()
      }
      thread.name = "PortalRequestsTests.onUnauthorized-\(index)"
      thread.start()
    }

    for task in inFlight {
      await task.value
    }
    let allThreadsFinished = await waitUntil { finishedThreads.value == 8 }
    XCTAssertTrue(allThreadsFinished, "All setter/getter threads must finish without deadlocking")
    XCTAssertEqual(MockURLProtocol.recordedRequests.count, 8)

    // The final value is observable and is what the next 401 invokes.
    let finalHook = HookCounter()
    sut.onUnauthorized = { finalHook.increment() }
    XCTAssertNotNil(sut.onUnauthorized)
    let error = await self.expectError {
      try await sut.execute(request: PortalAPIRequest(url: url, bearerToken: "t"))
    }
    XCTAssertEqual(error as? PortalRequestsError, .unauthorized)
    XCTAssertEqual(finalHook.value, 1)
  }

  func test_onUnauthorized_willUseHookInstalledAtInvocationTime() async throws {
    let hookA = HookCounter()
    let hookB = HookCounter()
    self.sut.onUnauthorized = { hookA.increment() }
    let sut = self.sut

    // The handler runs after the request left the transport and before the response arrives:
    // swapping the hook here proves the transport reads it at invocation time, not at send time.
    MockURLProtocol.handler = { request in
      sut.onUnauthorized = { hookB.increment() }
      guard let url = request.url,
            let response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: "HTTP/1.1", headerFields: nil)
      else {
        throw URLError(.badServerResponse)
      }
      return (response, Data())
    }

    let error = await self.expectError {
      try await self.sut.execute(request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t"))
    }

    XCTAssertEqual(error as? PortalRequestsError, .unauthorized)
    XCTAssertEqual(hookA.value, 0, "The replaced hook must not run")
    XCTAssertEqual(hookB.value, 1, "The hook installed before the response arrived is the one invoked")
  }

  func test_PortalRequests_willConformToPortalUnauthorizedReporting() {
    let requests: PortalRequestsProtocol = PortalRequests()

    let reporting = requests as? PortalUnauthorizedReporting

    XCTAssertNotNil(reporting, "The credentials layer installs the 401 hook only through this conformance")
    XCTAssertNil(reporting?.onUnauthorized, "A fresh transport starts without a hook so the first owner can install one")
  }

  // MARK: - Trace header gating

  func test_execute_willAddTraceHeader_forPortalHost() async throws {
    MockURLProtocol.respond(status: 200, body: "{}")

    _ = try await self.sut.execute(request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t"))

    let recorded = try XCTUnwrap(MockURLProtocol.lastRequest)
    let traceId = try XCTUnwrap(recorded.value(forHTTPHeaderField: PORTAL_TRACE_ID_HEADER))
    XCTAssertNotNil(UUID(uuidString: traceId), "The synthesised trace id must be a UUID")
    XCTAssertEqual(traceId, traceId.lowercased(), "Trace ids are lowercased for parity with the other SDKs")
  }

  func test_execute_willPreserveCallerTraceHeader_forPortalHost() async throws {
    MockURLProtocol.respond(status: 200, body: "{}")

    _ = try await self.sut.execute(request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t", traceId: "explicit-trace-id"))

    let recorded = try XCTUnwrap(MockURLProtocol.lastRequest)
    XCTAssertEqual(recorded.value(forHTTPHeaderField: PORTAL_TRACE_ID_HEADER), "explicit-trace-id")
  }

  func test_execute_willSynthesiseTraceHeader_whenCustomRequestOmitsIt_onPortalHost() async throws {
    MockURLProtocol.respond(status: 200, body: "{}")
    let request = BareRequest(url: self.portalUrl, headers: ["Accept": "application/json"])

    _ = try await self.sut.execute(request: request)

    let recorded = try XCTUnwrap(MockURLProtocol.lastRequest)
    let traceId = try XCTUnwrap(recorded.value(forHTTPHeaderField: PORTAL_TRACE_ID_HEADER), "A Portal-bound request always carries a trace id, even when the caller omitted it")
    XCTAssertNotNil(UUID(uuidString: traceId))
    XCTAssertEqual(recorded.value(forHTTPHeaderField: "Accept"), "application/json")
  }

  func test_execute_willKeepTraceHeader_forLocalhost() async throws {
    MockURLProtocol.respond(status: 200, body: "{}")
    let localhost = try XCTUnwrap(URL(string: "http://localhost:3001/x"))

    _ = try await self.sut.execute(request: PortalAPIRequest(url: localhost, bearerToken: "t"))

    let recorded = try XCTUnwrap(MockURLProtocol.lastRequest)
    let traceId = try XCTUnwrap(recorded.value(forHTTPHeaderField: PORTAL_TRACE_ID_HEADER), "localhost is Portal-owned (a local connect-api) and keeps the trace id")
    XCTAssertNotNil(UUID(uuidString: traceId))
  }

  // MARK: - Session seam, bearer hygiene and logging

  func test_execute_willNotSendBearer_whenRequestForThirdPartyHasNone() async throws {
    MockURLProtocol.respond(status: 200, body: "{}")

    _ = try await self.sut.execute(request: PortalAPIRequest(url: self.thirdPartyUrl, bearerToken: nil))

    let recorded = try XCTUnwrap(MockURLProtocol.lastRequest)
    XCTAssertNil(recorded.value(forHTTPHeaderField: "Authorization"), "The transport never synthesises a credential")
  }

  func test_execute_willUseInjectedSession_notShared() async throws {
    MockURLProtocol.respond(status: 200, body: "{}")

    _ = try await self.sut.execute(request: PortalAPIRequest(url: self.portalUrl, bearerToken: "t"))

    // MockURLProtocol is registered only on the injected session, so a recorded request proves
    // the transport routed through it rather than through a fresh (network-bound) session.
    let recorded = MockURLProtocol.recordedRequests
    XCTAssertEqual(recorded.count, 1)
    XCTAssertEqual(recorded.first?.url, self.portalUrl)
  }

  func test_execute_willNeverLogAuthorizationHeader() async throws {
    PortalLogger.shared.setLogLevel(.debug)
    let secret = "SECRET"
    _ = self.installCountingHook()

    MockURLProtocol.respond(status: 401)
    let unauthorized = await self.expectError {
      try await self.sut.execute(request: PortalAPIRequest(url: self.portalUrl, bearerToken: secret))
    }
    XCTAssertEqual(unauthorized as? PortalRequestsError, .unauthorized)

    MockURLProtocol.respond(status: 500, body: "boom")
    let serverError = await self.expectError {
      try await self.sut.execute(request: PortalAPIRequest(url: self.portalUrl, bearerToken: secret))
    }
    XCTAssertEqual(serverError as? PortalRequestsError, .internalServerError("500 - boom", url: self.portalUrl.absoluteString))

    XCTAssertFalse(self.logger.messages.isEmpty, "The 401 path logs at debug level, so the leak assertion below is not vacuous")
    self.logger.assertNoSecret(secret)
    self.logger.assertNoSecret("Bearer \(secret)")
  }

  // MARK: - PortalRequestsError

  func test_PortalRequestsError_dataStr_willExtractBodyAfterSeparator() {
    XCTAssertEqual(PortalRequestsError.clientError("400 - body", url: "u").dataStr, "body")
    XCTAssertEqual(PortalRequestsError.internalServerError("500 - a - b", url: "u").dataStr, "a", "Only the second ' - ' component is the body")
    XCTAssertEqual(PortalRequestsError.redirectError("302 - x").dataStr, "x")
    XCTAssertNil(PortalRequestsError.unauthorized.dataStr)
    XCTAssertNil(PortalRequestsError.couldNotParseHttpResponse.dataStr)
    XCTAssertNil(PortalRequestsError.clientError("no-separator", url: "u").dataStr, "A message without the separator has no extractable body")
  }

  func test_PortalRequestsError_willBeEquatable() {
    XCTAssertEqual(PortalRequestsError.clientError("400 - a", url: "u"), .clientError("400 - a", url: "u"))
    XCTAssertNotEqual(PortalRequestsError.clientError("400 - a", url: "u"), .clientError("400 - a", url: "v"))
    XCTAssertNotEqual(PortalRequestsError.clientError("400 - a", url: "u"), .clientError("400 - b", url: "u"))

    XCTAssertEqual(PortalRequestsError.internalServerError("500 - a", url: "u"), .internalServerError("500 - a", url: "u"))
    XCTAssertNotEqual(PortalRequestsError.internalServerError("500 - a", url: "u"), .internalServerError("500 - a", url: "v"))

    XCTAssertEqual(PortalRequestsError.redirectError("302 - x"), .redirectError("302 - x"))
    XCTAssertNotEqual(PortalRequestsError.redirectError("302 - x"), .redirectError("301 - x"))

    XCTAssertEqual(PortalRequestsError.unauthorized, .unauthorized)
    XCTAssertEqual(PortalRequestsError.couldNotParseHttpResponse, .couldNotParseHttpResponse)
    XCTAssertNotEqual(PortalRequestsError.unauthorized, .couldNotParseHttpResponse)
    XCTAssertNotEqual(PortalRequestsError.clientError("x", url: "u"), .internalServerError("x", url: "u"))
    XCTAssertNotEqual(PortalRequestsError.redirectError("x"), .clientError("x", url: ""))
  }

  // MARK: - Helpers

  /// Installs a counting `onUnauthorized` hook on the subject and returns the counter, so a
  /// test can assert exactly how many times (usually zero or one) the transport fired it.
  private func installCountingHook() -> HookCounter {
    let counter = HookCounter()
    self.sut.onUnauthorized = { counter.increment() }
    return counter
  }

  /// `true` when the recorded request carries a header named `X-Portal-Trace-Id` under any
  /// casing. `URLRequest.value(forHTTPHeaderField:)` is already case-insensitive, but the
  /// "stripped" assertions walk every key so a differently-cased leak cannot slip past.
  private func hasTraceHeader(_ request: URLRequest) -> Bool {
    (request.allHTTPHeaderFields ?? [:]).keys.contains {
      $0.caseInsensitiveCompare(PORTAL_TRACE_ID_HEADER) == .orderedSame
    }
  }

  /// Runs an async throwing expression that is expected to throw and returns the error, or
  /// fails the test and returns `nil` when it completed normally. XCTest has no async
  /// `XCTAssertThrowsError`, and returning the error lets each case pin the exact value.
  @discardableResult
  private func expectError<T>(
    file: StaticString = #filePath,
    line: UInt = #line,
    _ expression: () async throws -> T
  ) async -> Error? {
    do {
      _ = try await expression()
      XCTFail("Expected the call to throw, but it returned normally.", file: file, line: line)
      return nil
    } catch {
      return error
    }
  }
}

// MARK: - Test doubles

/// A lock-guarded counter the 401 hook and worker threads bump from whichever thread completed
/// the request, so the assertion reads a consistent value.
private final class HookCounter {
  private let lock = NSLock()
  private var _value = 0

  var value: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._value
  }

  func increment() {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._value += 1
  }
}

/// An ordered, lock-guarded event log for the "hook runs before the error reaches the caller"
/// ordering assertion; appended from the transport's completion thread and the test's own.
private final class HookEventLog {
  private let lock = NSLock()
  private var _events: [String] = []

  var events: [String] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._events
  }

  func append(_ event: String) {
    self.lock.lock()
    defer { self.lock.unlock() }
    self._events.append(event)
  }
}

/// A minimal `PortalBaseRequestProtocol` conformer for the cases where `PortalAPIRequest`'s
/// unconditional shaping (a synthesised trace id, a `Bearer`-prefixed `Authorization`) would
/// get in the way: it sends exactly the headers it is given and nothing else.
private struct BareRequest: PortalBaseRequestProtocol {
  let url: URL
  let method: HttpMethod
  let headers: [String: String]
  let payload: (any Codable)?

  init(url: URL, method: HttpMethod = .get, headers: [String: String], payload: (any Codable)? = nil) {
    self.url = url
    self.method = method
    self.headers = headers
    self.payload = payload
  }
}

/// A one-field payload whose encoding is deterministic, so the body written to the wire can be
/// compared byte for byte against `JSONEncoder().encode(...)`.
private struct TestPayload: Codable, Equatable {
  let k: String
}
