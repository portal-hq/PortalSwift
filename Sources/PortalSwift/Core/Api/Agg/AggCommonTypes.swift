//
//  AggCommonTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - Envelope

/// The success envelope every Agg endpoint returns: `{ "data": ... }`.
public struct AggResponse<T: Codable & Equatable>: Codable, Equatable {
  public let data: T

  public init(data: T) {
    self.data = data
  }
}

/// A page of results. Pass `nextCursor` as `cursor` to read the next one.
public struct AggPage<Item: Codable & Equatable>: Codable, Equatable {
  public let data: [Item]
  /// `nil` on the last page.
  public let nextCursor: String?
  public let hasMore: Bool

  public init(data: [Item], nextCursor: String? = nil, hasMore: Bool) {
    self.data = data
    self.nextCursor = nextCursor
    self.hasMore = hasMore
  }
}

// MARK: - Closed values

// The Portal API accepts only these on requests and query parameters.

/// The side of a trade.
public enum AggSide: String, Codable, Equatable {
  case buy
  case sell
}

/// Live trading, or a simulated `paper` account.
public enum AggMode: String, Codable, Equatable {
  case live
  case paper
}

/// A limit order's time in force. `GTD` requires `expiresAt`.
public enum AggTimeInForce: String, Codable, Equatable {
  case gtc = "GTC"
  case gtd = "GTD"
  case fok = "FOK"
  case fak = "FAK"
  case ioc = "IOC"
  case alo = "ALO"
}

/// A sort direction.
public enum AggSortDirection: String, Codable, Equatable {
  case asc
  case desc
}

/// How `listEvents` sorts.
public enum AggEventSort: String, Codable, Equatable {
  case volume
  case volume24hr
  case createdAt
  case endDate
  case arbReturn
}

/// How `listMarkets` sorts.
public enum AggMarketSort: String, Codable, Equatable {
  case volume
  case volume24hr
  case createdAt
  case updatedAt
}

/// How much of each market `listMarkets` returns: `summary` leaves out description and rules.
public enum AggMarketProjection: String, Codable, Equatable {
  case summary
  case full
}

/// What a search returns.
public enum AggSearchType: String, Codable, Equatable {
  case events
  case markets
}

/// A chart bar's width: 1, 5 or 60 minutes, or a day.
public enum AggChartResolution: String, Codable, Equatable {
  case oneMinute = "1"
  case fiveMinutes = "5"
  case oneHour = "60"
  case oneDay = "1D"
}

/// Open or closed positions.
public enum AggPositionStatus: String, Codable, Equatable {
  case active
  case closed
}

/// Market or limit orders.
public enum AggOrderType: String, Codable, Equatable {
  case market
  case limit
}

/// An activity item's kind.
public enum AggActivityType: String, Codable, Equatable {
  case trade
  case withdrawal
  case bridge
  case deposit
  case userOp = "user_op"
  case redeem
}

// MARK: - Open values

/// A venue Agg routes to.
public struct AggVenue: AggOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let polymarket: Self = "polymarket"
  public static let kalshi: Self = "kalshi"
  public static let limitless: Self = "limitless"
  public static let myriad: Self = "myriad"
  public static let predict: Self = "predict"
  public static let pred: Self = "pred"
  public static let probable: Self = "probable"
  public static let hyperliquid: Self = "hyperliquid"
  public static let prophetx: Self = "prophetx"
  public static let novig: Self = "novig"
  public static let tiprun: Self = "tiprun"
  public static let betdex: Self = "betdex"
}

/// A market or event status. Only `open` markets can be quoted.
public struct AggMarketStatus: AggOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let open: Self = "open"
  public static let closed: Self = "closed"
  public static let resolved: Self = "resolved"
  public static let unopened: Self = "unopened"
  public static let paused: Self = "paused"
}

/// A quote's status. Only `ok` with no `warnings` is tradable; every other status carries a reason
/// in `error`. A resolved market quotes as `invalid_input`.
public struct AggQuoteStatus: AggOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let ok: Self = "ok"
  public static let infeasible: Self = "infeasible"
  public static let checkerRejected: Self = "checker_rejected"
  public static let solverError: Self = "solver_error"
  public static let invalidInput: Self = "invalid_input"
  public static let noOrderbooks: Self = "no_orderbooks"
  public static let insufficientInputAmount: Self = "insufficient_input_amount"
  public static let engineUnavailable: Self = "engine_unavailable"
  public static let minOrderSizeViolated: Self = "min_order_size_violated"
  public static let insufficientBalance: Self = "insufficient_balance"
  public static let insufficientPosition: Self = "insufficient_position"
  public static let insufficientDepth: Self = "insufficient_depth"
  public static let noBidsAboveMinPrice: Self = "no_bids_above_min_price"
}

