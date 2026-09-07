//
//  WebSocketClient.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc. on 4/27/23.
//

import Foundation
import Starscream

enum WebSocketTypeErrors: LocalizedError {
  case MismatchedTypeMessage
}

/// Failures raised by `WebSocketClient` itself, as opposed to errors surfaced by Starscream.
///
/// Kept apart from `PortalCredentialError` so `PortalConnect` and the reconnect path can tell
/// "the credential is dead" (report it, emit code 401, never retry) from "this client is
/// misconfigured" (emit code 500). The description is a fixed literal: the server string a host
/// passed in is never echoed, so a malformed URL cannot smuggle anything into a log line.
enum WebSocketClientError: LocalizedError {
  /// `webSocketServer` did not parse as a `ws://` or `wss://` URL with a host.
  case invalidServerUrl

  var errorDescription: String? {
    switch self {
    case .invalidServerUrl:
      return "WebSocketClient - The web socket server URL is not a valid ws:// or wss:// URL."
    }
  }
}

public enum ConnectState {
  case connected
  case connecting
  case disconnected
  case disconnecting
}

struct EventHandlers {
  var close: [() -> Void]
  var dapp_session_requested: [(ConnectData) -> Void]
  var connected: [(ConnectedData) -> Void]
  var disconnect: [(DisconnectData) -> Void]
  var error: [(ConnectError) -> Void]
  var session_request: [(SessionRequestData) -> Void]
  var session_request_address: [(SessionRequestAddressData) -> Void]
  var session_request_transaction: [(SessionRequestTransactionData) -> Void]
  var portal_connect_error: [(ErrorData) -> Void]

  init() {
    self.close = []
    self.dapp_session_requested = []
    self.connected = []
    self.disconnect = []
    self.session_request = []
    self.session_request_address = []
    self.session_request_transaction = []
    self.error = []
    self.portal_connect_error = []
  }
}

/// The wallet side of a Portal Connect session: a Starscream web socket to the Connect proxy
/// authenticated with the client's Portal credential.
///
/// The credential is resolved every time a connection is opened, never at construction and
/// never cached, so a session that rotates or is invalidated underneath a long-lived
/// `PortalConnect` is picked up by the next connect or reconnect for free. A proxy that rejects
/// the upgrade with HTTP 401 is treated as terminal: the credential is reported through the
/// credentials layer, the client settles in `.disconnected`, and no reconnect is attempted,
/// because retrying with the same dead credential can only fail the same way. Every other drop
/// goes through one bounded, exponentially backed-off reconnect budget ported from the Android
/// SDK so a flapping network cannot spin the client forever.
public class WebSocketClient: Starscream.WebSocketDelegate {
  /// The reconnect budget: how many times a dropped connection is retried and how long each
  /// attempt waits.
  ///
  /// Delays double from `baseDelayNs` up to `maxDelayNs`, so a proxy that is briefly unreachable
  /// is retried quickly while a prolonged outage is not hammered. The defaults (5 attempts,
  /// 500 ms, 8 s) mirror the Android SDK. Injectable so tests can exercise the budget without
  /// waiting on real time.
  struct ReconnectPolicy {
    /// Attempts allowed since the last successful `connected` handshake before giving up.
    let maxAttempts: Int
    /// The delay before the first retry, in nanoseconds.
    let baseDelayNs: UInt64
    /// The ceiling for any single delay, in nanoseconds.
    let maxDelayNs: UInt64

    /// The production budget.
    static let `default` = ReconnectPolicy()

    init(maxAttempts: Int = 5, baseDelayNs: UInt64 = 500_000_000, maxDelayNs: UInt64 = 8_000_000_000) {
      self.maxAttempts = maxAttempts
      self.baseDelayNs = baseDelayNs
      self.maxDelayNs = maxDelayNs
    }

