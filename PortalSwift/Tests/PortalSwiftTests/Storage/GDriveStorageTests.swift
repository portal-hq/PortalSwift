//
//  GDriveStorageTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

@testable import PortalSwift
import XCTest

final class GDriveStorageTests: XCTestCase {
  var storage = GDriveStorage(encryption: MockPortalEncryption(), driveClient: MockGDriveClient())

  override func setUpWithError() throws {
    self.storage.api = PortalApi(apiKey: MockConstants.mockApiKey, requests: MockPortalRequests())
  }

  override func tearDownWithError() throws {}

  func testDecrypt() async throws {
    let expectation = XCTestExpectation(description: "GDriveStorage.write(value)")
    let mockGenerateResponse = try MockConstants.mockGenerateResponse
    let decryptResult = try await storage.decrypt(MockConstants.mockCiphertext, withKey: MockConstants.mockEncryptionKey)
    guard let decryptedData = decryptResult.data(using: .utf8) else {
      throw PasswordStorageError.unableToEncodeData
    }
    let generateResponse = try JSONDecoder().decode(PortalMpcGenerateResponse.self, from: decryptedData)
    XCTAssertEqual(generateResponse["ED25519"]?.id, mockGenerateResponse["ED25519"]?.id)
    XCTAssertEqual(generateResponse["SECP256K1"]?.id, mockGenerateResponse["SECP256K1"]?.id)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testDelete() async throws {
    let expectation = XCTestExpectation(description: "GDriveStorage.write(value)")
    let success = try await storage.delete()
    XCTAssertTrue(success)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testEncrypt() async throws {
    let expectation = XCTestExpectation(description: "GDriveStorage.write(value)")
    let shareData = try JSONEncoder().encode(MockConstants.mockWalletSigningShare)
    guard let shareString = String(data: shareData, encoding: .utf8) else {
      throw PasswordStorageError.unableToEncodeData
    }
    let encryptedData = try await storage.encrypt(shareString)
    XCTAssertEqual(encryptedData, MockConstants.mockEncryptData)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testRead() async throws {
    let expectation = XCTestExpectation(description: "GDriveStorage.write(value)")
    let result = try await storage.read()
    XCTAssertEqual(result, MockConstants.mockEncryptionKey)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testSignIn() async throws {
    let expectation = XCTestExpectation(description: "GDriveStorage.write(value)")

    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testValidateOperations() async throws {}

  func testWrite() async throws {
    let expectation = XCTestExpectation(description: "GDriveStorage.write(value)")
    let success = try await storage.write(MockConstants.mockEncryptionKey)
    XCTAssertTrue(success)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }
}
