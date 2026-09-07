//
//  PortalConnectTest.swift
//
//
//  Created by Portal Labs on 12/06/2024.
//

@testable import PortalSwift
import Starscream
import XCTest

/// The session token every case in this file authenticates with, and the string the security
/// case searches the emitted error and the log sink for.
private let connectToken = "ws-token-1"

class PortalConnectTest: XCTestCase {
  var portalConnect: PortalConnect!
  var mockClient: MockWebSocketClient!

  var keychain: PortalKeychainProtocol!
  let mockURL = "https://\(MockConstants.mockHost)/test-rpc"

  /// The credential the instance under test is built with. A session rather than a Client API
  /// Key, so the 401 paths can be observed: a static key is never reported to the host.
  var session = MockPortalSession(tokenValue: connectToken)

  /// Every `portal_connectError` the instance emitted, in emission order.
  private var errorEvents = ErrorDataRecorder()

  /// Subscribed to the session so the once-only host notification can be counted.
  private var recorder: InvalidationListenerRecorder?

  /// Captures the SDK's log lines so the security case is a real assertion.
  private var logger = RecordingLogger()

  /// Records the `ErrorData` payloads emitted on `Events.ConnectError`.
  ///
  /// Lock-guarded because a connect failure can be emitted from whichever thread the client's
  /// event bus is running on, while the test asserts from its own.
  private final class ErrorDataRecorder {
    private let lock = NSLock()
    private var _events: [ErrorData] = []

    /// Every emitted payload, in emission order.
    var events: [ErrorData] {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._events
    }

    /// How many payloads were emitted.
    var count: Int {
      self.events.count
    }

    /// The most recently emitted payload, if any.
    var last: ErrorData? {
      self.events.last
    }

    /// Subscribes to `connect`'s error event. The bus retains the handler, so the recorder is
    /// captured weakly.
    func observe(_ connect: PortalConnect) {
      connect.on(event: Events.ConnectError.rawValue) { [weak self] data in
        guard let errorData = data as? ErrorData else {
          return
        }
        self?.record(errorData)
      }
    }

    private func record(_ event: ErrorData) {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._events.append(event)
    }
  }

  override func setUpWithError() throws {
    try super.setUpWithError()

    // The registry's reported flags are process-wide; without a reset the once-only cases would
    // depend on what ran before them.
    CredentialInvalidationRegistry.shared.resetForTesting()
    self.logger = RecordingLogger()
    self.logger.install()

    self.keychain = MockPortalKeychain()
    let chainId = 11_155_111

    self.session = MockPortalSession(tokenValue: connectToken)
    portalConnect = try PortalConnect(
      credentials: session,
      chainId,
      keychain,
      ["eip155:11155111": mockURL],
      FeatureFlags()
    )

    mockClient = MockWebSocketClient(credentials: session, connect: portalConnect)
    portalConnect.client = mockClient

    self.errorEvents = ErrorDataRecorder()
    self.errorEvents.observe(portalConnect)
    self.recorder = InvalidationListenerRecorder(credentials: session)
  }

  override func tearDownWithError() throws {
    portalConnect = nil
    mockClient = nil
    self.recorder = nil
    self.logger.uninstall()
    CredentialInvalidationRegistry.shared.resetForTesting()
    try super.tearDownWithError()
  }

  func testConnect_success() {
    portalConnect.connect(mockURL)
    XCTAssertTrue(self.mockClient.isConnected)
    XCTAssertEqual(self.mockClient.uri, self.mockURL)
  }

  func testDisconnect() {
    portalConnect.connect(mockURL)
    portalConnect.disconnect(true)
    XCTAssertFalse(mockClient.isConnected)
  }

  func testHandleClose() {
    portalConnect.handleClose()
    XCTAssertNil(portalConnect.client!.topic)
    XCTAssertFalse(portalConnect.client!.isConnected)
  }

  func testHandleDappSessionRequested_approved() throws {
    let data = MockConstants.mockConnectData

    let expectation = self.expectation(description: "DappSessionApproved event should be handled")
    mockClient.onSend = { message in
      let event = try! JSONDecoder().decode(DappSessionResponseMessage.self, from: message)
      XCTAssertEqual(event.event, "portal_dappSessionApproved")
      expectation.fulfill()
    }

    portalConnect.handleDappSessionRequested(data: data)
    portalConnect.emit(event: Events.PortalDappSessionApproved.rawValue, data: data)

    waitForExpectations(timeout: 2.0, handler: nil)
  }

