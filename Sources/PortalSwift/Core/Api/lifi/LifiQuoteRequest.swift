//
//  LifiQuoteRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 21/11/2025.
//

import Foundation

/// Used to request a quote for a transfer of one token to another, cross chain or not
// MARK: - LifiQuoteRequest
public struct LifiQuoteRequest: Codable {
    /// The sending chain. Can be the chain id or chain key (required)
    public let fromChain: String
    /// The receiving chain. Can be the chain id or chain key (required)
    public let toChain: String
    /// The token that should be transferred. Can be the address or the symbol (required)
    public let fromToken: String
    /// The token that should be transferred to. Can be the address or the symbol (required)
    public let toToken: String
    /// The sending wallet address (required)
    public let fromAddress: String
    /// The amount that should be sent including all decimals (e.g. 1000000 for 1 USDC (6 decimals)) (required)
    public let fromAmount: String
    /// The receiving wallet address. If none is provided, the fromAddress will be used
    public let toAddress: String?
    /// Which kind of route should be preferred (FASTEST or CHEAPEST)
    public let order: LifiQuoteOrder?
    /// The maximum allowed slippage for the transaction as a decimal value. 0.005 represents 0.5%. Range: 0 <= x <= 1
    public let slippage: Double?
    /// A string containing tracking information about the integrator of the API
    public let integrator: String?
    /// The percent of the integrator's fee that is taken from every transaction. 0.02 represents 2%. Range: 0 <= x < 1
    public let fee: Double?
    /// A string containing tracking information about the referrer of the integrator
    public let referrer: String?
    /// List of bridges that are allowed for this transaction
    public let allowBridges: [String]?
    /// List of exchanges that are allowed for this transaction
    public let allowExchanges: [String]?
    /// List of bridges that are not allowed for this transaction
    public let denyBridges: [String]?
    /// List of exchanges that are not allowed for this transaction
    public let denyExchanges: [String]?
    /// List of bridges that should be preferred for this transaction
    public let preferBridges: [String]?
    /// List of exchanges that should be preferred for this transaction
    public let preferExchanges: [String]?
    /// Whether swaps or other contract calls should be allowed as part of the destination transaction of a bridge transfer (default: true)
    public let allowDestinationCall: Bool?
    /// The amount of the token to convert to gas on the destination side
    public let fromAmountForGas: String?
    /// The price impact threshold above which routes are hidden. As an example, one should specify 0.15 (15%) to hide routes with more than 15% price impact. The default is 10%.
    public let maxPriceImpact: Double?
    /// Timing setting to wait for a certain amount of swap rates. Format: "minWaitTime-${minWaitTimeMs}-${startingExpectedResults}-${reduceEveryMs}"
    public let swapStepTimingStrategies: [String]?
    /// Timing setting to wait for a certain amount of routes to be generated before choosing the best one. Format: "minWaitTime-${minWaitTimeMs}-${startingExpectedResults}-${reduceEveryMs}"
    public let routeTimingStrategies: [String]?
    /// Parameter to skip transaction simulation. The quote will be returned faster but the transaction gas limit won't be accurate.
    public let skipSimulation: Bool?
    
    public init(fromChain: String, toChain: String, fromToken: String, toToken: String, fromAddress: String, fromAmount: String, toAddress: String? = nil, order: LifiQuoteOrder? = nil, slippage: Double? = nil, integrator: String? = nil, fee: Double? = nil, referrer: String? = nil, allowBridges: [String]? = nil, allowExchanges: [String]? = nil, denyBridges: [String]? = nil, denyExchanges: [String]? = nil, preferBridges: [String]? = nil, preferExchanges: [String]? = nil, allowDestinationCall: Bool? = nil, fromAmountForGas: String? = nil, maxPriceImpact: Double? = nil, swapStepTimingStrategies: [String]? = nil, routeTimingStrategies: [String]? = nil, skipSimulation: Bool? = nil) {
        self.fromChain = fromChain
        self.toChain = toChain
        self.fromToken = fromToken
        self.toToken = toToken
        self.fromAddress = fromAddress
        self.fromAmount = fromAmount
        self.toAddress = toAddress
        self.order = order
        self.slippage = slippage
        self.integrator = integrator
        self.fee = fee
        self.referrer = referrer
        self.allowBridges = allowBridges
        self.allowExchanges = allowExchanges
        self.denyBridges = denyBridges
        self.denyExchanges = denyExchanges
        self.preferBridges = preferBridges
        self.preferExchanges = preferExchanges
        self.allowDestinationCall = allowDestinationCall
        self.fromAmountForGas = fromAmountForGas
        self.maxPriceImpact = maxPriceImpact
        self.swapStepTimingStrategies = swapStepTimingStrategies
        self.routeTimingStrategies = routeTimingStrategies
        self.skipSimulation = skipSimulation
    }
}

/// The way the resulting quote should be ordered
// MARK: - LifiQuoteOrder
public enum LifiQuoteOrder: String, Codable {
    /// This sorting criterion prioritizes routes with the shortest estimated execution time
    case fastest = "FASTEST"
    /// This criterion focuses on minimizing the cost of the transaction
    case cheapest = "CHEAPEST"
}
