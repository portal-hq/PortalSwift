//
//  YieldXyzBorrow.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Yield.xyz Borrow: supply, borrow, repay and withdraw on lending markets such as Morpho Blue and
/// Aave.
///
/// Integrations (`integrationId`) and markets (`marketId`) are opaque identifiers; discover them
/// with `getIntegrations()` and `getMarkets(params:)` instead of hard-coding them. Chains are CAIP-2
/// (`eip155:8453`). Show an action's `metadata` (predicted health factor and LTV) before the user
/// signs.
public protocol YieldXyzBorrowProtocol: AnyObject {
  /// Gets the Yield.xyz Borrow API health.
  func getHealth() async throws -> YieldXyzBorrowGetHealthResponse

  /// Lists the lending integrations (Aave, Morpho Blue, …) and the actions each supports.
  func getIntegrations() async throws -> YieldXyzBorrowGetIntegrationsResponse
  /// Gets one integration, with the schema of each action's `args`.
  func getIntegration(integrationId: String) async throws -> YieldXyzBorrowGetIntegrationResponse

  /// Lists lending markets. Without `scope`, Yield.xyz lists only the markets enabled in its
  /// dashboard; pass `.all` to list every market.
  func getMarkets(params: YieldXyzBorrowGetMarketsParams) async throws -> YieldXyzBorrowGetMarketsResponse
  /// Gets one market.
  func getMarket(marketId: String) async throws -> YieldXyzBorrowGetMarketResponse

  /// Gets an address's supply and borrow position on one integration and chain.
  func getPositions(params: YieldXyzBorrowGetPositionsParams) async throws -> YieldXyzBorrowGetPositionsResponse
  /// Lists an address's liquidations on one integration and chain.
  func getLiquidations(params: YieldXyzBorrowGetLiquidationsParams) async throws -> YieldXyzBorrowGetLiquidationsResponse

  /// Builds a lending action and returns it with the **unsigned** transactions of its first step.
  /// Nothing is signed or submitted: pass the action to `signAndSubmitAction`, or use
  /// `executeAction` to do both.
  func createAction(params: YieldXyzBorrowCreateActionParams) async throws -> YieldXyzBorrowActionResponse
  /// Lists an address's actions.
  func getActions(params: YieldXyzBorrowGetActionsParams) async throws -> YieldXyzBorrowGetActionsResponse
  /// Gets one action with the transactions of its current step.
  func getAction(actionId: String) async throws -> YieldXyzBorrowActionResponse
  /// Fetches the next step's transactions; call it once the current step is confirmed and
  /// `hasNextStep` is `true`.
  func stepAction(actionId: String) async throws -> YieldXyzBorrowActionResponse

  /// Submits the hash of a broadcast transaction (`transactionHash`) or a signed payload
  /// (`signedPayload`) for one transaction. A response whose `data.status` is `FAILED` is still a
  /// failure.
  func submitTransaction(transactionId: String, params: YieldXyzBorrowSubmitTransactionParams) async throws -> YieldXyzBorrowSubmitTransactionResponse

  /// Creates an action, then signs, submits and tracks it to completion (see
  /// `signAndSubmitAction`). To show the predicted health factor before the user signs, call
  /// `createAction` and then `signAndSubmitAction` instead.
  func executeAction(params: YieldXyzBorrowCreateActionParams, options: YieldXyzBorrowExecuteOptions) async throws -> YieldXyzBorrowExecutionResult

  /// Executes an existing action step by step. The action is read back first: its current state on
  /// Yield.xyz decides what still needs signing, and the transactions of the action passed in give
  /// the signing order, matched by id. Pass an action whose transactions are in signing order: the
  /// one `createAction` returned, the `action` of the latest `nextStep` progress event, or the
  /// `action` of an execution result or of a `YieldXyzBorrowExecutionError`. `getAction` may list
  /// transactions in a different order.
  ///
  /// Each `EVM_TRANSACTION` awaiting a signature (`CREATED` or `WAITING_FOR_SIGNATURE`) is sent with
  /// `eth_sendTransaction` on its own chain, with the idempotency key
  /// `yieldxyz-borrow-<transactionId>` unless `useIdempotencyKeys` is `false`. The on-chain
  /// transaction hash (the bundle transaction's for an account-abstracted client) is submitted to
  /// Yield.xyz, and the action is polled until Yield.xyz confirms the transaction before the next
  /// one is signed. When the confirmed step has `hasNextStep`, the next step is fetched and executed
  /// the same way, until the action succeeds.
  ///
  /// Failures throw `YieldXyzBorrowExecutionError` carrying the action and transaction ids. To
  /// resume, call this again with the error's `action`. An error with a `broadcastHash` belongs to
  /// a transaction that was already broadcast: pass it in `broadcastHashes`, so that transaction is
  /// resolved and submitted instead of signed again (except after `userOperationFailed`). A call
  /// made while another call on this instance is still executing the same action fails with
  /// `actionInProgress` and signs nothing.
  ///
  /// Cancelling the surrounding task stops the execution with `CancellationError`, except while a
  /// broadcast transaction is being resolved and submitted: then it fails with
  /// `submitOutcomeUnknown` carrying that transaction's `broadcastHash`. The `confirming` progress
  /// event also reports the hash as soon as the transaction is broadcast.
  func signAndSubmitAction(_ action: YieldXyzBorrowAction, options: YieldXyzBorrowExecuteOptions) async throws -> YieldXyzBorrowExecutionResult
}

public extension YieldXyzBorrowProtocol {
  /// Convenience overload of `getMarkets` without filters.
  func getMarkets() async throws -> YieldXyzBorrowGetMarketsResponse {
    try await getMarkets(params: YieldXyzBorrowGetMarketsParams())
  }

  /// Convenience overload of `executeAction` with default options.
  func executeAction(params: YieldXyzBorrowCreateActionParams) async throws -> YieldXyzBorrowExecutionResult {
    try await executeAction(params: params, options: YieldXyzBorrowExecuteOptions())
  }

