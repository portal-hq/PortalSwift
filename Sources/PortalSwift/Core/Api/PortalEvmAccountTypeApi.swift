//
//  PortalEvmAccountTypeApi.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Protocol for EVM Account Type API interactions.
public protocol PortalEvmAccountTypeApiProtocol: AnyObject {
  /// Retrieves the account type for the client's wallet on the given chain.
  /// - Parameter chainId: CAIP-2 chain ID (e.g., "eip155:11155111")
  /// - Returns: Response containing account type status and metadata
  func getStatus(chainId: String, traceId: String?) async throws -> EvmAccountTypeResponse

  /// Builds the authorization list hash for EIP-7702 upgrade.
  /// - Parameters:
  ///   - chainId: CAIP-2 chain ID
  ///   - subsidize: When `true`, the API submits the transaction on-chain and returns the hash in `data.transactionHash`.
  ///   - traceId: Optional trace ID forwarded as the `X-Portal-Trace-Id` header.
  /// - Returns: Response containing the hash to sign
  func buildAuthorizationList(chainId: String, subsidize: Bool?, traceId: String?) async throws -> BuildAuthorizationListResponse

  /// Builds the authorization transaction from the signature.
  /// - Parameters:
  ///   - chainId: CAIP-2 chain ID
  ///   - signature: The raw signature (without 0x prefix) from signing the authorization list hash
  ///   - subsidize: When `true`, the API submits the transaction on-chain and returns the hash in `data.transactionHash`.
  ///   - traceId: Optional trace ID forwarded as the `X-Portal-Trace-Id` header.
  /// - Returns: Response containing the EIP-7702 transaction and, when subsidized, the on-chain transaction hash.
  func buildAuthorizationTransaction(chainId: String, signature: String, subsidize: Bool?, traceId: String?) async throws -> BuildAuthorizationTransactionResponse
}

/// Backward-compatible convenience overloads.
///
/// The requirements carry an optional `traceId` so `EvmAccountType.upgradeTo7702` can share a
/// single `X-Portal-Trace-Id` across its requests. These overloads preserve the original call
/// shapes (without `traceId`) so existing callers of `PortalEvmAccountTypeApiProtocol` continue
/// to compile unchanged.
public extension PortalEvmAccountTypeApiProtocol {
  func getStatus(chainId: String) async throws -> EvmAccountTypeResponse {
    try await getStatus(chainId: chainId, traceId: nil)
  }

  func buildAuthorizationList(chainId: String, subsidize: Bool? = nil) async throws -> BuildAuthorizationListResponse {
    try await buildAuthorizationList(chainId: chainId, subsidize: subsidize, traceId: nil)
  }

  func buildAuthorizationTransaction(chainId: String, signature: String, subsidize: Bool? = nil) async throws -> BuildAuthorizationTransactionResponse {
    try await buildAuthorizationTransaction(chainId: chainId, signature: signature, subsidize: subsidize, traceId: nil)
  }
}

/// API class for EVM Account Type integration functionality.
public class PortalEvmAccountTypeApi: PortalEvmAccountTypeApiProtocol {
  /// Resolved per request and never cached, so a session rotated or invalidated underneath
  /// this instance is honoured on the next call. Shared by identity with the owning `PortalApi`.
  private let credentials: PortalCredentials
  private let baseUrl: String
  private let requests: PortalRequestsProtocol
  private let logger = PortalLogger.shared

  // MARK: - Private Body Structs

  private struct EmptyBody: Codable {}

  /// Create an instance of PortalEvmAccountTypeApi.
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

