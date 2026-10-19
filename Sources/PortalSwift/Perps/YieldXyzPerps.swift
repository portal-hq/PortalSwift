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
  /// Lists an account's actions on one venue. Requires `providerId`.
  func getActions(params: YieldXyzPerpsGetActionsParams) async throws -> YieldXyzPerpsGetActionsResponse
  /// Gets one action with its transactions and status.
  func getAction(actionId: String) async throws -> YieldXyzPerpsGetActionResponse

  /// Submits a signature (`signedPayload`, which requires `actionId`) or the hash of a broadcast
  /// transaction (`transactionHash`). A response whose `data.status` is `FAILED` is still a failure.
  func submitTransaction(params: YieldXyzPerpsSubmitTransactionParams) async throws -> YieldXyzPerpsSubmitTransactionResponse

  /// Gets an account's unified activity feed: its actions and lifecycle events, newest first.
  /// Requires `providerId` or `providerIds`.
  func getActivity(params: YieldXyzPerpsGetActivityParams) async throws -> YieldXyzPerpsGetActivityResponse
  /// Lists an account's lifecycle events (fills, liquidations, stop-loss / take-profit triggers).
  /// Requires `providerId` or `providerIds`.
  func getEvents(params: YieldXyzPerpsGetEventsParams) async throws -> YieldXyzPerpsGetEventsResponse
  /// Gets one lifecycle event.
  func getEvent(eventId: String) async throws -> YieldXyzPerpsGetEventResponse

  /// Gets the Yield.xyz Perps API health.
  func getHealth() async throws -> YieldXyzPerpsGetHealthResponse
  /// Gets per-venue health.
  func getProvidersHealth() async throws -> YieldXyzPerpsGetProvidersHealthResponse

  /// Creates an action, then signs and submits its transactions in order and tracks it to a final
  /// status (see `signAndSubmitAction`).
  ///
  /// A failure to create the action is thrown as the API reported it (read it with
  /// `YieldXyzPerpsApiError.from(_:)`), with no `failed` progress event; only the signing and tracking
  /// that follow throw `YieldXyzPerpsExecutionError`.
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
  /// Cancelling the surrounding task stops the execution with `CancellationError`, except between
  /// an on-chain leg's broadcast and the submission of its hash: then it fails with
  /// `submitOutcomeUnknown` carrying that leg's `broadcastHash`. The `confirming` progress event
  /// also reports the hash as soon as the leg is broadcast.
  func signAndSubmitAction(_ action: YieldXyzPerpsAction, options: YieldXyzPerpsExecuteOptions) async throws -> YieldXyzPerpsExecutionResult
}

public extension YieldXyzPerpsProtocol {
  /// Convenience overload of `getMarkets` without filters.
  func getMarkets() async throws -> YieldXyzPerpsGetMarketsResponse {
    try await getMarkets(params: YieldXyzPerpsGetMarketsParams())
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
  /// Polling fails on this many consecutive failed reads of an action (with 5, four in a row are
  /// retried and the fifth fails).
  var maxConsecutivePollErrors: Int

  static let standard = YieldXyzPerpsRetryPolicy(
    rateLimitDelays: [0.5, 1, 2],
    idempotencyInProgressDelays: [2, 4, 8],
    minPollInterval: 0.25,
    maxPollInterval: 10,
    maxConsecutivePollErrors: 5
  )
}

/// Ids of the actions being executed. Two overlapping executions of one action would both read a
/// transaction awaiting a signature and both sign it. `Portal` owns one and shares it with every
/// `YieldXyzPerps` it builds, so the guard holds even if two of them are created.
final class YieldXyzPerpsInFlightActions {
  private let lock = NSLock()
  private var actionIds = Set<String>()

  /// Claims `actionId` for one execution; `false` when another execution holds it.
  func claim(_ actionId: String) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return actionIds.insert(actionId).inserted
  }

