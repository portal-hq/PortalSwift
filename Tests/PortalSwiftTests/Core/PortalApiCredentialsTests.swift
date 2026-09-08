//
//  PortalApiCredentialsTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import AnyCodable
import Foundation
@testable import PortalSwift
import XCTest

/// Covers `PortalApi`'s half of the credentials contract: the credential is resolved once per
/// request and never at construction, every endpoint (async and the legacy synchronous one)
/// carries the value resolved for that call, a rotated token is sent without rebuilding the
/// instance, a credential failure fails the call before anything reaches the wire, the eight
/// lazy sub-APIs share the one credential instance, and a `401` from a Portal host invalidates
/// the credential and tells the host exactly once.
///
/// The transport is a `PortalRequestsSpy` for the recording cases and the real
/// `PortalRequests(urlSession:)` driven by `MockURLProtocol` for the end-to-end `401` cases, so
/// the hook path is exercised through the code that actually fires it rather than through a
/// double that simulates it. The legacy `storedClientBackupShare` path is driven through the
/// `httpRequests` seam with a stub that completes synchronously, which is what makes the
/// "reported before the caller sees the error" ordering observable.
///
/// The invalidation registry is reset around every case (its once-ever "reported" flags would
/// otherwise leak into the next test) and the logger sink is recorded at `.debug` so the
/// secret-leak assertions are real rather than vacuous.
final class PortalApiCredentialsTests: XCTestCase {
  private var credentials = MockCredentials(tokenValue: "first-token")
  private var spy = PortalRequestsSpy()
  private var httpStub = StubHttpRequester(baseUrl: "https://\(MockConstants.mockHost)")
  private var api: PortalApi?
  private var logger = RecordingLogger()
  private var previousLogLevel: PortalLogLevel = .none
  private let encoder = JSONEncoder()

  override func setUpWithError() throws {
    try super.setUpWithError()
    CredentialInvalidationRegistry.shared.resetForTesting()
    PortalOwnedHosts.resetForTesting()
    MockURLProtocol.reset()

    self.previousLogLevel = PortalLogger.shared.logLevel
    PortalLogger.shared.setLogLevel(.debug)
    self.logger = RecordingLogger()
    self.logger.install()

    self.credentials = MockCredentials(tokenValue: "first-token")
    self.spy = PortalRequestsSpy()
    self.spy.returnData = try self.encoder.encode(MockConstants.mockClient)
    self.httpStub = StubHttpRequester(baseUrl: "https://\(MockConstants.mockHost)")
    self.api = PortalApi(
      credentials: self.credentials,
      apiHost: MockConstants.mockHost,
      requests: self.spy,
      httpRequests: self.httpStub
    )
  }

  override func tearDownWithError() throws {
    self.api = nil
    self.logger.uninstall()
    PortalLogger.shared.setLogLevel(self.previousLogLevel)
    MockURLProtocol.reset()
    CredentialInvalidationRegistry.shared.resetForTesting()
    PortalOwnedHosts.resetForTesting()
    try super.tearDownWithError()
  }

  // MARK: - Helpers

  /// The `PortalApi` under test, or a failed assertion when `setUp` did not produce one.
  private func sut(file: StaticString = #filePath, line: UInt = #line) throws -> PortalApi {
    guard let api = self.api else {
      XCTFail("The PortalApi under test was not constructed.", file: file, line: line)
      throw XCTSkip("No PortalApi under test.")
    }
    return api
  }

  /// The `Authorization` header of every request the spy recorded, in call order.
  private var recordedAuthorizationHeaders: [String?] {
    self.spy.executeRequestHistory.map { $0.headers["Authorization"] }
  }

  /// A lock-guarded counter for hooks and completions that run off the test's own thread.
  private final class LockedCounter {
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

  /// One `PortalApi` endpoint, named so a failure says which call site sent the wrong bearer.
  private struct Endpoint {
    let name: String
    let call: () async throws -> Void
  }

