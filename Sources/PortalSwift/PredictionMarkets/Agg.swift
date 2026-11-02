//
//  Agg.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Agg: prediction markets across venues, through one method per Agg route plus helpers that run
/// the multi-step flows.
public protocol AggProtocol: PortalAggApiProtocol {
  /// Links the Portal wallet to its Agg account.
  func connect(chainId: String) async throws -> AggLink
  /// Whether the client is linked to Agg.
  func isConnected() async throws -> Bool
  /// Sends funds from the Portal wallet to the user's Agg deposit address.
  func deposit(params: AggDepositParams) async throws -> AggDepositResult
  /// Buys an outcome and waits for the fill to finish.
  func buy(params: AggBuyParams) async throws -> AggTradeResult
  /// Sells shares of an outcome and waits for the fill to finish.
  func sell(params: AggSellParams) async throws -> AggTradeResult
  /// Places a resting order from a decimal price and size.
  func placeLimitOrder(params: AggPlaceLimitOrderParams) async throws -> AggLimitOrder
  /// Redeems every eligible live position.
  func redeemAll(params: AggRedeemAllParams) async throws -> [AggRedeemResult]
  /// Withdraws from the Agg balance and waits for the withdrawal to finish.
  func withdraw(params: AggWithdrawParams) async throws -> AggWithdrawal
}

public extension AggProtocol {
  /// Links the Portal wallet on Polygon (`Agg.defaultLinkChainId`).
  func connect() async throws -> AggLink {
    try await connect(chainId: Agg.defaultLinkChainId)
  }

  func redeemAll() async throws -> [AggRedeemResult] {
    try await redeemAll(params: AggRedeemAllParams())
  }
}

/// Agg: prediction markets across venues (Polymarket, Kalshi, Limitless and more) through one Agg
/// account per client. Reach it through `portal.predictionMarkets.agg`.
///
/// Discovery and market data work right away. Everything else needs the client linked first with
/// `connect`, and is unavailable to account-abstracted clients. Live trading is geo-blocked in some
/// countries (the US on every venue); `mode: .paper` simulates trades anywhere.
///
/// Request failures are thrown as `AggRequestError`: read the Portal error `id`, Agg's `details` and
/// the request's trace id with `AggApiError.from(_:)`. On `AGG_LINK_REQUIRED`, run `connect` again
/// and retry. Cancelling the calling task cancels the call; a helper cancelled after it filled or
/// withdrew does not undo it.
public class Agg: AggProtocol {
  /// The CAIP-2 chain `connect` signs the link on by default (Polygon), as the Portal API does.
  public static let defaultLinkChainId = "eip155:137"

  /// Limit prices and sizes are scaled by 1e6.
  static let microDecimals = 6
  static let maxRedeemBatch = 20
  static let minOrderPollInterval: TimeInterval = 0.25
  static let maxOrderPollInterval: TimeInterval = 10
  static let maxTransientFailures = 5
  static let maxCallAttempts = 3
  /// The only final states in which the fill traded.
  static let successfulExecutionStates: Set<AggExecutionState> = [.filled, .partiallyFilled]
  static let finalWithdrawalStatuses: Set<AggWithdrawalStatus> = [.completed, .partial, .failed]

  private let api: PortalAggApiProtocol
  private let dependencies: AggDependencies
  /// Seconds before the second attempt of a call `retryingTransient` repeats; the third waits twice
  /// as long.
  private let transientRetryDelay: TimeInterval
  private let linkChainLock = NSLock()
  /// The chain the last successful `connect` signed on.
  private var lastLinkChainId: String?

  /// Create an instance of `Agg`.
  /// - Parameters:
  ///   - api: The Agg API.
  ///   - dependencies: What `connect` and `deposit` need to sign and send. `Portal` provides all of
  ///     them.
  public convenience init(api: PortalAggApiProtocol, dependencies: AggDependencies = AggDependencies()) {
    self.init(api: api, dependencies: dependencies, transientRetryDelay: 1)
  }

  init(api: PortalAggApiProtocol, dependencies: AggDependencies, transientRetryDelay: TimeInterval) {
    self.api = api
    self.dependencies = dependencies
    self.transientRetryDelay = transientRetryDelay
  }

  /*******************************************
   * Link
   *******************************************/

