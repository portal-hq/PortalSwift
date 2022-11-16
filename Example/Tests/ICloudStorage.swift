//
//  ICloudStorage.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import XCTest
@testable import PortalSwift

final class ICloudStorageTest: XCTestCase {
    var storage: ICloudStorage?

    override func setUpWithError() throws {
        storage = ICloudStorage()
        storage?.api = MockPortalApi(apiKey: "")
    }

    override func tearDownWithError() throws {
        storage = nil
    }

    func testDelete() throws {
      let privateKey = "privateKey"
      storage!.write(privateKey: privateKey) {
        (result: Result<Bool>) -> Void in
        
        do {
          self.storage!.read() {
            (result: Result<String>) -> Void in
            XCTAssert(result.data! == privateKey)
            
            self.storage!.delete() {
              (result: Result<Bool>) -> Void in
              XCTAssert(result.data! == true)
              
              self.storage!.read() {
                (result: Result<String>) -> Void in
                XCTAssert(result.data! == "")
              }
            }
          }
      }
    }

    func testRead() throws {
      storage!.read() {
        (result: Result<String>) -> Void in
        XCTAssert(result.data! == "")
      }
    }

    func testWrite() throws {
      let privateKey = "privateKey"
      storage!.write(privateKey: privateKey) {
        (result: Result<Bool>) -> Void in
          XCTAssert(result.data! == true)
          
          self.storage!.read() {
            (result: Result<String>) -> Void in
            XCTAssert(result.data! == privateKey)
          }
        }
      }
    }
}
