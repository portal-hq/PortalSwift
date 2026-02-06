//
//  PortalDelegationsApi.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Protocol for Delegations API interactions.
public protocol PortalDelegationsApiProtocol: AnyObject {
  /// Approves a delegation for a specified token on a given chain.
  /// Returns transactions for EVM chains or encodedTransactions for Solana chains.
  /// - Parameters:
  ///   - request: The approval request containing chain, token, delegateAddress, and amount
  /// - Returns: Response containing transaction data and metadata
  func approve(request: ApproveDelegationRequest) async throws -> ApproveDelegationResponse

  /// Revokes a delegation for a specified token on a given chain.
  /// Returns transactions for EVM chains or encodedTransactions for Solana chains.
  /// - Parameters:
  ///   - request: The revocation request containing chain, token, and delegateAddress
  /// - Returns: Response containing transaction data and metadata
  func revoke(request: RevokeDelegationRequest) async throws -> RevokeDelegationResponse

  /// Retrieves the delegation status for a specified token and delegate address.
  /// - Parameters:
  ///   - request: The status query containing chain, token, and delegateAddress
  /// - Returns: Response containing delegation status information
  func getStatus(request: GetDelegationStatusRequest) async throws -> DelegationStatusResponse

  /// Transfers tokens from one address to another using delegated authority.
  /// The caller must have been previously approved as a delegate.
  /// Returns transactions for EVM chains or encodedTransactions for Solana chains.
  /// - Parameters:
  ///   - request: The transfer request containing chain, token, fromAddress, toAddress, and amount
  /// - Returns: Response containing transaction data and metadata
  func transferFrom(request: TransferFromRequest) async throws -> TransferFromResponse
}

/// API class for Delegations integration functionality.
public class PortalDelegationsApi: PortalDelegationsApiProtocol {
  private let apiKey: String
  private let baseUrl: String
  private let requests: PortalRequestsProtocol
  private let logger = PortalLogger()

  // MARK: - Private Body Structs

  private struct ApproveDelegationBody: Codable {
    let delegateAddress: String
    let amount: String
  }

  private struct RevokeDelegationBody: Codable {
    let delegateAddress: String
  }

  private struct TransferFromBody: Codable {
    let fromAddress: String
    let toAddress: String
    let amount: String
  }

  /// Create an instance of PortalDelegationsApi.
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

