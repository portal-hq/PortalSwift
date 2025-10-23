//
//  ManageYieldRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation

/// Request to manage a yield opportunity
public struct ManageYieldRequest: Codable {
    public let yieldId: String
    public let address: String
    public let arguments: EnterYieldArguments
    public let action: YieldActionType
    public let passthrough: String
    
    public init(
        yieldId: String,
        address: String,
        arguments: EnterYieldArguments,
        action: YieldActionType,
        passthrough: String
    ) {
        self.yieldId = yieldId
        self.address = address
        self.arguments = arguments
        self.action = action
        self.passthrough = passthrough
    }
}

