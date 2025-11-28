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
  private let apiKey: String
  private let baseUrl: String
  private let requests: PortalRequestsProtocol
  private let logger = PortalLogger()

  /// Create an instance of PortalLifiTradingApi.
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

  /// Retrieves routes from the Lifi integration.
  public func getRoutes(request: LifiRoutesRequest) async throws -> LifiRoutesResponse {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/lifi/routes") else {
      logger.error("PortalLifiTradingApi.getRoutes() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: LifiRoutesResponse.self)
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
      return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: LifiQuoteResponse.self)
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
      return try await get(url, withBearerToken: apiKey, mappingInResponse: LifiStatusResponse.self)
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
      return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: LifiStepTransactionResponse.self)
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
}
