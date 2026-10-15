//
//  PortalYieldXyzBorrowApi.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Protocol describing the Yield.xyz Borrow API surface.
public protocol PortalYieldXyzBorrowApiProtocol: AnyObject {
  func getHealth() async throws -> YieldXyzBorrowGetHealthResponse
  func getIntegrations() async throws -> YieldXyzBorrowGetIntegrationsResponse
  func getIntegration(integrationId: String) async throws -> YieldXyzBorrowGetIntegrationResponse
  func getMarkets(params: YieldXyzBorrowGetMarketsParams) async throws -> YieldXyzBorrowGetMarketsResponse
  func getMarket(marketId: String) async throws -> YieldXyzBorrowGetMarketResponse
  func getPositions(params: YieldXyzBorrowGetPositionsParams) async throws -> YieldXyzBorrowGetPositionsResponse
  func getLiquidations(params: YieldXyzBorrowGetLiquidationsParams) async throws -> YieldXyzBorrowGetLiquidationsResponse
  func createAction(params: YieldXyzBorrowCreateActionParams) async throws -> YieldXyzBorrowActionResponse
  func getActions(params: YieldXyzBorrowGetActionsParams) async throws -> YieldXyzBorrowGetActionsResponse
  func getAction(actionId: String) async throws -> YieldXyzBorrowActionResponse
  func stepAction(actionId: String) async throws -> YieldXyzBorrowActionResponse
  func submitTransaction(transactionId: String, params: YieldXyzBorrowSubmitTransactionParams) async throws -> YieldXyzBorrowSubmitTransactionResponse
}

public extension PortalYieldXyzBorrowApiProtocol {
  /// Convenience overload of `getMarkets` without filters.
  func getMarkets() async throws -> YieldXyzBorrowGetMarketsResponse {
    try await getMarkets(params: YieldXyzBorrowGetMarketsParams())
  }
}

/// API class for the Yield.xyz Borrow integration.
///
/// Mirrors the React Native `PortalYieldXyzBorrowApi` HTTP surface. All endpoints sit under
/// `/api/v3/clients/me/integrations/yield-xyz-borrow/*`, require the client credential as a bearer
/// token, and return `{ "data": ... }`. Failures are thrown as the transport reports them
/// (`PortalRequestsError`); read the Portal error `id` and `details` with
/// `YieldXyzBorrowApiError.from(_:)`.
public class PortalYieldXyzBorrowApi: PortalYieldXyzBorrowApiProtocol, YieldXyzEvmTransactionLookupProviding {
  /// Resolved per request and never cached, so a session rotated or invalidated underneath
  /// this instance is honoured on the next call. Shared by identity with the owning `PortalApi`.
  private let credentials: PortalCredentials
  private let requests: PortalRequestsProtocol
  private let requestBuilder: YieldXyzRequestBuilder
  private let logger = PortalLogger.shared

  /// Create an instance of `PortalYieldXyzBorrowApi`.
  ///
  /// The credential is resolved again on every request and never at construction, so a session
  /// that rotates or is invalidated underneath this instance takes effect on the next call. The
  /// transport's 401 hook is wired to `credentials` only when the transport reports 401s and has
  /// no hook yet, and the `apiHost` is registered as Portal-owned (`PortalOwnedHosts`) so the hook
  /// and the trace header apply to it.
  /// - Parameters:
  ///   - credentials: The credential presented as the bearer on every request: a `StaticCredentials`
  ///     wrapping a Client API Key, or a session obtained through `PortalAuth`.
  ///   - apiHost: The Portal API hostname.
  ///   - requests: An instance of `PortalRequestsProtocol` used to perform HTTP requests.
  public init(
    credentials: PortalCredentials,
    apiHost: String = "api.portalhq.io",
    requests: PortalRequestsProtocol? = nil
  ) {
    self.credentials = credentials
    self.requestBuilder = YieldXyzRequestBuilder(
      baseUrl: apiHost.starts(with: "localhost") ? "http://\(apiHost)" : "https://\(apiHost)",
      basePath: "/api/v3/clients/me/integrations/yield-xyz-borrow",
      emptyIdentifier: { YieldXyzBorrowError.emptyIdentifier(name: $0) }
    )
    self.requests = requests ?? PortalRequests()
    PortalOwnedHosts.register(apiHost)

    PortalCredentialSupport.installUnauthorizedHook(on: self.requests, for: credentials, context: "PortalYieldXyzBorrowApi")
  }

