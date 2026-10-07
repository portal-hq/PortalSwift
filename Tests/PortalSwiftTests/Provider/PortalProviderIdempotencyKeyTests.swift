//
//  PortalProviderIdempotencyKeyTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab Issa.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import AnyCodable
@testable import PortalSwift
import XCTest

/// Covers how `PortalProvider.request()` resolves `RequestOptions.idempotencyKey` before anything
/// is approved, signed or sent.
///
/// The rules, in order: a key on a raw broadcast (`eth_sendRawTransaction`, `sol_sendTransaction`)
/// throws `unsupportedTarget` before any RPC request, whatever its shape; a malformed key throws
/// `invalidKey` before the approval prompt, the token resolve and the signer; a key on any method
/// other than `eth_sendTransaction`, `sol_signAndSendTransaction` and
/// `sol_signAndConfirmTransaction` is dropped with a warning, and so is a key on one of those that
/// the chain does not sign; otherwise the key reaches the signer trimmed. The key itself is never
/// logged. Signing request params are encoded with sorted keys so an identical retry carries
/// byte-identical params, which is what Portal compares.
final class PortalProviderIdempotencyKeyTests: XCTestCase {
  // MARK: - Fixtures

  private static let evmChainId = "eip155:11155111"
  private static let solanaChainId = "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1"
  private static let bitcoinChainId = "bip122:000000000933ea01ad0ee984209779ba-p2wpkh"
  private static let sessionToken = "session-token-idem"
  /// The trimmed key every keyed case expects to reach the signer. Distinctive so a "never
  /// logged" assertion cannot pass against some other constant.
  private static let key = "order-key-1"
  private static let paddedKey = "  order-key-1 "

  private var credentials = MockCredentials(tokenValue: PortalProviderIdempotencyKeyTests.sessionToken)
  private var requestsSpy = PortalRequestsSpy()
  private var signerSpy = SignerSpy()
  private var logger = RecordingLogger()

  override func setUpWithError() throws {
    try super.setUpWithError()
    self.credentials = MockCredentials(tokenValue: Self.sessionToken)
    self.requestsSpy = PortalRequestsSpy()
    self.requestsSpy.returnData = try JSONEncoder().encode(MockConstants.mockRpcResponse)
    self.signerSpy = SignerSpy()
    self.logger = RecordingLogger()
    self.logger.install()
  }

  override func tearDownWithError() throws {
    self.logger.uninstall()
    try super.tearDownWithError()
  }

  // MARK: - Helpers

  /// Counts listener invocations from whatever thread the provider emits on.
  private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0

    var value: Int {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self._value
    }

