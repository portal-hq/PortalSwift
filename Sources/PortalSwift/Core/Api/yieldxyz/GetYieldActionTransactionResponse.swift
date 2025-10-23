//
//  GetYieldActionTransactionResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation
import AnyCodable

/// Response for fetching a single yield action transaction by ID
public struct GetYieldActionTransactionResponse: Codable {
    public let data: YieldActionTransactionData
    public let metadata: YieldActionTransactionMetadata?
    
    public init(data: YieldActionTransactionData, metadata: YieldActionTransactionMetadata? = nil) {
        self.data = data
        self.metadata = metadata
    }
}

public struct YieldActionTransactionData: Codable {
    public let rawResponse: YieldActionTransactionRawResponse
    
    public init(rawResponse: YieldActionTransactionRawResponse) {
        self.rawResponse = rawResponse
    }
}

/// Mirrors a single transaction object returned by the Yield.xyz actions API.
public struct YieldActionTransactionRawResponse: Codable {
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
    public let stepIndex: Int
    public let gasEstimate: String?
    
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
        stepIndex: Int,
        gasEstimate: String? = nil
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
        self.stepIndex = stepIndex
        self.gasEstimate = gasEstimate
    }
}

public struct YieldActionTransactionMetadata: Codable {
    public let clientId: String?
    public let transactionId: String?
    
    public init(clientId: String? = nil, transactionId: String? = nil) {
        self.clientId = clientId
        self.transactionId = transactionId
    }
}

