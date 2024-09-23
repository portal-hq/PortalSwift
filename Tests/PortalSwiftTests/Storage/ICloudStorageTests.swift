//
//  ICloudStorageTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

@testable import PortalSwift
import XCTest

final class ICloudStorageTests: XCTestCase {
  var storage: ICloudStorage? = nil

  override func setUpWithError() throws {
      initICloudStorage()
  }

  override func tearDownWithError() throws {
      self.storage = nil
  }

}

// MARK: - Test Helpers

extension ICloudStorageTests {
    func initICloudStorage(
        portalKeyValueStore: PortalKeyValueStoreProtocol? = nil,
        portalEncryption: PortalEncryptionProtocol? = nil
    ) {
        let keyValueStore = portalKeyValueStore ?? MockPortalKeyValueStore()
        let encryption = portalEncryption ?? MockPortalEncryption()
        let mobile = MobileSpy()
        self.storage = ICloudStorage(mobile: mobile, encryption: encryption, keyValueStore: keyValueStore)
        self.storage?.api = PortalApi(apiKey: MockConstants.mockApiKey, requests: MockPortalRequests())
    }
}

// MARK: - delete tests
extension ICloudStorageTests {

    func testDelete() async throws {
      let expectation = XCTestExpectation(description: "ICloudStorage.delete()")
      let success = try await storage?.delete() ?? false
      XCTAssertTrue(success)
      expectation.fulfill()
      await fulfillment(of: [expectation], timeout: 5.0)
    }

    func test_delete_willCall_portalKeyValueStoreDelete_onlyOnce() async throws {
        // given
        let portalKeyValueStore = PortalKeyValueStoreSpy()
        initICloudStorage(portalKeyValueStore: portalKeyValueStore)

        // and given
        _ = try await storage?.delete()

        // then
        XCTAssertEqual(portalKeyValueStore.deleteCallsCount, 1)
    }
}

// MARK: - read tests
extension ICloudStorageTests { 

    func testRead() async throws {
      let expectation = XCTestExpectation(description: "ICloudStorage.read()")
      let result = try await storage?.read()
      XCTAssertEqual(result, MockConstants.mockEncryptionKey)
      expectation.fulfill()
      await fulfillment(of: [expectation], timeout: 5.0)
    }

    func test_read_willCall_portalKeyValueStoreRead_onlyOnce() async throws {
        // given
        let portalKeyValueStore = PortalKeyValueStoreSpy()
        portalKeyValueStore.readReturnValue = "any random value"
        initICloudStorage(portalKeyValueStore: portalKeyValueStore)

        // and given
        _ = try await storage?.read()

        // then
        XCTAssertEqual(portalKeyValueStore.readCallsCount, 1)
        
    }
}

// MARK: - write tests
extension ICloudStorageTests {

    func testWrite() async throws {
      let expectation = XCTestExpectation(description: "ICloudStorage.write()")
      let success = try await storage?.write(MockConstants.mockEncryptionKey) ?? false
      XCTAssertTrue(success)
      expectation.fulfill()
      await fulfillment(of: [expectation], timeout: 5.0)
    }

    func test_write_willCall_portalKeyValueStoreWrite_onlyOnce() async throws {
        // given
        let portalKeyValueStore = PortalKeyValueStoreSpy()
        initICloudStorage(portalKeyValueStore: portalKeyValueStore)

        // and given
        _ = try await storage?.write("")

        // then
        XCTAssertEqual(portalKeyValueStore.writeCallsCount, 1)
        
    }
}

// MARK: - validateOperations tests
extension ICloudStorageTests {
    func test_validateOperations_willCall_portalKeyValueStoreWrite_onlyOnce() async throws {
        // given
        let portalKeyValueStore = PortalKeyValueStoreSpy()
        portalKeyValueStore.readReturnValue = "test_value"
        initICloudStorage(portalKeyValueStore: portalKeyValueStore)

        // and given
        _ = try await storage?.validateOperations()

        // then
        XCTAssertEqual(portalKeyValueStore.writeCallsCount, 1)
        
    }