  /// Convenience overload of `signAndSubmitAction` with default options.
  func signAndSubmitAction(_ action: YieldXyzBorrowAction) async throws -> YieldXyzBorrowExecutionResult {
    try await signAndSubmitAction(action, options: YieldXyzBorrowExecuteOptions())
  }
}

/// Timing of the execution runner's retries. Production uses `.standard`; tests shorten it.
struct YieldXyzBorrowRetryPolicy {
  /// Waits before retrying a submission or a next-step request after a `429`, one per retry.
  var rateLimitDelays: [TimeInterval]
  /// Waits before re-sending a transaction Portal reports as `IDEMPOTENT_REQUEST_IN_PROGRESS`, one
  /// per retry.
  var idempotencyInProgressDelays: [TimeInterval]
  /// The shortest wait between two reads, whatever `pollOptions` asks for.
  var minPollInterval: TimeInterval
  /// The longest wait between two reads.
  var maxPollInterval: TimeInterval
  /// Consecutive failed reads tolerated before polling fails.
  var maxConsecutivePollErrors: Int

  static let standard = YieldXyzBorrowRetryPolicy(
    rateLimitDelays: [0.5, 1, 2],
    idempotencyInProgressDelays: [2, 4, 8],
    minPollInterval: 0.25,
    maxPollInterval: 10,
    maxConsecutivePollErrors: 5
  )
}

/// Yield.xyz Borrow provider implementation. Reach it through `portal.borrow.yieldxyz`.
public class YieldXyzBorrow: YieldXyzBorrowProtocol {
  /// The chain the wallet's EVM address is read through: every `eip155` chain shares it.
  static let walletChainId = "eip155:1"
  static let idempotencyKeyPrefix = "yieldxyz-borrow-"

  private static let failedActionStatuses: Set<YieldXyzBorrowActionStatus> = [.failed, .canceled, .stale]
  private static let completedTransactionStatuses: Set<YieldXyzBorrowTransactionStatus> = [.confirmed, .skipped]
  /// Only these are signed; any other non-final status is waited on, so a transaction is never
  /// signed twice.
  private static let signableTransactionStatuses: Set<YieldXyzBorrowTransactionStatus> = [.created, .waitingForSignature]
  /// Statuses showing Yield.xyz already recorded a submission.
  private static let recordedTransactionStatuses: Set<YieldXyzBorrowTransactionStatus> = [
    .signed, .broadcasted, .pending, .notFound, .confirmed, .skipped
  ]

  private let api: PortalYieldXyzBorrowApiProtocol
  private let dependencies: YieldXyzBorrowExecutionDependencies
  private let lookupEvmTransaction: YieldXyzBorrowLookupEvmTransaction?
  private let retryPolicy: YieldXyzBorrowRetryPolicy
  private let inFlightActions = YieldXyzInFlightActions()
  private let logger = PortalLogger.shared

  /// Create an instance of YieldXyzBorrow.
  /// - Parameters:
  ///   - api: The Yield.xyz Borrow API. A `PortalYieldXyzBorrowApi` also reads broadcast
  ///     transactions back to find their on-chain hash; without one, `executeAction` and
  ///     `signAndSubmitAction` fail with `dependencyUnavailable`.
  ///   - dependencies: What the high-level methods need to sign transactions. `Portal` provides all
  ///     of them.
  public convenience init(
    api: PortalYieldXyzBorrowApiProtocol,
    dependencies: YieldXyzBorrowExecutionDependencies = YieldXyzBorrowExecutionDependencies()
  ) {
    self.init(api: api, dependencies: dependencies, lookupEvmTransaction: Self.lookup(from: api), retryPolicy: .standard)
  }

  init(
    api: PortalYieldXyzBorrowApiProtocol,
    dependencies: YieldXyzBorrowExecutionDependencies,
    lookupEvmTransaction: YieldXyzBorrowLookupEvmTransaction?,
    retryPolicy: YieldXyzBorrowRetryPolicy = .standard
  ) {
    self.api = api
    self.dependencies = dependencies
    self.lookupEvmTransaction = lookupEvmTransaction
    self.retryPolicy = retryPolicy
  }

  /// The transaction lookup `api` serves, when it serves one.
  static func lookup(from api: PortalYieldXyzBorrowApiProtocol) -> YieldXyzBorrowLookupEvmTransaction? {
    guard let provider = api as? YieldXyzEvmTransactionLookupProviding else {
      return nil
    }
    return { [provider] chainId, hash in
      try await provider.lookupEvmTransaction(chainId: chainId, hash: hash)
    }
  }

  // MARK: - Reads

  public func getHealth() async throws -> YieldXyzBorrowGetHealthResponse {
    try await api.getHealth()
  }

  public func getIntegrations() async throws -> YieldXyzBorrowGetIntegrationsResponse {
    try await api.getIntegrations()
  }

  public func getIntegration(integrationId: String) async throws -> YieldXyzBorrowGetIntegrationResponse {
    try await api.getIntegration(integrationId: integrationId)
  }

  public func getMarkets(params: YieldXyzBorrowGetMarketsParams) async throws -> YieldXyzBorrowGetMarketsResponse {
    try await api.getMarkets(params: params)
  }

  public func getMarket(marketId: String) async throws -> YieldXyzBorrowGetMarketResponse {
    try await api.getMarket(marketId: marketId)
  }

  public func getPositions(params: YieldXyzBorrowGetPositionsParams) async throws -> YieldXyzBorrowGetPositionsResponse {
    try await api.getPositions(params: params)
  }

  public func getLiquidations(params: YieldXyzBorrowGetLiquidationsParams) async throws -> YieldXyzBorrowGetLiquidationsResponse {
    try await api.getLiquidations(params: params)
  }

  // MARK: - Actions

  public func createAction(params: YieldXyzBorrowCreateActionParams) async throws -> YieldXyzBorrowActionResponse {
    try await api.createAction(params: params)
  }

  public func getActions(params: YieldXyzBorrowGetActionsParams) async throws -> YieldXyzBorrowGetActionsResponse {
    try await api.getActions(params: params)
  }

  public func getAction(actionId: String) async throws -> YieldXyzBorrowActionResponse {
    try await api.getAction(actionId: actionId)
  }

