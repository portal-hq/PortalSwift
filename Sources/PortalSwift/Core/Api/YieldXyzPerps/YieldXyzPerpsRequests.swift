//
//  YieldXyzPerpsRequests.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - Parameters (YieldXyzPerps)

/// Filters for `getMarkets`.
public struct YieldXyzPerpsGetMarketsParams: Equatable {
  public var offset: Int?
  /// 1–100.
  public var limit: Int?
  /// Venue identifier, e.g. `hyperliquid`.
  public var providerId: String?
  public var sortBy: YieldXyzPerpsMarketSortKey?
  public var order: YieldXyzPerpsSortOrder?

  public init(
    offset: Int? = nil,
    limit: Int? = nil,
    providerId: String? = nil,
    sortBy: YieldXyzPerpsMarketSortKey? = nil,
    order: YieldXyzPerpsSortOrder? = nil
  ) {
    self.offset = offset
    self.limit = limit
    self.providerId = providerId
    self.sortBy = sortBy
    self.order = order
  }
}

/// The window of `getMarketCandles`.
public struct YieldXyzPerpsGetMarketCandlesParams: Equatable {
  public var interval: YieldXyzPerpsCandleInterval
  /// Window start, unix milliseconds.
  public var from: Int64
  /// Window end, unix milliseconds.
  public var to: Int64?

  public init(interval: YieldXyzPerpsCandleInterval, from: Int64, to: Int64? = nil) {
    self.interval = interval
    self.from = from
    self.to = to
  }
}

/// The venues and account of `getPositions` / `getOrders`: at least one of `providerId` and
/// `providerIds` is required. `address` defaults to the Portal wallet's EVM address.
public struct YieldXyzPerpsPortfolioParams: Equatable {
  public var address: String?
  public var providerId: String?
  public var providerIds: [String]?

  public init(address: String? = nil, providerId: String? = nil, providerIds: [String]? = nil) {
    self.address = address
    self.providerId = providerId
    self.providerIds = providerIds
  }
}

/// The venue and account of `getBalances`, which takes exactly one venue. `address` defaults to
/// the Portal wallet's EVM address.
public struct YieldXyzPerpsBalancesParams: Equatable {
  public var providerId: String
  public var address: String?

  public init(providerId: String, address: String? = nil) {
    self.providerId = providerId
    self.address = address
  }
}

/// An action to build. `args` is sent as-is; `address` defaults to the Portal wallet's EVM address.
public struct YieldXyzPerpsCreateActionParams: Equatable {
  public var providerId: String
  public var action: YieldXyzPerpsActionType
  public var args: YieldXyzPerpsActionArgs
  public var address: String?

  public init(
    providerId: String,
    action: YieldXyzPerpsActionType,
    args: YieldXyzPerpsActionArgs,
    address: String? = nil
  ) {
    self.providerId = providerId
    self.action = action
    self.args = args
    self.address = address
  }
}

/// Filters for `getActions`. `address` defaults to the Portal wallet's EVM address.
public struct YieldXyzPerpsGetActionsParams: Equatable {
  public var offset: Int?
  /// 1–100.
  public var limit: Int?
  public var address: String?
  public var providerId: String?
  public var marketId: String?
  /// Action type filter.
  public var type: YieldXyzPerpsActionType?
  public var status: YieldXyzPerpsActionStatus?
  public var statuses: [YieldXyzPerpsActionStatus]?

  public init(
    offset: Int? = nil,
    limit: Int? = nil,
    address: String? = nil,
    providerId: String? = nil,
    marketId: String? = nil,
    type: YieldXyzPerpsActionType? = nil,
    status: YieldXyzPerpsActionStatus? = nil,
    statuses: [YieldXyzPerpsActionStatus]? = nil
  ) {
    self.offset = offset
    self.limit = limit
    self.address = address
    self.providerId = providerId
    self.marketId = marketId
    self.type = type
    self.status = status
    self.statuses = statuses
  }
}

/// A submission for one transaction: a signature (`signedPayload`, which requires `actionId`) or
/// the hash of a transaction you broadcast (`transactionHash`).
public struct YieldXyzPerpsSubmitTransactionParams: Equatable {
  public var transactionId: String
  /// Required with `signedPayload`: Portal uses it to verify the signer before forwarding.
  public var actionId: String?
  public var signedPayload: String?
  public var transactionHash: String?

  public init(
    transactionId: String,
    actionId: String? = nil,
    signedPayload: String? = nil,
    transactionHash: String? = nil
  ) {
    self.transactionId = transactionId
    self.actionId = actionId
    self.signedPayload = signedPayload
    self.transactionHash = transactionHash
  }
}

/// Filters for `getActivity`. `address` defaults to the Portal wallet's EVM address.
public struct YieldXyzPerpsGetActivityParams: Equatable {
  public var offset: Int?
  /// 1–100.
  public var limit: Int?
  public var address: String?
  public var providerId: String?
  public var providerIds: [String]?
  /// Narrows the action items only, not the events.
  public var actionStatus: YieldXyzPerpsActionStatus?
  public var actionStatuses: [YieldXyzPerpsActionStatus]?

