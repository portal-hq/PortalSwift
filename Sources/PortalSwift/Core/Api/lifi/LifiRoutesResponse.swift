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
struct LifiRoutesResponse: Codable {
    /// List of possible routes for the given transfer (required)
    let routes: [LifiRoute]
    /// Routes that are unavailable for the given transfer (optional)
    let unavailableRoutes: LifiUnavailableRoutes?
}

/// A route that can be used to realize a token transfer
// MARK: - LifiRoute
struct LifiRoute: Codable {
    /// Unique identifier of the route
    let id: String
    /// The id of the sending chain
    let fromChainId: Int
    /// The amount that should be transferred in USD
    let fromAmountUSD: String
    /// The amount that should be transferred including all decimals
    let fromAmount: String
    /// The sending Token
    let fromToken: LifiToken
    /// The id of the receiving chain
    let toChainId: Int
    /// The estimated resulting amount of the toToken in USD as float with two decimals
    let toAmountUSD: String
    /// The estimated resulting amount of the toToken including all decimals
    let toAmount: String
    /// The minimal resulting amount of the toToken including all decimals
    let toAmountMin: String
    /// The Token that should be transferred to
    let toToken: LifiToken
    /// The steps required to fulfill the transfer
    let steps: [LifiStep]
    /// Aggregation of the underlying gas costs in USD
    let gasCostUSD: String?
    /// The sending wallet address
    let fromAddress: String?
    /// The receiving wallet address
    let toAddress: String?
    /// Whether a chain switch is part of the route
    let containsSwitchChain: Bool?
}

/// Token information
// MARK: - LifiToken
struct LifiToken: Codable {
    /// Address of the token
    let address: String
    /// Symbol of the token
    let symbol: String
    /// Number of decimals the token uses
    let decimals: Int
    /// Id of the token's chain
    let chainId: Int
    /// Name of the token
    let name: String
    /// Identifier for the token
    let coinKey: String?
    /// Logo of the token
    let logoURI: String?
    /// Token price in USD
    let priceUSD: String?
}

/// Step in a route
// MARK: - LifiStep
struct LifiStep: Codable {
    /// Unique identifier of the step
    let id: String
    /// The type of the step (swap, cross, or lifi)
    let type: LifiStepType
    /// The tool used for this step. E.g. relay
    let tool: String
    /// The action of the step
    let action: LifiAction
    /// The details of the tool used for this step. E.g. relay
    let toolDetails: LifiToolDetails?
    /// The estimation for the step
    let estimate: LifiEstimate?
    /// Internal steps included in this step
    let includedSteps: [LifiInternalStep]?
    /// A string containing tracking information about the integrator of the API
    let integrator: String?
    /// A string containing tracking information about the referrer of the integrator
    let referrer: String?
    /// An object containing status information about the execution
    let execution: AnyCodable?
    /// An ether.js TransactionRequest that can be triggered using a wallet provider
    let transactionRequest: AnyCodable?
    /// Aggregation of the underlying gas costs in USD
    let gasCostUSD: String?
    /// The sending wallet address
    let fromAddress: String?
    /// The receiving wallet address
    let toAddress: String?
    /// Whether a chain switch is part of the route
    let containsSwitchChain: Bool?
}

/// Type of step in a route
// MARK: - LifiStepType
enum LifiStepType: String, Codable {
    /// Swap step
    case swap = "swap"
    /// Cross-chain step
    case cross = "cross"
    /// LI.FI step
    case lifi = "lifi"
}

/// Tool details
// MARK: - LifiToolDetails
struct LifiToolDetails: Codable {
    /// The tool key
    let key: String?
    /// The tool name
    let name: String?
    /// The tool logo URL
    let logoURI: String?
}

/// Action within a step
// MARK: - LifiAction
struct LifiAction: Codable {
    /// The id of the chain where the transfer should start
    let fromChainId: Int
    /// The amount that should be transferred including all decimals
    let fromAmount: String
    /// The sending token
    let fromToken: LifiToken
    /// The id of the chain where the transfer should end
    let toChainId: Int
    /// The token that should be transferred to
    let toToken: LifiToken
    /// The maximum allowed slippage
    let slippage: Double?
    /// The sending wallet address
    let fromAddress: String?
    /// The receiving wallet address
    let toAddress: String?
}

/// Estimate for a step
// MARK: - LifiEstimate
struct LifiEstimate: Codable {
    /// The tool that is being used for this step
    let tool: String
    /// The amount that should be transferred including all decimals
    let fromAmount: String
    /// The estimated resulting amount of the toToken including all decimals
    let toAmount: String
    /// The minimal outcome of the transfer including all decimals
    let toAmountMin: String
    /// The contract address for the approval
    let approvalAddress: String
    /// The time needed to complete the following step (in seconds)
    let executionDuration: Int
    /// The amount that should be transferred in USD equivalent
    let fromAmountUSD: String?
    /// The estimated resulting amount of the toToken in USD equivalent
    let toAmountUSD: String?
    /// Fees included in the transfer
    let feeCosts: [LifiFeeCost]?
    /// Gas costs included in the transfer
    let gasCosts: [LifiGasCost]?
    /// Arbitrary data that depends on the used tool
    let data: LifiEstimateData?
}

