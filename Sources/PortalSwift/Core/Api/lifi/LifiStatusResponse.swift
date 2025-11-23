//
//  LifiStatusResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 21/11/2025.
//

import Foundation

/// Contains the current status of a cross chain transfer
// MARK: - LifiStatusResponse
struct LifiStatusResponse: Codable {
    /// The transaction on the sending chain (required)
    let sending: LifiTransactionInfo
    /// The transaction on the receiving chain
    let receiving: LifiTransactionInfo?
    /// An array of fee costs for the transaction
    let feeCosts: [LifiFeeCost]?
    /// The current status of the transfer (required)
    let status: LifiTransferStatus
    /// A more specific substatus (available for PENDING and DONE statuses)
    let substatus: LifiTransferSubstatus?
    /// A message that describes the substatus
    let substatusMessage: String?
    /// The tool used for this transfer (required)
    let tool: String
    /// The ID of this transfer (NOT a transaction hash)
    let transactionId: String?
    /// The address of the sender
    let fromAddress: String?
    /// The address of the receiver
    let toAddress: String?
    /// The link to the LI.FI explorer
    let lifiExplorerLink: String?
    /// The link to the bridge explorer
    let bridgeExplorerLink: String?
    /// The transaction metadata which includes integrator's string, etc.
    let metadata: LifiMetadata?
}

/// Transaction information
// MARK: - LifiTransactionInfo
struct LifiTransactionInfo: Codable {
    /// The hash of the transaction (required)
    let txHash: String
    /// Link to a block explorer showing the transaction (required)
    let txLink: String
    /// The amount of the transaction (required)
    let amount: String
    /// Information about the token (required)
    let token: LifiToken
    /// The id of the chain (required)
    let chainId: Int
    /// The token in which gas was paid
    let gasToken: LifiToken?
    /// The amount of the gas that was paid
    let gasAmount: String?
    /// The amount of the gas that was paid in USD
    let gasAmountUSD: String?
    /// The price of the gas
    let gasPrice: String?
    /// The amount of the gas that was used
    let gasUsed: String?
    /// The transaction timestamp
    let timestamp: Int?
    /// The transaction value
    let value: String?
    /// An array of swap or protocol steps included in the LI.FI transaction
    let includedSteps: [LifiIncludedSwapStep]?
}

/// Included swap or protocol step in the status response
// MARK: - LifiIncludedSwapStep
struct LifiIncludedSwapStep: Codable {
    /// The tool used for this step
    let tool: String?
    /// The details of the tool used for this step (e.g. `1inch` or `feeProtocol`)
    let toolDetails: LifiToolDetails?
    /// The amount that was sent to the tool
    let fromAmount: String?
    /// The token that was sent to the tool
    let fromToken: String?
    /// The amount that was received from the tool
    let toAmount: String?
    /// The token that was received from the tool
    let toToken: String?
    /// The amount that was sent to the bridge
    let bridgedAmount: String?
}

/// Transaction metadata
// MARK: - LifiMetadata
struct LifiMetadata: Codable {
    /// Integrator ID
    let integrator: String?
}

/// The current status of the transfer
// MARK: - LifiTransferStatus
enum LifiTransferStatus: String, Codable {
    /// Transaction not found
    case notFound = "NOT_FOUND"
    /// Invalid transaction
    case invalid = "INVALID"
    /// Transfer is pending
    case pending = "PENDING"
    /// Transfer is complete
    case done = "DONE"
    /// Transfer failed
    case failed = "FAILED"
}

/// A more specific substatus for PENDING and DONE statuses
// MARK: - LifiTransferSubstatus
enum LifiTransferSubstatus: String, Codable {
    /// Waiting for source chain confirmations
    case waitSourceConfirmations = "WAIT_SOURCE_CONFIRMATIONS"
    /// Waiting for destination transaction
    case waitDestinationTransaction = "WAIT_DESTINATION_TRANSACTION"
    /// Bridge is not available
    case bridgeNotAvailable = "BRIDGE_NOT_AVAILABLE"
    /// Chain is not available
    case chainNotAvailable = "CHAIN_NOT_AVAILABLE"
    /// Refund is in progress
    case refundInProgress = "REFUND_IN_PROGRESS"
    /// Unknown error occurred
    case unknownError = "UNKNOWN_ERROR"
    /// Transfer completed successfully
    case completed = "COMPLETED"
    /// Transfer partially completed
    case partial = "PARTIAL"
    /// Transfer was refunded
    case refunded = "REFUNDED"
}
