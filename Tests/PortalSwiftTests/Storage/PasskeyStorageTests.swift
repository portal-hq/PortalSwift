//
//  PasskeyStorageTests.swift
//
//
//  Created by Blake Williams on 3/31/24.
//

import AuthenticationServices
@testable import PortalSwift
import XCTest

// TODO: - To test the integration with `PasskeyAuth`, but we need to refactor some code for that to not expose more public functions.
// TODO: - To test the integration with `PortalRequests`, in order to do that we need to refactor the functions to be each function doing only one thing and to enable controlling the functions that depends on the `sessionId`

@available(iOS 16, *)
final class PasskeyStorageTests: XCTestCase {
  var storage: PasskeyStorage?

  override func setUpWithError() throws {
    initPasskeyStorage()
  }

  override func tearDownWithError() throws {
    storage = nil
  }
}

// MARK: - Test Helpers

@available(iOS 16, *)
extension PasskeyStorageTests {
  func initPasskeyStorage(
    requests: PortalRequestsProtocol? = nil
  ) {
    let portalRequests = requests ?? MockPortalRequests()
    storage = PasskeyStorage(auth: MockPasskeyAuth(), encryption: MockPortalEncryption(), requests: portalRequests)
    storage?.apiKey = MockConstants.mockApiKey
    storage?.api = PortalApi(apiKey: MockConstants.mockApiKey, requests: MockPortalRequests())
    DispatchQueue.main.async {
      self.storage?.anchor = MockAuthenticationAnchor()
    }
  }
}

// MARK: - decrypt  tests

@available(iOS 16, *)
extension PasskeyStorageTests {
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
}

// MARK: - encrypt tests

@available(iOS 16, *)
extension PasskeyStorageTests {
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
}

// MARK: - read tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func testRead() async throws {
    let expectation = XCTestExpectation(description: "PasskeyStorage.write(value)")
    let result = try await storage?.read()
    XCTAssertEqual(result, MockConstants.mockEncryptionKey)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func test_read_willCall_requestPost_twice() async throws {
    // given
    let portalRequestsSpy = MockPortalRequests()
    initPasskeyStorage(requests: portalRequestsSpy)

    // and given
    _ = try await storage?.read()

    let postCallsCount = await portalRequestsSpy.postCallsCount

    // then
    XCTAssertEqual(postCallsCount, 2)
  }
}

// MARK: - write tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func testWrite() async throws {
    let expectation = XCTestExpectation(description: "PasskeyStorage.write(value)")
    let success = try await storage?.write(MockConstants.mockEncryptionKey) ?? false
    XCTAssertTrue(success)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func test_write_willCall_requestGet_onlyOnce() async throws {
    // given
    let portalRequestsSpy = MockPortalRequests()
    initPasskeyStorage(requests: portalRequestsSpy)

    // and given
    _ = try await storage?.write("")

    let getCallsCount = await portalRequestsSpy.getCallsCount

    // then
    XCTAssertEqual(getCallsCount, 1)
  }
}

// MARK: - delete tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_delete_willThrowCorrectError() async throws {
    do {
      // given
      _ = try await storage?.delete()
      XCTFail("Expected error not thrown when calling PasskeyStorage.delete().")
    } catch {
      XCTAssertEqual(error as? StorageError, StorageError.mustExtendStorageClass)
    }
  }
}

// MARK: - validateOperations tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_validateOperation_willReturnTrueAlways() async throws {
    // given
    let isValid = try await storage?.validateOperations() ?? false

    // then
    XCTAssertTrue(isValid)
  }
}

