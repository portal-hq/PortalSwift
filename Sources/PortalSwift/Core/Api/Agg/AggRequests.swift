//
//  AggRequests.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

public struct AggLinkChallengeRequest: Codable, Equatable {
  /// CAIP-2 EVM chain for the sign-in message's Chain ID line.
  public let chainId: String?

  public init(chainId: String? = nil) {
    self.chainId = chainId
  }
}

public struct AggLinkRequest: Codable, Equatable {
  /// The `personal_sign` signature of the challenge's `signParams`.
  public let signature: String

  public init(signature: String) {
    self.signature = signature
  }
}

/// Prices an outcome across every venue.
public struct AggQuoteRequest: Codable, Equatable {
  /// `venueMarketOutcomes[].id` of a market.
  public let outcomeId: String
  public let side: AggSide
  /// On a buy, the USD to spend, as a decimal string. Send exactly one of `amount` and `shares`.
  public let amount: String?
  /// On a sell, the shares to sell, as a decimal string.
  public let shares: String?
  /// Maximum slippage, in basis points.
  public let slippageBps: Int?
  /// Restrict routing to these venues, e.g. `["polymarket"]`.
  public let venues: [AggVenue]?
  /// `.paper` prices for a simulated fill; fill it with the same mode.
  public let mode: AggMode?

  public init(
    outcomeId: String,
    side: AggSide,
    amount: String? = nil,
    shares: String? = nil,
    slippageBps: Int? = nil,
    venues: [AggVenue]? = nil,
    mode: AggMode? = nil
  ) {
    self.outcomeId = outcomeId
    self.side = side
    self.amount = amount
    self.shares = shares
    self.slippageBps = slippageBps
    self.venues = venues
    self.mode = mode
  }
}

/// Fills a quote.
public struct AggOrderRequest: Codable, Equatable {
  public let quoteId: String
  /// Must match the quote's mode: Agg will not fill a paper quote live or a live quote as paper.
  public let mode: AggMode?

  public init(quoteId: String, mode: AggMode? = nil) {
    self.quoteId = quoteId
    self.mode = mode
  }
}

/// A market order on one named venue, without a quote.
public struct AggDirectOrderRequest: Codable, Equatable {
  public let venue: AggVenue
  /// The outcome id on that venue.
  public let venueMarketOutcomeId: String
  public let side: AggSide
  /// Your idempotency key, 1 to 36 characters: a retried request returns 409 rather than trading
  /// twice.
  public let externalId: String
  /// On a buy, the USD to spend. Send this or `sellShares`.
  public let maxSpend: Double?
  /// On a sell, the shares to sell.
  public let sellShares: Double?
  public let slipCapBps: Int?

  public init(
    venue: AggVenue,
    venueMarketOutcomeId: String,
    side: AggSide,
    externalId: String,
    maxSpend: Double? = nil,
    sellShares: Double? = nil,
    slipCapBps: Int? = nil
  ) {
    self.venue = venue
    self.venueMarketOutcomeId = venueMarketOutcomeId
    self.side = side
    self.externalId = externalId
    self.maxSpend = maxSpend
    self.sellShares = sellShares
    self.slipCapBps = slipCapBps
  }
}

/// A resting order, the only kind `cancelOrder` can act on.
public struct AggLimitOrderRequest: Codable, Equatable {
  /// The venue to rest on, e.g. `polymarket`.
  public let venue: AggVenue
  /// The outcome id on that venue.
  public let venueMarketOutcomeId: String
  public let side: AggSide
  /// Price scaled by 1e6, as a positive integer string: `200000` is 0.20.
  public let limitPriceRaw: String
  /// Shares scaled by 1e6, as a positive integer string: `5000000` is five shares.
  public let sizeRaw: String
  public let timeInForce: AggTimeInForce
  public let postOnly: Bool?
  /// Required with `GTD`.
  public let expiresAt: String?
  public let clientOrderId: String?

