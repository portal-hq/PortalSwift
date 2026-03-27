//
//  FirebaseStorageTests.swift
//
//
//  Created by Portal Labs, Inc.
//

@testable import PortalSwift
import XCTest

final class FirebaseStorageTests: XCTestCase {
  var storage: FirebaseStorage?

  override func setUpWithError() throws {
    initFirebaseStorage()
  }

  override func tearDownWithError() throws {
    storage = nil
  }
}

// MARK: - Test Helpers

extension FirebaseStorageTests {
  func initFirebaseStorage(
    getToken: (() async throws -> String?)? = nil,
    requests: PortalRequestsProtocol? = nil
  ) {
    let portalRequests = requests ?? MockPortalRequests()
    let tokenProvider = getToken ?? { return "mock-firebase-token" }

    storage = FirebaseStorage(
      getToken: tokenProvider,
      tbsHost: "backup.web.portalhq.io",
      encryption: MockPortalEncryption(),
      requests: portalRequests
    )
    storage?.apiKey = MockConstants.mockApiKey
    storage?.api = PortalApi(apiKey: MockConstants.mockApiKey, requests: MockPortalRequests())
  }

  func initFirebaseStorageWithSpy(
    getToken: (() async throws -> String?)? = nil
  ) -> PortalRequestsSpy {
    let spy = PortalRequestsSpy()
    let tokenProvider = getToken ?? { return "mock-firebase-token" }

    storage = FirebaseStorage(
      getToken: tokenProvider,
      tbsHost: "backup.web.portalhq.io",
      encryption: MockPortalEncryption(),
      requests: spy
    )
    storage?.apiKey = MockConstants.mockApiKey
    storage?.api = PortalApi(apiKey: MockConstants.mockApiKey, requests: MockPortalRequests())

    return spy
  }
}

// MARK: - decrypt tests

extension FirebaseStorageTests {
  func testDecrypt() async throws {
    let mockGenerateResponse = try MockConstants.mockGenerateResponse
    let decryptResult = try await storage?.decrypt(MockConstants.mockCiphertext, withKey: MockConstants.mockEncryptionKey)
    guard let decryptedData = decryptResult?.data(using: .utf8) else {
      throw FirebaseStorageError.unexpectedResponse("Unable to decode data")
    }
    let generateResponse = try JSONDecoder().decode(PortalMpcGenerateResponse.self, from: decryptedData)
    XCTAssertEqual(generateResponse["ED25519"]?.id, mockGenerateResponse["ED25519"]?.id)
    XCTAssertEqual(generateResponse["SECP256K1"]?.id, mockGenerateResponse["SECP256K1"]?.id)
  }
}

// MARK: - encrypt tests

extension FirebaseStorageTests {
  func testEncrypt() async throws {
    let shareData = try JSONEncoder().encode(MockConstants.mockWalletSigningShare)
    guard let shareString = String(data: shareData, encoding: .utf8) else {
      throw FirebaseStorageError.unexpectedResponse("Unable to encode data")
    }
    let encryptedData = try await storage?.encrypt(shareString)
    XCTAssertEqual(encryptedData, MockConstants.mockEncryptData)
  }
}

// MARK: - read tests

extension FirebaseStorageTests {
  func testRead() async throws {
    let spy = initFirebaseStorageWithSpy()

    // Set up return data for the GET request
    let mockResponse = FirebaseEncryptionKeyResponse(encryptionKey: MockConstants.mockEncryptionKey)
    spy.returnData = try JSONEncoder().encode(mockResponse)

    let result = try await storage?.read()
    XCTAssertEqual(result, MockConstants.mockEncryptionKey)
  }

  func test_read_willCall_executeRequest_once() async throws {
    let spy = initFirebaseStorageWithSpy()

    let mockResponse = FirebaseEncryptionKeyResponse(encryptionKey: MockConstants.mockEncryptionKey)
    spy.returnData = try JSONEncoder().encode(mockResponse)

    _ = try await storage?.read()

    XCTAssertEqual(spy.executeCallsCount, 1)
  }

