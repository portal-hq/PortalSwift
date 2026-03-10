//
//  PortalKeychainTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

@testable import PortalSwift
import XCTest

final class PortalKeychainTests: XCTestCase {
  var keychain: PortalKeychainProtocol!
  var portalApi: PortalApiProtocol!
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  override func setUpWithError() throws {
    keychain = PortalKeychain(keychainAccess: MockPortalKeychainAccess())
    self.portalApi = PortalApi(
      apiKey: MockConstants.mockApiKey,
      apiHost: MockConstants.mockHost,
      requests: MockPortalRequests()
    )
    self.keychain.api = portalApi
  }

  override func tearDownWithError() throws {
    keychain = nil
  }
}

// MARK: - Test Helpers

extension PortalKeychainTests {
  func initKeychainWith(
    keychainAccess: PortalKeychainAccessProtocol? = nil,
    api: PortalApiProtocol? = PortalApi(
      apiKey: MockConstants.mockApiKey,
      apiHost: MockConstants.mockHost,
      requests: MockPortalRequests()
    )
  ) {
    keychain = PortalKeychain(keychainAccess: keychainAccess)
    self.portalApi = api
    keychain.api = portalApi
  }
}

// MARK: - delete shares tests

extension PortalKeychainTests {
  func test_deleteShares_willCall_keyChainAccess_deleteItem_onlyOnce() async throws {
    // given
    let keychainAccess = PortalKeyChainAccessSpy()
    initKeychainWith(keychainAccess: keychainAccess)

    // and given
    try await keychain.deleteShares()

    // then
    XCTAssertEqual(keychainAccess.deleteItemCallsCount, 1)
  }

  func test_deleteShares_willCall_keyChainAccess_deleteItem_passingCorrectParams() async throws {
    // given
    let keychainAccess = PortalKeyChainAccessSpy()
    initKeychainWith(keychainAccess: keychainAccess)

    // and given
    try await keychain.deleteShares()

    // then
    XCTAssertEqual(keychainAccess.deleteItemKeyParam, "\(MockConstants.mockClientId).shares")
  }

  func test_deleteShares_willThrowCorrectError_WhenClientNotFound() async throws {
    // given
    let keychainAccess = PortalKeyChainAccessSpy()
    initKeychainWith(keychainAccess: keychainAccess, api: nil)

    do {
      // and given
      try await keychain.deleteShares()
      XCTFail("Expected error not thrown when calling PortalKeychain.deleteShares when client is not found.")
    } catch {
      // then
      XCTAssertEqual(error as? PortalKeychain.KeychainError, PortalKeychain.KeychainError.clientNotFound)
    }
  }
}

// MARK: - getAddress & getAddresses tests

