//
//  PortalSendAssetIdempotencyKeyTests.swift
//  PortalSwiftTests
//
//  Verifies how sendAsset handles SendAssetParams.idempotencyKey: validated before the transaction
//  is built, forwarded trimmed to eth_sendTransaction (EVM) and sol_signAndSendTransaction
//  (Solana), and refused on Bitcoin before anything is built or signed. The end-to-end cases run
//  sendAsset through a real PortalProvider to a SignerSpy, so the provider's own key resolution
//  and signing-param encoding are covered too.
//

@testable import PortalSwift
import XCTest

extension PortalTests {
  private static let sendAssetEvmChainId = "eip155:11155111"
  private static let sendAssetSolanaChainId = "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1"
  private static let sendAssetBitcoinChainIds = [
    "bip122:000000000019d6689c085ae165831e93-p2wpkh",
    "bip122:000000000933ea01ad0ee984209779ba-p2wpkh"
  ]

  private func sendAssetParams(idempotencyKey: String?) -> SendAssetParams {
    SendAssetParams(to: "0xto", amount: "1.0", token: "NATIVE", traceId: "trace-send", idempotencyKey: idempotencyKey)
  }

  /// Runs `sendAsset`, failing the test if it does not throw, and returns the error it threw.
  private func sendAssetError(chainId: String, params: SendAssetParams, file: StaticString = #filePath, line: UInt = #line) async -> Error? {
    do {
      _ = try await portal.sendAsset(chainId: chainId, params: params)
      XCTFail("Expected sendAsset to throw on \(chainId).", file: file, line: line)
      return nil
    } catch {
      return error
    }
  }

  private func assertNoBuildCalls(_ apiSpy: PortalApiSpy, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(apiSpy.buildEip155TransactionCallsCount, 0, message, file: file, line: line)
    XCTAssertEqual(apiSpy.buildSolanaTransactionCallsCount, 0, message, file: file, line: line)
    XCTAssertEqual(apiSpy.buildBitcoinP2wpkhTransactionCallsCount, 0, message, file: file, line: line)
    XCTAssertEqual(apiSpy.broadcastBitcoinP2wpkhTransactionCallsCount, 0, message, file: file, line: line)
  }

  // MARK: - EVM and Solana forward the key

  func test_sendAsset_eip155_forwardsTheTrimmedIdempotencyKey_toEthSendTransaction() async throws {
    let apiSpy = PortalApiSpy()
    try initPortalWithSpy(api: apiSpy)
    let providerSpy = try PortalProviderSpy()
    setToPortal(portalProvider: providerSpy)

    _ = try await portal.sendAsset(chainId: Self.sendAssetEvmChainId, params: self.sendAssetParams(idempotencyKey: " \u{00A0}order-42\u{FEFF} "))

    XCTAssertEqual(apiSpy.buildEip155TransactionCallsCount, 1)
    XCTAssertEqual(providerSpy.requestOptionsCallsCount, 1)
    XCTAssertEqual(providerSpy.requestOptionsMethodParam, .eth_sendTransaction)
    XCTAssertEqual(providerSpy.requestOptionsOptionsParam?.idempotencyKey, "order-42")
    XCTAssertEqual(providerSpy.requestOptionsOptionsParam?.traceId, "trace-send", "The key must not displace the trace id.")
  }

  func test_sendAsset_solana_forwardsTheTrimmedIdempotencyKey_toSolSignAndSendTransaction() async throws {
    let apiSpy = PortalApiSpy()
    try initPortalWithSpy(api: apiSpy)
    let providerSpy = try PortalProviderSpy()
    setToPortal(portalProvider: providerSpy)

    _ = try await portal.sendAsset(chainId: Self.sendAssetSolanaChainId, params: self.sendAssetParams(idempotencyKey: "  order-42\n"))

    XCTAssertEqual(apiSpy.buildSolanaTransactionCallsCount, 1)
    XCTAssertEqual(providerSpy.requestOptionsCallsCount, 1)
    XCTAssertEqual(providerSpy.requestOptionsMethodParam, .sol_signAndSendTransaction)
    XCTAssertEqual(providerSpy.requestOptionsOptionsParam?.idempotencyKey, "order-42")
  }

  func test_sendAsset_withoutIdempotencyKey_forwardsNil() async throws {
    for chainId in [Self.sendAssetEvmChainId, Self.sendAssetSolanaChainId] {
      let apiSpy = PortalApiSpy()
      try initPortalWithSpy(api: apiSpy)
      let providerSpy = try PortalProviderSpy()
      setToPortal(portalProvider: providerSpy)

      _ = try await portal.sendAsset(chainId: chainId, params: SendAssetParams(to: "0xto", amount: "1.0", token: "NATIVE"))

      XCTAssertEqual(providerSpy.requestOptionsCallsCount, 1, chainId)
      XCTAssertNotNil(providerSpy.requestOptionsOptionsParam, chainId)
      XCTAssertNil(providerSpy.requestOptionsOptionsParam?.idempotencyKey, chainId)
    }
  }

