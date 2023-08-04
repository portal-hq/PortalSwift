//
//  PortalCoreTests.swift
//  PortalSwift_Tests
//
//  Created by Rami Shahatit on 8/4/23.
//  Copyright © 2023 CocoaPods. All rights reserved.
//

@testable import PortalSwift
import XCTest

final class PortalCoreTests: XCTestCase {
  var portal: Portal!
  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.

    self.portal = try Portal(apiKey: "test", backup: BackupOptions(icloud: MockICloudStorage()), chainId: 5, keychain: MockPortalKeychain(), gatewayConfig: [5: "gatewayUrl"], isMock: true)
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  func testCreateWallet() {
    let expectation = XCTestExpectation(description: "Generate")
    var encounteredStatuses: Set<MpcStatuses> = []

    self.portal.createWallet { addressResult in
      guard addressResult.error == nil else {
        XCTFail("Failure: \(String(describing: addressResult.error))")
        expectation.fulfill()
        return
      }
      XCTAssert(addressResult.data == mockAddress)
      expectation.fulfill()
    } progress: { MpcStatus in
      let status = MpcStatus.status
      encounteredStatuses.insert(status)
    }
    wait(for: [expectation], timeout: 5.0)
    XCTAssertEqual(encounteredStatuses, generateProgressCallbacks, "All expected statuses should be encountered")
  }

  func testBackupWallet() {
    let expectation = XCTestExpectation(description: "Backup")
    var encounteredStatuses: Set<MpcStatuses> = []

    self.portal.backupWallet(method: BackupMethods.iCloud.rawValue) { result in
      guard result.error == nil else {
        XCTFail("Failure: \(String(describing: result.error))")
        expectation.fulfill()
        return
      }

      XCTAssert(result.data! as String == mockCiphertext, "Backup should return cipherText")
      expectation.fulfill()
    } progress: { MpcStatus in
      let status = MpcStatus.status
      encounteredStatuses.insert(status)
    }
    wait(for: [expectation], timeout: 5.0)

    XCTAssertEqual(encounteredStatuses, backupProgressCallbacks, "All expected statuses should be encountered")
  }

  func testRecoverWallet() {
    let expectation = XCTestExpectation(description: "Recover")
    var encounteredStatuses: [MpcStatuses] = []

    self.portal.recoverWallet(cipherText: mockCiphertext, method: BackupMethods.iCloud.rawValue) { result in
      guard result.error == nil else {
        XCTFail("Failure: \(String(describing: result.error))")
        expectation.fulfill()
        return
      }

      XCTAssert(result.data! as String == mockCiphertext, "Recover should return cipherText")
      expectation.fulfill()
    } progress: { MpcStatus in
      let status = MpcStatus.status
      encounteredStatuses.append(status)
    }
    wait(for: [expectation], timeout: 5.0)

    XCTAssertEqual(encounteredStatuses, recoverProgressCallbacks, "All expected statuses should be encountered")
  }
}