extension PortalKeychainTests {
  func testGetAddress() async throws {
    let expectation = XCTestExpectation(description: "PortalKeychain.getAddress(forChainId)")
    let eip155Address = try await keychain.getAddress("eip155:11155111")
    let solanaAddress = try await keychain.getAddress("solana:4uhcVJyU9pJkvQyS88uRDiswHXSCkY3z")
    XCTAssert(eip155Address == MockConstants.mockEip155Address)
    XCTAssert(solanaAddress == MockConstants.mockSolanaAddress)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func test_getAddress_willThrowCorrectError_WhenPassingWrongChainId() async throws {
    // give
    let chainId = "123:321"
    do {
      // and given
      _ = try await keychain.getAddress(chainId)
      XCTFail("Expected error not thrown when calling PortalKeychain.getAddress when passing wrong chainId.")
    } catch {
      // then
      XCTAssertEqual(error as? PortalKeychain.KeychainError, PortalKeychain.KeychainError.unsupportedNamespace(chainId))
    }
  }

  func test_getAddress_willTryToDecodeOldLogic_WhenFailToEncodeKeychainData() async throws {
    // given
    let addressExpect = "123"
    let keyChainAccessMock = PortalKeyChainAccessMock()
    keyChainAccessMock.getItemReturnValue = addressExpect
    initKeychainWith(keychainAccess: keyChainAccessMock)

    // and given
    let address = try await keychain.getAddress("eip155:11155111")

    // then
    XCTAssertEqual(address, addressExpect)
  }

  func test_getAddress_willCall_keychainGetItem() async throws {
    // given
    let keyChainAccessSpy = PortalKeyChainAccessSpy()
    initKeychainWith(keychainAccess: keyChainAccessSpy)

    // and given
    _ = try await keychain.getAddress("eip155:11155111")

    // then
    XCTAssertTrue(keyChainAccessSpy.getItemCallsCount >= 1)
  }

  func testGetAddresses() async throws {
    let expectation = XCTestExpectation(description: "PortalKeychain.getAddresses()")
    let addresses = try await keychain.getAddresses()
    XCTAssert(addresses[.eip155] == MockConstants.mockEip155Address)
    XCTAssert(addresses[.solana] == MockConstants.mockSolanaAddress)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func test_getAddresses_willCall_keychainGetItem() async throws {
    // given
    let keyChainAccessSpy = PortalKeyChainAccessSpy()
    initKeychainWith(keychainAccess: keyChainAccessSpy)

    let metadataData = try encoder.encode(MockConstants.mockKeychainClientMetadata)
    keyChainAccessSpy.getItemReturnValue = String(data: metadataData, encoding: .utf8) ?? ""

    // and given
    _ = try await keychain.getAddresses()

    // then
    XCTAssertTrue(keyChainAccessSpy.getItemCallsCount >= 1)
  }

  func test_getAddresses_willThrowCorrectError_WhenThereIsNoMetadata() async throws {
    // given
    let keyChainAccessSpy = PortalKeyChainAccessSpy()
    initKeychainWith(keychainAccess: keyChainAccessSpy)

    do {
      // and given
      _ = try await keychain.getAddresses()
      XCTFail("Expected error not thrown when calling PortalKeychain.getAddresses when there is metadata.")
    } catch {
      // then
      XCTAssertEqual(error as? PortalKeychain.KeychainError, PortalKeychain.KeychainError.unableToDecodeMetadata)
    }
    // then
    XCTAssertTrue(keyChainAccessSpy.getItemCallsCount >= 1)
  }
}

// MARK: - getMetadata tests

extension PortalKeychainTests {
  func testGetMetadata() async throws {
    let expectation = XCTestExpectation(description: "PortalKeychain.getMetadata()")
    let metadata = try await keychain.getMetadata()
    XCTAssert(metadata.id == MockConstants.mockKeychainClientMetadata.id)
    XCTAssert(metadata.addresses == MockConstants.mockKeychainClientMetadata.addresses)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func test_getMetadata_willCall_keychainGetItem_onlyOnce() async throws {
    // given
    let keyChainAccessSpy = PortalKeyChainAccessSpy()
    initKeychainWith(keychainAccess: keyChainAccessSpy)

    let metadataData = try encoder.encode(MockConstants.mockKeychainClientMetadata)
    keyChainAccessSpy.getItemReturnValue = String(data: metadataData, encoding: .utf8) ?? ""

    // and given
    _ = try await keychain.getMetadata()

    // then
    XCTAssertEqual(keyChainAccessSpy.getItemCallsCount, 1)
  }

  func test_getMetaData_willThrowCorrectError_whenClientNotFound() async throws {
    // given
    keychain.api = nil

    do {
      // and given
      _ = try await keychain.getMetadata()
      XCTFail("Expected error not thrown when calling PortalKeychain.getMetadata when client is not found.")
    } catch {
      // then
      XCTAssertEqual(error as? PortalKeychain.KeychainError, PortalKeychain.KeychainError.clientNotFound)
    }
  }
}

// MARK: - getShare & getShares tests

extension PortalKeychainTests {
  // TODO: - add more getShare & getShares tests to cover the backward compatibility paths
  func testGetShare() async throws {
    let expectation = XCTestExpectation(description: "PortalKeychain.getShare(forChainId)")
    let mockMpcShareString = try MockConstants.mockMpcShareString
    let shareResult = try await keychain.getShare("eip155:11155111")

    guard let shareData = shareResult.data(using: .utf8),
          let mockShareData = mockMpcShareString.data(using: .utf8),
          let share = try? JSONDecoder().decode(MpcShare.self, from: shareData),
          let mockShare = try? JSONDecoder().decode(MpcShare.self, from: mockShareData)
    else {
      throw PortalKeychain.KeychainError.unableToEncodeKeychainData
    }

    XCTAssertEqual(share, mockShare)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testGetShares() async throws {
    let expectation = XCTestExpectation(description: "PortalKeychain.getShares()")
    let mockGeneratedShare = try MockConstants.mockGeneratedShare
    let shares = try await keychain.getShares()
    guard let secp256k1Share = shares["SECP256K1"] else {
      throw PortalKeychain.KeychainError.itemNotFound(item: "share")
    }
    guard let shareData = secp256k1Share.share.data(using: .utf8),
          let mockShareData = mockGeneratedShare.share.data(using: .utf8),
          let share = try? JSONDecoder().decode(MpcShare.self, from: shareData),
          let mockShare = try? JSONDecoder().decode(MpcShare.self, from: mockShareData)
    else {
      throw PortalKeychain.KeychainError.unableToEncodeKeychainData
    }
    XCTAssert(shares.count > 0)
    XCTAssertEqual(secp256k1Share.id, mockGeneratedShare.id)
    XCTAssertEqual(share, mockShare)
    expectation.fulfill()

    await fulfillment(of: [expectation], timeout: 5.0)
  }
}

// MARK: - setMetadata tests

extension PortalKeychainTests {
  func test_setMetadata_willThrowCorrectError_whenClientNotFound() async throws {
    do {
      // given
      keychain.api = nil
      // and given
      _ = try await keychain.setMetadata(MockConstants.mockKeychainClientMetadata)
      XCTFail("Expected error not thrown when calling PortalKeychain.setMetadata when client is not found.")
    } catch {
      // then
      XCTAssertEqual(error as? PortalKeychain.KeychainError, PortalKeychain.KeychainError.clientNotFound)
    }
  }

  func test_setMetadata_willCall_keychainUpdateItem_onlyOnce() async throws {
    // given
    let keyChainAccessSpy = PortalKeyChainAccessSpy()
    initKeychainWith(keychainAccess: keyChainAccessSpy)
    Thread.sleep(forTimeInterval: 0.1)
    keyChainAccessSpy.updateItemCallsCount = 0

    // and given
    _ = try await keychain.setMetadata(MockConstants.mockKeychainClientMetadata)

    // then
    XCTAssertEqual(keyChainAccessSpy.updateItemCallsCount, 1)
  }

  func test_setMetadata_willCall_keychainUpdateItem_passingCorrectParams() async throws {
    // given
    let keyChainAccessSpy = PortalKeyChainAccessSpy()
    initKeychainWith(keychainAccess: keyChainAccessSpy)

    // and given
    _ = try await keychain.setMetadata(MockConstants.mockKeychainClientMetadata)

    // key param
    let clientId = try await keychain.api?.client?.id ?? ""
    let metadataKey = "metadata"
    let key = "\(clientId).\(metadataKey)"

    // value param
    let data = (keyChainAccessSpy.updateItemValueParam ?? "").data(using: .utf8)
    let valueDecoded = try decoder.decode(PortalKeychainClientMetadata.self, from: data ?? Data())

    // then
    XCTAssertEqual(keyChainAccessSpy.updateItemKeyParam, key)
    XCTAssertEqual(MockConstants.mockKeychainClientMetadata.id, valueDecoded.id)
  }
}

// MARK: - setShares tests

extension PortalKeychainTests {
  func test_setShares_willThrowCorrectError_whenClientNotFound() async throws {
    // given
    keychain.api = nil

    do {
      // and given
      _ = try await keychain.setShares([:])
      XCTFail("Expected error not thrown when calling PortalKeychain.setMetadata when client is not found.")
    } catch {
      // then
      XCTAssertEqual(error as? PortalKeychain.KeychainError, PortalKeychain.KeychainError.clientNotFound)
    }
  }

  func test_setShares_willCall_keychainUpdateItem_atLeastOnce() async throws {
    // given
    let keyChainAccessSpy = PortalKeyChainAccessSpy()
    initKeychainWith(keychainAccess: keyChainAccessSpy)

    // and given
    _ = try await keychain.setShares([:])

    // then
    XCTAssertTrue(keyChainAccessSpy.updateItemCallsCount >= 1)
  }

  func test_setShares_willCall_keychainUpdateItem_passingCorrectParams() async throws {
    // given
    let keyChainAccessSpy = PortalKeyChainAccessSpy()
    initKeychainWith(keychainAccess: keyChainAccessSpy)

    // key param
    let clientId = try await keychain.api?.client?.id ?? ""

    // and given
    _ = try await keychain.setShares([:])

    // value param
    let data = (keyChainAccessSpy.updateItemValueParam ?? "").data(using: .utf8)
    let valueDecoded = try decoder.decode([String: PortalMpcGeneratedShare].self, from: data ?? Data())

    // then
    XCTAssertTrue(keyChainAccessSpy.updateItemKeyParam?.hasPrefix(clientId) ?? false)
    XCTAssertEqual([:], valueDecoded)
  }
}

// MARK: - Presignature Storage Tests

extension PortalKeychainTests {
  func test_getPresignatures_returnsEmptyArray_whenKeyNotFound() async throws {
    let access = InMemoryKeychainAccess()
    initKeychainWith(keychainAccess: access)

    let result = try await keychain.getPresignatures("SECP256K1")
    XCTAssertEqual(result.count, 0)
  }

  func test_insertPresignature_storesEntry_andGetReturnsIt() async throws {
    let access = InMemoryKeychainAccess()
    initKeychainWith(keychainAccess: access)

    let entry = PresignatureEntry(id: "test-id", expiresAt: "2099-01-01T00:00:00Z", data: "test-data")
    try await keychain.insertPresignature("SECP256K1", entry)

    let result = try await keychain.getPresignatures("SECP256K1")
    XCTAssertEqual(result, [entry])
  }

  func test_insertPresignature_throwsError_whenIdIsEmpty() async throws {
    let access = InMemoryKeychainAccess()
    initKeychainWith(keychainAccess: access)

    let entry = PresignatureEntry(id: "", expiresAt: "2099-01-01T00:00:00Z", data: "test-data")
    do {
      try await keychain.insertPresignature("SECP256K1", entry)
      XCTFail("Expected invalidPresignatureEntry error")
    } catch {
      guard case PortalKeychain.KeychainError.invalidPresignatureEntry(let reason) = error else {
        XCTFail("Unexpected error type: \(error)")
        return
      }
      XCTAssertTrue(reason.contains("id"))
    }
  }

  func test_insertPresignature_throwsError_whenDataIsEmpty() async throws {
    let access = InMemoryKeychainAccess()
    initKeychainWith(keychainAccess: access)

    let entry = PresignatureEntry(id: "test-id", expiresAt: "2099-01-01T00:00:00Z", data: "")
    do {
      try await keychain.insertPresignature("SECP256K1", entry)
      XCTFail("Expected invalidPresignatureEntry error")
    } catch {
      guard case PortalKeychain.KeychainError.invalidPresignatureEntry(let reason) = error else {
        XCTFail("Unexpected error type: \(error)")
        return
      }
      XCTAssertTrue(reason.contains("data"))
    }
  }

  func test_insertPresignature_throwsError_whenExpiresAtIsInvalidISO8601() async throws {
    let access = InMemoryKeychainAccess()
    initKeychainWith(keychainAccess: access)

    let entry = PresignatureEntry(id: "test-id", expiresAt: "not-a-date", data: "test-data")
    do {
      try await keychain.insertPresignature("SECP256K1", entry)
      XCTFail("Expected invalidPresignatureEntry error")
    } catch {
      guard case PortalKeychain.KeychainError.invalidPresignatureEntry(let reason) = error else {
        XCTFail("Unexpected error type: \(error)")
        return
      }
      XCTAssertTrue(reason.contains("ISO 8601"))
    }
  }

  func test_popOldestPresignature_returnsOldestEntry() async throws {
    let access = InMemoryKeychainAccess()
    initKeychainWith(keychainAccess: access)

    let entry1 = PresignatureEntry(id: "first", expiresAt: "2099-01-01T00:00:00Z", data: "data-1")
    let entry2 = PresignatureEntry(id: "second", expiresAt: "2099-01-01T00:00:00Z", data: "data-2")
    try await keychain.insertPresignature("SECP256K1", entry1)
    try await keychain.insertPresignature("SECP256K1", entry2)

    let popped = try await keychain.popOldestPresignature("SECP256K1")
    XCTAssertEqual(popped, entry1)

    let remaining = try await keychain.getPresignatures("SECP256K1")
    XCTAssertEqual(remaining, [entry2])
  }

  func test_popOldestPresignature_filtersExpiredEntries() async throws {
    let access = InMemoryKeychainAccess()
    initKeychainWith(keychainAccess: access)

    let expired = PresignatureEntry(id: "expired", expiresAt: "2020-01-01T00:00:00Z", data: "data-old")
    let valid = PresignatureEntry(id: "valid", expiresAt: "2099-01-01T00:00:00Z", data: "data-new")
    try await keychain.insertPresignature("SECP256K1", expired)
    try await keychain.insertPresignature("SECP256K1", valid)

    let popped = try await keychain.popOldestPresignature("SECP256K1")
    XCTAssertEqual(popped, valid)

    let remaining = try await keychain.getPresignatures("SECP256K1")
    XCTAssertEqual(remaining.count, 0)
  }

  func test_popOldestPresignature_returnsNil_whenEmpty() async throws {
    let access = InMemoryKeychainAccess()
    initKeychainWith(keychainAccess: access)

    let popped = try await keychain.popOldestPresignature("SECP256K1")
    XCTAssertNil(popped)
  }

  func test_deletePresignatures_removesStoredEntries() async throws {
    let access = InMemoryKeychainAccess()
    initKeychainWith(keychainAccess: access)

    let entry = PresignatureEntry(id: "test-id", expiresAt: "2099-01-01T00:00:00Z", data: "test-data")
    try await keychain.insertPresignature("SECP256K1", entry)

    try await keychain.deletePresignatures("SECP256K1")
    let result = try await keychain.getPresignatures("SECP256K1")
    XCTAssertEqual(result.count, 0)
  }

  func test_cleanupExpiredPresignatures_removesExpiredEntries() async throws {
    let access = InMemoryKeychainAccess()
    initKeychainWith(keychainAccess: access)

    let expired = PresignatureEntry(id: "expired", expiresAt: "2020-01-01T00:00:00Z", data: "data-old")
    let valid = PresignatureEntry(id: "valid", expiresAt: "2099-01-01T00:00:00Z", data: "data-new")
    try await keychain.insertPresignature("SECP256K1", expired)
    try await keychain.insertPresignature("SECP256K1", valid)

    let removed = try await keychain.cleanupExpiredPresignatures("SECP256K1")
    XCTAssertEqual(removed, 1)

    let remaining = try await keychain.getPresignatures("SECP256K1")
    XCTAssertEqual(remaining, [valid])
  }

  func test_cleanupExpiredPresignatures_returnsZero_whenNoneExpired() async throws {
    let access = InMemoryKeychainAccess()
    initKeychainWith(keychainAccess: access)

    let entry = PresignatureEntry(id: "valid", expiresAt: "2099-01-01T00:00:00Z", data: "data")
    try await keychain.insertPresignature("SECP256K1", entry)

    let removed = try await keychain.cleanupExpiredPresignatures("SECP256K1")
    XCTAssertEqual(removed, 0)
  }
}

/// In-memory keychain access for presignature tests.
/// Simulates real keychain behavior: throws itemNotFound when key doesn't exist.
private class InMemoryKeychainAccess: PortalKeychainAccessProtocol {
  private var store: [String: String] = [:]

  func addItem(_ key: String, value: String) throws {
    store[key] = value
  }

  func deleteItem(_ key: String) throws {
    store.removeValue(forKey: key)
  }

  func getItem(_ key: String) throws -> String {
    guard let value = store[key] else {
      throw PortalKeychainAccessError.itemNotFound(key)
    }
    return value
  }

  func updateItem(_ key: String, value: String) throws {
    if store[key] == nil {
      try addItem(key, value: value)
    } else {
      store[key] = value
    }
  }
}
