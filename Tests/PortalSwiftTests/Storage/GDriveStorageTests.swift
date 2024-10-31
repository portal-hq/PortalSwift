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
  var storage: GDriveStorage? = nil
  var portalApi: PortalApiProtocol? = nil

  override func setUpWithError() throws {
    initGDriveStorage()
  }

  override func tearDownWithError() throws {
    storage = nil
  }

  func testDecrypt() async throws {
    let expectation = XCTestExpectation(description: "PasswordStorage.write(value)")
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

  func testEncrypt() async throws {
    let expectation = XCTestExpectation(description: "GDriveStorage.write(value)")
    let shareData = try JSONEncoder().encode(MockConstants.mockWalletSigningShare)
    guard let shareString = String(data: shareData, encoding: .utf8) else {
      throw PasswordStorageError.unableToEncodeData
    }
    let encryptedData = try await storage?.encrypt(shareString)
    XCTAssertEqual(encryptedData, MockConstants.mockEncryptData)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testValidateOperations() async throws {}
}

// MARK: - test helpers

extension GDriveStorageTests {
  func initGDriveStorage(
    mobile: Mobile? = nil,
    encryption: PortalEncryptionProtocol? = nil,
    driveClient: GDriveClientProtocol? = nil,
    portalRequests: PortalRequestsProtocol? = nil
  ) {
    let mobileSpy = mobile ?? MobileSpy()
    let encryptionObj = encryption ?? MockPortalEncryption()
    let clientId = driveClient ?? MockGDriveClient()
    let requests = portalRequests ?? MockPortalRequests()
    storage = GDriveStorage(mobile: mobileSpy, encryption: encryptionObj, driveClient: clientId)
    portalApi = PortalApi(apiKey: MockConstants.mockApiKey, requests: requests)
    storage?.api = portalApi
  }
}

// MARK: - delete test

extension GDriveStorageTests {
  func testDelete() async throws {
    let expectation = XCTestExpectation(description: "GDriveStorage.write(value)")
    let success = try await storage?.delete() ?? false
    XCTAssertTrue(success)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func test_delete_willCall_driveGetIdForFilename_onlyOnce() async throws {
    // given
    let driveClient = GDriveClientSpy()
    initGDriveStorage(driveClient: driveClient)

    // and given
    _ = try await storage?.delete()

    // then
    XCTAssertEqual(driveClient.getIdForFilenameCallsCount, 1)
  }

//  func test_delete_willCall_driveGetIdForFilename_passingCorrectFilename() async throws {
//    // given
//    let driveClient = GDriveClientSpy()
//    initGDriveStorage(driveClient: driveClient)
//    let filename = try await storage?.getFilename() ?? ""
//
//    // and given
//    _ = try await storage?.delete()
//
//    // then
//    XCTAssertEqual(driveClient.getIdForFilenameFilenameParam, filename)
//  }

  func test_delete_willCall_driveDelete_onlyOnce() async throws {
    // given
    let driveClient = GDriveClientSpy()
    initGDriveStorage(driveClient: driveClient)

    // and given
    _ = try await storage?.delete()

    // then
    XCTAssertEqual(driveClient.deleteCallsCount, 1)
  }

  func test_delete_willCall_driveDelete_passingCorrectFileId() async throws {
    // given
    let testId = "test-id"
    let driveClient = GDriveClientSpy()
    initGDriveStorage(driveClient: driveClient)
    driveClient.getIdForFilenameReturnValue = testId

    // and given
    _ = try await storage?.delete()

    // then
    XCTAssertEqual(driveClient.deleteKeyParam, testId)
  }
}

// MARK: - read test

extension GDriveStorageTests {
//  func testRead() async throws {
//    let expectation = XCTestExpectation(description: "GDriveStorage.write(value)")
//    let result = try await storage?.read()
//    XCTAssertEqual(result, MockConstants.mockEncryptionKey)
//    expectation.fulfill()
//    await fulfillment(of: [expectation], timeout: 5.0)
//  }
//
//  func test_read_willCall_driveGetIdForFilename_onlyOnce() async throws {
//    // given
//    let driveClient = GDriveClientSpy()
//    initGDriveStorage(driveClient: driveClient)
//
//    // and given
//    _ = try await storage?.read()
//
//    // then
//    XCTAssertEqual(driveClient.getIdForFilenameCallsCount, 1)
//  }

//  func test_read_willCall_driveGetIdForFilename_passingCorrectFilename() async throws {
//    // given
//    let driveClient = GDriveClientSpy()
//    initGDriveStorage(driveClient: driveClient)
//    let filename = try await storage?.getFilename() ?? ""
//
//    // and given
//    _ = try await storage?.read()
//
//    // then
//    XCTAssertEqual(driveClient.getIdForFilenameFilenameParam, filename)
//  }

  func test_read_willCall_driveRecoverFiles_onlyOnce() async throws {
    // given
    let driveClient = GDriveClientSpy()
    initGDriveStorage(driveClient: driveClient)

    // and given
    _ = try await storage?.read()

    // then
    XCTAssertEqual(driveClient.recoverFilesCallsCount, 1)
  }

  func test_read_willCall_driveRecoverFiles_passingCorrectFileId() async throws {
    // given
    let recoverFiles = [
      "ios": "b04be2b5803a6aec128101a506baafb34a90d16bba8d30133c9f5bd21236ff82",
      "web_sdk": "347847577",
      "default": "347847577",
      "android": "347847577",
      "react_native": "347847577"
    ]

    let driveClient = GDriveClientSpy()
    initGDriveStorage(driveClient: driveClient)

    // and given
    _ = try await storage?.read()

    // then
    XCTAssertEqual(driveClient.recoverFilesHashesParam, recoverFiles)
  }
}

// MARK: - signIn test

extension GDriveStorageTests {
  func testSignIn() async throws {
    let expectation = XCTestExpectation(description: "GDriveStorage.write(value)")

    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func test_signIn_willThrowCorrectError_whenDriveAuthNotAvailable() async throws {
    // given
    let driveClient = GDriveClientSpy()
    driveClient.auth = nil
    initGDriveStorage(driveClient: driveClient)

    do {
      // and given
      _ = try await storage?.signIn()
      XCTFail("Expected error not thrown when calling GDriveStorage.signIn() when there is no GDriveClient.auth object.")
    } catch {
      // then
      XCTAssertEqual(error as? GDriveClientError, GDriveClientError.authenticationNotInitialized("Please call Portal.setGDriveConfiguration() to configure GoogleDrive"))
    }
  }
}

// MARK: - validateOperations test

extension GDriveStorageTests {
  func test_validateOperations_willCall_driveValidateOperations_onlyOnce() async throws {
    // given
    let driveClient = GDriveClientSpy()
    initGDriveStorage(driveClient: driveClient)

    // and given
    _ = try await storage?.validateOperations()

    // then
    XCTAssertEqual(driveClient.validateOperationsCallsCount, 1)
  }
}

// MARK: - write test

extension GDriveStorageTests {
  func testWrite() async throws {
    let expectation = XCTestExpectation(description: "GDriveStorage.write(value)")
    let success = try await storage?.write(MockConstants.mockEncryptionKey) ?? false
    XCTAssertTrue(success)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func test_write_willCall_driveWrite_onlyOnce() async throws {
    // given
    let driveClient = GDriveClientSpy()
    initGDriveStorage(driveClient: driveClient)

    // and given
    _ = try await storage?.write("")

    // then
    XCTAssertEqual(driveClient.writeCallsCount, 1)
  }

//  func test_write_willCall_driveWrite_passingCorrectParams() async throws {
//    // given
//    let driveClient = GDriveClientSpy()
//    initGDriveStorage(driveClient: driveClient)
//    let filename = try await storage?.getFilename() ?? ""
//    let value = "test-value"
//
//    // and given
//    _ = try await storage?.write(value)
//
//    // then
//    XCTAssertEqual(driveClient.writeFilenameParam, filename)
//    XCTAssertEqual(driveClient.writeWithContentParam, value)
//  }
}

// MARK: - getFilename test

// extension GDriveStorageTests {
//  func test_getFilename() async throws {
//    // given
//    let filename = try await storage?.getFilename()
//
//    // then
//    XCTAssertEqual(filename, "e927fcd90a6aee8f929cfe0765e00342a50ea0e4e9ef3e4973798a3546a7d45c.txt")
//  }
//
//  func test_getFilename_willThrowCorrectError_whenApiIsNotAvailable() async throws {
//    // given
//    storage?.api = nil
//
//    do {
//      // given
//      _ = try await storage?.getFilename()
//      XCTFail("Expected error not thrown when calling GDriveStorage.getFilename() when there is no api object available.")
//    } catch {
//      // then
//      XCTAssertEqual(error as? GDriveStorageError, GDriveStorageError.portalApiNotConfigured)
//    }
//  }
// }

// MARK: - hash test

// extension GDriveStorageTests {
//  func test_hash() async throws {
//    // given
//    let testValue = "test-value"
//    let hashValue = GDriveStorage.hash(testValue)
//
//    // then
//    XCTAssertEqual(hashValue, "5b1406fffc9de5537eb35a845c99521f26fba0e772d58b42e09f4221b9e043ae")
//  }
// }

// MARK: - encrypt tests

extension GDriveStorageTests {
  func test_encrypt_willCall_encryptionEncrypt_onlyOnce() async throws {
    // given
    let portalEncryption = PortalEncryptionSpy()
    initGDriveStorage(encryption: portalEncryption)

    // and given
    _ = try await storage?.encrypt("")

    // then
    XCTAssertEqual(portalEncryption.encryptCallsCount, 1)
  }

  func test_encrypt_willCall_encryptionEncrypt_passingCorrectParams() async throws {
    // given
    let portalEncryption = PortalEncryptionSpy()
    initGDriveStorage(encryption: portalEncryption)

    let testToEncrypt = "test-text"

    // and given
    _ = try await storage?.encrypt(testToEncrypt)

    // then
    XCTAssertEqual(portalEncryption.encryptValueParam, testToEncrypt)
  }
}

// MARK: - decrypt tests

extension GDriveStorageTests {
  func test_decrypt_willCall_encryptionDecrypt_onlyOnce() async throws {
    // given
    let portalEncryption = PortalEncryptionSpy()
    initGDriveStorage(encryption: portalEncryption)

    // and given
    _ = try await storage?.decrypt("", withKey: "")

    // then
    XCTAssertEqual(portalEncryption.decryptWithPrivateKeyCallsCount, 1)
  }

  func test_decrypt_willCall_encryptionDecrypt_passingCorrectParams() async throws {
    // given
    let portalEncryption = PortalEncryptionSpy()
    initGDriveStorage(encryption: portalEncryption)

    let value = "test-value"
    let privateKey = "test-key"

    // and given
    _ = try await storage?.decrypt(value, withKey: privateKey)

    // then
    XCTAssertEqual(portalEncryption.decryptWithPrivateKeyValueParam, value)
    XCTAssertEqual(portalEncryption.decryptWithPrivateKeyPrivateKeyParam, privateKey)
  }
}
