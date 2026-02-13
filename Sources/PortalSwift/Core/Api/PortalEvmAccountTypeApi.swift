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
  func getStatus(chainId: String) async throws -> EvmAccountTypeResponse

  /// Builds the authorization list hash for EIP-7702 upgrade.
  /// - Parameter chainId: CAIP-2 chain ID
  /// - Returns: Response containing the hash to sign
  func buildAuthorizationList(chainId: String) async throws -> BuildAuthorizationListResponse

  /// Builds the authorization transaction from the signature.
  /// - Parameters:
  ///   - chainId: CAIP-2 chain ID
  ///   - signature: The raw signature (without 0x prefix) from signing the authorization list hash
  ///   - subsidize: When `true`, the API submits the transaction on-chain and returns the hash in `data.transactionHash`.
  /// - Returns: Response containing the EIP-7702 transaction and, when subsidized, the on-chain transaction hash.
  func buildAuthorizationTransaction(chainId: String, signature: String, subsidize: Bool?) async throws -> BuildAuthorizationTransactionResponse
}

/// API class for EVM Account Type integration functionality.
public class PortalEvmAccountTypeApi: PortalEvmAccountTypeApiProtocol {
  private let apiKey: String
  private let baseUrl: String
  private let requests: PortalRequestsProtocol
  private let logger = PortalLogger()

  // MARK: - Private Body Structs

  private struct EmptyBody: Codable {}

  /// Create an instance of PortalEvmAccountTypeApi.
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

  // MARK: - Public functions

  /// Retrieves the account type for the client's wallet on the given chain.
  ///
  /// - Parameter chainId: CAIP-2 chain ID (e.g., "eip155:11155111")
  /// - Returns: Response containing data.status ("SMART_CONTRACT", "EIP_155_EOA", "EIP_7702_EOA") and metadata (chainId, eoaAddress, smartContractAddress)
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func getStatus(chainId: String) async throws -> EvmAccountTypeResponse {
    guard let encodedChain = chainId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
          let url = URL(string: "\(baseUrl)/api/v3/clients/me/chains/\(encodedChain)/wallet/account-type")
    else {
      logger.error("PortalEvmAccountTypeApi.getStatus() - Unable to build request URL.")
      throw URLError(.badURL)
    }
    do {
      return try await get(url, withBearerToken: apiKey, mappingInResponse: EvmAccountTypeResponse.self)
    } catch {
      logger.error("PortalEvmAccountTypeApi.getStatus() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Builds the authorization list hash for EIP-7702 upgrade.
  ///
  /// - Parameter chainId: CAIP-2 chain ID
  /// - Returns: Response containing data.hash (hex string with 0x prefix)
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func buildAuthorizationList(chainId: String) async throws -> BuildAuthorizationListResponse {
    guard let encodedChain = chainId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
          let url = URL(string: "\(baseUrl)/api/v3/clients/me/chains/\(encodedChain)/wallet/build-authorization-list")
    else {
      logger.error("PortalEvmAccountTypeApi.buildAuthorizationList() - Unable to build request URL.")
      throw URLError(.badURL)
    }
    do {
      let body = EmptyBody()
      return try await post(url, withBearerToken: apiKey, andPayload: body, mappingInResponse: BuildAuthorizationListResponse.self)
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
  public func buildAuthorizationTransaction(chainId: String, signature: String, subsidize: Bool? = nil) async throws -> BuildAuthorizationTransactionResponse {
    guard let encodedChain = chainId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
          let url = URL(string: "\(baseUrl)/api/v3/clients/me/chains/\(encodedChain)/wallet/build-authorization-transaction")
    else {
      logger.error("PortalEvmAccountTypeApi.buildAuthorizationTransaction() - Unable to build request URL.")
      throw URLError(.badURL)
    }
    do {
      let body = BuildAuthorizationTransactionRequest(signature: signature, subsidize: subsidize)
      return try await post(url, withBearerToken: apiKey, andPayload: body, mappingInResponse: BuildAuthorizationTransactionResponse.self)
    } catch {
      logger.error("PortalEvmAccountTypeApi.buildAuthorizationTransaction() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  // MARK: - Private functions

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

  private func get<ResponseType>(
    _ url: URL,
    withBearerToken: String? = nil,
    mappingInResponse: ResponseType.Type
  ) async throws -> ResponseType where ResponseType: Decodable {
    let portalRequest = PortalAPIRequest(url: url, bearerToken: withBearerToken)
    return try await requests.execute(request: portalRequest, mappingInResponse: mappingInResponse.self)
  }
}