  public func stepAction(actionId: String) async throws -> YieldXyzBorrowActionResponse {
    try await api.stepAction(actionId: actionId)
  }

  public func submitTransaction(
    transactionId: String,
    params: YieldXyzBorrowSubmitTransactionParams
  ) async throws -> YieldXyzBorrowSubmitTransactionResponse {
    if Self.isBlank(params.transactionHash), Self.isBlank(params.signedPayload) {
      throw YieldXyzBorrowError.submissionRequired
    }
    return try await api.submitTransaction(transactionId: transactionId, params: params)
  }

  // MARK: - Execution

  public func executeAction(
    params: YieldXyzBorrowCreateActionParams,
    options: YieldXyzBorrowExecuteOptions
  ) async throws -> YieldXyzBorrowExecutionResult {
    let action = try await createAction(params: params).data
    return try await signAndSubmitAction(action, options: options)
  }

  public func signAndSubmitAction(
    _ action: YieldXyzBorrowAction,
    options: YieldXyzBorrowExecuteOptions
  ) async throws -> YieldXyzBorrowExecutionResult {
    let actionId = action.id
    let claimed = inFlightActions.claim(actionId)
    defer {
      if claimed {
        inFlightActions.release(actionId)
      }
    }

    do {
      guard claimed else {
        throw YieldXyzBorrowExecutionError(
          reason: .actionInProgress,
          message: "Action \(actionId) is already being executed.",
          actionId: actionId,
          action: action
        )
      }
      let context = try await ExecutionContext(
        actionId: actionId,
        walletAddress: resolveWalletAddress(action),
        options: options,
        signingOrder: action.transactions.map(\.id),
        latestAction: action
      )
      var executions: [YieldXyzBorrowTransactionExecution] = []
      var stepTransactions = try await readCurrentState(context).transactions

      while true {
        for transaction in stepTransactions {
          if let execution = try await settleTransaction(context, transaction, index: executions.count) {
            executions.append(execution)
          }
        }

        let settled = try await waitForStepOutcome(context)
        if settled.hasNextStep {
          stepTransactions = try await fetchNextStep(context)
          continue
        }

        return YieldXyzBorrowExecutionResult(
          actionId: actionId,
          action: settled,
          status: settled.status,
          transactions: executions
        )
      }
    } catch is CancellationError {
      logger.warn("YieldXyzBorrow.signAndSubmitAction() - Execution of action \(actionId) was cancelled.")
      throw CancellationError()
    } catch {
      let failure = (error as? YieldXyzBorrowExecutionError) ?? YieldXyzBorrowExecutionError(
        reason: .signingFailed,
        message: "Executing action \(actionId) failed.",
        actionId: actionId,
        underlyingError: error
      )
      logger.error("YieldXyzBorrow.signAndSubmitAction() - Action \(actionId) failed (\(failure.reason.rawValue), transaction \(failure.transactionId ?? "none")): \(failure.message)")
      options.onProgress?(YieldXyzBorrowExecutionProgress(
        step: .failed,
        actionId: actionId,
        transactionId: failure.transactionId,
        broadcastHash: failure.broadcastHash,
        transactionHash: failure.transactionHash,
        userOperationHash: failure.userOperationHash,
        error: failure
      ))
      throw failure
    }
  }

  // MARK: - Execution internals

  /// The mutable state of one execution.
  private final class ExecutionContext {
    let actionId: String
    let walletAddress: String
    let options: YieldXyzBorrowExecuteOptions
    /// Transaction ids of the current step, in signing order.
    var signingOrder: [String]
    /// Kept in `signingOrder`, whatever order `getAction` returned.
    var latestAction: YieldXyzBorrowAction

    init(
      actionId: String,
      walletAddress: String,
      options: YieldXyzBorrowExecuteOptions,
      signingOrder: [String],
      latestAction: YieldXyzBorrowAction
    ) {
      self.actionId = actionId
      self.walletAddress = walletAddress
      self.options = options
      self.signingOrder = signingOrder
      self.latestAction = latestAction
    }
  }

  /// The hashes an error about a broadcast transaction carries.
  private struct Hashes {
    var broadcastHash: String?
    var transactionHash: String?
    var userOperationHash: String?
  }

  /// The hashes submitted to Yield.xyz for a broadcast transaction.
  private struct OnChainHashes {
    let transactionHash: String
    let userOperationHash: String?
  }

  private enum ResolvedHash {
    case transaction(String)
    case userOperation(transactionHash: String)
    case userOperationFailed(transactionHash: String)
  }

  /// The transaction lookup answered without `data`.
  private struct LookupReturnedNoData: LocalizedError {
    let hash: String

    var errorDescription: String? {
      "The transaction lookup for \(hash) returned no data."
    }
  }

  private enum ReconciliationOutcome {
    case recorded
    case notRecorded
    case unknown
  }

  private static func isBlank(_ value: String?) -> Bool {
    value?.isEmpty ?? true
  }

  /// The idempotency key of a transaction, or `nil` when its id cannot form a valid key.
  static func idempotencyKey(forTransactionId transactionId: String) -> String? {
    YieldXyzIdempotency.key(prefix: idempotencyKeyPrefix, transactionId: transactionId)
  }

  /// `action` with its transactions in `signingOrder`, matched by id. `getAction` may list them in a
  /// different order; transactions `signingOrder` does not know follow, in the order they came.
  static func inSigningOrder(_ action: YieldXyzBorrowAction, _ signingOrder: [String]) -> YieldXyzBorrowAction {
    var byId: [String: YieldXyzBorrowTransaction] = [:]
    for transaction in action.transactions {
      byId[transaction.id] = transaction
    }
    let known = Set(signingOrder)
    let ordered = signingOrder.compactMap { byId[$0] }
    let unknown = action.transactions.filter { !known.contains($0.id) }
    return action.with(transactions: ordered + unknown)
  }

  private func emit(_ context: ExecutionContext, _ progress: YieldXyzBorrowExecutionProgress) {
    context.options.onProgress?(progress)
  }

