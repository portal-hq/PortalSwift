//
//  AggHelperTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// What `Agg` needs from Portal to link the wallet and fund it. `Portal` provides all of them; a
/// standalone `Agg` can supply its own.
public struct AggDependencies {
  /// The Portal wallet's address on a CAIP-2 chain.
  public var getAddress: ((_ chainId: String) async -> String?)?
  /// Signs `params` with `personal_sign` on a CAIP-2 chain and returns the signature.
  public var personalSign: ((_ chainId: String, _ params: [String]) async throws -> String)?
  /// Whether a signing request can be routed through a CAIP-2 chain (an RPC endpoint is configured
  /// for it).
  public var isChainConfigured: ((_ chainId: String) async -> Bool)?
  /// Sends a token from the Portal wallet on a CAIP-2 chain and returns the transaction hash.
  public var sendAsset: ((_ chainId: String, _ params: SendAssetParams) async throws -> String)?

  public init(
    getAddress: ((_ chainId: String) async -> String?)? = nil,
    personalSign: ((_ chainId: String, _ params: [String]) async throws -> String)? = nil,
    isChainConfigured: ((_ chainId: String) async -> Bool)? = nil,
    sendAsset: ((_ chainId: String, _ params: SendAssetParams) async throws -> String)? = nil
  ) {
    self.getAddress = getAddress
    self.personalSign = personalSign
    self.isChainConfigured = isChainConfigured
    self.sendAsset = sendAsset
  }
}

/// A step of an Agg helper, reported through its `onProgress`.
public enum AggHelperStep: String, Equatable {
  /// A call failed with `AGG_LINK_REQUIRED` and `autoReconnect` is on: running `connect` before
  /// retrying it.
  case reconnecting
  /// Reading the deposit addresses, which Agg creates for a new user after the first request.
  case awaitingDepositAddresses
  /// Sending the deposit from the Portal wallet; `AggProgress.idempotencyKey` is set.
  case sendingDeposit
  /// The deposit was broadcast; `AggProgress.txHash` and `AggProgress.idempotencyKey` are set.
  case depositSent
  /// Pricing the trade.
  case quoting
  /// Filling the quote; `AggProgress.quote` is set.
  case filling
  /// Reading the fill's progress; `AggProgress.order` is set from the first read on.
  case pollingOrder
  /// Placing a limit order.
  case placingOrder
  /// Redeeming a batch of positions.
  case redeeming
  /// Reading what can be withdrawn and pricing the withdrawal.
  case previewingWithdrawal
  /// Creating the withdrawal; `AggProgress.withdrawalPreview` is set.
  case withdrawing
  /// Reading the withdrawal's status; `AggProgress.withdrawal` is set.
  case pollingWithdrawal
}

/// One progress event of an Agg helper. Fields are set as the helper learns them.
public struct AggProgress {
  public let step: AggHelperStep
  public let quote: AggQuote?
  public let fill: AggFill?
  /// The latest read of a fill: `steps[].label` is ready to show.
  public let order: AggExecutionStatus?
  public let txHash: String?
  public let withdrawalPreview: AggWithdrawalPreview?
  public let withdrawal: AggWithdrawal?
  /// The key the deposit is sent with. Keep it from `sendingDeposit` on: retrying with it never
  /// sends the deposit twice.
  public let idempotencyKey: String?

  public init(
    step: AggHelperStep,
    quote: AggQuote? = nil,
    fill: AggFill? = nil,
    order: AggExecutionStatus? = nil,
    txHash: String? = nil,
    withdrawalPreview: AggWithdrawalPreview? = nil,
    withdrawal: AggWithdrawal? = nil,
    idempotencyKey: String? = nil
  ) {
    self.step = step
    self.quote = quote
    self.fill = fill
    self.order = order
    self.txHash = txHash
    self.withdrawalPreview = withdrawalPreview
    self.withdrawal = withdrawal
    self.idempotencyKey = idempotencyKey
  }
}

/// Called with each progress event of a helper, on any thread.
public typealias AggProgressHandler = (AggProgress) -> Void

/// How a helper waits for Agg.
public struct AggPollOptions: Equatable {
  /// Seconds between reads. A fill waits its `pollAfterMs` instead when Agg sends one, kept between
  /// 0.25 and 10 seconds.
  public let interval: TimeInterval
  /// How long to wait before failing with the helper's timeout.
  public let timeout: TimeInterval

  public init(interval: TimeInterval, timeout: TimeInterval) {
    self.interval = interval
    self.timeout = timeout
  }
}