  func test_read_sendsCorrectURLPathAndMethod() async throws {
    let spy = initFirebaseStorageWithSpy()

    let mockResponse = FirebaseEncryptionKeyResponse(encryptionKey: MockConstants.mockEncryptionKey)
    spy.returnData = try JSONEncoder().encode(mockResponse)

    _ = try await storage?.read()

    XCTAssertEqual(spy.executeRequestParam?.method, .get)
    XCTAssertTrue(spy.executeRequestParam?.url.absoluteString.contains("/v1/backup/encrypt-key") ?? false)
  }

  func test_read_includesFirebaseTokenHeader() async throws {
    let spy = initFirebaseStorageWithSpy()

    let mockResponse = FirebaseEncryptionKeyResponse(encryptionKey: MockConstants.mockEncryptionKey)
    spy.returnData = try JSONEncoder().encode(mockResponse)

    _ = try await storage?.read()

    XCTAssertEqual(spy.executeRequestParam?.headers["X-Firebase-Token"], "mock-firebase-token")
  }

  func test_read_includesAuthorizationHeader() async throws {
    let spy = initFirebaseStorageWithSpy()

    let mockResponse = FirebaseEncryptionKeyResponse(encryptionKey: MockConstants.mockEncryptionKey)
    spy.returnData = try JSONEncoder().encode(mockResponse)

    _ = try await storage?.read()

    XCTAssertEqual(spy.executeRequestParam?.headers["Authorization"], "Bearer \(MockConstants.mockApiKey)")
  }

  func test_read_throwsError_whenNoApiKey() async throws {
    storage?.apiKey = nil

    do {
      _ = try await storage?.read()
      XCTFail("Expected FirebaseStorageError.noApiKey to be thrown")
    } catch {
      XCTAssertTrue(error is FirebaseStorageError)
    }
  }

  func test_read_throwsError_whenTokenCallbackReturnsNil() async throws {
    initFirebaseStorage(getToken: { return nil })
    storage?.apiKey = MockConstants.mockApiKey

    do {
      _ = try await storage?.read()
      XCTFail("Expected FirebaseStorageError.tokenUnavailable to be thrown")
    } catch {
      XCTAssertTrue(error is FirebaseStorageError)
    }
  }
}

// MARK: - write tests

extension FirebaseStorageTests {
  func testWrite() async throws {
    let spy = initFirebaseStorageWithSpy()

    // For PUT, the response is Data type
    spy.returnData = Data()

    let success = try await storage?.write(MockConstants.mockEncryptionKey) ?? false
    XCTAssertTrue(success)
  }

  func test_write_willCall_executeRequest_once() async throws {
    let spy = initFirebaseStorageWithSpy()
    spy.returnData = Data()

    _ = try await storage?.write(MockConstants.mockEncryptionKey)

    XCTAssertEqual(spy.executeCallsCount, 1)
  }

  func test_write_sendsCorrectURLPathAndMethod() async throws {
    let spy = initFirebaseStorageWithSpy()
    spy.returnData = Data()

    _ = try await storage?.write(MockConstants.mockEncryptionKey)

    XCTAssertEqual(spy.executeRequestParam?.method, .put)
    XCTAssertTrue(spy.executeRequestParam?.url.absoluteString.contains("/v1/backup/encrypt-key") ?? false)
  }

  func test_write_includesFirebaseTokenHeader() async throws {
    let spy = initFirebaseStorageWithSpy()
    spy.returnData = Data()

    _ = try await storage?.write(MockConstants.mockEncryptionKey)

    XCTAssertEqual(spy.executeRequestParam?.headers["X-Firebase-Token"], "mock-firebase-token")
  }

  func test_write_includesAuthorizationHeader() async throws {
    let spy = initFirebaseStorageWithSpy()
    spy.returnData = Data()

    _ = try await storage?.write(MockConstants.mockEncryptionKey)

    XCTAssertEqual(spy.executeRequestParam?.headers["Authorization"], "Bearer \(MockConstants.mockApiKey)")
  }

