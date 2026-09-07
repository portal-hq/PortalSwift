//
//  PortalLifiTradingApi.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 23/11/2025.
//

import Foundation

/// Protocol of Lifi Trading API interactions.
public protocol PortalLifiTradingApiProtocol: AnyObject {
  func getRoutes(request: LifiRoutesRequest) async throws -> LifiRoutesResponse
  func getQuote(request: LifiQuoteRequest) async throws -> LifiQuoteResponse
  func getStatus(request: LifiStatusRequest) async throws -> LifiStatusResponse
  func getRouteStep(request: LifiStepTransactionRequest) async throws -> LifiStepTransactionResponse
}

/// API class specifically for Lifi Trading integration functionality.
public class PortalLifiTradingApi: PortalLifiTradingApiProtocol {
  /// Resolved per request and never cached, so a session rotated or invalidated underneath
  /// this instance is honoured on the next call. Shared by identity with the owning `PortalApi`.
  private let credentials: PortalCredentials
  private let baseUrl: String
  private let requests: PortalRequestsProtocol
  private let logger = PortalLogger.shared

  /// Create an instance of PortalLifiTradingApi.
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

    installUnauthorizedHook(on: self.requests, for: credentials, context: "PortalLifiTradingApi")
  }

  /// Create an instance of PortalLifiTradingApi.
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

  /// Retrieves routes from the Lifi integration.
  public func getRoutes(request: LifiRoutesRequest) async throws -> LifiRoutesResponse {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/lifi/routes") else {
      logger.error("PortalLifiTradingApi.getRoutes() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await post(url, andPayload: request, mappingInResponse: LifiRoutesResponse.self)
    } catch {
      logger.error("PortalLifiTradingApi.getRoutes() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Retrieves a quote from the Lifi integration.
  public func getQuote(request: LifiQuoteRequest) async throws -> LifiQuoteResponse {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/lifi/quote") else {
      logger.error("PortalLifiTradingApi.getQuote() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await post(url, andPayload: request, mappingInResponse: LifiQuoteResponse.self)
    } catch {
      logger.error("PortalLifiTradingApi.getQuote() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Retrieves the status of a transaction from the Lifi integration.
  public func getStatus(request: LifiStatusRequest) async throws -> LifiStatusResponse {
    var queryParams: [String] = []
    addParam("fromChain", request.fromChain, to: &queryParams)
    addParam("txHash", request.txHash, to: &queryParams)
    addParam("bridge", request.bridge, to: &queryParams)
    addParam("toChain", request.toChain, to: &queryParams)

    let queryString = queryParams.isEmpty ? "" : "?\(queryParams.joined(separator: "&"))"

    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/lifi/status\(queryString)") else {
      logger.error("PortalLifiTradingApi.getStatus() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await get(url, mappingInResponse: LifiStatusResponse.self)
    } catch {
      logger.error("PortalLifiTradingApi.getStatus() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Retrieves an unsigned transaction from the Lifi integration that has yet to be signed/submitted.
  public func getRouteStep(request: LifiStepTransactionRequest) async throws -> LifiStepTransactionResponse {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/lifi/route-step-details") else {
      logger.error("PortalLifiTradingApi.getRouteStep() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await post(url, andPayload: request, mappingInResponse: LifiStepTransactionResponse.self)
    } catch {
      logger.error("PortalLifiTradingApi.getRouteStep() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /*******************************************
   * Private functions
   *******************************************/

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
}
