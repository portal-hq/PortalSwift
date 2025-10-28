//
//  YieldXyzGetBalancesRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation

/// Request to get yield balances for specific addresses and networks
public struct YieldXyzGetBalancesRequest: Codable {
    public let queries: [YieldXyzBalanceQuery]
    
    public init(queries: [YieldXyzBalanceQuery]) {
        self.queries = queries
    }
}

public struct YieldXyzBalanceQuery: Codable {
    public let address: String
    public let network: String
    public let yieldId: String?
    
    public init(address: String, network: String, yieldId: String? = nil) {
        self.address = address
        self.network = network
        self.yieldId = yieldId
    }
}