    /// The delay before reconnect attempt number `attempts` (zero-based): `base << attempts`,
    /// capped at `maxDelayNs`. Doubles step by step instead of shifting so a large attempt count
    /// can never overflow into a zero or tiny delay.
    func delay(forAttempt attempts: Int) -> UInt64 {
      var delay = self.baseDelayNs
      var remaining = attempts
      while remaining > 0, delay < self.maxDelayNs {
        delay = delay > self.maxDelayNs / 2 ? self.maxDelayNs : delay * 2
        remaining -= 1
      }
      return min(delay, self.maxDelayNs)
    }
  }

  public var isConnected: Bool {
    self.connectState == .connected || self.connectState == .connecting
  }

  public var topic: String?
  public var connectState: ConnectState = .disconnected

  /// The credential every upgrade request is authenticated with. Resolved per connect through
  /// `resolveCredentialToken(_:)`; the raw token is never stored on this object.
  let credentials: PortalCredentials

  /// The WalletConnect URI of the current (or last requested) session. Set by `connect(uri:)`
  /// and read back by the connect handshake and by every reconnect.
  var uri: String?

  /// The keep-alive timer started by the connect handshake. Readable so tests can assert it is
  /// invalidated on every terminal path.
  private(set) var pingTimer: Timer?

  /// How many reconnects have been started since the last successful `connected` handshake.
  /// Reset to zero by `handleConnect()`; when it reaches `reconnectPolicy.maxAttempts` the next
  /// drop gives up instead of retrying.
  private(set) var reconnectAttempts: Int {
    get {
      self.reconnectLock.lock()
      defer { self.reconnectLock.unlock() }
      return self._reconnectAttempts
    }
    set {
      self.reconnectLock.lock()
      defer { self.reconnectLock.unlock() }
      self._reconnectAttempts = newValue
    }
  }

  private let connect: PortalConnect
  private var events = EventHandlers()
  private let decoder = JSONDecoder()
  private let logger = PortalLogger.shared
  private let webSocketServer: String
  private let engine: Engine?
  private var socket: Starscream.WebSocket?
  private let reconnectPolicy: ReconnectPolicy
  private let sleep: (UInt64) async throws -> Void
  private let reconnectLock = NSLock()
  private var _reconnectAttempts = 0
  private var isReconnecting = false

  /// Characters a web socket host may contain. Anything else (whitespace, `/`, `@`, `%`) means
  /// the server string is not a URL this client should try to open.
  private static let hostCharacters: CharacterSet = {
    var set = CharacterSet.alphanumerics
    set.insert(charactersIn: ".-_:[]")
    return set
  }()

  /// Creates a client for `connect` that authenticates with `credentials`.
  ///
  /// Nothing is resolved here: the socket is created against a credential-less request so the
  /// engine exists for the lifetime of the client, and `connect(uri:)` swaps in a freshly built
  /// upgrade request every time it opens a connection. `engine`, `reconnectPolicy` and `sleep`
  /// are test seams; production callers leave them at their defaults.
  init(
    credentials: PortalCredentials,
    connect: PortalConnect,
    webSocketServer: String = "wss://connect.portalhq.io",
    engine: Engine? = nil,
    reconnectPolicy: ReconnectPolicy = .default,
    sleep: ((UInt64) async throws -> Void)? = nil
  ) {
    self.credentials = credentials
    self.connect = connect
    self.webSocketServer = webSocketServer
    self.engine = engine
    self.reconnectPolicy = reconnectPolicy
    self.sleep = sleep ?? { nanoseconds in try await Task.sleep(nanoseconds: nanoseconds) }

    if let url = Self.serverUrl(from: webSocketServer) {
      var request = URLRequest(url: url)
      request.timeoutInterval = 5
      let socket = Self.makeSocket(request: request, engine: engine)
      socket.delegate = self
      self.socket = socket
    }
  }

