//
//  YieldXyzPerpsExecutionTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import AnyCodable
@testable import PortalSwift
import XCTest

// MARK: - Doubles

/// An ordered record of what the runner did, shared by the fake backend and the signers.
final class PerpsCallLog {
  private(set) var entries: [String] = []

  func append(_ entry: String) {
    entries.append(entry)
  }
}

/// Yield.xyz as the SDK reads it back (like the React Native suite's `fakeBackend`): `getAction`
/// lists `initial` with each transaction's latest status, a successful submission records its
/// transaction as `CONFIRMED`, and the action succeeds once every transaction is recorded.
/// Scripted reads and submissions are consumed first, one per call.
final class FakePerpsBackend: PortalYieldXyzPerpsApiProtocol {
  var initial: YieldXyzPerpsAction
  var statuses: [String: YieldXyzPerpsTransactionStatus]
  var scriptedReads: [Swift.Result<YieldXyzPerpsAction, Error>] = []
  var scriptedSubmits: [Swift.Result<YieldXyzPerpsSubmitResult, Error>] = []
  var createActionError: Error?
  /// URLSession throws `URLError(.cancelled)` for a request whose task was cancelled. A scripted
  /// `URLError(.cancelled)` cancels the current task first, as that would, unless this is `false`.
  var cancelsTaskOnCancelledRequest = true
  let log: PerpsCallLog

  private(set) var submitted: [YieldXyzPerpsSubmitTransactionParams] = []
  private(set) var getActionCallsCount = 0
  private(set) var createActionRequests: [YieldXyzPerpsCreateActionRequest] = []

  init(_ initial: YieldXyzPerpsAction, log: PerpsCallLog = PerpsCallLog()) {
    self.initial = initial
    self.statuses = Dictionary(uniqueKeysWithValues: initial.transactions.map { ($0.id, $0.status) })
    self.log = log
  }

  /// The action as Yield.xyz lists it now.
  func currentAction() -> YieldXyzPerpsAction {
    let transactions = initial.transactions.map { $0.with(status: statuses[$0.id] ?? $0.status) }
    let recorded = transactions.allSatisfy { $0.status == .broadcasted || $0.status == .confirmed }
    return initial.with(status: recorded ? .success : initial.status, transactions: transactions)
  }

  func getAction(actionId _: String) async throws -> YieldXyzPerpsGetActionResponse {
    getActionCallsCount += 1
    log.append("read")
    if !scriptedReads.isEmpty {
      return try YieldXyzPerpsResponse(data: resolve(scriptedReads.removeFirst()))
    }
    return YieldXyzPerpsResponse(data: currentAction())
  }

  func submitTransaction(params: YieldXyzPerpsSubmitTransactionParams) async throws -> YieldXyzPerpsSubmitTransactionResponse {
    submitted.append(params)
    log.append("submit:\(params.transactionId)")
    if !scriptedSubmits.isEmpty {
      let result = try resolve(scriptedSubmits.removeFirst())
      if result.status != .failed {
        statuses[params.transactionId] = .confirmed
      }
      return YieldXyzPerpsResponse(data: result)
    }
    statuses[params.transactionId] = .confirmed
    return YieldXyzPerpsResponse(data: YieldXyzPerpsFixtures.submitResult())
  }

  func createAction(request: YieldXyzPerpsCreateActionRequest) async throws -> YieldXyzPerpsCreateActionResponse {
    createActionRequests.append(request)
    if let createActionError {
      try resolve(Swift.Result<Void, Error>.failure(createActionError))
    }
    return YieldXyzPerpsResponse(data: initial)
  }

  private func resolve<T>(_ result: Swift.Result<T, Error>) throws -> T {
    if case let .failure(error) = result, (error as? URLError)?.code == .cancelled, cancelsTaskOnCancelledRequest {
      withUnsafeCurrentTask { task in
        if let task {
          task.cancel()
        }
      }
    }
    return try result.get()
  }

  func getProviders() async throws -> YieldXyzPerpsGetProvidersResponse { YieldXyzPerpsResponse(data: []) }
  func getProvider(providerId _: String) async throws -> YieldXyzPerpsGetProviderResponse { YieldXyzPerpsResponse(data: .stub()) }
  func getMarkets(params _: YieldXyzPerpsGetMarketsParams) async throws -> YieldXyzPerpsGetMarketsResponse {
    YieldXyzPerpsResponse(data: YieldXyzPerpsPage(total: 0, offset: 0, limit: 25, items: []))
  }

  func getMarket(marketId _: String) async throws -> YieldXyzPerpsGetMarketResponse { YieldXyzPerpsResponse(data: .stub()) }
  func getMarketCandles(marketId _: String, params _: YieldXyzPerpsGetMarketCandlesParams) async throws -> YieldXyzPerpsGetMarketCandlesResponse {
    YieldXyzPerpsResponse(data: .stub())
  }

  func getPositions(request _: YieldXyzPerpsPortfolioRequest) async throws -> YieldXyzPerpsGetPositionsResponse { YieldXyzPerpsResponse(data: []) }
  func getOrders(request _: YieldXyzPerpsPortfolioRequest) async throws -> YieldXyzPerpsGetOrdersResponse { YieldXyzPerpsResponse(data: []) }
  func getBalances(request _: YieldXyzPerpsPortfolioRequest) async throws -> YieldXyzPerpsGetBalancesResponse { YieldXyzPerpsResponse(data: .stub()) }
  func getActions(request _: YieldXyzPerpsGetActionsRequest) async throws -> YieldXyzPerpsGetActionsResponse {
    YieldXyzPerpsResponse(data: YieldXyzPerpsPage(total: 0, offset: 0, limit: 25, items: []))
  }

  func getActivity(request _: YieldXyzPerpsGetActivityRequest) async throws -> YieldXyzPerpsGetActivityResponse {
    YieldXyzPerpsResponse(data: YieldXyzPerpsPage(total: 0, offset: 0, limit: 25, items: []))
  }

  func getEvents(request _: YieldXyzPerpsGetEventsRequest) async throws -> YieldXyzPerpsGetEventsResponse {
    YieldXyzPerpsResponse(data: YieldXyzPerpsPage(total: 0, offset: 0, limit: 25, items: []))
  }

  func getEvent(eventId _: String) async throws -> YieldXyzPerpsGetEventResponse { YieldXyzPerpsResponse(data: .stub()) }
  func getHealth() async throws -> YieldXyzPerpsGetHealthResponse { YieldXyzPerpsResponse(data: YieldXyzPerpsHealth(status: .ok, timestamp: "t")) }
  func getProvidersHealth() async throws -> YieldXyzPerpsGetProvidersHealthResponse {
    YieldXyzPerpsResponse(data: YieldXyzPerpsProvidersHealth(generatedAt: "t", providers: []))
  }
}

/// Records and scripts the signing dependencies.
final class PerpsSigners {
  var walletAddress: String? = YieldXyzPerpsFixtures.wallet
  var walletAddressError: Error?
  var signature: String? = YieldXyzPerpsFixtures.signature
  var signError: Error?
  /// Consumed one per send before `hash` applies.
  var scriptedSends: [Swift.Result<String?, Error>] = []
  var hash: String? = YieldXyzPerpsFixtures.fundingTxHash
  var confirmed = true
  var confirmError: Error?
  /// `nil` configures every chain.
  var configuredChains: Set<String>?
  /// Suspends the typed-data signer until `gate.release()` is called.
  var holdSigning = false
  let gate = SigningGate()
  let log: PerpsCallLog

  private(set) var typedDataRequests: [YieldXyzPerpsSignTypedDataRequest] = []
  private(set) var sends: [(param: ETHTransactionParam, chainId: String, idempotencyKey: String?)] = []
  private(set) var confirmations: [(hash: String, chainId: String)] = []

  init(log: PerpsCallLog) {
    self.log = log
  }

