//
//  LifiQuoteResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 21/11/2025.
//

import Foundation

/// Returns a Step object which contains information about the estimated result and a transactionRequest
// MARK: - LifiQuoteResponse
typealias LifiQuoteResponse = LifiStep

/// Error response when unable to find a quote for the requested transfer (404)
// MARK: - LifiQuoteErrorResponse
struct LifiQuoteErrorResponse: Codable {
    /// The error message
    let message: String
    /// Error details containing unavailable routes information
    let errors: LifiUnavailableRoutes?
}
