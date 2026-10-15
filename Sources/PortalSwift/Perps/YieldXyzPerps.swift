//
//  YieldXyzPerps.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Yield.xyz Perps: perpetual-futures trading on venues such as Hyperliquid.
///
/// Venues (`providerId`) are opaque identifiers such as `hyperliquid`, not chains; discover them
/// with `getProviders()` instead of hard-coding them. Perps is mainnet-only, requires a client
/// without account abstraction, and adds no trading guardrails: show an action's `summary` before
/// the user signs.
public protocol YieldXyzPerpsProtocol: AnyObject {
  /// Lists the trading venues, the actions each supports and the `args` schema of each action.
  func getProviders() async throws -> YieldXyzPerpsGetProvidersResponse
  /// Gets one trading venue.
  func getProvider(providerId: String) async throws -> YieldXyzPerpsGetProviderResponse

  /// Lists markets, optionally filtered by venue and sorted.
  func getMarkets(params: YieldXyzPerpsGetMarketsParams) async throws -> YieldXyzPerpsGetMarketsResponse
  /// Gets one market.
  func getMarket(marketId: String) async throws -> YieldXyzPerpsGetMarketResponse
  /// Gets OHLCV candles of a market over a time window.
  func getMarketCandles(marketId: String, params: YieldXyzPerpsGetMarketCandlesParams) async throws -> YieldXyzPerpsGetMarketCandlesResponse

  /// Gets an account's open positions. Requires `providerId` or `providerIds`.
  func getPositions(params: YieldXyzPerpsPortfolioParams) async throws -> YieldXyzPerpsGetPositionsResponse
  /// Gets an account's resting orders. Requires `providerId` or `providerIds`.
  func getOrders(params: YieldXyzPerpsPortfolioParams) async throws -> YieldXyzPerpsGetOrdersResponse
  /// Gets an account's collateral and margin on one venue.
  func getBalances(params: YieldXyzPerpsBalancesParams) async throws -> YieldXyzPerpsGetBalancesResponse

  /// Builds an action and returns it with its **unsigned** transactions. Nothing is signed or
  /// submitted: pass the action to `signAndSubmitAction`, or use `executeAction` to do both.
  func createAction(params: YieldXyzPerpsCreateActionParams) async throws -> YieldXyzPerpsCreateActionResponse
  /// Lists an account's actions.
  func getActions(params: YieldXyzPerpsGetActionsParams) async throws -> YieldXyzPerpsGetActionsResponse
  /// Gets one action with its transactions and status.
  func getAction(actionId: String) async throws -> YieldXyzPerpsGetActionResponse

  /// Submits a signature (`signedPayload`, which requires `actionId`) or the hash of a broadcast
  /// transaction (`transactionHash`). A response whose `data.status` is `FAILED` is still a failure.
  func submitTransaction(params: YieldXyzPerpsSubmitTransactionParams) async throws -> YieldXyzPerpsSubmitTransactionResponse

  /// Gets an account's unified activity feed: its actions and lifecycle events, newest first.
  func getActivity(params: YieldXyzPerpsGetActivityParams) async throws -> YieldXyzPerpsGetActivityResponse
  /// Lists an account's lifecycle events (fills, liquidations, stop-loss / take-profit triggers).
  func getEvents(params: YieldXyzPerpsGetEventsParams) async throws -> YieldXyzPerpsGetEventsResponse
  /// Gets one lifecycle event.
  func getEvent(eventId: String) async throws -> YieldXyzPerpsGetEventResponse

  /// Gets the Yield.xyz Perps API health.
  func getHealth() async throws -> YieldXyzPerpsGetHealthResponse
  /// Gets per-venue health.
  func getProvidersHealth() async throws -> YieldXyzPerpsGetProvidersHealthResponse

  /// Creates an action, then signs and submits its transactions in order and tracks it to a final
  /// status (see `signAndSubmitAction`).
  func executeAction(params: YieldXyzPerpsCreateActionParams, options: YieldXyzPerpsExecuteOptions) async throws -> YieldXyzPerpsExecutionResult

  /// Signs and submits the transactions of an existing action that await a signature, strictly in
  /// order, then polls the action until it reaches a final status, signing any transactions
  /// Yield.xyz adds meanwhile (for example while `WAITING_FOR_NEXT`).
  ///
  /// A transaction awaits a signature only while `CREATED`; a transaction in any other status is
  /// never signed, so resuming an action cannot sign a leg twice.
  ///
  /// - `EIP712_TYPED_DATA`: signed with `eth_signTypedData_v4` through `signingChainId`, then
  ///   submitted as `signedPayload` with the action id.
  /// - `EVM_TRANSACTION`: sent with `eth_sendTransaction` on its own chain (with the idempotency
  ///   key `yieldxyz-perps-<transactionId>` unless `useIdempotencyKeys` is `false`), confirmed,
  ///   then submitted as `transactionHash`.
  ///
  /// The action is read back before each transaction is signed: a transaction Yield.xyz no longer
  /// lists as pending is skipped, and the payload signed is the one Yield.xyz lists now.
  ///
  /// Failures throw `YieldXyzPerpsExecutionError` carrying the action and transaction ids. An error
  /// with a `broadcastHash` belongs to an `EVM_TRANSACTION` leg that was already broadcast: pass it
  /// in `broadcastHashes` when resuming. A call made while another call on this instance is still
  /// executing the same action fails with `actionInProgress` and signs nothing.
  ///
  /// Cancelling the surrounding task stops the execution with `CancellationError`, except once an
  /// on-chain leg is broadcast: then it fails with an error carrying that leg's `broadcastHash`. The
  /// `confirming` progress event also reports the hash as soon as the leg is broadcast.
  func signAndSubmitAction(_ action: YieldXyzPerpsAction, options: YieldXyzPerpsExecuteOptions) async throws -> YieldXyzPerpsExecutionResult
}