/// Sends funds from the Portal wallet to the user's Agg deposit address.
public struct AggDepositParams {
  /// The CAIP-2 chain to send on; it must be one of the deposit addresses' `supportedChains`.
  public let chainId: String
  /// The token to send, as Agg lists it for `chainId`: its contract address (an EVM address in any
  /// case, any other address, such as a Solana mint, exactly) or its symbol (e.g. `USDC`, in any
  /// case). A token is its chain and address. A symbol is only a convenience and is not guaranteed
  /// to be unique: one that names several tokens on `chainId` fails with
  /// `AggError.ambiguousDepositToken` and nothing is sent, so pass the address instead. The order
  /// Agg lists tokens in never picks one.
  public let token: String
  /// The amount to send, as a decimal string, e.g. `"10"` or `"1.5"`.
  public let amount: String
  /// Makes the send safe to retry: passed to `sendAsset`, so Portal never broadcasts a deposit twice
  /// under it. Generated when these params are created unless you pass one, and reported on
  /// `sendingDeposit`, in the result and in `AggError.depositOutcomeUnknown`.
  ///
  /// After `AggError.depositOutcomeUnknown`, retry with this same key (or these params). Portal
  /// refuses the key when the first send went out or failed, which ends in
  /// `AggError.depositOutcomeUnknown` again with no transaction hash: read
  /// `getBalances(sync: true, mode: nil)` to see whether it landed before depositing with a new key.
  /// Any other error from `deposit` means nothing was sent, so deposit again with a new key: Portal
  /// can keep refusing this one for a while after refusing its send (for example for insufficient
  /// funds).
  public let idempotencyKey: String
  public let onProgress: AggProgressHandler?
  /// On `AGG_LINK_REQUIRED`, run `connect` and retry that call once.
  public let autoReconnect: Bool
  /// How long to wait for the deposit addresses to be created.
  public let addressPoll: AggPollOptions

  public init(
    chainId: String,
    token: String,
    amount: String,
    idempotencyKey: String = generateIdempotencyKey(),
    onProgress: AggProgressHandler? = nil,
    autoReconnect: Bool = false,
    addressPoll: AggPollOptions = AggPollOptions(interval: 2, timeout: 60)
  ) {
    self.chainId = chainId
    self.token = token
    self.amount = amount
    self.idempotencyKey = idempotencyKey
    self.onProgress = onProgress
    self.autoReconnect = autoReconnect
    self.addressPoll = addressPoll
  }
}

/// A deposit that was broadcast. Agg credits it once the transaction confirms: read
/// `getBalances(sync: true, mode: nil)` to see it.
public struct AggDepositResult: Equatable {
  public let txHash: String
  /// Where the funds were sent.
  public let depositAddress: String
  public let chainId: String
  /// The token as Agg lists it on `chainId`.
  public let token: AggSupportedChainToken
  /// The key the deposit was sent with.
  public let idempotencyKey: String

  public init(txHash: String, depositAddress: String, chainId: String, token: AggSupportedChainToken, idempotencyKey: String) {
    self.txHash = txHash
    self.depositAddress = depositAddress
    self.chainId = chainId
    self.token = token
    self.idempotencyKey = idempotencyKey
  }
}

/// Buys an outcome: quotes, fills at once and waits for the fill to finish.
public struct AggBuyParams {
  /// `venueMarketOutcomes[].id` of a market.
  public let outcomeId: String
  /// The USD to spend, as a decimal string. Venue minimums are usually counted in shares, so very
  /// small amounts quote as `min_order_size_violated`.
  public let amount: String
  /// Maximum slippage, in basis points.
  public let slippageBps: Int?
  /// Restrict routing to these venues.
  public let venues: [AggVenue]?
  /// `.paper` for a simulated trade, which works from any country.
  public let mode: AggMode?
  public let onProgress: AggProgressHandler?
  /// On `AGG_LINK_REQUIRED`, run `connect` and retry that call once.
  public let autoReconnect: Bool
  /// How often to read the fill when Agg sends no `pollAfterMs`, and how long to wait.
  public let poll: AggPollOptions

  public init(
    outcomeId: String,
    amount: String,
    slippageBps: Int? = nil,
    venues: [AggVenue]? = nil,
    mode: AggMode? = nil,
    onProgress: AggProgressHandler? = nil,
    autoReconnect: Bool = false,
    poll: AggPollOptions = AggPollOptions(interval: 1, timeout: 180)
  ) {
    self.outcomeId = outcomeId
    self.amount = amount
    self.slippageBps = slippageBps
    self.venues = venues
    self.mode = mode
    self.onProgress = onProgress
    self.autoReconnect = autoReconnect
    self.poll = poll
  }
}

/// Sells shares of an outcome: quotes, fills at once and waits for the fill to finish.
public struct AggSellParams {
  /// `venueMarketOutcomes[].id` of a market.
  public let outcomeId: String
  /// The shares to sell, as a decimal string.
  public let shares: String
  /// Maximum slippage, in basis points.
  public let slippageBps: Int?
  /// Restrict routing to these venues.
  public let venues: [AggVenue]?
  /// `.paper` to sell simulated shares.
  public let mode: AggMode?
  public let onProgress: AggProgressHandler?
  /// On `AGG_LINK_REQUIRED`, run `connect` and retry that call once.
  public let autoReconnect: Bool
  /// How often to read the fill when Agg sends no `pollAfterMs`, and how long to wait.
  public let poll: AggPollOptions