  /// Starts a link: returns the challenge to sign. `connect` runs the whole link.
  public func createLinkChallenge(request: AggLinkChallengeRequest) async throws -> AggCreateLinkChallengeResponse {
    try await api.createLinkChallenge(request: request)
  }

  /// Completes a link with the challenge's signature. `connect` runs the whole link.
  public func createLink(request: AggLinkRequest) async throws -> AggCreateLinkResponse {
    try await api.createLink(request: request)
  }

  /// Gets the stored link. It can read linked while the next call still fails with
  /// `AGG_LINK_REQUIRED`; branch on that error rather than on this status.
  public func getLink() async throws -> AggGetLinkResponse {
    try await api.getLink()
  }

  /// Unlinks the client from Agg.
  public func deleteLink() async throws -> AggDeleteLinkResponse {
    try await api.deleteLink()
  }

  /*******************************************
   * Discovery (no link needed)
   *******************************************/

  /// Lists events with their markets and outcomes. An open event can contain closed markets: filter
  /// on both statuses before quoting an outcome.
  public func listEvents(params: AggListEventsParams) async throws -> AggListEventsResponse {
    try await api.listEvents(params: params)
  }

  /// Gets one event, including its `description`.
  public func getEvent(eventId: String, cluster: Bool?) async throws -> AggGetEventResponse {
    try await api.getEvent(eventId: eventId, cluster: cluster)
  }

  /// Gets an event page: the event, its first markets and the outcomes to chart.
  public func getEventBootstrap(eventId: String, limit: Int?) async throws -> AggGetEventBootstrapResponse {
    try await api.getEventBootstrap(eventId: eventId, limit: limit)
  }

  /// Lists markets, with their order constraints (`tickSize`, `minOrderSize`) and fees.
  public func listMarkets(params: AggListMarketsParams) async throws -> AggListMarketsResponse {
    try await api.listMarkets(params: params)
  }

  /// Searches events or markets, ranked by relevance.
  public func search(params: AggSearchParams) async throws -> AggSearchResponse {
    try await api.search(params: params)
  }

  /// Lists categories, or a category's children.
  public func listCategories(params: AggListCategoriesParams) async throws -> AggListCategoriesResponse {
    try await api.listCategories(params: params)
  }

  /// Gets the countries each venue blocks.
  public func getVenueGeoPolicy() async throws -> AggGetVenueGeoPolicyResponse {
    try await api.getVenueGeoPolicy()
  }

  /// Gets the app's venue and category switches.
  public func getAppConfig() async throws -> AggGetAppConfigResponse {
    try await api.getAppConfig()
  }

  /*******************************************
   * Market data (no link needed)
   *******************************************/

  /// Gets live midpoints for a batch of markets.
  public func getMidpoints(venueMarketIds: [String], bestPrice: Bool?) async throws -> AggGetMidpointsResponse {
    try await api.getMidpoints(venueMarketIds: venueMarketIds, bestPrice: bestPrice)
  }

  /// Gets live order books for a batch of markets.
  public func getOrderbooks(venueMarketIds: [String], depth: Int?) async throws -> AggGetOrderbooksResponse {
    try await api.getOrderbooks(venueMarketIds: venueMarketIds, depth: depth)
  }

  /// Gets one outcome's ladder and depth.
  public func getOutcomeOrderbook(outcomeId: String, depth: Int?) async throws -> AggGetOutcomeOrderbookResponse {
    try await api.getOutcomeOrderbook(outcomeId: outcomeId, depth: depth)
  }

  /// Gets OHLCV bars for an outcome. While `meta.state` is `.warming`, retry after
  /// `meta.retryAfterMs`.
  public func getChartBars(params: AggChartParams) async throws -> AggGetChartBarsResponse {
    try await api.getChartBars(params: params)
  }

  /// Gets the CDN chunks of an outcome's finalized chart history.
  public func getChartHistoryManifest(params: AggChartParams) async throws -> AggGetChartHistoryManifestResponse {
    try await api.getChartHistoryManifest(params: params)
  }

  /*******************************************
   * Account
   *******************************************/

  /// Gets the Agg user profile.
  public func getUser() async throws -> AggGetUserResponse {
    try await api.getUser()
  }

  /// Gets where to send funds. Wallets are provisioned lazily, so poll while it is `.notReady`; read
  /// it each time it is needed rather than caching it.
  public func getDepositAddresses() async throws -> AggGetDepositAddressesResponse {
    try await api.getDepositAddresses()
  }

