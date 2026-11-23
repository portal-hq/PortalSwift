//
//  YieldXyzPerpsMarketTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import AnyCodable
import Foundation

/// Venue display metadata. Every field may be missing or `null`.
public struct YieldXyzPerpsProviderMetadata: Codable, Equatable {
  public let description: String?
  public let externalLink: String?
  public let logoURI: String?

  public init(description: String? = nil, externalLink: String? = nil, logoURI: String? = nil) {
    self.description = description
    self.externalLink = externalLink
    self.logoURI = logoURI
  }
}

/// A trading venue. `id` is an opaque venue identifier such as `hyperliquid`, not a chain, and is
/// used unchanged as `providerId` everywhere else.
public struct YieldXyzPerpsProvider: Codable, Equatable {
  public let id: String
  public let name: String
  /// Venue identifier, passed through unchanged (a venue is not a chain).
  public let network: String
  public let metadata: YieldXyzPerpsProviderMetadata
  public let supportedActions: [YieldXyzPerpsActionType]
  /// A JSON Schema per action, keyed by action type, describing the exact `args` it accepts.
  public let argumentSchemas: [String: AnyCodable]

  public init(
    id: String,
    name: String,
    network: String,
    metadata: YieldXyzPerpsProviderMetadata,
    supportedActions: [YieldXyzPerpsActionType],
    argumentSchemas: [String: AnyCodable]
  ) {
    self.id = id
    self.name = name
    self.network = network
    self.metadata = metadata
    self.supportedActions = supportedActions
    self.argumentSchemas = argumentSchemas
  }
}

/// A token. `network` is a CAIP-2 chain id for real chains or an opaque venue identifier.
public struct YieldXyzPerpsToken: Codable, Equatable {
  public let symbol: String
  public let name: String?
  public let network: String
  public let decimals: Int?
  public let address: String?
  public let logoURI: String?

  public init(
    symbol: String,
    name: String? = nil,
    network: String,
    decimals: Int? = nil,
    address: String? = nil,
    logoURI: String? = nil
  ) {
    self.symbol = symbol
    self.name = name
    self.network = network
    self.decimals = decimals
    self.address = address
    self.logoURI = logoURI
  }
}

/// Market display metadata.
public struct YieldXyzPerpsMarketMetadata: Codable, Equatable {
  public let name: String
  public let logoURI: String?
  public let url: String?

  public init(name: String, logoURI: String? = nil, url: String? = nil) {
    self.name = name
    self.logoURI = logoURI
    self.url = url
  }
}

/// A tradable instrument on a venue. Treat `id` as opaque: use the ids `getMarkets` returns.
public struct YieldXyzPerpsMarket: Codable, Equatable {
  public let id: String
  public let providerId: String
  public let baseAsset: YieldXyzPerpsToken
  public let quoteAsset: YieldXyzPerpsToken
  /// `[min, max]` leverage.
  public let leverageRange: [Double]
  public let supportedMarginModes: [YieldXyzPerpsMarginMode]
  public let markPrice: Double
  public let oraclePrice: Double
  public let priceChange24h: Double
  public let priceChangePercent24h: Double
  public let volume24h: Double
  public let openInterest: Double
  /// Decimal string.
  public let makerFee: String?
  /// Decimal string.
  public let takerFee: String?
  /// Decimal string.
  public let fundingRate: String
  public let fundingRateIntervalHours: Double
  public let minSize: Double
  public let metadata: YieldXyzPerpsMarketMetadata

  public init(
    id: String,
    providerId: String,
    baseAsset: YieldXyzPerpsToken,
    quoteAsset: YieldXyzPerpsToken,
    leverageRange: [Double],
    supportedMarginModes: [YieldXyzPerpsMarginMode],
    markPrice: Double,
    oraclePrice: Double,
    priceChange24h: Double,
    priceChangePercent24h: Double,
    volume24h: Double,
    openInterest: Double,
    makerFee: String? = nil,
    takerFee: String? = nil,
    fundingRate: String,
    fundingRateIntervalHours: Double,
    minSize: Double,
    metadata: YieldXyzPerpsMarketMetadata
  ) {
    self.id = id
    self.providerId = providerId
    self.baseAsset = baseAsset
    self.quoteAsset = quoteAsset
    self.leverageRange = leverageRange
    self.supportedMarginModes = supportedMarginModes
    self.markPrice = markPrice
    self.oraclePrice = oraclePrice
    self.priceChange24h = priceChange24h
    self.priceChangePercent24h = priceChangePercent24h
    self.volume24h = volume24h
    self.openInterest = openInterest
    self.makerFee = makerFee
    self.takerFee = takerFee
    self.fundingRate = fundingRate
    self.fundingRateIntervalHours = fundingRateIntervalHours
    self.minSize = minSize
    self.metadata = metadata
  }
}

/// An OHLCV candle. Prices and volume are decimal strings.
public struct YieldXyzPerpsCandle: Codable, Equatable {
  /// Unix milliseconds.
  public let openTime: Int64
  /// Unix milliseconds.
  public let closeTime: Int64
  public let open: String
  public let high: String
  public let low: String
  public let close: String
  public let volume: String
  public let trades: Int

  public init(
    openTime: Int64,
    closeTime: Int64,
    open: String,
    high: String,
    low: String,
    close: String,
    volume: String,
    trades: Int
  ) {
    self.openTime = openTime
    self.closeTime = closeTime
    self.open = open
    self.high = high
    self.low = low
    self.close = close
    self.volume = volume
    self.trades = trades
  }
}

/// The candles of one market over a time window.
public struct YieldXyzPerpsCandles: Codable, Equatable {
  public let marketId: String
  public let interval: YieldXyzPerpsCandleInterval
  public let candles: [YieldXyzPerpsCandle]

  public init(marketId: String, interval: YieldXyzPerpsCandleInterval, candles: [YieldXyzPerpsCandle]) {
    self.marketId = marketId
    self.interval = interval
    self.candles = candles
  }
}
