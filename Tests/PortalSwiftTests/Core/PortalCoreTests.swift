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
    let keychain = MockPortalKeychain()
    keychain.clientId = MockConstants.mockClientId

    let mobile = MockMobileWrapper()

    let provider = try MockPortalProvider(
      apiKey: MockConstants.mockApiKey,
      rpcConfig: ["eip155:11155111": MockConstants.mockHost],
      keychain: keychain,
      autoApprove: true
    )

    let api = MockPortalApi(
      apiKey: MockConstants.mockApiKey,
      apiHost: MockConstants.mockHost,
      provider: provider,
      isMocked: true
    )

    let mpc = PortalMpc(
      apiKey: MockConstants.mockApiKey,
      api: api,
      keychain: keychain,
      mobile: mobile
    )

    self.portal = try Portal(apiKey: MockConstants.mockApiKey, backup: BackupOptions(icloud: MockICloudStorage()), chainId: 11_155_111, keychain: keychain, gatewayConfig: [11_155_111: MockConstants.mockHost], mpc: mpc, api: api, binary: mobile)
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
      XCTAssert(addressResult.data == MockConstants.mockEip155Address)
      expectation.fulfill()
    } progress: { MpcStatus in
      let status = MpcStatus.status
      encounteredStatuses.insert(status)
    }
    wait(for: [expectation], timeout: 5.0)
    XCTAssertEqual(encounteredStatuses, MockConstants.generateProgressCallbacks, "All expected statuses should be encountered")
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

      XCTAssert(result.data! as String == MockConstants.mockCiphertext, "Backup should return cipherText")
      expectation.fulfill()
    } progress: { MpcStatus in
      let status = MpcStatus.status
      encounteredStatuses.insert(status)
    }
    wait(for: [expectation], timeout: 5.0)

    XCTAssertEqual(encounteredStatuses, MockConstants.backupProgressCallbacks, "All expected statuses should be encountered")
  }

  func testRecoverWallet() {
    let expectation = XCTestExpectation(description: "Recover")
    var encounteredStatuses: [MpcStatuses] = []

    self.portal.recoverWallet(cipherText: MockConstants.mockCiphertext, method: BackupMethods.iCloud.rawValue) { result in
      guard result.error == nil else {
        XCTFail("Failure: \(String(describing: result.error))")
        expectation.fulfill()
        return
      }

      XCTAssert(result.data! as String == MockConstants.mockEip155Address, "Recover should return address")
      expectation.fulfill()
    } progress: { MpcStatus in
      let status = MpcStatus.status
      encounteredStatuses.append(status)
    }
    wait(for: [expectation], timeout: 5.0)

    XCTAssertEqual(encounteredStatuses, MockConstants.recoverProgressCallbacks, "All expected statuses should be encountered")
  }

  func testEjectWallet() {
    let expectation = XCTestExpectation(description: "Eject")

    self.portal.ejectPrivateKey(clientBackupCiphertext: MockConstants.mockCiphertext, method: BackupMethods.iCloud.rawValue, orgBackupShare: "someOrgShare") { result in
      guard result.error == nil else {
        XCTFail("Failure: \(String(describing: result.error))")
        expectation.fulfill()
        return
      }

      XCTAssertEqual(result.data!, "099cabf8c65c81e629d59e72f04a549aafa531329e25685a5b8762b926597209", "Unexpected private key")
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 5.0)
  }
}
