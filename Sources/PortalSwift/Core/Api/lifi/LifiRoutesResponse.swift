//
//  LifiRoutesResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 21/11/2025.
//

import Foundation
import AnyCodable

/// - Note: `routes` is required, `unavailableRoutes` is optional
// MARK: - LifiRoutesResponse
public struct LifiRoutesResponse: Codable {
    /// List of possible routes for the given transfer (required)
    public let routes: [LifiRoute]
    /// Routes that are unavailable for the given transfer (optional)
    public let unavailableRoutes: LifiUnavailableRoutes?
}

/// A route that can be used to realize a token transfer
// MARK: - LifiRoute
public struct LifiRoute: Codable {
    /// Unique identifier of the route
    public let id: String
    /// The id of the sending chain
    public let fromChainId: String
    /// The amount that should be transferred in USD
    public let fromAmountUSD: String
    /// The amount that should be transferred including all decimals
    public let fromAmount: String
    /// The sending Token
    public let fromToken: LifiToken
    /// The id of the receiving chain
    public let toChainId: String
    /// The estimated resulting amount of the toToken in USD as float with two decimals
    public let toAmountUSD: String
    /// The estimated resulting amount of the toToken including all decimals
    public let toAmount: String
    /// The minimal resulting amount of the toToken including all decimals
    public let toAmountMin: String
    /// The Token that should be transferred to
    public let toToken: LifiToken
    /// The steps required to fulfill the transfer
    public let steps: [LifiStep]
    /// Aggregation of the underlying gas costs in USD
    public let gasCostUSD: String?
    /// The sending wallet address
    public let fromAddress: String?
    /// The receiving wallet address
    public let toAddress: String?
    /// Whether a chain switch is part of the route
    public let containsSwitchChain: Bool?
}

/// Token information
// MARK: - LifiToken
public struct LifiToken: Codable {
    /// Address of the token
    public let address: String
    /// Symbol of the token
    public let symbol: String
    /// Number of decimals the token uses
    public let decimals: Int
    /// Id of the token's chain
    public let chainId: String
    /// Name of the token
    public let name: String
    /// Identifier for the token
    public let coinKey: String?
    /// Logo of the token
    public let logoURI: String?
    /// Token price in USD
    public let priceUSD: String?
    
    public init(address: String, symbol: String, decimals: Int, chainId: String, name: String, coinKey: String?, logoURI: String?, priceUSD: String?) {
        self.address = address
        self.symbol = symbol
        self.decimals = decimals
        self.chainId = chainId
        self.name = name
        self.coinKey = coinKey
        self.logoURI = logoURI
        self.priceUSD = priceUSD
    }
}

/// Step in a route
// MARK: - LifiStep
public struct LifiStep: Codable {
    /// Unique identifier of the step
    public let id: String
    /// The type of the step (swap, cross, or lifi)
    public let type: LifiStepType
    /// The tool used for this step. E.g. relay
    public let tool: String
    /// The action of the step
    public let action: LifiAction
    /// The details of the tool used for this step. E.g. relay
    public let toolDetails: LifiToolDetails?
    /// The estimation for the step
    public let estimate: LifiEstimate?
    /// Internal steps included in this step
    public let includedSteps: [LifiInternalStep]?
    /// A string containing tracking information about the integrator of the API
    public let integrator: String?
    /// A string containing tracking information about the referrer of the integrator
    public let referrer: String?
    /// An object containing status information about the execution
    public let execution: AnyCodable?
    /// An ether.js TransactionRequest that can be triggered using a wallet provider
    public let transactionRequest: AnyCodable?
    /// Aggregation of the underlying gas costs in USD
    public let gasCostUSD: String?
    /// The sending wallet address
    public let fromAddress: String?
    /// The receiving wallet address
    public let toAddress: String?
    /// Whether a chain switch is part of the route
    public let containsSwitchChain: Bool?
    
    public init(id: String, type: LifiStepType, tool: String, action: LifiAction, toolDetails: LifiToolDetails?, estimate: LifiEstimate?, includedSteps: [LifiInternalStep]?, integrator: String?, referrer: String?, execution: AnyCodable?, transactionRequest: AnyCodable?, gasCostUSD: String?, fromAddress: String?, toAddress: String?, containsSwitchChain: Bool?) {
        self.id = id
        self.type = type
        self.tool = tool
        self.action = action
        self.toolDetails = toolDetails
        self.estimate = estimate
        self.includedSteps = includedSteps
        self.integrator = integrator
        self.referrer = referrer
        self.execution = execution
        self.transactionRequest = transactionRequest
        self.gasCostUSD = gasCostUSD
        self.fromAddress = fromAddress
        self.toAddress = toAddress
        self.containsSwitchChain = containsSwitchChain
    }
}

/// Type of step in a route
// MARK: - LifiStepType
public enum LifiStepType: String, Codable {
    /// Swap step
    case swap = "swap"
    /// Cross-chain step
    case cross = "cross"
    /// LI.FI step
    case lifi = "lifi"
}

