//
//  PortalSwapLifiApi.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 23/11/2025.
//

import Foundation

/// Protocol of Lifi Swap API interactions.
public protocol PortalSwapLifiApiProtocol: AnyObject {
  func getRoutes(request: LifiRoutesRequest) async throws -> LifiRoutesResponse
  func getQuote(request: LifiQuoteRequest) async throws -> LifiQuoteResponse
  func getStatus(request: LifiStatusRequest) async throws -> LifiStatusResponse
  func stepTransaction(request: LifiStepTransactionRequest) async throws -> LifiStepTransactionResponse
}

/// API class specifically for Lifi Swap integration functionality.
public class PortalSwapLifiApi: PortalSwapLifiApiProtocol {
  private let apiKey: String
  private let baseUrl: String
  private let requests: PortalRequestsProtocol
  private let logger = PortalLogger()

  /// Create an instance of PortalSwapLifiApi.
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
      logger.error("PortalSwapLifiApi.getRoutes() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: LifiRoutesResponse.self)
    } catch {
      logger.error("PortalSwapLifiApi.getRoutes() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Retrieves a quote from the Lifi integration.
  public func getQuote(request: LifiQuoteRequest) async throws -> LifiQuoteResponse {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/lifi/quote") else {
      logger.error("PortalSwapLifiApi.getQuote() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: LifiQuoteResponse.self)
    } catch {
      logger.error("PortalSwapLifiApi.getQuote() - Error: \(error.localizedDescription)")
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
      logger.error("PortalSwapLifiApi.getStatus() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await get(url, withBearerToken: apiKey, mappingInResponse: LifiStatusResponse.self)
    } catch {
      logger.error("PortalSwapLifiApi.getStatus() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Submits step transaction details to the Lifi integration.
  public func stepTransaction(request: LifiStepTransactionRequest) async throws -> LifiStepTransactionResponse {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/integrations/lifi/step-details") else {
      logger.error("PortalSwapLifiApi.stepTransaction() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: LifiStepTransactionResponse.self)
    } catch {
      logger.error("PortalSwapLifiApi.stepTransaction() - Error: \(error.localizedDescription)")
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