    func increment() {
      self.lock.lock()
      defer { self.lock.unlock() }
      self._value += 1
    }
  }

  private func makeProvider(autoApprove: Bool = true) throws -> PortalProvider {
    try PortalProvider(
      credentials: self.credentials,
      rpcConfig: [
        Self.evmChainId: "https://api.portalhq.io/rpc/v1/eip155/11155111",
        Self.solanaChainId: "https://api.portalhq.io/rpc/v1/solana/EtWTRABZaYq6iMfeYKouRu166VU2xqa1"
      ],
      keychain: MockPortalKeychain(),
      autoApprove: autoApprove,
      requests: self.requestsSpy,
      signer: self.signerSpy
    )
  }

  @discardableResult
  private func request(
    _ provider: PortalProvider,
    chainId: String = PortalProviderIdempotencyKeyTests.evmChainId,
    method: PortalRequestMethod,
    params: [AnyCodable],
    idempotencyKey: String?
  ) async throws -> PortalProviderResult {
    try await provider.request(
      chainId: chainId,
      method: method,
      params: params,
      connect: nil,
      options: RequestOptions(signatureApprovalMemo: "memo", traceId: "trace-1", idempotencyKey: idempotencyKey)
    )
  }

  private var transactionParams: [AnyCodable] {
    [AnyCodable([
      "from": MockConstants.mockEip155Address,
      "to": MockConstants.mockEip155Address,
      "value": "0x1"
    ])]
  }

  private var solanaTransactionParams: [AnyCodable] {
    [AnyCodable("AQABAgMEBQYHCAkKCwwNDg8QERITFBUWFxgZGhscHR4fIA==")]
  }

  /// Runs `operation`, failing the test if it does not throw, and returns the error it threw.
  private func captureError<T>(
    file: StaticString = #filePath,
    line: UInt = #line,
    _ operation: () async throws -> T
  ) async -> Error? {
    do {
      _ = try await operation()
      XCTFail("Expected the call to throw, but it returned a value.", file: file, line: line)
      return nil
    } catch {
      return error
    }
  }

  private func assertInvalidKey(_ error: Error?, file: StaticString = #filePath, line: UInt = #line) {
    guard case .invalidKey = error as? PortalIdempotencyError else {
      XCTFail("Expected PortalIdempotencyError.invalidKey, got \(String(describing: error))", file: file, line: line)
      return
    }
  }

  /// Fails unless the provider sent at least one request and none of them carries the key, in its
  /// JSON body, its headers or its URL: a relayed RPC call has nowhere to enforce the key, so it
  /// must not leak it either.
  private func assertNoRequestCarriesTheKey(_ label: String = "", file: StaticString = #filePath, line: UInt = #line) throws {
    let requests = self.requestsSpy.executeRequestHistory
    XCTAssertFalse(requests.isEmpty, "\(label): no request was sent", file: file, line: line)
    for request in requests {
      XCTAssertFalse(request.url.absoluteString.contains(Self.key), "\(label): \(request.url)", file: file, line: line)
      XCTAssertFalse(
        request.headers.contains { $0.key.contains(Self.key) || $0.value.contains(Self.key) },
        "\(label): the key reached a header",
        file: file,
        line: line
      )
      if let payload = request.payload {
        let encodable: any Encodable = payload
        let body = try String(decoding: JSONEncoder().encode(encodable), as: UTF8.self)
        XCTAssertFalse(body.contains(Self.key), "\(label): \(body)", file: file, line: line)
      }
    }
  }

  // MARK: - Protected broadcast methods

  func test_ethSendTransaction_willPassTheTrimmedKeyToTheSigner() async throws {
    let provider = try makeProvider()

    try await self.request(provider, method: .eth_sendTransaction, params: self.transactionParams, idempotencyKey: Self.paddedKey)

    XCTAssertEqual(self.signerSpy.signIdempotencyKeyParams, [Self.key])
    XCTAssertEqual(self.signerSpy.idempotencyKeyOverloadCallsCount, 1)
    XCTAssertEqual(self.signerSpy.legacySignCallsCount, 0)
    XCTAssertEqual(self.signerSpy.lastSignCall?.token, Self.sessionToken)
    XCTAssertEqual(self.signerSpy.lastSignCall?.reqId, "trace-1", "The key must not displace the trace id.")
    XCTAssertEqual(self.signerSpy.lastSignCall?.signatureApprovalMemo, "memo")
  }

  func test_solSignAndSendTransaction_willPassTheTrimmedKeyToTheSigner() async throws {
    let provider = try makeProvider()

    try await self.request(provider, chainId: Self.solanaChainId, method: .sol_signAndSendTransaction, params: self.solanaTransactionParams, idempotencyKey: Self.paddedKey)

    XCTAssertEqual(self.signerSpy.signIdempotencyKeyParams, [Self.key])
    XCTAssertEqual(self.signerSpy.lastSignCall?.payload.method, .sol_signAndSendTransaction)
  }

  func test_solSignAndConfirmTransaction_willPassTheTrimmedKeyToTheSigner() async throws {
    let provider = try makeProvider()

    try await self.request(provider, chainId: Self.solanaChainId, method: .sol_signAndConfirmTransaction, params: self.solanaTransactionParams, idempotencyKey: Self.paddedKey)

    XCTAssertEqual(self.signerSpy.signIdempotencyKeyParams, [Self.key])
    XCTAssertEqual(self.signerSpy.lastSignCall?.payload.method, .sol_signAndConfirmTransaction)
  }

  func test_protectedMethod_withKey_willNotWarn_orLogTheKey() async throws {
    let provider = try makeProvider()

    try await self.request(provider, method: .eth_sendTransaction, params: self.transactionParams, idempotencyKey: Self.paddedKey)

    XCTAssertFalse(self.logger.contains("idempotencyKey ignored"))
    self.logger.assertNoSecret(Self.key)
  }

  func test_withoutKey_willPassNil_andNotWarn() async throws {
    let provider = try makeProvider()

    try await self.request(provider, method: .eth_sendTransaction, params: self.transactionParams, idempotencyKey: nil)

    XCTAssertEqual(self.signerSpy.signIdempotencyKeyParams, [nil])
    XCTAssertEqual(self.signerSpy.idempotencyKeyOverloadCallsCount, 1)
    // Filtered to this feature's lines: the log sink is process-global, so an unrelated warning
    // from a task another test started must not fail this one.
    XCTAssertFalse(self.logger.contains("idempotencyKey"), "Unexpected warnings: \(self.logger.messages(at: .warn))")
  }

  func test_withoutOptions_willPassNil() async throws {
    let provider = try makeProvider()

    _ = try await provider.request(chainId: Self.evmChainId, method: .eth_sendTransaction, params: self.transactionParams, connect: nil, options: nil)

    XCTAssertEqual(self.signerSpy.signIdempotencyKeyParams, [nil])
  }

  func test_protectedMethod_keyWrappedInJavaScriptWhitespace_reachesTheSignerTrimmed() async throws {
    // Portal trims with JavaScript's trim(), which removes U+00A0 and U+FEFF.
    let provider = try makeProvider()

    try await self.request(provider, method: .eth_sendTransaction, params: self.transactionParams, idempotencyKey: "\u{00A0}\(Self.key)\u{FEFF}")

    XCTAssertEqual(self.signerSpy.signIdempotencyKeyParams, [Self.key])
  }

  func test_protectedMethod_keyWrappedInAZeroWidthSpace_willThrowInvalidKey() async throws {
    // U+200B is not whitespace to JavaScript's trim(), so it stays in the key and fails the
    // character check, although Foundation would have trimmed it.
    let provider = try makeProvider()

    let error = await self.captureError {
      try await self.request(provider, method: .eth_sendTransaction, params: self.transactionParams, idempotencyKey: "\u{200B}\(Self.key)\u{200B}")
    }

    self.assertInvalidKey(error)
    XCTAssertTrue(self.signerSpy.signCalls.isEmpty)
  }

  func test_protectedMethod_withKey_afterManualApproval_willPassTheKey() async throws {
    let provider = try makeProvider(autoApprove: false)
    _ = provider.on(event: Events.PortalSigningRequested.rawValue) { [weak provider] data in
      _ = provider?.emit(event: Events.PortalSigningApproved.rawValue, data: data)
    }

    try await self.request(provider, method: .eth_sendTransaction, params: self.transactionParams, idempotencyKey: Self.paddedKey)

    XCTAssertEqual(self.signerSpy.signIdempotencyKeyParams, [Self.key])
  }

  // MARK: - Other methods: warn and drop

  func test_nonBroadcastSigningMethods_withKey_willPassNil_andWarnNamingTheMethod() async throws {
    let cases: [(chainId: String, method: PortalRequestMethod, params: [AnyCodable])] = [
      (Self.evmChainId, .personal_sign, [AnyCodable("0x74657374"), AnyCodable(MockConstants.mockEip155Address)]),
      (Self.evmChainId, .eth_sign, [AnyCodable(MockConstants.mockEip155Address), AnyCodable("0x74657374")]),
      (Self.evmChainId, .eth_signTypedData_v3, [AnyCodable(MockConstants.mockEip155Address), AnyCodable("{\"types\":{}}")]),
      (Self.evmChainId, .eth_signTypedData_v4, [AnyCodable(MockConstants.mockEip155Address), AnyCodable("{\"types\":{}}")]),
      (Self.evmChainId, .eth_signTransaction, self.transactionParams),
      (Self.evmChainId, .eth_signUserOperation, [AnyCodable(["sender": MockConstants.mockEip155Address, "nonce": "0x0", "callData": "0x"])]),
      (Self.solanaChainId, .sol_signMessage, [AnyCodable("74657374")]),
      (Self.solanaChainId, .sol_signTransaction, self.solanaTransactionParams),
      (Self.evmChainId, .rawSign, [AnyCodable("74657374")])
    ]

    for testCase in cases {
      self.signerSpy.reset()
      self.logger.reset()
      let provider = try makeProvider()

      try await self.request(provider, chainId: testCase.chainId, method: testCase.method, params: testCase.params, idempotencyKey: Self.paddedKey)

      let name = testCase.method.rawValue
      XCTAssertEqual(self.signerSpy.signCalls.count, 1, name)
      XCTAssertEqual(self.signerSpy.signIdempotencyKeyParams, [nil], "\(name) must not receive the key.")
      let warnings = self.logger.messages(at: .warn)
      XCTAssertTrue(
        warnings.contains { $0.contains("idempotencyKey ignored for \(name);") && $0.contains("eth_sendTransaction, sol_signAndSendTransaction and sol_signAndConfirmTransaction") },
        "Expected a warning naming \(name): \(warnings)"
      )
      self.logger.assertNoSecret(Self.key)
    }
  }

  func test_unprotectedMethod_warning_hasTheSharedWording() async throws {
    let provider = try makeProvider()

    try await self.request(provider, method: .personal_sign, params: [AnyCodable("0x74657374"), AnyCodable(MockConstants.mockEip155Address)], idempotencyKey: Self.paddedKey)

    XCTAssertTrue(
      self.logger.messages(at: .warn).contains(
        "PortalProvider.request() - idempotencyKey ignored for personal_sign; only eth_sendTransaction, sol_signAndSendTransaction and sol_signAndConfirmTransaction are protected"
      ),
      "\(self.logger.messages(at: .warn))"
    )
  }

  func test_rpcMethod_withKey_willWarn_andStillSendTheRequest() async throws {
    let provider = try makeProvider()

    try await self.request(provider, method: .eth_call, params: [], idempotencyKey: Self.paddedKey)

    XCTAssertEqual(self.requestsSpy.executeCallsCount, 1)
    XCTAssertTrue(self.signerSpy.signCalls.isEmpty)
    try self.assertNoRequestCarriesTheKey("eth_call")
    XCTAssertTrue(self.logger.contains("idempotencyKey ignored for eth_call;"))
    self.logger.assertNoSecret(Self.key)
  }

  func test_providerResolvedMethod_withKey_willWarn() async throws {
    let provider = try makeProvider()

    try await self.request(provider, method: .wallet_switchEthereumChain, params: [], idempotencyKey: Self.paddedKey)

    XCTAssertTrue(self.logger.contains("idempotencyKey ignored for wallet_switchEthereumChain;"))
    XCTAssertEqual(self.requestsSpy.executeCallsCount, 0)
  }

  func test_protectedMethod_onAChainThatDoesNotSignIt_withKey_willWarn_andRelayWithoutTheKey() async throws {
    // A protected method on a namespace that does not sign it is relayed to RPC, where the key
    // cannot travel, so it is dropped with a warning rather than silently.
    let cases: [(chainId: String, method: PortalRequestMethod, params: [AnyCodable])] = [
      (Self.solanaChainId, .eth_sendTransaction, self.transactionParams),
      (Self.evmChainId, .sol_signAndSendTransaction, self.solanaTransactionParams),
      (Self.evmChainId, .sol_signAndConfirmTransaction, self.solanaTransactionParams)
    ]

    for testCase in cases {
      self.requestsSpy = PortalRequestsSpy()
      self.requestsSpy.returnData = try JSONEncoder().encode(MockConstants.mockRpcResponse)
      self.signerSpy.reset()
      self.logger.reset()
      let provider = try makeProvider()

      try await self.request(provider, chainId: testCase.chainId, method: testCase.method, params: testCase.params, idempotencyKey: Self.paddedKey)

      let name = "\(testCase.method.rawValue) on \(testCase.chainId)"
      XCTAssertEqual(self.requestsSpy.executeCallsCount, 1, name)
      XCTAssertTrue(self.signerSpy.signCalls.isEmpty, name)
      try self.assertNoRequestCarriesTheKey(name)
      XCTAssertTrue(
        self.logger.messages(at: .warn).contains { $0.contains("idempotencyKey ignored for \(name);") && $0.contains("cannot be enforced") },
        "Expected a warning naming \(name): \(self.logger.messages(at: .warn))"
      )
      self.logger.assertNoSecret(Self.key)
    }
  }

  func test_protectedMethod_onAChainThatDoesNotSignIt_warning_hasTheSharedWording() async throws {
    let provider = try makeProvider()

    try await self.request(provider, chainId: Self.solanaChainId, method: .eth_sendTransaction, params: self.transactionParams, idempotencyKey: Self.paddedKey)

    XCTAssertTrue(
      self.logger.messages(at: .warn).contains(
        "PortalProvider.request() - idempotencyKey ignored for eth_sendTransaction on \(Self.solanaChainId); the method is not signed on this chain, so the key cannot be enforced"
      ),
      "\(self.logger.messages(at: .warn))"
    )
    XCTAssertFalse(self.logger.contains("are protected"), "Only the chain warning applies to a protected method.")
  }

  func test_unprotectedMethod_onAChainThatDoesNotSignIt_getsTheMethodWarning_notTheChainWarning() async throws {
    // The method check runs before the chain check, so the warning names the real reason.
    let provider = try makeProvider()

    try await self.request(provider, method: .sol_signMessage, params: [AnyCodable("74657374")], idempotencyKey: Self.paddedKey)

    XCTAssertEqual(self.requestsSpy.executeCallsCount, 1, "sol_signMessage is relayed to RPC on an EVM chain.")
    XCTAssertTrue(self.signerSpy.signCalls.isEmpty)
    try self.assertNoRequestCarriesTheKey("sol_signMessage on \(Self.evmChainId)")
    XCTAssertTrue(
      self.logger.messages(at: .warn).contains(
        "PortalProvider.request() - idempotencyKey ignored for sol_signMessage; only eth_sendTransaction, sol_signAndSendTransaction and sol_signAndConfirmTransaction are protected"
      ),
      "\(self.logger.messages(at: .warn))"
    )
    XCTAssertFalse(self.logger.contains("not signed on this chain"), "\(self.logger.messages(at: .warn))")
    self.logger.assertNoSecret(Self.key)
  }

  func test_protectedMethod_onAChainThatDoesNotSignIt_withInvalidKey_stillThrows() async throws {
    let provider = try makeProvider()

    let error = await self.captureError {
      try await self.request(provider, chainId: Self.solanaChainId, method: .eth_sendTransaction, params: self.transactionParams, idempotencyKey: "order key 42")
    }

    self.assertInvalidKey(error)
    XCTAssertEqual(self.requestsSpy.executeCallsCount, 0)
  }

  // MARK: - Raw broadcasts: eth_sendRawTransaction and sol_sendTransaction

  private static let ethRawBroadcastError = PortalIdempotencyError.unsupportedTarget(
    "idempotencyKey is not supported for eth_sendRawTransaction; the signed transaction is broadcast by a plain RPC call that Portal cannot deduplicate"
  )
  private static let solRawBroadcastError = PortalIdempotencyError.unsupportedTarget(
    "idempotencyKey is not supported for sol_sendTransaction; the signed transaction is broadcast by a plain RPC call that Portal cannot deduplicate"
  )

  func test_ethSendRawTransaction_withKey_willThrowUnsupportedTarget_beforeAnyRequest() async throws {
    let provider = try makeProvider()

    let error = await self.captureError {
      try await self.request(provider, method: .eth_sendRawTransaction, params: [AnyCodable("0xdeadbeef")], idempotencyKey: Self.paddedKey)
    }

    XCTAssertEqual(error as? PortalIdempotencyError, Self.ethRawBroadcastError)
    XCTAssertEqual(self.requestsSpy.executeCallsCount, 0, "The raw transaction must not be broadcast.")
    XCTAssertEqual(self.credentials.getTokenCalls, 0)
  }

  func test_ethSendRawTransaction_withInvalidKey_willThrowUnsupportedTarget() async throws {
    // The target check runs first: the key would be refused whatever its shape.
    let provider = try makeProvider()

    let error = await self.captureError {
      try await self.request(provider, method: .eth_sendRawTransaction, params: [AnyCodable("0xdeadbeef")], idempotencyKey: "not a valid key")
    }

    XCTAssertEqual(error as? PortalIdempotencyError, Self.ethRawBroadcastError)
    XCTAssertEqual(self.requestsSpy.executeCallsCount, 0)
  }

  func test_ethSendRawTransaction_withoutKey_isStillBroadcast() async throws {
    let provider = try makeProvider()

    try await self.request(provider, method: .eth_sendRawTransaction, params: [AnyCodable("0xdeadbeef")], idempotencyKey: nil)

    XCTAssertEqual(self.requestsSpy.executeCallsCount, 1)
  }

  func test_solSendTransaction_withKey_willThrowUnsupportedTarget_beforeAnyRequest() async throws {
    // Solana's raw broadcast RPC (`sendTransaction`) is refused like `eth_sendRawTransaction`, on
    // any chain it is sent to, instead of being relayed with the key dropped.
    for chainId in [Self.solanaChainId, Self.evmChainId] {
      self.requestsSpy = PortalRequestsSpy()
      let provider = try makeProvider()

      let error = await self.captureError {
        try await self.request(provider, chainId: chainId, method: .sol_sendTransaction, params: self.solanaTransactionParams, idempotencyKey: Self.paddedKey)
      }

      XCTAssertEqual(error as? PortalIdempotencyError, Self.solRawBroadcastError, chainId)
      XCTAssertEqual(self.requestsSpy.executeCallsCount, 0, "\(chainId): the signed transaction must not be broadcast.")
      XCTAssertTrue(self.signerSpy.signCalls.isEmpty, chainId)
    }
    XCTAssertEqual(self.credentials.getTokenCalls, 0)
    XCTAssertFalse(self.logger.contains("idempotencyKey ignored"), "A raw broadcast throws; it is not warned about and dropped.")
    self.logger.assertNoSecret(Self.key)
  }

  func test_rawBroadcast_withKey_onAChainThatIsNotItsOwn_willThrowUnsupportedTarget_beforeAnyRequest() async throws {
    // The refusal depends on the method alone: a raw broadcast relayed on another namespace is
    // still a plain RPC call Portal cannot deduplicate, so it throws instead of being dropped.
    let cases: [(chainId: String, method: PortalRequestMethod, params: [AnyCodable], expected: PortalIdempotencyError)] = [
      (Self.solanaChainId, .eth_sendRawTransaction, [AnyCodable("0xdeadbeef")], Self.ethRawBroadcastError),
      (Self.bitcoinChainId, .eth_sendRawTransaction, [AnyCodable("0xdeadbeef")], Self.ethRawBroadcastError),
      (Self.bitcoinChainId, .sol_sendTransaction, self.solanaTransactionParams, Self.solRawBroadcastError)
    ]

    for testCase in cases {
      self.requestsSpy = PortalRequestsSpy()
      self.signerSpy.reset()
      self.logger.reset()
      let provider = try makeProvider()
      let name = "\(testCase.method.rawValue) on \(testCase.chainId)"

      let error = await self.captureError {
        try await self.request(provider, chainId: testCase.chainId, method: testCase.method, params: testCase.params, idempotencyKey: Self.paddedKey)
      }

      XCTAssertEqual(error as? PortalIdempotencyError, testCase.expected, name)
      XCTAssertEqual(self.requestsSpy.executeCallsCount, 0, "\(name): the signed transaction must not be broadcast.")
      XCTAssertTrue(self.requestsSpy.executeRequestHistory.isEmpty, name)
      XCTAssertTrue(self.signerSpy.signCalls.isEmpty, name)
      XCTAssertFalse(self.logger.contains("idempotencyKey ignored"), "\(name): a raw broadcast throws; it is not warned about and dropped.")
      self.logger.assertNoSecret(Self.key)
    }
    XCTAssertEqual(self.credentials.getTokenCalls, 0)
  }

  func test_solSendTransaction_withInvalidKey_willThrowUnsupportedTarget() async throws {
    let provider = try makeProvider()

    let error = await self.captureError {
      try await self.request(provider, chainId: Self.solanaChainId, method: .sol_sendTransaction, params: self.solanaTransactionParams, idempotencyKey: "   ")
    }

    XCTAssertEqual(error as? PortalIdempotencyError, Self.solRawBroadcastError)
    XCTAssertEqual(self.requestsSpy.executeCallsCount, 0)
  }

  func test_solSendTransaction_withoutKey_isStillBroadcast() async throws {
    let provider = try makeProvider()

    try await self.request(provider, chainId: Self.solanaChainId, method: .sol_sendTransaction, params: self.solanaTransactionParams, idempotencyKey: nil)

    XCTAssertEqual(self.requestsSpy.executeCallsCount, 1)
    XCTAssertTrue(self.signerSpy.signCalls.isEmpty, "sol_sendTransaction is relayed to RPC, never signed.")
  }

  // MARK: - Invalid keys

  func test_invalidKey_willThrowBeforeTheApprovalPrompt_theTokenAndTheSigner() async throws {
    let provider = try makeProvider(autoApprove: false)
    let approvalRequests = Counter()
    // Approves when asked, so a regression that validated after the prompt fails the count below
    // instead of hanging on an approval that never comes.
    _ = provider.on(event: Events.PortalSigningRequested.rawValue) { [weak provider] data in
      approvalRequests.increment()
      _ = provider?.emit(event: Events.PortalSigningApproved.rawValue, data: data)
    }

    let error = await self.captureError {
      try await self.request(provider, method: .eth_sendTransaction, params: self.transactionParams, idempotencyKey: "order key 42")
    }

    self.assertInvalidKey(error)
    XCTAssertEqual(approvalRequests.value, 0)
    XCTAssertTrue(self.signerSpy.signCalls.isEmpty)
    XCTAssertEqual(self.credentials.getTokenCalls, 0, "An invalid key must not touch the session.")
  }

  func test_invalidKey_withoutApprovalListener_willThrowInvalidKey_notNoBinding() async throws {
    let provider = try makeProvider(autoApprove: false)

    let error = await self.captureError {
      try await self.request(provider, method: .eth_sendTransaction, params: self.transactionParams, idempotencyKey: String(repeating: "a", count: 256))
    }

    self.assertInvalidKey(error)
    XCTAssertNil(error as? ProviderSigningError)
    XCTAssertTrue(self.signerSpy.signCalls.isEmpty)
  }

  func test_invalidKey_onAnIgnoredMethod_stillThrows() async throws {
    // Validation precedes the method check, so a malformed key is reported even where it would
    // have been ignored.
    let provider = try makeProvider()

    let signError = await self.captureError {
      try await self.request(provider, method: .personal_sign, params: [AnyCodable("0x74657374"), AnyCodable(MockConstants.mockEip155Address)], idempotencyKey: "   ")
    }
    let rpcError = await self.captureError {
      try await self.request(provider, method: .eth_call, params: [], idempotencyKey: "slash/key")
    }

    self.assertInvalidKey(signError)
    self.assertInvalidKey(rpcError)
    XCTAssertTrue(self.signerSpy.signCalls.isEmpty)
    XCTAssertEqual(self.requestsSpy.executeCallsCount, 0)
  }

  func test_invalidKey_isNotLogged() async throws {
    let secretKey = "secret key with spaces"
    let provider = try makeProvider()

    let error = await self.captureError {
      try await self.request(provider, method: .eth_sendTransaction, params: self.transactionParams, idempotencyKey: secretKey)
    }

    self.assertInvalidKey(error)
    XCTAssertFalse(error?.localizedDescription.contains(secretKey) ?? true)
    self.logger.assertNoSecret(secretKey)
  }

  // MARK: - Signer rejections

  func test_idempotencyRejectionFromTheSigner_isRethrownUnchanged() async throws {
    self.signerSpy.errorToThrow = PortalMpcError(PortalError(id: PortalIdempotencyErrorId.requestAlreadyCompleted, message: "done"))
    let provider = try makeProvider()

    let error = await self.captureError {
      try await self.request(provider, method: .eth_sendTransaction, params: self.transactionParams, idempotencyKey: Self.key)
    }

    let mpcError = try XCTUnwrap(error as? PortalMpcError)
    XCTAssertTrue(mpcError.isIdempotencyRejection)
    XCTAssertEqual(mpcError.id, "IDEMPOTENT_REQUEST_ALREADY_COMPLETED")
    XCTAssertEqual(self.signerSpy.signCalls.count, 1, "The provider must not retry a rejected key.")
  }

  // MARK: - Deterministic params

  func test_signingParams_areEncodedWithSortedKeys() async throws {
    let provider = try makeProvider()
    let params = [AnyCodable([
      "value": "0x1",
      "to": "0xdef",
      "gas": "0x5208",
      "from": "0xabc",
      "data": "0x"
    ])]

    try await self.request(provider, method: .eth_sendTransaction, params: params, idempotencyKey: Self.key)

    XCTAssertEqual(
      self.signerSpy.lastSignCall?.payload.params,
      #"{"data":"0x","from":"0xabc","gas":"0x5208","to":"0xdef","value":"0x1"}"#
    )
  }

  func test_signingParams_areByteEqual_forDifferentInsertionOrders() async throws {
    let provider = try makeProvider()
    var forward: [String: Any] = [:]
    for (key, value) in [("from", "0xabc"), ("to", "0xdef"), ("value", "0x1"), ("data", "0x"), ("nonce", "0x2")] {
      forward[key] = value
    }
    var reverse: [String: Any] = [:]
    reverse.reserveCapacity(64)
    for (key, value) in [("nonce", "0x2"), ("data", "0x"), ("value", "0x1"), ("to", "0xdef"), ("from", "0xabc")] {
      reverse[key] = value
    }

    try await self.request(provider, method: .eth_sendTransaction, params: [AnyCodable(forward)], idempotencyKey: Self.key)
    try await self.request(provider, method: .eth_sendTransaction, params: [AnyCodable(reverse)], idempotencyKey: Self.key)

    let payloads = self.signerSpy.signPayloadParams.map { $0.params }
    XCTAssertEqual(payloads.count, 2)
    XCTAssertEqual(payloads.first, payloads.last)
    XCTAssertEqual(payloads.first, #"{"data":"0x","from":"0xabc","nonce":"0x2","to":"0xdef","value":"0x1"}"#)
  }

  func test_signingParams_typedStructs_areEncodedWithSortedKeys_onEveryCall() async throws {
    // `sendAsset` passes a typed transaction. `JSONEncoder` does not fix the key order of a
    // synthesized `Encodable` either, so without sorted keys two encodes can differ.
    let provider = try makeProvider()
    let transaction = ETHTransactionParam(from: "0xabc", to: "0xdef", gas: "0x5208", gasPrice: "0x1", value: "0x1", data: "0x")

    for _ in 0 ..< 3 {
      try await self.request(provider, method: .eth_sendTransaction, params: [AnyCodable(transaction)], idempotencyKey: Self.key)
    }

    let payloads = Set(self.signerSpy.signPayloadParams.map { $0.params })
    XCTAssertEqual(payloads, [#"{"data":"0x","from":"0xabc","gas":"0x5208","gasPrice":"0x1","to":"0xdef","value":"0x1"}"#])
  }

  func test_signingParams_sortNestedObjects() async throws {
    let provider = try makeProvider()
    let typedData: [String: Any] = [
      "primaryType": "Mail",
      "domain": ["version": "1", "name": "Portal", "chainId": 11_155_111]
    ]

    try await self.request(provider, method: .eth_signTypedData_v4, params: [AnyCodable(MockConstants.mockEip155Address), AnyCodable(typedData)], idempotencyKey: nil)

    let params = try XCTUnwrap(self.signerSpy.lastSignCall?.payload.params)
    XCTAssertTrue(
      params.contains(#"{"domain":{"chainId":11155111,"name":"Portal","version":"1"},"primaryType":"Mail"}"#),
      params
    )
  }

  // MARK: - Production wiring

  /// Builds the provider without a `signer:`, so the real `PortalMpcSigner` signs through
  /// `binary`. These cases prove the key crosses the `PortalSignerProtocol` existential into the
  /// class's implementation, not the protocol-extension default (which drops it), and reaches the
  /// binary. The `SignerSpy` cases above stop short of that dispatch.
  private func makeProviderWithDefaultSigner(
    binary: Mobile,
    featureFlags: FeatureFlags? = nil,
    presignatureSource: PresignatureSource? = nil,
    keychain: PortalKeychainProtocol = MockPortalKeychain()
  ) throws -> PortalProvider {
    try PortalProvider(
      credentials: self.credentials,
      rpcConfig: [Self.evmChainId: "https://api.portalhq.io/rpc/v1/eip155/11155111"],
      keychain: keychain,
      autoApprove: true,
      featureFlags: featureFlags,
      requests: self.requestsSpy,
      binary: binary,
      presignatureSource: presignatureSource
    )
  }

  private func decodeMetadata(_ metadata: String?, file: StaticString = #filePath, line: UInt = #line) throws -> MpcMetadata {
    let metadata = try XCTUnwrap(metadata, "The binary was not handed any metadata.", file: file, line: line)
    return try JSONDecoder().decode(MpcMetadata.self, from: Data(metadata.utf8))
  }

  func test_defaultMpcSigner_ethSendTransaction_withKey_putsTheTrimmedKeyInTheBinaryMetadata() async throws {
    let mobileSpy = MobileSpy()
    let provider = try makeProviderWithDefaultSigner(binary: mobileSpy)

    let result = try await self.request(provider, method: .eth_sendTransaction, params: self.transactionParams, idempotencyKey: Self.paddedKey)

    XCTAssertEqual(result.result as? String, MockConstants.mockSignature)
    XCTAssertEqual(mobileSpy.mobileSignCallsCount, 1)
    let metadata = try self.decodeMetadata(mobileSpy.mobileSignMetadataParam)
    XCTAssertEqual(metadata.idempotencyKey, Self.key)
    XCTAssertEqual(metadata.reqId, "trace-1")
    XCTAssertFalse(
      self.logger.contains("does not accept idempotencyKey"),
      "The default signer must not be reached through the protocol default that drops the key."
    )
    self.logger.assertNoSecret(Self.key)
  }

  func test_defaultMpcSigner_presignaturePath_withKey_putsTheTrimmedKeyInTheBinaryMetadata() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignWithPresignatureReturnValue = MockConstants.mockSignatureResponse
    let provider = try makeProviderWithDefaultSigner(
      binary: mobileSpy,
      featureFlags: FeatureFlags(usePresignatures: true),
      presignatureSource: FixedPresignatureSource()
    )

    try await self.request(provider, method: .eth_sendTransaction, params: self.transactionParams, idempotencyKey: Self.paddedKey)

    XCTAssertEqual(mobileSpy.mobileSignWithPresignatureCallsCount, 1)
    XCTAssertEqual(mobileSpy.mobileSignCallsCount, 0)
    XCTAssertEqual(try self.decodeMetadata(mobileSpy.mobileSignWithPresignatureMetadataStrParam).idempotencyKey, Self.key)
    self.logger.assertNoSecret(Self.key)
  }

  func test_defaultMpcSigner_personalSign_withKey_omitsTheMetadataField() async throws {
    let mobileSpy = MobileSpy()
    let provider = try makeProviderWithDefaultSigner(binary: mobileSpy)

    try await self.request(provider, method: .personal_sign, params: [AnyCodable("0x74657374"), AnyCodable(MockConstants.mockEip155Address)], idempotencyKey: Self.paddedKey)

    let metadata = try XCTUnwrap(mobileSpy.mobileSignMetadataParam)
    XCTAssertFalse(metadata.contains("idempotencyKey"), metadata)
    XCTAssertTrue(self.logger.contains("idempotencyKey ignored for personal_sign;"))
  }

  func test_defaultMpcSigner_rawSign_withKey_omitsTheMetadataField() async throws {
    let mobileSpy = MobileSpy()
    let provider = try makeProviderWithDefaultSigner(binary: mobileSpy)

    try await self.request(provider, method: .rawSign, params: [AnyCodable("74657374")], idempotencyKey: Self.paddedKey)

    XCTAssertEqual(mobileSpy.mobileSignIsRawParam, true)
    let metadata = try XCTUnwrap(mobileSpy.mobileSignMetadataParam)
    XCTAssertFalse(metadata.contains("idempotencyKey"), metadata)
  }

  func test_defaultMpcSigner_withoutKey_omitsTheMetadataField() async throws {
    let mobileSpy = MobileSpy()
    let provider = try makeProviderWithDefaultSigner(binary: mobileSpy)

    try await self.request(provider, method: .eth_sendTransaction, params: self.transactionParams, idempotencyKey: nil)

    let metadata = try XCTUnwrap(mobileSpy.mobileSignMetadataParam)
    XCTAssertFalse(metadata.contains("idempotencyKey"), metadata)
  }

  // MARK: - Production wiring over the MPC Enclave API

  /// A transport for the `EnclaveMobileWrapper` alone, answering every `/v1/sign` with a
  /// signature. The provider's RPC transport stays `requestsSpy`.
  private func enclaveSigningSpy() throws -> PortalRequestsSpy {
    let spy = PortalRequestsSpy()
    spy.returnData = try JSONEncoder().encode(EnclaveSignResponse(data: "0xenclave-tx-hash"))
    return spy
  }

  /// The keychain is returned so the test keeps it alive: the provider and the signer hold it
  /// weakly, and without a share the wrapper refuses to send anything.
  private func makeProviderWithEnclaveSigner(
    enclaveRequests: PortalRequestsSpy,
    presignatureSource: FixedPresignatureSource
  ) throws -> (provider: PortalProvider, keychain: MockPortalKeychain) {
    let keychain = MockPortalKeychain()
    let provider = try self.makeProviderWithDefaultSigner(
      binary: EnclaveMobileWrapper(requests: enclaveRequests, enclaveMPCHost: "mpc-client.portalhq.io"),
      featureFlags: FeatureFlags(useEnclaveMPCApi: true, usePresignatures: true),
      presignatureSource: presignatureSource,
      keychain: keychain
    )
    return (provider, keychain)
  }

  /// These cases go through the provider's own `PortalMpcSigner` rather than one built by hand.
  func test_defaultMpcSigner_enclave_presignaturesOn_withKey_usesThePresignature_andSendsTheTrimmedKeyHeader() async throws {
    let enclaveSpy = try enclaveSigningSpy()
    let source = FixedPresignatureSource()
    let (provider, keychain) = try makeProviderWithEnclaveSigner(enclaveRequests: enclaveSpy, presignatureSource: source)

    let result = try await self.request(provider, method: .eth_sendTransaction, params: self.transactionParams, idempotencyKey: Self.paddedKey)

    withExtendedLifetime(keychain) {}
    XCTAssertEqual(result.result as? String, "0xenclave-tx-hash")
    XCTAssertEqual(source.consumeCallCount, 1)
    XCTAssertEqual(enclaveSpy.executeCallsCount, 1)
    let request = try XCTUnwrap(enclaveSpy.executeRequestParam)
    XCTAssertEqual(request.url.absoluteString, "https://mpc-client.portalhq.io/v1/sign")
    XCTAssertEqual(request.headers[PORTAL_IDEMPOTENCY_KEY_HEADER], Self.key)
    let payload = try XCTUnwrap(request.payload as? [String: String])
    XCTAssertEqual(payload["presignature"], "presig-data")
    XCTAssertEqual(try self.decodeMetadata(payload["metadataStr"]).idempotencyKey, Self.key)
    self.logger.assertNoSecret(Self.key)
  }

  func test_defaultMpcSigner_enclave_presignaturesOn_withoutKey_keepsThePresignaturePath() async throws {
    let enclaveSpy = try enclaveSigningSpy()
    let source = FixedPresignatureSource()
    let (provider, keychain) = try makeProviderWithEnclaveSigner(enclaveRequests: enclaveSpy, presignatureSource: source)

    let result = try await self.request(provider, method: .eth_sendTransaction, params: self.transactionParams, idempotencyKey: nil)

    withExtendedLifetime(keychain) {}
    XCTAssertEqual(result.result as? String, "0xenclave-tx-hash")
    XCTAssertEqual(source.consumeCallCount, 1)
    XCTAssertEqual(enclaveSpy.executeCallsCount, 1)
    let request = try XCTUnwrap(enclaveSpy.executeRequestParam)
    XCTAssertEqual(request.url.absoluteString, "https://mpc-client.portalhq.io/v1/sign")
    XCTAssertEqual((request.payload as? [String: String])?["presignature"], "presig-data")
    XCTAssertFalse(request.headers.keys.contains { $0.caseInsensitiveCompare(PORTAL_IDEMPOTENCY_KEY_HEADER) == .orderedSame })
  }
}

/// Hands out the same presignature on every call, so the default signer takes the presignature
/// path.
private final class FixedPresignatureSource: PresignatureSource {
  private(set) var consumeCallCount = 0

  func consumePresignature(forCurve _: PortalCurve) async -> PresignatureEntry? {
    consumeCallCount += 1
    return PresignatureEntry(id: "presig-idem", expiresAt: "2099-01-01T00:00:00Z", data: "presig-data")
  }
}