  func release(_ actionId: String) {
    lock.lock()
    defer { lock.unlock() }
    actionIds.remove(actionId)
  }
}

/// Yield.xyz Perps provider implementation. Reach it through `portal.perps.yieldxyz`.
public class YieldXyzPerps: YieldXyzPerpsProtocol {
  static let defaultSigningChainId = "eip155:42161"
  static let idempotencyKeyPrefix = "yieldxyz-perps-"

  static let finalActionStatuses: Set<YieldXyzPerpsActionStatus> = [.success, .failed, .canceled, .stale]
  static let failedActionStatuses: Set<YieldXyzPerpsActionStatus> = [.failed, .canceled, .stale]
  /// Only this status is signed, so a transaction Yield.xyz already recorded is never signed twice.
  static let signableTransactionStatuses: Set<YieldXyzPerpsTransactionStatus> = [.created]
  /// Statuses showing Yield.xyz already recorded a submission; a submitted transaction is reported
  /// `QUEUED`.
  static let recordedTransactionStatuses: Set<YieldXyzPerpsTransactionStatus> = [.queued, .broadcasted, .confirmed]

  let api: PortalYieldXyzPerpsApiProtocol
  let dependencies: YieldXyzPerpsExecutionDependencies
  let retryPolicy: YieldXyzPerpsRetryPolicy
  let inFlightActions: YieldXyzPerpsInFlightActions
  let logger = PortalLogger.shared

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
    retryPolicy: YieldXyzPerpsRetryPolicy,
    inFlightActions: YieldXyzPerpsInFlightActions = YieldXyzPerpsInFlightActions()
  ) {
    self.api = api
    self.dependencies = dependencies
    self.retryPolicy = retryPolicy
    self.inFlightActions = inFlightActions
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
    guard !params.providerId.isEmpty else {
      throw YieldXyzPerpsError.providerRequired(method: "createAction")
    }
    return try await api.createAction(request: YieldXyzPerpsCreateActionRequest(
      providerId: params.providerId,
      address: resolveAddress(params.address),
      action: params.action,
      args: params.args
    ))
  }

  public func getActions(params: YieldXyzPerpsGetActionsParams) async throws -> YieldXyzPerpsGetActionsResponse {
    // Yield.xyz rejects a list without a venue; the Portal API forwards it, so fail here first.
    guard !Self.isBlank(params.providerId) else {
      throw YieldXyzPerpsError.providerRequired(method: "getActions")
    }
    return try await api.getActions(request: YieldXyzPerpsGetActionsRequest(address: resolveAddress(params.address), params: params))
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
    try assertAtLeastOneProvider("getActivity", providerId: params.providerId, providerIds: params.providerIds)
    return try await api.getActivity(request: YieldXyzPerpsGetActivityRequest(address: resolveAddress(params.address), params: params))
  }

  public func getEvents(params: YieldXyzPerpsGetEventsParams) async throws -> YieldXyzPerpsGetEventsResponse {
    try assertAtLeastOneProvider("getEvents", providerId: params.providerId, providerIds: params.providerIds)
    return try await api.getEvents(request: YieldXyzPerpsGetEventsRequest(address: resolveAddress(params.address), params: params))
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
    let action: YieldXyzPerpsAction
    do {
      action = try await createAction(params: params).data
    } catch let error where Self.isCancellation(error) {
      throw CancellationError()
    }
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
        if Self.finalActionStatuses.contains(context.latestAction.status) {
          break
        }
        // A read-back can list transactions the pass above never saw, for example when the action
        // passed in is stale: sign them now, without waiting, whether or not the action is polled.
        if Self.hasTransactionsToSign(context.latestAction, processed: processed) {
          continue
        }
        guard let pollOptions else {
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
    } catch let error where Self.isCancellation(error) {
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

  // MARK: - Validation helpers

  private static func isBlank(_ value: String?) -> Bool {
    value?.isEmpty ?? true
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
}