  private func executionError(
    _ context: ExecutionContext,
    reason: YieldXyzBorrowExecutionErrorReason,
    message: String,
    transactionId: String? = nil,
    hashes: Hashes = Hashes(),
    action: YieldXyzBorrowAction? = nil,
    underlyingError: Error? = nil
  ) -> YieldXyzBorrowExecutionError {
    YieldXyzBorrowExecutionError(
      reason: reason,
      message: message,
      actionId: context.actionId,
      transactionId: transactionId,
      broadcastHash: hashes.broadcastHash,
      transactionHash: hashes.transactionHash,
      userOperationHash: hashes.userOperationHash,
      action: action ?? context.latestAction,
      underlyingError: underlyingError
    )
  }

  @discardableResult
  private func recordLatest(_ context: ExecutionContext, _ action: YieldXyzBorrowAction) -> YieldXyzBorrowAction {
    context.latestAction = Self.inSigningOrder(action, context.signingOrder)
    return context.latestAction
  }

  private func resolveWalletAddress(_ action: YieldXyzBorrowAction) async throws -> String {
    var walletAddress: String?
    var cause: Error?
    do {
      walletAddress = try await dependencies.getWalletAddress?()
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      cause = error
    }
    guard let walletAddress, !walletAddress.isEmpty else {
      throw YieldXyzBorrowExecutionError(
        reason: .missingWalletAddress,
        message: "No Portal EVM wallet address is available to sign with.",
        actionId: action.id,
        action: action,
        underlyingError: cause
      )
    }
    return walletAddress
  }

  /// Reads the action back before anything is signed. The action passed in may be stale (a resumed
  /// execution), so it only gives the signing order: which transactions still need signing, and
  /// their payloads, come from Yield.xyz. A transaction Yield.xyz no longer lists is never signed.
  private func readCurrentState(_ context: ExecutionContext) async throws -> YieldXyzBorrowAction {
    let current = try await pollAction(context, awaited: "the action") { $0 }
    try assertActionNotFailed(context, current)
    context.signingOrder = current.transactions.map(\.id)
    return current
  }

  /// Brings one transaction of the current step to `CONFIRMED` or `SKIPPED`: signs and submits it
  /// when it awaits a signature (or, when the caller supplied its broadcast hash, submits that hash
  /// without signing again), and otherwise waits for Yield.xyz to settle it. Its status and payload
  /// are read from the latest action by id: the payload signed is the one Yield.xyz lists once the
  /// transaction awaits a signature, not the one listed when the step began. A transaction the
  /// latest action no longer lists is waited on until it is listed again.
  private func settleTransaction(
    _ context: ExecutionContext,
    _ transaction: YieldXyzBorrowTransaction,
    index: Int
  ) async throws -> YieldXyzBorrowTransactionExecution? {
    let suppliedBroadcastHash = context.options.broadcastHashes[transaction.id]
    let knownHashes = Hashes(broadcastHash: suppliedBroadcastHash)

    var current = context.latestAction.transactions.first { $0.id == transaction.id }
    let status = current?.status ?? transaction.status
    try assertTransactionNotFailed(context, transaction.id, status: status, hashes: knownHashes)
    if Self.completedTransactionStatuses.contains(status) {
      return nil
    }

    let awaitsSignature = current.map { Self.signableTransactionStatuses.contains($0.status) } ?? false
    if !awaitsSignature {
      let awaited = try await waitForTransactionStatus(context, transaction.id, hashes: knownHashes) {
        Self.signableTransactionStatuses.contains($0) || Self.completedTransactionStatuses.contains($0)
      }
      if Self.completedTransactionStatuses.contains(awaited.status) {
        return nil
      }
      current = awaited
    }
    guard let current else {
      return nil
    }

    // The read that settled the previous transaction may already show the action ended, with this
    // transaction still CREATED.
    try assertActionNotFailed(context, context.latestAction, transactionId: transaction.id, hashes: knownHashes)
    let execution: YieldXyzBorrowTransactionExecution
    if let suppliedBroadcastHash {
      execution = try await resumeBroadcastTransaction(context, current, index: index, broadcastHash: suppliedBroadcastHash)
    } else {
      execution = try await signAndSubmitTransaction(context, current, index: index)
    }

    _ = try await waitForTransactionStatus(
      context,
      transaction.id,
      hashes: Hashes(
        broadcastHash: suppliedBroadcastHash ?? execution.userOperationHash ?? execution.transactionHash,
        transactionHash: execution.transactionHash,
        userOperationHash: execution.userOperationHash
      )
    ) { Self.completedTransactionStatuses.contains($0) }
    emit(context, YieldXyzBorrowExecutionProgress(
      step: .confirmed,
      actionId: context.actionId,
      transactionId: transaction.id,
      index: index,
      transactionHash: execution.transactionHash,
      userOperationHash: execution.userOperationHash
    ))

    return execution
  }

  private func assertTransactionNotFailed(
    _ context: ExecutionContext,
    _ transactionId: String,
    status: YieldXyzBorrowTransactionStatus,
    hashes: Hashes = Hashes()
  ) throws {
    if status == .failed {
      throw executionError(
        context,
        reason: .transactionFailed,
        message: "Yield.xyz reported transaction \(transactionId) as FAILED.",
        transactionId: transactionId,
        hashes: hashes
      )
    }
  }