  public init(
    venue: AggVenue,
    venueMarketOutcomeId: String,
    side: AggSide,
    limitPriceRaw: String,
    sizeRaw: String,
    timeInForce: AggTimeInForce,
    postOnly: Bool? = nil,
    expiresAt: String? = nil,
    clientOrderId: String? = nil
  ) {
    self.venue = venue
    self.venueMarketOutcomeId = venueMarketOutcomeId
    self.side = side
    self.limitPriceRaw = limitPriceRaw
    self.sizeRaw = sizeRaw
    self.timeInForce = timeInForce
    self.postOnly = postOnly
    self.expiresAt = expiresAt
    self.clientOrderId = clientOrderId
  }
}

public struct AggCancelOrderRequest: Codable, Equatable {
  /// The order id, not the `quoteId`: `orderIds[]` on the fill, or `id` on an order row.
  public let orderId: String

  public init(orderId: String) {
    self.orderId = orderId
  }
}

public struct AggRedeemRequest: Codable, Equatable {
  /// 1 to 20 of the position's `venueMarketOutcomes[].venueBreakdown[].venueMarketOutcomeId`: the
  /// venue's own outcome ids, not the `outcomeId` that was quoted.
  public let venueMarketOutcomeIds: [String]

  public init(venueMarketOutcomeIds: [String]) {
    self.venueMarketOutcomeIds = venueMarketOutcomeIds
  }
}

public struct AggWithdrawalRequest: Codable, Equatable {
  public let tokenSymbol: AggTokenSymbol
  /// CAIP-2, e.g. `eip155:8453`; `solana:mainnet` also works for Solana.
  public let destinationChainId: String
  /// Base units of the destination token: 6 decimals for USDC, 18 on BNB Chain.
  public let amountRaw: String
  /// Cap `amountRaw` at what can actually be delivered. Cannot be combined with `requestId`.
  public let max: Bool?
  /// Defaults to the user's own Portal address for that chain. Any other address must be on the
  /// environment's destination allowlist for Agg, or the request returns 403.
  public let destinationAddress: String?
  /// A UUID that makes an exact-amount withdrawal replayable: the same parameters return the
  /// original withdrawal instead of dispatching twice, and changed parameters are rejected.
  public let requestId: String?

  public init(
    tokenSymbol: AggTokenSymbol,
    destinationChainId: String,
    amountRaw: String,
    max: Bool? = nil,
    destinationAddress: String? = nil,
    requestId: String? = nil
  ) {
    self.tokenSymbol = tokenSymbol
    self.destinationChainId = destinationChainId
    self.amountRaw = amountRaw
    self.max = max
    self.destinationAddress = destinationAddress
    self.requestId = requestId
  }
}

public struct AggWithdrawableQuoteRequest: Codable, Equatable {
  public let tokenSymbol: AggTokenSymbol
  /// CAIP-2.
  public let destinationChainId: String

  public init(tokenSymbol: AggTokenSymbol, destinationChainId: String) {
    self.tokenSymbol = tokenSymbol
    self.destinationChainId = destinationChainId
  }
}

/// Filters for `listEvents`.
public struct AggListEventsParams: Equatable {
  /// Event status, e.g. `open`.
  public let status: AggMarketStatus?
  public let search: String?
  /// Venue slugs, e.g. `polymarket`.
  public let venues: [AggVenue]?
  public let categoryIds: [String]?
  public let sortBy: AggEventSort?
  public let sortDir: AggSortDirection?
  /// 1–100.
  public let limit: Int?
  /// The previous page's `nextCursor`.
  public let cursor: String?

  public init(
    status: AggMarketStatus? = nil,
    search: String? = nil,
    venues: [AggVenue]? = nil,
    categoryIds: [String]? = nil,
    sortBy: AggEventSort? = nil,
    sortDir: AggSortDirection? = nil,
    limit: Int? = nil,
    cursor: String? = nil
  ) {
    self.status = status
    self.search = search
    self.venues = venues
    self.categoryIds = categoryIds
    self.sortBy = sortBy
    self.sortDir = sortDir
    self.limit = limit
    self.cursor = cursor
  }
}

/// Filters for `listMarkets`. Pass an event's id as `venueEventId` to page through its markets.
public struct AggListMarketsParams: Equatable {
  public let venueEventId: String?
  /// Market status, e.g. `open`.
  public let status: AggMarketStatus?
  public let venue: AggVenue?
  public let search: String?
  public let sortBy: AggMarketSort?
  public let sortDir: AggSortDirection?
  public let projection: AggMarketProjection?
  /// 1–100.
  public let limit: Int?
  /// The previous page's `nextCursor`.
  public let cursor: String?