    func test_validateOperations_willCall_portalKeyValueStoreRead_onlyOnce() async throws {
        // given
        let portalKeyValueStore = PortalKeyValueStoreSpy()
        portalKeyValueStore.readReturnValue = "test_value"
        initICloudStorage(portalKeyValueStore: portalKeyValueStore)

        // and given
        _ = try await storage?.validateOperations()

        // then
        XCTAssertEqual(portalKeyValueStore.readCallsCount, 1)
        
    }

    func test_validateOperations_willCall_portalKeyValueStoreDelete_onlyOnce() async throws {
        // given
        let portalKeyValueStore = PortalKeyValueStoreSpy()
        portalKeyValueStore.readReturnValue = "test_value"
        initICloudStorage(portalKeyValueStore: portalKeyValueStore)

        // and given
        _ = try await storage?.validateOperations()

        // then
        XCTAssertEqual(portalKeyValueStore.deleteCallsCount, 1)
        
    }
}

// MARK: - encrypt tests
extension ICloudStorageTests {
    func testEncrypt() async throws {
      let expectation = XCTestExpectation(description: "PasswordStorage.write(value)")
      let shareData = try JSONEncoder().encode(MockConstants.mockWalletSigningShare)
      guard let shareString = String(data: shareData, encoding: .utf8) else {
        throw PasswordStorageError.unableToEncodeData
      }
      let encryptedData = try await storage?.encrypt(shareString)
      XCTAssertEqual(encryptedData, MockConstants.mockEncryptData)
      expectation.fulfill()
      await fulfillment(of: [expectation], timeout: 5.0)
    }

    func test_encrypt_willCall_encryptionEncrypt_onlyOnce() async throws {
        // given
        let portalEncryption = PortalEncryptionSpy()
        initICloudStorage(portalEncryption: portalEncryption)

        // and given
        _ = try await storage?.encrypt("")

        // then
        XCTAssertEqual(portalEncryption.encryptCallsCount, 1)
    }

    func test_encrypt_willCall_encryptionEncrypt_passingCorrectParams() async throws {
        // given
        let portalEncryption = PortalEncryptionSpy()
        initICloudStorage(portalEncryption: portalEncryption)

        let testToEncrypt = "test-text"

        // and given
        _ = try await storage?.encrypt(testToEncrypt)

        // then
        XCTAssertEqual(portalEncryption.encryptValueParam, testToEncrypt)
    }
}

// MARK: - decrypt tests
extension ICloudStorageTests {
    func testDecrypt() async throws {
      let expectation = XCTestExpectation(description: "iCloudStorage.write(value)")
      let mockGenerateResponse = try MockConstants.mockGenerateResponse
      let decryptResult = try await storage?.decrypt(MockConstants.mockCiphertext, withKey: MockConstants.mockEncryptionKey)
      guard let decryptedData = decryptResult?.data(using: .utf8) else {
        throw PasswordStorageError.unableToEncodeData
      }
      let generateResponse = try JSONDecoder().decode(PortalMpcGenerateResponse.self, from: decryptedData)
      XCTAssertEqual(generateResponse["ED25519"]?.id, mockGenerateResponse["ED25519"]?.id)
      XCTAssertEqual(generateResponse["SECP256K1"]?.id, mockGenerateResponse["SECP256K1"]?.id)
      expectation.fulfill()
      await fulfillment(of: [expectation], timeout: 5.0)
    }

    func test_decrypt_willCall_encryptionDecrypt_onlyOnce() async throws {
        // given
        let portalEncryption = PortalEncryptionSpy()
        initICloudStorage(portalEncryption: portalEncryption)

        // and given
        _ = try await storage?.decrypt("", withKey: "")

        // then
        XCTAssertEqual(portalEncryption.decryptWithPrivateKeyCallsCount, 1)
    }

    func test_decrypt_willCall_encryptionDecrypt_passingCorrectParams() async throws {
        // given
        let portalEncryption = PortalEncryptionSpy()
        initICloudStorage(portalEncryption: portalEncryption)

        let value = "test-value"
        let privateKey = "test-key"

        // and given
        _ = try await storage?.decrypt(value, withKey: privateKey)

        // then
        XCTAssertEqual(portalEncryption.decryptWithPrivateKeyValueParam, value)
        XCTAssertEqual(portalEncryption.decryptWithPrivateKeyPrivateKeyParam, privateKey)
    }
}
