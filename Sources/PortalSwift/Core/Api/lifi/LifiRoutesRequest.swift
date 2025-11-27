//
//  LifiRoutesRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 21/11/2025.
//

import Foundation

/// Describes a desired any-to-any transfer and contains all information necessary to calculate the most efficient routes

// MARK: - LifiRoutesRequest

public struct LifiRoutesRequest: Codable {
  /// The sending chain id (required)
  public let fromChainId: String
  /// The amount that should be transferred including all decimals (e.g. 1000000 for 1 USDC (6 decimals)) (required)
  public let fromAmount: String
  /// The address of the sending Token (required)
  public let fromTokenAddress: String
  /// The id of the receiving chain (required)
  public let toChainId: String
  /// The address of the receiving Token (required)
  public let toTokenAddress: String
  /// Optional configuration for the routes
  public let options: LifiRoutesRequestOptions?
  /// The sending wallet address
  public let fromAddress: String?
  /// The receiving wallet address
  public let toAddress: String?
  /// The amount of the token to convert to gas on the destination side
  public let fromAmountForGas: String?

  public init(fromChainId: String, fromAmount: String, fromTokenAddress: String, toChainId: String, toTokenAddress: String, options: LifiRoutesRequestOptions? = nil, fromAddress: String? = nil, toAddress: String? = nil, fromAmountForGas: String? = nil) {
    self.fromChainId = fromChainId
    self.fromAmount = fromAmount
    self.fromTokenAddress = fromTokenAddress
    self.toChainId = toChainId
    self.toTokenAddress = toTokenAddress
    self.options = options
    self.fromAddress = fromAddress
    self.toAddress = toAddress
    self.fromAmountForGas = fromAmountForGas
  }
}

/// Optional configuration for the routes

// MARK: - LifiRoutesRequestOptions

public struct LifiRoutesRequestOptions: Codable {
  /// Facilitates transfer insurance via insurace.io, ensuring secure and insured transfer of assets (deprecated)
  public let insurance: Bool?
  /// Custom string the developer who integrates LiFi can set
  public let integrator: String?
  /// The maximum allowed slippage
  public let slippage: Double?
  /// Object configuring the bridges that should or should not be taken into consideration for the possibilities
  public let bridges: LifiToolsConfiguration?
  /// Object configuring the exchanges that should or should not be taken into consideration for the possibilities
  public let exchanges: LifiToolsConfiguration?
  /// The way the resulting routes should be ordered
  public let order: LifiRoutesOrder?
  /// Whether chain switches should be allowed in the routes (default: false)
  public let allowSwitchChain: Bool?
  /// Defines if we should return routes with a cross-chain bridge protocol (Connext, etc.) destination calls or not (default: true)
  public let allowDestinationCall: Bool?
  /// Integrators can set a wallet address as referrer to track them
  public let referrer: String?
  /// The percent of the integrator's fee that is taken from every transaction. The maximum fee amount should be less than 100%. Required range: 0 <= x < 1
  public let fee: Double?
  /// The price impact threshold above which routes are hidden. As an example, one should specify 0.15 (15%) to hide routes with more than 15% price impact. The default is 10%.
  public let maxPriceImpact: Double?
  /// Timing settings for route and swap steps
  public let timing: LifiTimingOptions?

  public init(insurance: Bool? = nil, integrator: String? = nil, slippage: Double? = nil, bridges: LifiToolsConfiguration? = nil, exchanges: LifiToolsConfiguration? = nil, order: LifiRoutesOrder? = nil, allowSwitchChain: Bool? = nil, allowDestinationCall: Bool? = nil, referrer: String? = nil, fee: Double? = nil, maxPriceImpact: Double? = nil, timing: LifiTimingOptions? = nil) {
    self.insurance = insurance
    self.integrator = integrator
    self.slippage = slippage
    self.bridges = bridges
    self.exchanges = exchanges
    self.order = order
    self.allowSwitchChain = allowSwitchChain
    self.allowDestinationCall = allowDestinationCall
    self.referrer = referrer
    self.fee = fee
    self.maxPriceImpact = maxPriceImpact
    self.timing = timing
  }
}

/// Configuration for bridges or exchanges (allow, deny, prefer)

// MARK: - LifiToolsConfiguration

public struct LifiToolsConfiguration: Codable {
  /// Allowed tools
  public let allow: [String]?
  /// Forbidden tools
  public let deny: [String]?
  /// Preferred tools
  public let prefer: [String]?

  public init(allow: [String]? = nil, deny: [String]? = nil, prefer: [String]? = nil) {
    self.allow = allow
    self.deny = deny
    self.prefer = prefer
  }
}

/// The way the resulting routes should be ordered

// MARK: - LifiRoutesOrder

public enum LifiRoutesOrder: String, Codable {
  /// Order by fastest route
  case fastest = "FASTEST"
  /// Order by cheapest route
  case cheapest = "CHEAPEST"
}

/// Timing options for routes and swap steps

// MARK: - LifiTimingOptions

public struct LifiTimingOptions: Codable {
  /// Timing setting to wait for a certain amount of swap rates
  public let swapStepTimingStrategies: [LifiTimingStrategy]?
  /// Timing setting to wait for a certain amount of routes to be generated before choosing the best one
  public let routeTimingStrategies: [LifiTimingStrategy]?

  public init(swapStepTimingStrategies: [LifiTimingStrategy]? = nil, routeTimingStrategies: [LifiTimingStrategy]? = nil) {
    self.swapStepTimingStrategies = swapStepTimingStrategies
    self.routeTimingStrategies = routeTimingStrategies
  }
}

/// Timing strategy configuration

// MARK: - LifiTimingStrategy

public struct LifiTimingStrategy: Codable {
  /// The timing strategy type
  public let strategy: LifiTimingStrategyType?
  /// Minimum wait time in milliseconds (range: 0 <= x <= 15000)
  public let minWaitTimeMs: Int?
  /// Starting expected results (range: 0 <= x <= 100)
  public let startingExpectedResults: Int?
  /// Reduce every milliseconds (range: 0 <= x <= 15000)
  public let reduceEveryMs: Int?

  public init(strategy: LifiTimingStrategyType? = nil, minWaitTimeMs: Int? = nil, startingExpectedResults: Int? = nil, reduceEveryMs: Int? = nil) {
    self.strategy = strategy
    self.minWaitTimeMs = minWaitTimeMs
    self.startingExpectedResults = startingExpectedResults
    self.reduceEveryMs = reduceEveryMs
  }
}

/// Type of timing strategy

// MARK: - LifiTimingStrategyType

public enum LifiTimingStrategyType: String, Codable {
  /// Minimum wait time strategy
  case minWaitTime
}
