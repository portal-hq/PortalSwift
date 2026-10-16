//
//  YieldXyzPerpsCommonTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import AnyCodable
import Foundation

// MARK: - Envelope

/// The success envelope every Yield.xyz Perps endpoint returns: `{ "data": ... }`.
public struct YieldXyzPerpsResponse<T: Codable & Equatable>: Codable, Equatable {
  public let data: T

  public init(data: T) {
    self.data = data
  }
}

/// A page of results, as returned by the paginated list endpoints.
public struct YieldXyzPerpsPage<Item: Codable & Equatable>: Codable, Equatable {
  public let total: Int
  public let offset: Int
  public let limit: Int
  public let items: [Item]

  public init(total: Int, offset: Int, limit: Int, items: [Item]) {
    self.total = total
    self.offset = offset
    self.limit = limit
    self.items = items
  }
}

// MARK: - Open values

/// A perps action type. Known values are the ones Portal accepts on `createAction`.
public struct YieldXyzPerpsActionType: YieldXyzOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let open: Self = "open"
  public static let close: Self = "close"
  public static let updateLeverage: Self = "updateLeverage"
  public static let stopLoss: Self = "stopLoss"
  public static let takeProfit: Self = "takeProfit"
  public static let cancelOrder: Self = "cancelOrder"
  public static let editOrder: Self = "editOrder"
  public static let fund: Self = "fund"
  public static let withdraw: Self = "withdraw"
  public static let approveAgent: Self = "approveAgent"
  public static let approveBuilderFee: Self = "approveBuilderFee"
  public static let updateMargin: Self = "updateMargin"
  public static let setTpAndSl: Self = "setTpAndSl"
  public static let setUnifiedAccount: Self = "setUnifiedAccount"
}

/// The lifecycle status of an action.
public struct YieldXyzPerpsActionStatus: YieldXyzOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let canceled: Self = "CANCELED"
  public static let created: Self = "CREATED"
  public static let waitingForNext: Self = "WAITING_FOR_NEXT"
  public static let processing: Self = "PROCESSING"
  public static let failed: Self = "FAILED"
  public static let success: Self = "SUCCESS"
  public static let stale: Self = "STALE"
}

/// The lifecycle status of a transaction within an action.
public struct YieldXyzPerpsTransactionStatus: YieldXyzOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let created: Self = "CREATED"
  public static let queued: Self = "QUEUED"
  public static let broadcasted: Self = "BROADCASTED"
  public static let confirmed: Self = "CONFIRMED"
  public static let failed: Self = "FAILED"
  public static let notFound: Self = "NOT_FOUND"
}

/// The kind of a transaction within an action.
public struct YieldXyzPerpsTransactionType: YieldXyzOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let approval: Self = "APPROVAL"
  public static let openPosition: Self = "OPEN_POSITION"
  public static let closePosition: Self = "CLOSE_POSITION"
  public static let updateLeverage: Self = "UPDATE_LEVERAGE"
  public static let stopLoss: Self = "STOP_LOSS"
  public static let takeProfit: Self = "TAKE_PROFIT"
  public static let cancelOrder: Self = "CANCEL_ORDER"
  public static let editOrder: Self = "EDIT_ORDER"
  public static let fund: Self = "FUND"
  public static let withdraw: Self = "WITHDRAW"
  public static let approveBuilderFee: Self = "APPROVE_BUILDER_FEE"
  public static let enableDexAbstraction: Self = "ENABLE_DEX_ABSTRACTION"
  public static let approveAgent: Self = "APPROVE_AGENT"
  public static let updateMargin: Self = "UPDATE_MARGIN"
  public static let setTpAndSl: Self = "SET_TP_AND_SL"
  public static let setUserAbstraction: Self = "SET_USER_ABSTRACTION"
}

/// How a transaction must be signed.
public struct YieldXyzPerpsSigningFormat: YieldXyzOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let evmTransaction: Self = "EVM_TRANSACTION"
  public static let eip712TypedData: Self = "EIP712_TYPED_DATA"
  public static let solanaTransaction: Self = "SOLANA_TRANSACTION"
  public static let cosmosTransaction: Self = "COSMOS_TRANSACTION"
}

/// The kind of a lifecycle event.
public struct YieldXyzPerpsEventType: YieldXyzOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let orderFilled: Self = "order_filled"
  public static let liquidation: Self = "liquidation"
  public static let stopLossTriggered: Self = "stop_loss_triggered"
  public static let takeProfitTriggered: Self = "take_profit_triggered"
}

