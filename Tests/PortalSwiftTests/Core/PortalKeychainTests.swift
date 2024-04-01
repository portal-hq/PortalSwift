//
//  PortalKeychainTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import PortalSwift
import XCTest

final class PortalKeychainTests: XCTestCase {
  var keychain: PortalKeychain = .init(keychainAccess: MockPortalKeychainAccess())

  override func setUpWithError() throws {
    self.keychain.api = PortalApi(
      apiKey: MockConstants.mockApiKey,
      apiHost: MockConstants.mockHost,
      requests: MockPortalRequests()
    )
  }

  override func tearDownWithError() throws {}

  func testGetAddress() async throws {
    let expectation = XCTestExpectation(description: "PortalKeychain.getAddress(forChainId)")
    let eip155Address = try await keychain.getAddress("eip155:11155111")
    let solanaAddress = try await keychain.getAddress("solana:4uhcVJyU9pJkvQyS88uRDiswHXSCkY3z")
    XCTAssert(eip155Address == MockConstants.mockEip155Address)
    XCTAssert(solanaAddress == MockConstants.mockSolanaAddress)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testGetAddresses() async throws {
    let expectation = XCTestExpectation(description: "PortalKeychain.getAddresses()")
    let addresses = try await keychain.getAddresses()
    XCTAssert(addresses[.eip155] == MockConstants.mockEip155Address)
    XCTAssert(addresses[.solana] == MockConstants.mockSolanaAddress)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testGetMetadata() async throws {
    let expectation = XCTestExpectation(description: "PortalKeychain.getMetadata()")
    let metadata = try await keychain.getMetadata()
    XCTAssert(metadata.id == MockConstants.mockKeychainClientMetadata.id)
    XCTAssert(metadata.addresses == MockConstants.mockKeychainClientMetadata.addresses)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

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
