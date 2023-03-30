//
//  PortalConnect.swift
//  PortalSwift
//
//  Created by Blake Williams on 3/29/23.
//

import Foundation

public struct ConnectResult: Codable {
  public var active: Bool
  public var expiry: Int
  public var peerMetadata: PeerMetadata
  public var relay: ProtocolOptions
  public var topic: String
}

public struct PeerMetadata: Codable {
  public var name: String
  public var description: String
  public var url: String
  public var icons: [String]
}

public struct ProtocolOptions: Codable {
  public var proto: String
  public var data: String?
  
  enum CodingKeys: String, CodingKey {
    case proto = "protocol"
  }
}

public struct ProviderRequestData: Codable {
  public var method: String
  public var params: String
}

public struct ProviderRequestPayload: Codable {
  public var chainId: String
  public var request: ProviderRequestData
}

public struct SessionRequest: Codable {
  public var id: String
  public var params: ProviderRequestPayload
  public var topic: String
}

public struct WebSocketMessage: Codable {
  public var event: String
  public var data: String
}

@available(iOS 13.0, *)
public class PortalConnect {
  public var connected: Bool = false
  
  private var events: Dictionary<String, [RegisteredEventHandler]> = [:]
  private var portal: Portal
  private var secure: Bool
  private var socket: URLSessionWebSocketTask?
  private var uri: String?
  private var webSocketServer: String
  
  init(
    portal: Portal,
    _ webSocketServer: String? = "connect.portalhq.io",
    _ secure: Bool? = true
  ) {
    self.portal = portal
    self.webSocketServer = webSocketServer!
    self.secure = secure!
    self.uri = secure! ? "wss://\(String(describing: webSocketServer))" : "ws:\(String(describing: webSocketServer))"
  }
  
  public func connect() -> Void {
    // Create the WebSocket URL
    // - Takes into account local testing, so conditionally adds the `wss://` vs `ws://`
    var url = URL(string: uri!)!
    
    // Create the WebSocket task
    socket = URLSession.shared.webSocketTask(with: url)
    
    // Start the WebSocket connection
    socket?.resume()
    
    // Receive message from the server
    socket?.receive { result in
      switch result {
        case .failure(let error):
          // Something went wrong
          print("[PortalConnect] WebSocket couldn't receive message because of error: \(error)")
        case .success(let message):
          // Received a message
          switch message {
          case .string(let text):
            // Received the message as text
            print("[PortalConnect] Received text message: \(text)")
            self.handleMessage(text)
          case .data(let data):
            // Received the message as data
            print("[PortalConnect] Received binary message: \(data)")
            self.handleMessage(data)
          @unknown default:
            fatalError()
        }
      }
    }
  }
  
  /// Emits an event from the provider to registered event handlers.
  /// - Parameters:
  ///   - event: The event to be emitted.
  ///   - data: The data to pass to registered event handlers.
  /// - Returns: The Portal Provider instance.
  public func emit(event: Events.RawValue, data: Any) -> PortalConnect {
    let registeredEventHandlers = self.events[event]

    if (registeredEventHandlers == nil) {
      print(String(format: "[PortalConnect] Could not find any bindings for event '%@'. Ignoring...", event))
      return self
    } else {
      // Invoke all registered handlers for the event
      do {
        for registeredEventHandler in registeredEventHandlers! {
          try registeredEventHandler.handler(data)
        }
      } catch {
        print("Error invoking registered handlers", error)
      }

      // Remove once instances
      events[event] = registeredEventHandlers?.filter(self.removeOnce)

      return self
    }
  }
  
  /// Registers a callback for an event.
  /// - Parameters:
  ///   - event: The event to register a callback.
  ///   - callback: The function to be invoked whenever the event fires.
  /// - Returns: The Portal Provider instance.
  public func on(
    event: Events.RawValue,
    callback: @escaping (_ data: Any) -> Void
  ) -> PortalConnect {
    if (self.events[event] == nil) {
      self.events[event] = []
    }

    self.events[event]?.append(RegisteredEventHandler(
      handler: callback,
      once: false
    ))

    return self
  }