/// A position direction.
public struct YieldXyzPerpsSide: YieldXyzOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let long: Self = "long"
  public static let short: Self = "short"
}

/// How margin is held for a position.
public struct YieldXyzPerpsMarginMode: YieldXyzOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let cross: Self = "cross"
  public static let isolated: Self = "isolated"
}

/// The kind of an order.
public struct YieldXyzPerpsOrderType: YieldXyzOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let market: Self = "market"
  public static let limit: Self = "limit"
  public static let stopLoss: Self = "stop_loss"
  public static let takeProfit: Self = "take_profit"
}

/// How a venue routes a `fund` deposit.
public struct YieldXyzPerpsFundingMethod: YieldXyzOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let bridge2: Self = "bridge2"
  public static let lifi: Self = "lifi"
}

/// A market sort key.
public struct YieldXyzPerpsMarketSortKey: YieldXyzOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let volume24h: Self = "volume24h"
  public static let markPrice: Self = "markPrice"
  public static let priceChangePercent24h: Self = "priceChangePercent24h"
}

/// A candle interval.
public struct YieldXyzPerpsCandleInterval: YieldXyzOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let oneMinute: Self = "1m"
  public static let fiveMinutes: Self = "5m"
  public static let fifteenMinutes: Self = "15m"
  public static let oneHour: Self = "1h"
  public static let fourHours: Self = "4h"
  public static let oneDay: Self = "1d"
}

/// The overall Yield.xyz Perps API health.
public struct YieldXyzPerpsHealthStatus: YieldXyzOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let ok: Self = "OK"
  public static let fail: Self = "FAIL"
}

/// The health of a single venue.
public struct YieldXyzPerpsProviderHealthState: YieldXyzOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let healthy: Self = "healthy"
  public static let degraded: Self = "degraded"
  public static let down: Self = "down"
}

/// A sort direction. The Portal API accepts only these two values.
public enum YieldXyzPerpsSortOrder: String, Codable, Equatable {
  case asc
  case desc
}

// MARK: - Loose objects

/// A coding key for objects that keep keys they do not model.
struct YieldXyzPerpsDynamicCodingKey: CodingKey, Hashable {
  let stringValue: String
  let intValue: Int?

  init(_ stringValue: String) {
    self.stringValue = stringValue
    self.intValue = nil
  }

  init?(stringValue: String) {
    self.init(stringValue)
  }

  init?(intValue: Int) {
    self.stringValue = String(intValue)
    self.intValue = intValue
  }
}

/// Decodes every key of `container` not in `knownKeys` as opaque JSON.
private func decodeAdditionalFields(
  from container: KeyedDecodingContainer<YieldXyzPerpsDynamicCodingKey>,
  excluding knownKeys: Set<String>
) throws -> [String: AnyCodable] {
  var additional: [String: AnyCodable] = [:]
  for key in container.allKeys where !knownKeys.contains(key.stringValue) {
    additional[key.stringValue] = try container.decode(AnyCodable.self, forKey: key)
  }
  return additional
}

/// Encodes `additional` into `container`, skipping keys a typed field already wrote.
private func encodeAdditionalFields(
  _ additional: [String: AnyCodable],
  into container: inout KeyedEncodingContainer<YieldXyzPerpsDynamicCodingKey>,
  excluding knownKeys: Set<String>
) throws {
  for (key, value) in additional where !knownKeys.contains(key) {
    try container.encode(value, forKey: YieldXyzPerpsDynamicCodingKey(key))
  }
}

/// A token reference. `network` is a CAIP-2 chain id for real chains (e.g. `eip155:42161`) or an
/// opaque venue identifier (e.g. `hyperliquid`). On requests a real funding chain must be CAIP-2.
///
/// Keys this type does not model are kept in `additionalFields` and sent back unchanged.
public struct YieldXyzPerpsTokenIdentifier: Codable, Equatable {
  public var network: String
  public var address: String?
  /// Keys the Portal API passes through that this type does not model. A key named like a typed
  /// field is ignored here: set the typed field instead.
  public var additionalFields: [String: AnyCodable]

  public init(network: String, address: String? = nil, additionalFields: [String: AnyCodable] = [:]) {
    self.network = network
    self.address = address
    self.additionalFields = additionalFields
  }