  var dependencies: YieldXyzPerpsExecutionDependencies {
    YieldXyzPerpsExecutionDependencies(
      getWalletAddress: { [self] in
        if let walletAddressError {
          throw walletAddressError
        }
        return walletAddress
      },
      signTypedData: { [self] request in try await signTypedData(request) },
      signAndSendTransaction: { [self] param, chainId, key in try await send(param, chainId, key) },
      waitForConfirmation: { [self] hash, chainId in try await confirm(hash, chainId) },
      isChainConfigured: { [self] chainId in configuredChains?.contains(chainId) ?? true }
    )
  }

  func signTypedData(_ request: YieldXyzPerpsSignTypedDataRequest) async throws -> String? {
    typedDataRequests.append(request)
    log.append("signTypedData")
    if holdSigning {
      await gate.enter()
    }
    if let signError {
      throw signError
    }
    return signature
  }

  func send(_ param: ETHTransactionParam, _ chainId: String, _ idempotencyKey: String?) async throws -> String? {
    sends.append((param, chainId, idempotencyKey))
    log.append("send")
    if !scriptedSends.isEmpty {
      return try scriptedSends.removeFirst().get()
    }
    return hash
  }

  func confirm(_ hash: String, _ chainId: String) async throws -> Bool {
    confirmations.append((hash, chainId))
    log.append("confirm")
    if let confirmError {
      throw confirmError
    }
    return confirmed
  }
}

/// Lets a test hold the signer inside a call: `enter()` (from the signer) suspends until
/// `release()`, and `waitUntilEntered()` (from the test) returns once the signer is inside.
final class SigningGate {
  private let lock = NSLock()
  private var entered = false
  private var released = false
  private var enterWaiters: [CheckedContinuation<Void, Never>] = []
  private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

  func enter() async {
    markEntered().forEach { $0.resume() }
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      if waitForRelease(continuation) {
        continuation.resume()
      }
    }
  }

  /// Records the entry and returns the waiters to wake; synchronous so the lock is never held
  /// across a suspension.
  private func markEntered() -> [CheckedContinuation<Void, Never>] {
    lock.lock()
    defer { lock.unlock() }
    entered = true
    let waiters = enterWaiters
    enterWaiters = []
    return waiters
  }

  /// Queues `continuation` until `release()`; `true` when the gate is already released.
  private func waitForRelease(_ continuation: CheckedContinuation<Void, Never>) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    if released {
      return true
    }
    releaseWaiters.append(continuation)
    return false
  }

  func waitUntilEntered() async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      lock.lock()
      if entered {
        lock.unlock()
        continuation.resume()
      } else {
        enterWaiters.append(continuation)
        lock.unlock()
      }
    }
  }

  func release() {
    lock.lock()
    released = true
    let waiters = releaseWaiters
    releaseWaiters = []
    lock.unlock()
    waiters.forEach { $0.resume() }
  }
}

extension YieldXyzPerpsTransaction {
  func with(status: YieldXyzPerpsTransactionStatus? = nil, signablePayload: AnyCodable?? = nil) -> YieldXyzPerpsTransaction {
    YieldXyzPerpsTransaction(
      id: id,
      network: network,
      chainId: chainId,
      type: type,
      status: status ?? self.status,
      address: address,
      args: args,
      signingFormat: signingFormat,
      signablePayload: signablePayload ?? self.signablePayload,
      rawPayload: rawPayload,
      error: error,
      explorerUrls: explorerUrls
    )
  }
}

extension YieldXyzPerpsAction {
  func with(status: YieldXyzPerpsActionStatus? = nil, transactions: [YieldXyzPerpsTransaction]? = nil) -> YieldXyzPerpsAction {
    YieldXyzPerpsAction(
      id: id,
      providerId: providerId,
      action: action,
      status: status ?? self.status,
      summary: summary,
      signedMetadata: signedMetadata,
      transactions: transactions ?? self.transactions,
      createdAt: createdAt,
      completedAt: completedAt
    )
  }
}

// MARK: - Tests

final class YieldXyzPerpsExecutionTests: XCTestCase {
  private typealias Fixtures = YieldXyzPerpsFixtures

  private var log: PerpsCallLog!
  private var backend: FakePerpsBackend!
  private var signers: PerpsSigners!
  private var perps: YieldXyzPerps!

  private let fastPolicy = YieldXyzPerpsRetryPolicy(
    rateLimitDelays: [0, 0, 0],
    idempotencyInProgressDelays: [0, 0, 0],
    minPollInterval: 0,
    maxPollInterval: 0.001,
    maxConsecutivePollErrors: 5
  )

  private func options(
    signingChainId: String = "eip155:42161",
    pollAction: Bool = true,
    timeoutSeconds: TimeInterval = 2,
    useIdempotencyKeys: Bool = true,
    broadcastHashes: [String: String] = [:],
    onProgress: ((YieldXyzPerpsExecutionProgress) -> Void)? = nil
  ) -> YieldXyzPerpsExecuteOptions {
    YieldXyzPerpsExecuteOptions(
      onProgress: onProgress,
      signingChainId: signingChainId,
      pollAction: pollAction,
      pollOptions: YieldXyzPerpsPollOptions(intervalSeconds: 0.001, timeoutSeconds: timeoutSeconds),
      useIdempotencyKeys: useIdempotencyKeys,
      broadcastHashes: broadcastHashes
    )
  }

  override func setUp() {
    super.setUp()
    resetDoubles()
  }

  private func resetDoubles() {
    log = PerpsCallLog()
    signers = PerpsSigners(log: log)
    setBackend(Fixtures.perpsAction())
  }

  override func tearDown() {
    log = nil
    backend = nil
    signers = nil
    perps = nil
    super.tearDown()
  }

  private func setBackend(_ action: YieldXyzPerpsAction) {
    backend = FakePerpsBackend(action, log: log)
    perps = YieldXyzPerps(api: backend, dependencies: signers.dependencies, retryPolicy: fastPolicy)
  }

  private func execute(_ action: YieldXyzPerpsAction? = nil, _ options: YieldXyzPerpsExecuteOptions? = nil) async throws -> YieldXyzPerpsExecutionResult {
    try await perps.signAndSubmitAction(action ?? backend.initial, options: options ?? self.options())
  }

  /// Runs the execution and returns the execution error it must fail with.
  private func expectFailure(
    _ reason: YieldXyzPerpsExecutionErrorReason,
    _ action: YieldXyzPerpsAction? = nil,
    _ options: YieldXyzPerpsExecuteOptions? = nil,
    file: StaticString = #filePath,
    line: UInt = #line
  ) async -> YieldXyzPerpsExecutionError? {
    do {
      _ = try await execute(action, options)
      XCTFail("Expected the execution to fail with \(reason.rawValue).", file: file, line: line)
      return nil
    } catch let error as YieldXyzPerpsExecutionError {
      XCTAssertEqual(error.reason, reason, error.message, file: file, line: line)
      return error
    } catch {
      XCTFail("Unexpected error \(error).", file: file, line: line)
      return nil
    }
  }

  private func backendError(_ status: Int, _ body: String = #"{"error":"failed"}"#) -> PortalRequestsError {
    status >= 500
      ? .internalServerError("\(status) - \(body)", url: "https://example.com")
      : .clientError("\(status) - \(body)", url: "https://example.com")
  }

  private func mpcError(_ id: String) -> PortalMpcError {
    PortalMpcError(PortalError(code: nil, id: id, message: "rejected"))
  }

