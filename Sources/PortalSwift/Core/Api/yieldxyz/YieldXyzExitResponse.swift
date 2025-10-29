//
//  YieldXyzExitResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation

/// Response from exiting a yield opportunity
public struct YieldXyzExitResponse: Codable {
    public let data: YieldXyzExitData?
    public let error: String?
    
    public init(data: YieldXyzExitData? = nil, error: String? = nil) {
        self.data = data
        self.error = error
    }
}

public struct YieldXyzExitData: Codable {
    public let rawResponse: YieldXyzExitRawResponse
    
    public init(rawResponse: YieldXyzExitRawResponse) {
        self.rawResponse = rawResponse
    }
}

public struct YieldXyzExitRawResponse: Codable {
    public let id: String
    public let intent: YieldXyzActionIntent
    public let type: YieldXyzActionType
    public let yieldId: String
    public let address: String
    public let amount: String?
    public let amountRaw: String?
    public let amountUsd: String?
    public let transactions: [YieldXyzActionTransaction]
    public let executionPattern: YieldXyzActionExecutionPattern
    public let rawArguments: YieldXyzEnterArguments?
    public let createdAt: String
    public let completedAt: String?
    public let status: YieldXyzActionStatus
    
    public init(
        id: String,
        intent: YieldXyzActionIntent,
        type: YieldXyzActionType,
        yieldId: String,
        address: String,
        amount: String? = nil,
        amountRaw: String? = nil,
        amountUsd: String? = nil,
        transactions: [YieldXyzActionTransaction],
        executionPattern: YieldXyzActionExecutionPattern,
        rawArguments: YieldXyzEnterArguments? = nil,
        createdAt: String,
        completedAt: String? = nil,
        status: YieldXyzActionStatus
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