  /// Approves a delegation for a specified token on a given chain.
  ///
  /// This method creates approval transactions that grant a delegate address the ability
  /// to transfer tokens on behalf of the owner. The endpoint returns unsigned transactions
  /// that must be signed sequentially.
  ///
  /// - For EVM chains: Returns `transactions` (array of ConstructedEipTransaction)
  /// - For Solana chains: Returns `encodedTransactions` (array of encoded transaction strings)
  ///
  /// - Parameter request: The approval request containing:
  ///   - `chain`: CAIP-2 chain ID (e.g., "eip155:11155111" or "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1")
  ///   - `token`: Token symbol (e.g., "USDC")
  ///   - `delegateAddress`: The address to delegate to
  ///   - `amount`: The amount to delegate (e.g., "1.0")
  /// - Returns: Response containing transaction data and approval metadata
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func approve(request: ApproveDelegationRequest) async throws -> ApproveDelegationResponse {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/chains/\(request.chain)/assets/\(request.token)/approvals") else {
      logger.error("PortalDelegationsApi.approve() - Unable to build request URL.")
      throw URLError(.badURL)
    }
    do {
      let body = ApproveDelegationBody(delegateAddress: request.delegateAddress, amount: request.amount)
      return try await post(url, withBearerToken: apiKey, andPayload: body, mappingInResponse: ApproveDelegationResponse.self)
    } catch {
      logger.error("PortalDelegationsApi.approve() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Revokes a delegation for a specified token on a given chain.
  ///
  /// This method creates revocation transactions that remove a delegate's ability to
  /// transfer tokens on behalf of the owner. The endpoint returns unsigned transactions
  /// that must be signed sequentially.
  ///
  /// - For EVM chains: Returns `transactions` (calls approve with amount 0)
  /// - For Solana chains: Returns `encodedTransactions` (Revoke instruction)
  ///
  /// - Parameter request: The revocation request containing:
  ///   - `chain`: CAIP-2 chain ID
  ///   - `token`: Token symbol
  ///   - `delegateAddress`: The address to revoke delegation from
  /// - Returns: Response containing transaction data and revocation metadata
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func revoke(request: RevokeDelegationRequest) async throws -> RevokeDelegationResponse {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/chains/\(request.chain)/assets/\(request.token)/revocations") else {
      logger.error("PortalDelegationsApi.revoke() - Unable to build request URL.")
      throw URLError(.badURL)
    }
    do {
      let body = RevokeDelegationBody(delegateAddress: request.delegateAddress)
      return try await post(url, withBearerToken: apiKey, andPayload: body, mappingInResponse: RevokeDelegationResponse.self)
    } catch {
      logger.error("PortalDelegationsApi.revoke() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Retrieves the delegation status for a specified token and delegate address.
  ///
  /// This method queries the current delegation state for a token, including balance
  /// information and active delegations with their allowed amounts.
  ///
  /// - Parameter request: The status query containing:
  ///   - `chain`: CAIP-2 chain ID
  ///   - `token`: Token symbol
  ///   - `delegateAddress`: The delegate address to query status for
  /// - Returns: Response containing chainId, token info, balance, and delegations array
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func getStatus(request: GetDelegationStatusRequest) async throws -> DelegationStatusResponse {
    var queryParams: [String] = []
    addParam("delegateAddress", request.delegateAddress, to: &queryParams)
    let queryString = queryParams.isEmpty ? "" : "?\(queryParams.joined(separator: "&"))"
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/chains/\(request.chain)/assets/\(request.token)/delegations\(queryString)") else {
      logger.error("PortalDelegationsApi.getStatus() - Unable to build request URL.")
      throw URLError(.badURL)
    }
    do {
      return try await get(url, withBearerToken: apiKey, mappingInResponse: DelegationStatusResponse.self)
    } catch {
      logger.error("PortalDelegationsApi.getStatus() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /// Transfers tokens from one address to another using delegated authority.
  ///
  /// This method creates transfer transactions that move tokens from an owner's account
  /// using previously approved delegation. The caller must have been approved as a delegate
  /// for the specified token and the transfer amount must not exceed the approved allowance.
  ///
  /// - For EVM chains: Returns `transactions` (transferFrom call)
  /// - For Solana chains: Returns `encodedTransactions` (TransferChecked with delegate)
  ///
  /// - Parameter request: The transfer request containing:
  ///   - `chain`: CAIP-2 chain ID
  ///   - `token`: Token symbol
  ///   - `fromAddress`: The owner's address (who approved the delegation)
  ///   - `toAddress`: The recipient's address
  ///   - `amount`: The amount to transfer (e.g., "1.0")
  /// - Returns: Response containing transaction data and transfer metadata (metadata is non-optional)
  /// - Throws: `URLError` if the URL cannot be constructed, or network/decoding errors if the request fails.
  public func transferFrom(request: TransferFromRequest) async throws -> TransferFromResponse {
    guard let url = URL(string: "\(baseUrl)/api/v3/clients/me/chains/\(request.chain)/assets/\(request.token)/delegations/transfers") else {
      logger.error("PortalDelegationsApi.transferFrom() - Unable to build request URL.")
      throw URLError(.badURL)
    }
    do {
      let body = TransferFromBody(fromAddress: request.fromAddress, toAddress: request.toAddress, amount: request.amount)
      return try await post(url, withBearerToken: apiKey, andPayload: body, mappingInResponse: TransferFromResponse.self)
    } catch {
      logger.error("PortalDelegationsApi.transferFrom() - Error: \(error.localizedDescription)")
      throw error
    }
  }

  /*******************************************
   * Private functions
   *******************************************/

  /// Performs a POST request to the specified URL with optional bearer token authentication and payload.
  ///
  /// - Parameters:
  ///   - url: The target URL for the request
  ///   - withBearerToken: Optional bearer token for authentication
  ///   - andPayload: Optional Codable payload to send in the request body
  ///   - mappingInResponse: The response type to decode the response into
  /// - Returns: Decoded response of the specified type
  /// - Throws: Network or decoding errors if the request fails
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

  /// Performs a GET request to the specified URL with optional bearer token authentication.
  ///
  /// - Parameters:
  ///   - url: The target URL for the request
  ///   - withBearerToken: Optional bearer token for authentication
  ///   - mappingInResponse: The response type to decode the response into
  /// - Returns: Decoded response of the specified type
  /// - Throws: Network or decoding errors if the request fails
  private func get<ResponseType>(
    _ url: URL,
    withBearerToken: String? = nil,
    mappingInResponse: ResponseType.Type
  ) async throws -> ResponseType where ResponseType: Decodable {
    let portalRequest = PortalAPIRequest(url: url, bearerToken: withBearerToken)
    return try await requests.execute(request: portalRequest, mappingInResponse: mappingInResponse.self)
  }

  /// Adds a percent-encoded query parameter to the array.
  ///
  /// - Parameters:
  ///   - key: The parameter key
  ///   - value: The parameter value (skipped if nil)
  ///   - queryParams: The array to append the parameter to
  private func addParam(_ key: String, _ value: Any?, to queryParams: inout [String]) {
    guard let value = value else { return }
    let stringValue = "\(value)"
    if let encoded = stringValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
      queryParams.append("\(key)=\(encoded)")
    }
  }
}
