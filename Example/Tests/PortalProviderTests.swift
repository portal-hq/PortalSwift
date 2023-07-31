//
//  PortalProviderTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

@testable import PortalSwift
import XCTest

final class PortalProviderTests: XCTestCase {
  var provider: PortalProvider?

  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.provider = try PortalProvider(
      apiKey: "test",
      chainId: 5,
      gatewayConfig: [5: "test"],
      keychain: MockPortalKeychain(),
      autoApprove: true,
      apiHost: "test"
    )
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    self.provider = nil
  }

  func testEmit() throws {
    let expectation = XCTestExpectation(description: "testEmit")
    var timesCalled = 0

    // Listen for the event.
    let _ = self.provider!.on(event: "test", callback: { data in
      print("data", data)
      XCTAssertEqual(data as! String, "test")
      timesCalled += 1

      if timesCalled == 3 {
        expectation.fulfill()
      }
    })

    // Emit 3 times.
    let _ = self.provider!.emit(event: "test", data: "test")
    let _ = self.provider!.emit(event: "test", data: "test")
    let _ = self.provider!.emit(event: "test", data: "test")

    // Wait for the expectation to be fulfilled, with a timeout of 5 seconds.
    wait(for: [expectation], timeout: 5.0)
  }

  func testGetApiKey() throws {
    let apiKey = self.provider!.apiKey
    XCTAssertEqual(apiKey, "test")
  }

  func testOn() throws {
    let expectation = XCTestExpectation(description: "testEmit")
    var timesCalled = 0

    // Listen for the event.
    let _ = self.provider!.on(event: "test", callback: { data in
      XCTAssertEqual(data as! String, "test")
      timesCalled += 1

      if timesCalled == 3 {
        expectation.fulfill()
      }
    })

    // Emit 3 times.
    let _ = self.provider!.emit(event: "test", data: "test")
    let _ = self.provider!.emit(event: "test", data: "test")
    let _ = self.provider!.emit(event: "test", data: "test")

    // Wait for the expectation to be fulfilled, with a timeout of 5 seconds.
    wait(for: [expectation], timeout: 5.0)
  }

  func testOnce() throws {
    let expectation = XCTestExpectation(description: "testEmit")

    let _ = self.provider!.once(event: "test", callback: { data in
      XCTAssertEqual(data as! String, "test")
      expectation.fulfill()
    })

    let _ = self.provider!.emit(event: "test", data: "test")
    wait(for: [expectation], timeout: 5.0)
  }

  func testRemoveListener() throws {
    let expectation = XCTestExpectation(description: "testEmit")

    // Listen for the event.
    let _ = self.provider!.on(event: "test-remove", callback: { _ in
      // Expect not to be called.
      XCTFail()
    })

    // Remove the listener.
    let _ = self.provider!.removeListener(event: "test-remove")

    // Emit the event.
    let _ = self.provider!.emit(event: "test-remove", data: "test")

    // Wait for the expectation to be fulfilled, with a timeout of 5 seconds.
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
      expectation.fulfill()
    }
  }

  func testRequest() throws {
    let expectation = XCTestExpectation(description: "testEmit")

    let _ = self.provider!.request(payload: ETHRequestPayload(method: "test", params: ["test", "test"])) { response in
      XCTAssertEqual(response.data!.method as String, "test")
      XCTAssertEqual(response.data!.params as! [String], ["test", "test"])
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5.0)
  }

  func testSetChainId() throws {
    let _ = try provider!.setChainId(value: 5)
    XCTAssertEqual(self.provider!.chainId, 5)
  }
}
