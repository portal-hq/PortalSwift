//
//  YieldXyzBorrowExecutionTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import AnyCodable
@testable import PortalSwift
import XCTest

/// Ports the React Native `yieldXyzBorrow.execute.test.ts` suite (same fixtures, same expectations),
/// plus the native-only idempotency-key and cancellation behaviour.
final class YieldXyzBorrowExecutionTests: XCTestCase {
  private typealias F = YieldXyzBorrowFixtures

  // MARK: - Doubles

  /// A thread-safe ordered log shared by the doubles, to assert what happened before what.
  private final class EventLog {
    private let lock = NSLock()
    private var entries: [String] = []

    func append(_ entry: String) {
      lock.lock()
      entries.append(entry)
      lock.unlock()
    }

    var all: [String] {
      lock.lock()
      defer { lock.unlock() }
      return entries
    }
  }

  /// Records every `eth_sendTransaction` and returns the scripted results in order, then
  /// `defaultResult`.
  private final class Signer {
    private let lock = NSLock()
    private let log: EventLog
    private(set) var calls: [(param: ETHTransactionParam, chainId: String, idempotencyKey: String?)] = []
    var results: [Swift.Result<String?, Error>] = []
    var defaultResult: Swift.Result<String?, Error> = .success(F.approvalHash)
    /// Holds the next call until released.
    var gate: SignatureGate?

    init(log: EventLog) {
      self.log = log
    }

    var callsCount: Int {
      lock.lock()
      defer { lock.unlock() }
      return calls.count
    }

    func sign(_ param: ETHTransactionParam, _ chainId: String, _ idempotencyKey: String?) async throws -> String? {
      let (result, gate): (Swift.Result<String?, Error>, SignatureGate?) = {
        lock.lock()
        defer { lock.unlock() }
        calls.append((param, chainId, idempotencyKey))
        let gate = self.gate
        self.gate = nil
        return (results.isEmpty ? defaultResult : results.removeFirst(), gate)
      }()
      log.append("sign")
      if let gate {
        return await gate.wait()
      }
      return try result.get()
    }
  }

  /// Holds one signing call until `release` is called.
  private final class SignatureGate {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<String?, Never>?
    private var startedContinuation: CheckedContinuation<Void, Never>?
    private var started = false

    func wait() async -> String? {
      await withCheckedContinuation { continuation in
        lock.lock()
        self.continuation = continuation
        started = true
        let waiting = startedContinuation
        startedContinuation = nil
        lock.unlock()
        waiting?.resume()
      }
    }

    func waitUntilStarted() async {
      await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        lock.lock()
        if started {
          lock.unlock()
          continuation.resume()
        } else {
          startedContinuation = continuation
          lock.unlock()
        }
      }
    }

