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
  let expiry: Int32?
  let peerMetadata: PeerMetadata
  let relay: ProtocolOptions?
  let topic: String?
}

struct ConnectV1Data: Codable {
  let id: Int
  let jsonrpc: String
  let method: String
  let params: [ConnectV1Params]
}

struct ConnectV1Params: Codable {
  let peerId: String
  let peerMeta: PeerMetadata
  let chainId: Int
}

struct DisconnectData: Codable {
  let id: Int
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

struct ProviderRequestAddressData: Codable {
  let method: String
  let params: [ETHAddressParam]
}

struct ProviderRequestTransactionData: Codable {
  let method: String
  let params: [ETHTransactionParam]
}

struct ProviderRequestData: Codable {
  let method: String
  let params: [String]
}

struct ProviderRequestParams: Codable {
  let chainId: Int?
  let request: ProviderRequestData
}

struct ProviderRequestTransactionParams: Codable {
  let chainId: Int?
  let request: ProviderRequestTransactionData
}

struct ProviderRequestAddressParams: Codable {
  let chainId: Int?
  let request: ProviderRequestAddressData
}

struct ProviderRequestPayload: Codable {
  let event: String
  let data: ProviderRequestData
}

struct ProviderRequestTransactionPayload: Codable {
  let event: String
  let data: ProviderRequestTransactionData
}

struct ProviderRequestAddressPayload: Codable {
  let event: String
  let data: ProviderRequestAddressData
}

struct SessionRequestData: Codable {
  let id: Int
  let params: ProviderRequestParams
  let topic: String
}

struct SessionRequestTransactionData: Codable {
  let id: Int
  let params: ProviderRequestTransactionParams
  let topic: String
}

struct SessionRequestAddressData: Codable {
  let id: Int
  let params: ProviderRequestAddressParams
  let topic: String
}

struct WebSocketMessage: Codable {
  let event: String
  let data: WebSocketMessageData?
}

struct WebSocketConnectedMessage: Codable {
  var event: String = "connected"
  let data: ConnectData
}

struct WebSocketConnectedV1Message: Codable {
  var event: String = "connected"
  let data: ConnectV1Data
}

struct WebSocketDisconnectMessage: Codable {
  var event: String = "disconnect"
  let data: DisconnectData
}

struct WebSocketSessionRequestMessage: Codable {
  var event: String = "session_request"
  let data: SessionRequestData
}

struct WebSocketSessionRequestAddressMessage: Codable {
  var event: String = "session_request"
  let data: SessionRequestAddressData
}

struct WebSocketSessionRequestTransactionMessage: Codable {
  var event: String = "session_request"
  let data: SessionRequestTransactionData
}

struct WebSocketRequest: Codable {
  let event: String
  let data: WebSocketRequestData?
}

struct WebSocketConnectRequest: Codable {
  let event: String
  let data: ConnectRequestData
}

enum WebSocketMessageData: Codable {
  case connectData(data: ConnectData)
  case disconnectData(data: DisconnectData)
  case sessionRequestData(data: SessionRequestData)
}

enum WebSocketRequestData: Codable {
  case connect(data: ConnectRequestData)
}

struct EventHandlers {
  var close: [() -> Void]
  var connected: [(ConnectData) -> Void]
  var connectedV1: [(ConnectV1Data) -> Void]
  var disconnect: [(DisconnectData) -> Void]
  var session_request: [(SessionRequestData) -> Void]
  var session_request_address: [(SessionRequestAddressData) -> Void]
  var session_request_transaction: [(SessionRequestTransactionData) -> Void]
  
  init() {
    close = []
    connected = []
    connectedV1 = []
    disconnect = []
    session_request = []
    session_request_address = []
    session_request_transaction = []
  }
}

class WebSocketClient : Starscream.WebSocketDelegate {
  private var events = EventHandlers()
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
    print("[WebSocketClient] Creating WebSocket client with headers: \(String(describing: request.allHTTPHeaderFields))")
    socket = Starscream.WebSocket(request: request)
    socket.delegate = self
  }
  
  func close() {
    socket.disconnect(closeCode: 1000)
  }
  
  func connect(uri: String) {
    self.uri = uri
    
    print("[WebSocketClient] Connecting to proxy...")
    socket.connect()
  }
  
