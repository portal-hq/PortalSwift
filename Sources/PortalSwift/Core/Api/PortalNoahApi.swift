//
//  PortalNoahApi.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Protocol describing the Noah on/off-ramp API surface.
public protocol PortalNoahApiProtocol: AnyObject {
  func initiateKyc(request: NoahInitiateKycRequest) async throws -> NoahInitiateKycResponse
  func initiatePayin(request: NoahInitiatePayinRequest) async throws -> NoahInitiatePayinResponse
  func simulatePayin(request: NoahSimulatePayinRequest) async throws -> NoahSimulatePayinResponse
  func getPaymentMethods(request: NoahGetPaymentMethodsRequest) async throws -> NoahGetPaymentMethodsResponse
  func getPayoutCountries() async throws -> NoahGetPayoutCountriesResponse
  func getPayoutChannels(request: NoahGetPayoutChannelsRequest) async throws -> NoahGetPayoutChannelsResponse
  func getPayoutChannelForm(channelId: String) async throws -> NoahGetPayoutChannelFormResponse
  func getPayoutQuote(request: NoahGetPayoutQuoteRequest) async throws -> NoahGetPayoutQuoteResponse
  func initiatePayout(request: NoahInitiatePayoutRequest) async throws -> NoahInitiatePayoutResponse
}

public extension PortalNoahApiProtocol {
  /// Convenience overload for `getPaymentMethods` using default request values.
  func getPaymentMethods() async throws -> NoahGetPaymentMethodsResponse {
    try await getPaymentMethods(request: NoahGetPaymentMethodsRequest())
  }
}

/// API class for the Noah on/off-ramp integration.
///
/// Mirrors the React Native `PortalNoahApi` HTTP surface. All endpoints sit
/// under `/api/v3/clients/me/integrations/noah/*` and require the client API
/// key as a bearer token.
public class PortalNoahApi: PortalNoahApiProtocol {
  private let apiKey: String
  private let baseUrl: String
  private let requests: PortalRequestsProtocol
  private let logger = PortalLogger.shared

  private static let basePath = "/api/v3/clients/me/integrations/noah"

  /// Create an instance of `PortalNoahApi`.
  /// - Parameters:
  ///   - apiKey: The Portal Client API key.
  ///   - apiHost: The Portal API hostname.
  ///   - requests: An instance of `PortalRequestsProtocol` used to perform HTTP requests.
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

