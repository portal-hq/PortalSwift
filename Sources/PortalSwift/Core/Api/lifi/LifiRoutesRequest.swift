//
//  LifiRoutesRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 21/11/2025.
//

import Foundation

/// Describes a desired any-to-any transfer and contains all information necessary to calculate the most efficient routes
// MARK: - LifiRoutesRequest
struct LifiRoutesRequest: Codable {
    /// The sending chain id (required)
    let fromChainId: Int
    /// The amount that should be transferred including all decimals (e.g. 1000000 for 1 USDC (6 decimals)) (required)
    let fromAmount: String
    /// The address of the sending Token (required)
    let fromTokenAddress: String
    /// The id of the receiving chain (required)
    let toChainId: Int
    /// The address of the receiving Token (required)
    let toTokenAddress: String
    /// Optional configuration for the routes
    let options: LifiRoutesRequestOptions?
    /// The sending wallet address
    let fromAddress: String?
    /// The receiving wallet address
    let toAddress: String?
    /// The amount of the token to convert to gas on the destination side
    let fromAmountForGas: String?
}

/// Optional configuration for the routes
// MARK: - LifiRoutesRequestOptions
struct LifiRoutesRequestOptions: Codable {
    /// Facilitates transfer insurance via insurace.io, ensuring secure and insured transfer of assets (deprecated)
    let insurance: Bool?
    /// Custom string the developer who integrates LiFi can set
    let integrator: String?
    /// The maximum allowed slippage
    let slippage: Double?
    /// Object configuring the bridges that should or should not be taken into consideration for the possibilities
    let bridges: LifiToolsConfiguration?
    /// Object configuring the exchanges that should or should not be taken into consideration for the possibilities
    let exchanges: LifiToolsConfiguration?
    /// The way the resulting routes should be ordered
    let order: LifiRoutesOrder?
    /// Whether chain switches should be allowed in the routes (default: false)
    let allowSwitchChain: Bool?
    /// Defines if we should return routes with a cross-chain bridge protocol (Connext, etc.) destination calls or not (default: true)
    let allowDestinationCall: Bool?
    /// Integrators can set a wallet address as referrer to track them
    let referrer: String?
    /// The percent of the integrator's fee that is taken from every transaction. The maximum fee amount should be less than 100%. Required range: 0 <= x < 1
    let fee: Double?
    /// The price impact threshold above which routes are hidden. As an example, one should specify 0.15 (15%) to hide routes with more than 15% price impact. The default is 10%.
    let maxPriceImpact: Double?
    /// Timing settings for route and swap steps
    let timing: LifiTimingOptions?
}

/// Configuration for bridges or exchanges (allow, deny, prefer)
// MARK: - LifiToolsConfiguration
struct LifiToolsConfiguration: Codable {
    /// Allowed tools
    let allow: [String]?
    /// Forbidden tools
    let deny: [String]?
    /// Preferred tools
    let prefer: [String]?
}

/// The way the resulting routes should be ordered
// MARK: - LifiRoutesOrder
enum LifiRoutesOrder: String, Codable {
    /// Order by fastest route
    case fastest = "FASTEST"
    /// Order by cheapest route
    case cheapest = "CHEAPEST"
}

/// Timing options for routes and swap steps
// MARK: - LifiTimingOptions
struct LifiTimingOptions: Codable {
    /// Timing setting to wait for a certain amount of swap rates
    let swapStepTimingStrategies: [LifiTimingStrategy]?
    /// Timing setting to wait for a certain amount of routes to be generated before choosing the best one
    let routeTimingStrategies: [LifiTimingStrategy]?
}

/// Timing strategy configuration
// MARK: - LifiTimingStrategy
struct LifiTimingStrategy: Codable {
    /// The timing strategy type
    let strategy: LifiTimingStrategyType?
    /// Minimum wait time in milliseconds (range: 0 <= x <= 15000)
    let minWaitTimeMs: Int?
    /// Starting expected results (range: 0 <= x <= 100)
    let startingExpectedResults: Int?
    /// Reduce every milliseconds (range: 0 <= x <= 15000)
    let reduceEveryMs: Int?
}

/// Type of timing strategy
// MARK: - LifiTimingStrategyType
enum LifiTimingStrategyType: String, Codable {
    /// Minimum wait time strategy
    case minWaitTime = "minWaitTime"
}
