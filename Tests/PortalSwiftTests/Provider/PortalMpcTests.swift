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
  var mpc: PortalMpc!
  var provider: PortalProvider!

  override func setUpWithError() throws {
    let keychain = MockPortalKeychain()
    keychain.clientId = mockClientId

    self.provider = try MockPortalProvider(
      apiKey: mockApiKey,
      chainId: 11_155_111,
      gatewayConfig: [11_155_111: mockHost],
      keychain: keychain,
      autoApprove: true
    )

    self.mpc = PortalMpc(
      apiKey: mockApiKey,
      api: MockPortalApi(
        apiKey: mockApiKey,
        apiHost: mockHost,
        provider: self.provider,
        mockRequests: true
      ),
      keychain: keychain,
      storage: BackupOptions(icloud: MockICloudStorage()),
      mobile: MockMobileWrapper()
    )
  }

  override func tearDownWithError() throws {
    self.mpc = nil
  }

  func testBackupIcloud() throws {
    let expectation = XCTestExpectation(description: "Backup")
    var encounteredStatuses: Set<MpcStatuses> = []

    self.mpc.backup(method: BackupMethods.iCloud.rawValue) { result in
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

  func testBackupGdrive() throws {
    self.mpc = PortalMpc(
      apiKey: mockApiKey,
      api: MockPortalApi(
        apiKey: mockApiKey,
        apiHost: mockHost,
        provider: self.provider,
        mockRequests: true
      ),
      keychain: MockPortalKeychain(),
      storage: BackupOptions(gdrive: MockGDriveStorage(clientID: mockClientId, viewController: UIViewController())),
      mobile: MockMobileWrapper()
    )
    let expectation = XCTestExpectation(description: "Backup")
    var encounteredStatuses: Set<MpcStatuses> = []

    self.mpc.backup(method: BackupMethods.GoogleDrive.rawValue) { result in
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

  func testGenerate() throws {
    let expectation = XCTestExpectation(description: "Generate")

    var encounteredStatuses: Set<MpcStatuses> = []

    self.mpc.generate { addressResult in

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

  func testRecover() throws {
    let expectation = XCTestExpectation(description: "Recover")
    var encounteredStatuses: [MpcStatuses] = []

    self.mpc.recover(cipherText: mockCiphertext, method: BackupMethods.iCloud.rawValue) { result in
      guard result.error == nil else {
        XCTFail("Failure: \(String(describing: result.error))")
        expectation.fulfill()
        return
      }
      XCTAssert(result.data! as String == mockAddress, "Recover should return address")
      expectation.fulfill()
    } progress: { MpcStatus in
      let status = MpcStatus.status
      encounteredStatuses.append(status)
    }
    wait(for: [expectation], timeout: 5.0)
    print(encounteredStatuses)
    XCTAssertEqual(encounteredStatuses, recoverProgressCallbacks, "All expected statuses should be encountered")
  }

  func testLegacyRecover() throws {
    let expectation = XCTestExpectation(description: "Legacy Recover")
    var encounteredStatuses: [MpcStatuses] = []

    self.mpc.legacyRecover(cipherText: mockCiphertext, method: BackupMethods.iCloud.rawValue) { result in
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
    print(encounteredStatuses)
    XCTAssertEqual(encounteredStatuses, legacyRecoverProgressCallbacks, "All expected statuses should be encountered")
  }
}