  private static let knownKeys: Set<String> = ["network", "address"]

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: YieldXyzPerpsDynamicCodingKey.self)
    self.network = try container.decode(String.self, forKey: YieldXyzPerpsDynamicCodingKey("network"))
    self.address = try container.decodeIfPresent(String.self, forKey: YieldXyzPerpsDynamicCodingKey("address"))
    self.additionalFields = try decodeAdditionalFields(from: container, excluding: Self.knownKeys)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: YieldXyzPerpsDynamicCodingKey.self)
    try container.encode(network, forKey: YieldXyzPerpsDynamicCodingKey("network"))
    try container.encodeIfPresent(address, forKey: YieldXyzPerpsDynamicCodingKey("address"))
    try encodeAdditionalFields(additionalFields, into: &container, excluding: Self.knownKeys)
  }
}

/// Action arguments. Documented fields are typed; any other key is kept in `additionalFields` and
/// sent as-is, leaving Yield.xyz the source of truth for which `args` an action takes (see the
/// provider's `argumentSchemas`). A position's or order's `pendingActions[].args` can be passed to
/// `createAction` unchanged.
public struct YieldXyzPerpsActionArgs: Codable, Equatable {
  public var marketId: String?
  public var side: YieldXyzPerpsSide?
  /// Human-readable units. For `fund` it is in units of the source token, not USD.
  public var amount: String?
  public var size: String?
  public var leverage: Double?
  public var marginMode: YieldXyzPerpsMarginMode?
  public var limitPrice: Double?
  public var stopLossPrice: Double?
  public var takeProfitPrice: Double?
  public var orderId: String?
  public var orderIds: [String]?
  public var assetIndex: Int?
  /// Funding source. `network` must be a CAIP-2 chain id.
  public var fromToken: YieldXyzPerpsTokenIdentifier?
  public var agentAddress: String?
  public var agentName: String?
  /// Unix seconds.
  public var validUntil: Int64?
  public var stopLossOrderId: String?
  public var takeProfitOrderId: String?
  public var skipApproval: Bool?
  public var fundingMethod: YieldXyzPerpsFundingMethod?
  public var enabled: Bool?
  /// Keys this type does not model; sent unchanged. A key named like a typed field is ignored
  /// here: set the typed field instead.
  public var additionalFields: [String: AnyCodable]

  public init(
    marketId: String? = nil,
    side: YieldXyzPerpsSide? = nil,
    amount: String? = nil,
    size: String? = nil,
    leverage: Double? = nil,
    marginMode: YieldXyzPerpsMarginMode? = nil,
    limitPrice: Double? = nil,
    stopLossPrice: Double? = nil,
    takeProfitPrice: Double? = nil,
    orderId: String? = nil,
    orderIds: [String]? = nil,
    assetIndex: Int? = nil,
    fromToken: YieldXyzPerpsTokenIdentifier? = nil,
    agentAddress: String? = nil,
    agentName: String? = nil,
    validUntil: Int64? = nil,
    stopLossOrderId: String? = nil,
    takeProfitOrderId: String? = nil,
    skipApproval: Bool? = nil,
    fundingMethod: YieldXyzPerpsFundingMethod? = nil,
    enabled: Bool? = nil,
    additionalFields: [String: AnyCodable] = [:]
  ) {
    self.marketId = marketId
    self.side = side
    self.amount = amount
    self.size = size
    self.leverage = leverage
    self.marginMode = marginMode
    self.limitPrice = limitPrice
    self.stopLossPrice = stopLossPrice
    self.takeProfitPrice = takeProfitPrice
    self.orderId = orderId
    self.orderIds = orderIds
    self.assetIndex = assetIndex
    self.fromToken = fromToken
    self.agentAddress = agentAddress
    self.agentName = agentName
    self.validUntil = validUntil
    self.stopLossOrderId = stopLossOrderId
    self.takeProfitOrderId = takeProfitOrderId
    self.skipApproval = skipApproval
    self.fundingMethod = fundingMethod
    self.enabled = enabled
    self.additionalFields = additionalFields
  }

  private enum Key: String, CaseIterable {
    case marketId, side, amount, size, leverage, marginMode, limitPrice, stopLossPrice, takeProfitPrice
    case orderId, orderIds, assetIndex, fromToken, agentAddress, agentName, validUntil, stopLossOrderId
    case takeProfitOrderId, skipApproval, fundingMethod, enabled

    var codingKey: YieldXyzPerpsDynamicCodingKey {
      YieldXyzPerpsDynamicCodingKey(rawValue)
    }
  }