  func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocket) {
    print("[WebSocketClient] Received event: \(event)")
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
      print("[WebSocketClient] Sending connect message...")
      
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
      // JSON decode the incoming message
      let payload = try JSONDecoder().decode(WebSocketSessionRequestMessage.self, from: data)
      print("[WebSocketClient] Received message: \(payload)")
      emit(payload.event, payload.data)
      return
    } catch {
      print(error)
      do {
        let payload = try JSONDecoder().decode(WebSocketSessionRequestAddressMessage.self, from: data)
        print("[WebSocketClient] Received message: \(payload)")
        emit(payload.event, payload.data)
        return
      } catch {
        print("[WebSocketClient] Unable to parse message as WebSocketSessionRequestMessage, attempting WebSocketSessionRequestAddressMessage...")
        do {
          let payload = try JSONDecoder().decode(WebSocketSessionRequestAddressMessage.self, from: data)
          print("[WebSocketClient] Received message: \(payload)")
          emit(payload.event, payload.data)
          return
        } catch {
          print("[WebSocketClient] Unable to parse message as WebSocketSessionRequestAddressMessage, attempting WebSocketSessionRequestTransactionMessage...")
          do {
            let payload = try JSONDecoder().decode(WebSocketSessionRequestTransactionMessage.self, from: data)
            print("[WebSocketClient] Received message: \(payload)")
            emit(payload.event, payload.data)
            return
          } catch {
            do {
              let payload = try JSONDecoder().decode(WebSocketConnectedMessage.self, from: data)
              print("[WebSocketClient] Received message: \(payload)")
              emit(payload.event, payload.data)
              return
            } catch {
              do {
                print("[WebSocketClient] Unable to parse message as WebSocketConnectedMessage, attempting WebSocketConnectedV1Message...")
                let payload = try JSONDecoder().decode(WebSocketConnectedV1Message.self, from: data)
                print("[WebSocketClient] Received message: \(payload)")
                emit(payload.event, payload.data)
                return
              } catch {
                print("[WebSocketClient] Unable to parse message as WebSocketConnectedV1Message, attempting WebSocketDisconnectMessage...")
                do {
                  let payload = try JSONDecoder().decode(WebSocketDisconnectMessage.self, from: data)
                  print("[WebSocketClient] Received message: \(payload)")
                  emit(payload.event, payload.data)
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
  
  func handleDisconnect(_ reason: String, _ code: UInt16) {
    isConnected = false
    print("[WebSocketClient] Websocket is disconnected: \(reason) with code: \(code)")
  }
  
  func handleError(_ error: (any Error)?) {
    print("[WebSocketClient] Received error: \(String(describing: error))")
  }
  
  func handleText(_ text: String) {
    // Get the raw data of the text
    let data = text.data(using: .utf8)!
    
    // Handle the request in `handleData()`
    handleData(data)
  }
  
  func emit(_ event: String, _ data: ConnectData) {
    // Get the list of event handlers for this event
    let eventHandlers = events.connected
    
    // Ensure there's something to invoke
    if (eventHandlers.count > 0) {
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
  
  func emit(_ event: String, _ data: ConnectV1Data) {
    // Get the list of event handlers for this event
    let eventHandlers = events.connectedV1
    
    // Ensure there's something to invoke
    if (eventHandlers.count > 0) {
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
    let eventHandlers = events.disconnect
    
    // Ensure there's something to invoke
    if (eventHandlers.count  > 0) {
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
    let eventHandlers = events.session_request
    
    // Ensure there's something to invoke
    if (eventHandlers.count > 0) {
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
  
  func emit(_ event: String, _ data: SessionRequestAddressData) {
    // Get the list of event handlers for this event
    let eventHandlers = events.session_request_address
    
    // Ensure there's something to invoke
    if (eventHandlers.count > 0) {
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
    let eventHandlers = events.session_request_transaction
    
    // Ensure there's something to invoke
    if (eventHandlers.count > 0) {
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
  
  func on(_ event: String, _ handler: @escaping () -> Void) {
    // Add event handler to the list
    events.close.append(handler)
  }
  
  func on(_ event: String, _ handler: @escaping (ConnectData) -> Void) {
    // Add event handler to the list
    events.connected.append(handler)
  }
  
  func on(_ event: String, _ handler: @escaping (ConnectV1Data) -> Void) {
    // Add event handler to the list
    events.connectedV1.append(handler)
  }
  
  func on(_ event: String, _ handler: @escaping (DisconnectData) -> Void) {
    // Add event handler to the list
    events.disconnect.append(handler)
  }
  
  func on(_ event: String, _ handler: @escaping (SessionRequestData) -> Void) {
    // Add event handler to the list
    events.session_request.append(handler)
  }
  
  func on(_ event: String, _ handler: @escaping (SessionRequestAddressData) -> Void) {
    // Add event handler to the list
    events.session_request_address.append(handler)
  }
  
  func on(_ event: String, _ handler: @escaping (SessionRequestTransactionData) -> Void) {
    // Add event handler to the list
    events.session_request_transaction.append(handler)
  }
  
  func send(_ message: String) {
    print("[WebSocketClient] Sending message: \(message)")
    socket.write(string: message)
  }
  
  func send(_ data: Data) {
    socket.write(data: data)
  }
}