    func release(_ hash: String) {
      lock.lock()
      let continuation = self.continuation
      self.continuation = nil
      lock.unlock()
      continuation?.resume(returning: hash)
    }
  }

  /// Records every lookup and returns the scripted results in order, then the EOA lookup of the
  /// hash.
  private final class Lookup {
    private let lock = NSLock()
    private(set) var calls: [(chainId: String, hash: String)] = []
    var results: [Swift.Result<YieldXyzEvmTransactionLookup?, Error>] = []
    /// Answers every call once `results` is used up, when set.
    var fallback: Swift.Result<YieldXyzEvmTransactionLookup?, Error>?

    var callsCount: Int {
      lock.lock()
      defer { lock.unlock() }
      return calls.count
    }

    func lookup(_ chainId: String, _ hash: String) async throws -> YieldXyzEvmTransactionLookup? {
      lock.lock()
      calls.append((chainId, hash))
      let result = results.isEmpty ? (fallback ?? .success(F.evmTransactionLookup(hash))) : results.removeFirst()
      lock.unlock()
      return try result.get()
    }
  }

  /// A stateful stand-in for the Borrow backend: a submitted hash confirms its transaction (or
  /// moves it to `statusAfterSubmit`), `getAction` reflects every transaction's status by id, and the
  /// action succeeds once all of them are complete.
  private final class FakeBackend {
    private let lock = NSLock()
    let initial: YieldXyzBorrowAction
    var statuses: [String: YieldXyzBorrowTransactionStatus]
    var statusAfterSubmit: YieldXyzBorrowTransactionStatus = .confirmed
    var finalActionStatus: YieldXyzBorrowActionStatus = .success
    var reorder = false
    private(set) var reads = 0
    private(set) var submits = 0
    /// Runs before each read is answered, with the read's 1-based number.
    var beforeRead: ((Int) -> Void)?
    /// Rewrites (or fails) each read; `submits` is the number of submissions so far.
    var transformRead: ((YieldXyzBorrowAction, Int) throws -> YieldXyzBorrowAction)?
    /// Fails the next submission instead of recording it, in order.
    var submitFailures: [Error] = []
    /// Applied to a recorded submission before it fails with `submitFailures`.
    var recordFailedSubmission = false
    let log: EventLog?

    init(_ initial: YieldXyzBorrowAction, log: EventLog? = nil) {
      self.initial = initial
      self.log = log
      self.statuses = Dictionary(initial.transactions.map { ($0.id, $0.status) }, uniquingKeysWith: { _, last in last })
    }

    func install(on api: PortalYieldXyzBorrowApiMock) {
      // Strong captures: the mock keeps the backend alive for the test.
      api.getActionHandler = { [self] _ in try self.read() }
      api.submitTransactionHandler = { [self] transactionId, params in try self.submit(transactionId, params) }
    }

    func setStatus(_ status: YieldXyzBorrowTransactionStatus, for transactionId: String) {
      lock.lock()
      statuses[transactionId] = status
      lock.unlock()
    }

    func read() throws -> YieldXyzBorrowAction {
      lock.lock()
      reads += 1
      let number = reads
      lock.unlock()
      log?.append("read#\(number)")
      beforeRead?(number)

      lock.lock()
      let transactions = initial.transactions.map { transaction in
        YieldXyzBorrowTransaction(
          id: transaction.id,
          network: transaction.network,
          type: transaction.type,
          status: statuses[transaction.id] ?? transaction.status,
          address: transaction.address,
          signingFormat: transaction.signingFormat,
          signablePayload: transaction.signablePayload
        )
      }
      let submitted = submits
      lock.unlock()

      let complete = transactions.allSatisfy { $0.status == .confirmed || $0.status == .skipped }
      let action = YieldXyzBorrowAction(
        id: initial.id,
        integrationId: initial.integrationId,
        action: initial.action,
        address: initial.address,
        status: complete ? finalActionStatus : .processing,
        transactions: reorder ? transactions.reversed() : transactions,
        hasNextStep: initial.hasNextStep,
        currentStep: initial.currentStep,
        totalSteps: initial.totalSteps,
        rawArguments: initial.rawArguments,
        metadata: initial.metadata,
        createdAt: initial.createdAt
      )
      return try transformRead?(action, submitted) ?? action
    }

    func submit(_ transactionId: String, _ params: YieldXyzBorrowSubmitTransactionParams) throws -> YieldXyzBorrowSubmitTransactionResult {
      lock.lock()
      submits += 1
      if !submitFailures.isEmpty {
        let failure = submitFailures.removeFirst()
        if recordFailedSubmission {
          statuses[transactionId] = .broadcasted
        }
        lock.unlock()
        throw failure
      }
      statuses[transactionId] = statusAfterSubmit
      lock.unlock()
      return F.submitResult(transactionHash: params.transactionHash ?? "")
    }
  }

  /// A two-step action: a submitted hash confirms its transaction, each step completes once all its
  /// transactions are confirmed, and `getAction` moves on to step two once `stepAction` is called.
  private final class TwoStepBackend {
    private let lock = NSLock()
    let stepOne: YieldXyzBorrowAction
    let stepTwo: YieldXyzBorrowAction
    private var submitted = Set<String>()
    private var step = 1
    var reorder = false

    init(_ stepOne: YieldXyzBorrowAction, _ stepTwo: YieldXyzBorrowAction) {
      self.stepOne = stepOne
      self.stepTwo = stepTwo
    }

    func install(on api: PortalYieldXyzBorrowApiMock) {
      api.submitTransactionHandler = { [self] transactionId, params in
        self.lock.lock()
        self.submitted.insert(transactionId)
        self.lock.unlock()
        return F.submitResult(transactionHash: params.transactionHash ?? "")
      }
      api.getActionHandler = { [self] _ in
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.step == 1 ? self.read(self.stepOne, completed: .waitingForNext) : self.read(self.stepTwo, completed: .success)
      }
      api.stepActionHandler = { [self] _ in
        self.lock.lock()
        self.step = 2
        self.lock.unlock()
        return self.stepTwo
      }
    }

    private func read(_ action: YieldXyzBorrowAction, completed: YieldXyzBorrowActionStatus) -> YieldXyzBorrowAction {
      let transactions = action.transactions.map { transaction in
        YieldXyzBorrowTransaction(
          id: transaction.id,
          network: transaction.network,
          type: transaction.type,
          status: submitted.contains(transaction.id) ? .confirmed : transaction.status,
          address: transaction.address,
          signingFormat: transaction.signingFormat,
          signablePayload: transaction.signablePayload
        )
      }
      let complete = transactions.allSatisfy { $0.status == .confirmed || $0.status == .skipped }
      return YieldXyzBorrowAction(
        id: action.id,
        integrationId: action.integrationId,
        action: action.action,
        address: action.address,
        status: complete ? completed : .processing,
        transactions: reorder ? transactions.reversed() : transactions,
        hasNextStep: action.hasNextStep,
        currentStep: action.currentStep,
        totalSteps: action.totalSteps,
        createdAt: action.createdAt
      )
    }
  }

  // MARK: - Setup

  private let fastPolicy = YieldXyzBorrowRetryPolicy(
    rateLimitDelays: [0, 0, 0],
    idempotencyInProgressDelays: [0, 0, 0],
    minPollInterval: 0,
    maxPollInterval: 0.001,
    maxConsecutivePollErrors: 5
  )
  private let fastPoll = YieldXyzBorrowPollOptions(intervalSeconds: 0.001, timeoutSeconds: 2)
  private let shortPoll = YieldXyzBorrowPollOptions(intervalSeconds: 0.005, timeoutSeconds: 0.04)

  private var log: EventLog!
  private var api: PortalYieldXyzBorrowApiMock!
  private var signer: Signer!
  private var lookup: Lookup!
  private var walletAddress: String?
  private var chainConfigured = true
  private var chainConfiguredCalls: [String] = []
  private var borrow: YieldXyzBorrow!

  override func setUp() {
    super.setUp()
    resetState()
  }

  /// Fresh doubles, for the setup and for each case of a looped test.
  private func resetState() {
    log = EventLog()
    api = PortalYieldXyzBorrowApiMock()
    signer = Signer(log: log)
    signer.results = [.success(F.approvalHash), .success(F.supplyHash)]
    lookup = Lookup()
    walletAddress = F.wallet
    chainConfigured = true
    chainConfiguredCalls = []
    borrow = makeBorrow()
  }

  override func tearDown() {
    borrow = nil
    api = nil
    signer = nil
    lookup = nil
    log = nil
    super.tearDown()
  }

  private func dependencies(signer withSigner: Bool = true) -> YieldXyzBorrowExecutionDependencies {
    YieldXyzBorrowExecutionDependencies(
      getWalletAddress: { [unowned self] in self.walletAddress },
      signAndSendTransaction: withSigner ? { [unowned self] param, chainId, key in try await self.signer.sign(param, chainId, key) } : nil,
      isChainConfigured: { [unowned self] chainId in
        self.chainConfiguredCalls.append(chainId)
        return self.chainConfigured
      }
    )
  }

  private func makeBorrow(signer withSigner: Bool = true, lookup withLookup: Bool = true) -> YieldXyzBorrow {
    YieldXyzBorrow(
      api: api,
      dependencies: dependencies(signer: withSigner),
      lookupEvmTransaction: withLookup ? { [unowned self] chainId, hash in try await self.lookup.lookup(chainId, hash) } : nil,
      retryPolicy: fastPolicy
    )
  }

  private func options(
    poll: YieldXyzBorrowPollOptions? = nil,
    broadcastHashes: [String: String] = [:],
    useIdempotencyKeys: Bool = true,
    signAndSendTransaction: YieldXyzBorrowSignAndSendTransaction? = nil,
    onProgress: ((YieldXyzBorrowExecutionProgress) -> Void)? = nil
  ) -> YieldXyzBorrowExecuteOptions {
    YieldXyzBorrowExecuteOptions(
      onProgress: onProgress,
      pollOptions: poll ?? fastPoll,
      useIdempotencyKeys: useIdempotencyKeys,
      signAndSendTransaction: signAndSendTransaction,
      broadcastHashes: broadcastHashes
    )
  }

  @discardableResult
  private func fakeBackend(_ action: YieldXyzBorrowAction) -> FakeBackend {
    let backend = FakeBackend(action, log: log)
    backend.install(on: api)
    return backend
  }

  /// Yield.xyz reports `action` exactly as it is, whatever the SDK submits.
  private func serve(_ action: YieldXyzBorrowAction) {
    api.getActionHandler = { _ in action }
  }

  private func backendError(_ status: Int, _ body: String = "{}") -> PortalRequestsError {
    status >= 500
      ? .internalServerError("\(status) - \(body)", url: "")
      : .clientError("\(status) - \(body)", url: "")
  }

  private func idempotencyError(_ id: String) -> PortalMpcError {
    PortalMpcError(PortalError(code: nil, id: id, message: "rejected"))
  }

  private func singleTransactionAction() -> YieldXyzBorrowAction {
    F.borrowAction(transactions: [F.approvalTransaction()])
  }

  /// Runs `operation`, expecting a `YieldXyzBorrowExecutionError` with `reason`.
  private func expectFailure(
    _ reason: YieldXyzBorrowExecutionErrorReason,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ operation: () async throws -> YieldXyzBorrowExecutionResult
  ) async -> YieldXyzBorrowExecutionError? {
    do {
      _ = try await operation()
      XCTFail("Expected the execution to fail with \(reason.rawValue)", file: file, line: line)
      return nil
    } catch let error as YieldXyzBorrowExecutionError {
      XCTAssertEqual(error.reason, reason, "\(error.message)", file: file, line: line)
      return error
    } catch {
      XCTFail("Expected a YieldXyzBorrowExecutionError, got \(error)", file: file, line: line)
      return nil
    }
  }

  private func execute(
    _ action: YieldXyzBorrowAction,
    _ options: YieldXyzBorrowExecuteOptions? = nil,
    on instance: YieldXyzBorrow? = nil
  ) async throws -> YieldXyzBorrowExecutionResult {
    try await (instance ?? borrow).signAndSubmitAction(action, options: options ?? self.options())
  }

  private var submittedCalls: [(String, String?)] {
    api.submitTransactionCalls.map { ($0.transactionId, $0.params.transactionHash) }
  }

  private func assertSubmitted(_ expected: [(String, String)], file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(submittedCalls.map(\.0), expected.map(\.0), file: file, line: line)
    XCTAssertEqual(submittedCalls.map(\.1), expected.map(\.1), file: file, line: line)
    XCTAssertTrue(api.submitTransactionCalls.allSatisfy { $0.params.signedPayload == nil }, file: file, line: line)
  }

  // MARK: - EOA

  func test_signsSubmitsAndConfirmsEachTransactionInSigningOrder() async throws {
    let action = F.borrowAction()
    fakeBackend(action)

    let result = try await execute(action)

    XCTAssertEqual(signer.calls.count, 2)
    let approval = signer.calls[0]
    XCTAssertEqual(approval.param.from, F.wallet)
    XCTAssertEqual(approval.param.to, F.usdcBase)
    XCTAssertTrue(approval.param.data?.hasPrefix("0x095ea7b3") ?? false)
    XCTAssertEqual(approval.param.gas, "0xdbb0")
    XCTAssertEqual(approval.param.value, "0x0")
    XCTAssertEqual(approval.chainId, F.base)
    XCTAssertEqual(approval.idempotencyKey, "yieldxyz-borrow-tx-approval")
    let supply = signer.calls[1]
    XCTAssertEqual(supply.param.to, F.aavePoolBase)
    XCTAssertTrue(supply.param.data?.hasPrefix("0x617ba037") ?? false)
    XCTAssertEqual(supply.param.gas, "0x668a0")
    XCTAssertEqual(supply.param.value, "0x0")
    XCTAssertEqual(supply.chainId, F.base)
    XCTAssertEqual(supply.idempotencyKey, "yieldxyz-borrow-tx-supply")
    assertSubmitted([("tx-approval", F.approvalHash), ("tx-supply", F.supplyHash)])
    XCTAssertEqual(result.actionId, "act-1")
    XCTAssertEqual(result.status, .success)
    XCTAssertEqual(result.action.status, .success)
    XCTAssertEqual(result.transactions, [
      YieldXyzBorrowTransactionExecution(
        transactionId: "tx-approval",
        type: .approval,
        transactionHash: F.approvalHash,
        submitResult: F.submitResult(transactionHash: F.approvalHash)
      ),
      YieldXyzBorrowTransactionExecution(
        transactionId: "tx-supply",
        type: .supply,
        transactionHash: F.supplyHash,
        submitResult: F.submitResult(transactionHash: F.supplyHash)
      )
    ])
  }

  func test_waitsForYieldXyzToConfirmATransactionBeforeSigningTheNextOne() async throws {
    let action = F.borrowAction()
    let backend = fakeBackend(action)
    backend.statusAfterSubmit = .broadcasted
    backend.beforeRead = { [unowned backend] read in
      if read == 3 {
        backend.setStatus(.confirmed, for: "tx-approval")
      }
      if read == 6 {
        backend.setStatus(.confirmed, for: "tx-supply")
      }
    }

    _ = try await execute(action)

    let events = log.all
    let secondSign = try XCTUnwrap(events.indices.filter { events[$0] == "sign" }.dropFirst().first)
    let approvalConfirmedRead = try XCTUnwrap(events.firstIndex(of: "read#3"))
    XCTAssertGreaterThan(secondSign, approvalConfirmedRead)
  }

  func test_readsStatusesByTransactionId_whenGetActionReordersTheTransactions() async throws {
    let action = F.borrowAction()
    fakeBackend(action).reorder = true

    let result = try await execute(action)

    XCTAssertEqual(result.transactions.map(\.transactionId), ["tx-approval", "tx-supply"])
    XCTAssertEqual(signer.calls.count, 2)
  }

  func test_skipsTransactionsAlreadyConfirmedOrSkipped() async throws {
    let action = F.borrowAction(transactions: [F.approvalTransaction(status: .skipped), F.supplyTransaction()])
    fakeBackend(action)
    signer.results = [.success(F.supplyHash)]

    let result = try await execute(action)

    XCTAssertEqual(signer.calls.count, 1)
    assertSubmitted([("tx-supply", F.supplyHash)])
    XCTAssertEqual(result.transactions.count, 1)
  }

  func test_waitsOnATransactionAlreadySubmitted_insteadOfSigningItAgain() async throws {
    let action = F.borrowAction(transactions: [F.approvalTransaction(status: .broadcasted)])
    let backend = fakeBackend(action)
    backend.beforeRead = { [unowned backend] read in
      if read == 3 {
        backend.setStatus(.confirmed, for: "tx-approval")
      }
    }

    let result = try await execute(action)

    XCTAssertEqual(api.getActionCallsCount, 3)
    XCTAssertEqual(signer.calls.count, 0)
    XCTAssertEqual(api.submitTransactionCallsCount, 0)
    XCTAssertEqual(result.status, .success)
    XCTAssertEqual(result.transactions, [])
  }

  func test_waitsForABlockedTransactionToAwaitASignatureBeforeSigningIt() async throws {
    let action = F.borrowAction(transactions: [F.approvalTransaction(status: .blocked)])
    let backend = fakeBackend(action)
    backend.beforeRead = { [unowned backend] read in
      if read == 3 {
        backend.setStatus(.created, for: "tx-approval")
      }
    }

    _ = try await execute(action)

    let events = log.all
    XCTAssertEqual(signer.calls.count, 1)
    XCTAssertGreaterThan(try XCTUnwrap(events.firstIndex(of: "sign")), try XCTUnwrap(events.firstIndex(of: "read#3")))
  }

  private let staleSupplyPayload = AnyCodable(#"{"from":"0x8ba1f109551bD432803012645Ac136ddd64DBA72","to":"0xA238Dd80C259a72e81d7e4664a9801593F98d1c5","data":"0x617ba037","gasLimit":"100"}"#)

  func test_signsThePayloadYieldXyzListsOnceABlockedTransactionAwaitsASignature() async throws {
    let blocked = F.supplyTransaction(status: .blocked, signablePayload: staleSupplyPayload)
    api.getActionResults = [
      .success(F.borrowAction(transactions: [blocked])),
      .success(F.borrowAction(status: .processing, transactions: [F.supplyTransaction(status: .waitingForSignature)]))
    ]
    api.getActionReturnValue = F.borrowAction(status: .success, transactions: [F.supplyTransaction(status: .confirmed)])
    api.submitTransactionReturnValue = F.submitResult(transactionHash: F.supplyHash)
    signer.results = [.success(F.supplyHash)]

    _ = try await execute(F.borrowAction(transactions: [blocked]))

    XCTAssertEqual(signer.calls.map(\.param.gas), ["0x668a0"])
  }

  func test_waitsForATransactionYieldXyzStopsListing_thenSignsThePayloadListedOnceItIsBack() async throws {
    let action = F.borrowAction(transactions: [F.approvalTransaction(), F.supplyTransaction(signablePayload: staleSupplyPayload)])
    var submitted = Set<String>()
    var readsWithoutSupply = 0
    api.submitTransactionHandler = { transactionId, params in
      submitted.insert(transactionId)
      return F.submitResult(transactionHash: params.transactionHash ?? "")
    }
    api.getActionHandler = { _ in
      guard submitted.contains("tx-approval") else {
        return action
      }
      let approval = F.approvalTransaction(status: .confirmed)
      if readsWithoutSupply < 2 {
        readsWithoutSupply += 1
        return F.borrowAction(status: .processing, transactions: [approval])
      }
      let supplied = submitted.contains("tx-supply")
      return F.borrowAction(
        status: supplied ? .success : .processing,
        transactions: [approval, F.supplyTransaction(status: supplied ? .confirmed : .waitingForSignature)]
      )
    }

    _ = try await execute(action)

    XCTAssertEqual(signer.calls.map(\.param.gas), ["0xdbb0", "0x668a0"])
  }

  func test_neverSignsATransactionYieldXyzStopsListing() async throws {
    for (status, reason) in [
      (YieldXyzBorrowActionStatus.processing, YieldXyzBorrowExecutionErrorReason.timeout),
      (.success, .timeout),
      (.canceled, .actionFailed)
    ] {
      resetState()
      let action = F.borrowAction(transactions: [F.approvalTransaction(), F.supplyTransaction(signablePayload: staleSupplyPayload)])
      api.submitTransactionHandler = { _, params in F.submitResult(transactionHash: params.transactionHash ?? "") }
      api.getActionHandler = { [unowned self] _ in
        self.api.submitTransactionCallsCount > 0
          ? F.borrowAction(status: status, transactions: [F.approvalTransaction(status: .confirmed)])
          : action
      }

      let error = await expectFailure(reason) { try await self.execute(action, self.options(poll: self.shortPoll)) }

      XCTAssertEqual(signer.calls.map(\.param.gas), ["0xdbb0"], "\(status)")
      assertSubmitted([("tx-approval", F.approvalHash)])
      XCTAssertEqual(error?.transactionId, "tx-supply")
    }
  }

  func test_acceptsAnActionAndTransactionAddressThatDifferOnlyInCase() async throws {
    let lowercased = F.wallet.lowercased()
    let action = F.borrowAction(address: lowercased, transactions: [F.approvalTransaction(address: lowercased)])
    fakeBackend(action)

    let result = try await execute(action)

    XCTAssertEqual(result.status, .success)
  }

  func test_prefersThePerCallSignerOverTheConfiguredOne() async throws {
    let action = singleTransactionAction()
    fakeBackend(action)
    var overrideCalls = 0

    _ = try await execute(action, options(signAndSendTransaction: { _, _, _ in
      overrideCalls += 1
      return F.approvalHash
    }))

    XCTAssertEqual(overrideCalls, 1)
    XCTAssertEqual(signer.calls.count, 0)
  }

  func test_executeAction_createsTheActionAndExecutesIt() async throws {
    let action = singleTransactionAction()
    fakeBackend(action)
    api.createActionReturnValue = YieldXyzBorrowResponse(data: action)
    let params = YieldXyzBorrowCreateActionParams(
      integrationId: "aave-borrow",
      action: .supply,
      address: F.wallet,
      args: YieldXyzBorrowActionArguments(marketId: "m-1", amount: "5", tokenAddress: F.usdcBase)
    )

    let result = try await borrow.executeAction(params: params, options: options())

    XCTAssertEqual(api.createActionParams, params)
    XCTAssertEqual(result.status, .success)
  }

  func test_executeAction_propagatesACreateActionErrorUnwrapped() async throws {
    api.createActionError = backendError(400, #"{"error":"Invalid request body"}"#)

    do {
      _ = try await borrow.executeAction(params: YieldXyzBorrowCreateActionParams(
        integrationId: "aave-borrow",
        action: .supply,
        address: F.wallet,
        args: YieldXyzBorrowActionArguments(marketId: "m-1")
      ), options: options())
      XCTFail("Expected createAction to fail")
    } catch {
      XCTAssertTrue(error is PortalRequestsError)
    }
  }

  // MARK: - Account abstraction

  func test_aa_submitsTheBundleTransactionHash_neverTheUserOperationHash() async throws {
    let action = singleTransactionAction()
    fakeBackend(action)
    signer.results = []
    signer.defaultResult = .success(F.userOperationHash)
    lookup.results = [
      .failure(backendError(404, #"{"error":"not found"}"#)),
      .success(F.userOperationLookup(receiptHash: nil)),
      .success(F.userOperationLookup(receiptHash: F.bundleHash))
    ]

    let result = try await execute(action)

    XCTAssertEqual(lookup.calls.first?.chainId, F.base)
    XCTAssertEqual(lookup.calls.first?.hash, F.userOperationHash)
    assertSubmitted([("tx-approval", F.bundleHash)])
    XCTAssertEqual(result.transactions, [YieldXyzBorrowTransactionExecution(
      transactionId: "tx-approval",
      type: .approval,
      transactionHash: F.bundleHash,
      userOperationHash: F.userOperationHash,
      submitResult: F.submitResult(transactionHash: F.bundleHash)
    )])
  }

  func test_aa_failsWithoutSubmittingWhenTheUserOperationDidNotSucceed() async throws {
    let action = singleTransactionAction()
    serve(action)
    signer.results = []
    signer.defaultResult = .success(F.userOperationHash)
    lookup.fallback = .success(F.userOperationLookup(receiptHash: F.bundleHash, success: false))

    let error = await expectFailure(.userOperationFailed) { try await self.execute(action) }

    XCTAssertEqual(error?.actionId, "act-1")
    XCTAssertEqual(error?.transactionId, "tx-approval")
    XCTAssertEqual(error?.broadcastHash, F.userOperationHash)
    XCTAssertEqual(error?.transactionHash, F.bundleHash)
    XCTAssertEqual(error?.userOperationHash, F.userOperationHash)
    XCTAssertEqual(api.submitTransactionCallsCount, 0)
  }

  func test_aa_timesOutWithTheBroadcastHashWhenTheUserOperationIsNeverFound() async throws {
    let action = singleTransactionAction()
    serve(action)
    signer.results = []
    signer.defaultResult = .success(F.userOperationHash)
    lookup.fallback = .failure(backendError(404))

    let error = await expectFailure(.timeout) { try await self.execute(action, self.options(poll: self.shortPoll)) }

    XCTAssertEqual(error?.broadcastHash, F.userOperationHash)
    XCTAssertEqual(api.submitTransactionCallsCount, 0)
  }

  func test_aa_failsTheLookupWithItsCauseOnANonTransientError() async throws {
    let action = singleTransactionAction()
    serve(action)
    lookup.fallback = .failure(backendError(400, #"{"error":"Unsupported chain"}"#))

    let error = await expectFailure(.pollingFailed) { try await self.execute(action) }

    XCTAssertEqual(YieldXyzBorrowApiError.from(error)?.message, "Unsupported chain")
    XCTAssertEqual(error?.broadcastHash, F.approvalHash)
  }

  func test_aa_stopsTheLookupAfterTooManyConsecutiveTransientFailures() async throws {
    let action = singleTransactionAction()
    serve(action)
    lookup.fallback = .failure(backendError(503))

    let error = await expectFailure(.pollingFailed) { try await self.execute(action) }

    XCTAssertEqual(lookup.callsCount, 5)
    XCTAssertEqual(YieldXyzBorrowApiError.from(error)?.status, 503)
  }

  func test_aa_aNotFoundResetsTheConsecutiveFailures() async throws {
    let action = singleTransactionAction()
    fakeBackend(action)
    let unavailable = backendError(503)
    lookup.results = [
      .failure(unavailable), .failure(unavailable), .failure(unavailable), .failure(unavailable),
      .failure(backendError(404)),
      .failure(unavailable), .failure(unavailable), .failure(unavailable), .failure(unavailable)
    ]

    let result = try await execute(action)

    XCTAssertEqual(result.status, .success)
    XCTAssertEqual(lookup.callsCount, 10)
  }

  func test_aa_keepsWaitingWhenTheLookupReturnsNoData() async throws {
    let action = singleTransactionAction()
    fakeBackend(action)
    lookup.results = [.success(nil), .success(nil)]

    let result = try await execute(action)

    XCTAssertEqual(result.status, .success)
    XCTAssertEqual(lookup.callsCount, 3)
  }

  // MARK: - Multi-step actions

  func test_fetchesAndExecutesTheNextStepWhenTheConfirmedStepHasANextStep() async throws {
    let stepOne = F.borrowAction(transactions: [F.approvalTransaction()], hasNextStep: true, currentStep: 1, totalSteps: 2)
    let stepTwo = F.borrowAction(
      status: .waitingForNext,
      transactions: [F.supplyTransaction(id: "tx-step-2")],
      hasNextStep: false,
      currentStep: 2,
      totalSteps: 2
    )
    TwoStepBackend(stepOne, stepTwo).install(on: api)
    var progress: [YieldXyzBorrowExecutionProgress] = []

    let result = try await execute(stepOne, options(onProgress: { progress.append($0) }))

    XCTAssertEqual(api.stepActionCallsCount, 1)
    XCTAssertEqual(api.stepActionActionIdParam, "act-1")
    XCTAssertEqual(submittedCalls.map(\.0), ["tx-approval", "tx-step-2"])
    let nextStep = try XCTUnwrap(progress.first { $0.step == .nextStep })
    XCTAssertEqual(nextStep.currentStep, 2)
    XCTAssertEqual(nextStep.totalSteps, 2)
    XCTAssertEqual(result.status, .success)
    XCTAssertEqual(result.transactions.map(\.transactionId), ["tx-approval", "tx-step-2"])
  }

  func test_keepsTheSigningOrderOfTheStepResponseInALaterStep_andReportsItWithNextStep() async throws {
    let stepOne = F.borrowAction(transactions: [F.approvalTransaction()], hasNextStep: true, totalSteps: 2)
    let stepTwo = F.borrowAction(
      transactions: [F.approvalTransaction(id: "tx-step-2-approval"), F.supplyTransaction(id: "tx-step-2-supply")],
      currentStep: 2,
      totalSteps: 2
    )
    let backend = TwoStepBackend(stepOne, stepTwo)
    backend.reorder = true
    backend.install(on: api)
    signer.results = [
      .success(F.approvalHash),
      .success("0x" + String(repeating: "e1", count: 32)),
      .success("0x" + String(repeating: "e2", count: 32))
    ]
    var progress: [YieldXyzBorrowExecutionProgress] = []

    let result = try await execute(stepOne, options(onProgress: { progress.append($0) }))

    XCTAssertEqual(submittedCalls.map(\.0), ["tx-approval", "tx-step-2-approval", "tx-step-2-supply"])
    XCTAssertEqual(signer.calls.map(\.param.to), [F.usdcBase, F.usdcBase, F.aavePoolBase])
    XCTAssertEqual(result.action.transactions.map(\.id), ["tx-step-2-approval", "tx-step-2-supply"])
    let nextStep = try XCTUnwrap(progress.first { $0.step == .nextStep })
    XCTAssertEqual(nextStep.action?.transactions.map(\.id), ["tx-step-2-approval", "tx-step-2-supply"])
    XCTAssertTrue(progress.filter { $0.step != .nextStep }.allSatisfy { $0.action == nil })
  }

  func test_doesNotSignTransactionsOfAnEarlierStepThatYieldXyzNoLongerLists() async throws {
    let stepOne = F.borrowAction(transactions: [F.approvalTransaction()], hasNextStep: true, totalSteps: 2)
    let stepTwo = F.borrowAction(transactions: [F.supplyTransaction(id: "tx-step-2")], currentStep: 2, totalSteps: 2)
    fakeBackend(stepTwo)
    signer.results = []
    signer.defaultResult = .success(F.supplyHash)

    _ = try await execute(stepOne)

    XCTAssertEqual(signer.calls.map(\.param.to), [F.aavePoolBase])
    XCTAssertEqual(submittedCalls.map(\.0), ["tx-step-2"])
    XCTAssertEqual(api.stepActionCallsCount, 0)
  }

  func test_resumesAnActionWhoseCurrentStepIsAlreadyConfirmed_byFetchingTheNextStep() async throws {
    let confirmed = F.borrowAction(status: .waitingForNext, transactions: [F.approvalTransaction(status: .confirmed)], hasNextStep: true)
    let next = F.borrowAction(transactions: [F.supplyTransaction()], currentStep: 2, totalSteps: 2)
    let backend = FakeBackend(next)
    var stepped = false
    api.getActionHandler = { _ in stepped ? try backend.read() : confirmed }
    api.submitTransactionHandler = { id, params in try backend.submit(id, params) }
    api.stepActionHandler = { _ in
      stepped = true
      return next
    }
    signer.results = [.success(F.supplyHash)]

    let result = try await execute(confirmed)

    XCTAssertEqual(api.stepActionCallsCount, 1)
    XCTAssertEqual(result.transactions.map(\.transactionId), ["tx-supply"])
  }

  func test_failsWhenTheNextStepHasNothingToSign() async throws {
    let action = F.borrowAction(status: .waitingForNext, transactions: [F.approvalTransaction(status: .confirmed)], hasNextStep: true)
    serve(action)
    api.stepActionReturnValue = F.borrowAction(transactions: [F.approvalTransaction(status: .confirmed)])

    _ = await expectFailure(.nextStepFailed) { try await self.execute(action) }
  }

  func test_failsWhenANextStepThatHasNotEndedListsNoTransactions() async throws {
    let action = F.borrowAction(status: .waitingForNext, transactions: [F.approvalTransaction(status: .confirmed)], hasNextStep: true)
    serve(action)
    api.stepActionReturnValue = F.borrowAction(status: .created, transactions: [])

    _ = await expectFailure(.nextStepFailed) { try await self.execute(action) }
  }

  func test_failsWithTheEndedActionWhenTheNextStepReturnsAnEndedAction() async throws {
    for status in [YieldXyzBorrowActionStatus.failed, .canceled, .stale] {
      resetState()
      let action = F.borrowAction(status: .waitingForNext, transactions: [F.approvalTransaction(status: .confirmed)], hasNextStep: true)
      serve(action)
      let ended = F.borrowAction(status: status, transactions: status == .failed ? [F.approvalTransaction(status: .confirmed)] : [])
      api.stepActionReturnValue = ended

      let error = await expectFailure(.actionFailed) { try await self.execute(action) }

      XCTAssertEqual(error?.action, ended, "\(status)")
      XCTAssertEqual(signer.calls.count, 0)
    }
  }

  func test_failsWithTheBackendCauseWhenTheNextStepIsRejected() async throws {
    let action = F.borrowAction(status: .waitingForNext, transactions: [F.approvalTransaction(status: .confirmed)], hasNextStep: true)
    serve(action)
    api.stepActionResults = [.failure(backendError(400, #"{"error":"Step not available yet"}"#))]

    let error = await expectFailure(.nextStepFailed) { try await self.execute(action) }

    XCTAssertEqual(YieldXyzBorrowApiError.from(error)?.message, "Step not available yet")
    XCTAssertEqual(api.stepActionCallsCount, 1)
  }

  func test_retriesARateLimitedNextStep() async throws {
    let stepOne = F.borrowAction(transactions: [F.approvalTransaction()], hasNextStep: true, totalSteps: 2)
    let stepTwo = F.borrowAction(transactions: [F.supplyTransaction(id: "tx-step-2")], currentStep: 2, totalSteps: 2)
    TwoStepBackend(stepOne, stepTwo).install(on: api)
    let handler = api.stepActionHandler
    var attempts = 0
    api.stepActionHandler = { [unowned self] id in
      attempts += 1
      if attempts == 1 {
        throw self.backendError(429)
      }
      return try await handler!(id)
    }

    let result = try await execute(stepOne)

    XCTAssertEqual(attempts, 2)
    XCTAssertEqual(result.status, .success)
  }

  func test_doesNotFetchANextStepForAnActionThatFailed() async throws {
    let action = F.borrowAction(status: .failed, transactions: [F.approvalTransaction(status: .confirmed)], hasNextStep: true)
    serve(action)

    _ = await expectFailure(.actionFailed) { try await self.execute(action) }

    XCTAssertEqual(api.stepActionCallsCount, 0)
  }

  // MARK: - Failures while tracking

  func test_failsWhenYieldXyzReportsTheTransactionFailed() async throws {
    let action = F.borrowAction()
    fakeBackend(action).statusAfterSubmit = .failed

    let error = await expectFailure(.transactionFailed) { try await self.execute(action) }

    XCTAssertEqual(error?.actionId, "act-1")
    XCTAssertEqual(error?.transactionId, "tx-approval")
    XCTAssertEqual(error?.action?.id, "act-1")
    XCTAssertEqual(signer.calls.count, 1)
  }

  func test_failsBeforeSigningATransactionThatIsAlreadyFailed() async throws {
    let action = F.borrowAction(transactions: [F.approvalTransaction(status: .failed)])
    serve(action)

    _ = await expectFailure(.transactionFailed) { try await self.execute(action) }

    XCTAssertEqual(signer.calls.count, 0)
  }

  func test_failsWhenTheActionEndsWhileTracking_keepingTheHashes() async throws {
    for status in [YieldXyzBorrowActionStatus.failed, .canceled, .stale] {
      resetState()
      let action = singleTransactionAction()
      let backend = fakeBackend(action)
      backend.statusAfterSubmit = .broadcasted
      backend.transformRead = { action, submits in submits > 0 ? Self.withStatus(action, status) : action }
      var progress: [YieldXyzBorrowExecutionProgress] = []

      let error = await expectFailure(.actionFailed) { try await self.execute(action, self.options(onProgress: { progress.append($0) })) }

      XCTAssertEqual(error?.actionId, "act-1")
      XCTAssertEqual(error?.transactionId, "tx-approval")
      XCTAssertEqual(error?.broadcastHash, F.approvalHash)
      XCTAssertEqual(error?.transactionHash, F.approvalHash)
      XCTAssertEqual(error?.action?.status, status)
      let failed = try XCTUnwrap(progress.first { $0.step == .failed })
      XCTAssertEqual(failed.transactionId, "tx-approval")
      XCTAssertEqual(failed.broadcastHash, F.approvalHash)
      XCTAssertEqual(failed.transactionHash, F.approvalHash)
      XCTAssertEqual(signer.calls.count, 1)
    }
  }

  func test_aa_keepsTheUserOperationAndBundleHashesWhenTheActionEndsWhilePending() async throws {
    let action = singleTransactionAction()
    let backend = fakeBackend(action)
    backend.statusAfterSubmit = .pending
    backend.transformRead = { action, submits in submits > 0 ? Self.withStatus(action, .failed) : action }
    signer.results = []
    signer.defaultResult = .success(F.userOperationHash)
    lookup.fallback = .success(F.userOperationLookup(receiptHash: F.bundleHash))
    var progress: [YieldXyzBorrowExecutionProgress] = []

    let error = await expectFailure(.actionFailed) { try await self.execute(action, self.options(onProgress: { progress.append($0) })) }

    XCTAssertEqual(error?.transactionId, "tx-approval")
    XCTAssertEqual(error?.broadcastHash, F.userOperationHash)
    XCTAssertEqual(error?.transactionHash, F.bundleHash)
    XCTAssertEqual(error?.userOperationHash, F.userOperationHash)
    let failed = try XCTUnwrap(progress.first { $0.step == .failed })
    XCTAssertEqual(failed.userOperationHash, F.userOperationHash)
    XCTAssertEqual(failed.transactionHash, F.bundleHash)
  }

  func test_doesNotSignTheNextTransactionOnceTheActionEnds() async throws {
    for status in [YieldXyzBorrowActionStatus.failed, .canceled, .stale] {
      resetState()
      let action = F.borrowAction()
      fakeBackend(action).transformRead = { action, submits in submits > 0 ? Self.withStatus(action, status) : action }

      let error = await expectFailure(.actionFailed) { try await self.execute(action) }

      XCTAssertEqual(error?.transactionId, "tx-supply")
      XCTAssertEqual(error?.action?.status, status)
      XCTAssertEqual(error?.action?.transactions[1].status, .created)
      XCTAssertEqual(signer.calls.count, 1)
      XCTAssertEqual(api.submitTransactionCallsCount, 1)
    }
  }

  func test_failsBeforeSigningAnythingWhenTheActionReadBackHasAlreadyFailed() async throws {
    serve(Self.withStatus(F.borrowAction(), .canceled))

    _ = await expectFailure(.actionFailed) { try await self.execute(F.borrowAction()) }

    XCTAssertEqual(signer.calls.count, 0)
  }

  func test_timesOutWhenTheTransactionIsNeverConfirmed() async throws {
    let action = singleTransactionAction()
    fakeBackend(action).statusAfterSubmit = .pending

    let error = await expectFailure(.timeout) { try await self.execute(action, self.options(poll: self.shortPoll)) }

    XCTAssertEqual(error?.action?.transactions.first?.status, .pending)
    XCTAssertEqual(error?.transactionId, "tx-approval")
    XCTAssertEqual(error?.broadcastHash, F.approvalHash)
    XCTAssertEqual(error?.transactionHash, F.approvalHash)
  }

  func test_keepsPollingThroughTransientReadFailures() async throws {
    let action = singleTransactionAction()
    let backend = FakeBackend(action)
    backend.install(on: api)
    let read = api.getActionHandler!
    var reads = 0
    api.getActionHandler = { [unowned self] id in
      reads += 1
      switch reads {
      case 2: throw self.backendError(503)
      case 3: throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "empty body"))
      case 4: throw self.backendError(429)
      default: return try await read(id)
      }
    }

    let result = try await execute(action)

    XCTAssertEqual(result.status, .success)
    XCTAssertEqual(reads, 5)
    XCTAssertEqual(signer.calls.count, 1)
  }

  func test_stopsPollingAfterTooManyConsecutiveTransientFailures() async throws {
    let action = singleTransactionAction()
    fakeBackend(action).transformRead = { [unowned self] action, submits in
      if submits > 0 {
        throw self.backendError(503)
      }
      return action
    }

    let error = await expectFailure(.pollingFailed) { try await self.execute(action) }

    XCTAssertEqual(api.getActionCallsCount, 1 + 5)
    XCTAssertEqual(YieldXyzBorrowApiError.from(error)?.status, 503)
    XCTAssertEqual(signer.calls.count, 1)
  }

  func test_stopsPollingAtOnceOnANotFoundOrASpentCredential() async throws {
    let causes: [Error] = [backendError(404, #"{"error":"Action not found"}"#), PortalCredentialError.sessionInvalidated]
    for cause in causes {
      resetState()
      let action = singleTransactionAction()
      fakeBackend(action).transformRead = { action, submits in
        if submits > 0 {
          throw cause
        }
        return action
      }

      let error = await expectFailure(.pollingFailed) { try await self.execute(action) }

      XCTAssertEqual(api.getActionCallsCount, 1 + 1, "\(cause)")
      XCTAssertNotNil(error?.underlyingError)
      XCTAssertEqual(signer.calls.count, 1)
    }
  }

  func test_failsBeforeSigningAnythingWhenTheActionCannotBeReadBack() async throws {
    let action = F.borrowAction()
    api.getActionHandler = { [unowned self] _ in throw self.backendError(404, #"{"error":"Action not found"}"#) }

    let error = await expectFailure(.pollingFailed) { try await self.execute(action) }

    XCTAssertEqual(YieldXyzBorrowApiError.from(error)?.status, 404)
    XCTAssertEqual(error?.action, action)
    XCTAssertEqual(signer.calls.count, 0)
  }

  // MARK: - Submission

  func test_failsWhenTheAcceptedSubmissionReportsTheTransactionFailed() async throws {
    let action = singleTransactionAction()
    fakeBackend(action)
    api.submitTransactionHandler = { _, _ in
      YieldXyzBorrowSubmitTransactionResult(transactionHash: F.approvalHash, link: "https://basescan.org", status: .failed, error: "execution reverted")
    }

    let error = await expectFailure(.submitFailed) { try await self.execute(action) }

    XCTAssertTrue(error?.message.contains("execution reverted") ?? false)
    XCTAssertEqual(error?.transactionHash, F.approvalHash)
  }

  func test_failsWithTheBackendErrorWhenTheSubmissionIsRejected() async throws {
    let action = singleTransactionAction()
    fakeBackend(action).submitFailures = [backendError(400, #"{"error":"Yield.xyz Borrow rejected the request: invalid hash"}"#)]

    let error = await expectFailure(.submitRejected) { try await self.execute(action) }

    XCTAssertEqual(YieldXyzBorrowApiError.from(error)?.message, "Yield.xyz Borrow rejected the request: invalid hash")
    XCTAssertEqual(api.submitTransactionCallsCount, 1)
  }

  func test_doesNotReconcileOrResubmitASubmissionTheApiRefusedBeforeSendingIt() async throws {
    let action = singleTransactionAction()
    fakeBackend(action).submitFailures = [YieldXyzBorrowError.emptyIdentifier(name: "transactionId")]

    let error = await expectFailure(.submitRejected) { try await self.execute(action) }

    XCTAssertEqual(error?.underlyingError as? YieldXyzBorrowError, .emptyIdentifier(name: "transactionId"))
    XCTAssertEqual(error?.broadcastHash, F.approvalHash)
    XCTAssertEqual(api.submitTransactionCallsCount, 1)
  }

  func test_doesNotRetryAReadTheApiRefusedBeforeSendingIt() async throws {
    let action = singleTransactionAction()
    api.getActionHandler = { _ in throw YieldXyzBorrowError.emptyIdentifier(name: "actionId") }

    let error = await expectFailure(.pollingFailed) { try await self.execute(action, self.options(poll: self.shortPoll)) }

    XCTAssertEqual(error?.underlyingError as? YieldXyzBorrowError, .emptyIdentifier(name: "actionId"))
    XCTAssertEqual(api.getActionCallsCount, 1)
    XCTAssertEqual(signer.calls.count, 0)
  }

  func test_treatsAnAmbiguousFailureAsSubmittedWhenTheActionShowsTheHashWasRecorded() async throws {
    let action = singleTransactionAction()
    let backend = fakeBackend(action)
    backend.submitFailures = [backendError(503)]
    backend.recordFailedSubmission = true
    backend.beforeRead = { [unowned backend] read in
      if read > 2 {
        backend.setStatus(.confirmed, for: "tx-approval")
      }
    }

    let result = try await execute(action)

    XCTAssertEqual(api.submitTransactionCallsCount, 1)
    XCTAssertEqual(result.transactions, [YieldXyzBorrowTransactionExecution(
      transactionId: "tx-approval",
      type: .approval,
      transactionHash: F.approvalHash,
      submitResult: nil
    )])
  }

  func test_resubmitsTheHashOnceWhenAnAmbiguousFailureLeftItUnrecorded() async throws {
    let action = singleTransactionAction()
    fakeBackend(action).submitFailures = [backendError(502)]

    let result = try await execute(action)

    XCTAssertEqual(result.status, .success)
    XCTAssertEqual(api.submitTransactionCallsCount, 2)
    XCTAssertEqual(signer.calls.count, 1)
  }

  func test_reconcilesATransportFailure() async throws {
    let action = singleTransactionAction()
    fakeBackend(action).submitFailures = [URLError(.networkConnectionLost)]

    let result = try await execute(action)

    XCTAssertEqual(result.status, .success)
    XCTAssertEqual(api.submitTransactionCallsCount, 2)
  }

  func test_givesUpWithoutResubmittingWhenTheActionReadBackNoLongerListsTheTransaction() async throws {
    let action = singleTransactionAction()
    let backend = fakeBackend(action)
    backend.submitFailures = [backendError(503), backendError(503)]
    backend.transformRead = { action, submits in submits > 0 ? action.with(transactions: []) : action }

    let error = await expectFailure(.submitOutcomeUnknown) { try await self.execute(action) }

    XCTAssertEqual(error?.transactionId, "tx-approval")
    XCTAssertEqual(error?.broadcastHash, F.approvalHash)
    XCTAssertEqual(error?.transactionHash, F.approvalHash)
    XCTAssertEqual(api.submitTransactionCallsCount, 1)
    XCTAssertEqual(signer.calls.count, 1)
  }

  func test_givesUpWhenTheOutcomeStaysUnknownAfterResubmitting() async throws {
    let action = singleTransactionAction()
    fakeBackend(action).submitFailures = [backendError(500), backendError(500), backendError(500)]

    _ = await expectFailure(.submitOutcomeUnknown) { try await self.execute(action) }

    XCTAssertEqual(api.submitTransactionCallsCount, 2)
    XCTAssertEqual(signer.calls.count, 1)
  }

  func test_failsWithActionFailed_withoutResubmitting_whenTheActionReadBackAfterAnAmbiguousFailureEnded() async throws {
    for status in [YieldXyzBorrowActionStatus.failed, .canceled, .stale] {
      resetState()
      let action = singleTransactionAction()
      let backend = fakeBackend(action)
      backend.submitFailures = [backendError(503), backendError(503)]
      backend.transformRead = { action, submits in submits > 0 ? Self.withStatus(action, status) : action }

      let error = await expectFailure(.actionFailed) { try await self.execute(action) }

      XCTAssertEqual(error?.transactionId, "tx-approval")
      XCTAssertEqual(error?.broadcastHash, F.approvalHash)
      XCTAssertEqual(error?.transactionHash, F.approvalHash)
      XCTAssertEqual(error?.action?.status, status)
      XCTAssertEqual(api.submitTransactionCallsCount, 1)
    }
  }

  func test_retriesARateLimitedSubmission() async throws {
    let action = singleTransactionAction()
    fakeBackend(action).submitFailures = [backendError(429)]

    let result = try await execute(action)

    XCTAssertEqual(result.status, .success)
    XCTAssertEqual(api.submitTransactionCallsCount, 2)
  }

  func test_rejectsASubmissionStillRateLimitedAfterTheRetries() async throws {
    let action = singleTransactionAction()
    fakeBackend(action).submitFailures = Array(repeating: backendError(429), count: 4)

    _ = await expectFailure(.submitRejected) { try await self.execute(action) }

    XCTAssertEqual(api.submitTransactionCallsCount, 4)
  }

  // MARK: - Checks before signing

  private func expectNotSigned(
    _ action: YieldXyzBorrowAction,
    _ reason: YieldXyzBorrowExecutionErrorReason,
    file: StaticString = #filePath,
    line: UInt = #line
  ) async -> YieldXyzBorrowExecutionError? {
    serve(action)
    let error = await expectFailure(reason, file: file, line: line) { try await self.execute(action) }
    XCTAssertEqual(signer.calls.count, 0, file: file, line: line)
    return error
  }

  func test_rejectsUnsupportedSigningFormats() async throws {
    for format in [YieldXyzBorrowSigningFormat.eip712TypedData, .solanaTransaction, nil] {
      resetState()
      let error = await expectNotSigned(
        F.borrowAction(transactions: [F.approvalTransaction(signingFormat: format)]),
        .unsupportedSigningFormat
      )
      XCTAssertEqual(error?.transactionId, "tx-approval")
    }
  }

  func test_rejectsNonEip155Networks() async throws {
    for network in ["base", "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp", "eip155:", "eip155:0x1"] {
      resetState()
      _ = await expectNotSigned(F.borrowAction(transactions: [F.approvalTransaction(network: network)]), .unsupportedNetwork)
    }
  }

  func test_rejectsAMalformedSignablePayload() async throws {
    let error = await expectNotSigned(
      F.borrowAction(transactions: [F.approvalTransaction(signablePayload: "0xf86c808504a8")]),
      .invalidSignablePayload
    )

    XCTAssertTrue(error?.message.contains("is not a JSON transaction object") ?? false)
  }

  func test_rejectsAMissingSignablePayload() async throws {
    _ = await expectNotSigned(F.borrowAction(transactions: [F.approvalTransaction(signablePayload: nil)]), .invalidSignablePayload)
  }

  func test_rejectsAPayloadWithoutFrom() async throws {
    let error = await expectNotSigned(
      F.borrowAction(transactions: [F.approvalTransaction(signablePayload: AnyCodable(#"{"to":"\#(F.usdcBase)","gasLimit":"56240"}"#))]),
      .invalidSignablePayload
    )

    XCTAssertTrue(error?.message.contains(#"has no valid "from" address"#) ?? false)
  }

  func test_rejectsATransactionBuiltForAnotherAddress() async throws {
    _ = await expectNotSigned(F.borrowAction(transactions: [F.approvalTransaction(address: F.otherWallet)]), .signerAddressMismatch)
  }

  func test_rejectsAPayloadWhoseFromIsAnotherAddress() async throws {
    let payload = AnyCodable(#"{"from":"\#(F.otherWallet)","to":"\#(F.usdcBase)","gasLimit":"56240"}"#)

    _ = await expectNotSigned(F.borrowAction(transactions: [F.approvalTransaction(signablePayload: payload)]), .signerAddressMismatch)
  }

  func test_rejectsAnActionBuiltForAnotherAddress() async throws {
    let error = await expectNotSigned(F.borrowAction(address: F.otherWallet), .signerAddressMismatch)

    XCTAssertTrue(error?.message.contains("Action act-1 was built for \(F.otherWallet)") ?? false)
  }

  func test_checksTheAddressOfTheActionAsYieldXyzLastListedItBeforeEachSignature() async throws {
    let action = F.borrowAction()
    fakeBackend(action).transformRead = { action, submits in
      guard submits > 0 else {
        return action
      }
      return YieldXyzBorrowAction(
        id: action.id,
        integrationId: action.integrationId,
        action: action.action,
        address: F.otherWallet,
        status: action.status,
        transactions: action.transactions,
        hasNextStep: action.hasNextStep,
        currentStep: action.currentStep,
        totalSteps: action.totalSteps,
        createdAt: action.createdAt
      )
    }

    let error = await expectFailure(.signerAddressMismatch) { try await self.execute(action) }

    XCTAssertEqual(error?.transactionId, "tx-supply")
    XCTAssertEqual(signer.calls.count, 1)
  }

  func test_rejectsAChainWithNoRpcEndpointConfigured() async throws {
    chainConfigured = false

    _ = await expectNotSigned(F.borrowAction(), .signingChainNotConfigured)

    XCTAssertEqual(chainConfiguredCalls, [F.base])
  }

  func test_doesNotNeedAnRpcEndpointForAChainThePerCallSignerSignsOn() async throws {
    chainConfigured = false
    let action = singleTransactionAction()
    fakeBackend(action)
    var overrideChains: [String] = []

    let result = try await execute(action, options(signAndSendTransaction: { _, chainId, _ in
      overrideChains.append(chainId)
      return F.approvalHash
    }))

    XCTAssertEqual(result.status, .success)
    XCTAssertEqual(overrideChains, [F.base])
    XCTAssertEqual(chainConfiguredCalls, [])
  }

  func test_failsWhenNoWalletAddressIsAvailable() async throws {
    walletAddress = nil

    _ = await expectNotSigned(F.borrowAction(), .missingWalletAddress)
  }

  func test_failsWhenNoSignerIsConfigured() async throws {
    serve(F.borrowAction())

    let error = await expectFailure(.dependencyUnavailable) { try await self.execute(F.borrowAction(), on: self.makeBorrow(signer: false)) }

    XCTAssertEqual(error?.errorDescription, "[YieldXyzBorrow] No transaction signer is configured.")
  }

  func test_failsWhenNoTransactionLookupIsConfigured() async throws {
    serve(F.borrowAction())

    let error = await expectFailure(.dependencyUnavailable) { try await self.execute(F.borrowAction(), on: self.makeBorrow(lookup: false)) }

    XCTAssertEqual(error?.errorDescription, "[YieldXyzBorrow] No transaction lookup is configured.")
    XCTAssertEqual(signer.calls.count, 0)
  }

  func test_namesBothWhenNeitherTheSignerNorTheTransactionLookupIsConfigured() async throws {
    serve(F.borrowAction())

    let error = await expectFailure(.dependencyUnavailable) {
      try await self.execute(F.borrowAction(), on: self.makeBorrow(signer: false, lookup: false))
    }

    XCTAssertEqual(error?.errorDescription, "[YieldXyzBorrow] No transaction signer and transaction lookup are configured.")
  }

  func test_aPublicInstanceWithAnApiThatCannotLookUpTransactionsFailsWithDependencyUnavailable() async throws {
    serve(F.borrowAction())
    let instance = YieldXyzBorrow(api: api, dependencies: dependencies())

    let error = await expectFailure(.dependencyUnavailable) { try await self.execute(F.borrowAction(), on: instance) }

    XCTAssertEqual(error?.errorDescription, "[YieldXyzBorrow] No transaction lookup is configured.")
  }

  // MARK: - Signing results

  func test_reportsASigningRequestThatWasNotApproved() async throws {
    serve(singleTransactionAction())
    signer.results = [.success(nil)]

    _ = await expectFailure(.signatureRejected) { try await self.execute(self.singleTransactionAction()) }

    XCTAssertEqual(api.submitTransactionCallsCount, 0)
  }

  func test_rejectsAValueThatIsNotATransactionHash() async throws {
    for hash in ["", "0x1234", "0x" + String(repeating: "zz", count: 32)] {
      resetState()
      serve(singleTransactionAction())
      signer.results = [.success(hash)]

      _ = await expectFailure(.invalidTransactionHash) { try await self.execute(self.singleTransactionAction()) }

      XCTAssertEqual(lookup.callsCount, 0, hash)
    }
  }

  func test_wrapsASignerFailureWithItsCause() async throws {
    serve(singleTransactionAction())
    signer.results = [.failure(PortalMpcError(PortalError(code: nil, id: nil, message: "MPC signing failed")))]

    let error = await expectFailure(.signingFailed) { try await self.execute(self.singleTransactionAction()) }

    XCTAssertTrue(error?.underlyingError is PortalMpcError)
  }

  // MARK: - Progress

  func test_reportsEachStageOfATransaction() async throws {
    let action = singleTransactionAction()
    fakeBackend(action)
    var progress: [YieldXyzBorrowExecutionProgress] = []

    _ = try await execute(action, options(onProgress: { progress.append($0) }))

    XCTAssertEqual(progress.map(\.step), [.polling, .signing, .confirming, .submitted, .polling, .confirmed])
    XCTAssertEqual(progress[1].index, 0)
    XCTAssertEqual(progress[2].actionId, "act-1")
    XCTAssertEqual(progress[2].transactionId, "tx-approval")
    XCTAssertEqual(progress[2].broadcastHash, F.approvalHash)
    XCTAssertEqual(progress[3].transactionHash, F.approvalHash)
    XCTAssertEqual(progress[5].transactionHash, F.approvalHash)
  }

  func test_reportsAFailureWithTheExecutionError() async throws {
    walletAddress = nil
    var progress: [YieldXyzBorrowExecutionProgress] = []

    _ = await expectFailure(.missingWalletAddress) { try await self.execute(F.borrowAction(), self.options(onProgress: { progress.append($0) })) }

    XCTAssertEqual(progress.map(\.step), [.failed])
    XCTAssertEqual(progress.first?.actionId, "act-1")
    XCTAssertEqual(progress.first?.error?.reason, .missingWalletAddress)
  }

  // MARK: - Concurrent calls

  func test_rejectsASecondCallOnAnActionStillExecuting_withoutSigningForIt() async throws {
    let action = singleTransactionAction()
    fakeBackend(action)
    let gate = SignatureGate()
    signer.gate = gate
    let options = self.options()
    let first = Task { try await self.borrow.signAndSubmitAction(action, options: options) }
    await gate.waitUntilStarted()
    var progress: [YieldXyzBorrowExecutionProgress] = []

    let error = await expectFailure(.actionInProgress) { try await self.execute(action, self.options(onProgress: { progress.append($0) })) }
    gate.release(F.approvalHash)

    XCTAssertEqual(error?.actionId, "act-1")
    XCTAssertEqual(progress.map(\.step), [.failed])
    let firstResult = try await first.value
    XCTAssertEqual(firstResult.status, .success)
    XCTAssertEqual(signer.callsCount, 1)
    XCTAssertEqual(api.submitTransactionCallsCount, 1)
  }

  func test_executesAnotherActionWhileOneIsStillExecuting() async throws {
    let first = F.borrowAction(transactions: [F.approvalTransaction()])
    let other = F.borrowAction(id: "act-2", transactions: [F.supplyTransaction()])
    let firstBackend = FakeBackend(first)
    let otherBackend = FakeBackend(other)
    api.getActionHandler = { actionId in try actionId == "act-1" ? firstBackend.read() : otherBackend.read() }
    api.submitTransactionHandler = { transactionId, params in
      try transactionId == "tx-approval" ? firstBackend.submit(transactionId, params) : otherBackend.submit(transactionId, params)
    }
    let gate = SignatureGate()
    signer.gate = gate
    let options = self.options()
    let running = Task { try await self.borrow.signAndSubmitAction(first, options: options) }
    await gate.waitUntilStarted()

    let otherResult = try await execute(other)
    gate.release(F.approvalHash)
    let firstResult = try await running.value

    XCTAssertEqual(otherResult.actionId, "act-2")
    XCTAssertEqual(otherResult.status, .success)
    XCTAssertEqual(firstResult.actionId, "act-1")
    XCTAssertEqual(firstResult.status, .success)
    assertSubmitted([("tx-supply", F.supplyHash), ("tx-approval", F.approvalHash)])
  }

  func test_acceptsANewCallOnTheActionOnceTheEarlierCallSucceeded() async throws {
    let action = singleTransactionAction()
    fakeBackend(action)

    _ = try await execute(action)
    let again = try await execute(action)

    XCTAssertEqual(again.status, .success)
    XCTAssertEqual(signer.calls.count, 1)
  }

  func test_acceptsANewCallOnTheActionOnceTheEarlierCallFailed() async throws {
    let action = singleTransactionAction()
    fakeBackend(action)
    signer.results = [.failure(URLError(.notConnectedToInternet)), .success(F.approvalHash)]

    _ = await expectFailure(.signingFailed) { try await self.execute(action) }
    let again = try await execute(action)

    XCTAssertEqual(again.status, .success)
    XCTAssertEqual(signer.calls.count, 2)
  }

  // MARK: - Resuming after a broadcast

  func test_doesNotSignATransactionListedInBroadcastHashes_andSubmitsItsBroadcastHash() async throws {
    let action = F.borrowAction()
    fakeBackend(action)
    signer.results = [.success(F.supplyHash)]

    let result = try await execute(action, options(broadcastHashes: ["tx-approval": F.approvalHash]))

    XCTAssertEqual(signer.calls.count, 1)
    XCTAssertEqual(signer.calls.first?.param.to, F.aavePoolBase)
    XCTAssertEqual(lookup.calls.first?.chainId, F.base)
    XCTAssertEqual(lookup.calls.first?.hash, F.approvalHash)
    assertSubmitted([("tx-approval", F.approvalHash), ("tx-supply", F.supplyHash)])
    XCTAssertEqual(result.status, .success)
    XCTAssertEqual(result.transactions.map(\.transactionHash), [F.approvalHash, F.supplyHash])
  }

  func test_doesNotSubmitATransactionListedInBroadcastHashesOnceTheActionEnds() async throws {
    for status in [YieldXyzBorrowActionStatus.failed, .canceled, .stale] {
      resetState()
      let action = F.borrowAction()
      fakeBackend(action).transformRead = { action, submits in submits > 0 ? Self.withStatus(action, status) : action }

      let error = await expectFailure(.actionFailed) { try await self.execute(action, self.options(broadcastHashes: ["tx-supply": F.supplyHash])) }

      XCTAssertEqual(error?.transactionId, "tx-supply")
      XCTAssertEqual(error?.broadcastHash, F.supplyHash)
      XCTAssertEqual(error?.action?.status, status)
      XCTAssertEqual(signer.calls.count, 1)
      XCTAssertFalse(lookup.calls.contains { $0.hash == F.supplyHash })
      assertSubmitted([("tx-approval", F.approvalHash)])
    }
  }

  func test_recoversListedTransactionsAcrossSteps() async throws {
    let stepOne = F.borrowAction(transactions: [F.approvalTransaction()], hasNextStep: true, totalSteps: 2)
    let stepTwo = F.borrowAction(transactions: [F.supplyTransaction(id: "tx-step-2")], currentStep: 2, totalSteps: 2)
    TwoStepBackend(stepOne, stepTwo).install(on: api)

    let result = try await execute(stepOne, options(broadcastHashes: ["tx-approval": F.approvalHash, "tx-step-2": F.supplyHash]))

    XCTAssertEqual(signer.calls.count, 0)
    XCTAssertEqual(api.stepActionCallsCount, 1)
    assertSubmitted([("tx-approval", F.approvalHash), ("tx-step-2", F.supplyHash)])
    XCTAssertEqual(result.status, .success)
  }

  func test_signsAsUsualWhenBroadcastHashesListsOnlyOtherTransactions() async throws {
    let action = F.borrowAction()
    fakeBackend(action)
    let otherHash = "0x" + String(repeating: "ee", count: 32)

    _ = try await execute(action, options(broadcastHashes: ["tx-from-another-action": otherHash]))

    XCTAssertEqual(signer.calls.count, 2)
    XCTAssertFalse(lookup.calls.contains { $0.hash == otherHash })
  }

  func test_stillWaitsForYieldXyzToConfirmARecoveredTransaction() async throws {
    let action = singleTransactionAction()
    let backend = fakeBackend(action)
    backend.statusAfterSubmit = .broadcasted
    backend.beforeRead = { [unowned backend] read in
      if read == 4 {
        backend.setStatus(.confirmed, for: "tx-approval")
      }
    }
    var progress: [YieldXyzBorrowExecutionProgress] = []

    let result = try await execute(action, options(broadcastHashes: ["tx-approval": F.approvalHash], onProgress: { progress.append($0) }))

    XCTAssertEqual(api.getActionCallsCount, 4)
    XCTAssertEqual(result.status, .success)
    XCTAssertEqual(progress.map(\.step), [.polling, .confirming, .submitted, .polling, .polling, .polling, .confirmed])
  }

  func test_waitsForARecoveredTransactionYieldXyzAlreadyRecorded_withoutSigningOrSubmittingItAgain() async throws {
    let action = F.borrowAction(transactions: [F.approvalTransaction(status: .broadcasted)])
    let backend = fakeBackend(action)
    backend.beforeRead = { [unowned backend] read in
      if read == 3 {
        backend.setStatus(.confirmed, for: "tx-approval")
      }
    }

    let result = try await execute(action, options(broadcastHashes: ["tx-approval": F.approvalHash]))

    XCTAssertEqual(api.getActionCallsCount, 3)
    XCTAssertEqual(signer.calls.count, 0)
    XCTAssertEqual(lookup.callsCount, 0)
    XCTAssertEqual(api.submitTransactionCallsCount, 0)
    XCTAssertEqual(result.status, .success)
  }

  func test_submitsTheBundleTransactionHashWhenRecoveringAnAccountAbstractedTransaction() async throws {
    let action = singleTransactionAction()
    fakeBackend(action)
    lookup.results = [
      .failure(backendError(404)),
      .success(F.userOperationLookup(receiptHash: nil)),
      .success(F.userOperationLookup(receiptHash: F.bundleHash))
    ]

    let result = try await execute(action, options(broadcastHashes: ["tx-approval": F.userOperationHash]))

    XCTAssertEqual(signer.calls.count, 0)
    XCTAssertEqual(lookup.calls.first?.hash, F.userOperationHash)
    assertSubmitted([("tx-approval", F.bundleHash)])
    XCTAssertEqual(result.transactions.first?.transactionHash, F.bundleHash)
    XCTAssertEqual(result.transactions.first?.userOperationHash, F.userOperationHash)
  }

  func test_failsARecoveredUserOperationThatDidNotSucceed_withoutSubmittingIt() async throws {
    let action = singleTransactionAction()
    serve(action)
    lookup.fallback = .success(F.userOperationLookup(receiptHash: F.bundleHash, success: false))

    let error = await expectFailure(.userOperationFailed) {
      try await self.execute(action, self.options(broadcastHashes: ["tx-approval": F.userOperationHash]))
    }

    XCTAssertEqual(error?.broadcastHash, F.userOperationHash)
    XCTAssertEqual(api.submitTransactionCallsCount, 0)
    XCTAssertEqual(signer.calls.count, 0)
  }

  func test_keepsTheBroadcastHashOnASubmissionFailureWhileRecovering() async throws {
    let action = singleTransactionAction()
    fakeBackend(action).submitFailures = [backendError(400, #"{"error":"Invalid hash"}"#)]

    let error = await expectFailure(.submitRejected) {
      try await self.execute(action, self.options(broadcastHashes: ["tx-approval": F.approvalHash]))
    }

    XCTAssertEqual(error?.actionId, "act-1")
    XCTAssertEqual(error?.transactionId, "tx-approval")
    XCTAssertEqual(error?.broadcastHash, F.approvalHash)
    XCTAssertEqual(error?.transactionHash, F.approvalHash)
    XCTAssertEqual(signer.calls.count, 0)
  }

  func test_keepsTheBroadcastHashWhenResolvingARecoveredTransactionTimesOut() async throws {
    let action = singleTransactionAction()
    serve(action)
    lookup.fallback = .failure(backendError(404))

    let error = await expectFailure(.timeout) {
      try await self.execute(action, self.options(poll: self.shortPoll, broadcastHashes: ["tx-approval": F.userOperationHash]))
    }

    XCTAssertEqual(error?.broadcastHash, F.userOperationHash)
    XCTAssertEqual(signer.calls.count, 0)
  }

  func test_aLookupTimeoutDoesNotReportAnEarlierTransientErrorAsItsCause() async throws {
    let action = singleTransactionAction()
    serve(action)
    lookup.results = [.failure(backendError(503))]
    lookup.fallback = .failure(backendError(404))

    let error = await expectFailure(.timeout) { try await self.execute(action, self.options(poll: self.shortPoll)) }

    XCTAssertGreaterThan(lookup.callsCount, 1)
    XCTAssertNil(error?.underlyingError)
  }

  func test_validatesARecoveredTransactionAndItsActionBeforeContinuing() async throws {
    for action in [
      F.borrowAction(transactions: [F.approvalTransaction(address: F.otherWallet)]),
      F.borrowAction(address: F.otherWallet, transactions: [F.approvalTransaction()])
    ] {
      resetState()
      serve(action)

      let error = await expectFailure(.signerAddressMismatch) {
        try await self.execute(action, self.options(broadcastHashes: ["tx-approval": F.approvalHash]))
      }

      XCTAssertEqual(error?.broadcastHash, F.approvalHash)
      XCTAssertEqual(lookup.callsCount, 0)
      XCTAssertEqual(api.submitTransactionCallsCount, 0)
    }
  }

  func test_rejectsASuppliedBroadcastHashThatIsNotATransactionHash() async throws {
    serve(F.borrowAction())

    _ = await expectFailure(.invalidTransactionHash) {
      try await self.execute(F.borrowAction(), self.options(broadcastHashes: ["tx-approval": "0x1234"]))
    }

    XCTAssertEqual(lookup.callsCount, 0)
    XCTAssertEqual(signer.calls.count, 0)
  }

  func test_recoversWithoutASigner_andNeedsTheTransactionLookupToDoSo() async throws {
    let action = singleTransactionAction()
    fakeBackend(action)
    let options = self.options(broadcastHashes: ["tx-approval": F.approvalHash])

    let recovered = try await execute(action, options, on: makeBorrow(signer: false))
    XCTAssertEqual(recovered.status, .success)

    serve(action)
    _ = await expectFailure(.dependencyUnavailable) { try await self.execute(action, options, on: self.makeBorrow(signer: false, lookup: false)) }
  }

  func test_keepsTheHashesAndTheActionInSigningOrderWhenPollingFailsAfterTheSubmission() async throws {
    let action = F.borrowAction()
    let backend = fakeBackend(action)
    backend.reorder = true
    backend.transformRead = { [unowned self] action, submits in
      if submits > 0 {
        throw self.backendError(404, #"{"error":"Action not found"}"#)
      }
      return action
    }
    signer.results = []
    signer.defaultResult = .success(F.userOperationHash)
    lookup.fallback = .success(F.userOperationLookup(receiptHash: F.bundleHash))

    let error = await expectFailure(.pollingFailed) { try await self.execute(action) }

    assertSubmitted([("tx-approval", F.bundleHash)])
    XCTAssertEqual(error?.transactionId, "tx-approval")
    XCTAssertEqual(error?.broadcastHash, F.userOperationHash)
    XCTAssertEqual(error?.transactionHash, F.bundleHash)
    XCTAssertEqual(error?.userOperationHash, F.userOperationHash)
    XCTAssertEqual(error?.action?.transactions.map(\.id), ["tx-approval", "tx-supply"])
  }

  func test_reportsTheActionOfAFailureInSigningOrder_soResumingFromItCannotSignOutOfOrder() async throws {
    let action = F.borrowAction()
    let backend = fakeBackend(action)
    backend.reorder = true
    var submits = 0
    api.submitTransactionHandler = { [unowned self] transactionId, params in
      submits += 1
      if transactionId == "tx-supply", submits == 2 {
        throw self.backendError(400, #"{"error":"Temporarily rejected"}"#)
      }
      return try backend.submit(transactionId, params)
    }

    let failure = await expectFailure(.submitRejected) { try await self.execute(action) }
    XCTAssertEqual(failure?.action?.transactions.map(\.id), ["tx-approval", "tx-supply"])

    let failedAction = try XCTUnwrap(failure?.action)
    let transactionId = try XCTUnwrap(failure?.transactionId)
    let broadcastHash = try XCTUnwrap(failure?.broadcastHash)
    let resumed = try await execute(failedAction, options(broadcastHashes: [transactionId: broadcastHash]))

    XCTAssertEqual(signer.calls.map(\.param.to), [F.usdcBase, F.aavePoolBase])
    XCTAssertEqual(submittedCalls.map(\.0), ["tx-approval", "tx-supply", "tx-supply"])
    XCTAssertEqual(resumed.status, .success)
  }

  func test_reportsTheLatestActionInSigningOrderAfterAFailureThatFollowsTheBroadcast() async throws {
    for reason in [YieldXyzBorrowExecutionErrorReason.timeout, .submitRejected, .userOperationFailed] {
      resetState()
      let action = F.borrowAction()
      fakeBackend(action).reorder = true
      switch reason {
      case .timeout:
        lookup.fallback = .failure(backendError(404))
      case .submitRejected:
        api.submitTransactionHandler = { [unowned self] _, _ in throw self.backendError(400) }
      default:
        lookup.fallback = .success(F.userOperationLookup(receiptHash: F.bundleHash, success: false))
      }

      let failure = await expectFailure(reason) { try await self.execute(action, self.options(poll: self.shortPoll)) }

      XCTAssertNotNil(failure?.broadcastHash, "\(reason)")
      XCTAssertEqual(failure?.action?.transactions.map(\.id), ["tx-approval", "tx-supply"], "\(reason)")
    }
  }

  func test_neverSignsTwiceWhenAnEoaAttemptIsResumedWithTheHashItsErrorReported() async throws {
    let action = singleTransactionAction()
    fakeBackend(action).submitFailures = [backendError(400, #"{"error":"Temporarily rejected"}"#)]

    let failure = await expectFailure(.submitRejected) { try await self.execute(action) }
    let transactionId = try XCTUnwrap(failure?.transactionId)
    let broadcastHash = try XCTUnwrap(failure?.broadcastHash)
    let resumed = try await execute(action, options(broadcastHashes: [transactionId: broadcastHash]))

    XCTAssertEqual(signer.calls.count, 1)
    XCTAssertEqual(resumed.status, .success)
  }

  func test_neverSignsTwiceWhenAnAccountAbstractedAttemptIsResumedAfterALookupTimeout() async throws {
    let action = singleTransactionAction()
    fakeBackend(action)
    signer.results = []
    signer.defaultResult = .success(F.userOperationHash)
    lookup.fallback = .failure(backendError(404))

    let failure = await expectFailure(.timeout) { try await self.execute(action, self.options(poll: self.shortPoll)) }
    lookup.fallback = .success(F.userOperationLookup(receiptHash: F.bundleHash))
    let transactionId = try XCTUnwrap(failure?.transactionId)
    let broadcastHash = try XCTUnwrap(failure?.broadcastHash)
    _ = try await execute(action, options(broadcastHashes: [transactionId: broadcastHash]))

    XCTAssertEqual(broadcastHash, F.userOperationHash)
    XCTAssertEqual(signer.calls.count, 1)
    assertSubmitted([("tx-approval", F.bundleHash)])
  }

  // MARK: - Signing order

  func test_signsInTheOrderOfTheActionPassedIn_whenGetActionListsTheTransactionsReversed() async throws {
    let action = F.borrowAction()
    fakeBackend(action).reorder = true

    let result = try await execute(action)

    XCTAssertEqual(signer.calls.map(\.param.to), [F.usdcBase, F.aavePoolBase])
    XCTAssertEqual(submittedCalls.map(\.0), ["tx-approval", "tx-supply"])
    XCTAssertEqual(result.action.transactions.map(\.id), ["tx-approval", "tx-supply"])
  }

  func test_doesNotSignAnApprovalYieldXyzAlreadyConfirmed_evenWhenTheActionPassedInIsStale() async throws {
    let action = F.borrowAction()
    let backend = fakeBackend(action)
    backend.reorder = true
    backend.setStatus(.confirmed, for: "tx-approval")
    signer.results = [.success(F.supplyHash)]

    _ = try await execute(action)

    XCTAssertEqual(signer.calls.map(\.param.to), [F.aavePoolBase])
    assertSubmitted([("tx-supply", F.supplyHash)])
  }

  func test_resumesABroadcastApprovalWithoutSigningIt_thenSignsSupply_whenGetActionListsThemReversed() async throws {
    let action = F.borrowAction()
    fakeBackend(action).reorder = true
    signer.results = [.success(F.supplyHash)]

    _ = try await execute(action, options(broadcastHashes: ["tx-approval": F.approvalHash]))

    XCTAssertEqual(signer.calls.map(\.param.to), [F.aavePoolBase])
    assertSubmitted([("tx-approval", F.approvalHash), ("tx-supply", F.supplyHash)])
  }

  func test_inSigningOrder_putsKnownIdsFirstAndAppendsUnknownOnes() {
    let action = F.borrowAction(transactions: [
      F.supplyTransaction(id: "b"),
      F.approvalTransaction(id: "new"),
      F.approvalTransaction(id: "a")
    ])

    let ordered = YieldXyzBorrow.inSigningOrder(action, ["a", "b", "gone"])

    XCTAssertEqual(ordered.transactions.map(\.id), ["a", "b", "new"])
  }

  // MARK: - Idempotency keys (native)

  func test_sendsNoIdempotencyKeyWhenOptedOut() async throws {
    let action = singleTransactionAction()
    fakeBackend(action)

    _ = try await execute(action, options(useIdempotencyKeys: false))

    XCTAssertEqual(signer.calls.count, 1)
    XCTAssertNil(signer.calls.first?.idempotencyKey)
  }

  func test_retriesASendPortalReportsInProgress_withTheSameKey() async throws {
    let action = singleTransactionAction()
    fakeBackend(action)
    signer.results = [
      .failure(idempotencyError(PortalIdempotencyErrorId.requestInProgress)),
      .failure(idempotencyError(PortalIdempotencyErrorId.requestInProgress)),
      .success(F.approvalHash)
    ]

    let result = try await execute(action)

    XCTAssertEqual(result.status, .success)
    XCTAssertEqual(signer.calls.map(\.idempotencyKey), Array(repeating: "yieldxyz-borrow-tx-approval", count: 3))
  }

  func test_failsWhenASendStaysInProgress() async throws {
    serve(singleTransactionAction())
    signer.results = []
    signer.defaultResult = .failure(idempotencyError(PortalIdempotencyErrorId.requestInProgress))

    let error = await expectFailure(.signingFailed) { try await self.execute(self.singleTransactionAction()) }

    XCTAssertEqual(signer.calls.count, 4)
    XCTAssertTrue(error?.message.contains("resume the action later") ?? false)
  }

  func test_failsWithTransactionAlreadyBroadcastWhenPortalAlreadySentTheTransaction() async throws {
    serve(singleTransactionAction())
    signer.results = [.failure(idempotencyError(PortalIdempotencyErrorId.requestAlreadyCompleted))]

    let error = await expectFailure(.transactionAlreadyBroadcast) { try await self.execute(self.singleTransactionAction()) }

    XCTAssertEqual(error?.transactionId, "tx-approval")
    XCTAssertTrue(error?.message.contains("broadcastHash") ?? false)
    XCTAssertEqual(api.submitTransactionCallsCount, 0)
    XCTAssertEqual(lookup.callsCount, 0)
  }

  func test_failsWithSigningFailedOnAnyOtherIdempotencyRejection() async throws {
    serve(singleTransactionAction())
    signer.results = [.failure(idempotencyError("IDEMPOTENCY_KEY_REUSED"))]

    let error = await expectFailure(.signingFailed) { try await self.execute(self.singleTransactionAction()) }

    XCTAssertTrue(error?.message.contains("IDEMPOTENCY_KEY_REUSED") ?? false)
  }

  func test_afterAFailedUserOperation_signingAgainNeedsTheOptOut() async throws {
    let action = singleTransactionAction()
    serve(action)
    signer.results = [
      .success(F.userOperationHash),
      .failure(idempotencyError(PortalIdempotencyErrorId.requestAlreadyCompleted))
    ]
    lookup.fallback = .success(F.userOperationLookup(receiptHash: F.bundleHash, success: false))

    _ = await expectFailure(.userOperationFailed) { try await self.execute(action) }
    _ = await expectFailure(.transactionAlreadyBroadcast) { try await self.execute(action) }

    fakeBackend(action)
    lookup.fallback = nil
    signer.results = [.success(F.approvalHash)]
    let retried = try await execute(action, options(useIdempotencyKeys: false))

    XCTAssertEqual(retried.status, .success)
    XCTAssertEqual(signer.calls.map(\.idempotencyKey), ["yieldxyz-borrow-tx-approval", "yieldxyz-borrow-tx-approval", nil])
  }

  // MARK: - Cancellation (native)

  func test_cancellationBeforeABroadcast_stopsWithCancellationError() async throws {
    let action = singleTransactionAction()
    let firstReadFailed = EventLog()
    api.getActionHandler = { [unowned self] _ in
      // The first read fails transiently, so the runner sleeps before reading again.
      firstReadFailed.append("failed")
      throw self.backendError(503)
    }
    let task = Task { try await self.execute(action, self.options(poll: YieldXyzBorrowPollOptions(intervalSeconds: 5, timeoutSeconds: 30))) }
    while firstReadFailed.all.isEmpty {
      try await Task.sleep(nanoseconds: 1_000_000)
    }
    task.cancel()

    do {
      _ = try await task.value
      XCTFail("Expected the execution to be cancelled")
    } catch {
      XCTAssertTrue(error is CancellationError)
    }
    XCTAssertEqual(signer.calls.count, 0)
  }

  func test_cancellationWhileResolvingABroadcastTransaction_keepsItsHash() async throws {
    let action = singleTransactionAction()
    serve(action)
    lookup.fallback = .failure(backendError(404))
    let task = Task { try await self.execute(action, self.options(poll: YieldXyzBorrowPollOptions(intervalSeconds: 0.05, timeoutSeconds: 30))) }
    while lookup.callsCount == 0 {
      try await Task.sleep(nanoseconds: 1_000_000)
    }
    task.cancel()

    do {
      _ = try await task.value
      XCTFail("Expected the execution to fail")
    } catch let error as YieldXyzBorrowExecutionError {
      XCTAssertEqual(error.reason, .submitOutcomeUnknown)
      XCTAssertEqual(error.transactionId, "tx-approval")
      XCTAssertEqual(error.broadcastHash, F.approvalHash)
      XCTAssertTrue(error.underlyingError is CancellationError)
    }
    XCTAssertEqual(signer.calls.count, 1)
    XCTAssertEqual(api.submitTransactionCallsCount, 0)
  }

  // MARK: - Helpers

  private static func withStatus(_ action: YieldXyzBorrowAction, _ status: YieldXyzBorrowActionStatus) -> YieldXyzBorrowAction {
    YieldXyzBorrowAction(
      id: action.id,
      integrationId: action.integrationId,
      action: action.action,
      address: action.address,
      status: status,
      transactions: action.transactions,
      hasNextStep: action.hasNextStep,
      currentStep: action.currentStep,
      totalSteps: action.totalSteps,
      rawArguments: action.rawArguments,
      metadata: action.metadata,
      createdAt: action.createdAt
    )
  }
}
