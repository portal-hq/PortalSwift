//
//  PortalEncryptionTests.swift
//
//
//  Created by Blake Williams on 4/1/24.
//
@testable import PortalSwift
import XCTest

final class PortalEncryptionTests: XCTestCase {
  let encryption = PortalEncryption(binary: MockMobileWrapper())

  override func setUpWithError() throws {}

  override func tearDownWithError() throws {}

  func testDecrypt() async throws {
    let expectation = XCTestExpectation(description: "PortalEncryption.decrypt(value)")
    let valueData = try JSONEncoder().encode(MockConstants.mockGenerateResponse)
    guard let value = String(data: valueData, encoding: .utf8) else {
      throw PortalEncryptionError.unableToEncodeData
    }
    let decryptionResult = try await encryption.decrypt(value, withPrivateKey: MockConstants.mockEncryptionKey)
    XCTAssertEqual(decryptionResult, MockConstants.mockDecryptedShare)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testDecryptWithPassword() async throws {
    let expectation = XCTestExpectation(description: "PortalEncryption.decrypt(value, withPassword)")
    let valueData = try JSONEncoder().encode(MockConstants.mockGenerateResponse)
    guard let value = String(data: valueData, encoding: .utf8) else {
      throw PortalEncryptionError.unableToEncodeData
    }
    let decryptionResult = try await encryption.decrypt(value, withPassword: MockConstants.mockEncryptionKey)
    XCTAssertEqual(decryptionResult, MockConstants.mockDecryptedShare)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testEncrypt() async throws {
    let expectation = XCTestExpectation(description: "PortalEncryption.encrypt(value)")
    let valueData = try JSONEncoder().encode(MockConstants.mockGenerateResponse)
    guard let value = String(data: valueData, encoding: .utf8) else {
      throw PortalEncryptionError.unableToEncodeData
    }
    let encryptedData = try await encryption.encrypt(value)
    XCTAssertEqual(encryptedData, MockConstants.mockEncryptData)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testEncryptWithPassword() async throws {
    let expectation = XCTestExpectation(description: "PortalEncryption.encrypt(value, withPassword)")
    let valueData = try JSONEncoder().encode(MockConstants.mockGenerateResponse)
    guard let value = String(data: valueData, encoding: .utf8) else {
      throw PortalEncryptionError.unableToEncodeData
    }
    let encryptedData = try await encryption.encrypt(value, withPassword: MockConstants.mockEncryptionKey)
    XCTAssertEqual(encryptedData, MockConstants.mockCiphertext)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }
}
