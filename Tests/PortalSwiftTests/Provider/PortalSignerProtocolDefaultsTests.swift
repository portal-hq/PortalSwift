//
//  PortalSignerProtocolDefaultsTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import Foundation
@testable import PortalSwift
import XCTest

/// `PortalSignerProtocol` has two `sign` overloads and an extension default for each, so a
/// conformer may implement either one alone. These cases pin both directions: a signer written
/// against the current contract (the `token:` overload only) compiles and is driven through
/// `token:`, and the legacy overload it did not implement fails loudly rather than silently.
final class PortalSignerProtocolDefaultsTests: XCTestCase {
  /// A signer written against the current contract. Pre-7.5 this declaration did not compile:
  /// the token-less overload had no default, so every custom signer had to implement a method
  /// the SDK never calls.
  private final class TokenOnlySigner: PortalSignerProtocol {
    func sign(
      _: String,
      withPayload _: PortalSignRequest,
      andRpcUrl _: String,
      usingBlockchain _: PortalBlockchain,
      signatureApprovalMemo _: String?,
      sponsorGas _: Bool?,
      reqId _: String?,
      token: String
    ) async throws -> String {
      "0xsigned-with-\(token)"
    }
  }

  /// A signer written against the earlier contract: the token-less overload only.
  private final class LegacySigner: PortalSignerProtocol {
    func sign(
      _: String,
      withPayload _: PortalSignRequest,
      andRpcUrl _: String,
      usingBlockchain _: PortalBlockchain,
      signatureApprovalMemo _: String?,
      sponsorGas _: Bool?,
      reqId _: String?
    ) async throws -> String {
      "0xsigned-legacy"
    }
  }

  private let request = PortalSignRequest(method: .eth_sendTransaction, params: "test-transaction")
  private let rpcUrl = "https://api.portalhq.io/rpc/v1/eip155/11155111"

  func test_tokenOnlySigner_isDrivenThroughTheTokenOverload() async throws {
    let signer = TokenOnlySigner()
    let blockchain = try PortalBlockchain(fromChainId: "eip155:11155111")

    let signature = try await signer.sign(
      "eip155:11155111",
      withPayload: self.request,
      andRpcUrl: self.rpcUrl,
      usingBlockchain: blockchain,
      signatureApprovalMemo: nil,
      sponsorGas: nil,
      reqId: nil,
      token: "session-token-1"
    )

    XCTAssertEqual(signature, "0xsigned-with-session-token-1")
  }

  func test_tokenOnlySigner_legacyOverloadThrowsUnsupported_insteadOfSilentlySucceeding() async throws {
    let signer = TokenOnlySigner()
    let blockchain = try PortalBlockchain(fromChainId: "eip155:11155111")

    await XCTAssertThrowsAsync(
      try await signer.sign(
        "eip155:11155111",
        withPayload: self.request,
        andRpcUrl: self.rpcUrl,
        usingBlockchain: blockchain,
        signatureApprovalMemo: nil,
        sponsorGas: nil,
        reqId: nil
      ),
      expected: PortalSignerError.tokenLessSignUnsupported
    )
  }

  func test_legacySigner_tokenOverloadForwardsToItsOwnImplementation() async throws {
    let signer = LegacySigner()
    let blockchain = try PortalBlockchain(fromChainId: "eip155:11155111")

    // The SDK only ever calls the `token:` overload; a conformer that predates it must still be
    // reached through the source-compatibility default, which ignores the token on purpose.
    let signature = try await signer.sign(
      "eip155:11155111",
      withPayload: self.request,
      andRpcUrl: self.rpcUrl,
      usingBlockchain: blockchain,
      signatureApprovalMemo: nil,
      sponsorGas: nil,
      reqId: nil,
      token: "ignored"
    )

    XCTAssertEqual(signature, "0xsigned-legacy")
  }
}