/// Fee cost information
// MARK: - LifiFeeCost
struct LifiFeeCost: Codable {
    /// Name of the fee
    let name: String
    /// Percentage of how much fees are taken
    let percentage: String
    /// The Token in which the fees are taken
    let token: LifiToken
    /// The amount of fees in USD
    let amountUSD: String
    /// Whether fee is included into transfer's fromAmount
    let included: Bool
    /// Description of the fee costs
    let description: String?
    /// The amount of fees
    let amount: String?
}

/// Gas cost information
// MARK: - LifiGasCost
struct LifiGasCost: Codable {
    /// Can be one of SUM, APPROVE or SEND
    let type: LifiGasCostType
    /// Amount of the gas cost
    let amount: String
    /// The used gas token
    let token: LifiToken
    /// Suggested current standard price for the chain
    let price: String?
    /// Estimation how much gas will be needed
    let estimate: String?
    /// Suggested gas limit
    let limit: String?
    /// Amount of the gas cost in USD
    let amountUSD: String?
}

/// Type of gas cost
// MARK: - LifiGasCostType
enum LifiGasCostType: String, Codable {
    /// Sum of gas costs
    case sum = "SUM"
    /// Gas cost for approval
    case approve = "APPROVE"
    /// Gas cost for sending
    case send = "SEND"
}

/// Estimate data (arbitrary data that depends on the tool)
// MARK: - LifiEstimateData
struct LifiEstimateData: Codable {
    /// Bid information for the transfer
    let bid: LifiBid?
    /// Bid signature
    let bidSignature: String?
    /// Gas fee in receiving token
    let gasFeeInReceivingToken: String?
    /// Total fee
    let totalFee: String?
    /// Meta transaction relayer fee
    let metaTxRelayerFee: String?
    /// Router fee
    let routerFee: String?
}

/// Bid information
// MARK: - LifiBid
struct LifiBid: Codable {
    /// User address
    let user: String?
    /// Router address
    let router: String?
    /// Initiator address
    let initiator: String?
    /// Sending chain ID
    let sendingChainId: Int?
    /// Sending asset ID (token address)
    let sendingAssetId: String?
    /// Amount to send
    let amount: String?
    /// Receiving chain ID
    let receivingChainId: Int?
    /// Receiving asset ID (token address)
    let receivingAssetId: String?
    /// Amount to receive
    let amountReceived: String?
    /// Receiving address
    let receivingAddress: String?
    /// Transaction ID
    let transactionId: String?
    /// Expiry timestamp
    let expiry: Int?
    /// Call data hash
    let callDataHash: String?
    /// Call to address
    let callTo: String?
    /// Encrypted call data
    let encryptedCallData: String?
    /// Sending chain transaction manager address
    let sendingChainTxManagerAddress: String?
    /// Receiving chain transaction manager address
    let receivingChainTxManagerAddress: String?
    /// Bid expiry timestamp
    let bidExpiry: Int?
}

/// Internal step (used in includedSteps)
// MARK: - LifiInternalStep
struct LifiInternalStep: Codable {
    /// Unique identifier of the step
    let id: String
    /// The type of the step (swap, cross, or lifi)
    let type: LifiStepType
    /// The tool used for this step. E.g. allbridge
    let tool: String
    /// The details of the tool used for this step. E.g. allbridge
    let toolDetails: LifiToolDetails
    /// Object describing what happens in a Step
    let action: LifiAction
    /// An estimate for the current transfer
    let estimate: LifiEstimate
}

/// Unavailable routes information
// MARK: - LifiUnavailableRoutes
struct LifiUnavailableRoutes: Codable {
    /// An object containing information about routes that were intentionally filtered out
    let filteredOut: [LifiFilteredRoute]?
    /// An object containing information about failed routes
    let failed: [LifiFailedRoute]?
}

/// Filtered out route
// MARK: - LifiFilteredRoute
struct LifiFilteredRoute: Codable {
    /// The complete representation of the attempted route (e.g., "100:USDC-hop-137:USDC-137:USDC~137:SUSHI")
    let overallPath: String?
    /// Our best attempt at describing the failure
    let reason: String?
}

/// Failed route
// MARK: - LifiFailedRoute
struct LifiFailedRoute: Codable {
    /// The complete representation of the attempted route (e.g., "100:USDC-hop-137:USDC-137:USDC~137:SUSHI")
    let overallPath: String?
    /// An object with all subpaths that generated one or more errors
    let subpaths: [String: LifiSubpathError]?
}

/// Subpath error information
// MARK: - LifiSubpathError
struct LifiSubpathError: Codable {
    /// The type of error that occurred
    let errorType: LifiErrorType?
    /// The error code
    let code: LifiErrorCode?
    /// Object describing what happens in a Step
    let action: LifiAction?
    /// The tool that emitted the error
    let tool: String?
    /// A human-readable message describing the error
    let message: String?
}

/// Error type
// MARK: - LifiErrorType
enum LifiErrorType: String, Codable {
    /// No quote available
    case noQuote = "NO_QUOTE"
}

/// Error code
// MARK: - LifiErrorCode
enum LifiErrorCode: String, Codable {
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
