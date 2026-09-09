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
/// "the credential is unusable" (emit code 401, never retry) from "this client is
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
  /// `PortalCredentialSupport.resolveToken(_:)`; the raw token is never stored on this object.
  let credentials: PortalCredentials

  /// The WalletConnect URI of the current (or last requested) session. Set by `connect(uri:)`
  /// and read back by the connect handshake and by every reconnect.
  var uri: String?

  /// The keep-alive timer started by the connect handshake. Readable so tests can assert it is
  /// invalidated on every terminal path.
  private(set) var pingTimer: Timer?

  /// How many reconnects have been started since the last successful `connected` handshake.
  /// Reset to zero when `handleData()` receives the proxy's `connected` message — not when the
  /// transport upgrade completes in `handleConnect()`, or a proxy that accepts every upgrade and
  /// drops the socket during the handshake would refill the budget on each drop and reconnect
  /// forever. When it reaches `reconnectPolicy.maxAttempts` the next drop gives up instead of
  /// retrying.
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

  /// The socket of the current or most recent connection. Rebuilt by `openConnection(uri:)` on
  /// every connect — see there for why a socket is never reused.
  private var socket: Starscream.WebSocket?
  private let reconnectPolicy: ReconnectPolicy
  private let sleep: (UInt64) async throws -> Void
  private let reconnectLock = NSLock()
  private var _reconnectAttempts = 0
  private var isReconnecting = false

  /// The backoff task scheduled by `reconnect()`, kept so `disconnect(_:)`, `close()`,
  /// `sendFinalMessageAndDisconnect()`, a host-initiated `connect(uri:)` and `deinit` can cancel
  /// it. Without this a socket the host closed during the backoff would silently re-open when
  /// the task woke — the pre-7.5 client reconnected synchronously, so no such window existed.
  /// Guarded by `reconnectLock`.
  private var reconnectTask: Task<Void, Never>?

  /// Bumped every time a reconnect is scheduled or cancelled, and captured by the task it
  /// belongs to, so a stale task's `finishReconnect` cannot clear bookkeeping that now belongs
  /// to a newer one. Guarded by `reconnectLock`.
  private var reconnectGeneration = 0

  /// `true` from the moment a reconnect attempt calls `openConnection(uri:)` until the proxy
  /// accepts the upgrade (`handleConnect`) or the attempt fails. It lets the delegate paths tell
  /// "the retry itself could not reach the proxy" — which must consume the next attempt from the
  /// budget — from an ordinary drop while already disconnected, which must not. Without it the
  /// budget was unreachable for exactly the common outage: `reconnect()` sets `.disconnected`,
  /// every re-entry is gated on `isConnected`, so a retry that failed at the transport emitted
  /// code 500 and stopped after one attempt. Guarded by `reconnectLock`.
  private var _isRetryInFlight = false

  private var isRetryInFlight: Bool {
    get {
      self.reconnectLock.lock()
      defer { self.reconnectLock.unlock() }
      return self._isRetryInFlight
    }
    set {
      self.reconnectLock.lock()
      defer { self.reconnectLock.unlock() }
      self._isRetryInFlight = newValue
    }
  }

  /// Characters a web socket host may contain. Anything else (whitespace, `/`, `@`, `%`) means
  /// the server string is not a URL this client should try to open.
  private static let hostCharacters: CharacterSet = {
    var set = CharacterSet.alphanumerics
    set.insert(charactersIn: ".-_:[]")
    return set
  }()

  /// Creates a client for `connect` that authenticates with `credentials`.
  ///
  /// Nothing is resolved and no socket exists yet: `connect(uri:)` builds a fresh upgrade request
  /// and a fresh Starscream socket every time it opens a connection (see `openConnection(uri:)`).
  /// `engine`, `reconnectPolicy` and `sleep` are test seams; production callers leave them at
  /// their defaults.
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
    // A backoff task holds `self` weakly, so it cannot keep the client alive — but it could
    // still wake and touch a dead socket. Cancel it with the client.
    reconnectTask?.cancel()
    connectState = .disconnected
    pingTimer?.invalidate()
  }

  func resetEventBus() {
    self.events = EventHandlers()
  }

  func close() {
    self.cancelPendingReconnect()
    // A close frame only after the upgrade; before it Starscream's `stop()` is a silent no-op, so
    // a connection that never got that far is cancelled at the transport instead.
    let wasUpgraded = self.isConnected
    self.connectState = .disconnected
    self.pingTimer?.invalidate()
    if wasUpgraded {
      self.socket?.disconnect(closeCode: 1000)
    } else {
      self.socket?.forceDisconnect()
    }
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

    let token = try PortalCredentialSupport.resolveToken(self.credentials)

    var request = URLRequest(url: url)
    request.timeoutInterval = 5
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    return request
  }

  /// Opens a connection to the proxy for the WalletConnect session at `uri`, on the host's
  /// initiative.
  ///
  /// Any reconnect still sleeping in its backoff is cancelled first: the host's request
  /// supersedes it, and letting the old task wake would clobber `uri` with the previous
  /// session's and re-open a connection nobody asked for. Throws `PortalCredentialError` when no
  /// usable credential is available and `WebSocketClientError.invalidServerUrl` when the client
  /// was built with a bad server string; in both cases nothing has been started and
  /// `connectState` is untouched. The upgrade request is rebuilt on every call so the bearer is
  /// always the current one.
  func connect(uri: String) throws {
    self.cancelPendingReconnect()
    try self.openConnection(uri: uri)
  }

  /// The shared body of `connect(uri:)` and a reconnect attempt: build the upgrade request with
  /// a freshly resolved bearer, record `uri`, and start a **new** socket. Does not touch the
  /// pending reconnect bookkeeping, so the reconnect task can call it without cancelling itself.
  ///
  /// A new socket every time, never `connect()` on the old one. Starscream's `WSEngine` ignores
  /// `start` while it believes it is still connecting, and only a completed upgrade, a transport
  /// cancellation or `forceStop()` clears that. A failure *before* the upgrade — proxy
  /// unreachable, DNS, or an HTTP 401 — runs the engine's `stop()`, whose close-frame write is
  /// skipped because nothing was ever writable, so the engine stays "connecting" and every later
  /// `connect()` on that socket returns silently with no delegate event. That is exactly where
  /// every reconnect attempt and every post-401 `connect(uri:)` starts from, so reusing the socket
  /// made the retry budget a single attempt and a rejected credential permanent for the client.
  ///
  /// The previous socket is detached first, so a late event from it (its own `.cancelled`, for
  /// one) cannot be mistaken for the new connection's, then force-stopped so its transport does
  /// not linger.
  private func openConnection(uri: String) throws {
    let request = try self.buildUpgradeRequest()

    self.uri = uri
    self.logger.info("WebSocketClient.connect() - Connecting to proxy...")

    if let previous = self.socket {
      previous.delegate = nil
      previous.forceDisconnect()
    }
    let socket = Self.makeSocket(request: request, engine: self.engine)
    socket.delegate = self
    self.socket = socket
    socket.connect()
  }

  func disconnect(_ userInitiated: Bool = false) {
    // A host-initiated disconnect must stay disconnected: drop any reconnect still waiting in
    // its backoff before it can wake and undo this.
    self.cancelPendingReconnect()
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
      if self.isRetryInFlight {
        // The retry attempt itself was cancelled at the transport before the proxy answered:
        // that is a failed attempt, so walk the budget rather than settling silently.
        self.logger.warn("WebSocketClient.didReceive() - The reconnect attempt was cancelled before the proxy answered. Scheduling the next attempt...")
        self.reconnect()
      } else {
        self.connectState = .disconnected
        self.pingTimer?.invalidate()
      }
    case let .error(error):
      self.handleError(error)
    case .peerClosed:
      if self.isConnected || self.isRetryInFlight {
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
    // The upgrade went through, so the retry — if this was one — did reach the proxy. From here a
    // drop is an ordinary drop again (`isConnected` covers `.connecting`), not a failed attempt.
    self.isRetryInFlight = false

    // Set the connection state. The reconnect budget is *not* reset here: the upgrade completing
    // says nothing about whether the proxy will answer the connect message (see `handleData`).
    self.connectState = .connecting

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
      // The proxy's answer, not the transport upgrade, ends the outage; the next drop starts a
      // fresh budget. Resetting on the upgrade alone would let a proxy that drops the socket
      // during every handshake defeat the cap.
      self.reconnectAttempts = 0
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
  /// Four outcomes: an upgrade rejected with 401 is terminal (report the credential, settle in
  /// `.disconnected`, emit code 401, never reconnect — the same credential would only be
  /// rejected again); a peer reset while connected goes through the bounded `reconnect()`
  /// budget; any failure of a reconnect attempt that is still in flight (`isRetryInFlight`)
  /// also goes through the budget, so an unreachable proxy is retried up to
  /// `reconnectPolicy.maxAttempts` times rather than once; anything else (other upgrade codes,
  /// transport failures while idle, `nil`) emits code 500 and settles in `.disconnected`,
  /// exactly as before. Only the error's type and, for an upgrade rejection, its status code are
  /// logged: the headers Starscream attaches to `notAnUpgrade` are never printed. The socket is
  /// closed with a close frame when the upgrade had completed and cancelled at the transport
  /// otherwise — before the upgrade, Starscream's `stop()` is a silent no-op.
  func handleError(_ error: (any Error)?) {
    if let upgradeError = error as? HTTPUpgradeError, case let .notAnUpgrade(statusCode, _) = upgradeError {
      self.logger.error("WebSocketClient.handleError() - The upgrade request was rejected with status \(statusCode).")

      if statusCode == 401 {
        self.logger.warn("WebSocketClient.handleError() - Credential rejected by the proxy. Not reconnecting.")
        PortalCredentialSupport.reportUnauthorizedAndLog(self.credentials, context: "WebSocketClient.handleError")
        self.isRetryInFlight = false
        self.pingTimer?.invalidate()
        self.connectState = .disconnected
        self.emit("error", ConnectError(message: "401 - Unauthorized", code: 401))
        // The upgrade was refused, so a close frame has nowhere to go: cancel the transport.
        self.socket?.forceDisconnect()
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

    if self.isRetryInFlight {
      // The retry attempt could not reach the proxy (network down, DNS, refused). Consume the
      // next attempt instead of giving up after one; `reconnect()` emits the exhaustion error
      // itself once the budget is spent.
      self.logger.warn("WebSocketClient.handleError() - The reconnect attempt failed at the transport. Scheduling the next attempt...")
      self.reconnect()
      return
    }

    let wasUpgraded = self.isConnected
    self.pingTimer?.invalidate()
    self.connectState = .disconnected
    self.emit("error", ConnectError(message: error?.localizedDescription ?? "An unknown error occurred.", code: 500))
    if wasUpgraded {
      self.socket?.disconnect(closeCode: 1000)
    } else {
      self.socket?.forceDisconnect()
    }
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
    self.cancelPendingReconnect()
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
  /// waits `reconnectPolicy.delay(forAttempt:)` on the main actor — the queue Starscream
  /// delivers on, so state and emitted events never race a delegate callback — re-checks that
  /// nothing superseded it while it slept (a host `disconnect()` or `connect(uri:)` cancels the
  /// task; a changed `uri` or state means someone else already connected), marks the retry in
  /// flight, and re-enters `openConnection(uri:)`, which resolves the credential again. A
  /// `PortalCredentialError` there is terminal (code 401, no further retry, and not reported —
  /// see `handleReconnectCredentialFailure`); any other failure emits code 500. A retry whose
  /// socket then fails at the transport comes back here through the delegate paths while
  /// `isRetryInFlight` is set, which is what lets the budget be walked to exhaustion. Whatever
  /// happens, `connectState` ends in `.disconnected` until the proxy actually answers with
  /// `.connected`.
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
    // A new cycle starts: whatever attempt was in flight has resolved (that is how we got here).
    self._isRetryInFlight = false
    if !exhausted {
      self.isReconnecting = true
      self._reconnectAttempts = attempts + 1
      self.reconnectGeneration += 1
    }
    // Read once, after the bump, as a `let`: the reconnect Task below captures it, and Swift 5.10
    // (CI's compiler) rejects a captured `var` in a `@Sendable` closure even when never mutated.
    let generation = self.reconnectGeneration
    self.reconnectLock.unlock()

    // Whatever happens next, the connection we had is gone. Say goodbye to it — a close frame
    // when the upgrade had completed, a transport cancel otherwise (`stop()` is a no-op before
    // the upgrade). The retry does not depend on this: `openConnection(uri:)` starts a fresh
    // socket regardless.
    let wasUpgraded = self.isConnected
    self.pingTimer?.invalidate()
    self.connectState = .disconnected
    if wasUpgraded {
      self.socket?.disconnect(closeCode: 1000)
    } else {
      self.socket?.forceDisconnect()
    }

    guard !exhausted else {
      self.logger.warn("WebSocketClient.reconnect() - Reconnect attempts exhausted after \(attempts) attempts. Giving up.")
      self.emit("error", ConnectError(message: "Reconnect attempts exhausted", code: 500))
      return
    }

    let delay = self.reconnectPolicy.delay(forAttempt: attempts)
    self.logger.info("WebSocketClient.reconnect() - Scheduling reconnect attempt \(attempts + 1) of \(self.reconnectPolicy.maxAttempts).")

    let task = Task { @MainActor [weak self] in
      guard let self = self else { return }
      defer { self.finishReconnect(generation: generation) }

      do {
        try await self.sleep(delay)
      } catch {
        // Only cancellation can land here; the guard below handles it.
      }

      // Superseded while sleeping: the host disconnected or closed (task cancelled — every
      // host-initiated teardown and `connect(uri:)` goes through `cancelPendingReconnect`), or
      // connected to another session (`uri` changed). Do nothing — waking up to re-open a
      // connection nobody wants any more is exactly the bug this guards against. `connectState`
      // is deliberately not consulted: the socket this reconnect replaces was closed in
      // `reconnect()`, so nothing can legitimately move the state while the task sleeps.
      guard !Task.isCancelled else {
        self.logger.debug("WebSocketClient.reconnect() - Reconnect cancelled while waiting. Staying disconnected.")
        return
      }
      guard self.uri == uri else {
        self.logger.debug("WebSocketClient.reconnect() - Reconnect superseded by a newer session while waiting. Ignoring.")
        return
      }

      self.isRetryInFlight = true
      do {
        try self.openConnection(uri: uri)
      } catch let error as PortalCredentialError {
        self.isRetryInFlight = false
        self.handleReconnectCredentialFailure(error)
      } catch {
        self.isRetryInFlight = false
        self.logger.error("WebSocketClient.reconnect() - Reconnect failed: \(type(of: error))")
        self.pingTimer?.invalidate()
        self.connectState = .disconnected
        self.emit("error", ConnectError(message: error.localizedDescription, code: 500))
      }
    }

    self.reconnectLock.lock()
    if generation == self.reconnectGeneration {
      self.reconnectTask = task
      self.reconnectLock.unlock()
    } else {
      // Cancelled (host disconnect / connect) between scheduling and here: never let it run.
      self.reconnectLock.unlock()
      task.cancel()
    }
  }

  /// Drops the reconnect that is sleeping in its backoff, if any, and resets the in-flight
  /// bookkeeping so the delegate paths stop treating the next transport event as a failed
  /// attempt. Called by every host-initiated teardown and by a host-initiated `connect(uri:)`.
  private func cancelPendingReconnect() {
    self.reconnectLock.lock()
    let task = self.reconnectTask
    self.reconnectTask = nil
    self.isReconnecting = false
    self._isRetryInFlight = false
    self.reconnectGeneration += 1
    self.reconnectLock.unlock()
    task?.cancel()
  }

  /// A credential that could not be resolved while reconnecting: settle in `.disconnected` and
  /// tell the host with code 401. Not retried, because the next attempt would resolve the same
  /// credential.
  ///
  /// Not reported through the credentials layer either. No request was sent, so the proxy
  /// rejected nothing: a `.sessionInvalidated` was already reported by the 401 that ended the
  /// session (or is a host sign-out, silent by contract), and a `.providerFailure` or
  /// `.unavailable` from a host-written provider may be transient — invalidating it here would
  /// destroy a credential the host could have recovered. Only the upgrade 401 in `handleError`
  /// reports, which is the rule every other component follows for a local `PortalCredentialError`.
  private func handleReconnectCredentialFailure(_ error: PortalCredentialError) {
    self.logger.error("WebSocketClient.reconnect() - Credential unavailable (\(error.reason?.rawValue ?? "INVALID_API_KEY")). Not retrying.")
    self.pingTimer?.invalidate()
    self.connectState = .disconnected
    self.emit("error", ConnectError(message: "401 - Unauthorized", code: 401))
  }

  /// Clears the in-flight flag for the reconnect of `generation` only. A task that was cancelled
  /// or superseded (the generation moved on) must not clear state that now belongs to its
  /// successor.
  private func finishReconnect(generation: Int) {
    self.reconnectLock.lock()
    defer { self.reconnectLock.unlock() }
    guard generation == self.reconnectGeneration else {
      return
    }
    self.isReconnecting = false
    self.reconnectTask = nil
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
