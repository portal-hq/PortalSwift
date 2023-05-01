//
//  WebSocketClient.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc. on 4/27/23.
//

import Foundation
import Starscream

struct ConnectRequestData: Codable {
  let address: String
  let chainId: Int
  let uri: String
}

struct ConnectData: Codable {
  let active: Bool
  let expiry: Int32
  let peerMetadata: PeerMetadata
  let relay: ProtocolOptions
  let topic: String
}

struct DisconnectData: Codable {
  let id: Int32
  let topic: String
}

struct PeerMetadata: Codable {
  let name: String
  let description: String
  let url: String
  let icons: [String]
}

struct ProtocolOptions: Codable {
  let `protocol`: String
  let data: String?
}

struct ProviderRequestData: Codable {
  let method: String
  let params: [String]
}

struct ProviderRequestPayload: Codable {
  let event: String
  let data: ProviderRequestData
}

struct SessionRequestData: Codable {
  let id: String
  let params: ProviderRequestPayload
  let topic: String
}

struct WebSocketMessage: Codable {
  let event: String
  let data: WebSocketMessageData?
}

struct WebSocketRequest: Codable {
  let event: String
  let data: WebSocketRequestData?
}

enum WebSocketMessageData: Codable {
  case connectData(data: ConnectData)
  case disconnectData(data: DisconnectData)
  case sessionRequestData(data: SessionRequestData)
}

enum WebSocketRequestData: Codable {
  case connect(data: ConnectRequestData)
}

class WebSocketClient : Starscream.WebSocketDelegate {
  private var events: [String: [(WebSocketMessageData?) -> Void]] = [:]
  private var isConnected = false
  private var portal: Portal
  private var webSocketServer: String
  private let socket: Starscream.WebSocket
  private var uri: String?
  
  
  init(portal: Portal, webSocketServer: String = "connect.portalhq.io") {
    self.portal = portal
    self.webSocketServer = webSocketServer
    
    // Build appropriate connection string
    let connectionString = webSocketServer.starts(with: "localhost")
      ? "ws://\(webSocketServer)"
      : "wss://\(webSocketServer)"
    
    // Create a new URLRequest instance
    var request = URLRequest(url: URL(string: connectionString)!)
    request.timeoutInterval = 5
    
    // Create the WebSocket to be connected on demand
    // - this WebSocket does not actually connect until
    //   the `connect` function is called
    socket = Starscream.WebSocket(request: request)
  }
  
  func connect(uri: String) {
    socket.connect()
  }
  
  func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocket) {
    // Handle incoming messages
    switch event {
      case .connected:
        handleConnect()
        break
      case .disconnected(let reason, let code):
        handleDisconnect(reason, code)
        break
      case .text(let text):
        handleText(text)
        break
      case .binary(let data):
        handleData(data)
        break
      case .ping(_):
        break
      case .pong(_):
        break
      case .viabilityChanged(_):
        break
      case .reconnectSuggested(_):
        break
      case .cancelled:
        isConnected = false
        break
      case .error(let error):
        isConnected = false
        handleError(error)
        break
      }
  }
  
  func handleConnect() {
    // Set the connection state
    isConnected = true
    
    print("[WebSocketClient] Connected to proxy service.")
    
    do {
      // Build the WebSocketRequest
      let request = WebSocketRequest(
        event: "connect",
        data: .connect(data: ConnectRequestData(
          address: portal.address,
          chainId: portal.chainId,
          uri: uri!
        ))
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
    do {
      // JSON decode the incoming message
      let payload = try JSONDecoder().decode(WebSocketMessage.self, from: data)
      
      emit(payload.event, payload.data)
    } catch {
      print("[WebSocketClient] Error when processing incoming data: \(error)")
    }
  }
  
  func handleDisconnect(_ reason: String, _ code: UInt16) {
    isConnected = false
    print("[WebSocketClient] Websocket is disconnected: \(reason) with code: \(code)")
  }
  
  func handleError(_ error: (any Error)?) {
    
  }
  
  func handleText(_ text: String) {
    // Get the raw data of the text
    let data = text.data(using: .utf8)!
    
    // Handle the request in `handleData()`
    handleData(data)
  }
  
  func emit(_ event: String, _ data: WebSocketMessageData?) {
    // Get the list of event handlers for this event
    let eventHandlers = events[event]
    
    // Ensure there's something to invoke
    if (eventHandlers != nil && eventHandlers?.count ?? 0 > 0) {
      // Loop through the event handlers
      for handler in eventHandlers! {
        // Invoke the handler
        handler(data)
      }
    } else {
      // Ignore the event
      print("[PortalConnect] No registered event handlers for \(event). Ignoring...")
    }
  }
  
  func on(_ event: String, _ handler: @escaping (WebSocketMessageData?) -> Void) {
    // Create a new Array if none exists yet
    if (events[event] == nil) {
      events[event] = []
    }
    
    // Add event handler to the list
    events[event]!.append(handler)
  }
  
  func send(_ message: String) {
    socket.write(string: message)
  }
  
  func send(_ data: Data) {
    socket.write(data: data)
  }
}
