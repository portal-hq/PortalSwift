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
      api: PortalApi(apiKey: MockConstants.mockApiKey, isMocked: true),
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

  func testRecover() async throws {
    let expectation = XCTestExpectation(description: "PortalMpc.recover()")
    let recoverResponse = try await mpc?.generate()
    XCTAssert(recoverResponse != nil)
    XCTAssertEqual(recoverResponse?[.eip155], MockConstants.mockEip155Address)
    XCTAssertEqual(recoverResponse?[.solana], MockConstants.mockSolanaAddress)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }
}