  private func parsedTypedData(_ request: YieldXyzPerpsSignTypedDataRequest?) throws -> NSDictionary {
    let json = try XCTUnwrap(request?.typedData)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? NSDictionary)
  }

  // MARK: EIP712_TYPED_DATA

  func test_eip712_signsTheTypedDataJsonWithTheWallet_andSubmitsTheSignatureWithActionId() async throws {
    let result = try await execute()

    XCTAssertEqual(signers.typedDataRequests.count, 1)
    XCTAssertEqual(signers.typedDataRequests.first?.address, Fixtures.wallet)
    XCTAssertEqual(backend.submitted, [YieldXyzPerpsSubmitTransactionParams(
      transactionId: "tx-order-1",
      actionId: "act-1",
      signedPayload: Fixtures.signature
    )])
    XCTAssertEqual(result.status, .success)
    XCTAssertEqual(result.transactions, [YieldXyzPerpsTransactionExecution(
      transactionId: "tx-order-1",
      type: .openPosition,
      signingFormat: .eip712TypedData,
      signedPayload: Fixtures.signature,
      submitResult: Fixtures.submitResult()
    )])
  }

  func test_eip712_addsEip712Domain_andOtherwiseSendsThePayloadUnchanged() async throws {
    _ = try await execute()

    let typedData = try parsedTypedData(signers.typedDataRequests.first)
    let types = try XCTUnwrap(typedData["types"] as? NSDictionary)
    XCTAssertEqual((types["EIP712Domain"] as? [NSDictionary])?.count, 4)
    XCTAssertNotNil(types["Agent"])
    XCTAssertEqual((typedData["domain"] as? NSDictionary)?["chainId"] as? Int, 1337)
    XCTAssertEqual(typedData["primaryType"] as? String, "Agent")
  }

  func test_eip712_routesThroughArbitrum_neverTheSigningDomain() async throws {
    _ = try await execute()

    XCTAssertEqual(signers.typedDataRequests.first?.chainId, "eip155:42161")
  }

  func test_eip712_usesTheSigningChainIdOption() async throws {
    _ = try await execute(nil, options(signingChainId: "eip155:1"))

    XCTAssertEqual(signers.typedDataRequests.first?.chainId, "eip155:1")
  }

  func test_eip712_rejectsASigningChainWithoutAnRpcEndpoint_beforeSigning() async {
    signers.configuredChains = ["eip155:1"]

    let error = await expectFailure(.signingChainNotConfigured)

    XCTAssertEqual(error?.transactionId, "tx-order-1")
    XCTAssertTrue(signers.typedDataRequests.isEmpty)
    XCTAssertTrue(backend.submitted.isEmpty)
  }

  func test_eip712_rejectsANonEip155SigningChain() async {
    _ = await expectFailure(.signingChainNotConfigured, nil, options(signingChainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp"))

    XCTAssertTrue(signers.typedDataRequests.isEmpty)
  }

  func test_eip712_rejectsAJsonEncodedPayload() async {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.orderTransaction(signablePayload: AnyCodable(Fixtures.hyperliquidOrderTypedDataJSON))]))

    let error = await expectFailure(.invalidSignablePayload)

    XCTAssertEqual(error?.message, "The signablePayload of transaction tx-order-1 is not an EIP-712 typed data object.")
    XCTAssertTrue(signers.typedDataRequests.isEmpty)
  }

  func test_eip712_treatsANilSignatureAsARejection() async {
    signers.signature = nil

    _ = await expectFailure(.signatureRejected)

    XCTAssertTrue(backend.submitted.isEmpty)
  }

  func test_eip712_rejectsASignatureThatIsNot65Bytes() async {
    signers.signature = "0x1234"

    _ = await expectFailure(.invalidSignature)

    XCTAssertTrue(backend.submitted.isEmpty)
  }

  func test_eip712_acceptsASignatureWithoutThe0xPrefix() async throws {
    signers.signature = String(Fixtures.signature.dropFirst(2))

    _ = try await execute()

    XCTAssertEqual(backend.submitted.first?.signedPayload, Fixtures.signature)
  }

  func test_eip712_acceptsAnUppercase0XPrefix() async throws {
    signers.signature = "0X" + Fixtures.signature.dropFirst(2)

    _ = try await execute()

    XCTAssertEqual(backend.submitted.first?.signedPayload, Fixtures.signature)
  }

  func test_eip712_aCancelledSignerStopsWithCancellationError() async {
    signers.signError = CancellationError()

    do {
      _ = try await execute()
      XCTFail("Expected the execution to be cancelled.")
    } catch {
      XCTAssertTrue(error is CancellationError, "\(error)")
      XCTAssertTrue(backend.submitted.isEmpty)
    }
  }

  func test_eip712_wrapsASignerFailureWithTheIds() async {
    signers.signError = URLError(.notConnectedToInternet)

    let error = await expectFailure(.signingFailed)

    XCTAssertEqual(error?.actionId, "act-1")
    XCTAssertEqual(error?.transactionId, "tx-order-1")
    XCTAssertEqual(error?.underlyingError as? URLError, URLError(.notConnectedToInternet))
    XCTAssertNil(error?.broadcastHash)
  }

  // MARK: Signer address check

  func test_refusesToSignATransactionBuiltForAnotherAddress() async {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.orderTransaction(address: "0x000000000000000000000000000000000000dEaD")]))

    _ = await expectFailure(.signerAddressMismatch)

    XCTAssertTrue(signers.typedDataRequests.isEmpty)
  }

  func test_refusesToSendAnEvmLegWhosePayloadSendsFromAnotherAddress() async {
    let payload = Fixtures.fundingTransactionPayload(from: "0x000000000000000000000000000000000000dEaD")
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction(signablePayload: AnyCodable(payload))]))

    _ = await expectFailure(.signerAddressMismatch)

    XCTAssertTrue(signers.sends.isEmpty)
  }

  func test_comparesAddressesCaseInsensitively() async throws {
    signers.walletAddress = Fixtures.wallet.lowercased()

    let result = try await execute()

    XCTAssertEqual(result.status, .success)
  }

  func test_failsWhenNoWalletAddressIsAvailable() async {
    signers.walletAddress = nil

    let error = await expectFailure(.missingWalletAddress)

    XCTAssertEqual(error?.action?.id, "act-1")
    XCTAssertEqual(backend.getActionCallsCount, 0)
  }

  func test_wrapsAWalletAddressFailure() async {
    signers.walletAddressError = URLError(.cancelled)

    let error = await expectFailure(.missingWalletAddress)

    XCTAssertEqual(error?.underlyingError as? URLError, URLError(.cancelled))
  }

  // MARK: EVM_TRANSACTION

  func test_evm_sendsTheParsedTransactionOnItsChainWithAnIdempotencyKey_confirms_thenSubmitsTheHashWithoutActionId() async throws {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))

    let result = try await execute()

    let send = try XCTUnwrap(signers.sends.first)
    XCTAssertEqual(send.chainId, "eip155:42161")
    XCTAssertEqual(send.idempotencyKey, "yieldxyz-perps-tx-fund-1")
    XCTAssertEqual(send.param.from, Fixtures.wallet)
    XCTAssertEqual(send.param.to, Fixtures.arbitrumUsdc)
    XCTAssertEqual(send.param.data, Fixtures.fundingTransferData)
    XCTAssertEqual(send.param.value, "0x0")
    // The payload's gasLimit (0x186a0) is not sent: Portal's signer estimates the gas when it sends.
    XCTAssertNil(send.param.gas)
    XCTAssertNil(send.param.nonce)
    XCTAssertNil(send.param.maxFeePerGas)
    XCTAssertEqual(signers.confirmations.first?.hash, Fixtures.fundingTxHash)
    XCTAssertEqual(signers.confirmations.first?.chainId, "eip155:42161")
    XCTAssertEqual(backend.submitted, [YieldXyzPerpsSubmitTransactionParams(transactionId: "tx-fund-1", transactionHash: Fixtures.fundingTxHash)])
    XCTAssertEqual(result.transactions.first?.transactionHash, Fixtures.fundingTxHash)
    XCTAssertEqual(result.transactions.first?.signingFormat, .evmTransaction)
  }

  /// Perps sends the unsigned transaction as a JSON object today (Borrow documents a JSON string);
  /// both forms must send the same transaction.
  func test_evm_sendsAPayloadThatArrivesAsAnObject_likeOneThatArrivesAsAString() async throws {
    let objectPayload = Fixtures.decode(AnyCodable.self, Fixtures.fundingTransactionPayload())
    XCTAssertNotNil(objectPayload.value as? [String: Any])
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction(signablePayload: objectPayload)]))

    _ = try await execute()

    let send = try XCTUnwrap(signers.sends.first)
    XCTAssertEqual(send.param.from, Fixtures.wallet)
    XCTAssertEqual(send.param.to, Fixtures.arbitrumUsdc)
    XCTAssertEqual(send.param.data, Fixtures.fundingTransferData)
    XCTAssertEqual(send.param.value, "0x0")
    XCTAssertNil(send.param.gas)
    XCTAssertNil(send.param.nonce)
    XCTAssertEqual(backend.submitted.first?.transactionHash, Fixtures.fundingTxHash)
  }

  func test_evm_sendsWithoutAKeyWhenIdempotencyKeysAreOff() async throws {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))

    _ = try await execute(nil, options(useIdempotencyKeys: false))

    XCTAssertEqual(signers.sends.count, 1)
    XCTAssertNil(signers.sends.first?.idempotencyKey)
  }

  func test_evm_fallsBackToEip155ChainIdWhenNetworkIsNotCaip2() async throws {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction(network: "arbitrum", chainId: "42161")]))

    _ = try await execute()

    XCTAssertEqual(signers.sends.first?.chainId, "eip155:42161")
  }

  func test_evm_rejectsATransactionWithoutAnEvmChain() async {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction(network: "hyperliquid", chainId: "abc")]))

    _ = await expectFailure(.invalidSignablePayload)

    XCTAssertTrue(signers.sends.isEmpty)
  }

  func test_evm_doesNotSubmitWhenTheLegFailsToConfirm() async {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))
    signers.confirmed = false

    let error = await expectFailure(.transactionNotConfirmed)

    XCTAssertEqual(error?.broadcastHash, Fixtures.fundingTxHash)
    XCTAssertEqual(error?.transactionHash, Fixtures.fundingTxHash)
    XCTAssertTrue(backend.submitted.isEmpty)
  }

  func test_evm_wrapsAConfirmationFailure_keepingTheBroadcastHash() async {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))
    signers.confirmError = URLError(.timedOut)

    let error = await expectFailure(.transactionNotConfirmed)

    XCTAssertEqual(error?.broadcastHash, Fixtures.fundingTxHash)
    XCTAssertEqual(error?.underlyingError as? URLError, URLError(.timedOut))
  }

  func test_evm_cancellingTheConfirmationKeepsTheBroadcastHash_withoutReportingTheLegAsNotConfirmed() async {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))
    signers.confirmError = CancellationError()

    let error = await expectFailure(.submitOutcomeUnknown)

    XCTAssertEqual(error?.transactionId, "tx-fund-1")
    XCTAssertEqual(error?.broadcastHash, Fixtures.fundingTxHash)
    XCTAssertEqual(error?.transactionHash, Fixtures.fundingTxHash)
    XCTAssertTrue(error?.underlyingError is CancellationError)
    XCTAssertTrue(backend.submitted.isEmpty)
  }

  func test_evm_rejectsAnOpaqueHexPayload() async {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction(signablePayload: AnyCodable("0xdeadbeef"))]))

    _ = await expectFailure(.invalidSignablePayload)

    XCTAssertTrue(signers.sends.isEmpty)
  }

  func test_evm_treatsANilHashAsARejection() async {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))
    signers.hash = nil

    _ = await expectFailure(.signatureRejected)

    XCTAssertTrue(signers.confirmations.isEmpty)
  }

  func test_evm_rejectsAValueThatIsNotATransactionHash() async {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))
    signers.hash = "0x1234"

    _ = await expectFailure(.invalidSignature)

    XCTAssertTrue(signers.confirmations.isEmpty)
  }

  // MARK: Idempotency keys

  func test_idempotency_retriesASendPortalReportsInProgress_withTheSameKey() async throws {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))
    signers.scriptedSends = [
      .failure(mpcError(PortalIdempotencyErrorId.requestInProgress)),
      .success(Fixtures.fundingTxHash)
    ]

    let result = try await execute()

    XCTAssertEqual(signers.sends.map(\.idempotencyKey), ["yieldxyz-perps-tx-fund-1", "yieldxyz-perps-tx-fund-1"])
    XCTAssertEqual(result.transactions.first?.transactionHash, Fixtures.fundingTxHash)
  }

  func test_idempotency_givesUpOnASendThatStaysInProgress_withoutClaimingNothingWasSent() async {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))
    signers.scriptedSends = Array(repeating: .failure(mpcError(PortalIdempotencyErrorId.requestInProgress)), count: 4)

    let error = await expectFailure(.broadcastOutcomeUnknown)

    XCTAssertEqual(signers.sends.count, 4)
    XCTAssertEqual((error?.underlyingError as? PortalMpcError)?.id, PortalIdempotencyErrorId.requestInProgress)
    XCTAssertTrue(backend.submitted.isEmpty)
  }

  func test_idempotency_stopsWhenPortalReportsTheLegAlreadyBroadcast() async {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))
    signers.scriptedSends = [.failure(mpcError(PortalIdempotencyErrorId.requestAlreadyCompleted))]

    let error = await expectFailure(.transactionAlreadyBroadcast)

    XCTAssertEqual(error?.transactionId, "tx-fund-1")
    XCTAssertNil(error?.broadcastHash)
    XCTAssertEqual(signers.sends.count, 1)
    XCTAssertTrue(signers.confirmations.isEmpty)
    XCTAssertTrue(backend.submitted.isEmpty)
  }

  func test_idempotency_reportsAnUncertainRejectionAsBroadcastOutcomeUnknown_namingTheId() async {
    let uncertain = [
      PortalIdempotencyErrorId.requestPreviouslyFailed,
      PortalIdempotencyErrorId.requestUnexpectedState,
      PortalIdempotencyErrorId.txMissing,
      PortalIdempotencyErrorId.keyReused
    ]
    for id in uncertain {
      resetDoubles()
      setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))
      signers.scriptedSends = [.failure(mpcError(id))]

      let error = await expectFailure(.broadcastOutcomeUnknown)

      XCTAssertEqual((error?.underlyingError as? PortalMpcError)?.id, id)
      XCTAssertTrue(error?.message.contains(id) == true, error?.message ?? "")
      // The message names both ways forward: resuming from a broadcast hash, or sending the leg anew.
      XCTAssertTrue(error?.message.contains("broadcastHashes") == true, error?.message ?? "")
      XCTAssertTrue(error?.message.contains("useIdempotencyKeys set to false") == true, error?.message ?? "")
      XCTAssertEqual(signers.sends.count, 1, id)
      XCTAssertTrue(backend.submitted.isEmpty, id)
    }
  }

  func test_idempotency_stopsWhenARetriedSendTurnsOutAlreadyBroadcast() async {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))
    signers.scriptedSends = [
      .failure(mpcError(PortalIdempotencyErrorId.requestInProgress)),
      .failure(mpcError(PortalIdempotencyErrorId.requestAlreadyCompleted))
    ]

    _ = await expectFailure(.transactionAlreadyBroadcast)

    XCTAssertEqual(signers.sends.count, 2)
    XCTAssertTrue(backend.submitted.isEmpty)
  }

  func test_idempotency_reportsSigningOnceAcrossRetries() async throws {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))
    signers.scriptedSends = [
      .failure(mpcError(PortalIdempotencyErrorId.requestInProgress)),
      .failure(mpcError(PortalIdempotencyErrorId.requestInProgress)),
      .success(Fixtures.fundingTxHash)
    ]
    var steps: [YieldXyzPerpsExecutionStep] = []

    _ = try await execute(nil, options(onProgress: { steps.append($0.step) }))

    XCTAssertEqual(steps.filter { $0 == .signing }.count, 1)
    XCTAssertEqual(signers.sends.count, 3)
  }

  func test_idempotency_doesNotRetryWithoutAKey() async {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))
    signers.scriptedSends = [.failure(mpcError(PortalIdempotencyErrorId.requestInProgress))]

    _ = await expectFailure(.broadcastOutcomeUnknown, nil, options(useIdempotencyKeys: false))

    XCTAssertEqual(signers.sends.count, 1)
  }

  // MARK: Send failures

  /// An RPC send that times out after the node accepted the transaction, or a connection dropped
  /// after the broadcast, may have put the leg on-chain: a new action would send it again.
  func test_evmSend_aFailureThatMayComeAfterTheBroadcast_isBroadcastOutcomeUnknown() async {
    let failures: [Error] = [mpcError("RPC_OP_FAILED"), URLError(.networkConnectionLost)]
    for failure in failures {
      resetDoubles()
      setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))
      signers.scriptedSends = [.failure(failure)]

      let error = await expectFailure(.broadcastOutcomeUnknown)

      XCTAssertEqual(error?.transactionId, "tx-fund-1")
      XCTAssertNil(error?.broadcastHash)
      XCTAssertTrue(error?.message.contains("broadcastHashes") == true, error?.message ?? "")
      XCTAssertTrue(error?.message.contains("idempotency key") == true, error?.message ?? "")
      XCTAssertEqual(signers.sends.count, 1)
      XCTAssertTrue(signers.confirmations.isEmpty)
      XCTAssertTrue(backend.submitted.isEmpty)
    }
  }

  func test_evmSend_withoutAKey_doesNotPromiseThatResumingIsProtected() async {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))
    signers.scriptedSends = [.failure(mpcError("RPC_OP_FAILED"))]

    let error = await expectFailure(.broadcastOutcomeUnknown, nil, options(useIdempotencyKeys: false))

    XCTAssertFalse(error?.message.contains("idempotency key") == true, error?.message ?? "")
  }

  /// Failures known to happen before anything reaches the chain stay `signingFailed`.
  func test_evmSend_aFailureBeforeTheBroadcast_isSigningFailed() async {
    let failures: [Error] = [
      "MSG_BUILD_FAILED",
      "TX_BUILD_FAILED",
      "BAD_REQUEST",
      "ADDRESS_BLOCKED",
      "POLICY_AMOUNT_LIMIT_EXCEEDED",
      "INSUFFICIENT_FUNDS",
      "AUTH_FAILED"
    ].map { self.mpcError($0) as Error } + [
      PortalIdempotencyError.invalidKey("too long"),
      PortalCredentialError.sessionInvalidated,
      ProviderSigningError.userDeclinedApproval
    ]
    XCTAssertEqual(failures.count, 10)
    for failure in failures {
      resetDoubles()
      setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))
      signers.scriptedSends = [.failure(failure)]

      let error = await expectFailure(.signingFailed)

      XCTAssertEqual(error?.transactionId, "tx-fund-1", "\(failure)")
      XCTAssertEqual(signers.sends.count, 1, "\(failure)")
      XCTAssertTrue(backend.submitted.isEmpty, "\(failure)")
    }
  }

  func test_idempotency_sendsWithoutAKeyWhenTheTransactionIdCannotFormOne() async throws {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction(id: "tx/fund")]))

    _ = try await execute()

    XCTAssertEqual(signers.sends.count, 1)
    XCTAssertNil(signers.sends.first?.idempotencyKey)
  }

  // MARK: Sequencing

  func test_processesMixedLegsStrictlyInOrder() async throws {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction(), Fixtures.orderTransaction()]))

    let result = try await execute()

    XCTAssertEqual(log.entries.filter { $0 != "read" }, ["send", "confirm", "submit:tx-fund-1", "signTypedData", "submit:tx-order-1"])
    XCTAssertEqual(result.transactions.map(\.transactionId), ["tx-fund-1", "tx-order-1"])
  }

  func test_stopsAtTheFirstFailure_withoutTouchingLaterTransactions() async {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction(), Fixtures.orderTransaction()]))
    signers.confirmed = false

    _ = await expectFailure(.transactionNotConfirmed)

    XCTAssertTrue(signers.typedDataRequests.isEmpty)
    XCTAssertTrue(backend.submitted.isEmpty)
  }

  func test_rejectsUnsupportedSigningFormats() async {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.orderTransaction(signingFormat: .solanaTransaction)]))

    let error = await expectFailure(.unsupportedSigningFormat)

    XCTAssertEqual(error?.message, "Transaction tx-order-1 uses signing format \"SOLANA_TRANSACTION\", which is not supported.")
  }

  func test_rejectsAMissingSigningFormat() async {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.orderTransaction(signingFormat: nil)]))

    let error = await expectFailure(.unsupportedSigningFormat)

    XCTAssertEqual(error?.message, "Transaction tx-order-1 uses signing format \"none\", which is not supported.")
  }

  func test_signsOnlyTheCreatedTransactionWhenAnotherIsAlreadyQueued() async throws {
    setBackend(Fixtures.perpsAction(transactions: [
      Fixtures.fundingTransaction(status: .queued),
      Fixtures.orderTransaction()
    ]))
    backend.statuses["tx-fund-1"] = .confirmed

    let result = try await execute()

    XCTAssertTrue(signers.sends.isEmpty)
    XCTAssertEqual(result.transactions.map(\.transactionId), ["tx-order-1"])
  }

  // MARK: Action lifecycle

  func test_signsTransactionsAddedWhileWaitingForNext() async throws {
    let first = Fixtures.fundingTransaction()
    let added = Fixtures.orderTransaction()
    // Yield.xyz lists `added` only once the first leg is recorded.
    setBackend(Fixtures.perpsAction(transactions: [first, added]))
    let waiting = Fixtures.perpsAction(status: .waitingForNext, transactions: [first.with(status: .queued)])
    backend.scriptedReads = [
      .success(Fixtures.perpsAction(transactions: [first])),
      .success(waiting),
      .success(waiting.with(transactions: [first.with(status: .confirmed), added]))
    ]

    let result = try await execute(Fixtures.perpsAction(transactions: [first]))

    XCTAssertEqual(result.transactions.map(\.transactionId), ["tx-fund-1", "tx-order-1"])
    XCTAssertEqual(result.status, .success)
  }

  func test_keepsPollingWhileTheActionIsProcessing() async throws {
    let processing = Fixtures.perpsAction(status: .processing, transactions: [Fixtures.orderTransaction(status: .queued)])
    backend.scriptedReads = [.success(Fixtures.perpsAction()), .success(processing), .success(processing)]

    let result = try await execute()

    XCTAssertEqual(result.status, .success)
    XCTAssertEqual(backend.getActionCallsCount, 4)
  }

  func test_failsWhenTheActionEnds_failed_canceled_orStale() async {
    for status in [YieldXyzPerpsActionStatus.failed, .canceled, .stale] {
      resetDoubles()
      backend.scriptedReads = [.success(Fixtures.perpsAction()), .success(Fixtures.perpsAction(status: status))]

      let error = await expectFailure(.actionFailed)

      XCTAssertEqual(error?.action?.status, status)
    }
  }

  func test_timesOutWhenTheActionNeverReachesAFinalStatus() async {
    setBackend(Fixtures.perpsAction(status: .processing, transactions: [Fixtures.orderTransaction(status: .queued)]))

    let error = await expectFailure(.timeout, Fixtures.perpsAction(), options(timeoutSeconds: 0.05))

    XCTAssertEqual(error?.action?.status, .processing)
  }

  func test_onlyReadsTheActionBeforeSigningWhenPollActionIsFalse() async throws {
    let result = try await execute(nil, options(pollAction: false))

    XCTAssertEqual(backend.getActionCallsCount, 1)
    XCTAssertEqual(result.status, .created)
    XCTAssertEqual(result.transactions.count, 1)
  }

  func test_returnsImmediatelyForAnActionThatAlreadySucceeded() async throws {
    let succeeded = Fixtures.perpsAction(status: .success, transactions: [Fixtures.orderTransaction(status: .confirmed)])

    let result = try await execute(succeeded)

    XCTAssertEqual(result.status, .success)
    XCTAssertTrue(result.transactions.isEmpty)
    XCTAssertEqual(backend.getActionCallsCount, 0)
  }

  func test_toleratesTransientReadFailures() async throws {
    backend.scriptedReads = [.failure(backendError(503)), .failure(backendError(429)), .failure(URLError(.networkConnectionLost))]

    let result = try await execute()

    XCTAssertEqual(result.status, .success)
  }

  func test_failsPollingOnATerminalReadError() async {
    backend.scriptedReads = [.failure(backendError(400))]

    let error = await expectFailure(.pollingFailed)

    XCTAssertTrue(signers.typedDataRequests.isEmpty)
    XCTAssertEqual(YieldXyzPerpsApiError.from(error)?.status, 400)
  }

  func test_failsPollingAfterRepeatedTransientFailures() async {
    backend.scriptedReads = Array(repeating: .failure(backendError(503)), count: 5)

    _ = await expectFailure(.pollingFailed)

    XCTAssertEqual(backend.getActionCallsCount, 5)
  }

  func test_doesNotRetryAReadThatFailedOnTheCredential() async {
    backend.scriptedReads = [.failure(PortalRequestsError.unauthorized)]

    _ = await expectFailure(.pollingFailed)

    XCTAssertEqual(backend.getActionCallsCount, 1)
  }

  // MARK: Submission outcomes

  func test_submit_treatsAFailedStatusAsAFailure() async {
    backend.scriptedSubmits = [.success(Fixtures.submitResult(.failed, error: "Order rejected"))]

    let error = await expectFailure(.submitFailed)

    XCTAssertEqual(error?.message, "Yield.xyz reported transaction tx-order-1 as FAILED: Order rejected.")
  }

  func test_submit_doesNotRetryA400() async {
    backend.scriptedSubmits = [.failure(backendError(400, #"{"error":"Yield.xyz Perps precondition failed","details":{"code":"EXECUTE_PRECONDITION_FAILED"}}"#))]

    let error = await expectFailure(.submitRejected)

    XCTAssertEqual(backend.submitted.count, 1)
    XCTAssertEqual(YieldXyzPerpsApiError.from(error)?.details?["code"], AnyCodable("EXECUTE_PRECONDITION_FAILED"))
    XCTAssertEqual(YieldXyzPerpsApiError.from(error)?.code, "EXECUTE_PRECONDITION_FAILED")
  }

  func test_submit_surfacesASignatureVerificationRejection() async {
    backend.scriptedSubmits = [.failure(backendError(400, #"{"error":"Signature recovered to 0x1","id":"PERPS_SIGNATURE_ADDRESS_MISMATCH","details":{"recovered":"0x1","expected":"0x2"}}"#))]

    let error = await expectFailure(.submitRejected)

    XCTAssertEqual(YieldXyzPerpsApiError.from(error)?.isSignatureError, true)
  }

  func test_submit_doesNotReconcileAFailureOnTheCredential() async {
    backend.scriptedSubmits = [.failure(PortalRequestsError.unauthorized)]

    _ = await expectFailure(.submitRejected)

    XCTAssertEqual(backend.getActionCallsCount, 1)
  }

  func test_submit_retriesTheSamePayloadAfterA429() async throws {
    backend.scriptedSubmits = [.failure(backendError(429))]

    _ = try await execute()

    XCTAssertEqual(backend.submitted.count, 2)
    XCTAssertEqual(backend.submitted[0], backend.submitted[1])
  }

  func test_submit_givesUpWithTheRateLimitErrorAfterRepeated429s() async {
    backend.scriptedSubmits = Array(repeating: .failure(backendError(429)), count: 4)

    let error = await expectFailure(.submitRejected)

    XCTAssertEqual(backend.submitted.count, 4)
    XCTAssertEqual(YieldXyzPerpsApiError.from(error)?.isRateLimit, true)
  }

  func test_submit_reconcilesAnAmbiguousSignatureSubmission_withoutResubmittingOnceRecorded() async throws {
    backend.scriptedSubmits = [.failure(backendError(503))]
    // The submission went through: once read back, the leg is recorded and the action succeeds.
    backend.statuses["tx-order-1"] = .confirmed
    let recorded = Fixtures.perpsAction(transactions: [Fixtures.orderTransaction(status: .queued)])
    backend.scriptedReads = [.success(Fixtures.perpsAction()), .success(recorded)]

    let result = try await execute()

    XCTAssertEqual(backend.submitted.count, 1)
    XCTAssertNil(result.transactions.first?.submitResult)
    XCTAssertEqual(result.transactions.first?.signedPayload, Fixtures.signature)
  }

  func test_submit_neverResubmitsASignatureWhoseOutcomeIsUnknown() async {
    backend.scriptedSubmits = [.failure(backendError(503))]

    _ = await expectFailure(.submitOutcomeUnknown)

    XCTAssertEqual(backend.submitted.count, 1)
  }

  func test_submit_resubmitsATransactionHashOnceTheActionShowsItWasNotRecorded() async throws {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))
    backend.scriptedSubmits = [.failure(URLError(.networkConnectionLost))]

    _ = try await execute()

    XCTAssertEqual(backend.submitted.map(\.transactionHash), [Fixtures.fundingTxHash, Fixtures.fundingTxHash])
    XCTAssertEqual(signers.sends.count, 1)
  }

  func test_submit_resubmitsAHashOnlyOnce() async {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))
    backend.scriptedSubmits = [.failure(backendError(503)), .failure(backendError(503))]

    let error = await expectFailure(.submitOutcomeUnknown)

    XCTAssertEqual(backend.submitted.count, 2)
    XCTAssertEqual(error?.broadcastHash, Fixtures.fundingTxHash)
  }

  func test_submit_treatsAMalformedResponseAsAmbiguous() async {
    backend.scriptedSubmits = [.failure(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "bad body")))]

    _ = await expectFailure(.submitOutcomeUnknown)

    XCTAssertEqual(backend.getActionCallsCount, 2)
  }

  func test_submit_reportsSubmitFailedWhenReconciliationShowsTheTransactionFailed() async {
    backend.scriptedSubmits = [.failure(backendError(503))]
    backend.scriptedReads = [.success(Fixtures.perpsAction()), .success(Fixtures.perpsAction(transactions: [Fixtures.orderTransaction(status: .failed)]))]

    _ = await expectFailure(.submitFailed)
  }

  func test_submit_reportsActionFailedWhenTheActionEndedBeforeRecordingTheLeg_keepingTheHash() async {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))
    backend.scriptedSubmits = [.failure(backendError(503))]
    backend.scriptedReads = [.success(backend.initial), .success(Fixtures.perpsAction(status: .stale, transactions: [Fixtures.fundingTransaction()]))]

    let error = await expectFailure(.actionFailed)

    XCTAssertEqual(error?.broadcastHash, Fixtures.fundingTxHash)
    XCTAssertEqual(backend.submitted.count, 1)
  }

  func test_submit_reportsOutcomeUnknownWhenTheActionCannotBeReadBack() async {
    backend.scriptedSubmits = [.failure(backendError(503))]
    backend.scriptedReads = [.success(Fixtures.perpsAction()), .failure(backendError(503))]

    _ = await expectFailure(.submitOutcomeUnknown)
  }

  // MARK: executeAction

  func test_executeAction_createsTheActionForTheWallet_withVerbatimArgs_thenExecutesIt() async throws {
    let args = YieldXyzPerpsActionArgs(marketId: "hyperliquid-eth-usdc", side: .long, size: "1000", leverage: 10, marginMode: .isolated)

    let result = try await perps.executeAction(
      params: YieldXyzPerpsCreateActionParams(providerId: "hyperliquid", action: .open, args: args),
      options: options()
    )

    XCTAssertEqual(backend.createActionRequests, [YieldXyzPerpsCreateActionRequest(providerId: "hyperliquid", address: Fixtures.wallet, action: .open, args: args)])
    XCTAssertEqual(result.status, .success)
  }

  func test_executeAction_surfacesACreationFailureUnchanged() async {
    backend.createActionError = backendError(400, #"{"error":"Perps on Hyperliquid require a non-account-abstracted client","id":"INTEGRATION_REQUIRES_EOA_CLIENT"}"#)

    do {
      _ = try await perps.executeAction(
        params: YieldXyzPerpsCreateActionParams(providerId: "hyperliquid", action: .open, args: YieldXyzPerpsActionArgs()),
        options: options()
      )
      XCTFail("Expected error not thrown.")
    } catch {
      XCTAssertTrue(error is PortalRequestsError)
      XCTAssertEqual(YieldXyzPerpsApiError.from(error)?.isEoaRequired, true)
      XCTAssertTrue(signers.typedDataRequests.isEmpty)
    }
  }

  // MARK: Progress

  func test_progress_reportsEachStep() async throws {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction(), Fixtures.orderTransaction()]))
    var events: [YieldXyzPerpsExecutionProgress] = []

    _ = try await execute(nil, options(onProgress: { events.append($0) }))

    XCTAssertEqual(events.map(\.step), [.polling, .signing, .confirming, .confirmed, .submitted, .polling, .signing, .submitted, .polling])
    XCTAssertEqual(events.map(\.transactionId), [nil, "tx-fund-1", "tx-fund-1", "tx-fund-1", "tx-fund-1", nil, "tx-order-1", "tx-order-1", nil])
    XCTAssertEqual(events[2].transactionHash, Fixtures.fundingTxHash)
    XCTAssertEqual(events[6].index, 1)
    XCTAssertEqual(events.last?.actionStatus, .success)
    XCTAssertTrue(events.allSatisfy { $0.actionId == "act-1" })
  }

  func test_progress_reportsAFailedStepWithTheError() async {
    signers.signature = nil
    var events: [YieldXyzPerpsExecutionProgress] = []

    _ = await expectFailure(.signatureRejected, nil, options(onProgress: { events.append($0) }))

    XCTAssertEqual(events.last?.step, .failed)
    XCTAssertEqual(events.last?.transactionId, "tx-order-1")
    XCTAssertEqual(events.last?.error?.reason, .signatureRejected)
  }

  // MARK: Concurrent calls

  func test_rejectsASecondCallOnAnActionThatIsStillExecuting() async throws {
    signers.holdSigning = true
    let perps = self.perps!
    let action = backend.initial
    let fastOptions = options()

    let first = Task { try await perps.signAndSubmitAction(action, options: fastOptions) }
    await signers.gate.waitUntilEntered()

    _ = await expectFailure(.actionInProgress)
    XCTAssertEqual(signers.typedDataRequests.count, 1)

    signers.gate.release()
    let result = try await first.value
    XCTAssertEqual(result.status, .success)
  }

  func test_rejectsASecondCallFromAnotherInstanceSharingTheGuard() async throws {
    signers.holdSigning = true
    let guardShared = YieldXyzPerpsInFlightActions()
    let first = YieldXyzPerps(api: backend, dependencies: signers.dependencies, retryPolicy: fastPolicy, inFlightActions: guardShared)
    let second = YieldXyzPerps(api: backend, dependencies: signers.dependencies, retryPolicy: fastPolicy, inFlightActions: guardShared)
    let action = backend.initial
    let fastOptions = options()

    let running = Task { try await first.signAndSubmitAction(action, options: fastOptions) }
    await signers.gate.waitUntilEntered()

    do {
      _ = try await second.signAndSubmitAction(action, options: fastOptions)
      XCTFail("Expected the second instance to refuse the action.")
    } catch let error as YieldXyzPerpsExecutionError {
      XCTAssertEqual(error.reason, .actionInProgress)
    }
    XCTAssertEqual(signers.typedDataRequests.count, 1)

    signers.gate.release()
    let result = try await running.value
    XCTAssertEqual(result.status, .success)
  }

  func test_acceptsANewCallOnceTheEarlierOneFailed() async throws {
    signers.signature = nil
    _ = await expectFailure(.signatureRejected)

    signers.signature = Fixtures.signature
    let result = try await execute()

    XCTAssertEqual(result.status, .success)
  }

  // MARK: Per-call overrides

  func test_prefersPerCallSigners() async throws {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction(), Fixtures.orderTransaction()]))
    let overrideHash = "0x" + String(repeating: "ab", count: 32)
    var custom = options()
    custom.signTypedData = { _ in YieldXyzPerpsFixtures.signature }
    custom.signAndSendTransaction = { _, _, _ in overrideHash }
    custom.waitForConfirmation = { _, _ in true }

    let result = try await execute(nil, custom)

    XCTAssertTrue(signers.typedDataRequests.isEmpty)
    XCTAssertTrue(signers.sends.isEmpty)
    XCTAssertTrue(signers.confirmations.isEmpty)
    XCTAssertEqual(result.transactions.first?.transactionHash, overrideHash)
  }

  func test_failsClearlyWithoutASigner() async {
    perps = YieldXyzPerps(
      api: backend,
      dependencies: YieldXyzPerpsExecutionDependencies(getWalletAddress: { YieldXyzPerpsFixtures.wallet }),
      retryPolicy: fastPolicy
    )

    let error = await expectFailure(.dependencyUnavailable)

    XCTAssertEqual(error?.message, "No typed-data signer is configured.")
  }

  func test_failsClearlyWithoutATransactionSignerAndWaiter() async {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))
    perps = YieldXyzPerps(
      api: backend,
      dependencies: YieldXyzPerpsExecutionDependencies(getWalletAddress: { YieldXyzPerpsFixtures.wallet }),
      retryPolicy: fastPolicy
    )

    let error = await expectFailure(.dependencyUnavailable)

    XCTAssertEqual(error?.message, "No transaction signer and confirmation waiter are configured.")
  }

  // MARK: Reading the action back before signing

  func test_readsTheActionAgainBeforeEachTransactionIsSigned() async throws {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction(), Fixtures.orderTransaction()]))

    _ = try await execute()

    XCTAssertEqual(Array(log.entries.prefix(5)), ["read", "send", "confirm", "submit:tx-fund-1", "read"])
  }

  func test_signsNothingOnceYieldXyzReportsTheActionAsFailed() async {
    backend.scriptedReads = [.success(Fixtures.perpsAction(status: .failed))]

    _ = await expectFailure(.actionFailed)

    XCTAssertTrue(signers.typedDataRequests.isEmpty)
    XCTAssertEqual(backend.getActionCallsCount, 1)
  }

  func test_skipsATransactionYieldXyzNoLongerLists() async throws {
    // Yield.xyz lists only the order now, though the action passed in also lists the funding leg.
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.orderTransaction()]))

    let result = try await execute(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction(), Fixtures.orderTransaction()]))

    XCTAssertTrue(signers.sends.isEmpty)
    XCTAssertEqual(result.transactions.map(\.transactionId), ["tx-order-1"])
  }

  func test_skipsATransactionYieldXyzNowReportsAsRecorded() async throws {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction(), Fixtures.orderTransaction()]))
    backend.statuses["tx-fund-1"] = .broadcasted

    let result = try await execute()

    XCTAssertTrue(signers.sends.isEmpty)
    XCTAssertEqual(result.transactions.map(\.transactionId), ["tx-order-1"])
  }

  func test_signsTheTypedDataYieldXyzListsNow() async throws {
    let current = Fixtures.decode(AnyCodable.self, Fixtures.hyperliquidOrderTypedDataJSON.replacingOccurrences(of: "\"source\": \"a\"", with: "\"source\": \"b\""))
    backend.scriptedReads = [.success(Fixtures.perpsAction(transactions: [Fixtures.orderTransaction(signablePayload: current)]))]

    _ = try await execute()

    let message = try parsedTypedData(signers.typedDataRequests.first)["message"] as? NSDictionary
    XCTAssertEqual(message?["source"] as? String, "b")
  }

  // MARK: Resuming a broadcast EVM_TRANSACTION

  func test_resume_confirmsAndSubmitsTheSuppliedHashWithoutSigning() async throws {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))

    let result = try await execute(nil, options(broadcastHashes: ["tx-fund-1": Fixtures.fundingTxHash]))

    XCTAssertTrue(signers.sends.isEmpty)
    XCTAssertEqual(signers.confirmations.first?.hash, Fixtures.fundingTxHash)
    XCTAssertEqual(backend.submitted.first?.transactionHash, Fixtures.fundingTxHash)
    XCTAssertEqual(result.transactions.first?.transactionHash, Fixtures.fundingTxHash)
  }

  func test_resume_broadcastsTheLegOnceAcrossAFailedConfirmationAndAResume() async throws {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))
    signers.confirmed = false
    let failure = await expectFailure(.transactionNotConfirmed)
    let broadcastHash = try XCTUnwrap(failure?.broadcastHash)

    signers.confirmed = true
    _ = try await execute(failure?.action, options(broadcastHashes: ["tx-fund-1": broadcastHash]))

    XCTAssertEqual(signers.sends.count, 1)
    XCTAssertEqual(backend.submitted.map(\.transactionHash), [broadcastHash])
  }

  func test_resume_worksWithoutATransactionSignerConfigured() async throws {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))
    perps = YieldXyzPerps(
      api: backend,
      dependencies: YieldXyzPerpsExecutionDependencies(
        getWalletAddress: { YieldXyzPerpsFixtures.wallet },
        waitForConfirmation: { _, _ in true }
      ),
      retryPolicy: fastPolicy
    )

    let result = try await execute(nil, options(broadcastHashes: ["tx-fund-1": Fixtures.fundingTxHash]))

    XCTAssertEqual(result.status, .success)
  }

  func test_resume_rejectsASuppliedValueThatIsNotATransactionHash() async {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))

    _ = await expectFailure(.invalidSignature, nil, options(broadcastHashes: ["tx-fund-1": "0x1234"]))

    XCTAssertTrue(signers.sends.isEmpty)
  }

  func test_resume_reportsTheBroadcastHashWhenTheSubmissionIsRejected() async {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))
    backend.scriptedSubmits = [.failure(backendError(400))]

    let error = await expectFailure(.submitRejected)

    XCTAssertEqual(error?.broadcastHash, Fixtures.fundingTxHash)
  }

  func test_errorsCarryTheLatestActionReadBack() async {
    let latest = Fixtures.perpsAction(status: .processing)
    backend.scriptedReads = [.success(latest)]
    signers.signature = nil

    let error = await expectFailure(.signatureRejected)

    XCTAssertEqual(error?.action?.status, .processing)
  }

  func test_resume_cancellingTheHashSubmissionKeepsTheBroadcastHash() async {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))
    backend.scriptedSubmits = [.failure(CancellationError())]

    let error = await expectFailure(.submitOutcomeUnknown)

    XCTAssertEqual(error?.broadcastHash, Fixtures.fundingTxHash)
    XCTAssertTrue(error?.underlyingError is CancellationError)
  }

  // MARK: Cancellation

  func test_cancellingTheTaskWhilePolling_stopsWithCancellationError() async {
    setBackend(Fixtures.perpsAction(status: .processing, transactions: [Fixtures.orderTransaction(status: .queued)]))
    let perps = self.perps!
    let action = Fixtures.perpsAction()
    let slowOptions = options(timeoutSeconds: 30)

    let task = Task { try await perps.signAndSubmitAction(action, options: slowOptions) }
    try? await Task.sleep(nanoseconds: 50_000_000)
    task.cancel()

    do {
      _ = try await task.value
      XCTFail("Expected the execution to be cancelled.")
    } catch {
      XCTAssertTrue(error is CancellationError, "\(error)")
    }
  }

  // MARK: Cancellation as URLSession reports it

  /// Runs the execution in its own task, which a scripted `URLError(.cancelled)` cancels, and
  /// returns the error it ends with.
  private func executionErrorInOwnTask(_ action: YieldXyzPerpsAction? = nil) async -> Error? {
    let perps = self.perps!
    let action = action ?? backend.initial
    let fastOptions = options()
    let task = Task { try await perps.signAndSubmitAction(action, options: fastOptions) }
    do {
      _ = try await task.value
      return nil
    } catch {
      return error
    }
  }

  func test_urlSessionCancellation_ofASignatureSubmit_stopsWithCancellationError() async {
    backend.scriptedSubmits = [.failure(URLError(.cancelled))]

    let error = await executionErrorInOwnTask()

    XCTAssertTrue(error is CancellationError, "\(String(describing: error))")
    XCTAssertEqual(backend.submitted.count, 1)
    // Stopped at once: no read-back to reconcile the submission.
    XCTAssertEqual(backend.getActionCallsCount, 1)
  }

  func test_urlSessionCancellation_ofAHashSubmit_keepsTheBroadcastHash() async {
    setBackend(Fixtures.perpsAction(transactions: [Fixtures.fundingTransaction()]))
    backend.scriptedSubmits = [.failure(URLError(.cancelled))]

    let error = await executionErrorInOwnTask() as? YieldXyzPerpsExecutionError

    XCTAssertEqual(error?.reason, .submitOutcomeUnknown)
    XCTAssertEqual(error?.broadcastHash, Fixtures.fundingTxHash)
    XCTAssertTrue(error?.underlyingError is CancellationError)
  }

  func test_urlSessionCancellation_ofARead_stopsWithCancellationError() async {
    backend.scriptedReads = [.failure(URLError(.cancelled))]

    let error = await executionErrorInOwnTask()

    XCTAssertTrue(error is CancellationError, "\(String(describing: error))")
    XCTAssertTrue(signers.typedDataRequests.isEmpty)
  }

  func test_urlSessionCancellation_ofCreateAction_stopsWithCancellationError() async {
    backend.createActionError = URLError(.cancelled)
    let perps = self.perps!
    let params = YieldXyzPerpsCreateActionParams(providerId: "hyperliquid", action: .open, args: YieldXyzPerpsActionArgs(), address: Fixtures.wallet)
    let fastOptions = options()

    let task = Task { try await perps.executeAction(params: params, options: fastOptions) }
    do {
      _ = try await task.value
      XCTFail("Expected the execution to be cancelled.")
    } catch {
      XCTAssertTrue(error is CancellationError, "\(error)")
    }
  }

  func test_aCancelledRequestWhileTheTaskRuns_isAnOrdinaryAmbiguousFailure() async {
    backend.cancelsTaskOnCancelledRequest = false
    backend.scriptedSubmits = [.failure(URLError(.cancelled))]

    let error = await expectFailure(.submitOutcomeUnknown)

    XCTAssertEqual(error?.underlyingError as? URLError, URLError(.cancelled))
    // Reconciled like any transport failure, and the signature is not resubmitted.
    XCTAssertEqual(backend.getActionCallsCount, 2)
    XCTAssertEqual(backend.submitted.count, 1)
  }

  // MARK: Poll schedule edges

  func test_aZeroTimeoutStillReadsTheActionOnce_thenSigns() async throws {
    let result = try await execute(nil, options(pollAction: false, timeoutSeconds: 0))

    XCTAssertEqual(backend.getActionCallsCount, 1)
    XCTAssertEqual(signers.typedDataRequests.count, 1)
    XCTAssertEqual(result.transactions.map(\.transactionId), ["tx-order-1"])
  }

  func test_aZeroTimeoutStillTracksTheActionToItsFinalStatus() async throws {
    let result = try await execute(nil, options(timeoutSeconds: 0))

    XCTAssertEqual(result.status, .success)
  }

  func test_withoutPolling_signsTransactionsTheReadBackAddsToAStaleAction() async throws {
    let current = Fixtures.perpsAction(transactions: [
      Fixtures.orderTransaction(id: "tx-order-1"),
      Fixtures.orderTransaction(id: "tx-order-2")
    ])
    setBackend(current)
    let stale = Fixtures.perpsAction(transactions: [Fixtures.orderTransaction(id: "tx-order-1")])

    let result = try await execute(stale, options(pollAction: false))

    XCTAssertEqual(backend.submitted.map(\.transactionId), ["tx-order-1", "tx-order-2"])
    XCTAssertEqual(signers.typedDataRequests.count, 2)
    XCTAssertEqual(result.transactions.map(\.transactionId), ["tx-order-1", "tx-order-2"])
  }
}
