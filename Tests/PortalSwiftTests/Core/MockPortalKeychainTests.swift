//
//  MockPortalKeychainTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

@testable import PortalSwift
import XCTest

/// `MockPortalKeychain` is public, so clients use it in their own tests. It must answer the same
/// Bitcoin chain IDs `PortalKeychain.getAddress(_:)` does.
final class MockPortalKeychainTests: XCTestCase {
  func test_getAddress_returnsTheMockBitcoinAddresses_forTheP2wpkhChainIds() async throws {
    // given
    let keychain = MockPortalKeychain()

    // then
    let mainnet = try await keychain.getAddress(PortalBlockchain.bitcoinP2wpkhMainnetChainId)
    XCTAssertEqual(mainnet, MockConstants.mockBitcoinP2wpkhMainnetAddress)
    let testnet = try await keychain.getAddress(PortalBlockchain.bitcoinP2wpkhTestnetChainId)
    XCTAssertEqual(testnet, MockConstants.mockBitcoinP2wpkhTestnetAddress)
  }

  func test_getAddress_returnsNil_forABitcoinChainIdWithoutAnAddressType() async throws {
    // given
    let keychain = MockPortalKeychain()

    // then
    let address = try await keychain.getAddress("bip122:000000000019d6689c085ae165831e93")
    XCTAssertNil(address)
  }

  func test_getAddresses_omitsBitcoin() async throws {
    // given
    let keychain = MockPortalKeychain()

    // then
    let addresses = try await keychain.getAddresses()
    XCTAssertFalse(addresses.keys.contains(.bip122))
  }
}
