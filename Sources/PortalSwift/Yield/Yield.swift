//
//  Yield.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation

/// The main entry point for yield-related functionality in the Portal SDK.
///
/// This class provides access to various yield providers and their capabilities.
/// Currently supports YieldXyz as the primary yield provider.
public class Yield {
    /// Access to YieldXyz yield provider functionality.
    public let yieldxyz: YieldXyz
    
    /// Create an instance of Yield.
    /// - Parameter api: The Portal API instance to use for yield operations.
    init(api: PortalApiProtocol) {
        self.yieldxyz = YieldXyz(api: api.yieldxyz)
    }
}
