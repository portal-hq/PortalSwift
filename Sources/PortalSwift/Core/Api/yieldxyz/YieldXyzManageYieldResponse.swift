//
//  YieldXyzManageYieldResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation

/// Response from managing a yield opportunity
public struct YieldXyzManageYieldResponse: Codable {
    public let data: YieldXyzManageYieldData
    
    public init(data: YieldXyzManageYieldData) {
        self.data = data
    }
}

public struct YieldXyzManageYieldData: Codable {
    public let rawResponse: YieldXyzManageYieldRawResponse
    
    public init(rawResponse: YieldXyzManageYieldRawResponse) {
        self.rawResponse = rawResponse
    }
}

public struct YieldXyzManageYieldRawResponse: Codable {
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

