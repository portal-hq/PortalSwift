//
//  WebSocketClient.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc. on 4/27/23.
//

import Foundation
import Starscream

enum WebSocketTypeErrors: Error {
  case MismatchedTypeMessage
}

class WebSocketClient: WebSocketEventBus, Starscream.WebSocketDelegate {
  public var topic: String?

  private var isConnected = false
  private var portal: Portal
  private var webSocketServer: String
  private let socket: Starscream.WebSocket
  private var uri: String?

  init(portal: Portal, webSocketServer: String = "connect.portalhq.io") {
    self.portal = portal
    self.webSocketServer = webSocketServer

    // Create a new URLRequest instance
    var request = URLRequest(url: URL(string: webSocketServer)!)
    request.timeoutInterval = 5
    request.setValue("Bearer \(portal.apiKey)", forHTTPHeaderField: "Authorization")

    // Create the WebSocket to be connected on demand
    // - this WebSocket does not actually connect until
    //   the `connect` function is called
    socket = Starscream.WebSocket(request: request)

    super.init(label: "PortalConnectWebSocketClient")

    socket.delegate = self
  }

  deinit {
    assert(
      isConnected == false,
      "[WebSocketClient] sendFinalMessageAndDisconnect must be called before deallocating the WebSocketManager"
    )
  }

  func close() {
    socket.disconnect(closeCode: 1000)
  }

  func connect(uri: String) {
    self.uri = uri

    print("[WebSocketClient] Connecting to proxy...")
    socket.connect()
  }

  func disconnect(_ userInitiated: Bool = false) {
    do {
      print("[WebSocketClient] Disconnecting from proxy...")

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
      let message = String(data: json, encoding: .utf8)!

      // Send the message
      socket.write(string: message)
    } catch {
      print("[WebSocketClient] Error encoding outbound message. Could not disconnect.")
    }
  }

  func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocket) {
    print("[WebSocketClient] Received event: \(event)")
    // Handle incoming messages
    switch event {
    case .connected:
      handleConnect()
    case let .disconnected(reason, code):
      handleDisconnect(reason, code)
    case let .text(text):
      handleText(text)
    case let .binary(data):
      handleData(data)
    case let .ping(data):
      print("Received ping, sending pong")
      client.write(pong: data!) // Responding to the ping here
    case .pong:
      print("Received pong")
    case .viabilityChanged:
      break
    case .reconnectSuggested:
      break
    case .cancelled:
      isConnected = false
    case let .error(error):
      handleError(error)
    }
  }

  func handleConnect() {
    // Set the connection state
    isConnected = true

    do {
      print("[WebSocketClient] Connected to proxy service. Sending connect message...")

      let address = try portal.keychain.getAddress()
      // Build the WebSocketRequest
      let request = WebSocketConnectRequest(
        event: "connect",
        data: ConnectRequestData(
          address: address,
          chainId: portal.chainId,
          uri: uri!
        )
      )

      // JSON encode the WebSocketRequest
      let json = try JSONEncoder().encode(request)
      let message = String(data: json, encoding: .utf8)

      // Send the connection request to the proxy service
      send(message!)
    } catch {
      print("[PortalConnect] Error connecting to uri: \(String(describing: uri)); \(error.localizedDescription)")
    }
  }

  func handleData(_ data: Data) {
    // Attempt to parse various data types
    do {
      var payload: WebSocketMessage?

      if jsonIsType(data, WebSocketDappSessionRequestMessage.self) {
        let message = try JSONDecoder().decode(WebSocketDappSessionRequestMessage.self, from: data)

        payload = WebSocketMessage(event: message.event, data: message.data)
      } else if jsonIsType(data, WebSocketSessionRequestAddressMessage.self) {
        let message = try JSONDecoder().decode(WebSocketSessionRequestAddressMessage.self, from: data)

        payload = WebSocketMessage(event: message.event, data: message.data)
      } else if jsonIsType(data, WebSocketSessionRequestTransactionMessage.self) {
        let message = try JSONDecoder().decode(WebSocketSessionRequestTransactionMessage.self, from: data)

        payload = WebSocketMessage(event: message.event, data: message.data)
      } else if jsonIsType(data, WebSocketSessionRequestMessage.self) {
        let message = try JSONDecoder().decode(WebSocketSessionRequestMessage.self, from: data)

        payload = WebSocketMessage(event: message.event, data: message.data)
      } else if jsonIsType(data, WebSocketConnectedMessage.self) {
        let message = try JSONDecoder().decode(WebSocketConnectedMessage.self, from: data)

        payload = WebSocketMessage(event: message.event, data: message.data)
      } else if jsonIsType(data, WebSocketDisconnectMessage.self) {
        let message = try JSONDecoder().decode(WebSocketDisconnectMessage.self, from: data)

        payload = WebSocketMessage(event: message.event, data: message.data)
      }

      guard payload != nil else {
        throw WebSocketTypeErrors.MismatchedTypeMessage
      }

      guard let event = ConnectEvents(rawValue: payload!.event) else {
        throw WebSocketTypeErrors.MismatchedTypeMessage
      }

      print("Event: \(event)")

      emit(event, payload!.data)
    } catch {
      print("[WebSocketClient] Received unrecognized message. Ignoring...")
    }
  }

  func handleDisconnect(_ reason: String, _ code: UInt16) {
    isConnected = false
    print("[WebSocketClient] Websocket is disconnected: \(reason) with code: \(code)")
  }

  func handleError(_ error: (any Error)?) {
    print("[WebSocketClient] Received error: \(String(describing: error))")
    // This error needs to match
    if let error = error, error.localizedDescription == "POSIXErrorCode(rawValue: 54): Connection reset by peer" && isConnected {
      print("Connection reset by peer. Attempting reconnect...")
      isConnected = false
      connect(uri: uri!)
    } else if error != nil && error?.localizedDescription != nil {
      emit(.ConnectError, ErrorData(message: error!.localizedDescription))
    } else {
      emit(.ConnectError, ErrorData(message: "An unknown error occurred."))
    }
  }

  func handleText(_ text: String) {
    // Get the raw data of the text
    let data = text.data(using: .utf8)!

    // Handle the request in `handleData()`
    handleData(data)
  }

  func send(_ message: String) {
    print("[WebSocketClient] Sending message: \(message)")
    socket.write(string: message)
  }

  func send(_ data: Data) {
    socket.write(data: data)
  }

  func sendFinalMessageAndDisconnect() {
    do {
      print("[WebSocketClient] Sending final message before deallocation...")

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
      let message = String(data: json, encoding: .utf8)!

      socket.write(string: message) {
        print("[WebSocketClient] Final message sent! Disconnecting...")
        // Close the connection
        self.socket.disconnect()
        self.isConnected = false
      }
    } catch {
      print("[WebSocketClient] Unable to encode disconnect message. Failed to disconnect.")
    }
  }

  private func jsonIsType<T: Codable>(_ data: Data, _ type: T.Type) -> Bool {
    print("Checking if data is of type: \(type)...")
    do {
      let _ = try JSONDecoder().decode(type, from: data)
      print("Of type!")
      return true
    } catch {
      print("Not of type!")
      return false
    }
  }
}
