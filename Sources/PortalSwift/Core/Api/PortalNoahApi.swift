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
  /// Resolved per request and never cached, so a session rotated or invalidated underneath
  /// this instance is honoured on the next call. Shared by identity with the owning `PortalApi`.
  private let credentials: PortalCredentials
  private let baseUrl: String
  private let requests: PortalRequestsProtocol
  private let logger = PortalLogger.shared

  private static let basePath = "/api/v3/clients/me/integrations/noah"

  /// Create an instance of `PortalNoahApi`.
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
  ///   - requests: An instance of `PortalRequestsProtocol` used to perform HTTP requests.
  public init(
    credentials: PortalCredentials,
    apiHost: String = "api.portalhq.io",
    requests: PortalRequestsProtocol? = nil
  ) {
    self.credentials = credentials
    self.baseUrl = apiHost.starts(with: "localhost") ? "http://\(apiHost)" : "https://\(apiHost)"
    self.requests = requests ?? PortalRequests()

    PortalCredentialSupport.installUnauthorizedHook(on: self.requests, for: credentials, context: "PortalNoahApi")
  }

  /// Create an instance of `PortalNoahApi`.
  ///
  /// Kept as a convenience so existing integrations compile unchanged; the key is wrapped in
  /// `StaticCredentials` and everything else follows the credentials path. A blank key is not
  /// rejected here because this initializer cannot throw: it fails on first use with
  /// `PortalCredentialError.unavailable` instead of sending an empty bearer.
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

  /// Start a Noah KYC flow for the current client.
  public func initiateKyc(request: NoahInitiateKycRequest) async throws -> NoahInitiateKycResponse {
    guard let url = URL(string: "\(baseUrl)\(Self.basePath)/customers/kyc") else {
      logger.error("PortalNoahApi.initiateKyc() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await post(url, andPayload: request, mappingInResponse: NoahInitiateKycResponse.self)
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
      return try await post(url, andPayload: request, mappingInResponse: NoahInitiatePayinResponse.self)
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
      return try await post(url, andPayload: request, mappingInResponse: NoahSimulatePayinResponse.self)
    } catch {
      logger.error("PortalNoahApi.simulatePayin() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// List stored Noah payment methods for the current client.
  public func getPaymentMethods(request: NoahGetPaymentMethodsRequest) async throws -> NoahGetPaymentMethodsResponse {
    guard let url = makeUrl(
      path: "\(Self.basePath)/payouts/payment-methods",
      queryItems: [
        queryItem("pageSize", request.pageSize),
        queryItem("pageToken", request.pageToken),
        queryItem("capability", request.capability?.rawValue)
      ]
    ) else {
      logger.error("PortalNoahApi.getPaymentMethods() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await get(url, mappingInResponse: NoahGetPaymentMethodsResponse.self)
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
      return try await get(url, mappingInResponse: NoahGetPayoutCountriesResponse.self)
    } catch {
      logger.error("PortalNoahApi.getPayoutCountries() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// List Noah payout channels matching the supplied filters.
  public func getPayoutChannels(request: NoahGetPayoutChannelsRequest) async throws -> NoahGetPayoutChannelsResponse {
    guard let url = makeUrl(
      path: "\(Self.basePath)/payouts/channels",
      queryItems: [
        queryItem("cryptoCurrency", request.cryptoCurrency),
        queryItem("country", request.country),
        queryItem("fiatCurrency", request.fiatCurrency),
        queryItem("fiatAmount", request.fiatAmount),
        queryItem("paymentMethodId", request.paymentMethodId),
        queryItem("pageSize", request.pageSize),
        queryItem("pageToken", request.pageToken)
      ]
    ) else {
      logger.error("PortalNoahApi.getPayoutChannels() - Unable to build request URL.")
      throw URLError(.badURL)
    }

    do {
      return try await get(url, mappingInResponse: NoahGetPayoutChannelsResponse.self)
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
      return try await get(url, mappingInResponse: NoahGetPayoutChannelFormResponse.self)
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
      return try await post(url, andPayload: request, mappingInResponse: NoahGetPayoutQuoteResponse.self)
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
      return try await post(url, andPayload: request, mappingInResponse: NoahInitiatePayoutResponse.self)
    } catch {
      logger.error("PortalNoahApi.initiatePayout() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /*******************************************
   * Private functions
   *******************************************/

  /// Builds a URL with correctly escaped query values via `URLComponents`.
  /// Prefer this over manual string joining + `.urlQueryAllowed`, which leaves
  /// reserved separators like `&` and `=` unescaped.
  private func makeUrl(path: String, queryItems: [URLQueryItem?] = []) -> URL? {
    guard var components = URLComponents(string: "\(baseUrl)\(path)") else {
      return nil
    }
    let items = queryItems.compactMap { $0 }
    if !items.isEmpty {
      components.queryItems = items
    }
    return components.url
  }

  private func queryItem(_ name: String, _ value: Any?) -> URLQueryItem? {
    guard let value else { return nil }
    return URLQueryItem(name: name, value: "\(value)")
  }

  @discardableResult
  private func get<ResponseType>(
    _ url: URL,
    mappingInResponse: ResponseType.Type
  ) async throws -> ResponseType where ResponseType: Decodable {
    // Resolved here, at the moment the request is built, so a rotated session is sent on the
    // next call and a dead one fails before anything reaches the wire.
    let token = try PortalCredentialSupport.resolveToken(self.credentials)
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
    let token = try PortalCredentialSupport.resolveToken(self.credentials)
    let portalRequest = PortalAPIRequest(url: url, method: .post, payload: andPayload, bearerToken: token)
    return try await requests.execute(request: portalRequest, mappingInResponse: mappingInResponse.self)
  }
}
