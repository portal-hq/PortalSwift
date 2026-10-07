//
//  PortalSignerProtocolDefaultsTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import AnyCodable
import Foundation
@testable import PortalSwift
import XCTest

/// `PortalSignerProtocol` has two `sign` overloads and an extension default for each, so a
/// conformer may implement either one alone. These cases pin both directions: a signer written
/// against the current contract (the `token:` overload only) compiles and is driven through
/// `token:`, and the legacy overload it did not implement fails loudly rather than silently.
/// The third overload (`idempotencyKey:`, the one `PortalProvider` calls) is pinned the same way:
/// older conformers are reached through its default, which drops the key with a warning, and a
/// conformer that implements it receives the key.
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

  /// A signer written against the idempotency-key contract: the `idempotencyKey:` overload only.
  /// It records the key it received so a test can prove the SDK's call reaches it unchanged.
  private final class KeyAwareSigner: PortalSignerProtocol {
    private(set) var receivedKeys: [String?] = []

    func sign(
      _: String,
      withPayload _: PortalSignRequest,
      andRpcUrl _: String,
      usingBlockchain _: PortalBlockchain,
      signatureApprovalMemo _: String?,
      sponsorGas _: Bool?,
      reqId _: String?,
      idempotencyKey: String?,
      token: String
    ) async throws -> String {
      self.receivedKeys.append(idempotencyKey)
      return "0xsigned-with-key-and-\(token)"
    }
  }

  private let request = PortalSignRequest(method: .eth_sendTransaction, params: "test-transaction")
  private let rpcUrl = "https://api.portalhq.io/rpc/v1/eip155/11155111"
  private let idempotencyKey = "idem-key-secret-1"
  private var logger = RecordingLogger()

  override func setUpWithError() throws {
    try super.setUpWithError()
    self.logger = RecordingLogger()
    self.logger.install()
  }

  override func tearDownWithError() throws {
    self.logger.uninstall()
    try super.tearDownWithError()
  }

  /// Drives `signer` through the `idempotencyKey:` overload, the one `PortalProvider` calls.
  private func signWithKey(_ signer: PortalSignerProtocol, idempotencyKey: String?, token: String = "session-token-1") async throws -> String {
    let blockchain = try PortalBlockchain(fromChainId: "eip155:11155111")
    return try await signer.sign(
      "eip155:11155111",
      withPayload: self.request,
      andRpcUrl: self.rpcUrl,
      usingBlockchain: blockchain,
      signatureApprovalMemo: nil,
      sponsorGas: nil,
      reqId: nil,
      idempotencyKey: idempotencyKey,
      token: token
    )
  }

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

  // MARK: - idempotencyKey: overload

  func test_tokenOnlySigner_idempotencyKeyOverload_forwardsToTokenOverload() async throws {
    let signature = try await self.signWithKey(TokenOnlySigner(), idempotencyKey: self.idempotencyKey)

    XCTAssertEqual(signature, "0xsigned-with-session-token-1")
  }

  func test_tokenOnlySigner_idempotencyKeyOverload_warnsThatTheKeyWasDropped_withoutLoggingIt() async throws {
    _ = try await self.signWithKey(TokenOnlySigner(), idempotencyKey: self.idempotencyKey)

    // Filtered to this feature's line: the log sink is process-global, so an unrelated warning
    // from a task another test started must not fail this one.
    let dropWarnings = self.logger.messages(at: .warn).filter { $0.contains("does not accept idempotencyKey") }
    XCTAssertEqual(dropWarnings.count, 1, "Unexpected warnings: \(self.logger.messages(at: .warn))")
    self.logger.assertNoSecret(self.idempotencyKey)
    self.logger.assertNoSecret("session-token-1")
  }

  func test_tokenOnlySigner_idempotencyKeyOverload_doesNotWarn_withoutAKey() async throws {
    let signature = try await self.signWithKey(TokenOnlySigner(), idempotencyKey: nil)

    XCTAssertEqual(signature, "0xsigned-with-session-token-1")
    XCTAssertFalse(self.logger.messages(at: .warn).contains { $0.contains("idempotencyKey") })
  }

  func test_legacySigner_idempotencyKeyOverload_forwardsThroughTheTokenOverload() async throws {
    // new overload -> `token:` default -> the token-less method the legacy signer implemented.
    let signature = try await self.signWithKey(LegacySigner(), idempotencyKey: self.idempotencyKey)

    XCTAssertEqual(signature, "0xsigned-legacy")
    XCTAssertEqual(self.logger.messages(at: .warn).filter { $0.contains("does not accept idempotencyKey") }.count, 1)
    self.logger.assertNoSecret(self.idempotencyKey)
  }

  func test_keyAwareSigner_receivesTheKey_throughTheOverloadTheSdkCalls() async throws {
    let signer = KeyAwareSigner()

    let signature = try await self.signWithKey(signer, idempotencyKey: self.idempotencyKey)

    XCTAssertEqual(signature, "0xsigned-with-key-and-session-token-1")
    XCTAssertEqual(signer.receivedKeys, [self.idempotencyKey])
    XCTAssertFalse(
      self.logger.messages(at: .warn).contains { $0.contains("idempotencyKey") },
      "A signer that accepts the key must not be warned about."
    )
  }

  func test_keyAwareSigner_isWhatThePortalProviderCalls() async throws {
    let signer = KeyAwareSigner()
    let provider = try PortalProvider(
      credentials: MockCredentials(tokenValue: "session-token-1"),
      rpcConfig: ["eip155:11155111": self.rpcUrl],
      keychain: MockPortalKeychain(),
      autoApprove: true,
      requests: PortalRequestsSpy(),
      signer: signer
    )

    let result = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_sendTransaction,
      params: [AnyCodable(["from": MockConstants.mockEip155Address, "to": MockConstants.mockEip155Address])],
      connect: nil,
      options: RequestOptions(idempotencyKey: " \(self.idempotencyKey) ")
    )

    XCTAssertEqual(result.result as? String, "0xsigned-with-key-and-session-token-1")
    XCTAssertEqual(signer.receivedKeys, [self.idempotencyKey])
  }

  func test_tokenOnlySigner_throughPortalProvider_withKey_signs_andWarnsOnce() async throws {
    // A host upgrading with a custom signer written against the `token:` contract keeps signing;
    // the key it cannot forward is reported once, without being logged.
    let provider = try PortalProvider(
      credentials: MockCredentials(tokenValue: "session-token-1"),
      rpcConfig: ["eip155:11155111": self.rpcUrl],
      keychain: MockPortalKeychain(),
      autoApprove: true,
      requests: PortalRequestsSpy(),
      signer: TokenOnlySigner()
    )

    let result = try await provider.request(
      chainId: "eip155:11155111",
      method: .eth_sendTransaction,
      params: [AnyCodable(["from": MockConstants.mockEip155Address, "to": MockConstants.mockEip155Address])],
      connect: nil,
      options: RequestOptions(idempotencyKey: self.idempotencyKey)
    )

    XCTAssertEqual(result.result as? String, "0xsigned-with-session-token-1")
    XCTAssertEqual(self.logger.messages(at: .warn).filter { $0.contains("does not accept idempotencyKey") }.count, 1)
    self.logger.assertNoSecret(self.idempotencyKey)
  }

  func test_keyAwareSigner_tokenOverload_fallsThroughToTheTokenLessDefault() async throws {
    // The chain is acyclic: a signer that implements only the newest overload was never asked to
    // implement the older ones, and the SDK never calls them, so they fail loudly.
    let blockchain = try PortalBlockchain(fromChainId: "eip155:11155111")

    await XCTAssertThrowsAsync(
      try await KeyAwareSigner().sign(
        "eip155:11155111",
        withPayload: self.request,
        andRpcUrl: self.rpcUrl,
        usingBlockchain: blockchain,
        signatureApprovalMemo: nil,
        sponsorGas: nil,
        reqId: nil,
        token: "session-token-1"
      ),
      expected: PortalSignerError.tokenLessSignUnsupported
    )
  }
}
