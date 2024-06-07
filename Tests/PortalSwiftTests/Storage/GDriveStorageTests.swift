//
//  GDriveStorageTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

@testable import PortalSwift
import XCTest

final class GDriveStorageTests: XCTestCase {
  //  func testExample() {
  //    XCTAssertTrue(true)
  //  }
  
  var storage: Storage?
  
  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.storage = Storage()
  }
  
  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    self.storage = nil
  }
  
  func testDelete() {
    self.storage!.delete { result in
      XCTAssert(result.error != nil)
    }
  }
}