/// Tool details
// MARK: - LifiToolDetails
public struct LifiToolDetails: Codable {
    /// The tool key
    public let key: String?
    /// The tool name
    public let name: String?
    /// The tool logo URL
    public let logoURI: String?
    
    public init(key: String?, name: String?, logoURI: String?) {
        self.key = key
        self.name = name
        self.logoURI = logoURI
    }
}

/// Action within a step
// MARK: - LifiAction
public struct LifiAction: Codable {
    /// The id of the chain where the transfer should start
    public let fromChainId: String
    /// The amount that should be transferred including all decimals
    public let fromAmount: String
    /// The sending token
    public let fromToken: LifiToken
    /// The id of the chain where the transfer should end
    public let toChainId: String
    /// The token that should be transferred to
    public let toToken: LifiToken
    /// The maximum allowed slippage
    public let slippage: Double?
    /// The sending wallet address
    public let fromAddress: String?
    /// The receiving wallet address
    public let toAddress: String?
    
    public init(fromChainId: String, fromAmount: String, fromToken: LifiToken, toChainId: String, toToken: LifiToken, slippage: Double?, fromAddress: String?, toAddress: String?) {
        self.fromChainId = fromChainId
        self.fromAmount = fromAmount
        self.fromToken = fromToken
        self.toChainId = toChainId
        self.toToken = toToken
        self.slippage = slippage
        self.fromAddress = fromAddress
        self.toAddress = toAddress
    }
}

/// Estimate for a step
// MARK: - LifiEstimate
public struct LifiEstimate: Codable {
    /// The tool that is being used for this step
    public let tool: String
    /// The amount that should be transferred including all decimals
    public let fromAmount: String
    /// The estimated resulting amount of the toToken including all decimals
    public let toAmount: String
    /// The minimal outcome of the transfer including all decimals
    public let toAmountMin: String
    /// The contract address for the approval
    public let approvalAddress: String
    /// The time needed to complete the following step (in seconds)
    public let executionDuration: Int
    /// The amount that should be transferred in USD equivalent
    public let fromAmountUSD: String?
    /// The estimated resulting amount of the toToken in USD equivalent
    public let toAmountUSD: String?
    /// Fees included in the transfer
    public let feeCosts: [LifiFeeCost]?
    /// Gas costs included in the transfer
    public let gasCosts: [LifiGasCost]?
    /// Arbitrary data that depends on the used tool
    public let data: LifiEstimateData?
    
    public init(tool: String, fromAmount: String, toAmount: String, toAmountMin: String, approvalAddress: String, executionDuration: Int, fromAmountUSD: String?, toAmountUSD: String?, feeCosts: [LifiFeeCost]?, gasCosts: [LifiGasCost]?, data: LifiEstimateData?) {
        self.tool = tool
        self.fromAmount = fromAmount
        self.toAmount = toAmount
        self.toAmountMin = toAmountMin
        self.approvalAddress = approvalAddress
        self.executionDuration = executionDuration
        self.fromAmountUSD = fromAmountUSD
        self.toAmountUSD = toAmountUSD
        self.feeCosts = feeCosts
        self.gasCosts = gasCosts
        self.data = data
    }
}

/// Fee cost information
// MARK: - LifiFeeCost
public struct LifiFeeCost: Codable {
    /// Name of the fee
    public let name: String
    /// Percentage of how much fees are taken
    public let percentage: String
    /// The Token in which the fees are taken
    public let token: LifiToken
    /// The amount of fees in USD
    public let amountUSD: String
    /// Whether fee is included into transfer's fromAmount
    public let included: Bool
    /// Description of the fee costs
    public let description: String?
    /// The amount of fees
    public let amount: String?
}

/// Gas cost information
// MARK: - LifiGasCost
public struct LifiGasCost: Codable {
    /// Can be one of SUM, APPROVE or SEND
    public let type: LifiGasCostType
    /// Amount of the gas cost
    public let amount: String
    /// The used gas token
    public let token: LifiToken
    /// Suggested current standard price for the chain
    public let price: String?
    /// Estimation how much gas will be needed
    public let estimate: String?
    /// Suggested gas limit
    public let limit: String?
    /// Amount of the gas cost in USD
    public let amountUSD: String?
}

/// Type of gas cost
// MARK: - LifiGasCostType
public enum LifiGasCostType: String, Codable {
    /// Sum of gas costs
    case sum = "SUM"
    /// Gas cost for approval
    case approve = "APPROVE"
    /// Gas cost for sending
    case send = "SEND"
}

/// Estimate data (arbitrary data that depends on the tool)
// MARK: - LifiEstimateData
public struct LifiEstimateData: Codable {
    /// Bid information for the transfer
    public let bid: LifiBid?
    /// Bid signature
    public let bidSignature: String?
    /// Gas fee in receiving token
    public let gasFeeInReceivingToken: String?
    /// Total fee
    public let totalFee: String?
    /// Meta transaction relayer fee
    public let metaTxRelayerFee: String?
    /// Router fee
    public let routerFee: String?
}

