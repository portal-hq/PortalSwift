//
//  PortalYieldXyzApi.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation

/// Protocol of Yield.xyz API interactions.
public protocol PortalYieldXyzApiProtocol: AnyObject {
  func getYields(request: YieldXyzGetYieldsRequest) async throws -> YieldXyzGetYieldsResponse
  func enterYield(request: YieldXyzEnterRequest) async throws -> YieldXyzEnterYieldResponse
  func exitYield(request: YieldXyzExitRequest) async throws -> YieldXyzExitResponse
  func manageYield(request: YieldXyzManageYieldRequest) async throws -> YieldXyzManageYieldResponse
  func getYieldBalances(request: YieldXyzGetBalancesRequest) async throws -> YieldXyzGetBalancesResponse
  func getHistoricalYieldActions(request: YieldXyzGetHistoricalActionsRequest) async throws -> YieldXyzGetHistoricalActionsResponse
  func getYieldTransaction(transactionId: String) async throws -> YieldXyzGetTransactionResponse
  func submitTransactionHash(request: YieldXyzTrackTransactionRequest) async throws -> YieldXyzTrackTransactionResponse
}

/// API class specifically for Yield.xyz integration functionality.
///
/// This class handles all yield-related API calls including discovering yields,
/// entering/exiting yield opportunities, managing yields, and tracking transactions.
public class PortalYieldXyzApi: PortalYieldXyzApiProtocol {
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
  /// - Returns: A `YieldXyzGetYieldsResponse` containing available yield opportunities.
  /// - Throws: An error if the operation fails.
  public func getYields(request: YieldXyzGetYieldsRequest) async throws -> YieldXyzGetYieldsResponse {
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
      return try await get(url, withBearerToken: apiKey, mappingInResponse: YieldXyzGetYieldsResponse.self)
    } catch {
      logger.error("PortalYieldXyzApi.getYields() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Enters a yield opportunity through the Yield.xyz integration.
  /// - Parameter request: The parameters for entering a yield opportunity.
  /// - Returns: A `YieldXyzEnterYieldResponse` containing the action details.
  /// - Throws: An error if the operation fails.
  public func enterYield(request: YieldXyzEnterRequest) async throws -> YieldXyzEnterYieldResponse {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/yield-xyz/actions/enter") else {
      logger.error("PortalYieldXyzApi.enterYield() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: YieldXyzEnterYieldResponse.self)
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
  /// - Returns: A `YieldXyzExitResponse` containing the action details.
  /// - Throws: An error if the operation fails.
  public func exitYield(request: YieldXyzExitRequest) async throws -> YieldXyzExitResponse {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/yield-xyz/actions/exit") else {
      logger.error("PortalYieldXyzApi.exitYield() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: YieldXyzExitResponse.self)
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
  /// - Returns: A `YieldXyzManageYieldResponse` containing the action details.
  /// - Throws: An error if the operation fails.
  public func manageYield(request: YieldXyzManageYieldRequest) async throws -> YieldXyzManageYieldResponse {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/yield-xyz/actions/manage") else {
      logger.error("PortalYieldXyzApi.manageYield() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: YieldXyzManageYieldResponse.self)
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
  /// - Returns: A `YieldXyzGetBalancesResponse` containing balance information.
  /// - Throws: An error if the operation fails.
  public func getYieldBalances(request: YieldXyzGetBalancesRequest) async throws -> YieldXyzGetBalancesResponse {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/yield-xyz/yields/balances") else {
      logger.error("PortalYieldXyzApi.getYieldBalances() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: YieldXyzGetBalancesResponse.self)
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
  /// - Returns: A `YieldXyzGetHistoricalActionsResponse` containing historical actions.
  /// - Throws: An error if the operation fails.
  public func getHistoricalYieldActions(request: YieldXyzGetHistoricalActionsRequest) async throws -> YieldXyzGetHistoricalActionsResponse {
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
      return try await get(url, withBearerToken: apiKey, mappingInResponse: YieldXyzGetHistoricalActionsResponse.self)
    } catch {
      logger.error("PortalYieldXyzApi.getHistoricalYieldActions() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Retrieves a single yield action transaction by its ID.
  /// - Parameter transactionId: The ID of the transaction to retrieve.
  /// - Returns: A `YieldXyzGetTransactionResponse` containing transaction details.
  /// - Throws: An error if the operation fails.
  public func getYieldTransaction(transactionId: String) async throws -> YieldXyzGetTransactionResponse {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/yield-xyz/transactions/\(transactionId)") else {
      logger.error("PortalYieldXyzApi.getYieldTransaction() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await get(url, withBearerToken: apiKey, mappingInResponse: YieldXyzGetTransactionResponse.self)
    } catch {
      logger.error("PortalYieldXyzApi.getYieldTransaction() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Submits a transaction hash for tracking in the Yield.xyz integration.
  /// - Parameter request: The transaction hash submission request containing transactionId and hash.
  /// - Returns: `true` if the submission was successful.
  /// - Throws: An error if the operation fails.
  public func submitTransactionHash(request: YieldXyzTrackTransactionRequest) async throws -> YieldXyzTrackTransactionResponse {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/yield-xyz/transactions/\(request.transactionId)/submit-hash") else {
      logger.error("PortalYieldXyzApi.submitTransactionHash() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await put(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: YieldXyzTrackTransactionResponse.self)
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
