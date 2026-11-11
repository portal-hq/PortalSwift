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
    XCTAssertTrue(blockchain.isMainnet, "xrpl:0 is the XRPL mainnet chain id")
    XCTAssertFalse(blockchain.shouldMethodBeSigned(.rawSign))
    XCTAssertFalse(blockchain.shouldMethodBeSigned(.eth_sendTransaction))
    XCTAssertFalse(blockchain.shouldMethodBeSigned(.sol_signTransaction))
  }

  func test_xrpl_testnetChainId_resolves_andIsNotMainnet() throws {
    // given
    let blockchain = try PortalBlockchain(fromChainId: "xrpl:1")

    // then
    XCTAssertEqual(blockchain.namespace, .xrpl)
    XCTAssertEqual(blockchain.curve, .SECP256K1)
    XCTAssertFalse(blockchain.isMainnet)
  }

  /// Stellar and Tron are address-only, like XRPL: the namespace resolves to the wallet that backs
  /// the address, but no method is signable. Flip these when signer support lands.
  func test_stellar_resolvesEd25519_andHasNoSignerMethods() throws {
    // given
    let mainnet = try PortalBlockchain(fromChainId: "stellar:pubnet")
    let testnet = try PortalBlockchain(fromChainId: "stellar:testnet")

    // then
    XCTAssertEqual(mainnet.namespace, .stellar)
    XCTAssertEqual(mainnet.curve, .ED25519)
    XCTAssertTrue(mainnet.isMainnet, "stellar:pubnet is the Stellar mainnet chain id")
    XCTAssertFalse(testnet.isMainnet)
    XCTAssertFalse(mainnet.shouldMethodBeSigned(.rawSign))
    XCTAssertFalse(mainnet.shouldMethodBeSigned(.sol_signTransaction))
  }

  func test_tron_resolvesSecp256k1_andHasNoSignerMethods() throws {
    // given
    let mainnet = try PortalBlockchain(fromChainId: "tron:mainnet")
    let nile = try PortalBlockchain(fromChainId: "tron:nile")

    // then
    XCTAssertEqual(mainnet.namespace, .tron)
    XCTAssertEqual(mainnet.curve, .SECP256K1)
    XCTAssertTrue(mainnet.isMainnet, "tron:mainnet is the Tron mainnet chain id")
    XCTAssertFalse(nile.isMainnet)
    XCTAssertFalse(mainnet.shouldMethodBeSigned(.rawSign))
    XCTAssertFalse(mainnet.shouldMethodBeSigned(.eth_sendTransaction))
  }

  /// An address-only namespace has no signer, so a signing method must be rejected up front rather
  /// than sent to whatever RPC URL the app configured for the chain.
  func test_addressOnlyNamespaces_rejectSignerMethods_andAllowOtherMethods() throws {
    for chainId in ["stellar:pubnet", "tron:mainnet", "xrpl:0"] {
      // given
      let blockchain = try PortalBlockchain(fromChainId: chainId)

      // then
      for method in PortalBlockchain.allSignerMethods {
        XCTAssertFalse(blockchain.isMethodSupported(method), "\(method.rawValue) should be unsupported on \(chainId)")
      }
      XCTAssertTrue(blockchain.isMethodSupported(.eth_blockNumber), "non-signing methods still reach RPC on \(chainId)")
    }
  }

  /// The guard only applies to namespaces with no signer. Solana and Bitcoin keep their behavior.
  func test_namespacesWithSigners_stillSupportEveryMethod() throws {
    // given
    let solana = try PortalBlockchain(fromChainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp")
    let bitcoin = try PortalBlockchain(fromChainId: PortalBlockchain.bitcoinP2wpkhMainnetChainId)

    // then
    XCTAssertTrue(solana.isMethodSupported(.sol_signTransaction))
    XCTAssertTrue(solana.isMethodSupported(.rawSign))
    XCTAssertTrue(bitcoin.isMethodSupported(.rawSign))
  }
}
