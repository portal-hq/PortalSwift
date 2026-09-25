//
//  MockWebSocketClient.swift
//
//
//  Created by Portal Labs on 12/06/2024.
//
import Foundation

/// A `WebSocketClient` that never opens a socket.
///
/// `connect(uri:)` flips a private connect state to `.connecting` and, two seconds later, to
/// `.connected`, so a host or test can drive `PortalConnect` end to end without a proxy. Set
/// `connectThrows` to make the next connect fail exactly the way a dead credential or a bad
/// server URL would, and read `connectCallsCount` to prove `PortalConnect` did (or did not)
/// re-enter connect. Outbound frames are handed to `onSend` instead of a socket.
public class MockWebSocketClient: WebSocketClient {
  private var mockConnectState: ConnectState = .disconnected

  /// Invoked once the mocked connection reports `.connected`.
  public var onConnect: (() -> Void)?

  /// Receives every binary frame the SDK would have written to the socket.
  public var onSend: ((Data) -> Void)?

  /// When set, the next `connect(uri:)` throws this instead of connecting and then clears it, so
  /// the call after that connects normally; set it again to fail twice. Pass a
  /// `PortalCredentialError` to exercise the 401 path, or any other error for the 500 path.
  public var connectThrows: Error?

  /// How many times `connect(uri:)` was called, including calls that threw.
  public private(set) var connectCallsCount = 0

  override public var isConnected: Bool {
    mockConnectState == .connected || mockConnectState == .connecting
  }

  /// Creates a mock client for `connect` authenticated with `credentials`.
  public init(
    credentials: PortalCredentials,
    connect: PortalConnect,
    webSocketServer: String = "wss://connect.portalhq.io"
  ) {
    super.init(credentials: credentials, connect: connect, webSocketServer: webSocketServer)
  }

  /// Wraps a Client API Key in `StaticCredentials`; kept so existing tests keep compiling.
  @available(*, deprecated, message: "Use init(credentials:connect:webSocketServer:) instead.")
  public convenience init(
    apiKey: String,
    connect: PortalConnect,
    webSocketServer: String = "wss://connect.portalhq.io"
  ) {
    self.init(credentials: StaticCredentials(apiKey), connect: connect, webSocketServer: webSocketServer)
  }

  override func connect(uri: String) throws {
    self.connectCallsCount += 1
    if let error = self.connectThrows {
      // One-shot, as documented: the failure belongs to this call only.
      self.connectThrows = nil
      throw error
    }

    self.uri = uri
    self.mockConnectState = .connecting
    DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
      self.mockConnectState = .connected
      self.onConnect?()
    }
  }

  override func disconnect(_: Bool = false) {
    self.mockConnectState = .disconnected
  }

  override func sendFinalMessageAndDisconnect() {
    self.mockConnectState = .disconnecting
    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
      self.mockConnectState = .disconnected
    }
  }

  override func send(_ data: Data) {
    self.onSend?(data)
  }
}
