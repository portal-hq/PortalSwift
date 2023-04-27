//
//  WebSocketClient.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc. on 4/27/23.
//

import Foundation
import Starscream

class WebSocketClient : Starscream.WebSocketDelegate {
  private var events: [String: (Data) -> Void] = [:]
  private var isConnected = false
  private var portal: Portal
  private var webSocketServer: String
  private let socket: Starscream.WebSocket
  
  
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
    
  }
  
  func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocket) {
    switch event {
      case .connected(let headers):
        isConnected = true
        print("websocket is connected: \(headers)")
      case .disconnected(let reason, let code):
        isConnected = false
        print("websocket is disconnected: \(reason) with code: \(code)")
      case .text(let string):
        print("Received text: \(string)")
      case .binary(let data):
        print("Received data: \(data.count)")
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
      case .error(let error):
        isConnected = false
        handleError(error)
      }
  }
  
  func handleError(_ error: (any Error)?) {
    
  }
  
  func emit(eventName: String, data: Data) {
    let message = "{\"eventName\": \"\(eventName)\", \"eventData\": \(String(describing: String(data: data, encoding: .utf8)))}"
    self.socket.write(string: message)
  }
  
  private func handleEvent(data: Data) {
    guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
        let jsonDictionary = jsonObject as? [String: Any],
        let eventName = jsonDictionary["eventName"] as? String,
        let eventData = jsonDictionary["eventData"] else {
      print("Received invalid WebSocket message")
      return
    }
    
    if let eventHandler = self.events[eventName] {
      eventHandler(eventData as! Data)
    } else {
      print("No event handler found for event: \(eventName)")
    }
  }
}