  public init(
    venueEventId: String? = nil,
    status: AggMarketStatus? = nil,
    venue: AggVenue? = nil,
    search: String? = nil,
    sortBy: AggMarketSort? = nil,
    sortDir: AggSortDirection? = nil,
    projection: AggMarketProjection? = nil,
    limit: Int? = nil,
    cursor: String? = nil
  ) {
    self.venueEventId = venueEventId
    self.status = status
    self.venue = venue
    self.search = search
    self.sortBy = sortBy
    self.sortDir = sortDir
    self.projection = projection
    self.limit = limit
    self.cursor = cursor
  }
}

/// A search, ranked by relevance.
public struct AggSearchParams: Equatable {
  /// The search text.
  public let q: String
  /// Whether to return events or markets.
  public let type: AggSearchType
  public let status: AggMarketStatus?
  public let limit: Int?
  /// The previous page's `nextCursor`.
  public let cursor: String?

  public init(
    q: String,
    type: AggSearchType,
    status: AggMarketStatus? = nil,
    limit: Int? = nil,
    cursor: String? = nil
  ) {
    self.q = q
    self.type = type
    self.status = status
    self.limit = limit
    self.cursor = cursor
  }
}

/// Filters for `listCategories`.
public struct AggListCategoriesParams: Equatable {
  /// A category id, to list its children; top-level categories without one.
  public let parentId: String?
  public let limit: Int?
  /// The previous page's `nextCursor`.
  public let cursor: String?

  public init(parentId: String? = nil, limit: Int? = nil, cursor: String? = nil) {
    self.parentId = parentId
    self.limit = limit
    self.cursor = cursor
  }
}

/// The series of `getChartBars` and `getChartHistoryManifest`.
public struct AggChartParams: Equatable {
  public let venueMarketOutcomeId: String
  /// Window end, Unix milliseconds.
  public let to: Int
  /// Window start, Unix milliseconds.
  public let from: Int?
  public let resolution: AggChartResolution?
  /// At most 5000.
  public let countBack: Int?

  public init(
    venueMarketOutcomeId: String,
    to: Int,
    from: Int? = nil,
    resolution: AggChartResolution? = nil,
    countBack: Int? = nil
  ) {
    self.venueMarketOutcomeId = venueMarketOutcomeId
    self.to = to
    self.from = from
    self.resolution = resolution
    self.countBack = countBack
  }
}

/// Filters for `listPositions`.
public struct AggListPositionsParams: Equatable {
  public let status: AggPositionStatus?
  public let mode: AggMode?
  public let limit: Int?
  /// The previous page's `nextCursor`.
  public let cursor: String?

  public init(
    status: AggPositionStatus? = nil,
    mode: AggMode? = nil,
    limit: Int? = nil,
    cursor: String? = nil
  ) {
    self.status = status
    self.mode = mode
    self.limit = limit
    self.cursor = cursor
  }
}

/// Filters for `listOrders`.
public struct AggListOrdersParams: Equatable {
  /// Only the orders of this quote.
  public let quoteId: String?
  public let orderType: AggOrderType?
  public let mode: AggMode?
  public let limit: Int?
  /// The previous page's `nextCursor`.
  public let cursor: String?

  public init(
    quoteId: String? = nil,
    orderType: AggOrderType? = nil,
    mode: AggMode? = nil,
    limit: Int? = nil,
    cursor: String? = nil
  ) {
    self.quoteId = quoteId
    self.orderType = orderType
    self.mode = mode
    self.limit = limit
    self.cursor = cursor
  }
}

/// Filters for `listActivity`.
public struct AggListActivityParams: Equatable {
  public let type: AggActivityType?
  public let limit: Int?
  /// The previous page's `nextCursor`.
  public let cursor: String?

  public init(type: AggActivityType? = nil, limit: Int? = nil, cursor: String? = nil) {
    self.type = type
    self.limit = limit
    self.cursor = cursor
  }
}
