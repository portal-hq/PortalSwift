//
//  PortalDelegationsApiCredentialsTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

/// `PortalDelegationsApi` stands in for the eight sub-APIs, which share one credential shape:
/// a `private let credentials`, a designated `init(credentials:apiHost:requests:)`, a deprecated
/// `init(apiKey:)` convenience, and per-call resolution inside the private `get`/`post` helpers.
///
/// The contract pinned here is the one that makes a rotating session work without rebuilding
/// anything: nothing is resolved at construction, every request resolves again, a rotated token
/// is sent on the next call, and a failing or dead credential fails the call before the request
/// is built — after the local URL validation, so a malformed argument is reported as a bad URL
/// rather than as a credential problem. The last case is the log-leak gate: the token must never
/// reach a log line, not even by way of a server error message that echoes it back.
///
/// The host-registration cases at the end run through a real `PortalRequests` on
/// `MockURLProtocol`, because what they pin — the 401 hook firing and the trace header going out
/// for a custom `apiHost` — is decided inside the transport, which the spy bypasses.
final class PortalDelegationsApiCredentialsTests: XCTestCase {
  /// A host an integrator fronts Portal through. Not Portal-owned until an SDK object is built
  /// against it, which is exactly what the registration cases prove.
  private static let customApiHost = "api.custodian.example"

  private var credentials = MockCredentials(tokenValue: "first-token")
  private var spy = PortalRequestsSpy()
  private var sut: PortalDelegationsApi?
  private var logger = RecordingLogger()
  private var previousLogLevel: PortalLogLevel = .none
  private let encoder = JSONEncoder()

  override func setUpWithError() throws {
    try super.setUpWithError()
    CredentialInvalidationRegistry.shared.resetForTesting()
    // The registry of configured hosts is process-wide; the registration cases assert on a host
    // being unknown first.
    PortalOwnedHosts.resetForTesting()
    MockURLProtocol.reset()

    self.previousLogLevel = PortalLogger.shared.logLevel
    PortalLogger.shared.setLogLevel(.debug)
    self.logger = RecordingLogger()
    self.logger.install()

    self.credentials = MockCredentials(tokenValue: "first-token")
    self.spy = PortalRequestsSpy()
    self.spy.returnData = try self.encoder.encode(DelegationStatusResponse.stub())
    self.sut = PortalDelegationsApi(
      credentials: self.credentials,
      apiHost: "api.portalhq.io",
      requests: self.spy
    )
  }

  override func tearDownWithError() throws {
    self.sut = nil
    self.logger.uninstall()
    PortalLogger.shared.setLogLevel(self.previousLogLevel)
    CredentialInvalidationRegistry.shared.resetForTesting()
    PortalOwnedHosts.resetForTesting()
    MockURLProtocol.reset()
    try super.tearDownWithError()
  }

  // MARK: - Helpers

  /// The API under test, or a failed assertion when `setUp` did not produce one.
  private func api(file: StaticString = #filePath, line: UInt = #line) throws -> PortalDelegationsApi {
    guard let sut = self.sut else {
      XCTFail("The PortalDelegationsApi under test was not constructed.", file: file, line: line)
      throw XCTSkip("No PortalDelegationsApi under test.")
    }
    return sut
  }

  /// The `Authorization` header of the most recent recorded request.
  private var lastAuthorizationHeader: String? {
    self.spy.executeRequestHistory.last?.headers["Authorization"]
  }

  /// The URL of the most recent recorded request.
  private var lastRequestUrl: String? {
    self.spy.executeRequestHistory.last?.url.absoluteString
  }

  /// An API host that makes every `URL(string:)` in the sub-API return `nil`.
  ///
  /// A malformed *path* no longer works for this: current Foundation percent-encodes invalid
  /// path characters instead of rejecting the string, so a chain containing a space still
  /// parses. A space in the authority component is still fatal, which is what this fixture
  /// relies on to reach the `URLError(.badURL)` branch and prove the ordering.
  private static let unparsableApiHost = "exa mple.com"