  /// Registers a callback for an event. Deletes the registered callback after it's fired once.
  /// - Parameters:
  ///   - event: The event to register a callback.
  ///   - callback: The function to be invoked whenever the event fires.
  /// - Returns: The Portal Provider instance.
  public func once(
    event: Events.RawValue,
    callback: @escaping (_ data: Any) throws -> Void
  ) -> PortalConnect {
    if (events[event] == nil) {
      events[event] = []
    }

    events[event]?.append(RegisteredEventHandler(
      handler: callback,
      once: true
    ))

    return self
  }

  /// Removes the callback for the specified event.
  /// - Parameters:
  ///   - event: A specific event from the list of Events.
  /// - Returns: An instance of Portal Provider.
  public func removeListener(
    event: Events.RawValue
  ) -> PortalConnect {
    if (events[event] == nil) {
      print(String(format: "[PortalConnect] Could not find any bindings for event '%@'. Ignoring...", event))
    }

    events[event] = nil

    return self
  }
  
  private func handleMessage(_ data: Data) -> Void {
    do {
      // Parse the data to a proper message struct
      var message = try JSONDecoder().decode(WebSocketMessage.self, from: data)
      var (event, data) = (message.event, message.data)
      
      switch event {
      case "close":
        socket?.cancel(with: .goingAway, reason: nil)
      case "connected":
        // Parse the connection payload
        var payload = try JSONDecoder().decode(ConnectResult.self, from: data.data(using: .utf8)!)
        if (!payload.active) {
          // Proxy is not connected to the bridge
          print("[PortalConnect] Could not establish a connection to the relay.")
          return
        }

        // Set connected to true and dispatch the "connect" event
        connected = true
        _ = emit(event: "connect", data: ["uri": self.uri])
      case "disconnect":
        socket?.cancel(with: .goingAway, reason: nil)
        connected = false
        _ = emit(event: "disconnect", data: [
          "uri": uri
        ])
      case "session_request":
        var payload = try JSONDecoder().decode(SessionRequest.self, from: data.data(using: .utf8)!)
        var request = payload.params.request
        
        handleRequest(request)
      default:
        print("[PortalConnect] Received unsupported event type: \(event)")
      }
    } catch {
      print("[PortalConnect] Unable to parse received message.")
    }
  }
  
  private func handleMessage(_ message: String) -> Void {
    // Parse the message string as data
    var data = message.data(using: .utf8)!
    
    // Pass it along to the other handleMessage() function
    handleMessage(data)
  }
  
  private func handleProviderRequest(
    _ method: ETHRequestMethods.RawValue,
    _ params: String,
    completion: @escaping (Result<TransactionCompletionResult>) -> Void
  ) -> Void {
    do {
      var params = try JSONDecoder().decode(ETHTransactionParam.self, from: params.data(using: .utf8)!)
      var payload = ETHTransactionPayload(method: method, params: [params])
      portal.provider.request(payload: payload, completion: completion)
    } catch {
      print("[PortalConnect] Unable to process received request. \(error.localizedDescription)")
    }
  }
  
  private func handleProviderRequest(
    _ method: ETHRequestMethods.RawValue,
    _ params: String,
    completion: @escaping (Result<AddressCompletionResult>) -> Void
  ) -> Void {
    do {
      var params = try JSONDecoder().decode(ETHAddressParam.self, from: params.data(using: .utf8)!)
      var payload = ETHAddressPayload(method: method, params: [params])
      portal.provider.request(payload: payload, completion: completion)
    } catch {
      print("[PortalConnect] Unable to process received request. \(error.localizedDescription)")
    }
  }
  
  private func handleRequest(
    _ request: ProviderRequestData
  ) {
    do {
      if (TransactionMethods.contains(request.method)) {
        handleProviderRequest(request.method, request.params) { (result: Result<TransactionCompletionResult>) in
          // Handle the transaction response
        }
      } else {
        handleProviderRequest(request.method, request.params) { (result: Result<AddressCompletionResult>) in
          // Handle the address response
        }
      }
    }
  }
  
  private func removeOnce(registeredEventHandler: RegisteredEventHandler) -> Bool {
    return !registeredEventHandler.once
  }
}
