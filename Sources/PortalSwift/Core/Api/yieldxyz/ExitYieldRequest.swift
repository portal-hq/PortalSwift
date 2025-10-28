//
//  ExitYieldRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation

/// Request to exit a yield opportunity
public struct ExitYieldRequest: Codable {
    public let yieldId: String
    public let address: String
    public let arguments: EnterYieldArguments?
    
    public init(yieldId: String, address: String, arguments: EnterYieldArguments? = nil) {
        self.yieldId = yieldId
        self.address = address
        self.arguments = arguments
        
    }
}

