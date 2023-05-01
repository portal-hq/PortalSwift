//
//  PortalConnect.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc. on 4/27/23.
//

import Foundation

class PortalConnect {
  var client: WebSocketClient
  var connected: Bool = false
  var portal: Portal
  
  
  init(portal: Portal, webSocketServer: String = "connect.portalhq.io") {
    self.portal = portal
    self.client = WebSocketClient(portal: portal, webSocketServer: webSocketServer)
  }
  
  func connect(uri: String) {
    client.on("close", handleClose)
    client.on("connected", handleConnected)
    client.on("disconnected", handleDisconnected)
    client.on("session_request", handleSessionRequest)
    
    client.connect(uri: uri)
  }
  
  func handleClose(_ data: WebSocketMessageData?) {
    connected = false
  }
  
  func handleConnected(_ data: WebSocketMessageData?) {
    connected = true
  }
  
  func handleDisconnected(_ data: WebSocketMessageData?) {
    connected = false
  }
  
  func handleSessionRequest(_ request: WebSocketMessageData?) {
    var data = request! as? SessionRequestData ?? nil
    
    switch request {
      case .sessionRequestData(let sessionRequestData):
        data = sessionRequestData
      break
      default:
        break
    }
    
    let (params) = data
  }
}
