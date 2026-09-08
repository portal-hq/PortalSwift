//
//  WebSocketClientTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import Starscream
import XCTest

// MARK: - Fixture constants

/// The session token every default fixture hands out. Also the string the security cases search
/// the emitted errors and the log sink for, so it must never appear in either.
private let wsToken = "ws-token-1"

/// The token a rotated session hands out, used to prove the client re-resolves the credential on
/// every connect instead of caching the one it saw first.
private let wsRotatedToken = "ws-token-2"

/// The production proxy address; the client is built against it so the assertions on the upgrade
/// request are the ones a real connection would make.
private let wsServer = "wss://connect.portalhq.io"

/// A server string that is syntactically a URL but whose host contains a space, which
/// `WebSocketClient.serverUrl(from:)` must reject rather than percent-encode.
private let wsMalformedServer = "wss://con nect.portalhq.io"

/// A WalletConnect URI in the shape `PortalConnect` passes down, used for every connect.
private let wsUri = "wc:test-topic@2?relay-protocol=irn&symKey=abc123"

/// The proxy's application-level answer to the connect message: the `connected` event that moves
/// the client to `.connected`. Distinct from Starscream's `.connected`, which is only the upgrade.
private let proxyConnectedMessage = """
{"event":"connected","data":{"id":"1","topic":"test-topic","params":{"active":true,"expiry":null,"peerMetadata":{"name":"dApp","description":"","url":"https://dapp.example","icons":[]},"relay":null,"topic":"test-topic"}}}
"""

// MARK: - WebSocketClientTests

/// Covers `WebSocketClient` end to end through its real Starscream socket: the per-connect
/// upgrade request, the throwing `connect(uri:)`, the terminal 401 in `handleError`, the bounded
/// reconnect budget and every delegate branch of `didReceive(event:client:)`.
///
/// The client is built on `FakeWebSocketEngine`, so a real `Starscream.WebSocket` sits between
/// the SDK and the double: what the engine records (`startRequests`, `startCallsCount`,
/// `stopCloseCodes`, `writtenStrings`) is exactly what would have gone on the wire, which is the
/// only way to assert that the bearer travels in the `Authorization` header of every connect and
/// never in the URL. Inbound events are pushed straight into `didReceive(event:client:)` with a
/// `FakeStarscreamClient`, because the socket's own callback hop is asynchronous and would turn
/// every branch assertion into a poll.
///
/// Time is injected: `RecordingSleeper` turns "0.5 s, 1 s, 2 s, 4 s, 8 s" into an array equality
/// and can hold a reconnect inside its delay so a second drop can be raced against it. The
/// credential is a `MockPortalSession` (a session, not a Client API Key) so the once-only host
/// notification is observable through `InvalidationListenerRecorder`, and the registry is reset
/// around every case because its reported flags are process-wide. The logger sink is recorded so
/// the "never logs the token" case is a real assertion rather than a hope.
final class WebSocketClientTests: XCTestCase {
  /// Everything one client needs, kept together so a case can build a second client (different
  /// credential, different server) without repeating five constructions.
  private struct Fixture {
    let credentials: PortalCredentials
    /// Held strongly for the life of the case: `PortalProvider` keeps only a `weak` reference to
    /// the keychain, so a keychain owned solely by `makeFixture` would be deallocated on return
    /// and `connect.address` would silently read `nil` — which is exactly the guard
    /// `handleConnect()` bails out on, making the connect frame disappear.
    let keychain: PortalKeychainProtocol
    let connect: PortalConnect
    let engine: FakeWebSocketEngine
    let sleeper: RecordingSleeper
    let client: PortalSwift.WebSocketClient
    let errors: ConnectErrorRecorder
  }

  /// Records every `ConnectError` the client emits on its `error` event.
  ///
  /// Lock-guarded because a reconnect failure is emitted from the reconnect `Task`'s thread
  /// while the test asserts from its own.
  private final class ConnectErrorRecorder {
    private let lock = NSLock()
    private var _errors: [ConnectError] = []

    /// Every emitted error, in emission order.
    var errors: [ConnectError] {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._errors
    }

    /// How many errors were emitted.
    var count: Int {
      self.errors.count
    }

    /// The most recently emitted error, if any.
    var last: ConnectError? {
      self.errors.last
    }

    /// The messages of every emitted error, for the security cases.
    var messages: [String] {
      self.errors.map(\.message)
    }

    /// Subscribes to `client`'s `error` event. The client retains the handler, so the recorder
    /// is captured weakly.
    func observe(_ client: PortalSwift.WebSocketClient) {
      client.on("error") { [weak self] (error: ConnectError) in
        self?.record(error)
      }
    }

    private func record(_ error: ConnectError) {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._errors.append(error)
    }
  }

  /// Records, per emitted event, whether the handler ran on the main thread.
  private final class ThreadRecorder {
    private let lock = NSLock()
    private var _onMainThread: [Bool] = []

    var onMainThread: [Bool] {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._onMainThread
    }

    var count: Int {
      self.onMainThread.count
    }

    func record() {
      let isMain = Thread.isMainThread
      self.lock.lock()
      defer { self.lock.unlock() }
      self._onMainThread.append(isMain)
    }
  }

  /// A keychain that has no address, which is what `handleConnect()`'s guard is written for.
  ///
  /// `PortalProvider.address` maps a throwing `getAddress()` to `nil`, and `MockPortalKeychain`
  /// always returns an address, so throwing here is the only way to reach the guard. Subclassed
  /// rather than added to the shared mock so no other test's `PortalConnect` changes shape.
  private final class AddresslessKeychain: MockPortalKeychain {
    /// The failure a keychain reports when the wallet has never been generated on this device.
    struct NoAddressError: Error {}

    override public func getAddress() throws -> String {
      throw NoAddressError()
    }
  }

  private var session = MockPortalSession(tokenValue: wsToken)
  private var logger = RecordingLogger()
  private var fixture: Fixture?
  private var recorder: InvalidationListenerRecorder?

  /// Every fixture built during a case, so `tearDown` can settle each client in `.disconnected`
  /// (the `deinit` assertion) and stop its ping timer before the objects are released.
  private var fixtures: [Fixture] = []

  override func setUpWithError() throws {
    try super.setUpWithError()

    CredentialInvalidationRegistry.shared.resetForTesting()
    self.logger = RecordingLogger()
    self.logger.install()

    self.session = MockPortalSession(tokenValue: wsToken)
    let fixture = try self.makeFixture(credentials: self.session)
    self.fixture = fixture
    self.recorder = InvalidationListenerRecorder(credentials: self.session)
  }

