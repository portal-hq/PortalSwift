//
//  ExitYieldXyzResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation

/// Response from exiting a yield opportunity
public struct ExitYieldXyzResponse: Codable {
    public let data: ExitYieldData
    
    public init(data: ExitYieldData) {
        self.data = data
    }
}

public struct ExitYieldData: Codable {
    public let rawResponse: ExitYieldRawResponse
    
    public init(rawResponse: ExitYieldRawResponse) {
        self.rawResponse = rawResponse
    }
}

public struct ExitYieldRawResponse: Codable {
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

