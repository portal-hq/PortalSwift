//
//  PortalKeychainAccessTests.swift
//  
//
//  Created by Prakash Kotwal on 13/06/2024.
//
@testable import PortalSwift
import XCTest

final class PortalKeychainAccessTests: XCTestCase {
  var mockKeychain: MockPortalKeychainAccess!
  var keychain: PortalKeychainAccess!
  let testKey = "PortalKeychain.testKey"
  override func setUpWithError() throws {
    mockKeychain = MockPortalKeychainAccess()
    keychain = PortalKeychainAccess()
  }
  
  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    mockKeychain = nil
    keychain = nil
  }
  
  func testAddItemSuccess() throws {
    XCTAssertNoThrow(try mockKeychain.addItem(testKey, value: "testValue"))
    XCTAssertEqual(try mockKeychain.getItem(testKey), "testValue")
  }
  
  func testUpdateItem() {
    XCTAssertNoThrow(try mockKeychain.addItem(testKey, value: "testValue"))
    XCTAssertNoThrow(try mockKeychain.updateItem(testKey, value: "updatedValue"))
    XCTAssertEqual(try mockKeychain.getItem(testKey), "updatedValue")
  }
  
  func testDeleteItem() {
    XCTAssertNoThrow(try mockKeychain.addItem(testKey, value: "testValue"))
    XCTAssertNoThrow(try mockKeychain.deleteItem(testKey))
    XCTAssertThrowsError(try mockKeychain.getItem(testKey)) { error in
      XCTAssertEqual((error as? PortalKeychainAccessError)?.localizedDescription, PortalKeychainAccessError.itemNotFound(testKey).localizedDescription)
    }
  }
  
  func testGetItem() {
    XCTAssertNoThrow(try mockKeychain.addItem(testKey, value: "testValue"))
    XCTAssertEqual(try mockKeychain.getItem(testKey), "testValue")
  }
    
}
