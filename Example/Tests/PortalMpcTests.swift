//
//  PortalMpcTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

@testable import PortalSwift
import XCTest

final class PortalMpcTests: XCTestCase {
  var mpc: PortalMpc?

  override func setUpWithError() throws {
    let provider = try MockPortalProvider(
      apiKey: "API_KEY",
      chainId: 5,
      gatewayConfig: [5: "https://example.com"],
      keychain: MockPortalKeychain(),
      autoApprove: true
    )

    self.mpc = MockPortalMpc(
      apiKey: "test",
      api: MockPortalApi(
        apiKey: "test",
        apiHost: "test",
        provider: provider,
        mockRequests: true
      ),
      keychain: MockPortalKeychain(),
      storage: BackupOptions(icloud: MockICloudStorage())
    )
  }

  override func tearDownWithError() throws {
    self.mpc = nil
  }

  func testBackup() throws {
    let expectation = XCTestExpectation(description: "Backup")
    self.mpc?.backup(method: BackupMethods.iCloud.rawValue) { result in
      XCTAssert(result.data! as String == mockBackupShare)
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 5.0)
  }

  func testGenerate() throws {
    self.mpc?.generate { addressResult in
      XCTAssert(addressResult.data == mockAddress)
    }
  }

  func testRecover() throws {
    let expectation = XCTestExpectation(description: "Recover")
    self.mpc?.recover(cipherText: "test", method: BackupMethods.iCloud.rawValue) { result in
      XCTAssert(result.data! as String == mockBackupShare)
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 5.0)
  }
}