  override func tearDownWithError() throws {
    for fixture in self.fixtures {
      // The client asserts in `deinit` that it is not connected, and a scheduled ping timer
      // would otherwise outlive the test on the main run loop.
      fixture.client.connectState = .disconnected
      fixture.client.pingTimer?.invalidate()
      // Wake anything still parked inside an injected delay so no reconnect task leaks forward.
      fixture.sleeper.release()
    }
    self.fixtures = []
    self.fixture = nil
    self.recorder = nil

    self.logger.uninstall()
    CredentialInvalidationRegistry.shared.resetForTesting()
    try super.tearDownWithError()
  }

  // MARK: - Helpers

  /// The `PortalConnect` a client is built for. Sepolia and the mock RPC config, matching the
  /// rest of the suite; the keychain decides whether `connect.address` resolves.
  private func makeConnect(
    credentials: PortalCredentials,
    keychain: PortalKeychainProtocol = MockPortalKeychain()
  ) throws -> PortalConnect {
    try PortalConnect(
      credentials: credentials,
      11_155_111,
      keychain,
      ["eip155:11155111": "https://\(MockConstants.mockHost)/test-rpc"],
      FeatureFlags()
    )
  }

  /// Builds a client on a fresh fake engine and recording sleeper and registers it for teardown.
  ///
  /// The reconnect policy is stated explicitly rather than defaulted so a case that asserts the
  /// back-off array is reading the same numbers the client was given.
  private func makeFixture(
    credentials: PortalCredentials,
    server: String = wsServer,
    keychain: PortalKeychainProtocol = MockPortalKeychain(),
    sleeper: RecordingSleeper = RecordingSleeper(),
    policy: PortalSwift.WebSocketClient.ReconnectPolicy = .init(
      maxAttempts: 5,
      baseDelayNs: 500_000_000,
      maxDelayNs: 8_000_000_000
    )
  ) throws -> Fixture {
    let connect = try self.makeConnect(credentials: credentials, keychain: keychain)
    let engine = FakeWebSocketEngine()
    let client = PortalSwift.WebSocketClient(
      credentials: credentials,
      connect: connect,
      webSocketServer: server,
      engine: engine,
      reconnectPolicy: policy,
      sleep: sleeper.sleep
    )
    let errors = ConnectErrorRecorder()
    errors.observe(client)

    let fixture = Fixture(
      credentials: credentials,
      keychain: keychain,
      connect: connect,
      engine: engine,
      sleeper: sleeper,
      client: client,
      errors: errors
    )
    self.fixtures.append(fixture)
    return fixture
  }

  /// The fixture `setUp` built, unwrapped without a force unwrap.
  private func defaultFixture(file: StaticString = #filePath, line: UInt = #line) throws -> Fixture {
    try XCTUnwrap(self.fixture, "The default fixture was not built", file: file, line: line)
  }

  /// The invalidation recorder `setUp` subscribed to the default session.
  private func defaultRecorder(file: StaticString = #filePath, line: UInt = #line) throws -> InvalidationListenerRecorder {
    try XCTUnwrap(self.recorder, "The invalidation recorder was not built", file: file, line: line)
  }

  /// The `client` argument of the delegate callback. The SDK ignores it; a fresh one per call
  /// keeps that visible.
  private func driver() -> FakeStarscreamClient {
    FakeStarscreamClient()
  }

  /// The event Starscream delivers when the proxy answered the upgrade with an HTTP status
  /// instead of switching protocols.
  private func upgradeRejected(_ statusCode: Int) -> Starscream.WebSocketEvent {
    .error(HTTPUpgradeError.notAnUpgrade(statusCode, [:]))
  }

  /// Asserts that `error` is the client's own invalid-server-URL failure and not a credential
  /// error, which is the distinction `PortalConnect` branches on (code 500 vs code 401).
  private func assertInvalidServerUrl(
    _ error: Error,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertTrue(
      error is WebSocketClientError,
      "Expected WebSocketClientError.invalidServerUrl, got \(type(of: error))",
      file: file,
      line: line
    )
    XCTAssertNil(error as? PortalCredentialError, "A bad server URL must not read as a credential failure", file: file, line: line)
  }

  /// Drives `count` reconnects by re-arming `.connected` before each `.peerClosed`, waiting for
  /// each attempt to reach the transport before moving on to the next.
  ///
  /// Re-arming is necessary because `reconnect()` settles the client in `.disconnected` for the
  /// whole attempt: without it the next drop would be ignored by the `isConnected` gate and the
  /// budget would never advance. The drop is re-delivered on every poll until the attempt lands,
  /// because a drop that arrives while the previous reconnect is still finishing is deliberately
  /// swallowed by the in-flight guard — re-delivering is how the test stays deterministic without
  /// reaching into that guard.
  private func driveReconnects(
    _ count: Int,
    fixture: Fixture,
    startCallsBefore: Int,
    file: StaticString = #filePath,
    line: UInt = #line
  ) async {
    for attempt in 1 ... count {
      let started = await waitUntil {
        if fixture.client.reconnectAttempts >= attempt, fixture.engine.startCallsCount >= startCallsBefore + attempt {
          return true
        }
        fixture.client.connectState = .connected
        fixture.client.didReceive(event: .peerClosed, client: FakeStarscreamClient())
        return false
      }
      XCTAssertTrue(started, "Reconnect attempt \(attempt) never reached the transport", file: file, line: line)
    }
  }

  // MARK: - buildUpgradeRequest

  func test_buildUpgradeRequest_willCarryBearerToken() throws {
    let fixture = try self.defaultFixture()

    let request = try fixture.client.buildUpgradeRequest()

    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(wsToken)")
    XCTAssertEqual(request.url?.absoluteString, wsServer)
    XCTAssertEqual(request.timeoutInterval, 5)
  }

  func test_buildUpgradeRequest_willResolveTokenPerCall() throws {
    let fixture = try self.defaultFixture()

    _ = try fixture.client.buildUpgradeRequest()
    _ = try fixture.client.buildUpgradeRequest()

    XCTAssertEqual(self.session.getTokenCalls, 2, "The credential is resolved once per upgrade request, never cached")
  }

  func test_buildUpgradeRequest_willPickUpRotatedToken() throws {
    let fixture = try self.defaultFixture()
    _ = try fixture.client.buildUpgradeRequest()

    self.session.tokenValue = wsRotatedToken
    let request = try fixture.client.buildUpgradeRequest()

    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(wsRotatedToken)")
  }

