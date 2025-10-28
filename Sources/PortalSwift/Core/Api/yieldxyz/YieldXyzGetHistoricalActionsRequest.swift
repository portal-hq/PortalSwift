//
//  YieldXyzGetHistoricalActionsRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation

/// Request to get historical yield actions with optional filtering
public struct YieldXyzGetHistoricalActionsRequest: Codable {
    public let offset: Int?
    public let limit: Int?
    public let address: String?
    public let status: YieldXyzActionStatus?
    public let intent: YieldXyzActionIntent?
    public let type: YieldXyzActionType?
    public let yieldId: String?
    
    public init(
        offset: Int? = nil,
        limit: Int? = nil,
        address: String? = nil,
        status: YieldXyzActionStatus? = nil,
        intent: YieldXyzActionIntent? = nil,
        type: YieldXyzActionType? = nil,
        yieldId: String? = nil
    ) {
        self.offset = offset
        self.limit = limit
        self.address = address
        self.status = status
        self.intent = intent
        self.type = type
        self.yieldId = yieldId
    }
}