  /// Create an instance of `PortalYieldXyzBorrowApi`.
  ///
  /// Kept as a convenience; the key is wrapped in `StaticCredentials` and everything else follows
  /// the credentials path. A blank key fails on first use with `PortalCredentialError.unavailable`.
  /// - Parameters:
  ///   - apiKey: The Portal Client API key.
  ///   - apiHost: The Portal API hostname.
  ///   - requests: An instance of `PortalRequestsProtocol` used to perform HTTP requests.
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

  /// Get the Yield.xyz Borrow API health.
  public func getHealth() async throws -> YieldXyzBorrowGetHealthResponse {
    try await get("getHealth", path: "/health")
  }

  /// List the lending integrations (Aave, Morpho Blue, …) and the actions each supports.
  public func getIntegrations() async throws -> YieldXyzBorrowGetIntegrationsResponse {
    try await get("getIntegrations", path: "/integrations")
  }

  /// Get one integration, with the schema of each action's `args`.
  public func getIntegration(integrationId: String) async throws -> YieldXyzBorrowGetIntegrationResponse {
    try await get("getIntegration", path: "/integrations/\(pathSegment("integrationId", integrationId))")
  }

  /// List lending markets, optionally filtered by integration and chain.
  public func getMarkets(params: YieldXyzBorrowGetMarketsParams) async throws -> YieldXyzBorrowGetMarketsResponse {
    try await get("getMarkets", path: "/markets", query: [
      ("offset", params.offset.map(String.init)),
      ("limit", params.limit.map(String.init)),
      ("integrationId", params.integrationId),
      ("network", params.network),
      ("scope", params.scope?.rawValue)
    ])
  }

  /// Get one market.
  public func getMarket(marketId: String) async throws -> YieldXyzBorrowGetMarketResponse {
    try await get("getMarket", path: "/markets/\(pathSegment("marketId", marketId))")
  }

  /// Get an address's supply and borrow position on one integration and chain.
  public func getPositions(params: YieldXyzBorrowGetPositionsParams) async throws -> YieldXyzBorrowGetPositionsResponse {
    try await get("getPositions", path: "/positions", query: [
      ("integrationId", params.integrationId),
      ("network", params.network),
      ("address", params.address)
    ])
  }

  /// List an address's liquidations on one integration and chain.
  public func getLiquidations(params: YieldXyzBorrowGetLiquidationsParams) async throws -> YieldXyzBorrowGetLiquidationsResponse {
    try await get("getLiquidations", path: "/positions/liquidations", query: [
      ("offset", params.offset.map(String.init)),
      ("limit", params.limit.map(String.init)),
      ("integrationId", params.integrationId),
      ("network", params.network),
      ("address", params.address),
      ("marketId", params.marketId)
    ])
  }

  /// Build a lending action and return it with the unsigned transactions of its first step.
  public func createAction(params: YieldXyzBorrowCreateActionParams) async throws -> YieldXyzBorrowActionResponse {
    try await post("createAction", path: "/actions", payload: params)
  }

  /// List an address's actions.
  public func getActions(params: YieldXyzBorrowGetActionsParams) async throws -> YieldXyzBorrowGetActionsResponse {
    try await get("getActions", path: "/actions", query: [
      ("offset", params.offset.map(String.init)),
      ("limit", params.limit.map(String.init)),
      ("address", params.address),
      ("integrationId", params.integrationId),
      ("action", params.action?.rawValue),
      ("status", params.status?.rawValue),
      ("statuses", YieldXyzRequestBuilder.joined(params.statuses?.map(\.rawValue)))
    ])
  }

  /// Get one action with the transactions of its current step.
  public func getAction(actionId: String) async throws -> YieldXyzBorrowActionResponse {
    try await get("getAction", path: "/actions/\(pathSegment("actionId", actionId))")
  }

