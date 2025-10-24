//
//  GetYieldXyzBalancesRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation

/// Request to get yield balances for specific addresses and networks
public struct GetYieldXyzBalancesRequest: Codable {
    public let queries: [YieldBalanceQuery]
    
    public init(queries: [YieldBalanceQuery]) {
        self.queries = queries
    }
}

public struct YieldBalanceQuery: Codable {
    public let address: String
    public let network: String
    public let yieldId: String?
    
    public init(address: String, network: String, yieldId: String? = nil) {
        self.address = address
        self.network = network
        self.yieldId = yieldId
    }
}