  func test_buildUpgradeRequest_willThrowProviderFailure_whenGetTokenThrows() throws {
    let credentials = MockCredentials(tokenValue: wsToken, onGetToken: { throw URLError(.badServerResponse) })
    let fixture = try self.makeFixture(credentials: credentials)

    XCTAssertThrowsError(try fixture.client.buildUpgradeRequest()) { error in
      XCTAssertEqual(error as? PortalCredentialError, .providerFailure(underlying: URLError(.badServerResponse)))
    }
    XCTAssertEqual(fixture.engine.startCallsCount, 0, "A failed credential must never reach the transport")
  }

  func test_buildUpgradeRequest_willThrowUnavailable_whenTokenBlank() throws {
    let credentials = MockCredentials(tokenValue: "  ")
    let fixture = try self.makeFixture(credentials: credentials)

    XCTAssertThrowsError(try fixture.client.buildUpgradeRequest()) { error in
      XCTAssertEqual(error as? PortalCredentialError, .unavailable)
    }
    XCTAssertEqual(fixture.engine.startCallsCount, 0)
  }

  func test_buildUpgradeRequest_willThrowSessionInvalidated_afterInvalidate() throws {
    let fixture = try self.defaultFixture()

    try self.session.invalidate()

    XCTAssertThrowsError(try fixture.client.buildUpgradeRequest()) { error in
      XCTAssertEqual(error as? PortalCredentialError, .sessionInvalidated)
    }
  }

  func test_buildUpgradeRequest_willThrow_whenServerUrlEmpty() throws {
    let fixture = try self.makeFixture(credentials: self.session, server: "")

    XCTAssertThrowsError(try fixture.client.buildUpgradeRequest()) { error in
      self.assertInvalidServerUrl(error)
    }
    XCTAssertEqual(fixture.engine.startCallsCount, 0)
  }

  func test_buildUpgradeRequest_willThrow_whenServerUrlMalformed() throws {
    let fixture = try self.makeFixture(credentials: self.session, server: wsMalformedServer)

    XCTAssertThrowsError(try fixture.client.buildUpgradeRequest()) { error in
      self.assertInvalidServerUrl(error)
    }
    XCTAssertEqual(fixture.engine.startCallsCount, 0)
  }

  func test_buildUpgradeRequest_willNotPlaceTokenInUrl() throws {
    let fixture = try self.defaultFixture()

    let request = try fixture.client.buildUpgradeRequest()

    let url = try XCTUnwrap(request.url?.absoluteString)
    XCTAssertFalse(url.contains(wsToken), "The bearer must travel in the Authorization header, never in the URL")
  }

  // MARK: - connect

