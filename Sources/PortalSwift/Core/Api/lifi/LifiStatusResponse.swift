//
//  LifiStatusResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 21/11/2025.
//

import Foundation

/// Response containing the status of a cross chain transfer from the Lifi integration

// MARK: - LifiStatusResponse

public struct LifiStatusResponse: Codable {
  public let data: LifiStatusData?
  public let error: String?

  public init(data: LifiStatusData? = nil, error: String? = nil) {
    self.data = data
    self.error = error
  }
}

public struct LifiStatusData: Codable {
  public let rawResponse: LifiStatusRawResponse

  public init(rawResponse: LifiStatusRawResponse) {
    self.rawResponse = rawResponse
  }
}

/// Contains the current status of a cross chain transfer

// MARK: - LifiStatusRawResponse

public struct LifiStatusRawResponse: Codable {
  /// The transaction on the sending chain (required)
  public let sending: LifiTransactionInfo
  /// The transaction on the receiving chain (can be partial with just chainId)
  public let receiving: LifiReceivingInfo?
  /// An array of fee costs for the transaction
  public let feeCosts: [LifiFeeCost]?
  /// The current status of the transfer (required)
  public let status: LifiTransferStatus
  /// A more specific substatus (available for PENDING and DONE statuses)
  public let substatus: LifiTransferSubstatus?
  /// A message that describes the substatus
  public let substatusMessage: String?
  /// The tool used for this transfer (required)
  public let tool: String
  /// The ID of this transfer (NOT a transaction hash)
  public let transactionId: String?
  /// The address of the sender
  public let fromAddress: String?
  /// The address of the receiver
  public let toAddress: String?
  /// The link to the LI.FI explorer
  public let lifiExplorerLink: String?
  /// The link to the bridge explorer
  public let bridgeExplorerLink: String?
  /// The transaction metadata which includes integrator's string, etc.
  public let metadata: LifiMetadata?
}

/// Receiving chain information (can be partial or full transaction info)

// MARK: - LifiReceivingInfo

public struct LifiReceivingInfo: Codable {
  /// The id of the chain
  public let chainId: String?
  /// Full transaction information (if available)
  public let txHash: String?
  public let txLink: String?
  public let token: LifiToken?
  public let amount: String?
  public let gasToken: LifiToken?
  public let gasAmount: String?
  public let gasAmountUSD: String?
  public let gasPrice: String?
  public let gasUsed: String?
  public let timestamp: Int?
  public let value: String?
  public let includedSteps: [LifiIncludedSwapStep]?
}

/// Transaction information

// MARK: - LifiTransactionInfo

public struct LifiTransactionInfo: Codable {
  /// The hash of the transaction (required)
  public let txHash: String
  /// Link to a block explorer showing the transaction (required)
  public let txLink: String
  /// The amount of the transaction (required)
  public let amount: String
  /// The amount of the transaction in USD
  public let amountUSD: String?
  /// Information about the token (required)
  public let token: LifiToken
  /// The id of the chain (required)
  public let chainId: String
  /// The token in which gas was paid
  public let gasToken: LifiToken?
  /// The amount of the gas that was paid
  public let gasAmount: String?
  /// The amount of the gas that was paid in USD
  public let gasAmountUSD: String?
  /// The price of the gas
  public let gasPrice: String?
  /// The amount of the gas that was used
  public let gasUsed: String?
  /// The transaction timestamp
  public let timestamp: Int?
  /// The transaction value
  public let value: String?
  /// An array of swap or protocol steps included in the LI.FI transaction
  public let includedSteps: [LifiIncludedSwapStep]?
}

/// Included swap or protocol step in the status response

// MARK: - LifiIncludedSwapStep

public struct LifiIncludedSwapStep: Codable {
  /// The tool used for this step
  public let tool: String?
  /// The details of the tool used for this step (e.g. `1inch` or `feeProtocol`)
  public let toolDetails: LifiToolDetails?
  /// The amount that was sent to the tool
  public let fromAmount: String?
  /// The token that was sent to the tool
  public let fromToken: LifiToken?
  /// The amount that was received from the tool
  public let toAmount: String?
  /// The token that was received from the tool
  public let toToken: LifiToken?
  /// The amount that was sent to the bridge
  public let bridgedAmount: String?
}

/// Transaction metadata

// MARK: - LifiMetadata

public struct LifiMetadata: Codable {
  /// Integrator ID
  public let integrator: String?
}

/// The current status of the transfer

// MARK: - LifiTransferStatus

public enum LifiTransferStatus: String, Codable {
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

public enum LifiTransferSubstatus: String, Codable {
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