public extension YieldXyzPerpsProtocol {
  /// Convenience overload of `getMarkets` without filters.
  func getMarkets() async throws -> YieldXyzPerpsGetMarketsResponse {
    try await getMarkets(params: YieldXyzPerpsGetMarketsParams())
  }

  /// Convenience overload of `getActions` for the Portal wallet, without filters.
  func getActions() async throws -> YieldXyzPerpsGetActionsResponse {
    try await getActions(params: YieldXyzPerpsGetActionsParams())
  }

  /// Convenience overload of `getActivity` for the Portal wallet, without filters.
  func getActivity() async throws -> YieldXyzPerpsGetActivityResponse {
    try await getActivity(params: YieldXyzPerpsGetActivityParams())
  }

  /// Convenience overload of `getEvents` for the Portal wallet, without filters.
  func getEvents() async throws -> YieldXyzPerpsGetEventsResponse {
    try await getEvents(params: YieldXyzPerpsGetEventsParams())
  }

  /// Convenience overload of `executeAction` with default options.
  func executeAction(params: YieldXyzPerpsCreateActionParams) async throws -> YieldXyzPerpsExecutionResult {
    try await executeAction(params: params, options: YieldXyzPerpsExecuteOptions())
  }

  /// Convenience overload of `signAndSubmitAction` with default options.
  func signAndSubmitAction(_ action: YieldXyzPerpsAction) async throws -> YieldXyzPerpsExecutionResult {
    try await signAndSubmitAction(action, options: YieldXyzPerpsExecuteOptions())
  }
}

/// Timing of the execution runner's retries. Production uses `.standard`; tests shorten it.
struct YieldXyzPerpsRetryPolicy {
  /// Waits before resubmitting after a `429`, one per retry.
  var rateLimitDelays: [TimeInterval]
  /// Waits before re-sending an on-chain leg Portal reports as `IDEMPOTENT_REQUEST_IN_PROGRESS`,
  /// one per retry.
  var idempotencyInProgressDelays: [TimeInterval]
  /// The shortest wait between two reads of an action, whatever `pollOptions` asks for.
  var minPollInterval: TimeInterval
  /// The longest wait between two reads of an action.
  var maxPollInterval: TimeInterval
  /// Consecutive failed reads of an action tolerated before polling fails.
  var maxConsecutivePollErrors: Int

  static let standard = YieldXyzPerpsRetryPolicy(
    rateLimitDelays: [0.5, 1, 2],
    idempotencyInProgressDelays: [2, 4, 8],
    minPollInterval: 0.25,
    maxPollInterval: 10,
    maxConsecutivePollErrors: 5
  )
}

/// Yield.xyz Perps provider implementation. Reach it through `portal.perps.yieldxyz`.
public class YieldXyzPerps: YieldXyzPerpsProtocol {
  static let defaultSigningChainId = "eip155:42161"
  static let idempotencyKeyPrefix = "yieldxyz-perps-"

  private static let finalActionStatuses: Set<YieldXyzPerpsActionStatus> = [.success, .failed, .canceled, .stale]
  private static let failedActionStatuses: Set<YieldXyzPerpsActionStatus> = [.failed, .canceled, .stale]
  /// Only this status is signed, so a transaction Yield.xyz already recorded is never signed twice.
  private static let signableTransactionStatuses: Set<YieldXyzPerpsTransactionStatus> = [.created]
  /// Statuses showing Yield.xyz already recorded a submission; a submitted transaction is reported
  /// `QUEUED`.
  private static let recordedTransactionStatuses: Set<YieldXyzPerpsTransactionStatus> = [.queued, .broadcasted, .confirmed]

  private let api: PortalYieldXyzPerpsApiProtocol
  private let dependencies: YieldXyzPerpsExecutionDependencies
  private let retryPolicy: YieldXyzPerpsRetryPolicy
  private let inFlightActions = YieldXyzInFlightActions()
  private let logger = PortalLogger.shared

  /// Create an instance of YieldXyzPerps.
  /// - Parameters:
  ///   - api: The Yield.xyz Perps API.
  ///   - dependencies: What the high-level methods need to sign and confirm transactions, and the
  ///     wallet address account requests default to. `Portal` provides all of them.
  public convenience init(
    api: PortalYieldXyzPerpsApiProtocol,
    dependencies: YieldXyzPerpsExecutionDependencies = YieldXyzPerpsExecutionDependencies()
  ) {
    self.init(api: api, dependencies: dependencies, retryPolicy: .standard)
  }

  init(
    api: PortalYieldXyzPerpsApiProtocol,
    dependencies: YieldXyzPerpsExecutionDependencies,
    retryPolicy: YieldXyzPerpsRetryPolicy
  ) {
    self.api = api
    self.dependencies = dependencies
    self.retryPolicy = retryPolicy
  }

  // MARK: - Market data

  public func getProviders() async throws -> YieldXyzPerpsGetProvidersResponse {
    try await api.getProviders()
  }

