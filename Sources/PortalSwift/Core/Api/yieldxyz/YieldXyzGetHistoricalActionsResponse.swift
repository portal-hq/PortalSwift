//
//  YieldXyzGetHistoricalActionsResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation

/// Response for fetching yield actions list for an address
public struct YieldXyzGetHistoricalActionsResponse: Codable {
    public let data: YieldXyzGetHistoricalActionsData?
    public let metadata: YieldXyzGetBalancesMetadata?
    public let error: String?
    
    public init(data: YieldXyzGetHistoricalActionsData? = nil, metadata: YieldXyzGetBalancesMetadata? = nil, error: String? = nil) {
        self.data = data
        self.metadata = metadata
        self.error = error
    }
}

public struct YieldXyzGetHistoricalActionsData: Codable {
    public let rawResponse: YieldXyzGetHistoricalActionsRawResponse
    
    public init(rawResponse: YieldXyzGetHistoricalActionsRawResponse) {
        self.rawResponse = rawResponse
    }
}

public struct YieldXyzGetHistoricalActionsRawResponse: Codable {
    public let items: [YieldXyzEnterRawResponse]
    public let total: Int?
    public let offset: Int?
    public let limit: Int?
    
    public init(
        items: [YieldXyzEnterRawResponse],
        total: Int? = nil,
        offset: Int? = nil,
        limit: Int? = nil
    ) {
        self.items = items
        self.total = total
        self.offset = offset
        self.limit = limit
    }
}