  /// Gets the managed balance. Funds are per chain: what a quote can spend depends on which chain
  /// holds them.
  /// - Parameter sync: Re-read the chains first, e.g. after a deposit. Live mode only.
  public func getBalances(sync: Bool?, mode: AggMode?) async throws -> AggGetBalancesResponse {
    try await api.getBalances(sync: sync, mode: mode)
  }

  /// Lists open and resolved positions. Redeem with `venueBreakdown[].venueMarketOutcomeId` once
  /// `eligible`.
  public func listPositions(params: AggListPositionsParams) async throws -> AggListPositionsResponse {
    try await api.listPositions(params: params)
  }

  /// Lists orders.
  public func listOrders(params: AggListOrdersParams) async throws -> AggListOrdersResponse {
    try await api.listOrders(params: params)
  }

  /// Lists trades, transfers and claims, newest first.
  public func listActivity(params: AggListActivityParams) async throws -> AggListActivityResponse {
    try await api.listActivity(params: params)
  }

  /*******************************************
   * Trading
   *******************************************/

  /// Prices an outcome across every venue. Offer the fill only when `status` is `ok` and `warnings`
  /// is empty; re-quote after `refreshAt`.
  public func createQuote(request: AggQuoteRequest) async throws -> AggCreateQuoteResponse {
    try await api.createQuote(request: request)
  }

  /// Fills a quote from the Agg balance; poll `getOrder` with its `quoteId` until it is terminal.
  public func createOrder(request: AggOrderRequest) async throws -> AggCreateOrderResponse {
    try await api.createOrder(request: request)
  }

  /// Gets a fill's progress. Wait `pollAfterMs` between reads and stop at `terminal`.
  public func getOrder(quoteId: String, mode: AggMode?) async throws -> AggGetOrderResponse {
    try await api.getOrder(quoteId: quoteId, mode: mode)
  }

  /// Places a resting limit order. `placeLimitOrder` takes the price and size as decimals.
  public func createLimitOrder(request: AggLimitOrderRequest) async throws -> AggCreateLimitOrderResponse {
    try await api.createLimitOrder(request: request)
  }

  /// Places a market order on one named venue, without a quote.
  public func createDirectOrder(request: AggDirectOrderRequest) async throws -> AggCreateDirectOrderResponse {
    try await api.createDirectOrder(request: request)
  }

  /// Cancels a resting order; it can come back `cancel_pending` or `cancelled`.
  public func cancelOrder(request: AggCancelOrderRequest) async throws -> AggCancelOrderResponse {
    try await api.cancelOrder(request: request)
  }

  /// Redeems resolved positions; the payout lands in the Agg balance at par.
  public func redeemPositions(request: AggRedeemRequest) async throws -> AggRedeemPositionsResponse {
    try await api.redeemPositions(request: request)
  }

  /*******************************************
   * Withdrawals
   *******************************************/

  /// Gets how much can leave, to a given chain.
  public func quoteWithdrawable(request: AggWithdrawableQuoteRequest) async throws -> AggQuoteWithdrawableResponse {
    try await api.quoteWithdrawable(request: request)
  }

  /// Gets a withdrawal's fees and receive amount; dispatches nothing. A `200` can still be
  /// `unviable`: offer the withdrawal only when `pricingStatus` is `quoted`.
  public func previewWithdrawal(request: AggWithdrawalRequest) async throws -> AggPreviewWithdrawalResponse {
    try await api.previewWithdrawal(request: request)
  }

  /// Moves funds out of Agg. Pass a `requestId` to make it safe to retry.
  public func createWithdrawal(request: AggWithdrawalRequest) async throws -> AggWithdrawalResponse {
    try await api.createWithdrawal(request: request)
  }

  /// Gets a withdrawal's status. `legs[].txHash` holds the transaction hash.
  public func getWithdrawal(withdrawalId: String) async throws -> AggWithdrawalResponse {
    try await api.getWithdrawal(withdrawalId: withdrawalId)
  }

  /*******************************************
   * Helpers
   *******************************************/

