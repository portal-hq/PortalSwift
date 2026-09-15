//
//  PortalBlockchainTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

@testable import PortalSwift
import XCTest

final class PortalBlockchainTests: XCTestCase {
  /// XRPL is address-only: the namespace resolves to the wallet that backs the address, but no
  /// method is signable, so no XRPL request reaches the MPC signer. Signer support is phase two;
  /// this test is the thing to flip when that lands.
  func test_xrpl_resolvesSecp256k1_andHasNoSignerMethods() throws {
    // given
    let blockchain = try PortalBlockchain(fromChainId: "xrpl:0")

    // then
    XCTAssertEqual(blockchain.namespace, .xrpl)
    XCTAssertEqual(blockchain.curve, .SECP256K1)
    XCTAssertFalse(blockchain.shouldMethodBeSigned(.rawSign))
    XCTAssertFalse(blockchain.shouldMethodBeSigned(.eth_sendTransaction))
    XCTAssertFalse(blockchain.shouldMethodBeSigned(.sol_signTransaction))
  }

  func test_xrpl_testnetChainId_resolves() throws {
    // given
    let blockchain = try PortalBlockchain(fromChainId: "xrpl:1")

    // then
    XCTAssertEqual(blockchain.namespace, .xrpl)
    XCTAssertFalse(blockchain.isMainnet)
  }
}
