//
//  LifiQuoteResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 21/11/2025.
//

import Foundation

/// Returns a Step object which contains information about the estimated result and a transactionRequest
// MARK: - LifiQuoteResponse
public typealias LifiQuoteResponse = LifiStep

/// Error response when unable to find a quote for the requested transfer (404)
// MARK: - LifiQuoteErrorResponse
public struct LifiQuoteErrorResponse: Codable {
    /// The error message
    public let message: String
    /// Error details containing unavailable routes information
    public let errors: LifiUnavailableRoutes?
}