  public init(
    offset: Int? = nil,
    limit: Int? = nil,
    address: String? = nil,
    providerId: String? = nil,
    providerIds: [String]? = nil,
    actionStatus: YieldXyzPerpsActionStatus? = nil,
    actionStatuses: [YieldXyzPerpsActionStatus]? = nil
  ) {
    self.offset = offset
    self.limit = limit
    self.address = address
    self.providerId = providerId
    self.providerIds = providerIds
    self.actionStatus = actionStatus
    self.actionStatuses = actionStatuses
  }
}

/// Filters for `getEvents`. `address` defaults to the Portal wallet's EVM address.
public struct YieldXyzPerpsGetEventsParams: Equatable {
  public var offset: Int?
  /// 1–100.
  public var limit: Int?
  public var address: String?
  public var providerId: String?
  public var providerIds: [String]?
  public var eventType: YieldXyzPerpsEventType?
  public var eventTypes: [YieldXyzPerpsEventType]?
  public var marketId: String?
  public var perpActionId: String?
  public var providerOrderId: String?
  /// Lower bound on `occurredAt`, ISO-8601.
  public var fromDate: String?
  /// Upper bound on `occurredAt`, ISO-8601.
  public var toDate: String?

  public init(
    offset: Int? = nil,
    limit: Int? = nil,
    address: String? = nil,
    providerId: String? = nil,
    providerIds: [String]? = nil,
    eventType: YieldXyzPerpsEventType? = nil,
    eventTypes: [YieldXyzPerpsEventType]? = nil,
    marketId: String? = nil,
    perpActionId: String? = nil,
    providerOrderId: String? = nil,
    fromDate: String? = nil,
    toDate: String? = nil
  ) {
    self.offset = offset
    self.limit = limit
    self.address = address
    self.providerId = providerId
    self.providerIds = providerIds
    self.eventType = eventType
    self.eventTypes = eventTypes
    self.marketId = marketId
    self.perpActionId = perpActionId
    self.providerOrderId = providerOrderId
    self.fromDate = fromDate
    self.toDate = toDate
  }
}

// MARK: - Requests (PortalYieldXyzPerpsApi), with `address` resolved

/// The body of `POST /positions`, `POST /orders` and `POST /balances`.
public struct YieldXyzPerpsPortfolioRequest: Codable, Equatable {
  public let address: String
  public let providerId: String?
  public let providerIds: [String]?

  public init(address: String, providerId: String? = nil, providerIds: [String]? = nil) {
    self.address = address
    self.providerId = providerId
    self.providerIds = providerIds
  }

  /// The request as sent: the Portal API rejects an empty string, so a blank `providerId` and blank
  /// `providerIds` entries are dropped, and an empty `providerIds` is not sent.
  var sanitized: YieldXyzPerpsPortfolioRequest {
    let ids = providerIds?.filter { !$0.isEmpty }
    return YieldXyzPerpsPortfolioRequest(
      address: address,
      providerId: providerId.flatMap { $0.isEmpty ? nil : $0 },
      providerIds: ids?.isEmpty == true ? nil : ids
    )
  }
}

/// The body of `POST /actions`.
public struct YieldXyzPerpsCreateActionRequest: Codable, Equatable {
  public let providerId: String
  public let address: String
  public let action: YieldXyzPerpsActionType
  public let args: YieldXyzPerpsActionArgs

  public init(providerId: String, address: String, action: YieldXyzPerpsActionType, args: YieldXyzPerpsActionArgs) {
    self.providerId = providerId
    self.address = address
    self.action = action
    self.args = args
  }
}

/// The query of `GET /actions`.
public struct YieldXyzPerpsGetActionsRequest: Equatable {
  public let address: String
  public let params: YieldXyzPerpsGetActionsParams

  public init(address: String, params: YieldXyzPerpsGetActionsParams = YieldXyzPerpsGetActionsParams()) {
    self.address = address
    self.params = params
  }
}

/// The query of `GET /activity`.
public struct YieldXyzPerpsGetActivityRequest: Equatable {
  public let address: String
  public let params: YieldXyzPerpsGetActivityParams

  public init(address: String, params: YieldXyzPerpsGetActivityParams = YieldXyzPerpsGetActivityParams()) {
    self.address = address
    self.params = params
  }
}

/// The query of `GET /events`.
public struct YieldXyzPerpsGetEventsRequest: Equatable {
  public let address: String
  public let params: YieldXyzPerpsGetEventsParams

  public init(address: String, params: YieldXyzPerpsGetEventsParams = YieldXyzPerpsGetEventsParams()) {
    self.address = address
    self.params = params
  }
}

/// The body of `POST /transactions/{transactionId}/submit`; the transaction id travels in the path.
/// Blank values are not sent: the Portal API rejects an empty string.
struct YieldXyzPerpsSubmitTransactionBody: Codable, Equatable {
  let signedPayload: String?
  let transactionHash: String?
  let actionId: String?

  init(signedPayload: String?, transactionHash: String?, actionId: String?) {
    self.signedPayload = signedPayload.flatMap { $0.isEmpty ? nil : $0 }
    self.transactionHash = transactionHash.flatMap { $0.isEmpty ? nil : $0 }
    self.actionId = actionId.flatMap { $0.isEmpty ? nil : $0 }
  }
}
