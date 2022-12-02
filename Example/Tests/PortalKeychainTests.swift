//
//  PortalKeychainTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import XCTest
import PortalSwift

final class PortalKeychainTests: XCTestCase {

  var keychain: PortalKeychain?
  
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
      keychain = PortalKeychain()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
  func testShare() {
    // This is an example of a functional test case.
    do {
      try keychain!.setSigningShare(signingShare: "TestSigningShare")
    }
    catch {
      print("Error setting the share")
    }
    XCTAssert(try keychain!.getSigningShare() == "TestSigningShare", "Signing Share should equal what we stored.")
    
  }
  
  func testAddress() {
    // This is an example of a functional test case.
    do {
      try keychain!.setAddress(address: "0xhahashdfasAJHAFKJ")
    }
    catch {
      print("Error setting the address")
    }
    XCTAssert(try keychain!.getAddress() == "0xhahashdfasAJHAFKJ", "Address should equal what we stored.")
    
  }

}
