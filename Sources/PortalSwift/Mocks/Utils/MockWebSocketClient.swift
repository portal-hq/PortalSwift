//
//  MockWebSocketClient.swift
//
//
//  Created by Portal Labs on 12/06/2024.
//
import Foundation

class MockWebSocketClient: WebSocketClient {
  private var mockConnectState: ConnectState = .disconnected
  var onConnect: (() -> Void)?
  var onSend: ((Data) -> Void)?
  var uri: String?
  override var isConnected: Bool {
    mockConnectState == .connected || mockConnectState == .connecting
  }

  override func connect(uri: String) {
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