  /// Links the Portal wallet to its Agg account: requests a Sign-In with Ethereum challenge for
  /// `chainId`, signs it with `personal_sign` and completes the link. Run it again whenever a call
  /// fails with `AGG_LINK_REQUIRED`.
  ///
  /// Nothing is signed unless `chainId` has an RPC URL configured (`AggError.missingRpcUrl`) and the
  /// challenge names the wallet's own address (`AggError.addressMismatch`). With Signature Approvals
  /// on, the signature reaches the approval hook as a normal `personal_sign`. A helper's
  /// `autoReconnect` links again on the chain of the last successful `connect`.
  /// - Parameter chainId: The CAIP-2 EVM chain named in the sign-in message and used to sign it.
  public func connect(chainId: String) async throws -> AggLink {
    if let isChainConfigured = dependencies.isChainConfigured {
      let configured = await isChainConfigured(chainId)
      if !configured {
        throw AggError.missingRpcUrl(chainId: chainId)
      }
    }
    guard let personalSign = dependencies.personalSign else {
      throw AggError.missingDependency(name: "personalSign")
    }
    guard let address = await dependencies.getAddress?(chainId), !address.isEmpty else {
      throw AggError.noAddress
    }

    let challenge = try await api.createLinkChallenge(request: AggLinkChallengeRequest(chainId: chainId)).data
    let signer = challenge.signParams.count > 1 ? challenge.signParams[1] : nil
    guard challenge.signParams.count == 2, let signer, signer.lowercased() == address.lowercased() else {
      throw AggError.addressMismatch(expected: address, actual: signer)
    }

    let signature = try await personalSign(chainId, challenge.signParams)
    let link = try await api.createLink(request: AggLinkRequest(signature: signature)).data
    rememberLinkChain(chainId)
    return link
  }

  /// Whether the client is linked to Agg. Where the Portal API checks the Agg session on `GET /link`
  /// (LM2K-792), `false` also means the session expired: run `connect`.
  public func isConnected() async throws -> Bool {
    try await getLink().data.isLinked
  }

  /// Sends funds from the Portal wallet to the user's Agg deposit address and returns once the
  /// transfer is broadcast. It waits for the deposit addresses, which Agg creates for a new user
  /// after the first request, and sends nothing unless Agg takes `params.token` on `params.chainId`
  /// (`AggError.unsupportedDepositToken`). Agg credits the funds once the transaction confirms: read
  /// `getBalances(sync: true, mode: nil)` to see them. The send carries `params.idempotencyKey`, so
  /// calling again with the same params never broadcasts it twice.
  public func deposit(params: AggDepositParams) async throws -> AggDepositResult {
    try Self.requireAmount("amount", params.amount)
    guard let sendAsset = dependencies.sendAsset else {
      throw AggError.missingDependency(name: "sendAsset")
    }
    let notify = Self.progress(params.onProgress)

    notify(AggProgress(step: .awaitingDepositAddresses))
    let addresses = try await poll(
      options: params.addressPoll,
      read: { try await self.linked(params.autoReconnect, notify) { try await self.api.getDepositAddresses() }.data },
      isDone: { $0.isReady },
      timeout: { AggError.depositAddressesTimeout(last: $0) }
    )
    // `poll` returns only once `isDone` holds, so this unwraps a `.ready`; the `else` cannot run.
    guard case let .ready(ready) = addresses else {
      throw AggError.depositAddressesTimeout(last: addresses)
    }

    let requested = params.token.lowercased()
    guard let token = ready.supportedChains
      .first(where: { $0.chainId == params.chainId })?
      .tokens
      .first(where: { $0.symbol.lowercased() == requested || $0.address.lowercased() == requested })
    else {
      throw AggError.unsupportedDepositToken(chainId: params.chainId, token: params.token)
    }
    let depositAddress = params.chainId.hasPrefix("solana:") ? ready.svmAddress : ready.evmAddress

    notify(AggProgress(step: .sendingDeposit))
    let txHash = try await sendAsset(
      params.chainId,
      SendAssetParams(to: depositAddress, amount: params.amount, token: token.address, idempotencyKey: params.idempotencyKey)
    )
    notify(AggProgress(step: .depositSent, txHash: txHash))
    return AggDepositResult(txHash: txHash, depositAddress: depositAddress, chainId: params.chainId, token: token)
  }

