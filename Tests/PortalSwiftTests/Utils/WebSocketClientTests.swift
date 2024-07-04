//
//  WebSocketClientTests.swift
//  
//
//  Created by Prakash Kotwal on 12/06/2024.
//
@testable import PortalSwift
import XCTest

class WebSocketClientTests: XCTestCase {
  var webSocketClient: WebSocketClient!
  let mockURL = "https://\(MockConstants.mockHost)/test-rpc"
  
  override func setUpWithError() throws {
    try super.setUpWithError()
    var portalConnect : PortalConnect!
    let keychain = MockPortalKeychain()
    let chainId = 11_155_111
    portalConnect = try PortalConnect(
      MockConstants.mockApiKey,
      chainId,
      keychain,
      ["eip155:11155111": mockURL]
    )
    webSocketClient = WebSocketClient(apiKey: MockConstants.mockApiKey, connect: portalConnect)
    portalConnect.client = webSocketClient
  }
  
  override func tearDown() {
    // Clean up
    webSocketClient = nil
    super.tearDown()
  }
  
  func testClose() {
    webSocketClient.close()
    XCTAssertEqual(webSocketClient.connectState, .disconnected)
  }
  
  func testConnect() {
    webSocketClient.connect(uri: mockURL)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
      XCTAssertEqual(self.webSocketClient.connectState, .connected)
    }
  }
  
  func testDisconnect() {
    let userInitiated = true
    webSocketClient.connect(uri: mockURL)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
      XCTAssertEqual(self.webSocketClient.connectState, .connected)
      self.webSocketClient.disconnect(userInitiated)
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        XCTAssertEqual(self.webSocketClient.connectState, .disconnected)
        XCTAssertFalse(self.webSocketClient.connectState == .connected)
      }
    }
  }
  func testHandleConnect() {
    webSocketClient.connect(uri: mockURL)
    webSocketClient.handleConnect()
    XCTAssertEqual(webSocketClient.connectState, .connecting)
  }
  
  func testHandleDisconnect() {
    let reason = "testReason"
    let code: UInt16 = 1000
    
    webSocketClient.handleDisconnect(reason, code)
    XCTAssertEqual(webSocketClient.connectState, .disconnected)
  }
  
  func testEmitWithConnectData() {
    let event = "testEvent"
    let data = MockConstants.mockConnectData
    
    var handlerCalled = false
    webSocketClient.on(event) { (_: ConnectData) in
      handlerCalled = true
    }
    
    webSocketClient.emit(event, data)
    XCTAssertTrue(handlerCalled)
  }
  
  func testEmitWithDisconnectData() {
    let event = "testEvent"
    let data = MockConstants.mockDicConnectedData
    
    // Add an event handler
    var handlerCalled = false
    webSocketClient.on(event) { (_: DisconnectData) in
      handlerCalled = true
    }
    webSocketClient.emit(event, data)
    XCTAssertTrue(handlerCalled)
  }
}