  private static let knownKeys = Set(Key.allCases.map(\.rawValue))

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: YieldXyzPerpsDynamicCodingKey.self)
    self.marketId = try container.decodeIfPresent(String.self, forKey: Key.marketId.codingKey)
    self.side = try container.decodeIfPresent(YieldXyzPerpsSide.self, forKey: Key.side.codingKey)
    self.amount = try container.decodeIfPresent(String.self, forKey: Key.amount.codingKey)
    self.size = try container.decodeIfPresent(String.self, forKey: Key.size.codingKey)
    self.leverage = try container.decodeIfPresent(Double.self, forKey: Key.leverage.codingKey)
    self.marginMode = try container.decodeIfPresent(YieldXyzPerpsMarginMode.self, forKey: Key.marginMode.codingKey)
    self.limitPrice = try container.decodeIfPresent(Double.self, forKey: Key.limitPrice.codingKey)
    self.stopLossPrice = try container.decodeIfPresent(Double.self, forKey: Key.stopLossPrice.codingKey)
    self.takeProfitPrice = try container.decodeIfPresent(Double.self, forKey: Key.takeProfitPrice.codingKey)
    self.orderId = try container.decodeIfPresent(String.self, forKey: Key.orderId.codingKey)
    self.orderIds = try container.decodeIfPresent([String].self, forKey: Key.orderIds.codingKey)
    self.assetIndex = try container.decodeIfPresent(Int.self, forKey: Key.assetIndex.codingKey)
    self.fromToken = try container.decodeIfPresent(YieldXyzPerpsTokenIdentifier.self, forKey: Key.fromToken.codingKey)
    self.agentAddress = try container.decodeIfPresent(String.self, forKey: Key.agentAddress.codingKey)
    self.agentName = try container.decodeIfPresent(String.self, forKey: Key.agentName.codingKey)
    self.validUntil = try container.decodeIfPresent(Int64.self, forKey: Key.validUntil.codingKey)
    self.stopLossOrderId = try container.decodeIfPresent(String.self, forKey: Key.stopLossOrderId.codingKey)
    self.takeProfitOrderId = try container.decodeIfPresent(String.self, forKey: Key.takeProfitOrderId.codingKey)
    self.skipApproval = try container.decodeIfPresent(Bool.self, forKey: Key.skipApproval.codingKey)
    self.fundingMethod = try container.decodeIfPresent(YieldXyzPerpsFundingMethod.self, forKey: Key.fundingMethod.codingKey)
    self.enabled = try container.decodeIfPresent(Bool.self, forKey: Key.enabled.codingKey)
    self.additionalFields = try decodeAdditionalFields(from: container, excluding: Self.knownKeys)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: YieldXyzPerpsDynamicCodingKey.self)
    try container.encodeIfPresent(marketId, forKey: Key.marketId.codingKey)
    try container.encodeIfPresent(side, forKey: Key.side.codingKey)
    try container.encodeIfPresent(amount, forKey: Key.amount.codingKey)
    try container.encodeIfPresent(size, forKey: Key.size.codingKey)
    try container.encodeIfPresent(leverage, forKey: Key.leverage.codingKey)
    try container.encodeIfPresent(marginMode, forKey: Key.marginMode.codingKey)
    try container.encodeIfPresent(limitPrice, forKey: Key.limitPrice.codingKey)
    try container.encodeIfPresent(stopLossPrice, forKey: Key.stopLossPrice.codingKey)
    try container.encodeIfPresent(takeProfitPrice, forKey: Key.takeProfitPrice.codingKey)
    try container.encodeIfPresent(orderId, forKey: Key.orderId.codingKey)
    try container.encodeIfPresent(orderIds, forKey: Key.orderIds.codingKey)
    try container.encodeIfPresent(assetIndex, forKey: Key.assetIndex.codingKey)
    try container.encodeIfPresent(fromToken, forKey: Key.fromToken.codingKey)
    try container.encodeIfPresent(agentAddress, forKey: Key.agentAddress.codingKey)
    try container.encodeIfPresent(agentName, forKey: Key.agentName.codingKey)
    try container.encodeIfPresent(validUntil, forKey: Key.validUntil.codingKey)
    try container.encodeIfPresent(stopLossOrderId, forKey: Key.stopLossOrderId.codingKey)
    try container.encodeIfPresent(takeProfitOrderId, forKey: Key.takeProfitOrderId.codingKey)
    try container.encodeIfPresent(skipApproval, forKey: Key.skipApproval.codingKey)
    try container.encodeIfPresent(fundingMethod, forKey: Key.fundingMethod.codingKey)
    try container.encodeIfPresent(enabled, forKey: Key.enabled.codingKey)
    try encodeAdditionalFields(additionalFields, into: &container, excluding: Self.knownKeys)
  }
}
