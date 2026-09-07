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
  func getYieldDefaults(includeOpportunities: Bool?) async throws -> YieldXyzGetDefaultsResponse
  func getYieldValidators(yieldId: String) async throws -> YieldXyzGetValidatorsResponse
}

/// API class specifically for Yield.xyz integration functionality.
///
/// This class handles all yield-related API calls including discovering yields,
/// entering/exiting yield opportunities, managing yields, and tracking transactions.
public class PortalYieldXyzApi: PortalYieldXyzApiProtocol {
  /// Resolved per request and never cached, so a session rotated or invalidated underneath
  /// this instance is honoured on the next call. Shared by identity with the owning `PortalApi`.
  private let credentials: PortalCredentials
  private let baseUrl: String
  private let requests: PortalRequestsProtocol
  private let logger = PortalLogger.shared

  /// Create an instance of PortalYieldXyzApi.
  ///
  /// The credential is resolved again on every request and never at construction, so a session
  /// that rotates or is invalidated underneath this instance takes effect on the next call. The
  /// transport's 401 hook is wired to `credentials` only when the transport reports 401s and has
  /// no hook yet, so a standalone instance with its own transport still reports a dead session
  /// while one built by `PortalApi` finds the hook already installed and leaves it alone.
  /// - Parameters:
  ///   - credentials: The credential presented as the bearer on every request: a `StaticCredentials`
  ///     wrapping a Client API Key, or a session obtained through `PortalAuth`.
  ///   - apiHost: The Portal API hostname.
  ///   - requests: An instance of PortalRequestsProtocol to handle HTTP requests.
  public init(
    credentials: PortalCredentials,
    apiHost: String = "api.portalhq.io",
    requests: PortalRequestsProtocol? = nil
  ) {
    self.credentials = credentials
    self.baseUrl = apiHost.starts(with: "localhost") ? "http://\(apiHost)" : "https://\(apiHost)"
    self.requests = requests ?? PortalRequests()

    installUnauthorizedHook(on: self.requests, for: credentials, context: "PortalYieldXyzApi")
  }

