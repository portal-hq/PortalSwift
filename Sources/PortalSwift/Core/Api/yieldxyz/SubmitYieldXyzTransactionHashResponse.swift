//
//  SubmitYieldXyzTransactionHashResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation

/// Response from submitting a transaction hash
public struct SubmitYieldXyzTransactionHashResponse: Codable {
    public let success: Bool
    public let transaction: TransactionInfo
    
    public init(success: Bool, transaction: TransactionInfo) {
        self.success = success
        self.transaction = transaction
    }
}

public struct TransactionInfo: Codable {
    public let id: String
    public let hash: String
    public let status: String
    public let blockNumber: Int?
    public let gasUsed: String?
    public let gasPrice: String?
    public let updatedAt: String
    
    public init(
        id: String,
        hash: String,
        status: String,
        blockNumber: Int? = nil,
        gasUsed: String? = nil,
        gasPrice: String? = nil,
        updatedAt: String
    ) {
        self.id = id
        self.hash = hash
        self.status = status
        self.blockNumber = blockNumber
        self.gasUsed = gasUsed
        self.gasPrice = gasPrice
        self.updatedAt = updatedAt
    }
}