  /// Fails the test unless `error` is a `URLError(.badURL)`.
  private func assertBadUrl(_ error: Error, _ method: String, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual((error as? URLError)?.code, .badURL, "\(method) threw a \(type(of: error)) instead of URLError(.badURL).", file: file, line: line)
  }
}

// MARK: - Construction

extension PortalDelegationsApiCredentialsTests {
  func test_init_willNotResolveTokenAtConstruction() throws {
    // given & when: setUp constructed the API

    // then
    XCTAssertEqual(self.credentials.getTokenCalls, 0, "Constructing a sub-API must not touch the credential.")
    XCTAssertEqual(self.spy.executeCallsCount, 0)
  }

  func test_deprecatedInitApiKey_willStillAuthenticate() async throws {
    // given
    let api = PortalDelegationsApi(apiKey: "client-api-key", apiHost: "api.portalhq.io", requests: self.spy)

    // when
    _ = try await api.getStatus(request: .stub())

    // then
    XCTAssertEqual(self.lastAuthorizationHeader, "Bearer client-api-key")
  }

  func test_deprecatedInitApiKey_willThrowUnavailable_whenKeyBlank() async throws {
    // given
    let api = PortalDelegationsApi(apiKey: "", apiHost: "api.portalhq.io", requests: self.spy)

    // when & then: a blank key resolves as no credential at all, before the request is built
    await XCTAssertThrowsAsync(try await api.getStatus(request: .stub()), expected: PortalCredentialError.unavailable)
    XCTAssertEqual(self.spy.executeCallsCount, 0)
  }
}

// MARK: - Per-request resolution

extension PortalDelegationsApiCredentialsTests {
  func test_getStatus_willResolveTokenOnEveryRequest() async throws {
    // given
    let api = try self.api()

    // when
    _ = try await api.getStatus(request: .stub())
    _ = try await api.getStatus(request: .stub())

    // then
    XCTAssertEqual(self.credentials.getTokenCalls, 2, "The credential must be resolved again for every request.")
    XCTAssertEqual(self.spy.executeCallsCount, 2)
  }

  func test_getStatus_willSendRotatedTokenWithoutRebuild() async throws {
    // given
    let api = try self.api()

    // when
    _ = try await api.getStatus(request: .stub())
    self.credentials.tokenValue = "second-token"
    _ = try await api.getStatus(request: .stub())

    // then
    XCTAssertEqual(self.spy.bearerTokensSent, ["first-token", "second-token"])
  }

  func test_getStatus_willThrowProviderFailure_withoutRequest() async throws {
    // given
    let api = try self.api()
    self.credentials.onGetToken = { throw NSError(domain: "host.provider", code: 7) }

    // when & then
    await XCTAssertThrowsAsync(
      try await api.getStatus(request: .stub()),
      expected: PortalCredentialError.providerFailure(underlying: NSError(domain: "any", code: 0))
    )
    XCTAssertEqual(self.spy.executeCallsCount, 0)
  }

  func test_getStatus_willThrowUnavailable_whenTokenBlank() async throws {
    // given
    let api = try self.api()
    self.credentials.tokenValue = ""

    // when & then
    await XCTAssertThrowsAsync(try await api.getStatus(request: .stub()), expected: PortalCredentialError.unavailable)
    XCTAssertEqual(self.spy.executeCallsCount, 0)
  }

  func test_getStatus_willThrowSessionInvalidated_whenCredentialDead() async throws {
    // given
    let api = try self.api()
    self.credentials.onGetToken = { throw PortalCredentialError.sessionInvalidated }

    // when & then: the precise reason survives; it is not downgraded to a provider failure
    await XCTAssertThrowsAsync(try await api.getStatus(request: .stub()), expected: PortalCredentialError.sessionInvalidated)
    XCTAssertEqual(self.spy.executeCallsCount, 0)
  }
}

// MARK: - Every verb

