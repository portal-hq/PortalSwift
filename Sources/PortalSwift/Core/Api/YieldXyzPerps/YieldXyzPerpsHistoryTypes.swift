//
//  YieldXyzPerpsHistoryTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// The order an event concerns.
public struct YieldXyzPerpsEventOrder: Codable, Equatable {
  public let orderId: String
  public let marketId: String
  public let asset: String
  /// Known values: `buy`, `sell`.
  public let side: String
  public let type: YieldXyzPerpsOrderType
  public let originalSizeBase: String
  public let remainingSizeBase: String
  public let limitPrice: Double?
  /// Known values: `ioc`, `gtc`, `alo`.
  public let timeInForce: String?
  public let triggerPrice: Double?
  public let reduceOnly: Bool
  public let isPositionLevel: Bool
  /// The venue's client order id (on Hyperliquid, the order's `cloid`: `0x` and 32 hex characters);
  /// `nil` when there is none, which is the case for fill events.
  public let clientOrderId: String?
  public let childOrderIds: [String]
  /// ISO-8601.
  public let createdAt: String
  /// Absent on opening or non-closing fills.
  public let closedPnl: String?
  /// Present on fill events.
  public let fillPrice: Double?

  public init(
    orderId: String,
    marketId: String,
    asset: String,
    side: String,
    type: YieldXyzPerpsOrderType,
    originalSizeBase: String,
    remainingSizeBase: String,
    limitPrice: Double? = nil,
    timeInForce: String? = nil,
    triggerPrice: Double? = nil,
    reduceOnly: Bool,
    isPositionLevel: Bool,
    clientOrderId: String? = nil,
    childOrderIds: [String],
    createdAt: String,
    closedPnl: String? = nil,
    fillPrice: Double? = nil
  ) {
    self.orderId = orderId
    self.marketId = marketId
    self.asset = asset
    self.side = side
    self.type = type
    self.originalSizeBase = originalSizeBase
    self.remainingSizeBase = remainingSizeBase
    self.limitPrice = limitPrice
    self.timeInForce = timeInForce
    self.triggerPrice = triggerPrice
    self.reduceOnly = reduceOnly
    self.isPositionLevel = isPositionLevel
    self.clientOrderId = clientOrderId
    self.childOrderIds = childOrderIds
    self.createdAt = createdAt
    self.closedPnl = closedPnl
    self.fillPrice = fillPrice
  }

  private enum CodingKeys: String, CodingKey {
    case orderId, marketId, asset, side, type, originalSizeBase, remainingSizeBase, limitPrice, timeInForce
    case triggerPrice, reduceOnly, isPositionLevel, clientOrderId, childOrderIds, createdAt, closedPnl, fillPrice
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.orderId = try container.decode(String.self, forKey: .orderId)
    self.marketId = try container.decode(String.self, forKey: .marketId)
    self.asset = try container.decode(String.self, forKey: .asset)
    self.side = try container.decode(String.self, forKey: .side)
    self.type = try container.decode(YieldXyzPerpsOrderType.self, forKey: .type)
    self.originalSizeBase = try container.decode(String.self, forKey: .originalSizeBase)
    self.remainingSizeBase = try container.decode(String.self, forKey: .remainingSizeBase)
    self.limitPrice = try container.decodeIfPresent(Double.self, forKey: .limitPrice)
    self.timeInForce = try container.decodeIfPresent(String.self, forKey: .timeInForce)
    self.triggerPrice = try container.decodeIfPresent(Double.self, forKey: .triggerPrice)
    self.reduceOnly = try container.decode(Bool.self, forKey: .reduceOnly)
    self.isPositionLevel = try container.decode(Bool.self, forKey: .isPositionLevel)
    // Yield.xyz's spec types it as an object but sends a string or null: anything else reads as
    // `nil` instead of failing the whole event.
    self.clientOrderId = try? container.decodeIfPresent(String.self, forKey: .clientOrderId)
    self.childOrderIds = try container.decode([String].self, forKey: .childOrderIds)
    self.createdAt = try container.decode(String.self, forKey: .createdAt)
    self.closedPnl = try container.decodeIfPresent(String.self, forKey: .closedPnl)
    self.fillPrice = try container.decodeIfPresent(Double.self, forKey: .fillPrice)
  }
}

/// A lifecycle event: an order fill, a liquidation, or a stop-loss / take-profit trigger.
public struct YieldXyzPerpsEvent: Codable, Equatable {
  public let id: String
  public let eventType: YieldXyzPerpsEventType
  public let providerId: String
  /// ISO-8601.
  public let occurredAt: String
  public let marketId: String?
  /// The action that produced the event; `nil` for liquidations.
  public let perpActionId: String?
  public let providerOrderId: String?
  public let explorerUrl: String?
  public let order: YieldXyzPerpsEventOrder

  public init(
    id: String,
    eventType: YieldXyzPerpsEventType,
    providerId: String,
    occurredAt: String,
    marketId: String? = nil,
    perpActionId: String? = nil,
    providerOrderId: String? = nil,
    explorerUrl: String? = nil,
    order: YieldXyzPerpsEventOrder
  ) {
    self.id = id
    self.eventType = eventType
    self.providerId = providerId
    self.occurredAt = occurredAt
    self.marketId = marketId
    self.perpActionId = perpActionId
    self.providerOrderId = providerOrderId
    self.explorerUrl = explorerUrl
    self.order = order
  }
}

/// An item of the unified activity feed, discriminated on its `type`.
public enum YieldXyzPerpsActivityItem: Codable, Equatable {
  /// `type: "event"`.
  case event(YieldXyzPerpsEvent)
  /// `type: "action"`.
  case action(YieldXyzPerpsAction)
  /// A `type` this SDK does not know yet; its payload is not decoded.
  case unknown(type: String)

  /// The wire discriminator.
  public var type: String {
    switch self {
    case .event:
      return "event"
    case .action:
      return "action"
    case let .unknown(type):
      return type
    }
  }

  private enum CodingKeys: String, CodingKey {
    case type
    case event
    case action
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)
    switch type {
    case "event":
      self = try .event(container.decode(YieldXyzPerpsEvent.self, forKey: .event))
    case "action":
      self = try .action(container.decode(YieldXyzPerpsAction.self, forKey: .action))
    default:
      self = .unknown(type: type)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(type, forKey: .type)
    switch self {
    case let .event(event):
      try container.encode(event, forKey: .event)
    case let .action(action):
      try container.encode(action, forKey: .action)
    case .unknown:
      break
    }
  }
}