  /// Buys an outcome: quotes, fills at once (protected by `params.slippageBps`) and waits for the
  /// fill to finish. A fill that fails transiently is sent again with the same quote, which Agg
  /// fills only once.
  ///
  /// Succeeds when the fill ends `filled` or `partially_filled` (read `status.orders[]` for how much
  /// traded). Fails with `AggError.quoteNotTradable` when the quote cannot be filled and nothing was
  /// traded, `AggError.orderFailed` when the fill ends in any other final state (`failed`,
  /// `cancelled`, `expired`), and `AggError.orderOutcomeUnknown` when the fill may have gone through
  /// but its outcome could not be read: then read `getOrder` rather than buying again.
  public func buy(params: AggBuyParams) async throws -> AggTradeResult {
    try Self.requireAmount("amount", params.amount)
    return try await trade(
      request: AggQuoteRequest(
        outcomeId: params.outcomeId,
        side: .buy,
        amount: params.amount,
        slippageBps: params.slippageBps,
        venues: params.venues,
        mode: params.mode
      ),
      pollOptions: params.poll,
      notify: Self.progress(params.onProgress),
      autoReconnect: params.autoReconnect
    )
  }

  /// Sells shares of an outcome: quotes, fills at once (protected by `params.slippageBps`) and waits
  /// for the fill to finish. Succeeds and fails as `buy` does.
  public func sell(params: AggSellParams) async throws -> AggTradeResult {
    try Self.requireAmount("shares", params.shares)
    return try await trade(
      request: AggQuoteRequest(
        outcomeId: params.outcomeId,
        side: .sell,
        shares: params.shares,
        slippageBps: params.slippageBps,
        venues: params.venues,
        mode: params.mode
      ),
      pollOptions: params.poll,
      notify: Self.progress(params.onProgress),
      autoReconnect: params.autoReconnect
    )
  }

  /// Places a resting order from a decimal price and size, scaling both by 1e6 as the API takes
  /// them. A price outside 0 to 1, or a price or size with more than 6 decimals, is refused with
  /// `AggError.invalidAmount` before anything is sent. Cancel the order with `cancelOrder` and its
  /// `orderId`.
  public func placeLimitOrder(params: AggPlaceLimitOrderParams) async throws -> AggLimitOrder {
    let limitPriceRaw = try Self.toRaw("price", params.price, decimals: Self.microDecimals, exact: true)
    guard limitPriceRaw.count <= Self.microDecimals else {
      throw AggError.invalidAmount(name: "price", value: params.price)
    }
    let sizeRaw = try Self.toRaw("shares", params.shares, decimals: Self.microDecimals, exact: true)
    let request = AggLimitOrderRequest(
      venue: params.venue,
      venueMarketOutcomeId: params.venueMarketOutcomeId,
      side: params.side,
      limitPriceRaw: limitPriceRaw,
      sizeRaw: sizeRaw,
      timeInForce: params.timeInForce,
      postOnly: params.postOnly,
      expiresAt: params.expiresAt,
      clientOrderId: params.clientOrderId
    )
    let notify = Self.progress(params.onProgress)
    notify(AggProgress(step: .placingOrder))
    return try await linked(params.autoReconnect, notify) { try await self.api.createLimitOrder(request: request) }.data
  }

  /// Redeems every live position whose `redeemStatus` is `eligible`, in batches of 20, and returns
  /// each batch's result; an empty list when nothing is eligible. Holdings on a losing outcome are
  /// left out. The payouts land in the Agg balance at par.
  public func redeemAll(params: AggRedeemAllParams) async throws -> [AggRedeemResult] {
    let notify = Self.progress(params.onProgress)

    var positions: [AggPosition] = []
    var cursor: String?
    repeat {
      let pageCursor = cursor
      let page = try await linked(params.autoReconnect, notify) {
        try await self.api.listPositions(params: AggListPositionsParams(cursor: pageCursor))
      }.data
      positions += page.data
      cursor = page.hasMore ? page.nextCursor : nil
    } while cursor != nil

    var seen = Set<String>()
    let ids = positions
      .filter { $0.redeemStatus == .eligible }
      .flatMap { $0.venueMarket.venueMarketOutcomes.filter { $0.winner != false } }
      .flatMap { $0.venueBreakdown.compactMap(\.venueMarketOutcomeId) }
      .filter { seen.insert($0).inserted }

    var results: [AggRedeemResult] = []
    for start in stride(from: 0, to: ids.count, by: Self.maxRedeemBatch) {
      let batch = Array(ids[start ..< min(start + Self.maxRedeemBatch, ids.count)])
      notify(AggProgress(step: .redeeming))
      let result = try await linked(params.autoReconnect, notify) {
        try await self.api.redeemPositions(request: AggRedeemRequest(venueMarketOutcomeIds: batch))
      }.data
      results.append(result)
    }
    return results
  }