extension PortalDelegationsApiCredentialsTests {
  func test_approve_willCarryResolvedBearer() async throws {
    // given
    let api = try self.api()
    self.spy.returnData = try self.encoder.encode(ApproveDelegationResponse.stub())
    let request = ApproveDelegationRequest.stub(delegateAddress: "0xdelegate", amount: "2.5")

    // when
    _ = try await api.approve(request: request)

    // then
    let recorded = self.spy.executeRequestHistory.last
    XCTAssertEqual(recorded?.method, .post)
    XCTAssertTrue(self.lastRequestUrl?.hasSuffix("/approvals") ?? false, "approve() must POST to the approvals path.")
    XCTAssertEqual(self.lastAuthorizationHeader, "Bearer first-token")

    // The body struct is private to the SDK, so its fields are read reflectively rather than
    // by decoding into a type the test cannot name.
    let payload = try XCTUnwrap(recorded?.payload)
    var fields: [String: String] = [:]
    for child in Mirror(reflecting: payload).children {
      if let label = child.label, let value = child.value as? String {
        fields[label] = value
      }
    }
    XCTAssertEqual(fields["delegateAddress"], "0xdelegate", "The payload must reach the wire intact.")
    XCTAssertEqual(fields["amount"], "2.5")
  }

  func test_revoke_willCarryResolvedBearer() async throws {
    // given
    let api = try self.api()
    self.spy.returnData = try self.encoder.encode(RevokeDelegationResponse.stub())

    // when
    _ = try await api.revoke(request: .stub())

    // then
    XCTAssertEqual(self.spy.executeRequestHistory.last?.method, .post)
    XCTAssertTrue(self.lastRequestUrl?.hasSuffix("/revocations") ?? false, "revoke() must POST to the revocations path.")
    XCTAssertEqual(self.lastAuthorizationHeader, "Bearer first-token")
  }

  func test_transferFrom_willCarryResolvedBearer() async throws {
    // given
    let api = try self.api()
    self.spy.returnData = try self.encoder.encode(TransferFromResponse.stub())

    // when
    _ = try await api.transferFrom(request: .stub())

    // then
    XCTAssertEqual(self.spy.executeRequestHistory.last?.method, .post)
    XCTAssertTrue(self.lastRequestUrl?.hasSuffix("/delegations/transfers") ?? false, "transferFrom() must POST to the transfers path.")
    XCTAssertEqual(self.lastAuthorizationHeader, "Bearer first-token")
  }

  func test_allMethods_willNotSendRequest_whenCredentialFails() async throws {
    // given
    let api = try self.api()
    self.credentials.onGetToken = { throw NSError(domain: "host.provider", code: 7) }

    // when & then
    await XCTAssertThrowsAsync(try await api.approve(request: .stub())) { error in
      XCTAssertTrue(error is PortalCredentialError, "approve threw a \(type(of: error)).")
    }
    await XCTAssertThrowsAsync(try await api.revoke(request: .stub())) { error in
      XCTAssertTrue(error is PortalCredentialError, "revoke threw a \(type(of: error)).")
    }
    await XCTAssertThrowsAsync(try await api.getStatus(request: .stub())) { error in
      XCTAssertTrue(error is PortalCredentialError, "getStatus threw a \(type(of: error)).")
    }
    await XCTAssertThrowsAsync(try await api.transferFrom(request: .stub())) { error in
      XCTAssertTrue(error is PortalCredentialError, "transferFrom threw a \(type(of: error)).")
    }
    XCTAssertEqual(self.spy.executeCallsCount, 0)
  }

  func test_allMethods_willResolveTokenAfterUrlValidation() async throws {
    // given
    XCTAssertNil(
      URL(string: "https://\(Self.unparsableApiHost)/api/v3/clients/me"),
      "The fixture must actually be unparsable for this ordering test to mean anything."
    )
    let credentials = MockCredentials(tokenValue: "first-token")
    let api = PortalDelegationsApi(credentials: credentials, apiHost: Self.unparsableApiHost, requests: self.spy)

    // when & then: local validation runs first, so the credential is never consulted
    await XCTAssertThrowsAsync(try await api.approve(request: .stub())) { self.assertBadUrl($0, "approve") }
    await XCTAssertThrowsAsync(try await api.revoke(request: .stub())) { self.assertBadUrl($0, "revoke") }
    await XCTAssertThrowsAsync(try await api.getStatus(request: .stub())) { self.assertBadUrl($0, "getStatus") }
    await XCTAssertThrowsAsync(try await api.transferFrom(request: .stub())) { self.assertBadUrl($0, "transferFrom") }
    XCTAssertEqual(credentials.getTokenCalls, 0, "No credential access before local validation.")
    XCTAssertEqual(self.spy.executeCallsCount, 0)
  }
}

