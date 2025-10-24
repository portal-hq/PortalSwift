//
//  PortalYieldXyzApi.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation

/// API class specifically for Yield.xyz integration functionality.
///
/// This class handles all yield-related API calls including discovering yields,
/// entering/exiting yield opportunities, managing yields, and tracking transactions.
public class PortalYieldXyzApi {
    private let apiKey: String
    private let baseUrl: String
    private let requests: PortalRequestsProtocol
    private let logger = PortalLogger()
    
    /// Create an instance of PortalYieldXyzApi.
    /// - Parameters:
    ///   - apiKey: The Client API key.
    ///   - apiHost: The Portal API hostname.
    ///   - requests: An instance of PortalRequestsProtocol to handle HTTP requests.
    public init(
        apiKey: String,
        apiHost: String = "api.portalhq.io",
        requests: PortalRequestsProtocol? = nil
    ) {
        self.apiKey = apiKey
        self.baseUrl = apiHost.starts(with: "localhost") ? "http://\(apiHost)" : "https://\(apiHost)"
        self.requests = requests ?? PortalRequests()
    }
    
    /*******************************************
     * Public functions
     *******************************************/
    
    /// Retrieves yield opportunities from the Yield.xyz integration.
    /// - Parameter request: The parameters for the yield discovery request.
    /// - Returns: A `GetYieldsXyzResponse` containing available yield opportunities.
    /// - Throws: An error if the operation fails.
    public func getYields(request: GetYieldsXyzRequest) async throws -> GetYieldsXyzResponse {
        var queryParams: [String] = []
        
        // Helper function to add query parameters
        func addParam(_ key: String, _ value: Any?) {
            guard let value = value else { return }
            let stringValue = "\(value)"
            if let encoded = stringValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                queryParams.append("\(key)=\(encoded)")
            }
        }
        
        addParam("offset", request.offset)
        addParam("limit", request.limit)
        addParam("network", request.network)
        addParam("yieldId", request.yieldId)
        addParam("type", request.type?.rawValue)
        addParam("hasCooldownPeriod", request.hasCooldownPeriod)
        addParam("hasWarmupPeriod", request.hasWarmupPeriod)
        addParam("token", request.token)
        addParam("inputToken", request.inputToken)
        addParam("provider", request.provider)
        addParam("search", request.search)
        addParam("sort", request.sort?.rawValue)
        
        let queryString = queryParams.isEmpty ? "" : "?\(queryParams.joined(separator: "&"))"
        
        guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/yield-xyz/yields\(queryString)") else {
            logger.error("PortalYieldXyzApi.getYields() - Unable to build request URL.")
            throw URLError(.badURL)
        }
        
        do {
            return try await get(url, withBearerToken: apiKey, mappingInResponse: GetYieldsXyzResponse.self)
        } catch {
            logger.error("PortalYieldXyzApi.getYields() - Error: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Enters a yield opportunity through the Yield.xyz integration.
    /// - Parameter request: The parameters for entering a yield opportunity.
    /// - Returns: An `EnterYieldXyzResponse` containing the action details.
    /// - Throws: An error if the operation fails.
    public func enterYield(request: EnterYieldXyzRequest) async throws -> EnterYieldXyzResponse {
        guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/yield-xyz/actions/enter") else {
            logger.error("PortalYieldXyzApi.enterYield() - Unable to build request URL.")
            throw URLError(.badURL)
        }
        
        do {
            return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: EnterYieldXyzResponse.self)
        } catch {
            logger.error("PortalYieldXyzApi.enterYield() - Error: \(error.localizedDescription)")
            // Provide more helpful error message for common issues
            let errorString = error.localizedDescription.lowercased()
            if errorString.contains("400") || errorString.contains("bad request") {
                throw NSError(
                    domain: "PortalYieldXyzApi",
                    code: 400,
                    userInfo: [NSLocalizedDescriptionKey: "API returned 400 Bad Request. This usually means required fields are missing (e.g., validatorAddress for staking yields). Try a different yield type like lending."]
                )
            }
            throw error
        }
    }
    
    /// Exits a yield opportunity through the Yield.xyz integration.
    /// - Parameter request: The parameters for exiting a yield opportunity.
    /// - Returns: An `ExitYieldXyzResponse` containing the action details.
    /// - Throws: An error if the operation fails.
    public func exitYield(request: ExitYieldXyzRequest) async throws -> ExitYieldXyzResponse {
        guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/yield-xyz/actions/exit") else {
            logger.error("PortalYieldXyzApi.exitYield() - Unable to build request URL.")
            throw URLError(.badURL)
        }
        
        do {
            return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: ExitYieldXyzResponse.self)
        } catch {
            logger.error("PortalYieldXyzApi.exitYield() - Error: \(error.localizedDescription)")
            let errorString = error.localizedDescription.lowercased()
            if errorString.contains("400") || errorString.contains("bad request") {
                throw NSError(
                    domain: "PortalYieldXyzApi",
                    code: 400,
                    userInfo: [NSLocalizedDescriptionKey: "API returned 400 Bad Request when exiting yield."]
                )
            }
            throw error
        }
    }
    
    /// Manages a yield opportunity through the Yield.xyz integration.
    /// - Parameter request: The parameters for managing a yield opportunity.
    /// - Returns: A `ManageYieldXyzResponse` containing the action details.
    /// - Throws: An error if the operation fails.
    public func manageYield(request: ManageYieldXyzRequest) async throws -> ManageYieldXyzResponse {
        guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/yield-xyz/actions/manage") else {
            logger.error("PortalYieldXyzApi.manageYield() - Unable to build request URL.")
            throw URLError(.badURL)
        }
        
        do {
            return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: ManageYieldXyzResponse.self)
        } catch {
            logger.error("PortalYieldXyzApi.manageYield() - Error: \(error.localizedDescription)")
            let errorString = error.localizedDescription.lowercased()
            if errorString.contains("400") || errorString.contains("bad request") {
                throw NSError(
                    domain: "PortalYieldXyzApi",
                    code: 400,
                    userInfo: [NSLocalizedDescriptionKey: "API returned 400 Bad Request when managing yield."]
                )
            }
            throw error
        }
    }
    
    /// Retrieves yield balances for specified addresses and networks.
    /// - Parameter request: The parameters for the yield balances request.
    /// - Returns: A `GetYieldXyzBalancesResponse` containing balance information.
    /// - Throws: An error if the operation fails.
    public func getYieldBalances(request: GetYieldXyzBalancesRequest) async throws -> GetYieldXyzBalancesResponse {
        guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/yield-xyz/yields/balances") else {
            logger.error("PortalYieldXyzApi.getYieldBalances() - Unable to build request URL.")
            throw URLError(.badURL)
        }
        
        do {
            return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: GetYieldXyzBalancesResponse.self)
        } catch {
            logger.error("PortalYieldXyzApi.getYieldBalances() - Error: \(error.localizedDescription)")
            let errorString = error.localizedDescription.lowercased()
            if errorString.contains("400") || errorString.contains("bad request") {
                throw NSError(
                    domain: "PortalYieldXyzApi",
                    code: 400,
                    userInfo: [NSLocalizedDescriptionKey: "API returned 400 Bad Request when getting yield balances."]
                )
            }
            throw error
        }
    }
    
    /// Retrieves historical yield actions with optional filtering.
    /// - Parameter request: The parameters for the historical yield actions request.
    /// - Returns: A `GetYieldXyzActionsResponse` containing historical actions.
    /// - Throws: An error if the operation fails.
    public func getHistoricalYieldActions(request: GetYieldXyzActionsRequest) async throws -> GetYieldXyzActionsResponse {
        var queryParams: [String] = []
        
        // Helper function to add query parameters
        func addParam(_ key: String, _ value: Any?) {
            guard let value = value else { return }
            let stringValue = "\(value)"
            if let encoded = stringValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                queryParams.append("\(key)=\(encoded)")
            }
        }
        
        addParam("address", request.address)
        addParam("offset", request.offset)
        addParam("limit", request.limit)
        addParam("status", request.status?.rawValue)
        addParam("intent", request.intent?.rawValue)
        addParam("type", request.type?.rawValue)
        addParam("yieldId", request.yieldId)
        
        let queryString = queryParams.isEmpty ? "" : "?\(queryParams.joined(separator: "&"))"
        
        guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/yield-xyz/actions\(queryString)") else {
            logger.error("PortalYieldXyzApi.getHistoricalYieldActions() - Unable to build request URL.")
            throw URLError(.badURL)
        }
        
        do {
            return try await get(url, withBearerToken: apiKey, mappingInResponse: GetYieldXyzActionsResponse.self)
        } catch {
            logger.error("PortalYieldXyzApi.getHistoricalYieldActions() - Error: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Retrieves a single yield action transaction by its ID.
    /// - Parameter transactionId: The ID of the transaction to retrieve.
    /// - Returns: A `GetYieldXyzActionTransactionResponse` containing transaction details.
    /// - Throws: An error if the operation fails.
    public func getYieldTransaction(transactionId: String) async throws -> GetYieldXyzActionTransactionResponse {
        guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/yield-xyz/transactions/\(transactionId)") else {
            logger.error("PortalYieldXyzApi.getYieldTransaction() - Unable to build request URL.")
            throw URLError(.badURL)
        }
        
        do {
            return try await get(url, withBearerToken: apiKey, mappingInResponse: GetYieldXyzActionTransactionResponse.self)
        } catch {
            logger.error("PortalYieldXyzApi.getYieldTransaction() - Error: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Submits a transaction hash for tracking in the Yield.xyz integration.
    /// - Parameter request: The transaction hash submission request containing transactionId and hash.
    /// - Returns: `true` if the submission was successful.
    /// - Throws: An error if the operation fails.
    public func submitTransactionHash(request: SubmitYieldXyzTransactionHashRequest) async throws -> Bool {
        guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/yield-xyz/transactions/\(request.transactionId)/submit-hash") else {
            logger.error("PortalYieldXyzApi.submitTransactionHash() - Unable to build request URL.")
            throw URLError(.badURL)
        }
        
        do {
            // TODO: - we need to revisit the response here
            try await put(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: Data.self)
            return true
        } catch {
            logger.error("PortalYieldXyzApi.submitTransactionHash() - Error: \(error.localizedDescription)")
            let errorString = error.localizedDescription.lowercased()
            if errorString.contains("400") || errorString.contains("bad request") {
                throw NSError(
                    domain: "PortalYieldXyzApi",
                    code: 400,
                    userInfo: [NSLocalizedDescriptionKey: "API returned 400 Bad Request when submitting transaction hash."]
                )
            }
            throw error
        }
    }
    
    /*******************************************
     * Private functions
     *******************************************/
    
    @discardableResult
    private func get<ResponseType>(
        _ url: URL,
        withBearerToken: String? = nil,
        mappingInResponse: ResponseType.Type
    ) async throws -> ResponseType where ResponseType: Decodable {
        let portalRequest = PortalAPIRequest(url: url, bearerToken: withBearerToken)
        return try await requests.execute(request: portalRequest, mappingInResponse: mappingInResponse.self)
    }
    
    @discardableResult
    private func post<ResponseType>(
        _ url: URL,
        withBearerToken: String? = nil,
        andPayload: Codable? = nil,
        mappingInResponse: ResponseType.Type
    ) async throws -> ResponseType where ResponseType: Decodable {
        let portalRequest = PortalAPIRequest(url: url, method: .post, payload: andPayload, bearerToken: withBearerToken)
        return try await requests.execute(request: portalRequest, mappingInResponse: mappingInResponse.self)
    }
    
    @discardableResult
    private func put<ResponseType>(
        _ url: URL,
        withBearerToken: String? = nil,
        andPayload: Codable,
        mappingInResponse: ResponseType.Type
    ) async throws -> ResponseType where ResponseType: Decodable {
        let portalRequest = PortalAPIRequest(url: url, method: .put, payload: andPayload, bearerToken: withBearerToken)
        return try await requests.execute(request: portalRequest, mappingInResponse: mappingInResponse.self)
    }
}