  /// Withdraws from the Agg balance and waits for the withdrawal to finish. It previews first and
  /// sends nothing unless the amount prices as `quoted` (`AggError.withdrawalNotViable`). The
  /// withdrawal carries `params.requestId`, and creating it is retried on transient failures with
  /// that same id, so it is never sent twice.
  ///
  /// Succeeds when the withdrawal ends `completed` or `partial` (read `completedAmountRaw`). Fails
  /// with `AggError.withdrawalFailed` when it ends `failed`, and `AggError.withdrawalOutcomeUnknown`
  /// when it may have been created but its outcome could not be read: do not call `withdraw` again
  /// then, because its preview can refuse an amount that already left.
  public func withdraw(params: AggWithdrawParams) async throws -> AggWithdrawal {
    try Self.requireAmount("amount", params.amount)
    let notify = Self.progress(params.onProgress)
    let autoReconnect = params.autoReconnect

    notify(AggProgress(step: .previewingWithdrawal))
    let withdrawable = try await linked(autoReconnect, notify) {
      try await self.api.quoteWithdrawable(
        request: AggWithdrawableQuoteRequest(tokenSymbol: params.tokenSymbol, destinationChainId: params.destinationChainId)
      )
    }.data
    let amountRaw = try Self.toRaw("amount", params.amount, decimals: withdrawable.decimals, exact: false)
    let preview = try await linked(autoReconnect, notify) {
      try await self.api.previewWithdrawal(request: AggWithdrawalRequest(
        tokenSymbol: params.tokenSymbol,
        destinationChainId: params.destinationChainId,
        amountRaw: amountRaw,
        destinationAddress: params.destinationAddress
      ))
    }.data
    guard preview.pricingStatus == .quoted else {
      throw AggError.withdrawalNotViable(preview: preview)
    }

    let request = AggWithdrawalRequest(
      tokenSymbol: params.tokenSymbol,
      destinationChainId: params.destinationChainId,
      amountRaw: amountRaw,
      destinationAddress: params.destinationAddress,
      requestId: params.requestId
    )
    notify(AggProgress(step: .withdrawing, withdrawalPreview: preview))
    let created: AggWithdrawal
    do {
      created = try await retryingTransient {
        try await self.linked(autoReconnect, notify) { try await self.api.createWithdrawal(request: request) }.data
      }
    } catch {
      if !YieldXyzCancellation.isCancellation(error), AggRequestFailure.isAmbiguous(error) {
        throw AggError.withdrawalOutcomeUnknown(request: request, withdrawal: nil, last: nil, underlyingError: error)
      }
      throw error
    }

    var withdrawal = created
    if !Self.finalWithdrawalStatuses.contains(created.status) {
      notify(AggProgress(step: .pollingWithdrawal, withdrawal: created))
      var last: AggWithdrawal?
      do {
        withdrawal = try await poll(
          options: params.poll,
          read: { try await self.linked(autoReconnect, notify) { try await self.api.getWithdrawal(withdrawalId: created.withdrawalId) }.data },
          isDone: { Self.finalWithdrawalStatuses.contains($0.status) },
          onRead: {
            last = $0
            notify(AggProgress(step: .pollingWithdrawal, withdrawal: $0))
          },
          timeout: { AggError.withdrawalTimeout(withdrawalId: created.withdrawalId, last: $0) }
        )
      } catch {
        if YieldXyzCancellation.isCancellation(error) {
          throw error
        }
        throw AggError.withdrawalOutcomeUnknown(request: request, withdrawal: created, last: last, underlyingError: error)
      }
    }
    if withdrawal.status == .failed {
      throw AggError.withdrawalFailed(withdrawal: withdrawal)
    }
    return withdrawal
  }

  /*******************************************
   * Private functions
   *******************************************/