  /// Fetch the next step's transactions of a multi-step action, once the current step is confirmed
  /// and `hasNextStep` is `true`. The request has no body.
  public func stepAction(actionId: String) async throws -> YieldXyzBorrowActionResponse {
    try await post("stepAction", path: "/actions/\(pathSegment("actionId", actionId))/step", payload: nil)
  }

  /// Submit the hash of a broadcast transaction, or a signed payload, for one transaction. Empty
  /// values are not sent.
  public func submitTransaction(
    transactionId: String,
    params: YieldXyzBorrowSubmitTransactionParams
  ) async throws -> YieldXyzBorrowSubmitTransactionResponse {
    try await post(
      "submitTransaction",
      path: "/transactions/\(pathSegment("transactionId", transactionId))/submit",
      payload: YieldXyzBorrowSubmitTransactionBody(params)
    )
  }

  /*******************************************
   * Internal functions
   *******************************************/

  /// Reads back the transaction or user operation behind `hash` on the `eip155` chain `chainId`,
  /// decoding only the hashes and the user operation's outcome.
  func lookupEvmTransaction(chainId: String, hash: String) async throws -> YieldXyzEvmTransactionLookup? {
    do {
      guard let encodedChainId = YieldXyzRequestBuilder.encodeURIComponent(chainId),
            let encodedHash = YieldXyzRequestBuilder.encodeURIComponent(hash),
            let url = URL(string: "\(requestBuilder.baseUrl)/api/v3/clients/me/chains/\(encodedChainId)/transactions/\(encodedHash)")
      else {
        throw URLError(.badURL)
      }
      let token = try PortalCredentialSupport.resolveToken(self.credentials)
      let portalRequest = PortalAPIRequest(url: url, bearerToken: token)
      let body = try await requests.execute(request: portalRequest, mappingInResponse: YieldXyzEvmTransactionLookupBody.self)
      return body.data.map { data in
        YieldXyzEvmTransactionLookup(
          transactionHash: data.evmTransaction?.hash,
          userOperation: data.evmUserOperation.map {
            YieldXyzEvmTransactionLookup.UserOperation(success: $0.success, receiptTransactionHash: $0.receipt?.hash)
          }
        )
      }
    } catch {
      logger.debug("PortalYieldXyzBorrowApi.lookupEvmTransaction() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /*******************************************
   * Private functions
   *******************************************/

  /// Encodes an id as a single path segment; an empty id is rejected.
  private func pathSegment(_ name: String, _ value: String) throws -> String {
    try requestBuilder.pathSegment(name, value)
  }

  private func get<ResponseType: Decodable>(
    _ method: String,
    path: @autoclosure () throws -> String,
    query: [(String, String?)] = []
  ) async throws -> ResponseType {
    do {
      let url = try requestBuilder.makeUrl(path: path(), query: query)
      // Resolved here, at the moment the request is built, so a rotated session is sent on the
      // next call and a dead one fails before anything reaches the wire.
      let token = try PortalCredentialSupport.resolveToken(self.credentials)
      let portalRequest = PortalAPIRequest(url: url, bearerToken: token)
      return try await requests.execute(request: portalRequest, mappingInResponse: ResponseType.self)
    } catch {
      logger.error("PortalYieldXyzBorrowApi.\(method)() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// A `nil` payload sends a request without a body.
  private func post<ResponseType: Decodable>(
    _ method: String,
    path: @autoclosure () throws -> String,
    payload: Codable?
  ) async throws -> ResponseType {
    do {
      let url = try requestBuilder.makeUrl(path: path())
      let token = try PortalCredentialSupport.resolveToken(self.credentials)
      let portalRequest = PortalAPIRequest(url: url, method: .post, payload: payload, bearerToken: token)
      return try await requests.execute(request: portalRequest, mappingInResponse: ResponseType.self)
    } catch {
      logger.error("PortalYieldXyzBorrowApi.\(method)() - Error: \(error.localizedDescription)")
      throw error
    }
  }
}
