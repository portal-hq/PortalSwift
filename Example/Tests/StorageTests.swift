//
//  StorageTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import XCTest
@testable import PortalSwift

final class StorageTests: XCTestCase {
  var storage: Storage?

  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    storage = Storage()
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    storage = nil
  }

  func testDelete() {
    storage!.delete() { result in
      XCTAssert(result.error != nil)
    }
  }

  func testRead() {
    storage!.read() { result in
      XCTAssert(result.error != nil)
    }
  }

  func testWrite() {
    storage!.write(privateKey: "test") { result in
      XCTAssert(result.error != nil)
    }
  }
}
