//
//  EnterYieldResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation
import AnyCodable

/// Response from entering a yield opportunity
public struct EnterYieldResponse: Codable {
    public let data: EnterYieldData
    
    public init(data: EnterYieldData) {
        self.data = data
    }
}

public struct EnterYieldData: Codable {
    public let rawResponse: EnterYieldRawResponse
    
    public init(rawResponse: EnterYieldRawResponse) {
        self.rawResponse = rawResponse
    }
}

public struct EnterYieldRawResponse: Codable {
    public let id: String
    public let intent: YieldActionIntent
    public let type: YieldActionType
    public let yieldId: String
    public let address: String
    public let amount: String?
    public let amountRaw: String?
    public let amountUsd: String?
    public let transactions: [YieldActionTransaction]
    public let executionPattern: YieldActionExecutionPattern
    public let rawArguments: EnterYieldArguments?
    public let createdAt: String
    public let completedAt: String?
    public let status: YieldActionStatus
    
    public init(
        id: String,
        intent: YieldActionIntent,
        type: YieldActionType,
        yieldId: String,
        address: String,
        amount: String? = nil,
        amountRaw: String? = nil,
        amountUsd: String? = nil,
        transactions: [YieldActionTransaction],
        executionPattern: YieldActionExecutionPattern,
        rawArguments: EnterYieldArguments? = nil,
        createdAt: String,
        completedAt: String? = nil,
        status: YieldActionStatus
    ) {
        self.id = id
        self.intent = intent
        self.type = type
        self.yieldId = yieldId
        self.address = address
        self.amount = amount
        self.amountRaw = amountRaw
        self.amountUsd = amountUsd
        self.transactions = transactions
        self.executionPattern = executionPattern
        self.rawArguments = rawArguments
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.status = status
    }
}

/// Yield action intent types
public enum YieldActionIntent: String, Codable {
    case enter
    case manage
    case exit
}

/// Yield action types
public enum YieldActionType: String, Codable {
    case STAKE
    case UNSTAKE
    case CLAIM_REWARDS
    case RESTAKE_REWARDS
    case WITHDRAW
    case WITHDRAW_ALL
    case RESTAKE
    case CLAIM_UNSTAKED
    case UNLOCK_LOCKED
    case STAKE_LOCKED
    case VOTE
    case REVOKE
    case VOTE_LOCKED
    case REVOTE
    case REBOND
    case MIGRATE
    case VERIFY_WITHDRAW_CREDENTIALS
    case DELEGATE
}

/// Yield action execution patterns
public enum YieldActionExecutionPattern: String, Codable {
    case synchronous
    case asynchronous
    case batch
}

/// Yield action status
public enum YieldActionStatus: String, Codable {
    case CANCELED
    case CREATED
    case WAITING_FOR_NEXT
    case PROCESSING
    case FAILED
    case SUCCESS
    case STALE
}

/// Yield action transaction
public struct YieldActionTransaction: Codable {
    public let id: String
    public let title: String
    public let network: String
    public let status: YieldActionTransactionStatus
    public let type: YieldActionTransactionType
    public let hash: String?
    public let createdAt: String
    public let broadcastedAt: String?
    public let signedTransaction: String?
    public let unsignedTransaction: AnyCodable?
    public let annotatedTransaction: [String: AnyCodable]?
    public let structuredTransaction: [String: AnyCodable]?
    public let stepIndex: Int
    public let description: String?
    public let error: String?
    public let gasEstimate: String?
    public let explorerUrl: String?
    public let isMessage: Bool?
    
    public init(
        id: String,
        title: String,
        network: String,
        status: YieldActionTransactionStatus,
        type: YieldActionTransactionType,
        hash: String? = nil,
        createdAt: String,
        broadcastedAt: String? = nil,
        signedTransaction: String? = nil,
        unsignedTransaction: AnyCodable? = nil,
        annotatedTransaction: [String: AnyCodable]? = nil,
        structuredTransaction: [String: AnyCodable]? = nil,
        stepIndex: Int,
        description: String? = nil,
        error: String? = nil,
        gasEstimate: String? = nil,
        explorerUrl: String? = nil,
        isMessage: Bool? = nil
    ) {
        self.id = id
        self.title = title
        self.network = network
        self.status = status
        self.type = type
        self.hash = hash
        self.createdAt = createdAt
        self.broadcastedAt = broadcastedAt
        self.signedTransaction = signedTransaction
        self.unsignedTransaction = unsignedTransaction
        self.annotatedTransaction = annotatedTransaction
        self.structuredTransaction = structuredTransaction
        self.stepIndex = stepIndex
        self.description = description
        self.error = error
        self.gasEstimate = gasEstimate
        self.explorerUrl = explorerUrl
        self.isMessage = isMessage
    }
}

/// Yield action transaction status
public enum YieldActionTransactionStatus: String, Codable {
    case NOT_FOUND
    case CREATED
    case BLOCKED
    case WAITING_FOR_SIGNATURE
    case SIGNED
    case BROADCASTED
    case PENDING
    case CONFIRMED
    case FAILED
    case SKIPPED
}

/// Yield action transaction type
public enum YieldActionTransactionType: String, Codable {
    case SWAP
    case DEPOSIT
    case APPROVAL
    case STAKE
    case CLAIM_UNSTAKED
    case CLAIM_REWARDS
    case RESTAKE_REWARDS
    case UNSTAKE
    case SPLIT
    case MERGE
    case LOCK
    case UNLOCK
    case SUPPLY
    case BRIDGE
    case VOTE
    case REVOKE
    case RESTAKE
    case REBOND
    case WITHDRAW
    case WITHDRAW_ALL
    case CREATE_ACCOUNT
    case REVEAL
    case MIGRATE
    case DELEGATE
    case UNDELEGATE
    case UTXO_P_TO_C_IMPORT
    case UTXO_C_TO_P_IMPORT
    case WRAP
    case UNWRAP
    case UNFREEZE_LEGACY
    case UNFREEZE_LEGACY_BANDWIDTH
    case UNFREEZE_LEGACY_ENERGY
    case UNFREEZE_BANDWIDTH
    case UNFREEZE_ENERGY
    case FREEZE_BANDWIDTH
    case FREEZE_ENERGY
    case UNDELEGATE_BANDWIDTH
    case UNDELEGATE_ENERGY
    case P2P_NODE_REQUEST
    case CREATE_EIGENPOD
    case VERIFY_WITHDRAW_CREDENTIALS
    case START_CHECKPOINT
    case VERIFY_CHECKPOINT_PROOFS
    case QUEUE_WITHDRAWALS
    case COMPLETE_QUEUED_WITHDRAWALS
    case LUGANODES_PROVISION
    case LUGANODES_EXIT_REQUEST
    case INFSTONES_PROVISION
    case INFSTONES_EXIT_REQUEST
    case INFSTONES_CLAIM_REQUEST
}