  /// Checks the latest action and the transaction were built for the Portal wallet on an EVM chain,
  /// and narrows its payload.
  private func prepareTransaction(
    _ context: ExecutionContext,
    _ transaction: YieldXyzBorrowTransaction,
    hashes: Hashes = Hashes()
  ) throws -> (chainId: String, request: YieldXyzEvmTransactionRequest) {
    guard transaction.signingFormat == .evmTransaction else {
      throw executionError(
        context,
        reason: .unsupportedSigningFormat,
        message: "Transaction \(transaction.id) uses signing format \"\(transaction.signingFormat?.rawValue ?? "none")\"; only EVM_TRANSACTION is supported.",
        transactionId: transaction.id,
        hashes: hashes
      )
    }

    let chainId = transaction.network
    guard YieldXyzEvmTransactionParams.isEvmChainId(chainId) else {
      throw executionError(
        context,
        reason: .unsupportedNetwork,
        message: "Transaction \(transaction.id) is on \"\(chainId)\", which is not an EIP-155 chain Portal supports.",
        transactionId: transaction.id,
        hashes: hashes
      )
    }

    try assertBuiltForWallet(context, subject: "Action \(context.actionId)", address: context.latestAction.address, transactionId: transaction.id, hashes: hashes)
    try assertBuiltForWallet(context, subject: "Transaction \(transaction.id)", address: transaction.address, transactionId: transaction.id, hashes: hashes)

    // Yield.xyz records a submission under the transaction's id: without one, the transaction could
    // be broadcast but never submitted.
    guard !transaction.id.isEmpty else {
      throw executionError(
        context,
        reason: .invalidSignablePayload,
        message: "A transaction of action \(context.actionId) has no id, so it could not be submitted once broadcast.",
        hashes: hashes
      )
    }

    let request: YieldXyzEvmTransactionRequest
    switch YieldXyzEvmTransactionParams.parse(transaction.signablePayload, defaultFrom: nil) {
    case let .success(parsed):
      request = parsed
    case let .failure(problem):
      throw executionError(
        context,
        reason: .invalidSignablePayload,
        message: "The signablePayload of transaction \(transaction.id) \(problem.description).",
        transactionId: transaction.id,
        hashes: hashes
      )
    }
    try assertBuiltForWallet(context, subject: "Transaction \(transaction.id)", address: request.from, transactionId: transaction.id, hashes: hashes)

    return (chainId, request)
  }

  private func assertBuiltForWallet(
    _ context: ExecutionContext,
    subject: String,
    address: String,
    transactionId: String,
    hashes: Hashes
  ) throws {
    guard address.lowercased() == context.walletAddress.lowercased() else {
      throw executionError(
        context,
        reason: .signerAddressMismatch,
        message: "\(subject) was built for \(address), not the Portal wallet \(context.walletAddress).",
        transactionId: transactionId,
        hashes: hashes
      )
    }
  }

  private func signAndSubmitTransaction(
    _ context: ExecutionContext,
    _ transaction: YieldXyzBorrowTransaction,
    index: Int
  ) async throws -> YieldXyzBorrowTransactionExecution {
    let (chainId, request) = try prepareTransaction(context, transaction)

    let signerOverride = context.options.signAndSendTransaction
    if signerOverride == nil, let isChainConfigured = dependencies.isChainConfigured, !(await isChainConfigured(chainId)) {
      throw executionError(
        context,
        reason: .signingChainNotConfigured,
        message: "No RPC endpoint is configured for \(chainId); add it to rpcConfig to sign transaction \(transaction.id).",
        transactionId: transaction.id
      )
    }

    let signAndSendTransaction = signerOverride ?? dependencies.signAndSendTransaction
    guard let signAndSendTransaction, let lookupEvmTransaction else {
      let message: String
      if signAndSendTransaction != nil {
        message = "No transaction lookup is configured."
      } else if lookupEvmTransaction != nil {
        message = "No transaction signer is configured."
      } else {
        message = "No transaction signer and transaction lookup are configured."
      }
      throw executionError(context, reason: .dependencyUnavailable, message: message, transactionId: transaction.id)
    }

    let broadcastHash = try await sendTransaction(
      context,
      transaction,
      index: index,
      param: YieldXyzEvmTransactionParams.toSendTransactionParam(request),
      chainId: chainId,
      signAndSendTransaction: signAndSendTransaction
    )

    return try await submitBroadcastTransaction(
      context,
      transaction,
      index: index,
      chainId: chainId,
      broadcastHash: broadcastHash,
      lookupEvmTransaction: lookupEvmTransaction
    )
  }

  /// Signs and broadcasts a transaction. With an idempotency key, Portal broadcasts it at most once:
  /// a send it reports as still in progress is retried with the same key a few times, and a send it
  /// reports as already completed stops with `transactionAlreadyBroadcast`, because Portal does not
  /// return the hash of that broadcast.
  private func sendTransaction(
    _ context: ExecutionContext,
    _ transaction: YieldXyzBorrowTransaction,
    index: Int,
    param: ETHTransactionParam,
    chainId: String,
    signAndSendTransaction: YieldXyzBorrowSignAndSendTransaction
  ) async throws -> String {
    var idempotencyKey: String?
    if context.options.useIdempotencyKeys {
      idempotencyKey = Self.idempotencyKey(forTransactionId: transaction.id)
      if idempotencyKey == nil {
        logger.warn("YieldXyzBorrow - Transaction id \(transaction.id) cannot form an idempotency key; it is sent without one.")
      }
    }

    emit(context, YieldXyzBorrowExecutionProgress(
      step: .signing,
      actionId: context.actionId,
      transactionId: transaction.id,
      index: index
    ))

    var inProgressRetries = 0
    var returned: String?
    while true {
      do {
        returned = try await signAndSendTransaction(param, chainId, idempotencyKey)
        break
      } catch is CancellationError {
        throw CancellationError()
      } catch let error as PortalMpcError where idempotencyKey != nil && error.id == PortalIdempotencyErrorId.requestInProgress {
        guard inProgressRetries < retryPolicy.idempotencyInProgressDelays.count else {
          throw executionError(
            context,
            reason: .signingFailed,
            message: "Portal is still processing the send of transaction \(transaction.id); resume the action later.",
            transactionId: transaction.id,
            underlyingError: error
          )
        }
        try await YieldXyzExecutionClock.sleep(seconds: retryPolicy.idempotencyInProgressDelays[inProgressRetries])
        inProgressRetries += 1
      } catch let error as PortalMpcError where idempotencyKey != nil && error.id == PortalIdempotencyErrorId.requestAlreadyCompleted {
        throw executionError(
          context,
          reason: .transactionAlreadyBroadcast,
          message: "Portal already broadcast transaction \(transaction.id) and does not return its hash; resume with the broadcastHash the confirming progress event reported, or look the transaction up on-chain. To sign it again after its user operation failed, build a new action or set useIdempotencyKeys to false.",
          transactionId: transaction.id,
          underlyingError: error
        )
      } catch let error as PortalMpcError where idempotencyKey != nil && error.isIdempotencyRejection {
        // Every later send of this transaction under the same key gets the same answer while Portal
        // remembers the key, including after a send that failed: check the chain, then build a new
        // action (its transactions get new keys) or send without a key.
        throw executionError(
          context,
          reason: .signingFailed,
          message: "Portal refused to send transaction \(transaction.id) again under its idempotency key (\(error.id ?? "unknown")); check the chain, then build a new action or set useIdempotencyKeys to false.",
          transactionId: transaction.id,
          underlyingError: error
        )
      } catch {
        throw executionError(
          context,
          reason: .signingFailed,
          message: "Sending transaction \(transaction.id) failed.",
          transactionId: transaction.id,
          underlyingError: error
        )
      }
    }

    guard let returned else {
      throw executionError(
        context,
        reason: .signatureRejected,
        message: "The signing request for transaction \(transaction.id) was rejected.",
        transactionId: transaction.id
      )
    }
    guard YieldXyzEvmTransactionParams.isTransactionHash(returned) else {
      throw executionError(
        context,
        reason: .invalidTransactionHash,
        message: "The signer did not return a transaction hash for transaction \(transaction.id).",
        transactionId: transaction.id
      )
    }
    return returned
  }

