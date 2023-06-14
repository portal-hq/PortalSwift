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
struct EventHandlers {
  var close: [() -> Void]
  var dapp_session_requested: [(ConnectData) -> Void]
  var dapp_session_requestedV1: [(ConnectV1Data) -> Void]
  var connected: [(ConnectedData) -> Void]
  var connectedV1: [(ConnectedV1Data) -> Void]
  var disconnect: [(DisconnectData) -> Void]
  var session_request: [(SessionRequestData) -> Void]
  var session_request_address: [(SessionRequestAddressData) -> Void]
  var session_request_transaction: [(SessionRequestTransactionData) -> Void]
  
  init() {
    close = []
    dapp_session_requested = []
    dapp_session_requestedV1 = []
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
    socket = Starscream.WebSocket(request: request)
    socket.delegate = self
  }
  
  func resetEventBus() {
    events = EventHandlers()
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
      case .ping(let data):
        print("Received ping, sending pong")
        client.write(pong: data!)  // Responding to the ping here
        break
      case .pong(_):
        print("Received pong")
        break
      case .viabilityChanged(_):
        break
      case .reconnectSuggested(_):
        break
      case .cancelled:
        isConnected = false
        break
      case .error(let error):
        handleError(error)
        break
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
      // JSON decode the incoming message
      let payload = try JSONDecoder().decode(WebSocketSessionRequestMessage.self, from: data)
      print("[WebSocketClient] Received message: \(payload)")
      emit(payload.event, payload.data)
      return
    } catch {
      print(error)
      do {
        let payload = try JSONDecoder().decode(WebSocketDappSessionRequestV1Message.self, from: data)
        print("[WebSocketClient] Received message: \(payload)")
        if (payload.event != "portal_dappSessionRequestedV1" ) {
          throw WebSocketTypeErrors.MismatchedTypeMessage
        }
        emit(payload.event, payload.data)
        return
      } catch {
        print("[WebSocketClient] Unable to parse message as WebSocketDappSessionRequestV1Message, attempting WebSocketDappSessionRequestMessage...")
        do {
          let payload = try JSONDecoder().decode(WebSocketDappSessionRequestMessage.self, from: data)
          print("[WebSocketClient] Received message: \(payload)")
          if (payload.event != "portal_dappSessionRequested" ) {
            throw WebSocketTypeErrors.MismatchedTypeMessage
          }
          emit(payload.event, payload.data)
          return
        } catch {
          print("[WebSocketClient] Unable to parse message as WebSocketDappSessionRequestMessage, attempting WebSocketSessionRequestAddressMessage...")
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
                  if (payload.event != "connected" ) {
                    throw WebSocketTypeErrors.MismatchedTypeMessage
                  }
                  emit(payload.event, payload.data)
                  return
                } catch {
                  do {
                    print("[WebSocketClient] Unable to parse message as WebSocketConnectedMessage, attempting WebSocketConnectedV1Message...")
                    let payload = try JSONDecoder().decode(WebSocketConnectedV1Message.self, from: data)
                    print("[WebSocketClient] Received message: \(payload)")
                    if (payload.event != "connected" ) {
                      throw WebSocketTypeErrors.MismatchedTypeMessage
                    }
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
    }
  }
  
  func handleDisconnect(_ reason: String, _ code: UInt16) {
    isConnected = false
    print("[WebSocketClient] Websocket is disconnected: \(reason) with code: \(code)")
  }
  
  func handleError(_ error: (any Error)?) {
    isConnected = false
    print("[WebSocketClient] Received error: \(String(describing: error))")
    // This error needs to match
    if (error?.localizedDescription == "Connection reset by peer") {
      connect(uri: uri!)
    }
  }
  
  func handleText(_ text: String) {
    // Get the raw data of the text
    let data = text.data(using: .utf8)!
    
    // Handle the request in `handleData()`
    handleData(data)
  }
  
  func emit(_ event: String, _ data: ConnectData) {
    // Get the list of event handlers for this event
    let eventHandlers = events.dapp_session_requested
    
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
  
  func emit(_ event: String, _ data: ConnectedData) {
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
    let eventHandlers = events.dapp_session_requestedV1
    
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
  
  func emit(_ event: String, _ data: ConnectedV1Data) {
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
        print("[WebsocketClient] data: \(String(describing: handler))")
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
  
  func on(_ event: String, _ handler: @escaping (ConnectData) -> Void) {
    // Add event handler to the list
    events.dapp_session_requested.append(handler)
  }
  
  func on(_ event: String, _ handler: @escaping (ConnectV1Data) -> Void) {
    // Add event handler to the list
    events.dapp_session_requestedV1.append(handler)
  }
  
  func on(_ event: String, _ handler: @escaping (ConnectedData) -> Void) {
    // Add event handler to the list
    events.connected.append(handler)
  }
  
  func on(_ event: String, _ handler: @escaping (ConnectedV1Data) -> Void) {
    // Add event handler to the list
    events.connectedV1.append(handler)
  }
  
  func on(_ event: String, _ handler: @escaping () -> Void) {
    // Add event handler to the list
    events.close.append(handler)
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
