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

public class WebSocketClient: Starscream.WebSocketDelegate {
  public var isConnected: Bool {
    return self.connectState == .connected || self.connectState == .connecting
  }

  public var topic: String?
  public var connectState: ConnectState = .disconnected

  private var apiKey: String
  private var connect: PortalConnect
  private var events = EventHandlers()
  private var webSocketServer: String
  private let socket: Starscream.WebSocket
  private var uri: String?
  private var pingTimer: Timer?

  init(apiKey: String, connect: PortalConnect, webSocketServer: String = "connect.portalhq.io") {
    self.apiKey = apiKey
    self.connect = connect
    self.webSocketServer = webSocketServer

    // Create a new URLRequest instance
    var request = URLRequest(url: URL(string: webSocketServer)!)
    request.timeoutInterval = 5
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

    // Create the WebSocket to be connected on demand
    // - this WebSocket does not actually connect until
    //   the `connect` function is called
    self.socket = Starscream.WebSocket(request: request)
    self.socket.delegate = self
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
    self.socket.disconnect(closeCode: 1000)
  }

  func connect(uri: String) {
    self.uri = uri

    print("[WebSocketClient] Connecting to proxy...")
    self.socket.connect()
  }

  func disconnect(_ userInitiated: Bool = false) {
    self.connectState = .disconnecting

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
      self.socket.write(string: message)
      self.connectState = .disconnected
      self.pingTimer?.invalidate()
    } catch {
      print("[WebSocketClient] Error encoding outbound message. Could not disconnect.")
    }
  }

  public func didReceive(event: Starscream.WebSocketEvent, client _: Starscream.WebSocketClient) {
    if case .pong = event {} // Do nothing for pong
    else {
      print("[WebSocketClient] Received event: \(event)")
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
        self.connect(uri: self.uri!)
      }
    case .cancelled:
      self.connectState = .disconnected
      self.pingTimer?.invalidate()
    case let .error(error):
      self.handleError(error)
    case .peerClosed:
      if self.isConnected {
        self.connect(uri: self.uri!)
      } else {
        self.pingTimer?.invalidate()
        self.connectState = .disconnected
      }
    }
  }

  func ping(interval: TimeInterval = 25.0) {
    self.pingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
      guard let self = self else { return }
      self.socket.write(ping: Data())
    }
  }

  func handleConnect() {
    // Set the connection state
    self.connectState = .connecting

    do {
      print("[WebSocketClient] Connected to proxy service. Sending connect message...")

      guard let address = connect.address else {
        print("[WebSocketClient] No address found in keychain. Ignoring connect event...")
        return
      }
      // Build the WebSocketRequest
      let request = WebSocketConnectRequest(
        event: "connect",
        data: ConnectRequestData(
          address: address,
          chainId: connect.chainId,
          uri: self.uri!
        )
      )

      // JSON encode the WebSocketRequest
      let json = try JSONEncoder().encode(request)
      let message = String(data: json, encoding: .utf8)

      // Send the connection request to the proxy service
      self.send(message!)
      self.ping(interval: 10)
    } catch {
      print("[PortalConnect] Error connecting to uri: \(String(describing: self.uri)); \(error.localizedDescription)")
    }
  }

  func handleData(_ data: Data) {
    // Attempt to parse various data types
    do {
      // JSON decode the incoming message
      let payload = try JSONDecoder().decode(WebSocketSessionRequestMessage.self, from: data)
      self.emit(payload.event, payload.data)
      return
    } catch {
      do {
        let payload = try JSONDecoder().decode(WebSocketDappSessionRequestMessage.self, from: data)
        if payload.event != "portal_dappSessionRequested" {
          throw WebSocketTypeErrors.MismatchedTypeMessage
        }
        self.emit(payload.event, payload.data)
        return
      } catch {
        print("[WebSocketClient] Unable to parse message as WebSocketDappSessionRequestMessage, attempting WebSocketSessionRequestAddressMessage...")
        do {
          let payload = try JSONDecoder().decode(WebSocketSessionRequestAddressMessage.self, from: data)
          self.emit(payload.event, payload.data)
          return
        } catch {
          print("[WebSocketClient] Unable to parse message as WebSocketSessionRequestMessage, attempting WebSocketSessionRequestAddressMessage...")
          do {
            let payload = try JSONDecoder().decode(WebSocketSessionRequestAddressMessage.self, from: data)
            self.emit(payload.event, payload.data)
            return
          } catch {
            print("[WebSocketClient] Unable to parse message as WebSocketSessionRequestAddressMessage, attempting WebSocketSessionRequestTransactionMessage...")
            do {
              let payload = try JSONDecoder().decode(WebSocketSessionRequestTransactionMessage.self, from: data)
              self.emit(payload.event, payload.data)
              return
            } catch {
              do {
                let payload = try JSONDecoder().decode(WebSocketConnectedMessage.self, from: data)
                if payload.event != "connected" {
                  throw WebSocketTypeErrors.MismatchedTypeMessage
                }
                self.connectState = .connected
                self.emit(payload.event, payload.data)
                return
              } catch {
                print("[WebSocketClient] Unable to parse message as WebSocketConnectedMessage, attempting WebSocketDisconnectMessage...")
                do {
                  let payload = try JSONDecoder().decode(WebSocketDisconnectMessage.self, from: data)
                  if payload.event != "disconnect" {
                    throw WebSocketTypeErrors.MismatchedTypeMessage
                  }
                  self.connectState = .disconnected
                  self.emit(payload.event, payload.data)
                  return
                } catch {
                  print("[WebSocketClient] Unable to parse message as WebSocketDisconnectMessage, attempting WebSocketErrorMessage...")
                  do {
                    let payload = try JSONDecoder().decode(WebSocketErrorMessage.self, from: data)
                    if payload.event != "portal_connectError" {
                      throw WebSocketTypeErrors.MismatchedTypeMessage
                    }
                    self.emit(payload.event, payload.data)
                    return
                  } catch {
                    print("[WebSocketClient] Error when processing incoming data: \(error)")
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  func handleDisconnect(_ reason: String, _ code: UInt16) {
    self.connectState = .disconnected
    self.pingTimer?.invalidate()
    print("[WebSocketClient] Websocket is disconnected: \(reason) with code: \(code)")
    self.socket.disconnect(closeCode: 1000)
  }

  func handleError(_ error: (any Error)?) {
    print("[WebSocketClient] Received error: \(String(describing: error))")

    // This error needs to match
    if let error = error, error.localizedDescription == "The operation couldn’t be completed. Connection reset by peer" && isConnected {
      print("Connection reset by peer. Attempting reconnect...")
      self.connectState = .disconnected
      self.pingTimer?.invalidate()
      self.connect(uri: self.uri!)
      self.connectState = .connecting
    } else if error != nil && error?.localizedDescription != nil {
      self.connectState = .disconnected
      self.pingTimer?.invalidate()

      self.emit("error", ConnectError(message: error!.localizedDescription, code: 500))
      self.socket.disconnect(closeCode: 1000)
    } else {
      self.connectState = .disconnected
      self.pingTimer?.invalidate()

      self.emit("error", ConnectError(message: "An unknown error occurred.", code: 500))
      self.socket.disconnect(closeCode: 1000)
    }
  }

  func handleText(_ text: String) {
    // Get the raw data of the text
    let data = text.data(using: .utf8)!

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
      print("[PortalConnect] No registered event handlers for \(event). Ignoring...")
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
      print("[PortalConnect] No registered event handlers for \(event). Ignoring...")
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
      print("[PortalConnect] No registered event handlers for \(event). Ignoring...")
    }
  }

  func emit(_ event: String, _ data: ConnectError) {
    var eventHandlers = self.events.error

    // Ensure there's something to invoke
    if eventHandlers.count > 0 {
      // Loop through the event handlers
      for handler in eventHandlers {
        // Invoke the handler
        handler(data)
      }
    } else {
      // Ignore the event
      print("[PortalConnect] No registered event handlers for \(event). Ignoring...")
    }
  }

  func emit(_ event: String, _ data: ErrorData) {
    var eventHandlers = self.events.portal_connect_error

    // Ensure there's something to invoke
    if eventHandlers.count > 0 {
      // Loop through the event handlers
      for handler in eventHandlers {
        // Invoke the handler
        handler(data)
      }
    } else {
      // Ignore the event
      print("[PortalConnect] No registered event handlers for \(event). Ignoring...")
    }
  }

  func emit(_ event: String, _ data: SessionRequestData) {
    // Get the list of event handlers for this event
    let eventHandlers = self.events.session_request

    // Ensure there's something to invoke
    if eventHandlers.count > 0 {
      // Loop through the event handlers
      for handler in eventHandlers {
        print("[WebsocketClient] data: \(String(describing: data))")
        // Invoke the handler
        handler(data)
      }
    } else {
      // Ignore the event
      print("[PortalConnect] No registered event handlers for \(event). Ignoring...")
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
      print("[PortalConnect] No registered event handlers for \(event). Ignoring...")
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
      print("[PortalConnect] No registered event handlers for \(event). Ignoring...")
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
    print("[WebSocketClient] Sending message: \(message)")
    self.socket.write(string: message)
  }

  func send(_ data: Data) {
    self.socket.write(data: data)
  }

  func sendFinalMessageAndDisconnect() {
    self.connectState = .disconnecting

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

      self.socket.write(string: message) {
        print("[WebSocketClient] Final message sent! Disconnecting...")
        // Close the connection
        self.socket.disconnect()
        self.connectState = .disconnected
      }
    } catch {
      print("[WebSocketClient] Unable to encode disconnect message. Failed to disconnect.")
    }
  }
}
