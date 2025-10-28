//
//  SubmitTransactionHashRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation

/// Request to submit a transaction hash for tracking
public struct SubmitTransactionHashRequest: Codable {
    public let transactionId: String
    public let hash: String
    
    public init(transactionId: String, hash: String) {
        self.transactionId = transactionId
        self.hash = hash
    }
}