  func test_write_throwsError_whenNoApiKey() async throws {
    storage?.apiKey = nil

    do {
      _ = try await storage?.write(MockConstants.mockEncryptionKey)
      XCTFail("Expected FirebaseStorageError.noApiKey to be thrown")
    } catch {
      XCTAssertTrue(error is FirebaseStorageError)
    }
  }

  func test_write_throwsError_whenTokenCallbackReturnsNil() async throws {
    initFirebaseStorage(getToken: { return nil })
    storage?.apiKey = MockConstants.mockApiKey

    do {
      _ = try await storage?.write(MockConstants.mockEncryptionKey)
      XCTFail("Expected FirebaseStorageError.tokenUnavailable to be thrown")
    } catch {
      XCTAssertTrue(error is FirebaseStorageError)
    }
  }
}

// MARK: - delete tests

extension FirebaseStorageTests {
  func test_delete_throwsDeleteNotSupported() async throws {
    do {
      _ = try await storage?.delete()
      XCTFail("Expected FirebaseStorageError.deleteNotSupported to be thrown")
    } catch {
      XCTAssertTrue(error is FirebaseStorageError)
      XCTAssertEqual(error as? FirebaseStorageError, .deleteNotSupported)
    }
  }
}

// MARK: - validateOperations tests

extension FirebaseStorageTests {
  func test_validateOperations_returnsTrue() async throws {
    let isValid = try await storage?.validateOperations() ?? false
    XCTAssertTrue(isValid)
  }
}

// MARK: - BackupMethods.Firebase tests

extension FirebaseStorageTests {
  func test_firebaseBackupMethod_hasCorrectRawValue() {
    XCTAssertEqual(BackupMethods.Firebase.rawValue, "FIREBASE")
  }

  func test_firebaseBackupMethod_isDecodable() throws {
    let json = "\"FIREBASE\""
    let data = json.data(using: .utf8)!
    let method = try JSONDecoder().decode(BackupMethods.self, from: data)
    XCTAssertEqual(method, .Firebase)
  }

  func test_firebaseBackupMethod_isEncodable() throws {
    let method = BackupMethods.Firebase
    let data = try JSONEncoder().encode(method)
    let string = String(data: data, encoding: .utf8)
    XCTAssertEqual(string, "\"FIREBASE\"")
  }

  func test_firebaseBackupMethod_initFromString() {
    let method = BackupMethods(fromString: "FIREBASE")
    XCTAssertEqual(method, .Firebase)
  }

  func test_firebaseBackupMethod_coexistsWithOtherMethods() {
    // Verify Firebase doesn't conflict with other backup method raw values
    let allMethods: [BackupMethods] = [.GoogleDrive, .iCloud, .local, .Password, .Passkey, .Firebase, .Unknown]
    let rawValues = allMethods.map { $0.rawValue }
    let uniqueRawValues = Set(rawValues)
    XCTAssertEqual(rawValues.count, uniqueRawValues.count, "All backup method raw values should be unique")
  }
}

// MARK: - TBS host configuration tests

extension FirebaseStorageTests {
  func test_tbsHost_defaultsToPortalProduction() {
    let storage = FirebaseStorage(getToken: { return "token" })
    XCTAssertEqual(storage.tbsHost, "https://backup.web.portalhq.io")
  }

  func test_tbsHost_canBeCustomized() {
    let storage = FirebaseStorage(
      getToken: { return "token" },
      tbsHost: "custom-tbs.example.com"
    )
    XCTAssertEqual(storage.tbsHost, "https://custom-tbs.example.com")
  }
}

// MARK: - Error description tests

extension FirebaseStorageTests {
  func test_noApiKeyError_hasDescription() {
    let error = FirebaseStorageError.noApiKey
    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription?.contains("API key") ?? false)
  }

  func test_tokenUnavailableError_hasDescription() {
    let error = FirebaseStorageError.tokenUnavailable
    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription?.contains("token unavailable") ?? false)
  }

  func test_unexpectedResponseError_hasDescription() {
    let error = FirebaseStorageError.unexpectedResponse("test message")
    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription?.contains("test message") ?? false)
  }
}
