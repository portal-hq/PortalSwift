//
//  PortalMpcTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import XCTest
@testable import PortalSwift

final class PortalMpcTests: XCTestCase {
  var mpc: PortalMpc?

  override func setUpWithError() throws {
    mpc = MockPortalMpc(apiKey: "test", chainId: 5, keychain: MockPortalKeychain(), storage: BackupOptions(icloud: MockICloudStorage()), gatewayUrl: "testurl")
  }

  override func tearDownWithError() throws {
    mpc = nil
  }

  func testBackup() throws {
    let expectation = XCTestExpectation(description: "Backup")
    mpc?.backup(method: BackupMethods.iCloud.rawValue) { result in
      XCTAssert(result.data! as String == mockBackupShare)
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 5.0)
  }

  func testGenerate() throws {
    let address = try mpc?.generate()
    XCTAssert(address == mockAddress)
  }

  func testRecover() throws {
    let expectation = XCTestExpectation(description: "Recover")
    mpc?.recover(cipherText: "test", method: BackupMethods.iCloud.rawValue) { result in
      XCTAssert(result.data! as String == mockBackupShare)
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 5.0)
  }
}
