//
//  YieldXyz.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation

/// YieldXyz provider implementation for discovering and managing yield opportunities.
public class YieldXyz {
    private let api: PortalYieldXyzApi
    
    /// Create an instance of YieldXyz.
    /// - Parameter api: The PortalYieldXyzApi instance to use for yield operations.
    public init(api: PortalYieldXyzApi) {
        self.api = api
    }
    
    /// Discovers yield opportunities based on the provided parameters.
    /// - Parameter request: Optional parameters for yield discovery. If nil, uses default parameters.
    /// - Returns: A `GetYieldsXyzResponse` containing available yield opportunities.
    /// - Throws: An error if the operation fails.
    public func discover(request: GetYieldsXyzRequest? = nil) async throws -> GetYieldsXyzResponse {
        let discoveryRequest = request ?? GetYieldsXyzRequest()
        return try await api.getYields(request: discoveryRequest)
    }
    
    /// Enters a yield opportunity with the specified parameters.
    /// - Parameter request: The parameters for entering a yield opportunity.
    /// - Returns: An `EnterYieldXyzResponse` containing the action details.
    /// - Throws: An error if the operation fails.
    public func enter(request: EnterYieldXyzRequest) async throws -> EnterYieldXyzResponse {
        return try await api.enterYield(request: request)
    }
    
    /// Tracks a transaction by submitting its hash to the Yield.xyz integration.
    /// - Parameters:
    ///   - transactionId: The ID of the transaction to track.
    ///   - txHash: The hash of the transaction to submit.
    /// - Returns: `true` if the submission was successful.
    /// - Throws: An error if the operation fails.
    @discardableResult
    public func track(transactionId: String, txHash: String) async throws -> Bool {
        let request = SubmitYieldXyzTransactionHashRequest(transactionId: transactionId, hash: txHash)
        return try await api.submitTransactionHash(request: request)
    }
    
    /// Retrieves yield balances for specified addresses and networks.
    /// - Parameter request: The parameters for the yield balances request.
    /// - Returns: A `GetYieldXyzBalancesResponse` containing balance information.
    /// - Throws: An error if the operation fails.
    public func getBalances(request: GetYieldXyzBalancesRequest) async throws -> GetYieldXyzBalancesResponse {
        return try await api.getYieldBalances(request: request)
    }
    
    /// Retrieves a single yield action transaction by its ID.
    /// - Parameter transactionId: The ID of the transaction to retrieve.
    /// - Returns: A `GetYieldXyzActionTransactionResponse` containing transaction details.
    /// - Throws: An error if the operation fails.
    public func getTransaction(transactionId: String) async throws -> GetYieldXyzActionTransactionResponse {
        return try await api.getYieldTransaction(transactionId: transactionId)
    }
    
    /// Retrieves historical yield actions with optional filtering.
    /// - Parameter request: The parameters for the historical yield actions request.
    /// - Returns: A `GetYieldXyzActionsResponse` containing historical actions.
    /// - Throws: An error if the operation fails.
    public func getHistoricalActions(request: GetYieldXyzActionsRequest) async throws -> GetYieldXyzActionsResponse {
        return try await api.getHistoricalYieldActions(request: request)
    }
    
    /// Manages a yield opportunity with the specified parameters.
    /// - Parameter request: The parameters for managing a yield opportunity.
    /// - Returns: A `ManageYieldXyzResponse` containing the action details.
    /// - Throws: An error if the operation fails.
    public func manage(request: ManageYieldXyzRequest) async throws -> ManageYieldXyzResponse {
        return try await api.manageYield(request: request)
    }
    
    /// Exits a yield opportunity with the specified parameters.
    /// - Parameter request: The parameters for exiting a yield opportunity.
    /// - Returns: An `ExitYieldXyzResponse` containing the action details.
    /// - Throws: An error if the operation fails.
    public func exit(request: ExitYieldXyzRequest) async throws -> ExitYieldXyzResponse {
        return try await api.exitYield(request: request)
    }
}
