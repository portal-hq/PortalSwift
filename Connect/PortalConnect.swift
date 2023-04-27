//
//  PortalConnect.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc. on 4/27/23.
//

import Foundation

class PortalConnect {
  var portal: Portal
  var client: WebSocketClient
  
  init(portal: Portal, webSocketServer: String = "connect.portalhq.io") {
    self.portal = portal
    self.client = WebSocketClient(portal: portal, webSocketServer: webSocketServer)
  }
  
  func connect(uri: String) {
    
  }
}