  /// Wraps a Client API Key in `StaticCredentials`. Kept non-throwing like the original, so a
  /// blank key is not rejected here but fails at the first `connect(uri:)` with
  /// `PortalCredentialError.unavailable`.
  @available(*, deprecated, message: "Use init(credentials:connect:webSocketServer:) instead; the apiKey is wrapped in StaticCredentials and a blank key fails at connect time with PortalCredentialError.unavailable.")
  convenience init(
    apiKey: String,
    connect: PortalConnect,
    webSocketServer: String = "wss://connect.portalhq.io",
    engine: Engine? = nil
  ) {
    self.init(
      credentials: StaticCredentials(apiKey),
      connect: connect,
      webSocketServer: webSocketServer,
      engine: engine
    )
  }

  deinit {
    assert(
      isConnected == false,
      "[WebSocketClient] sendFinalMessageAndDisconnect must be called before deallocating the WebSocketManager"
    )
    connectState = .disconnected
    pingTimer?.invalidate()
  }

  func resetEventBus() {
    self.events = EventHandlers()
  }

  func close() {
    self.connectState = .disconnected
    self.pingTimer?.invalidate()
    self.socket?.disconnect(closeCode: 1000)
  }

  /// Builds the HTTP upgrade request for the proxy with a freshly resolved bearer.
  ///
  /// Called on every connect and reconnect so a rotated session token is sent without rebuilding
  /// the client, and so an invalidated one fails here — before any socket is touched — with a
  /// `PortalCredentialError` the caller can act on. The server URL is validated first (local
  /// validation before credential access) and the token travels only in the `Authorization`
  /// header, never in the URL.
  func buildUpgradeRequest() throws -> URLRequest {
    guard let url = Self.serverUrl(from: self.webSocketServer) else {
      throw WebSocketClientError.invalidServerUrl
    }

    let token = try resolveCredentialToken(self.credentials)

    var request = URLRequest(url: url)
    request.timeoutInterval = 5
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    return request
  }

  /// Opens a connection to the proxy for the WalletConnect session at `uri`.
  ///
  /// Throws `PortalCredentialError` when no usable credential is available and
  /// `WebSocketClientError.invalidServerUrl` when the client was built with a bad server string;
  /// in both cases nothing has been started and `connectState` is untouched. The upgrade request
  /// is rebuilt on every call so the bearer is always the current one.
  func connect(uri: String) throws {
    let request = try self.buildUpgradeRequest()
    guard let socket = self.socket else {
      throw WebSocketClientError.invalidServerUrl
    }

    self.uri = uri
    self.logger.info("WebSocketClient.connect() - Connecting to proxy...")
    socket.request = request
    socket.connect()
  }

  func disconnect(_ userInitiated: Bool = false) {
    self.connectState = .disconnecting

    do {
      self.logger.info("WebSocketClient.disconnect() - Disconnecting from proxy...")

      // Build the WebSocketRequest
      let request = WebSocketDisconnectRequest(
        event: "disconnect",
        data: DisconnectRequestData(
          topic: topic,
          userInitiated: userInitiated
        )
      )

      // JSON encode the WebSocketRequest
      let json = try JSONEncoder().encode(request)
      guard let message = String(data: json, encoding: .utf8) else {
        throw WebSocketTypeErrors.MismatchedTypeMessage
      }

      // Send the message
      self.socket?.write(string: message)
      self.connectState = .disconnected
      self.pingTimer?.invalidate()
      self.handleData(json)
    } catch {
      self.connectState = .disconnected
      self.pingTimer?.invalidate()
      self.logger.error("WebSocketClient.disconnect() - Error encoding outbound message. Could not send the disconnect message.")
    }
  }

