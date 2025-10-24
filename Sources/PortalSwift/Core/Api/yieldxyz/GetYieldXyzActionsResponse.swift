//
//  GetYieldXyzActionsResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation

/// Response for fetching yield actions list for an address
public struct GetYieldXyzActionsResponse: Codable {
    public let data: YieldActionsData
    public let metadata: YieldMetadata?
    
    public init(data: YieldActionsData, metadata: YieldMetadata? = nil) {
        self.data = data
        self.metadata = metadata
    }
}

public struct YieldActionsData: Codable {
    public let rawResponse: YieldActionsRawResponse
    
    public init(rawResponse: YieldActionsRawResponse) {
        self.rawResponse = rawResponse
    }
}

public struct YieldActionsRawResponse: Codable {
    public let items: [EnterYieldRawResponse]
    public let total: Int?
    public let offset: Int?
    public let limit: Int?
    
    public init(
        items: [EnterYieldRawResponse],
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