    installUnauthorizedHook(on: self.requests, for: credentials, context: "PortalEvmAccountTypeApi")
  }

  /// Create an instance of PortalEvmAccountTypeApi.
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

  // MARK: - Public functions

  /// Retrieves the account type for the client's wallet on the given chain.
  ///
  /// - Parameter chainId: CAIP-2 chain ID (e.g., "eip155:11155111")
  /// - Returns: Response containing data.status ("SMART_CONTRACT", "EIP_155_EOA", "EIP_7702_EOA") and metadata (chainId, eoaAddress, smartContractAddress)
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func getStatus(chainId: String, traceId: String? = nil) async throws -> EvmAccountTypeResponse {
    let traceId = traceId ?? generateTraceId()
    guard let encodedChain = chainId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
          let url = URL(string: "\(baseUrl)/api/v3/clients/me/chains/\(encodedChain)/wallet/account-type")
    else {
      logger.error("PortalEvmAccountTypeApi.getStatus() - Unable to build request URL.")
      throw URLError(.badURL)
    }
    do {
      return try await get(url, traceId: traceId, mappingInResponse: EvmAccountTypeResponse.self)
    } catch {
      logger.error("PortalEvmAccountTypeApi.getStatus() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Builds the authorization list hash for EIP-7702 upgrade.
  ///
  /// - Parameters:
  ///   - chainId: CAIP-2 chain ID
  ///   - subsidize: When `true`, the API submits the transaction on-chain and returns the transaction hash in `data.transactionHash`. Defaults to `nil`.
  /// - Returns: Response containing data.hash (hex string with 0x prefix)
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func buildAuthorizationList(chainId: String, subsidize: Bool? = nil, traceId: String? = nil) async throws -> BuildAuthorizationListResponse {
    let traceId = traceId ?? generateTraceId()
    guard let encodedChain = chainId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
          let url = URL(string: "\(baseUrl)/api/v3/clients/me/chains/\(encodedChain)/wallet/build-authorization-list")
    else {
      logger.error("PortalEvmAccountTypeApi.buildAuthorizationList() - Unable to build request URL.")
      throw URLError(.badURL)
    }
    do {
      let body = BuildAuthorizationListRequest(subsidize: subsidize)
      return try await post(url, andPayload: body, traceId: traceId, mappingInResponse: BuildAuthorizationListResponse.self)
    } catch {
      logger.error("PortalEvmAccountTypeApi.buildAuthorizationList() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Builds the authorization transaction from the signature.
  ///
  /// - Parameters:
  ///   - chainId: CAIP-2 chain ID
  ///   - signature: The raw signature (without 0x prefix) from signing the authorization list hash
  ///   - subsidize: When `true`, the API submits the transaction on-chain and returns the transaction hash in `data.transactionHash`. Defaults to `nil`.
  /// - Returns: Response containing `data.transaction` (the EIP-7702 transaction) and, when subsidized, `data.transactionHash` (the on-chain transaction hash).
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func buildAuthorizationTransaction(chainId: String, signature: String, subsidize: Bool? = nil, traceId: String? = nil) async throws -> BuildAuthorizationTransactionResponse {
    let traceId = traceId ?? generateTraceId()
    guard let encodedChain = chainId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
          let url = URL(string: "\(baseUrl)/api/v3/clients/me/chains/\(encodedChain)/wallet/build-authorization-transaction")
    else {
      logger.error("PortalEvmAccountTypeApi.buildAuthorizationTransaction() - Unable to build request URL.")
      throw URLError(.badURL)
    }
    do {
      let body = BuildAuthorizationTransactionRequest(signature: signature, subsidize: subsidize)
      return try await post(url, andPayload: body, traceId: traceId, mappingInResponse: BuildAuthorizationTransactionResponse.self)
    } catch {
      logger.error("PortalEvmAccountTypeApi.buildAuthorizationTransaction() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  // MARK: - Private functions

  @discardableResult
  private func post<ResponseType>(
    _ url: URL,
    andPayload: Codable? = nil,
    traceId: String? = nil,
    mappingInResponse: ResponseType.Type
  ) async throws -> ResponseType where ResponseType: Decodable {
    // Resolved here, at the moment the request is built, so a rotated session is sent on the
    // next call and a dead one fails before anything reaches the wire.
    let token = try resolveCredentialToken(self.credentials)
    let portalRequest = PortalAPIRequest(url: url, method: .post, payload: andPayload, bearerToken: token, traceId: traceId)
    return try await requests.execute(request: portalRequest, mappingInResponse: mappingInResponse.self)
  }

  private func get<ResponseType>(
    _ url: URL,
    traceId: String? = nil,
    mappingInResponse: ResponseType.Type
  ) async throws -> ResponseType where ResponseType: Decodable {
    // Resolved here, at the moment the request is built, so a rotated session is sent on the
    // next call and a dead one fails before anything reaches the wire.
    let token = try resolveCredentialToken(self.credentials)
    let portalRequest = PortalAPIRequest(url: url, bearerToken: token, traceId: traceId)
    return try await requests.execute(request: portalRequest, mappingInResponse: mappingInResponse.self)
  }
}