/// A fill's `overallState`. `filled`, `partially_filled`, `failed`, `cancelled` and `expired` are
/// final.
public struct AggExecutionState: AggOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let created: Self = "created"
  public static let routing: Self = "routing"
  public static let quoting: Self = "quoting"
  public static let placing: Self = "placing"
  public static let confirming: Self = "confirming"
  public static let filled: Self = "filled"
  public static let partiallyFilled: Self = "partially_filled"
  public static let failed: Self = "failed"
  public static let cancelled: Self = "cancelled"
  public static let expired: Self = "expired"
}

/// An order's status. `filled`, `partial_fill`, `failed`, `expired` and `cancelled` are final.
public struct AggOrderStatus: AggOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let pending: Self = "pending"
  public static let signing: Self = "signing"
  public static let pendingBridge: Self = "pending_bridge"
  public static let submitting: Self = "submitting"
  public static let submitted: Self = "submitted"
  public static let open: Self = "open"
  public static let partiallyFilledOpen: Self = "partially_filled_open"
  public static let cancelPending: Self = "cancel_pending"
  public static let filled: Self = "filled"
  public static let partialFill: Self = "partial_fill"
  public static let failed: Self = "failed"
  public static let expired: Self = "expired"
  public static let cancelled: Self = "cancelled"
}

/// An execution step's status.
public struct AggExecutionStepStatus: AggOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let pending: Self = "pending"
  public static let inProgress: Self = "in_progress"
  public static let completed: Self = "completed"
  public static let failed: Self = "failed"
  public static let skipped: Self = "skipped"
}

/// The stage of the fill an execution step belongs to.
public struct AggExecutionStepKind: AggOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let submit: Self = "submit"
  public static let setup: Self = "setup"
  public static let bridge: Self = "bridge"
  public static let fill: Self = "fill"
  public static let `internal`: Self = "internal"
}

/// A withdrawal's status. `completed`, `partial` and `failed` are final.
public struct AggWithdrawalStatus: AggOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let pending: Self = "pending"
  public static let bridging: Self = "bridging"
  public static let transferring: Self = "transferring"
  public static let completed: Self = "completed"
  public static let partial: Self = "partial"
  public static let failed: Self = "failed"
}

/// How a withdrawal is priced. Only a `quoted` withdrawal can be sent.
public struct AggWithdrawalPricingStatus: AggOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let unquoted: Self = "unquoted"
  public static let quoting: Self = "quoting"
  public static let quoted: Self = "quoted"
  public static let unviable: Self = "unviable"
}

/// Whether a position can be redeemed. Redeem it once it is `eligible`.
public struct AggRedeemStatus: AggOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let ineligible: Self = "ineligible"
  public static let eligible: Self = "eligible"
}

/// Who holds a balance, allocation or position leg.
public struct AggCustodyKind: AggOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let eoa: Self = "EOA"
  public static let depositWallet: Self = "DEPOSIT_WALLET"
  public static let polymarketLegacy: Self = "POLYMARKET_LEGACY"
  public static let venueAccount: Self = "VENUE_ACCOUNT"
  public static let venueOmnibus: Self = "VENUE_OMNIBUS"
}

/// The state of a chart series, on `meta.state`. While it is `warming`, retry after
/// `meta.retryAfterMs`.
public struct AggChartState: AggOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let ready: Self = "ready"
  public static let warming: Self = "warming"
  public static let empty: Self = "empty"
  public static let failed: Self = "failed"
  public static let unsupported: Self = "unsupported"
}

/// A token symbol. Paper accounts hold `PAPER_USD`.
public struct AggTokenSymbol: AggOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let usdc: Self = "USDC"
  public static let usdcE: Self = "USDC.e"
  public static let usdt: Self = "USDT"
  public static let pusd: Self = "pUSD"
  public static let usd1: Self = "USD1"
  public static let paperUsd: Self = "PAPER_USD"
}
