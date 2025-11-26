//
//  LifiQuoteResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 21/11/2025.
//

import Foundation

/// Response containing a quote from the Lifi integration
// MARK: - LifiQuoteResponse
public struct LifiQuoteResponse: Codable {
    public let data: LifiQuoteData?
    public let error: String?

    public init(data: LifiQuoteData? = nil, error: String? = nil) {
        self.data = data
        self.error = error
    }
}

public struct LifiQuoteData: Codable {
    public let rawResponse: LifiStep

    public init(rawResponse: LifiStep) {
        self.rawResponse = rawResponse
    }
}

/// Error response when unable to find a quote for the requested transfer (404)
// MARK: - LifiQuoteErrorResponse
public struct LifiQuoteErrorResponse: Codable {
    /// The error message
    public let message: String
    /// Error details containing unavailable routes information
    public let errors: LifiUnavailableRoutes?
}