  public func didReceive(event: Starscream.WebSocketEvent, client _: Starscream.WebSocketClient) {
    if case .pong = event {} // Do nothing for pong
    else {
      // Only the case name: the payload of `.connected`/`.error` can carry request headers.
      self.logger.debug("WebSocketClient.didReceive() - Received event: \(Self.eventName(event))")
    }
    // Handle incoming messages
    switch event {
    case .connected:
      self.handleConnect()
    case let .disconnected(reason, code):
      self.handleDisconnect(reason, code)
    case let .text(text):
      self.handleText(text)
    case let .binary(data):
      self.handleData(data)
    case .ping: break
    case .pong: break
    case .viabilityChanged: break
    case .reconnectSuggested:
      if self.isConnected {
        self.reconnect()
      }
    case .cancelled:
      self.connectState = .disconnected
      self.pingTimer?.invalidate()
    case let .error(error):
      self.handleError(error)
    case .peerClosed:
      if self.isConnected {
        self.reconnect()
      } else {
        self.pingTimer?.invalidate()
        self.connectState = .disconnected
      }
    }
  }

  func ping(interval: TimeInterval = 25.0) {
    self.pingTimer?.invalidate()
    self.pingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
      guard let self = self else { return }
      self.socket?.write(ping: Data())
    }
  }

  func handleConnect() {
    // Set the connection state
    self.connectState = .connecting
    // A completed handshake ends the current outage; the next drop starts a fresh budget.
    self.reconnectAttempts = 0

    self.logger.info("WebSocketClient.handleConnect() - Connected to proxy service. Sending connect message...")

    guard let address = connect.address else {
      self.logger.warn("WebSocketClient.handleConnect() - No address found in keychain. Ignoring connect event...")
      return
    }
    guard let uri = self.uri else {
      self.logger.warn("WebSocketClient.handleConnect() - No session uri to connect to. Ignoring connect event...")
      return
    }

    do {
      // Build the WebSocketRequest
      let request = WebSocketConnectRequest(
        event: "connect",
        data: ConnectRequestData(
          address: address,
          chainId: connect.chainId,
          uri: uri
        )
      )

      // JSON encode the WebSocketRequest
      let json = try JSONEncoder().encode(request)
      guard let message = String(data: json, encoding: .utf8) else {
        throw WebSocketTypeErrors.MismatchedTypeMessage
      }

      // Send the connection request to the proxy service
      self.send(message)
      self.ping(interval: 10)
    } catch {
      self.logger.error("WebSocketClient.handleConnect() - Error encoding the connect message: \(type(of: error))")
    }
  }

  func handleData(_ data: Data) {
    if let payload = try? decoder.decode(WebSocketSessionRequestMessage.self, from: data) {
      self.emit(payload.event, payload.data)
      return
    } else if let payload = try? decoder.decode(WebSocketDappSessionRequestMessage.self, from: data) {
      self.emit(payload.event, payload.data)
      return
    } else if let payload = try? decoder.decode(WebSocketSessionRequestAddressMessage.self, from: data) {
      self.emit(payload.event, payload.data)
      return
    } else if let payload = try? decoder.decode(WebSocketSessionRequestAddressMessage.self, from: data) {
      self.emit(payload.event, payload.data)
      return
    } else if let payload = try? decoder.decode(WebSocketSessionRequestTransactionMessage.self, from: data) {
      self.emit(payload.event, payload.data)
      return
    } else if let payload = try? decoder.decode(WebSocketConnectedMessage.self, from: data), payload.event == "connected" {
      self.connectState = .connected
      self.emit(payload.event, payload.data)
      return
    } else if let payload = try? decoder.decode(WebSocketDisconnectMessage.self, from: data), payload.event == "disconnect" {
      self.connectState = .disconnected
      self.emit(payload.event, payload.data)
      return
    } else if let payload = try? decoder.decode(WebSocketErrorMessage.self, from: data), payload.event == "portal_connectError" {
      self.emit(payload.event, payload.data)
      return
    }

    self.logger.info("⚠️ WebSocketClient.handleData() - Received unparsable event. Ignoring.")
  }

  func handleDisconnect(_ reason: String, _ code: UInt16) {
    self.connectState = .disconnected
    self.pingTimer?.invalidate()
    self.logger.info("WebSocketClient.handleDisconnect() - Websocket is disconnected: \(reason) with code: \(code)")
    self.socket?.disconnect(closeCode: 1000)
  }

  /// Handles a Starscream `.error` event.
  ///
  /// Three outcomes: an upgrade rejected with 401 is terminal (report the credential, settle in
  /// `.disconnected`, emit code 401, never reconnect — the same credential would only be
  /// rejected again); a peer reset while connected goes through the bounded `reconnect()`
  /// budget; anything else (other upgrade codes, transport failures, `nil`) emits code 500 and
  /// settles in `.disconnected`, exactly as before. Only the error's type and, for an upgrade
  /// rejection, its status code are logged: the headers Starscream attaches to
  /// `notAnUpgrade` are never printed.
  func handleError(_ error: (any Error)?) {
    if let upgradeError = error as? HTTPUpgradeError, case let .notAnUpgrade(statusCode, _) = upgradeError {
      self.logger.error("WebSocketClient.handleError() - The upgrade request was rejected with status \(statusCode).")

      if statusCode == 401 {
        self.logger.warn("WebSocketClient.handleError() - Credential rejected by the proxy. Not reconnecting.")
        reportUnauthorizedAndLog(self.credentials, context: "WebSocketClient.handleError")
        self.pingTimer?.invalidate()
        self.connectState = .disconnected
        self.emit("error", ConnectError(message: "401 - Unauthorized", code: 401))
        self.socket?.disconnect(closeCode: 1000)
        return
      }
    } else if let error = error {
      self.logger.error("WebSocketClient.handleError() - Received error: \(type(of: error))")
    } else {
      self.logger.error("WebSocketClient.handleError() - Received an unknown error.")
    }

    if let error = error, Self.isPeerReset(error), self.isConnected {
      self.logger.warn("WebSocketClient.handleError() - Connection reset by peer. Attempting reconnect...")
      self.reconnect()
      return
    }

    self.pingTimer?.invalidate()
    self.connectState = .disconnected
    self.emit("error", ConnectError(message: error?.localizedDescription ?? "An unknown error occurred.", code: 500))
    self.socket?.disconnect(closeCode: 1000)
  }

  func handleText(_ text: String) {
    // Get the raw data of the text
    guard let data = text.data(using: .utf8) else {
      self.logger.warn("WebSocketClient.handleText() - Received text that could not be encoded as UTF-8. Ignoring.")
      return
    }

    // Handle the request in `handleData()`
    self.handleData(data)
  }

  func emit(_ event: String, _ data: ConnectData) {
    // Get the list of event handlers for this event
    let eventHandlers = self.events.dapp_session_requested

    // Ensure there's something to invoke
    if eventHandlers.count > 0 {
      // Loop through the event handlers
      for handler in eventHandlers {
        // Invoke the handler
        handler(data)
      }
    } else {
      // Ignore the event
      self.logger.debug("[WebSocketClient] No registered event handlers for \(event). Ignoring...")
    }
  }

  func emit(_ event: String, _ data: ConnectedData) {
    // Get the list of event handlers for this event
    let eventHandlers = self.events.connected

    // Ensure there's something to invoke
    if eventHandlers.count > 0 {
      // Loop through the event handlers
      for handler in eventHandlers {
        // Invoke the handler
        handler(data)
      }
    } else {
      // Ignore the event
      self.logger.debug("[WebSocketClient] No registered event handlers for \(event). Ignoring...")
    }
  }

  func emit(_ event: String, _ data: DisconnectData) {
    // Get the list of event handlers for this event
    let eventHandlers = self.events.disconnect

    // Ensure there's something to invoke
    if eventHandlers.count > 0 {
      // Loop through the event handlers
      for handler in eventHandlers {
        // Invoke the handler
        handler(data)
      }
    } else {
      // Ignore the event
      self.logger.debug("[WebSocketClient] No registered event handlers for \(event). Ignoring...")
    }
  }

  func emit(_ event: String, _ data: ConnectError) {
    let eventHandlers = self.events.error

    // Ensure there's something to invoke
    if eventHandlers.count > 0 {
      // Loop through the event handlers
      for handler in eventHandlers {
        // Invoke the handler
        handler(data)
      }
    } else {
      // Ignore the event
      self.logger.debug("[WebSocketClient] No registered event handlers for \(event). Ignoring...")
    }
  }

  func emit(_ event: String, _ data: ErrorData) {
    let eventHandlers = self.events.portal_connect_error

    // Ensure there's something to invoke
    if eventHandlers.count > 0 {
      // Loop through the event handlers
      for handler in eventHandlers {
        // Invoke the handler
        handler(data)
      }
    } else {
      // Ignore the event
      self.logger.debug("[WebSocketClient] No registered event handlers for \(event). Ignoring...")
    }
  }

  func emit(_ event: String, _ data: SessionRequestData) {
    // Get the list of event handlers for this event
    let eventHandlers = self.events.session_request

    // Ensure there's something to invoke
    if eventHandlers.count > 0 {
      // Loop through the event handlers
      for handler in eventHandlers {
        self.logger.debug("[WebSocketClient] data: \(String(describing: data))")
        // Invoke the handler
        handler(data)
      }
    } else {
      // Ignore the event
      self.logger.debug("[WebSocketClient] No registered event handlers for \(event). Ignoring...")
    }
  }

  func emit(_ event: String, _ data: SessionRequestAddressData) {
    // Get the list of event handlers for this event
    let eventHandlers = self.events.session_request_address

    // Ensure there's something to invoke
    if eventHandlers.count > 0 {
      // Loop through the event handlers
      for handler in eventHandlers {
        // Invoke the handler
        handler(data)
      }
    } else {
      // Ignore the event
      self.logger.debug("[WebSocketClient] No registered event handlers for \(event). Ignoring...")
    }
  }

  func emit(_ event: String, _ data: SessionRequestTransactionData) {
    // Get the list of event handlers for this event
    let eventHandlers = self.events.session_request_transaction

    // Ensure there's something to invoke
    if eventHandlers.count > 0 {
      // Loop through the event handlers
      for handler in eventHandlers {
        // Invoke the handler
        handler(data)
      }
    } else {
      // Ignore the event
      self.logger.debug("[WebSocketClient] No registered event handlers for \(event). Ignoring...")
    }
  }

  func on(_: String, _ handler: @escaping (ConnectData) -> Void) {
    // Add event handler to the list
    self.events.dapp_session_requested.append(handler)
  }

  func on(_: String, _ handler: @escaping (ConnectedData) -> Void) {
    // Add event handler to the list
    self.events.connected.append(handler)
  }

  func on(_: String, _ handler: @escaping () -> Void) {
    // Add event handler to the list
    self.events.close.append(handler)
  }

  func on(_: String, _ handler: @escaping (DisconnectData) -> Void) {
    // Add event handler to the list
    self.events.disconnect.append(handler)
  }

  func on(_: String, _ handler: @escaping (SessionRequestData) -> Void) {
    // Add event handler to the list
    self.events.session_request.append(handler)
  }

  func on(_: String, _ handler: @escaping (SessionRequestAddressData) -> Void) {
    // Add event handler to the list
    self.events.session_request_address.append(handler)
  }

  func on(_: String, _ handler: @escaping (SessionRequestTransactionData) -> Void) {
    // Add event handler to the list
    self.events.session_request_transaction.append(handler)
  }

  func on(_: String, _ handler: @escaping (ErrorData) -> Void) {
    // Add event handler to the list
    self.events.portal_connect_error.append(handler)
  }

  func on(_: String, _ handler: @escaping (ConnectError) -> Void) {
    // Add event handler to the list
    self.events.error.append(handler)
  }

  func off(_ event: String) {
    switch event {
    case "close":
      self.events.close = []
    case "connected":
      self.events.connected = []
    case "portal_dappSessionRequested":
      self.events.dapp_session_requested = []
    case "disconnected":
      self.events.disconnect = []
    case "error":
      self.events.error = []
    case "portal_connectError":
      self.events.portal_connect_error = []
    case "session_request":
      self.events.session_request = []
    case "session_request_address":
      self.events.session_request_address = []
    case "session_request_transaction":
      self.events.session_request_transaction = []
    default:
      break
    }
  }

  func send(_ message: String) {
    self.logger.debug("[WebSocketClient] Sending message: \(message)")
    self.socket?.write(string: message)
  }

  func send(_ data: Data) {
    self.socket?.write(data: data)
  }

  func sendFinalMessageAndDisconnect() {
    self.connectState = .disconnecting

    do {
      self.logger.debug("WebSocketClient.sendFinalMessageAndDisconnect() - Sending final message before deallocation...")

      // Write your last message here
      let request = WebSocketDisconnectRequest(
        event: "disconnect",
        data: DisconnectRequestData(
          topic: topic,
          userInitiated: false
        )
      )

      // JSON encode the WebSocketRequest
      let json = try JSONEncoder().encode(request)
      guard let message = String(data: json, encoding: .utf8) else {
        throw WebSocketTypeErrors.MismatchedTypeMessage
      }

      self.socket?.write(string: message) {
        self.logger.debug("WebSocketClient.sendFinalMessageAndDisconnect() - Final message sent! Disconnecting...")
        // Close the connection
        self.socket?.disconnect()
        self.connectState = .disconnected
      }
    } catch {
      self.logger.error("WebSocketClient.sendFinalMessageAndDisconnect() - Unable to encode disconnect message. Failed to disconnect.")
    }
  }

  /*******************************************
   * Private functions
   *******************************************/

  /// The single reconnect path for `.reconnectSuggested`, `.peerClosed` and a peer reset.
  ///
  /// Non-throwing by design: it is called from delegate callbacks that cannot propagate. One
  /// reconnect is in flight at a time — a second drop that arrives while the first is still
  /// sleeping is ignored, so back-to-back events cannot multiply connections. Each call consumes
  /// one attempt from the budget; once `reconnectPolicy.maxAttempts` are used the client gives
  /// up with `ConnectError(message: "Reconnect attempts exhausted", code: 500)`. Otherwise it
  /// waits `reconnectPolicy.delay(forAttempt:)` and re-enters `connect(uri:)`, which resolves
  /// the credential again. A `PortalCredentialError` there is terminal (reported, code 401, no
  /// further retry); any other failure emits code 500. Whatever happens, `connectState` ends in
  /// `.disconnected` until the proxy actually answers with `.connected`.
  private func reconnect() {
    guard let uri = self.uri else {
      self.logger.warn("WebSocketClient.reconnect() - No session uri to reconnect to. Staying disconnected.")
      self.pingTimer?.invalidate()
      self.connectState = .disconnected
      return
    }

    self.reconnectLock.lock()
    if self.isReconnecting {
      self.reconnectLock.unlock()
      self.logger.debug("WebSocketClient.reconnect() - A reconnect is already in flight. Ignoring.")
      return
    }
    let attempts = self._reconnectAttempts
    let exhausted = attempts >= self.reconnectPolicy.maxAttempts
    if !exhausted {
      self.isReconnecting = true
      self._reconnectAttempts = attempts + 1
    }
    self.reconnectLock.unlock()

    // Whatever happens next, the connection we had is gone.
    self.pingTimer?.invalidate()
    self.connectState = .disconnected

    guard !exhausted else {
      self.logger.warn("WebSocketClient.reconnect() - Reconnect attempts exhausted after \(attempts) attempts. Giving up.")
      self.emit("error", ConnectError(message: "Reconnect attempts exhausted", code: 500))
      return
    }

    let delay = self.reconnectPolicy.delay(forAttempt: attempts)
    self.logger.info("WebSocketClient.reconnect() - Scheduling reconnect attempt \(attempts + 1) of \(self.reconnectPolicy.maxAttempts).")

    // Starscream's engine refuses to start while it still believes the previous connection is
    // open (a peer close leaves it in that state); closing it first lets the fresh start go out.
    self.socket?.disconnect(closeCode: 1000)

    Task { [weak self] in
      guard let self = self else { return }
      defer { self.finishReconnect() }

      do {
        try await self.sleep(delay)
        try self.connect(uri: uri)
      } catch let error as PortalCredentialError {
        self.handleReconnectCredentialFailure(error)
      } catch {
        self.logger.error("WebSocketClient.reconnect() - Reconnect failed: \(type(of: error))")
        self.pingTimer?.invalidate()
        self.connectState = .disconnected
        self.emit("error", ConnectError(message: error.localizedDescription, code: 500))
      }
    }
  }

  /// A dead credential discovered while reconnecting: report it once through the credentials
  /// layer, settle in `.disconnected` and tell the host with code 401. Not retried, because
  /// the next attempt would resolve the same dead credential.
  private func handleReconnectCredentialFailure(_ error: PortalCredentialError) {
    self.logger.error("WebSocketClient.reconnect() - Credential unavailable (\(error.reason?.rawValue ?? "INVALID_API_KEY")). Not retrying.")
    reportUnauthorizedAndLog(self.credentials, context: "WebSocketClient.reconnect")
    self.pingTimer?.invalidate()
    self.connectState = .disconnected
    self.emit("error", ConnectError(message: "401 - Unauthorized", code: 401))
  }

  private func finishReconnect() {
    self.reconnectLock.lock()
    defer { self.reconnectLock.unlock() }
    self.isReconnecting = false
  }

  /// Starscream reports a TCP reset as a generic error; the text is the only handle it gives us.
  private static func isPeerReset(_ error: Error) -> Bool {
    error.localizedDescription == "The operation couldn’t be completed. Connection reset by peer"
  }

  /// Parses `server` as a `ws://`/`wss://` URL with a plausible host, or returns `nil`.
  ///
  /// `URL(string:)` alone is not enough: newer Foundation versions percent-encode invalid
  /// characters instead of failing, so a host containing whitespace would otherwise be accepted
  /// and only fail deep inside the transport.
  private static func serverUrl(from server: String) -> URL? {
    guard let components = URLComponents(string: server),
          let scheme = components.scheme?.lowercased(),
          scheme == "ws" || scheme == "wss",
          let host = components.host,
          !host.isEmpty,
          host.unicodeScalars.allSatisfy({ Self.hostCharacters.contains($0) }),
          let url = components.url
    else {
      return nil
    }
    return url
  }

  /// Builds the Starscream socket, on the injected engine when a test supplied one.
  private static func makeSocket(request: URLRequest, engine: Engine?) -> Starscream.WebSocket {
    if let engine = engine {
      return Starscream.WebSocket(request: request, engine: engine)
    }
    return Starscream.WebSocket(request: request)
  }

  /// The case name of `event` without its payload, for logging.
  private static func eventName(_ event: Starscream.WebSocketEvent) -> String {
    switch event {
    case .connected: return "connected"
    case .disconnected: return "disconnected"
    case .text: return "text"
    case .binary: return "binary"
    case .pong: return "pong"
    case .ping: return "ping"
    case .error: return "error"
    case .viabilityChanged: return "viabilityChanged"
    case .reconnectSuggested: return "reconnectSuggested"
    case .cancelled: return "cancelled"
    case .peerClosed: return "peerClosed"
    }
  }
}