  /// Continues a transaction the caller reports as already broadcast, from the broadcast hash an
  /// earlier attempt returned. It is validated like any other transaction but never signed, so it
  /// cannot be broadcast twice.
  private func resumeBroadcastTransaction(
    _ context: ExecutionContext,
    _ transaction: YieldXyzBorrowTransaction,
    index: Int,
    broadcastHash: String
  ) async throws -> YieldXyzBorrowTransactionExecution {
    let hashes = Hashes(broadcastHash: broadcastHash)
    let (chainId, _) = try prepareTransaction(context, transaction, hashes: hashes)

    guard YieldXyzEvmTransactionParams.isTransactionHash(broadcastHash) else {
      throw executionError(
        context,
        reason: .invalidTransactionHash,
        message: "The broadcast hash supplied for transaction \(transaction.id) is not a transaction hash.",
        transactionId: transaction.id,
        hashes: hashes
      )
    }
    guard let lookupEvmTransaction else {
      throw executionError(
        context,
        reason: .dependencyUnavailable,
        message: "No transaction lookup is configured.",
        transactionId: transaction.id,
        hashes: hashes
      )
    }

    return try await submitBroadcastTransaction(
      context,
      transaction,
      index: index,
      chainId: chainId,
      broadcastHash: broadcastHash,
      lookupEvmTransaction: lookupEvmTransaction
    )
  }

  /// Resolves the on-chain hash of a broadcast transaction and submits it to Yield.xyz.
  private func submitBroadcastTransaction(
    _ context: ExecutionContext,
    _ transaction: YieldXyzBorrowTransaction,
    index: Int,
    chainId: String,
    broadcastHash: String,
    lookupEvmTransaction: YieldXyzBorrowLookupEvmTransaction
  ) async throws -> YieldXyzBorrowTransactionExecution {
    emit(context, YieldXyzBorrowExecutionProgress(
      step: .confirming,
      actionId: context.actionId,
      transactionId: transaction.id,
      index: index,
      broadcastHash: broadcastHash
    ))

    var resolvedHashes: OnChainHashes?
    let hashes: OnChainHashes
    let submitResult: YieldXyzBorrowSubmitTransactionResult?
    do {
      hashes = try await resolveOnChainHashes(context, transaction, chainId: chainId, broadcastHash: broadcastHash, lookupEvmTransaction: lookupEvmTransaction)
      resolvedHashes = hashes
      submitResult = try await submitWithReconciliation(context, transaction, broadcastHash: broadcastHash, hashes: hashes)
    } catch is CancellationError {
      // The transaction is on-chain: keep its hash so the caller can resume with `broadcastHashes`.
      throw executionError(
        context,
        reason: .submitOutcomeUnknown,
        message: "Submitting transaction \(transaction.id) (\(broadcastHash)) was cancelled; resume with broadcastHashes.",
        transactionId: transaction.id,
        hashes: Hashes(
          broadcastHash: broadcastHash,
          transactionHash: resolvedHashes?.transactionHash,
          userOperationHash: resolvedHashes?.userOperationHash
        ),
        underlyingError: CancellationError()
      )
    }

    emit(context, YieldXyzBorrowExecutionProgress(
      step: .submitted,
      actionId: context.actionId,
      transactionId: transaction.id,
      index: index,
      transactionHash: hashes.transactionHash,
      userOperationHash: hashes.userOperationHash
    ))

    return YieldXyzBorrowTransactionExecution(
      transactionId: transaction.id,
      type: transaction.type,
      transactionHash: hashes.transactionHash,
      userOperationHash: hashes.userOperationHash,
      submitResult: submitResult
    )
  }

