//
//  YieldXyzExitRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation

/// Request to exit a yield opportunity
public struct YieldXyzExitRequest: Codable {
    public let yieldId: String
    public let address: String
    public let arguments: YieldXyzEnterArguments?
    
    public init(yieldId: String, address: String, arguments: YieldXyzEnterArguments? = nil) {
        self.yieldId = yieldId
        self.address = address
        self.arguments = arguments
    }
}

