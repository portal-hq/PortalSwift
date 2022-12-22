//
//  PortalApiTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import XCTest
@testable import PortalSwift

final class PortalApiTests: XCTestCase {
  var api: PortalApi?

  override func setUpWithError() throws {
    api = PortalApi(apiKey: "test", apiHost: "api.portalhq.io", mockRequests: true)
  }

  override func tearDownWithError() throws {
    api = nil
  }

  func testGetClient() throws {
    let expectation = XCTestExpectation(description: "Get client")
    try api?.getClient() { result in
      XCTAssert(result.data as! String == mockBackupShare)
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 5.0)
  }

  func testGetEnabledDapps() throws {
    let expectation = XCTestExpectation(description: "Get enabled dapps")
    try api?.getEnabledDapps() { result in
      XCTAssert(result.data as! String == mockBackupShare)
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 5.0)
  }

  func testGetSupportedNetworks() throws {
    let expectation = XCTestExpectation(description: "Get supported networks")
    try api?.getSupportedNetworks() { result in
      XCTAssert(result.data as! String == mockBackupShare)
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 5.0)
  }
}