  /// Create an instance of PortalYieldXyzApi.
  ///
  /// Kept as a convenience so existing integrations compile unchanged; the key is wrapped in
  /// `StaticCredentials` and everything else follows the credentials path. A blank key is not
  /// rejected here because this initializer cannot throw: it fails on first use with
  /// `PortalCredentialError.unavailable` instead of sending an empty bearer.
  /// - Parameters:
  ///   - apiKey: The Client API key.
  ///   - apiHost: The Portal API hostname.
  ///   - requests: An instance of PortalRequestsProtocol to handle HTTP requests.
  @available(*, deprecated, message: "Use init(credentials:) instead; wrap a Client API Key in StaticCredentials(apiKey) or pass a PortalAuth session.")
  public convenience init(
    apiKey: String,
    apiHost: String = "api.portalhq.io",
    requests: PortalRequestsProtocol? = nil
  ) {
    self.init(credentials: StaticCredentials(apiKey), apiHost: apiHost, requests: requests)
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

    addParam("offset", request.offset, to: &queryParams)
    addParam("limit", request.limit, to: &queryParams)
    addParam("network", request.network, to: &queryParams)
    addParam("yieldId", request.yieldId, to: &queryParams)
    addParam("type", request.type?.rawValue, to: &queryParams)
    addParam("hasCooldownPeriod", request.hasCooldownPeriod, to: &queryParams)
    addParam("hasWarmupPeriod", request.hasWarmupPeriod, to: &queryParams)
    addParam("token", request.token, to: &queryParams)
    addParam("inputToken", request.inputToken, to: &queryParams)
    addParam("provider", request.provider, to: &queryParams)
    addParam("search", request.search, to: &queryParams)
    addParam("sort", request.sort?.rawValue, to: &queryParams)

    let queryString = queryParams.isEmpty ? "" : "?\(queryParams.joined(separator: "&"))"

    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/yield-xyz/yields\(queryString)") else {
      logger.error("PortalYieldXyzApi.getYields() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await get(url, mappingInResponse: YieldXyzGetYieldsResponse.self)
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
      return try await post(url, andPayload: request, mappingInResponse: YieldXyzEnterYieldResponse.self)
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
      return try await post(url, andPayload: request, mappingInResponse: YieldXyzExitResponse.self)
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
      return try await post(url, andPayload: request, mappingInResponse: YieldXyzManageYieldResponse.self)
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
      return try await post(url, andPayload: request, mappingInResponse: YieldXyzGetBalancesResponse.self)
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

    addParam("address", request.address, to: &queryParams)
    addParam("offset", request.offset, to: &queryParams)
    addParam("limit", request.limit, to: &queryParams)
    addParam("status", request.status?.rawValue, to: &queryParams)
    addParam("intent", request.intent?.rawValue, to: &queryParams)
    addParam("type", request.type?.rawValue, to: &queryParams)
    addParam("yieldId", request.yieldId, to: &queryParams)

    let queryString = queryParams.isEmpty ? "" : "?\(queryParams.joined(separator: "&"))"

    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/yield-xyz/actions\(queryString)") else {
      logger.error("PortalYieldXyzApi.getHistoricalYieldActions() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await get(url, mappingInResponse: YieldXyzGetHistoricalActionsResponse.self)
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
      return try await get(url, mappingInResponse: YieldXyzGetTransactionResponse.self)
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
      return try await put(url, andPayload: request, mappingInResponse: YieldXyzTrackTransactionResponse.self)
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

  /// Retrieves Portal's curated default yield opportunities, keyed by `"{caip2}:{TOKEN}"`.
  /// - Parameter includeOpportunities: When `true`, the backend enriches each entry with the live opportunity.
  /// - Returns: A `YieldXyzGetDefaultsResponse` whose `data` maps chain+token keys to default yields.
  /// - Throws: An error if the operation fails.
  public func getYieldDefaults(includeOpportunities: Bool? = nil) async throws -> YieldXyzGetDefaultsResponse {
    var queryParams: [String] = []
    addParam("includeOpportunities", includeOpportunities, to: &queryParams)

    let queryString = queryParams.isEmpty ? "" : "?\(queryParams.joined(separator: "&"))"

    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/yield-xyz/yields/defaults\(queryString)") else {
      logger.error("PortalYieldXyzApi.getYieldDefaults() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await get(url, mappingInResponse: YieldXyzGetDefaultsResponse.self)
    } catch {
      logger.error("PortalYieldXyzApi.getYieldDefaults() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Retrieves available validators for a native-staking yield.
  /// - Parameter yieldId: The yield identifier.
  /// - Returns: A `YieldXyzGetValidatorsResponse` containing validators.
  /// - Throws: An error if the operation fails.
  public func getYieldValidators(yieldId: String) async throws -> YieldXyzGetValidatorsResponse {
    // Encode as a single path segment (exclude `/` which `.urlPathAllowed` still permits).
    var pathSegmentAllowed = CharacterSet.urlPathAllowed
    pathSegmentAllowed.remove(charactersIn: "/")
    let encodedYieldId = yieldId.addingPercentEncoding(withAllowedCharacters: pathSegmentAllowed) ?? yieldId

    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/yield-xyz/yields/\(encodedYieldId)/validators") else {
      logger.error("PortalYieldXyzApi.getYieldValidators() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await get(url, mappingInResponse: YieldXyzGetValidatorsResponse.self)
    } catch {
      logger.error("PortalYieldXyzApi.getYieldValidators() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /*******************************************
   * Private functions
   *******************************************/

  // Helper function to add query parameters
  private func addParam(_ key: String, _ value: Any?, to queryParams: inout [String]) {
    guard let value = value else { return }
    let stringValue = "\(value)"
    if let encoded = stringValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
      queryParams.append("\(key)=\(encoded)")
    }
  }

  @discardableResult
  private func get<ResponseType>(
    _ url: URL,
    mappingInResponse: ResponseType.Type
  ) async throws -> ResponseType where ResponseType: Decodable {
    // Resolved here, at the moment the request is built, so a rotated session is sent on the
    // next call and a dead one fails before anything reaches the wire.
    let token = try resolveCredentialToken(self.credentials)
    let portalRequest = PortalAPIRequest(url: url, bearerToken: token)
    return try await requests.execute(request: portalRequest, mappingInResponse: mappingInResponse.self)
  }

  @discardableResult
  private func post<ResponseType>(
    _ url: URL,
    andPayload: Codable? = nil,
    mappingInResponse: ResponseType.Type
  ) async throws -> ResponseType where ResponseType: Decodable {
    // Resolved here, at the moment the request is built, so a rotated session is sent on the
    // next call and a dead one fails before anything reaches the wire.
    let token = try resolveCredentialToken(self.credentials)
    let portalRequest = PortalAPIRequest(url: url, method: .post, payload: andPayload, bearerToken: token)
    return try await requests.execute(request: portalRequest, mappingInResponse: mappingInResponse.self)
  }

  @discardableResult
  private func put<ResponseType>(
    _ url: URL,
    andPayload: Codable,
    mappingInResponse: ResponseType.Type
  ) async throws -> ResponseType where ResponseType: Decodable {
    // Resolved here, at the moment the request is built, so a rotated session is sent on the
    // next call and a dead one fails before anything reaches the wire.
    let token = try resolveCredentialToken(self.credentials)
    let portalRequest = PortalAPIRequest(url: url, method: .put, payload: andPayload, bearerToken: token)
    return try await requests.execute(request: portalRequest, mappingInResponse: mappingInResponse.self)
  }
}