  /// Quotes `request`, fills it if it is tradable and waits for the fill to finish.
  private func trade(
    request: AggQuoteRequest,
    pollOptions: AggPollOptions,
    notify: @escaping AggProgressHandler,
    autoReconnect: Bool
  ) async throws -> AggTradeResult {
    notify(AggProgress(step: .quoting))
    let quote = try await linked(autoReconnect, notify) { try await self.api.createQuote(request: request) }.data
    guard quote.status == .ok, (quote.warnings ?? []).isEmpty else {
      throw AggError.quoteNotTradable(quote: quote)
    }

    notify(AggProgress(step: .filling, quote: quote))
    let fill: AggFill
    do {
      // Agg fills a quote once: sending the same `quoteId` again returns that fill
      // (`alreadyAccepted`), so a transient failure is safe to repeat.
      fill = try await retryingTransient {
        try await self.linked(autoReconnect, notify) {
          try await self.api.createOrder(request: AggOrderRequest(quoteId: quote.quoteId, mode: request.mode))
        }.data
      }
    } catch {
      // A fill whose response was lost may have gone through: the quote id is how to find it.
      if !YieldXyzCancellation.isCancellation(error), AggRequestFailure.isAmbiguous(error) {
        throw AggError.orderOutcomeUnknown(quote: quote, fill: nil, last: nil, underlyingError: error)
      }
      throw error
    }
    notify(AggProgress(step: .pollingOrder, quote: quote, fill: fill))

    var last: AggExecutionStatus?
    let status: AggExecutionStatus
    do {
      status = try await poll(
        options: pollOptions,
        read: { try await self.linked(autoReconnect, notify) { try await self.api.getOrder(quoteId: quote.quoteId, mode: request.mode) }.data },
        isDone: { $0.terminal },
        wait: { Self.orderPollWait(pollAfterMs: $0.pollAfterMs) },
        onRead: {
          last = $0
          notify(AggProgress(step: .pollingOrder, quote: quote, fill: fill, order: $0))
        },
        timeout: { AggError.orderTimeout(quoteId: quote.quoteId, last: $0) }
      )
    } catch {
      if YieldXyzCancellation.isCancellation(error) {
        throw error
      }
      throw AggError.orderOutcomeUnknown(quote: quote, fill: fill, last: last, underlyingError: error)
    }
    guard Self.successfulExecutionStates.contains(status.overallState) else {
      throw AggError.orderFailed(status: status)
    }
    return AggTradeResult(quote: quote, fill: fill, status: status)
  }

  /// Runs an API call; with `autoReconnect`, answers `AGG_LINK_REQUIRED` by running `connect` on the
  /// chain the last `connect` used (Polygon before any) and retrying the call once. A call refused
  /// for the link did nothing, so retrying it cannot trade or send twice.
  private func linked<T>(
    _ autoReconnect: Bool,
    _ notify: AggProgressHandler,
    _ call: () async throws -> T
  ) async throws -> T {
    do {
      return try await call()
    } catch {
      guard autoReconnect, AggApiError.from(error)?.isLinkRequired == true else {
        throw error
      }
      notify(AggProgress(step: .reconnecting))
      _ = try await connect(chainId: reconnectChainId())
      return try await call()
    }
  }

  private func rememberLinkChain(_ chainId: String) {
    linkChainLock.lock()
    defer { linkChainLock.unlock() }
    lastLinkChainId = chainId
  }

  private func reconnectChainId() -> String {
    linkChainLock.lock()
    defer { linkChainLock.unlock() }
    return lastLinkChainId ?? Self.defaultLinkChainId
  }

  /// Reads with `read` until `isDone`, waiting `wait` (or the interval) between reads, for up to the
  /// options' timeout; then throws `timeout` with the last read. Up to `maxTransientFailures`
  /// transient failures in a row (rate limits, gateway errors, network errors) are read through; any
  /// other failure ends the wait.
  private func poll<T>(
    options: AggPollOptions,
    read: () async throws -> T,
    isDone: (T) -> Bool,
    wait: (T) -> TimeInterval? = { _ in nil },
    onRead: (T) -> Void = { _ in },
    timeout: (T?) -> AggError
  ) async throws -> T {
    // Monotonic: a wall-clock change must not cut a wait short or stretch it.
    let deadline = YieldXyzExecutionClock.now() + max(0, options.timeout)
    var last: T?
    var failures = 0
    while true {
      try Task.checkCancellation()
      var waitSeconds = options.interval
      do {
        let value = try await read()
        failures = 0
        last = value
        onRead(value)
        if isDone(value) {
          return value
        }
        waitSeconds = wait(value) ?? options.interval
      } catch {
        failures += 1
        if YieldXyzCancellation.isCancellation(error) || !AggRequestFailure.isTransient(error) || failures > Self.maxTransientFailures {
          throw error
        }
      }
      let remaining = deadline - YieldXyzExecutionClock.now()
      guard remaining > 0 else {
        throw timeout(last)
      }
      try await YieldXyzExecutionClock.sleep(seconds: min(waitSeconds, remaining))
    }
  }