  public init(
    outcomeId: String,
    shares: String,
    slippageBps: Int? = nil,
    venues: [AggVenue]? = nil,
    mode: AggMode? = nil,
    onProgress: AggProgressHandler? = nil,
    autoReconnect: Bool = false,
    poll: AggPollOptions = AggPollOptions(interval: 1, timeout: 180)
  ) {
    self.outcomeId = outcomeId
    self.shares = shares
    self.slippageBps = slippageBps
    self.venues = venues
    self.mode = mode
    self.onProgress = onProgress
    self.autoReconnect = autoReconnect
    self.poll = poll
  }
}

/// A finished trade.
public struct AggTradeResult: Equatable {
  public let quote: AggQuote
  public let fill: AggFill
  /// The final read of the fill: `overallState` and `orders[]` say how much filled.
  public let status: AggExecutionStatus

  public init(quote: AggQuote, fill: AggFill, status: AggExecutionStatus) {
    self.quote = quote
    self.fill = fill
    self.status = status
  }
}

/// A resting order, with the price and size as decimals.
public struct AggPlaceLimitOrderParams {
  /// The venue to rest on, e.g. `.polymarket`.
  public let venue: AggVenue
  /// The outcome id on that venue.
  public let venueMarketOutcomeId: String
  public let side: AggSide
  /// USD per share as a decimal string between 0 and 1, e.g. `"0.2"`, with at most 6 decimals.
  public let price: String
  /// The number of shares as a decimal string, with at most 6 decimals. Polymarket rejects orders
  /// that trade immediately under $1 in total (price × shares), a couple of seconds after
  /// submission.
  public let shares: String
  public let timeInForce: AggTimeInForce
  public let postOnly: Bool?
  /// Required with `.gtd`.
  public let expiresAt: String?
  public let clientOrderId: String?
  public let onProgress: AggProgressHandler?
  /// On `AGG_LINK_REQUIRED`, run `connect` and retry the order once.
  public let autoReconnect: Bool

  public init(
    venue: AggVenue,
    venueMarketOutcomeId: String,
    side: AggSide,
    price: String,
    shares: String,
    timeInForce: AggTimeInForce = .gtc,
    postOnly: Bool? = nil,
    expiresAt: String? = nil,
    clientOrderId: String? = nil,
    onProgress: AggProgressHandler? = nil,
    autoReconnect: Bool = false
  ) {
    self.venue = venue
    self.venueMarketOutcomeId = venueMarketOutcomeId
    self.side = side
    self.price = price
    self.shares = shares
    self.timeInForce = timeInForce
    self.postOnly = postOnly
    self.expiresAt = expiresAt
    self.clientOrderId = clientOrderId
    self.onProgress = onProgress
    self.autoReconnect = autoReconnect
  }
}

/// Redeems every eligible live position.
public struct AggRedeemAllParams {
  public let onProgress: AggProgressHandler?
  /// On `AGG_LINK_REQUIRED`, run `connect` and retry that call once.
  public let autoReconnect: Bool

  public init(onProgress: AggProgressHandler? = nil, autoReconnect: Bool = false) {
    self.onProgress = onProgress
    self.autoReconnect = autoReconnect
  }
}

/// Withdraws from the Agg balance and waits for the withdrawal to finish.
public struct AggWithdrawParams {
  /// The amount to withdraw, as a decimal string in `tokenSymbol`, e.g. `"1.5"`. Rounded down to the
  /// token's decimals.
  public let amount: String
  public let tokenSymbol: AggTokenSymbol
  /// CAIP-2, e.g. `eip155:8453`.
  public let destinationChainId: String
  /// Defaults to the user's own Portal address for that chain.
  public let destinationAddress: String?
  /// Identifies this withdrawal so a repeated `createWithdrawal` returns it instead of sending
  /// twice. Generated once when these params are created; create new params for a new withdrawal.
  /// Calling `withdraw` again with the same params is safe only when it failed before the
  /// withdrawal was created; after that it fails with `AggError.withdrawalOutcomeUnknown`, which
  /// says how to recover.
  public let requestId: String
  public let onProgress: AggProgressHandler?
  /// On `AGG_LINK_REQUIRED`, run `connect` and retry that call once.
  public let autoReconnect: Bool
  /// How often to read the withdrawal and how long to wait for it to finish.
  public let poll: AggPollOptions

  public init(
    amount: String,
    tokenSymbol: AggTokenSymbol,
    destinationChainId: String,
    destinationAddress: String? = nil,
    requestId: String = UUID().uuidString.lowercased(),
    onProgress: AggProgressHandler? = nil,
    autoReconnect: Bool = false,
    poll: AggPollOptions = AggPollOptions(interval: 5, timeout: 600)
  ) {
    self.amount = amount
    self.tokenSymbol = tokenSymbol
    self.destinationChainId = destinationChainId
    self.destinationAddress = destinationAddress
    self.requestId = requestId
    self.onProgress = onProgress
    self.autoReconnect = autoReconnect
    self.poll = poll
  }
}