  /// Every `PortalApi` call site that resolves the credential, one call each, in a fixed order.
  ///
  /// The bodies the spy returns do not match most of these response types, so most calls are
  /// expected to fail while decoding — deliberately: what is under test is that the request was
  /// built with a freshly resolved bearer, which the spy records before it decodes anything.
  private func credentialResolvingEndpoints(on api: PortalApi) -> [Endpoint] {
    var endpoints: [Endpoint] = []
    endpoints.append(Endpoint(name: "getClient") { _ = try await api.getClient() })
    endpoints.append(Endpoint(name: "getBalances") { _ = try await api.getBalances("eip155:1") })
    endpoints.append(Endpoint(name: "getAssets") { _ = try await api.getAssets("eip155:1") })
    endpoints.append(Endpoint(name: "getNftAssets") { _ = try await api.getNftAssets("eip155:1") })
    endpoints.append(Endpoint(name: "getSharePairs") { _ = try await api.getSharePairs(.signing, walletId: "wallet-id") })
    endpoints.append(Endpoint(name: "getTransactions") { _ = try await api.getTransactions("eip155:1", limit: nil, offset: nil, order: nil) })
    endpoints.append(Endpoint(name: "getTransactionDetails") { _ = try await api.getTransactionDetails(chain: "eip155:1", signature: "0xsignature") })
    endpoints.append(Endpoint(name: "getClientCipherText") { _ = try await api.getClientCipherText("backup-share-pair-id", traceId: nil) })
    endpoints.append(Endpoint(name: "getQuote") { _ = try await api.getQuote("swaps-key", withArgs: QuoteArgs(buyToken: "USDC", sellToken: "ETH", sellAmount: "1"), forChainId: "eip155:1") })
    endpoints.append(Endpoint(name: "getSources") { _ = try await api.getSources("swaps-key", forChainId: "eip155:1") })
    endpoints.append(Endpoint(name: "identify") { _ = try await api.identify([:]) })
    endpoints.append(Endpoint(name: "track") { _ = try await api.track("Test Event", withProperties: [:]) })
    endpoints.append(Endpoint(name: "prepareEject") { _ = try await api.prepareEject("wallet-id", .GoogleDrive, traceId: nil) })
    endpoints.append(Endpoint(name: "eject") { _ = try await api.eject(traceId: nil) })
    endpoints.append(Endpoint(name: "updateShareStatus") { try await api.updateShareStatus(.backup, status: .STORED_CLIENT_BACKUP_SHARE, sharePairIds: ["share-pair-id"], traceId: nil) })
    endpoints.append(Endpoint(name: "fund") { _ = try await api.fund(chainId: "eip155:1", params: FundParams(amount: "1", token: "USDC")) })
    endpoints.append(Endpoint(name: "evaluateTransaction") { _ = try await api.evaluateTransaction(chainId: "eip155:1", transaction: Self.evaluateTransactionParam, operationType: nil) })
    endpoints.append(Endpoint(name: "buildEip155Transaction") { _ = try await api.buildEip155Transaction(chainId: "eip155:1", params: BuildTransactionParam.stub(), traceId: nil) })
    endpoints.append(Endpoint(name: "buildSolanaTransaction") { _ = try await api.buildSolanaTransaction(chainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d", params: BuildTransactionParam.stub(), traceId: nil) })
    endpoints.append(Endpoint(name: "buildBitcoinP2wpkhTransaction") { _ = try await api.buildBitcoinP2wpkhTransaction(chainId: "bip122:000000000019d6689c085ae165831e93", params: BuildTransactionParam.stub(), traceId: nil) })
    endpoints.append(Endpoint(name: "broadcastBitcoinP2wpkhTransaction") { _ = try await api.broadcastBitcoinP2wpkhTransaction(chainId: "bip122:000000000019d6689c085ae165831e93", params: BroadcastParam(signatures: ["0xsig"], rawTxHex: "0xraw"), traceId: nil) })
    endpoints.append(Endpoint(name: "getWalletCapabilities") { _ = try await api.getWalletCapabilities(traceId: nil) })
    endpoints.append(Endpoint(name: "simulateTransaction") { _ = try await api.simulateTransaction(["to": "0xrecipient"], withChainId: "eip155:1") })
    endpoints.append(Endpoint(name: "generatePreGeneratedShares") { _ = try await api.generatePreGeneratedShares(metadataStr: "{}", traceId: nil) })
    endpoints.append(Endpoint(name: "storeClientCipherText") { _ = try await api.storeClientCipherText("backup-share-pair-id", cipherText: "cipher-text", traceId: nil) })
    return endpoints
  }

  /// A minimal transaction for `evaluateTransaction`; only its presence matters here.
  private static var evaluateTransactionParam: EvaluateTransactionParam {
    EvaluateTransactionParam(
      to: "0xrecipient",
      value: nil,
      data: nil,
      maxFeePerGas: nil,
      maxPriorityFeePerGas: nil,
      gas: nil,
      gasPrice: nil
    )
  }
}

// MARK: - Construction

extension PortalApiCredentialsTests {
  func test_init_willNotResolveCredentialAtConstruction() throws {
    // given & when: setUp constructed the PortalApi

    // then
    XCTAssertEqual(self.credentials.getTokenCalls, 0, "Constructing a PortalApi must not touch the credential.")
  }

  func test_deprecatedInitApiKey_willStillAuthenticate() async throws {
    // given
    let api = PortalApi(apiKey: "client-api-key", apiHost: MockConstants.mockHost, requests: self.spy)

    // when
    _ = try await api.getClient()

    // then
    XCTAssertEqual(self.recordedAuthorizationHeaders, ["Bearer client-api-key"])
    XCTAssertTrue(api.credentials is StaticCredentials, "The deprecated initializer must wrap the key in StaticCredentials.")
    XCTAssertEqual((api.credentials as? StaticCredentials)?.value, "client-api-key")
  }
}

// MARK: - Per-request resolution

extension PortalApiCredentialsTests {
  func test_getClient_willResolveCredentialPerRequest() async throws {
    // given
    let api = try self.sut()

    // when
    _ = try await api.getClient()
    _ = try await api.getClient()

    // then
    XCTAssertEqual(self.credentials.getTokenCalls, 2, "The credential must be resolved again for every request.")
    XCTAssertEqual(self.recordedAuthorizationHeaders, ["Bearer first-token", "Bearer first-token"])
  }

  func test_getClient_willSendRotatedTokenWithoutRebuild() async throws {
    // given
    let api = try self.sut()

    // when
    _ = try await api.getClient()
    self.credentials.tokenValue = "second-token"
    _ = try await api.getClient()

    // then
    XCTAssertEqual(self.spy.bearerTokensSent, ["first-token", "second-token"])
  }

  func test_getClient_willThrowProviderFailure_withoutMakingRequest() async throws {
    // given
    let api = try self.sut()
    self.credentials.onGetToken = { throw NSError(domain: "host.provider", code: 7) }

    // when & then
    await XCTAssertThrowsAsync(try await api.getClient(), expected: PortalCredentialError.providerFailure(underlying: NSError(domain: "any", code: 0)))
    XCTAssertEqual(self.spy.executeCallsCount, 0, "A credential failure must fail before the request is sent.")
  }

  func test_getClient_willThrowSessionInvalidated_withoutMakingRequest() async throws {
    // given
    let api = try self.sut()
    self.credentials.onGetToken = { throw PortalCredentialError.sessionInvalidated }

    // when & then
    await XCTAssertThrowsAsync(try await api.getClient(), expected: PortalCredentialError.sessionInvalidated)
    XCTAssertEqual(self.spy.executeCallsCount, 0)
  }

  func test_getClient_willThrowUnavailable_whenTokenBlank() async throws {
    // given
    let api = try self.sut()
    self.credentials.tokenValue = ""

    // when & then
    await XCTAssertThrowsAsync(try await api.getClient(), expected: PortalCredentialError.unavailable)
    XCTAssertEqual(self.spy.executeCallsCount, 0, "A blank token must fail before the request is sent.")
  }

  func test_everyAsyncEndpoint_willCarryResolvedBearer() async throws {
    // given
    let api = try self.sut()
    let endpoints = self.credentialResolvingEndpoints(on: api)
    XCTAssertEqual(endpoints.count, 25, "Every credential-resolving call site must be exercised.")

    // when
    for endpoint in endpoints {
      _ = try? await endpoint.call()
    }

    // then
    XCTAssertEqual(self.spy.executeCallsCount, endpoints.count, "Every endpoint must reach the transport exactly once.")
    XCTAssertEqual(self.credentials.getTokenCalls, endpoints.count, "Every endpoint must resolve the credential exactly once.")
    for (index, header) in self.recordedAuthorizationHeaders.enumerated() {
      XCTAssertEqual(header, "Bearer first-token", "\(endpoints[index].name) sent the wrong bearer.")
    }
  }

  func test_everyAsyncEndpoint_willNotSendRequest_whenCredentialFails() async throws {
    // given
    let api = try self.sut()
    self.credentials.onGetToken = { throw NSError(domain: "host.provider", code: 7) }
    let endpoints = self.credentialResolvingEndpoints(on: api)

    // when & then
    for endpoint in endpoints {
      do {
        try await endpoint.call()
        XCTFail("\(endpoint.name) returned normally with a failing credential.")
      } catch {
        XCTAssertTrue(error is PortalCredentialError, "\(endpoint.name) threw a \(type(of: error)) instead of a PortalCredentialError.")
      }
    }
    XCTAssertEqual(self.spy.executeCallsCount, 0, "No endpoint may reach the transport with a failing credential.")
  }
}

// MARK: - Analytics

extension PortalApiCredentialsTests {
  func test_identify_willCarrySessionToken() async throws {
    // given
    let api = try self.sut()
    self.spy.returnData = try self.encoder.encode(MetricsResponse(status: true))
    self.credentials.tokenValue = "session-token"

    // when
    _ = try await api.identify([:])

    // then
    let request = self.spy.executeRequestHistory.last
    XCTAssertEqual(request?.method, .post)
    XCTAssertEqual(request?.url.absoluteString, "https://\(MockConstants.mockHost)/api/v1/analytics/identify")
    XCTAssertEqual(request?.headers["Authorization"], "Bearer session-token")
  }

  func test_track_willCarrySessionToken() async throws {
    // given
    let api = try self.sut()
    self.spy.returnData = try self.encoder.encode(MetricsResponse(status: true))
    self.credentials.tokenValue = "session-token"

    // when
    _ = try await api.track("Test Event", withProperties: [:])

    // then
    let request = self.spy.executeRequestHistory.last
    XCTAssertEqual(request?.method, .post)
    XCTAssertEqual(request?.url.absoluteString, "https://\(MockConstants.mockHost)/api/v1/analytics/track")
    XCTAssertEqual(request?.headers["Authorization"], "Bearer session-token")
  }

  func test_track_willNotSwallowCredentialError() async throws {
    // given
    let api = try self.sut()
    self.credentials.onGetToken = { throw PortalCredentialError.sessionInvalidated }

    // when & then: analytics must not downgrade a credential failure into a silent metrics miss
    await XCTAssertThrowsAsync(try await api.track("Test Event", withProperties: [:]), expected: PortalCredentialError.sessionInvalidated)
    XCTAssertEqual(self.spy.executeCallsCount, 0)
  }
}

// MARK: - Unauthorized hook installation

extension PortalApiCredentialsTests {
  func test_initCredentials_willInstallUnauthorizedHook_whenTransportHasNone() throws {
    // given
    let transport = PortalRequests(urlSession: MockURLProtocol.makeSession())
    XCTAssertTrue(transport.onUnauthorized == nil)
    let credentials = MockCredentials(tokenValue: "first-token")

    // when
    let api = PortalApi(credentials: credentials, apiHost: "api.portalhq.io", requests: transport)

    // then
    XCTAssertTrue(api.credentials === credentials)
    XCTAssertTrue(transport.onUnauthorized != nil, "PortalApi must wire the 401 hook onto a transport that has none.")
    transport.onUnauthorized?(nil)
    XCTAssertEqual(credentials.invalidateCalls, 1)
  }

  func test_initCredentials_willNotOverwriteExistingHook() throws {
    // given
    let presetInvocations = LockedCounter()
    let transport = PortalRequestsSpy()
    transport.onUnauthorized = { _ in presetInvocations.increment() }
    let credentials = MockCredentials(tokenValue: "first-token")

    // when
    let api = PortalApi(credentials: credentials, apiHost: MockConstants.mockHost, requests: transport)
    transport.onUnauthorized?(nil)

    // then
    XCTAssertTrue(api.credentials === credentials)
    XCTAssertEqual(transport.onUnauthorizedSetCount, 1, "An already-wired hook must be left alone.")
    XCTAssertEqual(presetInvocations.value, 1)
    XCTAssertEqual(credentials.invalidateCalls, 0)
  }

  func test_unauthorizedHook_willReportNotOnlyInvalidate() async throws {
    // given
    _ = try self.sut()
    let recorder = InvalidationListenerRecorder(credentials: self.credentials)

    // when
    self.spy.onUnauthorized?(nil)

    // then
    XCTAssertEqual(self.credentials.invalidateCalls, 1)
    let delivered = await waitUntil { recorder.deliveries == 1 }
    XCTAssertTrue(delivered, "The dead session must be reported to the host, not only invalidated.")
    XCTAssertEqual(recorder.deliveries, 1)
  }
}

// MARK: - End-to-end 401

extension PortalApiCredentialsTests {
  func test_getClient_willRethrowUnauthorizedAndReport_when401ThroughRealTransport() async throws {
    // given
    let credentials = MockCredentials(tokenValue: "first-token")
    credentials.onInvalidate = { [weak credentials] in
      credentials?.onGetToken = { throw PortalCredentialError.sessionInvalidated }
    }
    MockURLProtocol.respond(status: 401, body: "{\"message\":\"unauthorized\"}")
    let transport = PortalRequests(urlSession: MockURLProtocol.makeSession())
    let api = PortalApi(credentials: credentials, apiHost: "api.portalhq.io", requests: transport)
    let recorder = InvalidationListenerRecorder(credentials: credentials)

    // when
    await XCTAssertThrowsAsync(try await api.getClient(), expected: PortalRequestsError.unauthorized)

    // then
    XCTAssertEqual(credentials.invalidateCalls, 1)
    let delivered = await waitUntil { recorder.deliveries == 1 }
    XCTAssertTrue(delivered, "The host must be told the session ended.")
    let requestsAfterFirstCall = MockURLProtocol.recordedRequests.count
    XCTAssertEqual(requestsAfterFirstCall, 1)

    // and: the Portal is spent — the next call fails at the credential, before any request
    await XCTAssertThrowsAsync(try await api.getClient(), expected: PortalCredentialError.sessionInvalidated)
    XCTAssertEqual(MockURLProtocol.recordedRequests.count, requestsAfterFirstCall)
    XCTAssertEqual(recorder.deliveries, 1, "The report happens once per credential.")
  }

  func test_getClient_willInvalidate_when401FromTheConfiguredCustomHost() async throws {
    // given: an integrator who fronts Portal through their own domain. The configured `apiHost`
    // is registered as Portal-owned at init (`PortalOwnedHosts`), otherwise every 401 from their
    // own backend would read as third-party and session invalidation would silently never fire.
    let credentials = MockCredentials(tokenValue: "first-token")
    let recorder = InvalidationListenerRecorder(credentials: credentials)
    MockURLProtocol.respond(status: 401, body: "{\"message\":\"unauthorized\"}")
    let transport = PortalRequests(urlSession: MockURLProtocol.makeSession())
    // `setUp` already built an API against this host; start from a clean registry so the
    // registration proven below is this construction's.
    PortalOwnedHosts.resetForTesting()
    XCTAssertFalse(isPortalOwnedUrl("https://\(MockConstants.mockHost)/api/v3/clients/me"), "Precondition: not a Portal host until configured")
    let api = PortalApi(credentials: credentials, apiHost: MockConstants.mockHost, requests: transport)

    // when
    await XCTAssertThrowsAsync(try await api.getClient(), expected: PortalRequestsError.unauthorized)

    // then
    XCTAssertTrue(isPortalOwnedUrl("https://\(MockConstants.mockHost)/api/v3/clients/me"), "Constructing the API registers its host")
    XCTAssertEqual(credentials.invalidateCalls, 1, "A 401 from the host this API was configured against ends the session.")
    let delivered = await waitUntil { recorder.deliveries == 1 }
    XCTAssertTrue(delivered, "The host must be told the session ended.")
    XCTAssertEqual(MockURLProtocol.recordedRequests.count, 1)
  }
}

// MARK: - Synchronous storedClientBackupShare path

extension PortalApiCredentialsTests {
  func test_storedClientBackupShare_willResolveTokenIntoAuthorizationHeader() throws {
    // given
    let api = try self.sut()
    self.httpStub.stringToReturn = "OK"
    var observedHeaders: [String: String] = [:]
    var observedGetTokenCalls = -1
    var completed = false

    // when
    try api.storedClientBackupShare(success: true, backupMethod: BackupMethods.GoogleDrive.rawValue) { [self] _ in
      observedHeaders = self.httpStub.lastHeaders
      observedGetTokenCalls = self.credentials.getTokenCalls
      completed = true
    }

    // then
    XCTAssertTrue(completed, "The stub transport completes synchronously.")
    XCTAssertEqual(self.httpStub.putCallsCount, 1)
    XCTAssertEqual(observedHeaders["Authorization"], "Bearer first-token")
    XCTAssertNotNil(observedHeaders[PORTAL_TRACE_ID_HEADER], "The Portal-owned legacy path still carries a trace id.")
    XCTAssertEqual(observedGetTokenCalls, 1, "The synchronous path resolves the credential exactly once.")
  }

  func test_storedClientBackupShare_willThrowProviderFailure_beforeRequest() throws {
    // given
    let api = try self.sut()
    self.credentials.onGetToken = { throw NSError(domain: "host.provider", code: 7) }

    // when & then
    XCTAssertThrowsError(
      try api.storedClientBackupShare(success: true, backupMethod: BackupMethods.GoogleDrive.rawValue) { _ in
        XCTFail("The completion must not run when the credential failed.")
      }
    ) { error in
      XCTAssertEqual(error as? PortalCredentialError, .providerFailure(underlying: NSError(domain: "any", code: 0)))
    }
    XCTAssertEqual(self.httpStub.putCallsCount, 0, "The legacy transport must not be called with a failed credential.")
  }

  func test_storedClientBackupShare_willReportUnauthorized_when401() async throws {
    // given
    let api = try self.sut()
    let recorder = InvalidationListenerRecorder(credentials: self.credentials)
    self.httpStub.errorToReturn = HttpError.unauthorized("401 - Unauthorized")
    var observedError: Error?
    var observedInvalidateCalls = -1

    // when
    try api.storedClientBackupShare(success: true, backupMethod: BackupMethods.GoogleDrive.rawValue) { [self] result in
      observedError = result.error
      observedInvalidateCalls = self.credentials.invalidateCalls
    }

    // then
    XCTAssertEqual(observedError as? HttpError, .unauthorized("401 - Unauthorized"))
    XCTAssertEqual(observedInvalidateCalls, 1, "The credential must already be invalidated when the caller sees the 401.")
    let delivered = await waitUntil { recorder.deliveries == 1 }
    XCTAssertTrue(delivered, "The synchronous path reports the dead session too.")
  }

  func test_storedClientBackupShare_willSurfaceOriginal401_whenInvalidationFails() throws {
    // given
    let api = try self.sut()
    self.credentials.onInvalidate = { throw NSError(domain: "keychain", code: -25300) }
    self.httpStub.errorToReturn = HttpError.unauthorized("401 - Unauthorized")
    var observedError: Error?

    // when
    try api.storedClientBackupShare(success: true, backupMethod: BackupMethods.GoogleDrive.rawValue) { result in
      observedError = result.error
    }

    // then: the report is bookkeeping, never the outcome the caller sees
    XCTAssertEqual(observedError as? HttpError, .unauthorized("401 - Unauthorized"))
    if case let .unauthorized(message)? = observedError as? HttpError {
      XCTAssertTrue(message.contains("401"), "The caller must still see the original 401.")
    } else {
      XCTFail("Expected the original HttpError.unauthorized, got \(String(describing: observedError.map { type(of: $0) })).")
    }
    XCTAssertEqual(self.credentials.invalidateCalls, 1)
  }

  func test_storedClientBackupShare_willNotInvalidate_onNon401() throws {
    // given
    let api = try self.sut()
    self.httpStub.errorToReturn = HttpError.internalServerError("500 - Server Error")
    var observedError: Error?
    var observedInvalidateCalls = -1

    // when
    try api.storedClientBackupShare(success: true, backupMethod: BackupMethods.GoogleDrive.rawValue) { [self] result in
      observedError = result.error
      observedInvalidateCalls = self.credentials.invalidateCalls
    }

    // then
    XCTAssertEqual(observedError as? HttpError, .internalServerError("500 - Server Error"))
    XCTAssertEqual(observedInvalidateCalls, 0, "Only a 401 says the credential was rejected.")
  }

  func test_storedClientBackupShare_willNotInvalidate_onSuccess() async throws {
    // given
    let api = try self.sut()
    self.httpStub.stringToReturn = "OK"
    var observedResult: String?
    var observedInvalidateCalls = -1

    // when
    try api.storedClientBackupShare(success: true, backupMethod: BackupMethods.GoogleDrive.rawValue) { [self] result in
      observedResult = result.data
      observedInvalidateCalls = self.credentials.invalidateCalls
    }

    // then
    XCTAssertEqual(observedResult, "OK")
    XCTAssertEqual(observedInvalidateCalls, 0)

    // and: the fire-and-forget metrics call that follows still resolves a bearer of its own
    let trackUrl = "https://\(MockConstants.mockHost)/api/v1/analytics/track"
    let tracked = await waitUntil { self.spy.executeRequestHistory.contains { $0.url.absoluteString == trackUrl } }
    XCTAssertTrue(tracked, "The follow-up analytics call never reached the transport.")
    let trackRequest = self.spy.executeRequestHistory.first { $0.url.absoluteString == trackUrl }
    XCTAssertEqual(trackRequest?.headers["Authorization"], "Bearer first-token")
  }
}

// MARK: - Sub-APIs

extension PortalApiCredentialsTests {
  func test_subApis_willShareOneCredentialInstance() async throws {
    // given
    let api = try self.sut()

    // when: one call through each of the eight lazy sub-APIs
    _ = try? await api.delegations.getStatus(request: .stub())
    _ = try? await api.yieldxyz.getYieldDefaults(includeOpportunities: nil)
    _ = try? await api.lifi.getRoutes(request: .stub())
    _ = try? await api.zeroX.getSources(chainId: "eip155:1", zeroXApiKey: nil)
    _ = try? await api.hypernative.scanURL(request: .stub())
    _ = try? await api.blockaid.scanURL(request: .stub())
    _ = try? await api.evmAccountType.getStatus(chainId: "eip155:1", traceId: nil)
    _ = try? await api.noah.getPayoutCountries()

    // then
    XCTAssertEqual(self.credentials.getTokenCalls, 8, "Every sub-API must resolve the one shared credential.")
    XCTAssertEqual(self.spy.executeCallsCount, 8)
    for header in self.recordedAuthorizationHeaders {
      XCTAssertEqual(header, "Bearer first-token")
    }
  }

  func test_subApis_willObserveInvalidation_afterOne401() async throws {
    // given
    let api = try self.sut()
    self.credentials.onInvalidate = { [weak credentials = self.credentials] in
      credentials?.onGetToken = { throw PortalCredentialError.sessionInvalidated }
    }
    self.spy.simulatePortalUnauthorizedOnce = true

    // when: one endpoint sees the 401 and the credential is reported
    await XCTAssertThrowsAsync(try await api.getClient(), expected: PortalRequestsError.unauthorized)
    XCTAssertEqual(self.credentials.invalidateCalls, 1)
    let requestsAfter401 = self.spy.executeCallsCount

    // then: a sub-API built from the same credential is dead too, without a request
    await XCTAssertThrowsAsync(try await api.delegations.getStatus(request: .stub()), expected: PortalCredentialError.sessionInvalidated)
    XCTAssertEqual(self.spy.executeCallsCount, requestsAfter401, "A dead credential must fail before the request is sent.")
  }
}

// MARK: - Client cache

extension PortalApiCredentialsTests {
  func test_client_cachedValue_willNotResolveTokenOnSecondRead() async throws {
    // given
    let api = try self.sut()

    // when
    _ = try await api.client
    _ = try await api.client

    // then: the cached ClientResponse is reused, so the second read touches nothing
    XCTAssertEqual(self.credentials.getTokenCalls, 1)
    XCTAssertEqual(self.spy.executeCallsCount, 1)
  }
}

// MARK: - Security

extension PortalApiCredentialsTests {
  func test_PortalApi_willNeverLogToken() async throws {
    // given
    let secret = "SECRET-CST"
    let credentials = MockCredentials(tokenValue: secret)
    let spy = PortalRequestsSpy()
    spy.returnData = try self.encoder.encode(MockConstants.mockClient)
    let api = PortalApi(credentials: credentials, apiHost: MockConstants.mockHost, requests: spy)

    // when: the success path
    _ = try await api.getClient()

    // and: the 401 path
    spy.simulatePortalUnauthorizedOnce = true
    await XCTAssertThrowsAsync(try await api.getClient(), expected: PortalRequestsError.unauthorized)

    // and: the credential-failure path
    credentials.onGetToken = { throw NSError(domain: "host.provider", code: 7) }
    _ = try? await api.getClient()

    // then
    self.logger.assertNoSecret(secret)
    self.logger.assertNoSecret(MockConstants.mockApiKey)
  }
}

// MARK: - StubHttpRequester

/// A `MockHttpRequester` whose `put` records what the legacy synchronous path sent and completes
/// immediately with a scripted value or error.
///
/// It exists because `PortalApi.storedClientBackupShare` bypasses `PortalRequests` — and its 401
/// hook — so the only way to observe that path's own credential resolution and its own
/// `reportUnauthorizedAndLog` call is through the `httpRequests` seam. Completing synchronously
/// is deliberate: it makes "the credential was already invalidated when the caller saw the
/// error" observable from inside the completion, with no polling.
private final class StubHttpRequester: MockHttpRequester {
  private let lock = NSLock()
  private var _putCallsCount = 0
  private var _lastPath = ""
  private var _lastHeaders: [String: String] = [:]
  private var _lastBody: [String: Any] = [:]

  /// The value handed to the completion when `errorToReturn` is `nil`.
  var stringToReturn = "OK"
  /// When set, the completion receives this error instead of a value.
  var errorToReturn: Error?

  /// How many times `put` was called.
  var putCallsCount: Int {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._putCallsCount
  }

  /// The path of the most recent `put`.
  var lastPath: String {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._lastPath
  }

  /// The headers of the most recent `put`, where the resolved bearer is asserted.
  var lastHeaders: [String: String] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._lastHeaders
  }

  /// The body of the most recent `put`.
  var lastBody: [String: Any] {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self._lastBody
  }

  override func put<T: Codable>(
    path: String,
    body: [String: Any]?,
    headers: [String: String],
    requestType _: HttpRequestType,
    completion: @escaping (PortalSwift.Result<T>) -> Void
  ) throws {
    self.lock.lock()
    self._putCallsCount += 1
    self._lastPath = path
    self._lastHeaders = headers
    self._lastBody = body ?? [:]
    let error = self.errorToReturn
    let value = self.stringToReturn
    self.lock.unlock()

    if let error {
      completion(PortalSwift.Result(error: error))
      return
    }
    guard let typed = value as? T else {
      completion(PortalSwift.Result(error: StubHttpRequesterError.unsupportedResponseType))
      return
    }
    completion(PortalSwift.Result(data: typed))
  }
}

/// Raised when a test scripts a value the caller's generic response type cannot hold, so the
/// mismatch surfaces as a failed assertion rather than a silent no-op completion.
private enum StubHttpRequesterError: LocalizedError {
  case unsupportedResponseType

  var errorDescription: String? {
    switch self {
    case .unsupportedResponseType:
      return "StubHttpRequester was asked for a response type it cannot produce."
    }
  }
}
