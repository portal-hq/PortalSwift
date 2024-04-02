//
//  PortalMpcTests.swift
//
//
//  Created by Blake Williams on 3/30/24.
//

@testable import PortalSwift
import XCTest

final class PortalMpcTests: XCTestCase {
  private var mpc: PortalMpc?

  override func setUpWithError() throws {
    self.mpc = PortalMpc(
      apiKey: MockConstants.mockApiKey,
      api: PortalApi(apiKey: MockConstants.mockApiKey, requests: MockPortalRequests()),
      keychain: MockPortalKeychain(),
      mobile: MockMobileWrapper()
    )

    self.mpc?.registerBackupMethod(.GoogleDrive, withStorage: MockGDriveStorage())
    self.mpc?.registerBackupMethod(.Password, withStorage: MockPasswordStorage())
    self.mpc?.registerBackupMethod(.iCloud, withStorage: MockICloudStorage())
    if #available(iOS 16, *) {
      mpc?.registerBackupMethod(.Passkey, withStorage: MockPasskeyStorage())
    }
  }

  override func tearDownWithError() throws {}

  func testBackup() async throws {
    let expectation = XCTestExpectation(description: "PortalMpc.backup()")
    try mpc?.setPassword(MockConstants.mockEncryptionKey)
    let backupResponse = try await mpc?.backup(.Password)
    XCTAssert(backupResponse != nil)
    XCTAssert(backupResponse?.shareIds.count ?? 0 > 0)
    XCTAssertEqual(backupResponse?.cipherText, MockConstants.mockCiphertext)
    for shareId in backupResponse?.shareIds ?? [] {
      XCTAssertEqual(shareId, MockConstants.mockMpcShareId)
    }
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testBackupCompletion() throws {
    let expectation = XCTestExpectation(description: "Backup")
    try mpc?.setPassword(MockConstants.mockEncryptionKey)
    var encounteredStatuses: Set<MpcStatuses> = []
    self.mpc?.backup(method: BackupMethods.Password.rawValue) { result in
      guard result.error == nil else {
        XCTFail("Failure: \(String(describing: result.error))")
        expectation.fulfill()
        return
      }
      guard let cipherText = result.data else {
        XCTFail("Unable to parse cipherText")
        expectation.fulfill()
        return
      }
      XCTAssertEqual(cipherText, MockConstants.mockCiphertext)
      expectation.fulfill()
    } progress: { MpcStatus in
      let status = MpcStatus.status
      encounteredStatuses.insert(status)
    }
    wait(for: [expectation], timeout: 5.0)
    XCTAssertEqual(encounteredStatuses, MockConstants.backupProgressCallbacks)
  }

  func testEject() throws {}

  func testGenerate() async throws {
    let expectation = XCTestExpectation(description: "PortalMpc.generate()")
    let generateResponse = try await mpc?.generate()
    XCTAssert(generateResponse != nil)
    XCTAssertEqual(generateResponse?[.eip155], MockConstants.mockEip155Address)
    XCTAssertEqual(generateResponse?[.solana], MockConstants.mockSolanaAddress)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testGenerateCompletion() throws {
    let expectation = XCTestExpectation(description: "Generate")
    var encounteredStatuses: Set<MpcStatuses> = []
    self.mpc?.generate { addressResult in
      guard addressResult.error == nil else {
        XCTFail("Failure: \(String(describing: addressResult.error))")
        expectation.fulfill()
        return
      }
      guard let address = addressResult.data else {
        XCTFail("Unable to parse address")
        return
      }
      XCTAssertEqual(address, MockConstants.mockEip155Address)
      expectation.fulfill()
    } progress: { MpcStatus in
      let status = MpcStatus.status
      encounteredStatuses.insert(status)
    }
    wait(for: [expectation], timeout: 5.0)
    XCTAssertEqual(encounteredStatuses, MockConstants.generateProgressCallbacks)
  }

  func testRecover() async throws {
    let expectation = XCTestExpectation(description: "PortalMpc.recover()")
    let recoverResponse = try await mpc?.generate()
    XCTAssert(recoverResponse != nil)
    XCTAssertEqual(recoverResponse?[.eip155], MockConstants.mockEip155Address)
    XCTAssertEqual(recoverResponse?[.solana], MockConstants.mockSolanaAddress)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testRecoverCompletion() throws {
    let expectation = XCTestExpectation(description: "Recover")
    try mpc?.setPassword(MockConstants.mockEncryptionKey)
    var encounteredStatuses: Set<MpcStatuses> = Set()
    self.mpc?.recover(cipherText: MockConstants.mockCiphertext, method: BackupMethods.Password.rawValue) { result in
      guard result.error == nil else {
        XCTFail("Failure: \(String(describing: result.error))")
        expectation.fulfill()
        return
      }
      guard let address = result.data else {
        XCTFail("Unable to parse addresses")
        return
      }
      XCTAssertEqual(address, MockConstants.mockEip155Address)
      expectation.fulfill()
    } progress: { MpcStatus in
      let status = MpcStatus.status
      encounteredStatuses.insert(status)
    }
    wait(for: [expectation], timeout: 5.0)
    XCTAssertEqual(encounteredStatuses, MockConstants.recoverProgressCallbacks)
  }
}