  func test_connect_willStartEngineWithFreshRequest() throws {
    let fixture = try self.defaultFixture()

    try fixture.client.connect(uri: wsUri)

    XCTAssertEqual(fixture.engine.startCallsCount, 1)
    XCTAssertEqual(fixture.engine.startRequests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer \(wsToken)")
    XCTAssertEqual(fixture.client.uri, wsUri)
  }

  func test_connect_willRebuildRequest_onEachCall() throws {
    let fixture = try self.defaultFixture()

    try fixture.client.connect(uri: wsUri)
    self.session.tokenValue = wsRotatedToken
    try fixture.client.connect(uri: wsUri)

    let requests = fixture.engine.startRequests
    XCTAssertEqual(requests.count, 2)
    XCTAssertEqual(requests.last?.value(forHTTPHeaderField: "Authorization"), "Bearer \(wsRotatedToken)")
  }

  func test_connect_willThrowCredentialError_withoutStartingEngine() throws {
    let fixture = try self.defaultFixture()
    try self.session.invalidate()

    XCTAssertThrowsError(try fixture.client.connect(uri: wsUri)) { error in
      XCTAssertEqual(error as? PortalCredentialError, .sessionInvalidated)
    }
    XCTAssertEqual(fixture.engine.startCallsCount, 0)
    XCTAssertEqual(fixture.client.connectState, .disconnected)
  }

  func test_connect_willThrow_whenServerUrlInvalid_withoutStartingEngine() throws {
    let fixture = try self.makeFixture(credentials: self.session, server: wsMalformedServer)

    XCTAssertThrowsError(try fixture.client.connect(uri: wsUri)) { error in
      self.assertInvalidServerUrl(error)
    }
    XCTAssertEqual(fixture.engine.startCallsCount, 0)
  }

  // MARK: - didReceive(.connected)

  func test_didReceive_connected_willSendConnectMessage_andSetConnecting() throws {
    let fixture = try self.defaultFixture()
    try fixture.client.connect(uri: wsUri)

    fixture.client.didReceive(event: .connected([:]), client: self.driver())

    XCTAssertEqual(fixture.client.connectState, .connecting)
    let message = try XCTUnwrap(fixture.engine.writtenStrings.last)
    let json = try XCTUnwrap(message.data(using: .utf8))
    let request = try JSONDecoder().decode(WebSocketConnectRequest.self, from: json)
    XCTAssertEqual(request.event, "connect")
    XCTAssertEqual(request.data.uri, wsUri)
    XCTAssertEqual(request.data.address, MockConstants.mockEip155Address)
    XCTAssertEqual(request.data.chainId, 11_155_111)
    let pingTimer = try XCTUnwrap(fixture.client.pingTimer)
    XCTAssertTrue(pingTimer.isValid, "The keep-alive timer is scheduled by the handshake")
  }

  func test_didReceive_connected_willNotResetReconnectAttempts() async throws {
    let fixture = try self.defaultFixture()
    try fixture.client.connect(uri: wsUri)

    await self.driveReconnects(3, fixture: fixture, startCallsBefore: 1)
    XCTAssertEqual(fixture.client.reconnectAttempts, 3)

    fixture.client.didReceive(event: .connected([:]), client: self.driver())

    XCTAssertEqual(fixture.client.connectState, .connecting)
    XCTAssertEqual(fixture.client.reconnectAttempts, 3, "The transport upgrade alone does not end the outage")
  }

  func test_handleData_connected_willResetReconnectAttempts() async throws {
    let fixture = try self.defaultFixture()
    try fixture.client.connect(uri: wsUri)

    await self.driveReconnects(3, fixture: fixture, startCallsBefore: 1)
    XCTAssertEqual(fixture.client.reconnectAttempts, 3)

    fixture.client.didReceive(event: .connected([:]), client: self.driver())
    fixture.client.didReceive(event: .text(proxyConnectedMessage), client: self.driver())

    XCTAssertEqual(fixture.client.connectState, .connected, "The proxy's `connected` message is what completes the handshake")
    XCTAssertEqual(fixture.client.reconnectAttempts, 0, "The proxy's answer ends the outage")

    fixture.sleeper.reset()
    let sleptBaseDelay = await waitUntil {
      if fixture.sleeper.recordedNanoseconds == [500_000_000] {
        return true
      }
      fixture.client.connectState = .connected
      fixture.client.didReceive(event: .peerClosed, client: FakeStarscreamClient())
      return false
    }
    XCTAssertTrue(sleptBaseDelay, "The next drop starts a fresh budget at the base delay")
  }

  func test_reconnect_willExhaustBudget_whenProxyDropsAfterEveryUpgrade() async throws {
    // The scenario the budget exists for: the proxy accepts every upgrade and then closes the
    // socket before answering `connected`. Were the budget reset on the upgrade, each drop would
    // start again at attempt 1 and the client would reconnect at the base delay forever.
    let fixture = try self.defaultFixture()
    try fixture.client.connect(uri: wsUri)

    for attempt in 1 ... 5 {
      let started = await waitUntil {
        if fixture.client.reconnectAttempts >= attempt, fixture.engine.startCallsCount >= 1 + attempt {
          return true
        }
        fixture.client.didReceive(event: .connected([:]), client: FakeStarscreamClient())
        fixture.client.didReceive(event: .peerClosed, client: FakeStarscreamClient())
        return false
      }
      XCTAssertTrue(started, "Reconnect attempt \(attempt) never reached the transport")
    }
    XCTAssertEqual(fixture.client.reconnectAttempts, 5, "Five upgrades without a `connected` answer do not refill the budget")

    let gaveUp = await waitUntil {
      if fixture.errors.last?.message == "Reconnect attempts exhausted" {
        return true
      }
      fixture.client.didReceive(event: .connected([:]), client: FakeStarscreamClient())
      fixture.client.didReceive(event: .peerClosed, client: FakeStarscreamClient())
      return false
    }
    XCTAssertTrue(gaveUp, "The sixth drop exhausts the budget")
    XCTAssertEqual(fixture.errors.last?.code, 500)
    XCTAssertEqual(fixture.client.connectState, .disconnected)
    XCTAssertEqual(fixture.engine.startCallsCount, 6, "One connect plus five reconnects, no seventh")
  }

  func test_didReceive_connected_willNotSend_whenNoAddress() throws {
    let fixture = try self.makeFixture(credentials: self.session, keychain: AddresslessKeychain())
    try fixture.client.connect(uri: wsUri)

    fixture.client.didReceive(event: .connected([:]), client: self.driver())

    XCTAssertTrue(fixture.engine.writtenStrings.isEmpty, "Without an address there is nothing to announce to the proxy")
    // Flagged in the plan: the client stays in `.connecting` although nothing was sent. Pinned
    // as-is so a deliberate change to `.disconnected` shows up here as a failing expectation.
    XCTAssertEqual(fixture.client.connectState, .connecting)
  }

  // MARK: - handleError: terminal 401

  func test_handleError_notAnUpgrade401_willReportUnauthorizedOnce() async throws {
    let fixture = try self.defaultFixture()
    let recorder = try self.defaultRecorder()
    fixture.client.connectState = .connected

    fixture.client.didReceive(event: self.upgradeRejected(401), client: self.driver())

    XCTAssertEqual(self.session.invalidateCalls, 1)
    let notified = await waitUntil { recorder.count == 1 }
    XCTAssertTrue(notified, "A proxy 401 must tell the host its session ended")
    XCTAssertEqual(recorder.count, 1)
  }

  func test_handleError_notAnUpgrade401_willSetDisconnected() throws {
    let fixture = try self.defaultFixture()
    fixture.client.connectState = .connected

    fixture.client.didReceive(event: self.upgradeRejected(401), client: self.driver())

    XCTAssertEqual(fixture.client.connectState, .disconnected)
    XCTAssertFalse(fixture.client.isConnected, "A rejected credential must never leave isConnected stuck true")
  }

  func test_handleError_notAnUpgrade401_willEmitConnectError401() throws {
    let fixture = try self.defaultFixture()
    fixture.client.connectState = .connected

    fixture.client.didReceive(event: self.upgradeRejected(401), client: self.driver())

    XCTAssertEqual(fixture.errors.count, 1)
    XCTAssertEqual(fixture.errors.last?.message, "401 - Unauthorized")
    XCTAssertEqual(fixture.errors.last?.code, 401)
  }

  func test_handleError_notAnUpgrade401_willNotReconnect() async throws {
    let fixture = try self.defaultFixture()
    try fixture.client.connect(uri: wsUri)
    fixture.client.connectState = .connected

    fixture.client.didReceive(event: self.upgradeRejected(401), client: self.driver())

    let reconnected = await waitUntil(timeout: 0.1) { fixture.engine.startCallsCount > 1 }
    XCTAssertFalse(reconnected, "Retrying with the same rejected credential can only fail the same way")
    XCTAssertEqual(fixture.engine.startCallsCount, 1)
    XCTAssertEqual(fixture.sleeper.sleepCallsCount, 0)
  }

  func test_handleError_notAnUpgrade401_willInvalidatePingTimer_andStopEngine() throws {
    let fixture = try self.defaultFixture()
    try fixture.client.connect(uri: wsUri)
    fixture.client.didReceive(event: .connected([:]), client: self.driver())
    fixture.client.connectState = .connected

    fixture.client.didReceive(event: self.upgradeRejected(401), client: self.driver())

    XCTAssertFalse(fixture.client.pingTimer?.isValid ?? false, "The keep-alive must stop with the connection")
    XCTAssertEqual(fixture.engine.stopCallsCount, 1)
  }

  func test_handleError_notAnUpgrade401_twice_willReportOnce() async throws {
    let fixture = try self.defaultFixture()
    let recorder = try self.defaultRecorder()
    fixture.client.connectState = .connected

    fixture.client.didReceive(event: self.upgradeRejected(401), client: self.driver())
    fixture.client.connectState = .connected
    fixture.client.didReceive(event: self.upgradeRejected(401), client: self.driver())

    let notified = await waitUntil { recorder.count == 1 }
    XCTAssertTrue(notified)
    XCTAssertEqual(recorder.count, 1, "The host is told once however many 401s arrive")
    XCTAssertEqual(fixture.errors.count, 2, "Every rejection is still surfaced to the caller")
    // Each report invalidates: only the host notification is deduplicated (see
    // ReportUnauthorizedTests.test_reportUnauthorized_willNotifyOnce_whenReportedSequentially).
    XCTAssertEqual(self.session.invalidateCalls, 2)
  }

  // MARK: - handleError: other outcomes

  func test_handleError_notAnUpgrade403_willNotReport() async throws {
    let fixture = try self.defaultFixture()
    let recorder = try self.defaultRecorder()
    let error = HTTPUpgradeError.notAnUpgrade(403, [:])
    fixture.client.connectState = .connected

    fixture.client.didReceive(event: .error(error), client: self.driver())

    XCTAssertEqual(self.session.invalidateCalls, 0, "Only a 401 implicates the credential")
    XCTAssertEqual(recorder.count, 0)
    XCTAssertEqual(fixture.errors.count, 1)
    XCTAssertEqual(fixture.errors.last?.code, 500)
    XCTAssertEqual(fixture.errors.last?.message, error.localizedDescription)
    XCTAssertEqual(fixture.client.connectState, .disconnected)
    XCTAssertEqual(fixture.engine.stopCallsCount, 1)
  }

  func test_handleError_notAnUpgrade500_willNotReport() async throws {
    let fixture = try self.defaultFixture()
    let recorder = try self.defaultRecorder()
    let error = HTTPUpgradeError.notAnUpgrade(500, [:])
    fixture.client.connectState = .connected

    fixture.client.didReceive(event: .error(error), client: self.driver())

    XCTAssertEqual(self.session.invalidateCalls, 0)
    XCTAssertEqual(recorder.count, 0)
    XCTAssertEqual(fixture.errors.last?.code, 500)
    XCTAssertEqual(fixture.errors.last?.message, error.localizedDescription)
    XCTAssertEqual(fixture.client.connectState, .disconnected)
  }

  func test_handleError_genericError_willEmit500_andDisconnect() throws {
    let fixture = try self.defaultFixture()
    let error = URLError(.timedOut)
    fixture.client.connectState = .connected

    fixture.client.didReceive(event: .error(error), client: self.driver())

    XCTAssertEqual(fixture.errors.count, 1)
    XCTAssertEqual(fixture.errors.last?.code, 500)
    XCTAssertEqual(fixture.errors.last?.message, error.localizedDescription)
    XCTAssertEqual(fixture.client.connectState, .disconnected)
    XCTAssertEqual(self.session.invalidateCalls, 0)
    XCTAssertEqual(fixture.engine.stopCallsCount, 1)
  }

  func test_handleError_nilError_willEmitUnknown500() throws {
    let fixture = try self.defaultFixture()
    fixture.client.connectState = .connected

    fixture.client.didReceive(event: .error(nil), client: self.driver())

    XCTAssertEqual(fixture.errors.count, 1)
    XCTAssertEqual(fixture.errors.last?.message, "An unknown error occurred.")
    XCTAssertEqual(fixture.errors.last?.code, 500)
    XCTAssertEqual(fixture.client.connectState, .disconnected)
  }

  func test_handleError_peerReset_whileConnected_willReconnectWithBackoff() async throws {
    let fixture = try self.defaultFixture()
    try fixture.client.connect(uri: wsUri)
    fixture.client.connectState = .connected

    fixture.client.didReceive(event: .error(PeerResetError()), client: self.driver())

    let restarted = await waitUntil { fixture.engine.startCallsCount == 2 }
    XCTAssertTrue(restarted, "A peer reset while connected is retried")
    XCTAssertEqual(fixture.sleeper.recordedNanoseconds, [500_000_000])
    XCTAssertEqual(fixture.client.reconnectAttempts, 1)
    XCTAssertEqual(
      fixture.client.connectState,
      .disconnected,
      "A reconnect must not report .connecting before the proxy answers"
    )
  }

  func test_handleError_peerReset_whileDisconnected_willNotReconnect() async throws {
    let fixture = try self.defaultFixture()
    try fixture.client.connect(uri: wsUri)
    fixture.client.connectState = .disconnected

    fixture.client.didReceive(event: .error(PeerResetError()), client: self.driver())

    let reconnected = await waitUntil(timeout: 0.1) { fixture.engine.startCallsCount > 1 }
    XCTAssertFalse(reconnected)
    XCTAssertEqual(fixture.engine.startCallsCount, 1)
    XCTAssertEqual(fixture.errors.last?.code, 500)
    XCTAssertEqual(fixture.errors.last?.message, PeerResetError.starscreamText)
  }

  // MARK: - reconnect budget

  func test_reconnect_willBackOffExponentially_cappedAt8s() async throws {
    let fixture = try self.defaultFixture()
    try fixture.client.connect(uri: wsUri)

    await self.driveReconnects(5, fixture: fixture, startCallsBefore: 1)

    XCTAssertEqual(
      fixture.sleeper.recordedNanoseconds,
      [500_000_000, 1_000_000_000, 2_000_000_000, 4_000_000_000, 8_000_000_000]
    )
    XCTAssertEqual(fixture.engine.startCallsCount, 6, "One connect plus five reconnects")
  }

  func test_reconnect_willGiveUp_afterFiveAttempts() async throws {
    let fixture = try self.defaultFixture()
    try fixture.client.connect(uri: wsUri)
    await self.driveReconnects(5, fixture: fixture, startCallsBefore: 1)

    let gaveUp = await waitUntil {
      if fixture.errors.last?.message == "Reconnect attempts exhausted" {
        return true
      }
      fixture.client.connectState = .connected
      fixture.client.didReceive(event: .peerClosed, client: FakeStarscreamClient())
      return false
    }
    XCTAssertTrue(gaveUp, "The sixth drop exhausts the budget")
    XCTAssertEqual(fixture.errors.last?.code, 500)
    XCTAssertEqual(fixture.client.connectState, .disconnected)
    XCTAssertEqual(fixture.engine.startCallsCount, 6, "No seventh attempt")
    XCTAssertEqual(fixture.sleeper.sleepCallsCount, 5, "An exhausted budget does not wait")
  }

  func test_reconnect_willStopWithoutReporting_whenCredentialInvalidatedBeforeReconnect() async throws {
    let fixture = try self.defaultFixture()
    let recorder = try self.defaultRecorder()
    try fixture.client.connect(uri: wsUri)
    fixture.client.didReceive(event: .connected([:]), client: self.driver())

    // A host sign-out, which the credentials layer documents as silent. The SDK's own 401 path
    // would already have reported before the session read as invalidated.
    try self.session.invalidate()
    fixture.client.connectState = .connected
    fixture.client.didReceive(event: .peerClosed, client: self.driver())

    let surfaced = await waitUntil { fixture.errors.last?.code == 401 }
    XCTAssertTrue(surfaced, "A dead credential found during a reconnect is terminal")
    XCTAssertEqual(fixture.client.connectState, .disconnected)
    XCTAssertFalse(fixture.client.isConnected)
    XCTAssertEqual(fixture.engine.startCallsCount, 1, "The reconnect never reached the transport")
    XCTAssertFalse(fixture.client.pingTimer?.isValid ?? false)
    let notified = await waitUntil(timeout: 0.1) { recorder.count > 0 }
    XCTAssertFalse(notified, "Nothing was sent, so nothing was rejected: a local credential failure is not a report")
    XCTAssertEqual(self.session.invalidateCalls, 1, "Only this test's own sign-out touched the session")
  }

  func test_reconnect_willNotRetry_afterCredentialFailure() async throws {
    let fixture = try self.defaultFixture()
    try fixture.client.connect(uri: wsUri)
    try self.session.invalidate()
    fixture.client.connectState = .connected
    fixture.client.didReceive(event: .peerClosed, client: self.driver())
    let reported = await waitUntil { fixture.errors.last?.code == 401 }
    XCTAssertTrue(reported)

    // Forget the failed attempt's delay so the assertions below are about what happens next.
    fixture.sleeper.reset()
    fixture.client.didReceive(event: .peerClosed, client: self.driver())
    fixture.client.didReceive(event: .reconnectSuggested(true), client: self.driver())

    let retried = await waitUntil(timeout: 0.1) { fixture.engine.startCallsCount > 1 }
    XCTAssertFalse(retried, "Further drops after a credential failure must not be retried")
    XCTAssertEqual(fixture.engine.startCallsCount, 1)
    XCTAssertEqual(fixture.sleeper.sleepCallsCount, 0)
  }

  func test_reconnect_willStopWithoutInvalidating_whenProviderThrowsDuringReconnect() async throws {
    let credentials = MockCredentials(tokenValue: wsToken)
    credentials.onGetToken = { [weak credentials] in
      // The first resolution (the initial connect) succeeds; the reconnect's fails.
      if (credentials?.getTokenCalls ?? 0) >= 2 {
        throw URLError(.userAuthenticationRequired)
      }
    }
    let fixture = try self.makeFixture(credentials: credentials)
    try fixture.client.connect(uri: wsUri)
    fixture.client.connectState = .connected

    fixture.client.didReceive(event: .peerClosed, client: self.driver())

    let surfaced = await waitUntil { fixture.errors.last?.code == 401 }
    XCTAssertTrue(surfaced, "A provider failure during a reconnect is terminal for this connection")
    XCTAssertEqual(credentials.invalidateCalls, 0, "A host provider's failure may be transient; the SDK must not destroy its credential")
    XCTAssertEqual(fixture.client.connectState, .disconnected)
    XCTAssertEqual(fixture.engine.startCallsCount, 1)
  }

  func test_reconnect_willNeverLeaveConnecting_whenConnectThrows() async throws {
    // The server string is fixed at construction, so a reconnect that fails on a bad URL is
    // staged by building the client against one and driving it into a connected state directly.
    let fixture = try self.makeFixture(credentials: self.session, server: wsMalformedServer)
    fixture.client.uri = wsUri
    fixture.client.connectState = .connected

    fixture.client.didReceive(event: .peerClosed, client: self.driver())

    let failed = await waitUntil { fixture.errors.count == 1 }
    XCTAssertTrue(failed, "A reconnect that cannot build a request still reports")
    XCTAssertEqual(fixture.errors.last?.code, 500, "A bad server URL is not a credential failure")
    XCTAssertEqual(fixture.client.connectState, .disconnected, "No path may leave the client in .connecting")
    XCTAssertEqual(fixture.engine.startCallsCount, 0)
    XCTAssertEqual(self.session.invalidateCalls, 0)
  }

  // MARK: - didReceive: remaining branches

  func test_didReceive_reconnectSuggested_whileConnected_willReconnect() async throws {
    let fixture = try self.defaultFixture()
    try fixture.client.connect(uri: wsUri)
    fixture.client.connectState = .connected

    fixture.client.didReceive(event: .reconnectSuggested(true), client: self.driver())

    let restarted = await waitUntil { fixture.engine.startCallsCount == 2 }
    XCTAssertTrue(restarted)
    XCTAssertEqual(fixture.sleeper.recordedNanoseconds, [500_000_000])
  }

  func test_didReceive_reconnectSuggested_whileDisconnected_willDoNothing() async throws {
    let fixture = try self.defaultFixture()
    try fixture.client.connect(uri: wsUri)
    fixture.client.connectState = .disconnected

    fixture.client.didReceive(event: .reconnectSuggested(true), client: self.driver())

    let restarted = await waitUntil(timeout: 0.1) { fixture.engine.startCallsCount > 1 }
    XCTAssertFalse(restarted)
    XCTAssertEqual(fixture.engine.startCallsCount, 1)
    XCTAssertEqual(fixture.sleeper.sleepCallsCount, 0)
  }

  func test_didReceive_peerClosed_whileDisconnected_willInvalidatePing_andStayDisconnected() async throws {
    let fixture = try self.defaultFixture()
    try fixture.client.connect(uri: wsUri)
    fixture.client.didReceive(event: .connected([:]), client: self.driver())
    fixture.client.connectState = .disconnected

    fixture.client.didReceive(event: .peerClosed, client: self.driver())

    XCTAssertFalse(fixture.client.pingTimer?.isValid ?? false)
    XCTAssertEqual(fixture.client.connectState, .disconnected)
    let restarted = await waitUntil(timeout: 0.1) { fixture.engine.startCallsCount > 1 }
    XCTAssertFalse(restarted, "A drop while already disconnected is not retried")
  }

  func test_didReceive_cancelled_willSetDisconnected() throws {
    let fixture = try self.defaultFixture()
    try fixture.client.connect(uri: wsUri)
    fixture.client.didReceive(event: .connected([:]), client: self.driver())

    fixture.client.didReceive(event: .cancelled, client: self.driver())

    XCTAssertEqual(fixture.client.connectState, .disconnected)
    XCTAssertFalse(fixture.client.pingTimer?.isValid ?? false)
  }

  func test_didReceive_disconnected_willSetDisconnected_andStopEngine() throws {
    let fixture = try self.defaultFixture()
    try fixture.client.connect(uri: wsUri)
    fixture.client.didReceive(event: .connected([:]), client: self.driver())

    fixture.client.didReceive(event: .disconnected("bye", 1000), client: self.driver())

    XCTAssertEqual(fixture.client.connectState, .disconnected)
    XCTAssertEqual(fixture.engine.stopCallsCount, 1)
    XCTAssertEqual(fixture.engine.stopCloseCodes, [1000])
    XCTAssertFalse(fixture.client.pingTimer?.isValid ?? false)
  }

  // MARK: - Cancellation of a pending reconnect

  /// Drops the connection so a reconnect is scheduled and parks it inside the injected delay,
  /// so the case can act "during the backoff". Returns once the sleep is held.
  private func scheduleHeldReconnect(_ fixture: Fixture, file: StaticString = #filePath, line: UInt = #line) async throws {
    try fixture.client.connect(uri: wsUri)
    fixture.client.connectState = .connected
    fixture.client.didReceive(event: .peerClosed, client: self.driver())
    let held = await fixture.sleeper.waitUntilHeld()
    XCTAssertTrue(held, "The reconnect never reached its backoff", file: file, line: line)
  }

  func test_disconnect_duringBackoff_willCancelTheReconnect_andNotReopenTheSocket() async throws {
    let fixture = try self.makeFixture(credentials: self.session, sleeper: RecordingSleeper(isHolding: true))
    try await self.scheduleHeldReconnect(fixture)

    fixture.client.disconnect()
    fixture.sleeper.release()

    let reopened = await waitUntil(timeout: 0.3) { fixture.engine.startCallsCount > 1 }
    XCTAssertFalse(reopened, "A socket the host closed must stay closed when the backoff expires")
    XCTAssertEqual(fixture.engine.startCallsCount, 1)
    XCTAssertEqual(fixture.client.connectState, .disconnected)
  }

  func test_close_duringBackoff_willCancelTheReconnect() async throws {
    let fixture = try self.makeFixture(credentials: self.session, sleeper: RecordingSleeper(isHolding: true))
    try await self.scheduleHeldReconnect(fixture)

    fixture.client.close()
    fixture.sleeper.release()

    let reopened = await waitUntil(timeout: 0.3) { fixture.engine.startCallsCount > 1 }
    XCTAssertFalse(reopened, "close() must also drop a reconnect waiting in its backoff")
    XCTAssertEqual(fixture.client.connectState, .disconnected)
  }

  func test_connect_duringBackoff_willSupersedeTheReconnect_andKeepTheNewUri() async throws {
    let fixture = try self.makeFixture(credentials: self.session, sleeper: RecordingSleeper(isHolding: true))
    try await self.scheduleHeldReconnect(fixture)
    let newUri = "wc:other-topic@2?relay-protocol=irn&symKey=def456"

    try fixture.client.connect(uri: newUri)
    fixture.sleeper.release()

    let thirdStart = await waitUntil(timeout: 0.3) { fixture.engine.startCallsCount > 2 }
    XCTAssertFalse(thirdStart, "The stale reconnect must not open a third connection")
    XCTAssertEqual(fixture.engine.startCallsCount, 2, "The initial connect plus the host's new connect")
    XCTAssertEqual(fixture.client.uri, newUri, "The stale reconnect must not clobber the new session's uri")
  }

  // MARK: - Retry budget when the proxy is unreachable

  func test_reconnect_willWalkTheWholeBudget_whenEveryRetryFailsAtTheTransport() async throws {
    let fixture = try self.defaultFixture()
    try fixture.client.connect(uri: wsUri)
    fixture.client.connectState = .connected
    fixture.client.didReceive(event: .peerClosed, client: self.driver())

    // Each retry reaches the transport and fails there. The client is deliberately *not*
    // re-armed to `.connected` by the test — that re-arming is what the pre-fix ladder silently
    // depended on, and it is not something a real outage does.
    for attempt in 1 ... 5 {
      let started = await waitUntil { fixture.engine.startCallsCount == 1 + attempt }
      XCTAssertTrue(started, "Retry \(attempt) never reached the transport")
      fixture.client.didReceive(event: .error(URLError(.cannotConnectToHost)), client: self.driver())
    }

    let gaveUp = await waitUntil { fixture.errors.last?.message == "Reconnect attempts exhausted" }
    XCTAssertTrue(gaveUp, "The sixth transport failure exhausts the budget")
    XCTAssertEqual(
      fixture.sleeper.recordedNanoseconds,
      [500_000_000, 1_000_000_000, 2_000_000_000, 4_000_000_000, 8_000_000_000]
    )
    XCTAssertEqual(fixture.engine.startCallsCount, 6, "One connect plus five retries, and no sixth")
    XCTAssertEqual(fixture.client.connectState, .disconnected)
  }

  func test_reconnect_willTreatCancelledDuringRetry_asAFailedAttempt() async throws {
    let fixture = try self.defaultFixture()
    try fixture.client.connect(uri: wsUri)
    fixture.client.connectState = .connected
    fixture.client.didReceive(event: .peerClosed, client: self.driver())
    let firstRetry = await waitUntil { fixture.engine.startCallsCount == 2 }
    XCTAssertTrue(firstRetry)

    fixture.client.didReceive(event: .cancelled, client: self.driver())

    let secondRetry = await waitUntil { fixture.engine.startCallsCount == 3 }
    XCTAssertTrue(secondRetry, "A retry cancelled at the transport consumes the next attempt")
    XCTAssertEqual(fixture.client.reconnectAttempts, 2)
  }

  func test_handleError_whileIdle_willStillEmit500_andNotTouchTheBudget() async throws {
    let fixture = try self.defaultFixture()
    try fixture.client.connect(uri: wsUri)
    fixture.client.connectState = .disconnected

    fixture.client.didReceive(event: .error(URLError(.cannotConnectToHost)), client: self.driver())

    XCTAssertEqual(fixture.errors.last?.code, 500)
    XCTAssertEqual(fixture.sleeper.sleepCallsCount, 0, "A drop while idle is not a failed retry")
    XCTAssertEqual(fixture.client.reconnectAttempts, 0)
  }

  // MARK: - Main-actor delivery

  func test_reconnect_willEmitItsErrors_onTheMainThread() async throws {
    let fixture = try self.defaultFixture()
    let threads = ThreadRecorder()
    fixture.client.on("error") { (_: ConnectError) in threads.record() }
    try fixture.client.connect(uri: wsUri)
    fixture.client.didReceive(event: .connected([:]), client: self.driver())

    // Dead credential: the reconnect fails inside its task and emits code 401 from there.
    try self.session.invalidate()
    fixture.client.connectState = .connected
    fixture.client.didReceive(event: .peerClosed, client: self.driver())

    let emitted = await waitUntil { threads.count == 1 }
    XCTAssertTrue(emitted)
    XCTAssertEqual(
      threads.onMainThread,
      [true],
      "Events emitted by the reconnect task must reach the host on the main thread, like every Starscream-delivered event"
    )
  }

  // MARK: - Concurrency

  func test_reconnect_willRunOnce_whenTwoPeerClosedArriveTogether() async throws {
    let sleeper = RecordingSleeper(isHolding: true)
    let fixture = try self.makeFixture(credentials: self.session, sleeper: sleeper)
    try fixture.client.connect(uri: wsUri)
    fixture.client.connectState = .connected

    fixture.client.didReceive(event: .peerClosed, client: self.driver())
    let held = await sleeper.waitUntilHeld()
    XCTAssertTrue(held, "The first reconnect must be parked inside its delay")

    // Re-arm the connected state so the second drop is rejected by the in-flight guard rather
    // than by the `isConnected` gate.
    fixture.client.connectState = .connected
    fixture.client.didReceive(event: .peerClosed, client: self.driver())
    sleeper.release()

    let restarted = await waitUntil { fixture.engine.startCallsCount == 2 }
    XCTAssertTrue(restarted)
    let restartedTwice = await waitUntil(timeout: 0.1) { fixture.engine.startCallsCount > 2 }
    XCTAssertFalse(restartedTwice, "Two drops in flight must produce one reconnect")
    XCTAssertEqual(sleeper.sleepCallsCount, 1)
    XCTAssertEqual(fixture.client.reconnectAttempts, 1)
  }

  func test_handleError_401_racingPeerClosed_willReportOnce_andNotReconnect() async throws {
    let fixture = try self.defaultFixture()
    let recorder = try self.defaultRecorder()
    try fixture.client.connect(uri: wsUri)
    fixture.client.connectState = .connected

    fixture.client.didReceive(event: self.upgradeRejected(401), client: self.driver())
    fixture.client.didReceive(event: .peerClosed, client: self.driver())

    let notified = await waitUntil { recorder.count == 1 }
    XCTAssertTrue(notified)
    XCTAssertEqual(self.session.invalidateCalls, 1, "The drop that follows a 401 must not report again")
    let restarted = await waitUntil(timeout: 0.1) { fixture.engine.startCallsCount > 1 }
    XCTAssertFalse(restarted)
    XCTAssertEqual(fixture.engine.startCallsCount, 1)
    XCTAssertEqual(fixture.client.connectState, .disconnected)
  }

  // MARK: - Persistence and the deprecated constructor

  func test_connect_afterTerminal401_willThrowSessionInvalidated() throws {
    let fixture = try self.defaultFixture()
    try fixture.client.connect(uri: wsUri)
    fixture.client.connectState = .connected
    fixture.client.didReceive(event: self.upgradeRejected(401), client: self.driver())

    XCTAssertThrowsError(try fixture.client.connect(uri: wsUri)) { error in
      XCTAssertEqual(error as? PortalCredentialError, .sessionInvalidated)
    }
    XCTAssertEqual(fixture.engine.startCallsCount, 1, "A reported credential cannot open a new connection")
  }

  @available(*, deprecated, message: "Exercises the deprecated apiKey constructor on purpose.")
  func test_init_apiKey_deprecated_willCarryStaticBearer() throws {
    let keychain = MockPortalKeychain()
    let connect = try self.makeConnect(credentials: MockConstants.mockCredentials, keychain: keychain)
    let engine = FakeWebSocketEngine()
    let client = PortalSwift.WebSocketClient(
      apiKey: MockConstants.mockApiKey,
      connect: connect,
      webSocketServer: wsServer,
      engine: engine
    )
    self.fixtures.append(
      Fixture(
        credentials: MockConstants.mockCredentials,
        keychain: keychain,
        connect: connect,
        engine: engine,
        sleeper: RecordingSleeper(),
        client: client,
        errors: ConnectErrorRecorder()
      )
    )

    let request = try client.buildUpgradeRequest()

    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(MockConstants.mockApiKey)")
  }

  // MARK: - Security

  func test_connectError_messages_willNotContainToken() async throws {
    let fixture = try self.defaultFixture()
    try fixture.client.connect(uri: wsUri)

    fixture.client.connectState = .connected
    fixture.client.didReceive(event: self.upgradeRejected(403), client: self.driver())
    fixture.client.connectState = .connected
    fixture.client.didReceive(event: self.upgradeRejected(401), client: self.driver())

    let credentialFixture = try self.makeFixture(credentials: MockPortalSession(tokenValue: wsToken))
    try credentialFixture.client.connect(uri: wsUri)
    try credentialFixture.credentials.invalidate()
    credentialFixture.client.connectState = .connected
    credentialFixture.client.didReceive(event: .peerClosed, client: self.driver())
    let failed = await waitUntil { credentialFixture.errors.last?.code == 401 }
    XCTAssertTrue(failed)

    let messages = fixture.errors.messages + credentialFixture.errors.messages
    XCTAssertFalse(messages.isEmpty, "The assertion would be vacuous without any emitted error")
    for message in messages {
      XCTAssertFalse(message.contains(wsToken), "A ConnectError message leaked the credential: \(message)")
    }
  }

  func test_webSocketClient_willNotLogToken() async throws {
    let fixture = try self.defaultFixture()
    let recorder = try self.defaultRecorder()

    try fixture.client.connect(uri: wsUri)
    fixture.client.didReceive(event: .connected([:]), client: self.driver())
    fixture.client.connectState = .connected
    fixture.client.didReceive(event: self.upgradeRejected(401), client: self.driver())
    let notified = await waitUntil { recorder.count == 1 }
    XCTAssertTrue(notified)

    XCTAssertFalse(self.logger.messages.isEmpty, "The client logs its lifecycle; an empty sink would make this vacuous")
    self.logger.assertNoSecret(wsToken)
  }
}
