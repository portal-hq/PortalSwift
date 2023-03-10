//
//  HttpRequestTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import XCTest
@testable import PortalSwift

final class HttpRequestTests: XCTestCase {
  func testHttpRequest() {
    let expectation = XCTestExpectation(description: "Request")

    // Create the request.
    let request = HttpRequest<String, Dictionary<String, Any>>(
      url: "https://www.portalhq.io",
      method: "GET",
      body: [:],
      headers: [:],
      requestType: HttpRequestType.CustomRequest

    )

    // Attempt to send the request.
    request.send() { (result: Result<String>) -> Void in
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5.0)
  }

  func testHttpRequestWithBody() {
    let expectation = XCTestExpectation(description: "Request")

    // Create the request.
    let request = HttpRequest<String, Dictionary<String, Any>>(
      url: "https://www.portalhq.io",
      method: "POST",
      body: ["test": "test"],
      headers: ["Content-Type": "application/json"],
      requestType: HttpRequestType.CustomRequest
    )

    // Attempt to send the request.
    request.send() { (result: Result<String>) -> Void in
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5.0)
  }

  func testHttpRequestWithString() {
    let expectation = XCTestExpectation(description: "Request")

    // Create the request.
    let request = HttpRequest<String, Dictionary<String, Any>>(
      url: "https://www.portalhq.io",
      method: "GET",
      body: [:],
      headers: [:],
      isString: true,
      requestType: HttpRequestType.CustomRequest
    )

    // Attempt to send the request.
    request.send() { (result: Result<String>) -> Void in
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5.0)
  }
}
