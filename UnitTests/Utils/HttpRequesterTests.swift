//
//  HttpRequesterTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//
@testable import PortalSwift
import XCTest

final class HttpRequesterTests: XCTestCase {
  var requester: HttpRequester?

  override func setUpWithError() throws {
    self.requester = HttpRequester(baseUrl: "https://www.portalhq.io")
  }

  func testHttpRequester() throws {
    let expectation = XCTestExpectation(description: "Requester")

    try requester?.get(
      path: "/",
      headers: [:],
      requestType: HttpRequestType.CustomRequest
    ) { (_: Result<String>) in
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5.0)
  }

  func testHttpRequesterWithBody() throws {
    let expectation = XCTestExpectation(description: "Requester")

    try requester?.post(
      path: "/",
      body: ["test": "test"],
      headers: [:],
      requestType: HttpRequestType.CustomRequest
    ) { (_: Result<String>) in
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5.0)
  }
}