  // MARK: - Bitcoin refuses the key

  func test_sendAsset_bip122_withIdempotencyKey_throwsUnsupportedTarget_beforeBuildingOrSigning() async throws {
    for chainId in Self.sendAssetBitcoinChainIds {
      let apiSpy = PortalApiSpy()
      try initPortalWithSpy(api: apiSpy)
      let providerSpy = try PortalProviderSpy()
      setToPortal(portalProvider: providerSpy)

      let error = await self.sendAssetError(chainId: chainId, params: self.sendAssetParams(idempotencyKey: "order-42"))

      XCTAssertEqual(
        error as? PortalIdempotencyError,
        .unsupportedTarget("idempotencyKey is not supported for Bitcoin sendAsset; the transaction is raw-signed and broadcast by the SDK"),
        chainId
      )
      self.assertNoBuildCalls(apiSpy, chainId)
      XCTAssertEqual(providerSpy.requestOptionsCallsCount, 0, "\(chainId): nothing may be signed.")
    }
  }

  func test_sendAsset_bip122_unsupportedAddressType_withIdempotencyKey_throwsUnsupportedTarget() async throws {
    // The key is refused before the p2wpkh check, so an unsupported Bitcoin address type gets the
    // same error as a supported one, and nothing is built.
    for chainId in ["bip122:000000000019d6689c085ae165831e93-p2tr", "bip122:000000000933ea01ad0ee984209779ba-p2pkh"] {
      let apiSpy = PortalApiSpy()
      try initPortalWithSpy(api: apiSpy)
      let providerSpy = try PortalProviderSpy()
      setToPortal(portalProvider: providerSpy)

      let keyedError = await self.sendAssetError(chainId: chainId, params: self.sendAssetParams(idempotencyKey: "order-42"))
      let unkeyedError = await self.sendAssetError(chainId: chainId, params: self.sendAssetParams(idempotencyKey: nil))

      XCTAssertEqual(keyedError as? PortalIdempotencyError, .unsupportedBitcoinSendAsset, chainId)
      XCTAssertEqual(unkeyedError as? PortalClassError, .unsupportedChainId(chainId), "\(chainId): without a key the address type check still applies.")
      self.assertNoBuildCalls(apiSpy, chainId)
      XCTAssertEqual(providerSpy.requestOptionsCallsCount, 0, chainId)
    }
  }

  func test_sendAsset_bip122_withoutIdempotencyKey_stillBuildsSignsAndBroadcasts() async throws {
    let apiSpy = PortalApiSpy()
    apiSpy.buildBitcoinP2wpkhTransactionReturnValue = BuildBitcoinP2wpkhTransactionResponse.stub(
      transaction: BitcoinP2wpkhTransaction.stub(signatureHashes: ["hash-1", "hash-2"], rawTxHex: "rawTxHex")
    )
    try initPortalWithSpy(api: apiSpy)
    let providerSpy = try PortalProviderSpy()
    setToPortal(portalProvider: providerSpy)

    _ = try await portal.sendAsset(chainId: Self.sendAssetBitcoinChainIds[0], params: self.sendAssetParams(idempotencyKey: nil))

    XCTAssertEqual(apiSpy.buildBitcoinP2wpkhTransactionCallsCount, 1)
    XCTAssertEqual(providerSpy.requestOptionsCallsCount, 2, "Each signature hash is raw-signed.")
    XCTAssertEqual(providerSpy.requestOptionsMethodParam, .rawSign)
    XCTAssertNil(providerSpy.requestOptionsOptionsParam?.idempotencyKey)
    XCTAssertEqual(apiSpy.broadcastBitcoinP2wpkhTransactionCallsCount, 1)
  }

  // MARK: - Invalid keys fail before the build

  func test_sendAsset_malformedIdempotencyKey_throwsInvalidKey_beforeBuilding() async throws {
    let secretKey = "order key/42"

    for chainId in [Self.sendAssetEvmChainId, Self.sendAssetSolanaChainId] + Self.sendAssetBitcoinChainIds {
      let apiSpy = PortalApiSpy()
      try initPortalWithSpy(api: apiSpy)
      let providerSpy = try PortalProviderSpy()
      setToPortal(portalProvider: providerSpy)

      let error = await self.sendAssetError(chainId: chainId, params: self.sendAssetParams(idempotencyKey: secretKey))

      guard case let .invalidKey(rule) = error as? PortalIdempotencyError else {
        XCTFail("\(chainId): expected PortalIdempotencyError.invalidKey, got \(String(describing: error))")
        continue
      }
      XCTAssertEqual(rule, "idempotencyKey may only contain the characters A-Z, a-z, 0-9, '.', '_', '~' and '-'", chainId)
      XCTAssertFalse(error?.localizedDescription.contains(secretKey) ?? true, chainId)
      self.assertNoBuildCalls(apiSpy, chainId)
      XCTAssertEqual(providerSpy.requestOptionsCallsCount, 0, chainId)
    }
  }