// MARK: - beginLogin tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_beginLogin_willCall_requestPost_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try JSONEncoder().encode(MockConstants.mockPasskeyAuthenticationOptions)
    initPasskeyStorage(requests: portalRequestsSpy)

    // and given
    _ = try await storage?.beginLogin()

    // then
    XCTAssertEqual(portalRequestsSpy.postCallsCount, 1)
  }

  func test_beginLogin_willCall_requestPost_passingCorrectUrlPathAndPayload() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try JSONEncoder().encode(MockConstants.mockPasskeyAuthenticationOptions)
    initPasskeyStorage(requests: portalRequestsSpy)

    // and given
    _ = try await storage?.beginLogin()

    // then
    XCTAssertEqual(portalRequestsSpy.postFromParam?.path(), "/passkeys/begin-login")
    XCTAssertEqual(portalRequestsSpy.postAndPayloadParam as? [String: String], ["relyingParty": "portalhq.io"])
  }
}

// MARK: - beginRegistration tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_beginRegistration_willCall_requestPost_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try JSONEncoder().encode(MockConstants.mockPasskeyRegistrationOptions)
    initPasskeyStorage(requests: portalRequestsSpy)

    // and given
    _ = try await storage?.beginRegistration()

    // then
    XCTAssertEqual(portalRequestsSpy.postCallsCount, 1)
  }

  func test_beginRegistration_willCall_requestPost_passingCorrectUrlPathAndPayload() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try JSONEncoder().encode(MockConstants.mockPasskeyRegistrationOptions)
    initPasskeyStorage(requests: portalRequestsSpy)

    // and given
    _ = try await storage?.beginRegistration()

    // then
    XCTAssertEqual(portalRequestsSpy.postFromParam?.path(), "/passkeys/begin-registration")
    XCTAssertEqual(portalRequestsSpy.postAndPayloadParam as? [String: String], ["relyingParty": "portalhq.io"])
  }
}

// MARK: - getPasskeyStatus tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_getPasskeyStatus_willCall_requestGet_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try JSONEncoder().encode(MockConstants.mockPasskeyStatus)
    initPasskeyStorage(requests: portalRequestsSpy)

    // and given
    _ = try await storage?.getPasskeyStatus()

    // then
    XCTAssertEqual(portalRequestsSpy.getCallsCount, 1)
  }

  func test_getPasskeyStatus_willCall_requestGet_passingCorrectUrlPath() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try JSONEncoder().encode(MockConstants.mockPasskeyStatus)
    initPasskeyStorage(requests: portalRequestsSpy)

    // and given
    _ = try await storage?.getPasskeyStatus()

    // then
    XCTAssertEqual(portalRequestsSpy.getFromParam?.path(), "/passkeys/status")
  }
}

// MARK: - handleFinishLoginRead tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_handleFinishLoginRead_willThrowCorrectError_whenThereIsNoSessionId() async throws {
    do {
      // given
      _ = try await storage?.handleFinishLoginRead("")
      XCTFail("Expected error not thrown when calling PasskeyStorage.handleFinishLoginRead() when there is no sessionId.")
    } catch {
      // then
      XCTAssertEqual(error as? PasskeyStorageError, PasskeyStorageError.readError)
    }
  }
}

// MARK: - handleFinishLoginWrite tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_handleFinishLoginWrite_willThrowCorrectError_whenThereIsNoSessionId() async throws {
    do {
      // given
      _ = try await storage?.handleFinishLoginWrite("", withValue: "")
      XCTFail("Expected error not thrown when calling PasskeyStorage.handleFinishLoginWrite() when there is no sessionId.")
    } catch {
      // then
      XCTAssertEqual(error as? PasskeyStorageError, PasskeyStorageError.writeError)
    }
  }
}

// MARK: - handleFinishRegistration tests

@available(iOS 16, *)
extension PasskeyStorageTests {
  func test_handleFinishRegistration_willThrowCorrectError_whenThereIsNoSessionId() async throws {
    do {
      // given
      _ = try await storage?.handleFinishRegistration("", withPrivateKey: "")
      XCTFail("Expected error not thrown when calling PasskeyStorage.handleFinishLoginWrite() when there is no sessionId.")
    } catch {
      // then
      XCTAssertEqual(error as? PasskeyStorageError, PasskeyStorageError.writeError)
    }
  }
}

// MARK: -  tests

@available(iOS 16, *)
extension PasskeyStorageTests {}
