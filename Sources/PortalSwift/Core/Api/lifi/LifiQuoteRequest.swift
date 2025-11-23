//
//  LifiQuoteRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 21/11/2025.
//

import Foundation

/// Used to request a quote for a transfer of one token to another, cross chain or not
// MARK: - LifiQuoteRequest
struct LifiQuoteRequest: Codable {
    /// The sending chain. Can be the chain id or chain key (required)
    let fromChain: String
    /// The receiving chain. Can be the chain id or chain key (required)
    let toChain: String
    /// The token that should be transferred. Can be the address or the symbol (required)
    let fromToken: String
    /// The token that should be transferred to. Can be the address or the symbol (required)
    let toToken: String
    /// The sending wallet address (required)
    let fromAddress: String
    /// The amount that should be sent including all decimals (e.g. 1000000 for 1 USDC (6 decimals)) (required)
    let fromAmount: String
    /// The receiving wallet address. If none is provided, the fromAddress will be used
    let toAddress: String?
    /// Which kind of route should be preferred (FASTEST or CHEAPEST)
    let order: LifiQuoteOrder?
    /// The maximum allowed slippage for the transaction as a decimal value. 0.005 represents 0.5%. Range: 0 <= x <= 1
    let slippage: Double?
    /// A string containing tracking information about the integrator of the API
    let integrator: String?
    /// The percent of the integrator's fee that is taken from every transaction. 0.02 represents 2%. Range: 0 <= x < 1
    let fee: Double?
    /// A string containing tracking information about the referrer of the integrator
    let referrer: String?
    /// List of bridges that are allowed for this transaction
    let allowBridges: [String]?
    /// List of exchanges that are allowed for this transaction
    let allowExchanges: [String]?
    /// List of bridges that are not allowed for this transaction
    let denyBridges: [String]?
    /// List of exchanges that are not allowed for this transaction
    let denyExchanges: [String]?
    /// List of bridges that should be preferred for this transaction
    let preferBridges: [String]?
    /// List of exchanges that should be preferred for this transaction
    let preferExchanges: [String]?
    /// Whether swaps or other contract calls should be allowed as part of the destination transaction of a bridge transfer (default: true)
    let allowDestinationCall: Bool?
    /// The amount of the token to convert to gas on the destination side
    let fromAmountForGas: String?
    /// The price impact threshold above which routes are hidden. As an example, one should specify 0.15 (15%) to hide routes with more than 15% price impact. The default is 10%.
    let maxPriceImpact: Double?
    /// Timing setting to wait for a certain amount of swap rates. Format: "minWaitTime-${minWaitTimeMs}-${startingExpectedResults}-${reduceEveryMs}"
    let swapStepTimingStrategies: [String]?
    /// Timing setting to wait for a certain amount of routes to be generated before choosing the best one. Format: "minWaitTime-${minWaitTimeMs}-${startingExpectedResults}-${reduceEveryMs}"
    let routeTimingStrategies: [String]?
    /// Parameter to skip transaction simulation. The quote will be returned faster but the transaction gas limit won't be accurate.
    let skipSimulation: Bool?
}

/// The way the resulting quote should be ordered
// MARK: - LifiQuoteOrder
enum LifiQuoteOrder: String, Codable {
    /// This sorting criterion prioritizes routes with the shortest estimated execution time
    case fastest = "FASTEST"
    /// This criterion focuses on minimizing the cost of the transaction
    case cheapest = "CHEAPEST"
}
