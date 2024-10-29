//
//  PortalEncryptionTests.swift
//
//
//  Created by Blake Williams on 4/1/24.
//
@testable import PortalSwift
import XCTest

final class PortalEncryptionTests: XCTestCase {
  var encryption: PortalEncryption? = nil

  override func setUpWithError() throws {
    encryption = PortalEncryption(binary: MockMobileWrapper())
  }

  override func tearDownWithError() throws {
    encryption = nil
  }
}

// MARK: - Decrypt test

extension PortalEncryptionTests {
  func testDecrypt() async throws {
    let expectation = XCTestExpectation(description: "PortalEncryption.decrypt(value)")
    let valueData = try JSONEncoder().encode(MockConstants.mockGenerateResponse)
    guard let value = String(data: valueData, encoding: .utf8) else {
      throw PortalEncryptionError.unableToEncodeData
    }
    let decryptionResult = try await encryption?.decrypt(value, withPrivateKey: MockConstants.mockEncryptionKey)
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
    let decryptionResult = try await encryption?.decrypt(value, withPassword: MockConstants.mockEncryptionKey)
    XCTAssertEqual(decryptionResult, MockConstants.mockDecryptedShare)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func test_decryptWithPrivateKey_willCall_mobileMobileDecrypt_onlyOnce() async throws {
    // given
    let mobileSpy = MobileSpy()
    encryption = PortalEncryption(binary: mobileSpy)

    // and given
    _ = try? await encryption?.decrypt("", withPrivateKey: "")

    // then
    XCTAssertEqual(mobileSpy.mobileDecryptCallsCount, 1)
  }

  func test_decryptWithPrivateKey_willCall_mobileMobileDecrypt_passingCorrectValues() async throws {
    // given
    let value = "test-value"
    let privateKey = "private-key"
    let mobileSpy = MobileSpy()
    encryption = PortalEncryption(binary: mobileSpy)

    // and given
    _ = try? await encryption?.decrypt(value, withPrivateKey: privateKey)

    // then
    XCTAssertEqual(mobileSpy.mobileDecryptKeyParam, privateKey)
    XCTAssertEqual(mobileSpy.mobileDecryptDkgCipherTextParam, value)
  }

  func test_decryptWithPassword_willCall_mobileMobileDecrypt_onlyOnce() async throws {
    // given
    let mobileSpy = MobileSpy()
    encryption = PortalEncryption(binary: mobileSpy)

    // and given
    _ = try? await encryption?.decrypt("", withPassword: "")

    // then
    XCTAssertEqual(mobileSpy.mobileDecryptWithPasswordCallsCount, 1)
  }

  func test_decryptWithPassword_willCall_mobileMobileDecrypt_passingCorrectValues() async throws {
    // given
    let value = "test-value"
    let password = "test-password"
    let mobileSpy = MobileSpy()
    encryption = PortalEncryption(binary: mobileSpy)

    // and given
    _ = try? await encryption?.decrypt(value, withPassword: password)

    // then
    XCTAssertEqual(mobileSpy.mobileDecryptWithPasswordKeyParam, password)
    XCTAssertEqual(mobileSpy.mobileDecryptWithPasswordDkgCipherTextParam, value)
  }
}

// MARK: - Encrypt test

extension PortalEncryptionTests {
  func testEncrypt() async throws {
    let expectation = XCTestExpectation(description: "PortalEncryption.encrypt(value)")
    let valueData = try JSONEncoder().encode(MockConstants.mockGenerateResponse)
    guard let value = String(data: valueData, encoding: .utf8) else {
      throw PortalEncryptionError.unableToEncodeData
    }
    let encryptedData = try await encryption?.encrypt(value)
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
    let encryptedData = try await encryption?.encrypt(value, withPassword: MockConstants.mockEncryptionKey)
    XCTAssertEqual(encryptedData, MockConstants.mockCiphertext)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func test_encrypt_willCall_mobileMobileEncrypt_onlyOnce() async throws {
    // given
    let mobileSpy = MobileSpy()
    encryption = PortalEncryption(binary: mobileSpy)

    // and given
    _ = try? await encryption?.encrypt("")

    // then
    XCTAssertEqual(mobileSpy.mobileEncryptCallsCount, 1)
  }

  func test_encrypt_willCall_mobileMobileEncrypt_passingCorrectValues() async throws {
    // given
    let value = "test-value"
    let mobileSpy = MobileSpy()
    encryption = PortalEncryption(binary: mobileSpy)

    // and given
    _ = try? await encryption?.encrypt(value)

    // then
    XCTAssertEqual(mobileSpy.mobileEncryptValueParam, value)
  }

  func test_encryptWithPassword_willCall_mobileMobileEncrypt_onlyOnce() async throws {
    // given
    let mobileSpy = MobileSpy()
    encryption = PortalEncryption(binary: mobileSpy)

    // and given
    _ = try? await encryption?.encrypt("", withPassword: "")

    // then
    XCTAssertEqual(mobileSpy.mobileEncryptWithPasswordCallsCount, 1)
  }

  func test_encryptWithPassword_willCall_mobileMobileEncrypt_passingCorrectValues() async throws {
    // given
    let value = "test-value"
    let password = "test-password"
    let mobileSpy = MobileSpy()
    encryption = PortalEncryption(binary: mobileSpy)

    // and given
    _ = try? await encryption?.encrypt(value, withPassword: password)

    // then
    XCTAssertEqual(mobileSpy.mobileEncryptWithPasswordValueParam, value)
    XCTAssertEqual(mobileSpy.mobileEncryptWithPasswordPasswordParam, password)
  }
}