  /// Polls the transaction lookup until the hash `eth_sendTransaction` returned resolves to an
  /// on-chain transaction: the transaction itself for an EOA, or the bundle transaction that
  /// included the user operation for an account-abstracted client. The lookup answers `404` until
  /// either is visible.
  private func resolveOnChainHashes(
    _ context: ExecutionContext,
    _ transaction: YieldXyzBorrowTransaction,
    chainId: String,
    broadcastHash: String,
    lookupEvmTransaction: YieldXyzBorrowLookupEvmTransaction
  ) async throws -> OnChainHashes {
    let hashes = Hashes(broadcastHash: broadcastHash)
    var consecutiveErrors = 0

    let resolved: ResolvedHash
    do {
      resolved = try await YieldXyzPollLoop.run(
        intervalSeconds: context.options.pollOptions.intervalSeconds,
        timeoutSeconds: context.options.pollOptions.timeoutSeconds,
        minIntervalSeconds: retryPolicy.minPollInterval,
        maxIntervalSeconds: retryPolicy.maxPollInterval
      ) { () async throws -> YieldXyzPollStep<ResolvedHash> in
        let lookup: YieldXyzEvmTransactionLookup?
        do {
          lookup = try await lookupEvmTransaction(chainId, broadcastHash)
        } catch is CancellationError {
          throw CancellationError()
        } catch {
          // The Portal API answers 404 until the transaction or user operation is visible.
          if YieldXyzRequestFailure.status(of: error) == 404 {
            consecutiveErrors = 0
            return .continue
          }
          if !YieldXyzRequestFailure.isTransient(error) {
            throw error
          }
          consecutiveErrors += 1
          if consecutiveErrors >= retryPolicy.maxConsecutivePollErrors {
            throw error
          }
          return .continue
        }

        guard let lookup else {
          let error = LookupReturnedNoData(hash: broadcastHash)
          consecutiveErrors += 1
          if consecutiveErrors >= retryPolicy.maxConsecutivePollErrors {
            throw error
          }
          return .continue
        }
        consecutiveErrors = 0

        if let transactionHash = lookup.transactionHash {
          return .stop(.transaction(transactionHash))
        }
        if let userOperation = lookup.userOperation, let receiptHash = userOperation.receiptTransactionHash {
          return .stop(userOperation.success == false
            ? .userOperationFailed(transactionHash: receiptHash)
            : .userOperation(transactionHash: receiptHash))
        }
        return .continue
      }
    } catch is YieldXyzPollLoopTimeout {
      throw executionError(
        context,
        reason: .timeout,
        message: "The on-chain transaction of \(transaction.id) (\(broadcastHash)) was not found in time.",
        transactionId: transaction.id,
        hashes: hashes
      )
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      throw executionError(
        context,
        reason: .pollingFailed,
        message: "Looking up transaction \(transaction.id) (\(broadcastHash)) failed.",
        transactionId: transaction.id,
        hashes: hashes,
        underlyingError: error
      )
    }

    switch resolved {
    case let .transaction(transactionHash):
      return OnChainHashes(transactionHash: transactionHash, userOperationHash: nil)
    case let .userOperation(transactionHash):
      return OnChainHashes(transactionHash: transactionHash, userOperationHash: broadcastHash)
    case let .userOperationFailed(transactionHash):
      throw executionError(
        context,
        reason: .userOperationFailed,
        message: "The user operation of transaction \(transaction.id) (\(broadcastHash)) was included in \(transactionHash) but did not succeed.",
        transactionId: transaction.id,
        hashes: Hashes(broadcastHash: broadcastHash, transactionHash: transactionHash, userOperationHash: broadcastHash)
      )
    }
  }

  /// Submits the on-chain hash, retrying only when that is known to be safe: after a `429` (the
  /// request was not processed), or once after an ambiguous failure when the action shows the hash
  /// was not recorded. Recording a hash cannot broadcast anything twice.
  private func submitWithReconciliation(
    _ context: ExecutionContext,
    _ transaction: YieldXyzBorrowTransaction,
    broadcastHash: String,
    hashes: OnChainHashes
  ) async throws -> YieldXyzBorrowSubmitTransactionResult? {
    let errorHashes = Hashes(broadcastHash: broadcastHash, transactionHash: hashes.transactionHash, userOperationHash: hashes.userOperationHash)
    var rateLimitRetries = 0
    var hashResubmitted = false

    while true {
      let failure: Error
      do {
        let result = try await api.submitTransaction(
          transactionId: transaction.id,
          params: YieldXyzBorrowSubmitTransactionParams(transactionHash: hashes.transactionHash)
        ).data
        if result.status == .failed {
          throw executionError(
            context,
            reason: .submitFailed,
            message: "Yield.xyz reported transaction \(transaction.id) as FAILED\(result.error.map { ": \($0)" } ?? "").",
            transactionId: transaction.id,
            hashes: errorHashes
          )
        }
        return result
      } catch let error as YieldXyzBorrowExecutionError {
        throw error
      } catch is CancellationError {
        throw CancellationError()
      } catch {
        failure = error
      }

      if YieldXyzRequestFailure.isRateLimit(failure), rateLimitRetries < retryPolicy.rateLimitDelays.count {
        try await YieldXyzExecutionClock.sleep(seconds: retryPolicy.rateLimitDelays[rateLimitRetries])
        rateLimitRetries += 1
        continue
      }

      if !YieldXyzRequestFailure.isAmbiguous(failure) {
        throw executionError(
          context,
          reason: .submitRejected,
          message: YieldXyzRequestFailure.isRefusedBeforeSending(failure)
            ? "The submission of transaction \(transaction.id) could not be sent."
            : "Yield.xyz rejected the submission of transaction \(transaction.id).",
          transactionId: transaction.id,
          hashes: errorHashes,
          underlyingError: failure
        )
      }

      let outcome = try await reconcileSubmission(context, transaction, hashes: errorHashes)
      if outcome == .recorded {
        return nil
      }
      if outcome == .notRecorded, !hashResubmitted {
        hashResubmitted = true
        continue
      }

      throw executionError(
        context,
        reason: .submitOutcomeUnknown,
        message: "The submission of transaction \(transaction.id) failed and its outcome could not be confirmed; check the action before retrying.",
        transactionId: transaction.id,
        hashes: errorHashes,
        underlyingError: failure
      )
    }
  }

  private func reconcileSubmission(
    _ context: ExecutionContext,
    _ transaction: YieldXyzBorrowTransaction,
    hashes: Hashes
  ) async throws -> ReconciliationOutcome {
    let action: YieldXyzBorrowAction
    do {
      action = try await api.getAction(actionId: context.actionId).data
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      logger.warn("YieldXyzBorrow - Could not read action \(context.actionId) to reconcile a failed submission: \(error.localizedDescription)")
      return .unknown
    }

    guard let latest = action.transactions.first(where: { $0.id == transaction.id }) else {
      return .unknown
    }
    let current = recordLatest(context, action)

    if Self.recordedTransactionStatuses.contains(latest.status) {
      return .recorded
    }
    if latest.status == .failed {
      throw executionError(
        context,
        reason: .submitFailed,
        message: "Yield.xyz reported transaction \(transaction.id) as FAILED.",
        transactionId: transaction.id,
        hashes: hashes,
        action: current
      )
    }
    // An ended action leaves its unsubmitted transactions CREATED: they are not awaiting a
    // submission any more.
    try assertActionNotFailed(context, current, transactionId: transaction.id, hashes: hashes)
    return Self.signableTransactionStatuses.contains(latest.status) ? .notRecorded : .unknown
  }

