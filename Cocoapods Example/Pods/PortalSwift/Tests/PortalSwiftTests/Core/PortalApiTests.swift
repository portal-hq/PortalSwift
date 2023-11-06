//
//  PortalApiTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

@testable import PortalSwift
import XCTest

final class PortalApiTests: XCTestCase {
  var api: PortalApi?

  override func setUpWithError() throws {
    let provider = try MockPortalProvider(
      apiKey: mockApiKey,
      chainId: 5,
      gatewayConfig: [5: mockHost],
      keychain: MockPortalKeychain(),
      autoApprove: true
    )
    self.api = PortalApi(apiKey: mockApiKey, apiHost: mockHost, provider: provider, mockRequests: true)
  }

  override func tearDownWithError() throws {
    self.api = nil
  }

  func testGetClient() throws {
    throw XCTSkip("Test is not implemented yet")

    let expectation = XCTestExpectation(description: "Get client")
    try api?.getClient { result in
      XCTAssert(result.data as! String == mockBackupShare)
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 5.0)
  }

  func testGetEnabledDapps() throws {
    throw XCTSkip("Test is not implemented yet")

    let expectation = XCTestExpectation(description: "Get enabled dapps")
    try api?.getEnabledDapps { result in
      XCTAssert(result.data as! String == mockBackupShare)
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 5.0)
  }

  func testGetSupportedNetworks() throws {
    throw XCTSkip("Test is not implemented yet")

    let expectation = XCTestExpectation(description: "Get supported networks")
    try api?.getSupportedNetworks { result in
      XCTAssert(result.data as! String == mockBackupShare)
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 5.0)
  }
}