  /// Start a Noah KYC flow for the current client.
  public func initiateKyc(request: NoahInitiateKycRequest) async throws -> NoahInitiateKycResponse {
    guard let url = URL(string: "\(baseUrl)\(Self.basePath)/customers/kyc") else {
      logger.error("PortalNoahApi.initiateKyc() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: NoahInitiateKycResponse.self)
    } catch {
      logger.error("PortalNoahApi.initiateKyc() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Initiate a Noah payin (on-ramp) and receive bank deposit instructions.
  public func initiatePayin(request: NoahInitiatePayinRequest) async throws -> NoahInitiatePayinResponse {
    guard let url = URL(string: "\(baseUrl)\(Self.basePath)/payins") else {
      logger.error("PortalNoahApi.initiatePayin() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: NoahInitiatePayinResponse.self)
    } catch {
      logger.error("PortalNoahApi.initiatePayin() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Simulate a Noah payin (sandbox-only fiat deposit).
  public func simulatePayin(request: NoahSimulatePayinRequest) async throws -> NoahSimulatePayinResponse {
    guard let url = URL(string: "\(baseUrl)\(Self.basePath)/payins/simulate") else {
      logger.error("PortalNoahApi.simulatePayin() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: NoahSimulatePayinResponse.self)
    } catch {
      logger.error("PortalNoahApi.simulatePayin() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// List stored Noah payment methods for the current client.
  public func getPaymentMethods(request: NoahGetPaymentMethodsRequest) async throws -> NoahGetPaymentMethodsResponse {
    var queryParams: [String] = []
    addParam("pageSize", request.pageSize, to: &queryParams)
    addParam("pageToken", request.pageToken, to: &queryParams)
    addParam("capability", request.capability?.rawValue, to: &queryParams)

    let queryString = queryParams.isEmpty ? "" : "?\(queryParams.joined(separator: "&"))"

    guard let url = URL(string: "\(baseUrl)\(Self.basePath)/payouts/payment-methods\(queryString)") else {
      logger.error("PortalNoahApi.getPaymentMethods() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await get(url, withBearerToken: apiKey, mappingInResponse: NoahGetPaymentMethodsResponse.self)
    } catch {
      logger.error("PortalNoahApi.getPaymentMethods() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// List the countries and fiat currencies supported for Noah payouts.
  public func getPayoutCountries() async throws -> NoahGetPayoutCountriesResponse {
    guard let url = URL(string: "\(baseUrl)\(Self.basePath)/payouts/countries") else {
      logger.error("PortalNoahApi.getPayoutCountries() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await get(url, withBearerToken: apiKey, mappingInResponse: NoahGetPayoutCountriesResponse.self)
    } catch {
      logger.error("PortalNoahApi.getPayoutCountries() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// List Noah payout channels matching the supplied filters.
  public func getPayoutChannels(request: NoahGetPayoutChannelsRequest) async throws -> NoahGetPayoutChannelsResponse {
    var queryParams: [String] = []
    addParam("cryptoCurrency", request.cryptoCurrency, to: &queryParams)
    addParam("country", request.country, to: &queryParams)
    addParam("fiatCurrency", request.fiatCurrency, to: &queryParams)
    addParam("fiatAmount", request.fiatAmount, to: &queryParams)
    addParam("paymentMethodId", request.paymentMethodId, to: &queryParams)
    addParam("pageSize", request.pageSize, to: &queryParams)
    addParam("pageToken", request.pageToken, to: &queryParams)

    let queryString = queryParams.isEmpty ? "" : "?\(queryParams.joined(separator: "&"))"

    guard let url = URL(string: "\(baseUrl)\(Self.basePath)/payouts/channels\(queryString)") else {
      logger.error("PortalNoahApi.getPayoutChannels() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await get(url, withBearerToken: apiKey, mappingInResponse: NoahGetPayoutChannelsResponse.self)
    } catch {
      logger.error("PortalNoahApi.getPayoutChannels() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Fetch the dynamic form schema for the given Noah payout channel.
  public func getPayoutChannelForm(channelId: String) async throws -> NoahGetPayoutChannelFormResponse {
    // Encode as a single path segment. Both `.urlPathAllowed` and
    // `URL.appendingPathComponent` leave `/` unescaped, which would alter the
    // request path (path injection). Strip `/` from the allowed set so it is
    // percent-encoded.
    var allowed = CharacterSet.urlPathAllowed
    allowed.remove(charactersIn: "/")
    guard let encodedChannelId = channelId.addingPercentEncoding(withAllowedCharacters: allowed) else {
      logger.error("PortalNoahApi.getPayoutChannelForm() - Unable to percent-encode channelId.")
      throw PortalApiError.unableToEncodeData
    }

    guard let url = URL(string: "\(baseUrl)\(Self.basePath)/payouts/channels/\(encodedChannelId)/form") else {
      logger.error("PortalNoahApi.getPayoutChannelForm() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await get(url, withBearerToken: apiKey, mappingInResponse: NoahGetPayoutChannelFormResponse.self)
    } catch {
      logger.error("PortalNoahApi.getPayoutChannelForm() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Request a Noah payout quote for the given channel and form responses.
  public func getPayoutQuote(request: NoahGetPayoutQuoteRequest) async throws -> NoahGetPayoutQuoteResponse {
    guard let url = URL(string: "\(baseUrl)\(Self.basePath)/payouts/quote") else {
      logger.error("PortalNoahApi.getPayoutQuote() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: NoahGetPayoutQuoteResponse.self)
    } catch {
      logger.error("PortalNoahApi.getPayoutQuote() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Initiate a Noah payout from a previously quoted payout.
  public func initiatePayout(request: NoahInitiatePayoutRequest) async throws -> NoahInitiatePayoutResponse {
    guard let url = URL(string: "\(baseUrl)\(Self.basePath)/payouts") else {
      logger.error("PortalNoahApi.initiatePayout() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await post(url, withBearerToken: apiKey, andPayload: request, mappingInResponse: NoahInitiatePayoutResponse.self)
    } catch {
      logger.error("PortalNoahApi.initiatePayout() - Error: \(error.localizedDescription)")
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
