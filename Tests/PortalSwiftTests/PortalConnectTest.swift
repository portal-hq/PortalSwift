//
//  PortalConnectTest.swift
//
//
//  Created by Portal Labs on 12/06/2024.
//

@testable import PortalSwift
import XCTest

class PortalConnectTest: XCTestCase {
  var portalConnect: PortalConnect!
  var mockClient: MockWebSocketClient!

  var keychain: PortalKeychainProtocol!
  let mockURL = "https://\(MockConstants.mockHost)/test-rpc"

  override func setUpWithError() throws {
    try super.setUpWithError()

    self.keychain = MockPortalKeychain()
    let chainId = 11_155_111

    portalConnect = try PortalConnect(
      MockConstants.mockApiKey,
      chainId,
      keychain,
      ["eip155:11155111": mockURL],
      FeatureFlags()
    )

    mockClient = MockWebSocketClient(apiKey: MockConstants.mockApiKey, connect: portalConnect)
    portalConnect.client = mockClient
  }

  override func tearDownWithError() throws {
    portalConnect = nil
    mockClient = nil
    try super.tearDownWithError()
  }

  func testConnect_success() {
    portalConnect.connect(mockURL)
    XCTAssertTrue(self.mockClient.isConnected)
    XCTAssertEqual(self.mockClient.uri, self.mockURL)
  }

  func testDisconnect() {
    portalConnect.connect(mockURL)
    portalConnect.disconnect(true)
    XCTAssertFalse(mockClient.isConnected)
  }

  func testHandleClose() {
    portalConnect.handleClose()
    XCTAssertNil(portalConnect.client!.topic)
    XCTAssertFalse(portalConnect.client!.isConnected)
  }

  func testHandleDappSessionRequested_approved() throws {
    let data = MockConstants.mockConnectData

    let expectation = self.expectation(description: "DappSessionApproved event should be handled")
    mockClient.onSend = { message in
      let event = try! JSONDecoder().decode(DappSessionResponseMessage.self, from: message)
      XCTAssertEqual(event.event, "portal_dappSessionApproved")
      expectation.fulfill()
    }

    portalConnect.handleDappSessionRequested(data: data)
    portalConnect.emit(event: Events.PortalDappSessionApproved.rawValue, data: data)

    waitForExpectations(timeout: 2.0, handler: nil)
  }

  func testHandleDappSessionRequested_rejected() throws {
    let data = MockConstants.mockConnectData

    let expectation = self.expectation(description: "DappSessionRejected event should be handled")
    mockClient.onSend = { message in
      let event = try! JSONDecoder().decode(DappSessionResponseMessage.self, from: message)
      XCTAssertEqual(event.event, "portal_dappSessionRejected")
      expectation.fulfill()
    }

    portalConnect.handleDappSessionRequested(data: data)
    portalConnect.emit(event: Events.PortalDappSessionRejected.rawValue, data: data)

    waitForExpectations(timeout: 2.0, handler: nil)
  }

  func testHandleSessionRequest_success() async throws {
    let data = MockConstants.mockSessionRequestData

    let expectation = self.expectation(description: "SessionRequest should be handled successfully")
    portalConnect.handleSessionRequest(data: data)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testHandleSessionRequestAddress_success() async throws {
    let data = MockConstants.mockSessionRequestAddressData

    let expectation = self.expectation(description: "SessionRequestAddress should be handled successfully")
    portalConnect.handleSessionRequestAddress(data: data)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testHandleSessionRequestTransaction_success() async throws {
    let data = MockConstants.mockSessionRequestTransactionData

    let expectation = self.expectation(description: "SessionRequestTransaction should be handled successfully")
    portalConnect.handleSessionRequestTransaction(data: data)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }
}