  private func waitForTransactionStatus(
    _ context: ExecutionContext,
    _ transactionId: String,
    hashes: Hashes,
    isSettled: @escaping (YieldXyzBorrowTransactionStatus) -> Bool
  ) async throws -> YieldXyzBorrowTransaction {
    try await pollAction(context, awaited: "transaction \(transactionId)", transactionId: transactionId, hashes: hashes) { action in
      guard let latest = action.transactions.first(where: { $0.id == transactionId }) else {
        return nil
      }
      try self.assertTransactionNotFailed(context, transactionId, status: latest.status, hashes: hashes)
      return isSettled(latest.status) ? latest : nil
    }
  }

  /// Waits until the confirmed step either has a next step or the action succeeds.
  private func waitForStepOutcome(_ context: ExecutionContext) async throws -> YieldXyzBorrowAction {
    let outcome: (YieldXyzBorrowAction) throws -> YieldXyzBorrowAction? = { action in
      try self.assertActionNotFailed(context, action)
      return action.hasNextStep || action.status == .success ? action : nil
    }
    if let settled = try outcome(context.latestAction) {
      return settled
    }
    return try await pollAction(context, awaited: "the action", check: outcome)
  }

  private func assertActionNotFailed(
    _ context: ExecutionContext,
    _ action: YieldXyzBorrowAction,
    transactionId: String? = nil,
    hashes: Hashes = Hashes()
  ) throws {
    if Self.failedActionStatuses.contains(action.status) {
      throw executionError(
        context,
        reason: .actionFailed,
        message: "Action \(context.actionId) ended with status \(action.status).",
        transactionId: transactionId,
        hashes: hashes,
        action: action
      )
    }
  }

  private func fetchNextStep(_ context: ExecutionContext) async throws -> [YieldXyzBorrowTransaction] {
    let next = try await requestNextStep(context)
    try assertActionNotFailed(context, next)

    let hasTransactionToProcess = next.transactions.contains {
      !Self.completedTransactionStatuses.contains($0.status) && $0.status != .failed
    }
    guard hasTransactionToProcess else {
      throw executionError(
        context,
        reason: .nextStepFailed,
        message: "The next step of action \(context.actionId) returned no transaction to sign.",
        action: next
      )
    }

    context.signingOrder = next.transactions.map(\.id)
    context.latestAction = next
    emit(context, YieldXyzBorrowExecutionProgress(
      step: .nextStep,
      actionId: context.actionId,
      currentStep: next.currentStep,
      totalSteps: next.totalSteps,
      actionStatus: next.status,
      action: next
    ))
    return next.transactions
  }

  /// POSTs `/step`, retrying a rate-limited request.
  private func requestNextStep(_ context: ExecutionContext) async throws -> YieldXyzBorrowAction {
    var rateLimitRetries = 0
    while true {
      do {
        return try await api.stepAction(actionId: context.actionId).data
      } catch is CancellationError {
        throw CancellationError()
      } catch {
        if YieldXyzRequestFailure.isRateLimit(error), rateLimitRetries < retryPolicy.rateLimitDelays.count {
          try await YieldXyzExecutionClock.sleep(seconds: retryPolicy.rateLimitDelays[rateLimitRetries])
          rateLimitRetries += 1
          continue
        }
        throw executionError(
          context,
          reason: .nextStepFailed,
          message: "Fetching the next step of action \(context.actionId) failed.",
          underlyingError: error
        )
      }
    }
  }

  /// Reads the action back until `check` returns a value. Rate limits, 5xx, transport failures and
  /// undecodable bodies are retried up to `maxConsecutivePollErrors` times in a row; any other
  /// failure stops polling. An action that ended as `FAILED`, `CANCELED` or `STALE` stops it too.
  private func pollAction<T>(
    _ context: ExecutionContext,
    awaited: String,
    transactionId: String? = nil,
    hashes: Hashes = Hashes(),
    check: @escaping (YieldXyzBorrowAction) throws -> T?
  ) async throws -> T {
    var consecutiveErrors = 0
    do {
      return try await YieldXyzPollLoop.run(
        intervalSeconds: context.options.pollOptions.intervalSeconds,
        timeoutSeconds: context.options.pollOptions.timeoutSeconds,
        minIntervalSeconds: retryPolicy.minPollInterval,
        maxIntervalSeconds: retryPolicy.maxPollInterval
      ) { () async throws -> YieldXyzPollStep<T> in
        var action: YieldXyzBorrowAction?
        var failure: Error?
        do {
          action = try await api.getAction(actionId: context.actionId).data
        } catch is CancellationError {
          throw CancellationError()
        } catch {
          failure = error
        }

        guard let action else {
          consecutiveErrors += 1
          let transient = failure.map(YieldXyzRequestFailure.isTransient) ?? true
          if transient, consecutiveErrors < retryPolicy.maxConsecutivePollErrors {
            return .continue
          }
          throw executionError(
            context,
            reason: .pollingFailed,
            message: "Reading action \(context.actionId) failed.",
            transactionId: transactionId,
            hashes: hashes,
            underlyingError: failure
          )
        }

        consecutiveErrors = 0
        let current = recordLatest(context, action)
        emit(context, YieldXyzBorrowExecutionProgress(step: .polling, actionId: context.actionId, actionStatus: current.status))

        if let value = try check(current) {
          return .stop(value)
        }
        try assertActionNotFailed(context, current, transactionId: transactionId, hashes: hashes)
        return .continue
      }
    } catch is YieldXyzPollLoopTimeout {
      throw executionError(
        context,
        reason: .timeout,
        message: "Waiting for \(awaited) of action \(context.actionId) timed out (last status \(context.latestAction.status)).",
        transactionId: transactionId,
        hashes: hashes
      )
    }
  }
}