  public func getProvider(providerId: String) async throws -> YieldXyzPerpsGetProviderResponse {
    try await api.getProvider(providerId: providerId)
  }

  public func getMarkets(params: YieldXyzPerpsGetMarketsParams) async throws -> YieldXyzPerpsGetMarketsResponse {
    try await api.getMarkets(params: params)
  }

  public func getMarket(marketId: String) async throws -> YieldXyzPerpsGetMarketResponse {
    try await api.getMarket(marketId: marketId)
  }

  public func getMarketCandles(
    marketId: String,
    params: YieldXyzPerpsGetMarketCandlesParams
  ) async throws -> YieldXyzPerpsGetMarketCandlesResponse {
    try await api.getMarketCandles(marketId: marketId, params: params)
  }

  // MARK: - Account data

  public func getPositions(params: YieldXyzPerpsPortfolioParams) async throws -> YieldXyzPerpsGetPositionsResponse {
    try assertAtLeastOneProvider("getPositions", providerId: params.providerId, providerIds: params.providerIds)
    return try await api.getPositions(request: YieldXyzPerpsPortfolioRequest(
      address: resolveAddress(params.address),
      providerId: params.providerId,
      providerIds: params.providerIds
    ))
  }

  public func getOrders(params: YieldXyzPerpsPortfolioParams) async throws -> YieldXyzPerpsGetOrdersResponse {
    try assertAtLeastOneProvider("getOrders", providerId: params.providerId, providerIds: params.providerIds)
    return try await api.getOrders(request: YieldXyzPerpsPortfolioRequest(
      address: resolveAddress(params.address),
      providerId: params.providerId,
      providerIds: params.providerIds
    ))
  }

  public func getBalances(params: YieldXyzPerpsBalancesParams) async throws -> YieldXyzPerpsGetBalancesResponse {
    guard !params.providerId.isEmpty else {
      throw YieldXyzPerpsError.providerRequired(method: "getBalances")
    }
    return try await api.getBalances(request: YieldXyzPerpsPortfolioRequest(
      address: resolveAddress(params.address),
      providerId: params.providerId
    ))
  }

  // MARK: - Actions

  public func createAction(params: YieldXyzPerpsCreateActionParams) async throws -> YieldXyzPerpsCreateActionResponse {
    try await api.createAction(request: YieldXyzPerpsCreateActionRequest(
      providerId: params.providerId,
      address: resolveAddress(params.address),
      action: params.action,
      args: params.args
    ))
  }

  public func getActions(params: YieldXyzPerpsGetActionsParams) async throws -> YieldXyzPerpsGetActionsResponse {
    try await api.getActions(request: YieldXyzPerpsGetActionsRequest(address: resolveAddress(params.address), params: params))
  }

  public func getAction(actionId: String) async throws -> YieldXyzPerpsGetActionResponse {
    try await api.getAction(actionId: actionId)
  }

  public func submitTransaction(params: YieldXyzPerpsSubmitTransactionParams) async throws -> YieldXyzPerpsSubmitTransactionResponse {
    if Self.isBlank(params.signedPayload), Self.isBlank(params.transactionHash) {
      throw YieldXyzPerpsError.submissionRequired
    }
    if !Self.isBlank(params.signedPayload), Self.isBlank(params.actionId) {
      throw YieldXyzPerpsError.actionIdRequired
    }
    return try await api.submitTransaction(params: params)
  }

  // MARK: - History

  public func getActivity(params: YieldXyzPerpsGetActivityParams) async throws -> YieldXyzPerpsGetActivityResponse {
    try await api.getActivity(request: YieldXyzPerpsGetActivityRequest(address: resolveAddress(params.address), params: params))
  }

  public func getEvents(params: YieldXyzPerpsGetEventsParams) async throws -> YieldXyzPerpsGetEventsResponse {
    try await api.getEvents(request: YieldXyzPerpsGetEventsRequest(address: resolveAddress(params.address), params: params))
  }

  public func getEvent(eventId: String) async throws -> YieldXyzPerpsGetEventResponse {
    try await api.getEvent(eventId: eventId)
  }

  // MARK: - Health

  public func getHealth() async throws -> YieldXyzPerpsGetHealthResponse {
    try await api.getHealth()
  }

  public func getProvidersHealth() async throws -> YieldXyzPerpsGetProvidersHealthResponse {
    try await api.getProvidersHealth()
  }

  // MARK: - Execution

  public func executeAction(
    params: YieldXyzPerpsCreateActionParams,
    options: YieldXyzPerpsExecuteOptions
  ) async throws -> YieldXyzPerpsExecutionResult {
    let action = try await createAction(params: params).data
    return try await signAndSubmitAction(action, options: options)
  }

