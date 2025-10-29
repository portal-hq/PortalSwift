//
//  YieldXyzGetTransactionResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation
import AnyCodable

/// Response for fetching a single yield action transaction by ID
public struct YieldXyzGetTransactionResponse: Codable {
    public let data: YieldXyzGetTransactionData?
    public let metadata: YieldXyzGetTransactionMetadata?
    public let error: String?
    
    public init(data: YieldXyzGetTransactionData? = nil, metadata: YieldXyzGetTransactionMetadata? = nil, error: String? = nil) {
        self.data = data
        self.metadata = metadata
        self.error = error
    }
}

public struct YieldXyzGetTransactionData: Codable {
    public let rawResponse: YieldXyzGetTransactionRawResponse
    
    public init(rawResponse: YieldXyzGetTransactionRawResponse) {
        self.rawResponse = rawResponse
    }
}

/// Mirrors a single transaction object returned by the Yield.xyz actions API.
public struct YieldXyzGetTransactionRawResponse: Codable {
    public let id: String
    public let title: String
    public let network: String
    public let status: YieldXyzActionTransactionStatus
    public let type: YieldXyzActionTransactionType
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
        status: YieldXyzActionTransactionStatus,
        type: YieldXyzActionTransactionType,
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

public struct YieldXyzGetTransactionMetadata: Codable {
    public let clientId: String?
    public let transactionId: String?
    
    public init(clientId: String? = nil, transactionId: String? = nil) {
        self.clientId = clientId
        self.transactionId = transactionId
    }
}