  func testHandleDappSessionRequested_rejected() throws {
    let data = MockConstants.mockConnectData

    let expectation = self.expectation(description: "DappSessionRejected event should be handled")
    mockClient.onSend = { message in
      let event = try! JSONDecoder().decode(DappSessionResponseMessage.self, from: message)
      XCTAssertEqual(event.event, "portal_dappSessionRejected")
      expectation.fulfill()
    }

    portalConnect.handleDappSessionRequested(data: data)
    portalConnect.emit(event: Events.PortalDappSessionRejected.rawValue, data: data)

    waitForExpectations(timeout: 2.0, handler: nil)
  }

  func testHandleSessionRequest_success() async throws {
    let data = MockConstants.mockSessionRequestData

    let expectation = self.expectation(description: "SessionRequest should be handled successfully")
    portalConnect.handleSessionRequest(data: data)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testHandleSessionRequestAddress_success() async throws {
    let data = MockConstants.mockSessionRequestAddressData

    let expectation = self.expectation(description: "SessionRequestAddress should be handled successfully")
    portalConnect.handleSessionRequestAddress(data: data)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testHandleSessionRequestTransaction_success() async throws {
    let data = MockConstants.mockSessionRequestTransactionData

    let expectation = self.expectation(description: "SessionRequestTransaction should be handled successfully")
    portalConnect.handleSessionRequestTransaction(data: data)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  // MARK: - Credentials

  func test_init_credentials_willBuildClient() throws {
    // PortalProvider holds the keychain weakly, so the keychain has to outlive the initializer
    // call for `connect.address` to resolve; a temporary argument would be gone by the assertion.
    let keychain = MockPortalKeychain()
    let connect = try PortalConnect(
      credentials: MockPortalSession(tokenValue: connectToken),
      11_155_111,
      keychain,
      ["eip155:11155111": mockURL],
      FeatureFlags()
    )

    XCTAssertNotNil(connect.client, "The credentials initializer builds its own web socket client")
    XCTAssertFalse(connect.connected)
    XCTAssertEqual(connect.address, MockConstants.mockEip155Address)
  }

  @available(*, deprecated, message: "Exercises the deprecated apiKey initializer on purpose.")
  func test_init_apiKey_deprecated_willStillBuild() throws {
    let connect = try PortalConnect(
      MockConstants.mockApiKey,
      11_155_111,
      MockPortalKeychain(),
      ["eip155:11155111": mockURL],
      FeatureFlags()
    )

    let client = try XCTUnwrap(connect.client)
    let request = try client.buildUpgradeRequest()
    XCTAssertEqual(
      request.value(forHTTPHeaderField: "Authorization"),
      "Bearer \(MockConstants.mockApiKey)",
      "A Client API Key is wrapped in StaticCredentials and still sent as the bearer"
    )
  }

  @available(*, deprecated, message: "Exercises the deprecated gatewayConfig initializer on purpose.")
  func test_init_gatewayConfig_deprecated_willStillBuild() throws {
    let connect = try PortalConnect(
      MockConstants.mockApiKey,
      11_155_111,
      PortalKeychain(keychainAccess: MockPortalKeychainAccess()),
      [11_155_111: mockURL],
      FeatureFlags()
    )

    XCTAssertNotNil(connect.client, "The legacy Ethereum-reference gateway config still builds")
    XCTAssertEqual(connect.chainId, 11_155_111)
  }

  func test_connect_willEmitPortalConnectError_andStayDisconnected_whenCredentialFails() {
    mockClient.connectThrows = PortalCredentialError.providerFailure(underlying: URLError(.badURL))

    // The signature is non-throwing: the failure is delivered on the event bus, not raised.
    portalConnect.connect(mockURL)

    XCTAssertEqual(self.errorEvents.count, 1)
    XCTAssertEqual(self.errorEvents.last?.params.code, 401)
    XCTAssertFalse(portalConnect.connected)
    XCTAssertEqual(mockClient.connectState, .disconnected)
  }

  func test_connect_willReportUnauthorized_whenCredentialErrorIsSessionInvalidated() async throws {
    let engine = FakeWebSocketEngine()
    let client = PortalSwift.WebSocketClient(
      credentials: session,
      connect: portalConnect,
      webSocketServer: "wss://connect.portalhq.io",
      engine: engine
    )
    portalConnect.client = client
    let recorder = try XCTUnwrap(self.recorder)
    try self.session.invalidate()

    portalConnect.connect(mockURL)

    XCTAssertEqual(self.errorEvents.count, 1)
    XCTAssertEqual(self.errorEvents.last?.params.code, 401)
    XCTAssertFalse(portalConnect.connected)
    XCTAssertEqual(engine.startCallsCount, 0, "A dead credential never reaches the transport")
    let notified = await waitUntil { recorder.count == 1 }
    XCTAssertTrue(notified, "The host must learn its session ended")
    XCTAssertLessThanOrEqual(recorder.count, 1, "The host is told at most once per credential")
  }

  func test_connect_willNotInvalidate_whenNonCredentialErrorThrown() {
    mockClient.connectThrows = URLError(.badURL)

    portalConnect.connect(mockURL)

    XCTAssertEqual(self.errorEvents.count, 1)
    XCTAssertEqual(self.errorEvents.last?.params.code, 500, "A transport failure is not a credential failure")
    XCTAssertEqual(self.session.invalidateCalls, 0)
    XCTAssertFalse(portalConnect.connected)
  }

  func test_connect_willConnect_whenCredentialValid() {
    portalConnect.connect(mockURL)

    XCTAssertTrue(mockClient.isConnected)
    XCTAssertEqual(mockClient.uri, self.mockURL)
    XCTAssertEqual(self.errorEvents.count, 0)
  }

  func test_connect_willNotResolveCredential_whenAlreadyConnectedToSameUri() {
    portalConnect.connect(mockURL)
    let tokenCallsAfterFirstConnect = self.session.getTokenCalls

    portalConnect.connect(mockURL)

    XCTAssertEqual(mockClient.connectCallsCount, 1, "A repeat connect to the same uri is ignored")
    XCTAssertEqual(self.session.getTokenCalls, tokenCallsAfterFirstConnect)
  }

  func test_connect_calledTwice_afterInvalidation_willReportOnce() async throws {
    let engine = FakeWebSocketEngine()
    let client = PortalSwift.WebSocketClient(
      credentials: session,
      connect: portalConnect,
      webSocketServer: "wss://connect.portalhq.io",
      engine: engine
    )
    portalConnect.client = client
    let recorder = try XCTUnwrap(self.recorder)
    try self.session.invalidate()

    portalConnect.connect(mockURL)
    portalConnect.connect(mockURL)

    XCTAssertEqual(self.errorEvents.count, 2, "Every attempt is surfaced to the host's error handler")
    XCTAssertEqual(self.errorEvents.last?.params.code, 401)
    let notified = await waitUntil { recorder.count == 1 }
    XCTAssertTrue(notified)
    XCTAssertLessThanOrEqual(recorder.count, 1, "The session-ended notification is once per credential")
    // One invalidation from this test plus one per report: only the announcement is deduplicated.
    XCTAssertEqual(self.session.invalidateCalls, 3)
    XCTAssertEqual(engine.startCallsCount, 0)
  }

  func test_connect_errorEvent_willNotContainToken() {
    mockClient.connectThrows = PortalCredentialError.sessionInvalidated

    portalConnect.connect(mockURL)

    let message = self.errorEvents.last?.params.message
    XCTAssertNotNil(message, "The assertion would be vacuous without an emitted error")
    XCTAssertFalse(message?.contains(connectToken) ?? true, "The credential must never reach the host's error message")
    self.logger.assertNoSecret(connectToken)
  }

  func test_disconnect_afterCredentialFailure_willNotCrash() {
    mockClient.connectThrows = PortalCredentialError.sessionInvalidated
    portalConnect.connect(mockURL)

    portalConnect.disconnect(true)

    XCTAssertFalse(portalConnect.connected)
    XCTAssertEqual(self.errorEvents.count, 1)
  }
}
