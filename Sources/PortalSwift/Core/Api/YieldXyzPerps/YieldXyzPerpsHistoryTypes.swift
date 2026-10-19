//
//  YieldXyzPerpsHistoryTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import AnyCodable
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
  /// The client order id, when the venue sends it as a string (Hyperliquid's `cloid` is a hex
  /// string); `nil` when there is none.
  public var clientOrderId: String? {
    clientOrderIdValue?.string
  }

  /// The client order id when the venue sends an object instead of a string; `nil` otherwise.
  public var clientOrderIdObject: [String: AnyCodable]? {
    clientOrderIdValue?.object
  }

  private let clientOrderIdValue: YieldXyzPerpsClientOrderIdValue?
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
    clientOrderIdObject: [String: AnyCodable]? = nil,
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
    self.clientOrderIdValue = clientOrderId.map(YieldXyzPerpsClientOrderIdValue.string)
      ?? clientOrderIdObject.map(YieldXyzPerpsClientOrderIdValue.object)
    self.childOrderIds = childOrderIds
    self.createdAt = createdAt
    self.closedPnl = closedPnl
    self.fillPrice = fillPrice
  }

  private enum CodingKeys: String, CodingKey {
    case orderId, marketId, asset, side, type, originalSizeBase, remainingSizeBase, limitPrice, timeInForce
    case triggerPrice, reduceOnly, isPositionLevel, childOrderIds, createdAt, closedPnl, fillPrice
    case clientOrderIdValue = "clientOrderId"
  }
}

/// A client order id as the Portal API sends it: a string, or an object. Decoding never fails; any
/// other value reads as having no id.
enum YieldXyzPerpsClientOrderIdValue: Codable, Equatable {
  case string(String)
  case object([String: AnyCodable])
  case unrecognized

  var string: String? {
    if case let .string(value) = self {
      return value
    }
    return nil
  }

  var object: [String: AnyCodable]? {
    if case let .object(value) = self {
      return value
    }
    return nil
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([String: AnyCodable].self) {
      self = .object(value)
    } else {
      self = .unrecognized
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case let .string(value):
      try container.encode(value)
    case let .object(value):
      try container.encode(value)
    case .unrecognized:
      try container.encodeNil()
    }
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