// MARK: - Host registration

extension PortalDelegationsApiCredentialsTests {
  func test_init_willRegisterApiHost_soA401OnACustomHostReachesTheHook_andTheTraceHeaderIsSent() async throws {
    // given: an integrator who fronts Portal through their own domain and builds the sub-API on
    // its own, with its own transport. The 401 hook and the trace header are both gated on the
    // host being Portal-owned, so a custom host nobody registered would silently get neither —
    // and the hook this init installs could never fire.
    let credentials = MockCredentials(tokenValue: "first-token")
    let recorder = InvalidationListenerRecorder(credentials: credentials)
    MockURLProtocol.respond(status: 401, body: "{\"message\":\"unauthorized\"}")
    let transport = PortalRequests(urlSession: MockURLProtocol.makeSession())
    XCTAssertFalse(isPortalOwnedUrl("https://\(Self.customApiHost)/api/v3/clients/me"), "Precondition: not a Portal host until configured")

    // when
    let api = PortalDelegationsApi(credentials: credentials, apiHost: Self.customApiHost, requests: transport)
    await XCTAssertThrowsAsync(try await api.getStatus(request: .stub()), expected: PortalRequestsError.unauthorized)

    // then
    XCTAssertTrue(isPortalOwnedUrl("https://\(Self.customApiHost)/api/v3/clients/me"), "Constructing the API registers its host")
    XCTAssertEqual(credentials.invalidateCalls, 1, "A 401 from the host this API was configured against ends the session.")
    let delivered = await waitUntil { recorder.deliveries == 1 }
    XCTAssertTrue(delivered, "The host must be told the session ended.")
    XCTAssertEqual(MockURLProtocol.recordedRequests.count, 1)
    let request = try XCTUnwrap(MockURLProtocol.lastRequest)
    XCTAssertEqual(request.url?.host, Self.customApiHost)
    XCTAssertNotNil(request.value(forHTTPHeaderField: PORTAL_TRACE_ID_HEADER), "The trace header goes to the configured host, as it did before hosts were classified.")
  }

  func test_init_everyIntegrationApi_willRegisterItsApiHost() {
    // The eight sub-APIs share the init shape, and each has to register on its own: nothing else
    // knows the host a standalone one was built against.
    let credentials = MockCredentials(tokenValue: "first-token")
    let hosts = (1 ... 8).map { "api\($0).custodian.example" }
    for host in hosts {
      XCTAssertFalse(isPortalOwnedUrl("https://\(host)/x"), "Precondition: \(host) is not a Portal host until configured")
    }

    _ = PortalBlockaidApi(credentials: credentials, apiHost: hosts[0], requests: self.spy)
    _ = PortalDelegationsApi(credentials: credentials, apiHost: hosts[1], requests: self.spy)
    _ = PortalEvmAccountTypeApi(credentials: credentials, apiHost: hosts[2], requests: self.spy)
    _ = PortalHypernativeApi(credentials: credentials, apiHost: hosts[3], requests: self.spy)
    _ = PortalLifiTradingApi(credentials: credentials, apiHost: hosts[4], requests: self.spy)
    _ = PortalNoahApi(credentials: credentials, apiHost: hosts[5], requests: self.spy)
    _ = PortalYieldXyzApi(credentials: credentials, apiHost: hosts[6], requests: self.spy)
    _ = PortalZeroXTradingApi(credentials: credentials, apiHost: hosts[7], requests: self.spy)

    for host in hosts {
      XCTAssertTrue(isPortalOwnedUrl("https://\(host)/x"), "\(host) must be registered by the API built against it")
    }
    XCTAssertFalse(isPortalOwnedUrl("https://rpc.api1.custodian.example/x"), "Exactly, not as a suffix")
    XCTAssertEqual(credentials.getTokenCalls, 0, "Registration does not touch the credential")
  }
}