  public func signAndSubmitAction(
    _ action: YieldXyzPerpsAction,
    options: YieldXyzPerpsExecuteOptions
  ) async throws -> YieldXyzPerpsExecutionResult {
    let actionId = action.id
    let claimed = inFlightActions.claim(actionId)
    defer {
      if claimed {
        inFlightActions.release(actionId)
      }
    }

    do {
      guard claimed else {
        throw YieldXyzPerpsExecutionError(
          reason: .actionInProgress,
          message: "Action \(actionId) is already being executed.",
          actionId: actionId,
          action: action
        )
      }
      let walletAddress = try await resolveWalletAddressForSigning(action)
      let context = ExecutionContext(actionId: actionId, walletAddress: walletAddress, options: options, latestAction: action)
      let pollOptions: YieldXyzPerpsPollOptions? = options.pollAction ? options.pollOptions : nil
      var processed = Set<String>()
      var executions: [YieldXyzPerpsTransactionExecution] = []

      while !Self.finalActionStatuses.contains(context.latestAction.status) {
        for listed in context.latestAction.transactions {
          if processed.contains(listed.id) || !Self.awaitsSignature(listed) {
            continue
          }
          processed.insert(listed.id)

          let transaction = try await readBeforeSigning(context, listed: listed)
          if Self.finalActionStatuses.contains(context.latestAction.status) {
            break
          }
          guard let transaction else {
            continue
          }
          let execution = try await processTransaction(context, transaction: transaction, index: executions.count)
          executions.append(execution)
        }

        // A final status read back before a signature needs no further polling.
        guard let pollOptions, !Self.finalActionStatuses.contains(context.latestAction.status) else {
          break
        }
        context.latestAction = try await pollForProgress(context, processed: processed, pollOptions: pollOptions)
      }

      let finalAction = context.latestAction
      if Self.failedActionStatuses.contains(finalAction.status) {
        throw YieldXyzPerpsExecutionError(
          reason: .actionFailed,
          message: "Action \(actionId) ended with status \(finalAction.status).",
          actionId: actionId,
          action: finalAction
        )
      }

      return YieldXyzPerpsExecutionResult(
        actionId: actionId,
        action: finalAction,
        status: finalAction.status,
        transactions: executions
      )
    } catch is CancellationError {
      logger.warn("YieldXyzPerps.signAndSubmitAction() - Execution of action \(actionId) was cancelled.")
      throw CancellationError()
    } catch {
      let failure = (error as? YieldXyzPerpsExecutionError) ?? YieldXyzPerpsExecutionError(
        reason: .signingFailed,
        message: "Executing action \(actionId) failed.",
        actionId: actionId,
        underlyingError: error
      )
      logger.error("YieldXyzPerps.signAndSubmitAction() - Action \(actionId) failed (\(failure.reason.rawValue), transaction \(failure.transactionId ?? "none")): \(failure.message)")
      options.onProgress?(YieldXyzPerpsExecutionProgress(
        step: .failed,
        actionId: actionId,
        transactionId: failure.transactionId,
        transactionHash: failure.transactionHash,
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
    let options: YieldXyzPerpsExecuteOptions
    var latestAction: YieldXyzPerpsAction

    init(actionId: String, walletAddress: String, options: YieldXyzPerpsExecuteOptions, latestAction: YieldXyzPerpsAction) {
      self.actionId = actionId
      self.walletAddress = walletAddress
      self.options = options
      self.latestAction = latestAction
    }
  }

  private enum SubmitBody {
    case signature(String)
    case transactionHash(String)
  }

  private enum ReconciliationOutcome {
    case recorded
    case notRecorded
    case unknown
  }

  private static func awaitsSignature(_ transaction: YieldXyzPerpsTransaction) -> Bool {
    signableTransactionStatuses.contains(transaction.status)
  }

  private static func isBlank(_ value: String?) -> Bool {
    value?.isEmpty ?? true
  }

  /// The idempotency key of an `EVM_TRANSACTION` leg, or `nil` when the transaction id cannot form a
  /// valid key (1–255 characters of `A-Z a-z 0-9 . _ ~ -`).
  static func idempotencyKey(forTransactionId transactionId: String) -> String? {
    YieldXyzIdempotency.key(prefix: idempotencyKeyPrefix, transactionId: transactionId)
  }

  private func emit(_ context: ExecutionContext, _ progress: YieldXyzPerpsExecutionProgress) {
    context.options.onProgress?(progress)
  }

  private func transactionError(
    _ context: ExecutionContext,
    _ transaction: YieldXyzPerpsTransaction,
    reason: YieldXyzPerpsExecutionErrorReason,
    message: String,
    broadcastHash: String? = nil,
    action: YieldXyzPerpsAction? = nil,
    underlyingError: Error? = nil
  ) -> YieldXyzPerpsExecutionError {
    YieldXyzPerpsExecutionError(
      reason: reason,
      message: message,
      actionId: context.actionId,
      transactionId: transaction.id,
      broadcastHash: broadcastHash,
      transactionHash: broadcastHash,
      action: action ?? context.latestAction,
      underlyingError: underlyingError
    )
  }

  private func resolveWalletAddressForSigning(_ action: YieldXyzPerpsAction) async throws -> String {
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
      throw YieldXyzPerpsExecutionError(
        reason: .missingWalletAddress,
        message: "No Portal EVM wallet address is available to sign with.",
        actionId: action.id,
        action: action,
        underlyingError: cause
      )
    }
    return walletAddress
  }

  private func resolveAddress(_ address: String?) async throws -> String {
    if let address, !address.isEmpty {
      return address
    }
    guard let walletAddress = try await dependencies.getWalletAddress?(), !walletAddress.isEmpty else {
      throw YieldXyzPerpsError.noAddress
    }
    return walletAddress
  }

  private func assertAtLeastOneProvider(_ method: String, providerId: String?, providerIds: [String]?) throws {
    if Self.isBlank(providerId), !(providerIds ?? []).contains(where: { !$0.isEmpty }) {
      throw YieldXyzPerpsError.providerRequired(method: method)
    }
  }

  /// Reads the action back before `listed` is signed: the action passed in, or one read before an
  /// earlier transaction was processed, may be stale. The transaction is signed only while it still
  /// awaits a signature, and with the payload Yield.xyz lists now.
  private func readBeforeSigning(
    _ context: ExecutionContext,
    listed: YieldXyzPerpsTransaction
  ) async throws -> YieldXyzPerpsTransaction? {
    let current = try await pollAction(
      context,
      schedule: context.options.pollOptions,
      check: { $0 },
      timeoutMessage: { "Reading action \(context.actionId) before signing transaction \(listed.id) timed out (last status \(context.latestAction.status))." }
    )

    guard let latest = current.transactions.first(where: { $0.id == listed.id }) else {
      logger.warn("YieldXyzPerps - Transaction \(listed.id) is no longer listed for action \(context.actionId); it is not signed.")
      return nil
    }
    return Self.awaitsSignature(latest) ? latest : nil
  }

  private func processTransaction(
    _ context: ExecutionContext,
    transaction: YieldXyzPerpsTransaction,
    index: Int
  ) async throws -> YieldXyzPerpsTransactionExecution {
    let signingFormat = transaction.signingFormat
    guard signingFormat == .eip712TypedData || signingFormat == .evmTransaction else {
      throw transactionError(
        context,
        transaction,
        reason: .unsupportedSigningFormat,
        message: "Transaction \(transaction.id) uses signing format \"\(signingFormat?.rawValue ?? "none")\", which is not supported."
      )
    }

    guard transaction.address.lowercased() == context.walletAddress.lowercased() else {
      throw transactionError(
        context,
        transaction,
        reason: .signerAddressMismatch,
        message: "Transaction \(transaction.id) was built for \(transaction.address), not the Portal wallet \(context.walletAddress)."
      )
    }

    if signingFormat == .eip712TypedData {
      return try await processTypedDataTransaction(context, transaction: transaction, index: index)
    }
    return try await processEvmTransaction(context, transaction: transaction, index: index)
  }

  private func processTypedDataTransaction(
    _ context: ExecutionContext,
    transaction: YieldXyzPerpsTransaction,
    index: Int
  ) async throws -> YieldXyzPerpsTransactionExecution {
    let typedData: [String: Any]
    switch YieldXyzPerpsPayloads.prepareTypedData(transaction.signablePayload) {
    case let .success(prepared):
      typedData = prepared
    case let .failure(problem):
      throw transactionError(
        context,
        transaction,
        reason: .invalidSignablePayload,
        message: "The signablePayload of transaction \(transaction.id) \(problem.description)."
      )
    }
    guard let typedDataJSON = YieldXyzPerpsPayloads.typedDataJSON(typedData) else {
      throw transactionError(
        context,
        transaction,
        reason: .invalidSignablePayload,
        message: "The signablePayload of transaction \(transaction.id) cannot be encoded as JSON."
      )
    }

    let chainId = context.options.signingChainId
    try await assertSigningChain(context, transaction, chainId: chainId)

    guard let signTypedData = context.options.signTypedData ?? dependencies.signTypedData else {
      throw transactionError(context, transaction, reason: .dependencyUnavailable, message: "No typed-data signer is configured.")
    }

    emit(context, YieldXyzPerpsExecutionProgress(
      step: .signing,
      actionId: context.actionId,
      transactionId: transaction.id,
      index: index,
      signingFormat: transaction.signingFormat
    ))

    let returned: String?
    do {
      returned = try await signTypedData(YieldXyzPerpsSignTypedDataRequest(
        address: context.walletAddress,
        typedData: typedDataJSON,
        chainId: chainId
      ))
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      throw transactionError(
        context,
        transaction,
        reason: .signingFailed,
        message: "Signing transaction \(transaction.id) failed.",
        underlyingError: error
      )
    }

    guard let returned else {
      throw transactionError(
        context,
        transaction,
        reason: .signatureRejected,
        message: "The signing request for transaction \(transaction.id) was rejected."
      )
    }
    // The signer returns the signature hex-encoded; accept it with or without the `0x` prefix.
    let digits = returned.hasPrefix("0x") || returned.hasPrefix("0X") ? String(returned.dropFirst(2)) : returned
    let signature = "0x" + digits
    guard YieldXyzPerpsPayloads.isSignature(signature) else {
      throw transactionError(
        context,
        transaction,
        reason: .invalidSignature,
        message: "The signer did not return a 65-byte hex signature for transaction \(transaction.id)."
      )
    }

    let submitResult = try await submitWithReconciliation(context, transaction, body: .signature(signature))

    emit(context, YieldXyzPerpsExecutionProgress(
      step: .submitted,
      actionId: context.actionId,
      transactionId: transaction.id,
      index: index,
      signingFormat: transaction.signingFormat
    ))

    return YieldXyzPerpsTransactionExecution(
      transactionId: transaction.id,
      type: transaction.type,
      signingFormat: .eip712TypedData,
      signedPayload: signature,
      submitResult: submitResult
    )
  }

  private func processEvmTransaction(
    _ context: ExecutionContext,
    transaction: YieldXyzPerpsTransaction,
    index: Int
  ) async throws -> YieldXyzPerpsTransactionExecution {
    let request: YieldXyzEvmTransactionRequest
    switch YieldXyzEvmTransactionParams.parse(transaction.signablePayload, defaultFrom: transaction.address) {
    case let .success(parsed):
      request = parsed
    case let .failure(problem):
      throw transactionError(
        context,
        transaction,
        reason: .invalidSignablePayload,
        message: "The signablePayload of transaction \(transaction.id) \(problem.description)."
      )
    }
    guard request.from.lowercased() == context.walletAddress.lowercased() else {
      throw transactionError(
        context,
        transaction,
        reason: .signerAddressMismatch,
        message: "The signablePayload of transaction \(transaction.id) sends from \(request.from), not the Portal wallet \(context.walletAddress)."
      )
    }

    let chainId = try resolveEvmChainId(context, transaction)
    try await assertSigningChain(context, transaction, chainId: chainId)

    let signAndSendTransaction = context.options.signAndSendTransaction ?? dependencies.signAndSendTransaction
    let suppliedBroadcastHash = context.options.broadcastHashes[transaction.id]
    guard let waitForConfirmation = context.options.waitForConfirmation ?? dependencies.waitForConfirmation else {
      throw transactionError(
        context,
        transaction,
        reason: .dependencyUnavailable,
        message: suppliedBroadcastHash == nil && signAndSendTransaction == nil
          ? "No transaction signer and confirmation waiter are configured."
          : "No confirmation waiter is configured."
      )
    }

    let transactionHash: String
    if let suppliedBroadcastHash {
      // A leg the caller reports as already broadcast is confirmed and submitted from that hash
      // but never signed, so it cannot be broadcast twice.
      guard YieldXyzEvmTransactionParams.isTransactionHash(suppliedBroadcastHash) else {
        throw transactionError(
          context,
          transaction,
          reason: .invalidSignature,
          message: "The broadcast hash supplied for transaction \(transaction.id) is not a transaction hash."
        )
      }
      transactionHash = suppliedBroadcastHash
    } else if let signAndSendTransaction {
      transactionHash = try await signAndSendEvmTransaction(
        context,
        transaction: transaction,
        index: index,
        param: YieldXyzEvmTransactionParams.toSendTransactionParam(request),
        chainId: chainId,
        signAndSendTransaction: signAndSendTransaction
      )
    } else {
      throw transactionError(context, transaction, reason: .dependencyUnavailable, message: "No transaction signer is configured.")
    }

    emit(context, YieldXyzPerpsExecutionProgress(
      step: .confirming,
      actionId: context.actionId,
      transactionId: transaction.id,
      index: index,
      signingFormat: transaction.signingFormat,
      transactionHash: transactionHash
    ))

    let confirmed: Bool
    do {
      confirmed = try await waitForConfirmation(transactionHash, chainId)
    } catch {
      throw transactionError(
        context,
        transaction,
        reason: .transactionNotConfirmed,
        message: "Confirming transaction \(transaction.id) (\(transactionHash)) failed.",
        broadcastHash: transactionHash,
        underlyingError: error
      )
    }
    guard confirmed else {
      throw transactionError(
        context,
        transaction,
        reason: .transactionNotConfirmed,
        message: "Transaction \(transaction.id) (\(transactionHash)) did not confirm successfully.",
        broadcastHash: transactionHash
      )
    }

    emit(context, YieldXyzPerpsExecutionProgress(
      step: .confirmed,
      actionId: context.actionId,
      transactionId: transaction.id,
      index: index,
      signingFormat: transaction.signingFormat,
      transactionHash: transactionHash
    ))

    let submitResult: YieldXyzPerpsSubmitResult?
    do {
      submitResult = try await submitWithReconciliation(context, transaction, body: .transactionHash(transactionHash))
    } catch is CancellationError {
      // The leg is on-chain: keep its hash so the caller can resume with `broadcastHashes`.
      throw transactionError(
        context,
        transaction,
        reason: .submitOutcomeUnknown,
        message: "Submitting transaction \(transaction.id) (\(transactionHash)) was cancelled; resume with broadcastHashes.",
        broadcastHash: transactionHash,
        underlyingError: CancellationError()
      )
    }

    emit(context, YieldXyzPerpsExecutionProgress(
      step: .submitted,
      actionId: context.actionId,
      transactionId: transaction.id,
      index: index,
      signingFormat: transaction.signingFormat,
      transactionHash: transactionHash
    ))

    return YieldXyzPerpsTransactionExecution(
      transactionId: transaction.id,
      type: transaction.type,
      signingFormat: .evmTransaction,
      transactionHash: transactionHash,
      submitResult: submitResult
    )
  }

  /// Signs and broadcasts an on-chain leg. With an idempotency key, Portal broadcasts the leg at
  /// most once: a send it reports as still in progress is retried with the same key a few times,
  /// and a send it reports as already completed stops with `transactionAlreadyBroadcast`, because
  /// Portal does not return the hash of that broadcast.
  private func signAndSendEvmTransaction(
    _ context: ExecutionContext,
    transaction: YieldXyzPerpsTransaction,
    index: Int,
    param: ETHTransactionParam,
    chainId: String,
    signAndSendTransaction: YieldXyzPerpsSignAndSendTransaction
  ) async throws -> String {
    var idempotencyKey: String?
    if context.options.useIdempotencyKeys {
      idempotencyKey = Self.idempotencyKey(forTransactionId: transaction.id)
      if idempotencyKey == nil {
        logger.warn("YieldXyzPerps - Transaction id \(transaction.id) cannot form an idempotency key; it is sent without one.")
      }
    }

    emit(context, YieldXyzPerpsExecutionProgress(
      step: .signing,
      actionId: context.actionId,
      transactionId: transaction.id,
      index: index,
      signingFormat: transaction.signingFormat
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
          throw transactionError(
            context,
            transaction,
            reason: .signingFailed,
            message: "Portal is still processing the send of transaction \(transaction.id); resume the action later.",
            underlyingError: error
          )
        }
        try await Self.sleep(seconds: retryPolicy.idempotencyInProgressDelays[inProgressRetries])
        inProgressRetries += 1
      } catch let error as PortalMpcError where idempotencyKey != nil && error.id == PortalIdempotencyErrorId.requestAlreadyCompleted {
        throw transactionError(
          context,
          transaction,
          reason: .transactionAlreadyBroadcast,
          message: "Portal already broadcast transaction \(transaction.id) and does not return its hash; look it up on-chain and resume with broadcastHashes.",
          underlyingError: error
        )
      } catch let error as PortalMpcError where idempotencyKey != nil && error.isIdempotencyRejection {
        // Every later send of this leg under the same key gets the same answer while Portal
        // remembers the key: check the chain, then build a new action (its legs get new keys).
        throw transactionError(
          context,
          transaction,
          reason: .signingFailed,
          message: "Portal refused to send transaction \(transaction.id) again under its idempotency key (\(error.id ?? "unknown")); check the chain before building a new action.",
          underlyingError: error
        )
      } catch {
        throw transactionError(
          context,
          transaction,
          reason: .signingFailed,
          message: "Sending transaction \(transaction.id) failed.",
          underlyingError: error
        )
      }
    }

    guard let returned else {
      throw transactionError(
        context,
        transaction,
        reason: .signatureRejected,
        message: "The signing request for transaction \(transaction.id) was rejected."
      )
    }
    guard YieldXyzEvmTransactionParams.isTransactionHash(returned) else {
      throw transactionError(
        context,
        transaction,
        reason: .invalidSignature,
        message: "The signer did not return a transaction hash for transaction \(transaction.id)."
      )
    }
    return returned
  }

  /// Real chains arrive as CAIP-2 in `network`; otherwise fall back to the numeric `chainId`.
  private func resolveEvmChainId(_ context: ExecutionContext, _ transaction: YieldXyzPerpsTransaction) throws -> String {
    if YieldXyzEvmTransactionParams.isEvmChainId(transaction.network) {
      return transaction.network
    }
    let fromChainId = "eip155:\(transaction.chainId)"
    if YieldXyzEvmTransactionParams.isEvmChainId(fromChainId) {
      return fromChainId
    }
    throw transactionError(
      context,
      transaction,
      reason: .invalidSignablePayload,
      message: "Transaction \(transaction.id) does not identify an EVM chain (network \"\(transaction.network)\", chainId \"\(transaction.chainId)\")."
    )
  }

  private func assertSigningChain(
    _ context: ExecutionContext,
    _ transaction: YieldXyzPerpsTransaction,
    chainId: String
  ) async throws {
    guard chainId.hasPrefix("eip155:") else {
      throw transactionError(
        context,
        transaction,
        reason: .signingChainNotConfigured,
        message: "Transaction \(transaction.id) must be signed through an EIP-155 chain, got \"\(chainId)\"."
      )
    }
    if let isChainConfigured = dependencies.isChainConfigured, !(await isChainConfigured(chainId)) {
      throw transactionError(
        context,
        transaction,
        reason: .signingChainNotConfigured,
        message: "No RPC endpoint is configured for \(chainId); add it to rpcConfig to sign transaction \(transaction.id)."
      )
    }
  }

  /// Submits, retrying only when that is known to be safe: after a `429` (the request was not
  /// processed), or after an ambiguous failure once the action shows the transaction was not
  /// recorded and the submission is a transaction hash (recording a hash cannot execute anything
  /// twice). A signature is never resubmitted after an ambiguous failure.
  private func submitWithReconciliation(
    _ context: ExecutionContext,
    _ transaction: YieldXyzPerpsTransaction,
    body: SubmitBody
  ) async throws -> YieldXyzPerpsSubmitResult? {
    var params = YieldXyzPerpsSubmitTransactionParams(transactionId: transaction.id)
    var transactionHash: String?
    switch body {
    case let .signature(signature):
      params.signedPayload = signature
      params.actionId = context.actionId
    case let .transactionHash(hash):
      params.transactionHash = hash
      transactionHash = hash
    }

    var rateLimitRetries = 0
    var hashResubmitted = false

    while true {
      let failure: Error
      do {
        let result = try await api.submitTransaction(params: params).data
        if result.status == .failed {
          throw transactionError(
            context,
            transaction,
            reason: .submitFailed,
            message: "Yield.xyz reported transaction \(transaction.id) as FAILED\(result.error.map { ": \($0)" } ?? "").",
            broadcastHash: transactionHash
          )
        }
        return result
      } catch let error as YieldXyzPerpsExecutionError {
        throw error
      } catch is CancellationError {
        throw CancellationError()
      } catch {
        failure = error
      }

      if YieldXyzRequestFailure.status(of: failure) == 429, rateLimitRetries < retryPolicy.rateLimitDelays.count {
        try await Self.sleep(seconds: retryPolicy.rateLimitDelays[rateLimitRetries])
        rateLimitRetries += 1
        continue
      }

      if !YieldXyzRequestFailure.isAmbiguous(failure) {
        throw transactionError(
          context,
          transaction,
          reason: .submitRejected,
          message: YieldXyzRequestFailure.isRefusedBeforeSending(failure)
            ? "The submission of transaction \(transaction.id) could not be sent."
            : "Yield.xyz rejected the submission of transaction \(transaction.id).",
          broadcastHash: transactionHash,
          underlyingError: failure
        )
      }

      let outcome = try await reconcileSubmission(context, transaction, broadcastHash: transactionHash)
      if outcome == .recorded {
        return nil
      }
      if outcome == .notRecorded, transactionHash != nil, !hashResubmitted {
        hashResubmitted = true
        continue
      }

      throw transactionError(
        context,
        transaction,
        reason: .submitOutcomeUnknown,
        message: "The submission of transaction \(transaction.id) failed and its outcome could not be confirmed; check the action before retrying.",
        broadcastHash: transactionHash,
        underlyingError: failure
      )
    }
  }

  private func reconcileSubmission(
    _ context: ExecutionContext,
    _ transaction: YieldXyzPerpsTransaction,
    broadcastHash: String?
  ) async throws -> ReconciliationOutcome {
    let action: YieldXyzPerpsAction
    do {
      action = try await api.getAction(actionId: context.actionId).data
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      logger.warn("YieldXyzPerps - Could not read action \(context.actionId) to reconcile a failed submission: \(error.localizedDescription)")
      return .unknown
    }

    guard let latest = action.transactions.first(where: { $0.id == transaction.id }) else {
      return .unknown
    }
    context.latestAction = action

    if Self.recordedTransactionStatuses.contains(latest.status) {
      return .recorded
    }
    if latest.status == .failed {
      throw transactionError(
        context,
        transaction,
        reason: .submitFailed,
        message: "Yield.xyz reported transaction \(transaction.id) as FAILED.",
        broadcastHash: broadcastHash,
        action: action
      )
    }
    // An ended action leaves its unsubmitted transactions CREATED: they are not awaiting a
    // submission any more.
    if Self.failedActionStatuses.contains(action.status) {
      throw transactionError(
        context,
        transaction,
        reason: .actionFailed,
        message: "Action \(context.actionId) ended with status \(action.status).",
        broadcastHash: broadcastHash,
        action: action
      )
    }
    return Self.signableTransactionStatuses.contains(latest.status) ? .notRecorded : .unknown
  }

  /// Polls until the action is final or has new pending transactions to sign.
  private func pollForProgress(
    _ context: ExecutionContext,
    processed: Set<String>,
    pollOptions: YieldXyzPerpsPollOptions
  ) async throws -> YieldXyzPerpsAction {
    try await pollAction(
      context,
      schedule: pollOptions,
      check: { action in
        let hasNewTransactions = action.transactions.contains { !processed.contains($0.id) && Self.awaitsSignature($0) }
        return Self.finalActionStatuses.contains(action.status) || hasNewTransactions ? action : nil
      },
      timeoutMessage: { "Action \(context.actionId) did not reach a final status in time (last status \(context.latestAction.status))." }
    )
  }

  /// Reads the action back until `check` returns a value. Rate limits, 5xx, transport failures and
  /// undecodable bodies are retried up to `maxConsecutivePollErrors` times in a row; any other
  /// failure stops polling. The wait between reads grows by 1.5× up to `maxPollInterval`.
  private func pollAction<T>(
    _ context: ExecutionContext,
    schedule: YieldXyzPerpsPollOptions,
    check: (YieldXyzPerpsAction) -> T?,
    timeoutMessage: () -> String
  ) async throws -> T {
    var consecutiveErrors = 0
    do {
      return try await YieldXyzPollLoop.run(
        intervalSeconds: schedule.intervalSeconds,
        timeoutSeconds: schedule.timeoutSeconds,
        minIntervalSeconds: retryPolicy.minPollInterval,
        maxIntervalSeconds: retryPolicy.maxPollInterval
      ) { () async throws -> YieldXyzPollStep<T> in
        var action: YieldXyzPerpsAction?
        var failure: Error?
        do {
          action = try await api.getAction(actionId: context.actionId).data
        } catch is CancellationError {
          throw CancellationError()
        } catch {
          failure = error
        }

        if let action {
          consecutiveErrors = 0
          context.latestAction = action
          emit(context, YieldXyzPerpsExecutionProgress(step: .polling, actionId: context.actionId, actionStatus: action.status))
          if let value = check(action) {
            return .stop(value)
          }
          return .continue
        }

        consecutiveErrors += 1
        let transient = failure.map(YieldXyzRequestFailure.isTransient) ?? true
        if !transient || consecutiveErrors >= retryPolicy.maxConsecutivePollErrors {
          throw YieldXyzPerpsExecutionError(
            reason: .pollingFailed,
            message: "Reading action \(context.actionId) failed.",
            actionId: context.actionId,
            action: context.latestAction,
            underlyingError: failure
          )
        }
        return .continue
      }
    } catch is YieldXyzPollLoopTimeout {
      throw YieldXyzPerpsExecutionError(
        reason: .timeout,
        message: timeoutMessage(),
        actionId: context.actionId,
        action: context.latestAction
      )
    }
  }

  private static func sleep(seconds: TimeInterval) async throws {
    try await YieldXyzExecutionClock.sleep(seconds: seconds)
  }
}
