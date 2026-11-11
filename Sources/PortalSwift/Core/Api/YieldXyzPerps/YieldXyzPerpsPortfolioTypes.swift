//
//  YieldXyzPerpsPortfolioTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// A next step available on a position or order. `args` can be passed to `createAction` as-is.
public struct YieldXyzPerpsPendingAction: Codable, Equatable {
  public let type: YieldXyzPerpsActionType
  public let label: String
  public let args: YieldXyzPerpsActionArgs

  public init(type: YieldXyzPerpsActionType, label: String, args: YieldXyzPerpsActionArgs) {
    self.type = type
    self.label = label
    self.args = args
  }
}

/// An open position on a venue.
public struct YieldXyzPerpsPosition: Codable, Equatable {
  public let marketId: String
  public let side: YieldXyzPerpsSide
  public let size: String
  public let entryPrice: Double
  public let markPrice: Double
  public let leverage: Double
  public let marginMode: YieldXyzPerpsMarginMode
  public let margin: Double
  public let unrealizedPnl: Double
  public let funding: Double
  public let liquidationPrice: Double
  public let pendingActions: [YieldXyzPerpsPendingAction]

  public init(
    marketId: String,
    side: YieldXyzPerpsSide,
    size: String,
    entryPrice: Double,
    markPrice: Double,
    leverage: Double,
    marginMode: YieldXyzPerpsMarginMode,
    margin: Double,
    unrealizedPnl: Double,
    funding: Double,
    liquidationPrice: Double,
    pendingActions: [YieldXyzPerpsPendingAction]
  ) {
    self.marketId = marketId
    self.side = side
    self.size = size
    self.entryPrice = entryPrice
    self.markPrice = markPrice
    self.leverage = leverage
    self.marginMode = marginMode
    self.margin = margin
    self.unrealizedPnl = unrealizedPnl
    self.funding = funding
    self.liquidationPrice = liquidationPrice
    self.pendingActions = pendingActions
  }
}

/// A resting limit or trigger order.
public struct YieldXyzPerpsOrder: Codable, Equatable {
  public let marketId: String
  public let side: YieldXyzPerpsSide
  public let type: YieldXyzPerpsOrderType
  public let size: String
  public let limitPrice: Double?
  public let triggerPrice: Double?
  public let leverage: Double?
  public let margin: Double?
  public let reduceOnly: Bool
  /// When the venue placed the order, in Unix milliseconds.
  public let createdAt: Int64
  public let pendingActions: [YieldXyzPerpsPendingAction]

  public init(
    marketId: String,
    side: YieldXyzPerpsSide,
    type: YieldXyzPerpsOrderType,
    size: String,
    limitPrice: Double? = nil,
    triggerPrice: Double? = nil,
    leverage: Double? = nil,
    margin: Double? = nil,
    reduceOnly: Bool,
    createdAt: Int64,
    pendingActions: [YieldXyzPerpsPendingAction]
  ) {
    self.marketId = marketId
    self.side = side
    self.type = type
    self.size = size
    self.limitPrice = limitPrice
    self.triggerPrice = triggerPrice
    self.leverage = leverage
    self.margin = margin
    self.reduceOnly = reduceOnly
    self.createdAt = createdAt
    self.pendingActions = pendingActions
  }
}

/// Account collateral and margin on a single venue.
public struct YieldXyzPerpsBalance: Codable, Equatable {
  public let providerId: String
  public let collateral: YieldXyzPerpsToken
  public let accountValue: Double
  public let usedMargin: Double
  public let availableBalance: Double
  public let unrealizedPnl: Double
  public let unifiedAccountMode: Bool?

  public init(
    providerId: String,
    collateral: YieldXyzPerpsToken,
    accountValue: Double,
    usedMargin: Double,
    availableBalance: Double,
    unrealizedPnl: Double,
    unifiedAccountMode: Bool? = nil
  ) {
    self.providerId = providerId
    self.collateral = collateral
    self.accountValue = accountValue
    self.usedMargin = usedMargin
    self.availableBalance = availableBalance
    self.unrealizedPnl = unrealizedPnl
    self.unifiedAccountMode = unifiedAccountMode
  }
}
