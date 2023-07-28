//
//  ICloudStorageTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

@testable import PortalSwift
import XCTest

final class ICloudStorageTests: XCTestCase {
  var storage: ICloudStorage?

  override func setUpWithError() throws {
    let provider = try MockPortalProvider(apiKey: "", chainId: 5, gatewayConfig: [5: "https://example.com"], keychain: MockPortalKeychain(), autoApprove: true)

    self.storage = ICloudStorage()
    self.storage?.api = MockPortalApi(apiKey: "", apiHost: "", provider: provider)
  }

  override func tearDownWithError() throws {
    self.storage = nil
  }

  func testDelete() throws {
    let expectation = XCTestExpectation(description: "Delete")
    let privateKey = "privateKey"

    self.storage!.write(privateKey: privateKey) { (result: Result<Bool>) in
      if result.error != nil {
        XCTFail("Failed to write private key to storage. Make sure you are signed into iCloud on your simulator before running tests.")
      }

      self.storage!.read { (result: Result<String>) in
        XCTAssert(result.data! == privateKey)

        self.storage!.delete { (result: Result<Bool>) in
          XCTAssert(result.data! == true)

          self.storage!.read { (result: Result<String>) in
            XCTAssert(result.data! == "")
            expectation.fulfill()
          }
        }
      }
    }

    wait(for: [expectation], timeout: 5.0)
  }

  func testRead() throws {
    let expectation = XCTestExpectation(description: "Read")

    self.storage!.read { (result: Result<String>) in
      XCTAssert(result.data! == "")
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5.0)
  }

  func testWrite() throws {
    let expectation = XCTestExpectation(description: "Write")
    let privateKey = "privateKey"

    self.storage!.write(privateKey: privateKey) { (result: Result<Bool>) in
      XCTAssert(result.data! == true)

      self.storage!.read { (result: Result<String>) in
        XCTAssert(result.data! == privateKey)
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 5.0)
  }
}
