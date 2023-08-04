//
//  PortalKeychainTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import PortalSwift
import XCTest

final class PortalKeychainTests: XCTestCase {
  var keychain: PortalKeychain! // Implicitly unwrapped optional

  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.keychain = PortalKeychain()
    self.keychain.clientId = "test-client-id"
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    self.keychain = nil
  }

  func testShare() {
    self.keychain.setSigningShare(signingShare: "TestSigningShare") { _ in }
    XCTAssert(try self.keychain.getSigningShare() == "TestSigningShare", "Signing Share should equal what we stored.")
  }

  func testAddress() {
    self.keychain.setAddress(address: "0xhahashdfasAJHAFKJ") { _ in }
    XCTAssert(try self.keychain.getAddress() == "0xhahashdfasAJHAFKJ", "Address should equal what we stored.")
  }

  func testDeleteAddress() {
    self.keychain.setAddress(address: "0xhahashdfasAJHAFKJ") { _ in }
    XCTAssertNoThrow(try self.keychain.deleteAddress(), "Delete address should not throw an error.")
    XCTAssertThrowsError(try self.keychain.getAddress()) { error in
      let expectedError = PortalKeychain.KeychainError.ItemNotFound(item: "test-client-id.address")
      XCTAssert(expectedError == error as? PortalKeychain.KeychainError, "ItemNotFound error should throw")
    }
  }

  func testDeleteSigningShare() {
    self.keychain.setSigningShare(signingShare: "TestSigningShare") { _ in }
    XCTAssertNoThrow(try self.keychain.deleteSigningShare(), "Delete signing share should not throw an error.")
    XCTAssertThrowsError(try self.keychain.getSigningShare()) { error in
      let expectedError = PortalKeychain.KeychainError.ItemNotFound(item: "test-client-id.share")
      XCTAssert(expectedError == error as? PortalKeychain.KeychainError, "ItemNotFound error should throw")
    }
  }
}