  func test_sendAsset_whitespaceOnlyIdempotencyKey_throwsInvalidKey_beforeBuilding() async throws {
    let apiSpy = PortalApiSpy()
    try initPortalWithSpy(api: apiSpy)
    let providerSpy = try PortalProviderSpy()
    setToPortal(portalProvider: providerSpy)

    let error = await self.sendAssetError(chainId: Self.sendAssetEvmChainId, params: self.sendAssetParams(idempotencyKey: " \u{00A0}\t\u{3000} "))

    guard case let .invalidKey(rule) = error as? PortalIdempotencyError else {
      XCTFail("Expected PortalIdempotencyError.invalidKey, got \(String(describing: error))")
      return
    }
    XCTAssertEqual(rule, "idempotencyKey must not be empty or whitespace-only")
    self.assertNoBuildCalls(apiSpy, "A whitespace-only key must fail before the build.")
    XCTAssertEqual(providerSpy.requestOptionsCallsCount, 0)
  }

  // MARK: - End to end through PortalProvider

  /// Replaces the provider with a real `PortalProvider` that signs through `signerSpy`, so
  /// `sendAsset` runs through the provider's key resolution and signing-param encoding.
  private func setProvider(signingWith signerSpy: SignerSpy) throws {
    let requestsSpy = PortalRequestsSpy()
    requestsSpy.returnData = try JSONEncoder().encode(MockConstants.mockRpcResponse)
    let provider = try PortalProvider(
      credentials: MockCredentials(tokenValue: "session-token-send"),
      rpcConfig: [
        Self.sendAssetEvmChainId: "https://api.portalhq.io/rpc/v1/eip155/11155111",
        Self.sendAssetSolanaChainId: "https://api.portalhq.io/rpc/v1/solana/EtWTRABZaYq6iMfeYKouRu166VU2xqa1"
      ],
      keychain: MockPortalKeychain(),
      autoApprove: true,
      requests: requestsSpy,
      signer: signerSpy
    )
    setToPortal(portalProvider: provider)
  }

  func test_sendAsset_eip155_sameKeyRetry_reachesTheSignerWithTheTrimmedKey_andByteIdenticalParams() async throws {
    // The build response is the same on both calls, as an EVM rebuild normally is, so the retry
    // must reach the signer with byte-identical params: that is what Portal compares.
    try initPortalWithSpy(api: PortalApiSpy())
    let signerSpy = SignerSpy()
    try self.setProvider(signingWith: signerSpy)

    for _ in 0 ..< 2 {
      let response = try await portal.sendAsset(chainId: Self.sendAssetEvmChainId, params: self.sendAssetParams(idempotencyKey: " order-42 "))
      XCTAssertEqual(response.txHash, MockConstants.mockSignature)
    }

    XCTAssertEqual(signerSpy.signIdempotencyKeyParams, ["order-42", "order-42"])
    XCTAssertEqual(signerSpy.signPayloadParams.map { $0.method }, [.eth_sendTransaction, .eth_sendTransaction])
    XCTAssertEqual(
      signerSpy.signPayloadParams.map { $0.params },
      Array(repeating: #"{"data":"0xData","from":"0xFromAddress","to":"0xToAddress","value":"1000000000000000000"}"#, count: 2)
    )
    XCTAssertEqual(signerSpy.signReqIdParams, ["trace-send", "trace-send"])
  }

  func test_sendAsset_solana_sameKeyRetry_reachesTheSignerWithTheTrimmedKey() async throws {
    try initPortalWithSpy(api: PortalApiSpy())
    let signerSpy = SignerSpy()
    try self.setProvider(signingWith: signerSpy)

    for _ in 0 ..< 2 {
      _ = try await portal.sendAsset(chainId: Self.sendAssetSolanaChainId, params: self.sendAssetParams(idempotencyKey: "\u{3000}order-42\n"))
    }

    XCTAssertEqual(signerSpy.signIdempotencyKeyParams, ["order-42", "order-42"])
    XCTAssertEqual(signerSpy.signPayloadParams.map { $0.method }, [.sol_signAndSendTransaction, .sol_signAndSendTransaction])
    let params = signerSpy.signPayloadParams.map { $0.params }
    XCTAssertEqual(params.count, 2)
    XCTAssertEqual(params.first, params.last)
    XCTAssertTrue(params.first?.contains("defaultTransactionData") ?? false, params.first ?? "nil")
  }

  func test_sendAsset_withoutIdempotencyKey_reachesTheSignerWithNil() async throws {
    try initPortalWithSpy(api: PortalApiSpy())
    let signerSpy = SignerSpy()
    try self.setProvider(signingWith: signerSpy)

    _ = try await portal.sendAsset(chainId: Self.sendAssetEvmChainId, params: self.sendAssetParams(idempotencyKey: nil))
    _ = try await portal.sendAsset(chainId: Self.sendAssetSolanaChainId, params: self.sendAssetParams(idempotencyKey: nil))

    XCTAssertEqual(signerSpy.signIdempotencyKeyParams, [nil, nil])
    XCTAssertEqual(signerSpy.idempotencyKeyOverloadCallsCount, 2)
  }
}