  /// Runs `call`, repeating it up to `maxCallAttempts` times while it fails transiently. Only for
  /// calls safe to repeat.
  private func retryingTransient<T>(_ call: () async throws -> T) async throws -> T {
    var attempt = 1
    while true {
      do {
        return try await call()
      } catch {
        if YieldXyzCancellation.isCancellation(error) || !AggRequestFailure.isTransient(error) || attempt >= Self.maxCallAttempts {
          throw error
        }
        try await YieldXyzExecutionClock.sleep(seconds: transientRetryDelay * Double(attempt))
        attempt += 1
      }
    }
  }

  private static func progress(_ onProgress: AggProgressHandler?) -> AggProgressHandler {
    onProgress ?? { _ in }
  }

  /// Seconds to wait before reading a fill again: Agg's `pollAfterMs`, kept between 0.25 and 10
  /// seconds; `nil` when Agg sent none, to use the poll interval.
  static func orderPollWait(pollAfterMs: Int?) -> TimeInterval? {
    pollAfterMs.map { min(max(Double($0) / 1000, minOrderPollInterval), maxOrderPollInterval) }
  }

  /// The integer and fraction digits of a plain positive decimal string (`"1"`, `"1.5"`, `".5"`), or
  /// `nil` for anything else.
  private static func decimalParts(_ value: String) -> (integer: String, fraction: String)? {
    guard value.range(of: "^([0-9]+(\\.[0-9]*)?|\\.[0-9]+)$", options: .regularExpression) != nil else {
      return nil
    }
    let parts = value.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
    return (String(parts[0]), parts.count > 1 ? String(parts[1]) : "")
  }

  private static func requireAmount(_ name: String, _ value: String) throws {
    guard let parts = decimalParts(value), (parts.integer + parts.fraction).contains(where: { $0 != "0" }) else {
      throw AggError.invalidAmount(name: name, value: value)
    }
  }

  /// `value` in base units of a `decimals`-decimal token. Extra decimals are refused when `exact`,
  /// and rounded down otherwise; a value that comes to zero is refused.
  static func toRaw(_ name: String, _ value: String, decimals: Int, exact: Bool) throws -> String {
    guard let parts = decimalParts(value), decimals >= 0 else {
      throw AggError.invalidAmount(name: name, value: value)
    }
    let extra = parts.fraction.dropFirst(decimals)
    if exact, extra.contains(where: { $0 != "0" }) {
      throw AggError.invalidAmount(name: name, value: value)
    }
    let fraction = String((parts.fraction + String(repeating: "0", count: decimals)).prefix(decimals))
    let raw = String((parts.integer + fraction).drop(while: { $0 == "0" }))
    guard !raw.isEmpty else {
      throw AggError.invalidAmount(name: name, value: value)
    }
    return raw
  }
}

/// How the Agg helpers classify a failure. `PortalAggApi` throws every failure of a request it sent
/// as an `AggRequestError`. Anything else never reached the Portal API (a request refused before
/// sending, a missing credential, a reconnect whose signature was declined), so it is neither
/// transient nor ambiguous.
enum AggRequestFailure {
  /// Statuses that clear on retry: a rate limit and gateway errors.
  static let transientStatuses: Set<Int> = [429, 502, 503, 504]

  /// A failure that clears on retry: a rate limit, a gateway error or a network error.
  static func isTransient(_ error: Error) -> Bool {
    guard let requestError = error as? AggRequestError else {
      return false
    }
    if let status = AggApiError.from(requestError)?.status {
      return transientStatuses.contains(status)
    }
    return requestError.underlyingError is URLError
  }

  /// A failure after which Agg may or may not have acted on the request: a 5xx (other than a
  /// session refresh, which the Portal API returns before calling Agg), a network error, or a
  /// response that did not decode.
  static func isAmbiguous(_ error: Error) -> Bool {
    guard let requestError = error as? AggRequestError,
          AggApiError.from(requestError)?.isSessionRefreshInProgress != true
    else {
      return false
    }
    return YieldXyzRequestFailure.isAmbiguous(requestError.underlyingError)
  }
}
