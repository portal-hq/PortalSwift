//
//  GetYieldXyzBalancesResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation

/// Response from getting yield balances
public struct GetYieldXyzBalancesResponse: Codable {
    public let data: YieldBalancesData?
    public let metadata: YieldMetadata?
    
    public init(data: YieldBalancesData? = nil, metadata: YieldMetadata? = nil) {
        self.data = data
        self.metadata = metadata
    }
}

public struct YieldBalancesData: Codable {
    public let rawResponse: YieldBalancesRawResponse
    
    public init(rawResponse: YieldBalancesRawResponse) {
        self.rawResponse = rawResponse
    }
}

public struct YieldBalancesRawResponse: Codable {
    public let items: [YieldBalanceItem]
    public let errors: [String]
    
    public init(items: [YieldBalanceItem], errors: [String] = []) {
        self.items = items
        self.errors = errors
    }
}

public struct YieldBalanceItem: Codable {
    public let yieldId: String
    public let balances: [YieldBalance]
    
    public init(yieldId: String, balances: [YieldBalance]) {
        self.yieldId = yieldId
        self.balances = balances
    }
}

public struct YieldBalance: Codable {
    public let address: String
    public let amount: String
    public let amountRaw: String
    public let type: String
    public let token: YieldToken
    public let pendingActions: [String]
    public let amountUsd: String?
    public let isEarning: Bool?
    
    public init(
        address: String,
        amount: String,
        amountRaw: String,
        type: String,
        token: YieldToken,
        pendingActions: [String] = [],
        amountUsd: String? = nil,
        isEarning: Bool? = nil
    ) {
        self.address = address
        self.amount = amount
        self.amountRaw = amountRaw
        self.type = type
        self.token = token
        self.pendingActions = pendingActions
        self.amountUsd = amountUsd
        self.isEarning = isEarning
    }
}

public struct YieldToken: Codable {
    public let address: String
    public let symbol: String
    public let name: String
    public let decimals: Int
    public let logoURI: String?
    public let network: String
    public let isPoints: Bool?
    
    public init(
        address: String,
        symbol: String,
        name: String,
        decimals: Int,
        logoURI: String? = nil,
        network: String,
        isPoints: Bool? = nil
    ) {
        self.address = address
        self.symbol = symbol
        self.name = name
        self.decimals = decimals
        self.logoURI = logoURI
        self.network = network
        self.isPoints = isPoints
    }
}

public struct YieldMetadata: Codable {
    public let clientId: String?
    
    public init(clientId: String?) {
        self.clientId = clientId
    }
}