/// Bid information
// MARK: - LifiBid
public struct LifiBid: Codable {
    /// User address
    public let user: String?
    /// Router address
    public let router: String?
    /// Initiator address
    public let initiator: String?
    /// Sending chain ID
    public let sendingChainId: String?
    /// Sending asset ID (token address)
    public let sendingAssetId: String?
    /// Amount to send
    public let amount: String?
    /// Receiving chain ID
    public let receivingChainId: String?
    /// Receiving asset ID (token address)
    public let receivingAssetId: String?
    /// Amount to receive
    public let amountReceived: String?
    /// Receiving address
    public let receivingAddress: String?
    /// Transaction ID
    public let transactionId: String?
    /// Expiry timestamp
    public let expiry: Int?
    /// Call data hash
    public let callDataHash: String?
    /// Call to address
    public let callTo: String?
    /// Encrypted call data
    public let encryptedCallData: String?
    /// Sending chain transaction manager address
    public let sendingChainTxManagerAddress: String?
    /// Receiving chain transaction manager address
    public let receivingChainTxManagerAddress: String?
    /// Bid expiry timestamp
    public let bidExpiry: Int?
}

/// Internal step (used in includedSteps)
// MARK: - LifiInternalStep
public struct LifiInternalStep: Codable {
    /// Unique identifier of the step
    public let id: String
    /// The type of the step (swap, cross, or lifi)
    public let type: LifiStepType
    /// The tool used for this step. E.g. allbridge
    public let tool: String
    /// The details of the tool used for this step. E.g. allbridge
    public let toolDetails: LifiToolDetails
    /// Object describing what happens in a Step
    public let action: LifiAction
    /// An estimate for the current transfer
    public let estimate: LifiEstimate
}

/// Unavailable routes information
// MARK: - LifiUnavailableRoutes
public struct LifiUnavailableRoutes: Codable {
    /// An object containing information about routes that were intentionally filtered out
    public let filteredOut: [LifiFilteredRoute]?
    /// An object containing information about failed routes
    public let failed: [LifiFailedRoute]?
}

/// Filtered out route
// MARK: - LifiFilteredRoute
public struct LifiFilteredRoute: Codable {
    /// The complete representation of the attempted route (e.g., "100:USDC-hop-137:USDC-137:USDC~137:SUSHI")
    public let overallPath: String?
    /// Our best attempt at describing the failure
    public let reason: String?
}

/// Failed route
// MARK: - LifiFailedRoute
public struct LifiFailedRoute: Codable {
    /// The complete representation of the attempted route (e.g., "100:USDC-hop-137:USDC-137:USDC~137:SUSHI")
    public let overallPath: String?
    /// An object with all subpaths that generated one or more errors
    public let subpaths: [String: LifiSubpathError]?
}

/// Subpath error information
// MARK: - LifiSubpathError
public struct LifiSubpathError: Codable {
    /// The type of error that occurred
    public let errorType: LifiErrorType?
    /// The error code
    public let code: LifiErrorCode?
    /// Object describing what happens in a Step
    public let action: LifiAction?
    /// The tool that emitted the error
    public let tool: String?
    /// A human-readable message describing the error
    public let message: String?
}

/// Error type
// MARK: - LifiErrorType
public enum LifiErrorType: String, Codable {
    /// No quote available
    case noQuote = "NO_QUOTE"
}

/// Error code
// MARK: - LifiErrorCode
public enum LifiErrorCode: String, Codable {
    /// No possible route found
    case noPossibleRoute = "NO_POSSIBLE_ROUTE"
    /// Insufficient liquidity
    case insufficientLiquidity = "INSUFFICIENT_LIQUIDITY"
    /// Tool timeout
    case toolTimeout = "TOOL_TIMEOUT"
    /// Unknown error
    case unknownError = "UNKNOWN_ERROR"
    /// RPC error
    case rpcError = "RPC_ERROR"
    /// Amount too low
    case amountTooLow = "AMOUNT_TOO_LOW"
    /// Amount too high
    case amountTooHigh = "AMOUNT_TOO_HIGH"
    /// Fees higher than amount
    case feesHigherThanAmount = "FEES_HIGHER_THAN_AMOUNT"
    /// Different recipient not supported
    case differentRecipientNotSupported = "DIFFERENT_RECIPIENT_NOT_SUPPORTED"
    /// Tool specific error
    case toolSpecificError = "TOOL_SPECIFIC_ERROR"
    /// Cannot guarantee minimum amount
    case cannotGuaranteeMinAmount = "CANNOT_GUARANTEE_MIN_AMOUNT"
    /// Rate limit exceeded
    case rateLimitExceeded = "RATE_LIMIT_EXCEEDED"
}
