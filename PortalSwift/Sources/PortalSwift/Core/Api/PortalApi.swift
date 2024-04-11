//
//  PortalApi.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

/// The class to interface with Portal's REST API.
public class PortalApi {
  private var _client: ClientResponse?
  private var apiKey: String
  private var baseUrl: String
  private let decoder = JSONDecoder()
  private var httpRequests: HttpRequester
  private let logger = PortalLogger()
  private var provider: PortalProvider?
  private let requests: PortalRequests
  private let featureFlags: FeatureFlags?

  private var address: String? {
    self.provider?.address
  }

  private var chainId: Int? {
    self.provider?.chainId
  }

  public var client: ClientResponse? {
    get async throws {
      if self._client == nil {
        self._client = try await self.getClient()
      }
      return self._client
    }
  }

  /// Create an instance of a PortalApi class.
  /// - Parameters:
  ///   - apiKey: The Client API key. You can create one using Portal's REST API.
  ///   - apiHost: (optional) The Portal API hostname.
  ///   - provider: The PortalProvider instance to use for stateful Provider info (chainId, address)
  public init(
    apiKey: String,
    apiHost: String = "api.portalhq.io",
    provider: PortalProvider? = nil,
    featureFlags: FeatureFlags? = nil,
    requests: PortalRequests? = nil
  ) {
    self.apiKey = apiKey
    self.baseUrl = apiHost.starts(with: "localhost") ? "http://\(apiHost)" : "https://\(apiHost)"
    self.featureFlags = featureFlags
    self.provider = provider
    self.requests = requests ?? PortalRequests()
    self.httpRequests = HttpRequester(baseUrl: self.baseUrl)
  }

  /*******************************************
   * Public functions
   *******************************************/

  public func eject() async throws -> String {
    if let url = URL(string: "\(baseUrl)/api/v3/clients/me/eject") {
      do {
        let data = try await post(url, withBearerToken: self.apiKey)
        guard let ejectResponse = String(data: data, encoding: .utf8) else {
          throw PortalApiError.unableToReadStringResponse
        }

        return ejectResponse
      } catch {
        self.logger.error("PortalApi.getBalances() - Unable to eject: \(error.localizedDescription)")
        throw error
      }
    }

    self.logger.error("PortalApi.eject() - Unable to build request URL.")
    throw URLError(.badURL)
  }

  public func getBalances(_ chainId: String) async throws -> [FetchedBalance] {
    if let url = URL(string: "\(baseUrl)/api/v3/clients/me/balances?chainId=\(chainId)") {
      do {
        let data = try await get(url, withBearerToken: self.apiKey)
        let balancesResponse = try decoder.decode([FetchedBalance].self, from: data)

        return balancesResponse
      } catch {
        self.logger.error("PortalApi.getBalances() - Unable to get balanaces: \(error.localizedDescription)")
        throw error
      }
    }

    self.logger.error("PortalApi.getBalances() - Unable to build request URL.")
    throw URLError(.badURL)
  }

  /// Retrieve the client by API key.
  /// - Returns: ClientResponse
  public func getClient() async throws -> ClientResponse {
    if let url = URL(string: "\(baseUrl)/api/v3/clients/me") {
      do {
        let data = try await get(url, withBearerToken: self.apiKey)
        let clientResponse = try decoder.decode(ClientResponse.self, from: data)

        return clientResponse
      } catch {
        throw error
      }
    }

    throw URLError(.badURL)
  }

  public func getQuote(_ swapsApiKey: String, withArgs: QuoteArgs) async throws -> Quote {
    if let url = URL(string: "\(baseUrl)/api/v1/swaps/quote") {
      // Build the request body
      var body = withArgs.toDictionary()
      // Append Portal-provided values
      body["address"] = AnyEncodable(self.address)
      body["apiKey"] = AnyEncodable(swapsApiKey)
      body["chainId"] = AnyEncodable(self.chainId)

      let data = try await post(url, withBearerToken: self.apiKey, andPayload: body)
      let response = try decoder.decode(Quote.self, from: data)

      return response
    }

    throw URLError(.badURL)
  }

  public func getNFTs(_ chainId: String) async throws -> [FetchedNFT] {
    if let url = URL(string: "\(baseUrl)/api/v3/clients/me/nfts?chainId=\(chainId)") {
      do {
        let data = try await get(url, withBearerToken: self.apiKey)
        let nfts = try decoder.decode([FetchedNFT].self, from: data)

        return nfts
      } catch {
        self.logger.error("PortalApi.getNFTs() - Unable to fetch NFTs: \(error.localizedDescription)")
        throw error
      }
    }

    self.logger.error("PortalApi.getNFTs() - Unable to build request URL.")
    throw URLError(.badURL)
  }

  public func getSharePairs(_ type: PortalSharePairType, walletId: String) async throws -> [FetchedSharePair] {
    if let url = URL(string: "\(baseUrl)/api/v3/clients/me/wallets/\(walletId)/\(type)-share-pairs") {
      do {
        let data = try await get(url, withBearerToken: self.apiKey)
        let sharePairs = try decoder.decode([FetchedSharePair].self, from: data)

        return sharePairs
      } catch {
        self.logger.error("PortalApi.getSharePairs() - Unable to fetch \(type) share pairs: \(error.localizedDescription)")
        throw error
      }
    }

    self.logger.error("PortalApi.getSharePairs() - Unable to build request URL.")
    throw URLError(.badURL)
  }

  public func getSources(_ swapsApiKey: String, forChainId: String) async throws -> [String: String] {
    if let url = URL(string: "\(baseUrl)/api/v1/swaps/sources") {
      let payload = ["apiKey": swapsApiKey, "chainId": forChainId]
      let data = try await post(url, withBearerToken: self.apiKey, andPayload: payload)
      let response = try decoder.decode([String: String].self, from: data)

      return response
    }

    throw URLError(.badURL)
  }

  public func getTransactions(
    _ chainId: String,
    limit: Int? = nil,
    offset: Int? = nil,
    order: TransactionOrder? = nil
  ) async throws -> [FetchedTransaction] {
    var requestUrlString = "\(baseUrl)/api/v3/clients/me/transactions?chainId=\(chainId)"

    var queryParams: [String] = []

    if let limit {
      queryParams.append("limit=\(limit)")
    }
    if let offset {
      queryParams.append("offset=\(offset)")
    }
    if let order {
      queryParams.append("order=\(order)")
    }

    // Add the combined query parameters to the path
    if !queryParams.isEmpty {
      requestUrlString += "?" + queryParams.joined(separator: "&")
    }

    if let url = URL(string: requestUrlString) {
      do {
        let data = try await get(url, withBearerToken: self.apiKey)
        let transactions = try decoder.decode([FetchedTransaction].self, from: data)

        return transactions
      } catch {
        self.logger.error("PortalApi.getTransactions() - Unable to fetch transactions: \(error.localizedDescription)")
        throw error
      }
    }

    self.logger.error("PortalApi.getTransactions() - Unable to build request URL.")
    throw URLError(.badURL)
  }

  public func identify(_ traits: [String: AnyEncodable] = [:]) async throws -> MetricsResponse {
    if let url = URL(string: "\(baseUrl)/api/v1/analytics/identify") {
      let data = try await post(url, withBearerToken: self.apiKey, andPayload: ["traits": traits])
      let response = try decoder.decode(MetricsResponse.self, from: data)

      return response
    }

    throw URLError(.badURL)
  }

  public func refreshClient() async throws {
    do {
      self._client = try await self.getClient()

      return
    } catch {
      self.logger.error("PortalApi.refreshClient() - Unable to refresh client: \(error.localizedDescription)")
      throw error
    }
  }

  /// Simulates a transaction for the client.
  /// - Parameters:
  ///   - to: The recipient address.
  ///   - value: (Optional) The transacton "value" parameter.
  ///   - data: (Optional) The transacton "data" parameter.
  ///   - maxFeePerGas: (Optional) The transacton "maxFeePerGas" parameter.
  ///   - maxPriorityFeePerGas: (Optional) The transacton "maxPriorityFeePerGas" parameter.
  ///   - gas: (Optional) The transacton "gas" parameter.
  ///   - gasPrice: (Optional) The transacton "gasPrice" parameter.
  ///   - completion: The callback that contains transaction simulation response.
  /// - Returns: Void.
  public func simulateTransaction(_ transaction: Any, withChainId: String) async throws -> SimulatedTransaction {
    guard let chainId = withChainId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
      throw PortalApiError.unableToEncodeData
    }
    if let url = URL(string: "\(baseUrl)/api/v3/clients/me/simulate-transaction?chainId=\(chainId)") {
      do {
        let transformedTransaction = try AnyEncodable(transaction)
        let data = try await post(url, withBearerToken: self.apiKey, andPayload: transformedTransaction)
        let simulatedTransaction = try decoder.decode(SimulatedTransaction.self, from: data)

        return simulatedTransaction
      } catch {
        self.logger.error("PortalApi.simulateTransaction() - Unable to simulate transaction: \(error.localizedDescription)")
        throw error
      }
    }

    self.logger.error("PortalApi.simulateTransaction() - Unable to build request URL.")
    throw URLError(.badURL)
  }

  func track(_ event: String, withProperties: [String: AnyEncodable]) async throws -> MetricsResponse {
    if let url = URL(string: "\(baseUrl)/api/v1/analytics/track") {
      let payload = MetricsTrackRequest(
        event: event,
        properties: withProperties
      )
      let data = try await post(url, withBearerToken: self.apiKey, andPayload: payload)
      let response = try decoder.decode(MetricsResponse.self, from: data)

      return response
    }

    throw URLError(.badURL)
  }

  public func updateShareStatus(
    _ type: PortalSharePairType,
    status: SharePairUpdateStatus,
    sharePairIds: [String]
  ) async throws {
    if let url = URL(string: "\(baseUrl)/api/v3/clients/me/\(type.rawValue)-share-pairs/") {
      do {
        let payload = ShareStatusUpdateRequest(
          backupSharePairIds: type == .backup ? sharePairIds : nil,
          signingSharePairIds: type == .signing ? sharePairIds : nil,
          status: status
        )

        _ = try await self.patch(url, withBearerToken: self.apiKey, andPayload: payload)

        return
      } catch {
        self.logger.error("PortalApi.updateShareStatus() - Unable to update share status: \(error.localizedDescription)")
        throw error
      }
    }

    self.logger.error("PortalApi.updateShareStatus() - Unable to build request URL.")
    throw URLError(.badURL)
  }

  /*******************************************
   * Private functions
   *******************************************/

  private func get(_ url: URL, withBearerToken: String? = nil) async throws -> Data {
    return try await self.requests.get(url, withBearerToken: withBearerToken)
  }

  private func patch(_ url: URL, withBearerToken: String? = nil, andPayload: Encodable) async throws -> Data {
    return try await self.requests.patch(url, withBearerToken: withBearerToken, andPayload: andPayload)
  }

  private func post(_ url: URL, withBearerToken: String? = nil, andPayload: Encodable? = nil) async throws -> Data {
    return try await self.requests.post(url, withBearerToken: withBearerToken, andPayload: andPayload)
  }

  /*******************************************
   * Deprecated functions
   *******************************************/

  /// Retrieve the client by API key.
  /// - Parameter completion: The callback that contains the Client.
  /// - Returns: Void.
  @available(*, deprecated, renamed: "getClient", message: "Please use the async/await implementation of getClient().")
  public func getClient(completion: @escaping (Result<ClientResponse>) -> Void) throws {
    Task.init {
      do {
        let client = try await getClient()
        completion(Result(data: client))
      } catch {
        completion(Result(error: error))
      }
    }
  }

  @available(*, deprecated, renamed: "getQuote", message: "Please use the async/await implementation of getQuote().")
  public func getQuote(
    _ swapsApiKey: String,
    _ args: QuoteArgs,
    completion: @escaping (Result<Quote>) -> Void
  ) throws {
    Task {
      do {
        let response = try await getQuote(swapsApiKey, withArgs: args)
        completion(Result(data: response))
      } catch {
        completion(Result(error: error))
      }
    }
  }

  @available(*, deprecated, renamed: "getSources", message: "Please use the async/await implementation of getSources().")
  public func getSources(swapsApiKey: String, completion: @escaping (Result<[String: String]>) -> Void) throws {
    Task {
      do {
        let response = try await getSources(swapsApiKey, forChainId: "eip155:\(self.chainId ?? 1)")
        completion(Result(data: response))
      } catch {
        completion(Result(error: error))
      }
    }
  }

  /// Retrieve a list of NFTs for the client.
  /// - Parameters:
  ///   - completion: The callback that contains the list of NFTs.
  /// - Returns: Void.
  @available(*, deprecated, renamed: "getNFTs", message: "Please use the async/await implementation of getNFTs().")
  public func getNFTs(completion: @escaping (Result<[FetchedNFT]>) -> Void) throws {
    Task {
      do {
        let response = try await getNFTs("eip155:\(self.chainId ?? 1)")
        completion(Result(data: response))
      } catch {
        completion(Result(error: error))
      }
    }
  }

  /// Retrieve a list of Transactions for the client.
  /// - Parameters:
  ///   - limit: (Optional) The maximum number of transactions to return.
  ///   - offset: (Optional) The number of transactions to skip before starting to return.
  ///   - order: (Optional) Order in which to return the transactions.
  ///   - chainId: (Optional) ID of the chain to retrieve transactions from. Defaults to `self.chainId` if not provided.
  ///   - completion: The callback that contains the list of Transactions.
  /// - Returns: Void.
  @available(*, deprecated, renamed: "getTransactions", message: "Please use the async/await implementation of getTransactions().")
  public func getTransactions(
    limit: Int? = nil,
    offset: Int? = nil,
    order: GetTransactionsOrder? = nil,
    chainId: Int? = nil,
    completion: @escaping (Result<[FetchedTransaction]>) -> Void
  ) throws {
    Task {
      do {
        let transactionsOrder = order == .asc ? TransactionOrder.ASC : TransactionOrder.DESC
        let response = try await getTransactions("eip155:\(chainId ?? self.chainId ?? 1)", limit: limit, offset: offset, order: transactionsOrder)
        completion(Result(data: response))
      } catch {
        completion(Result(error: error))
      }
    }
  }

  /// Retrieve a list of Balances for the client.
  /// - Parameters:
  ///   - completion: The callback that contains the list of Balances.
  /// - Returns: Void.
  @available(*, deprecated, renamed: "getBalances", message: "Please use the async/await implementation of getBalances().")
  public func getBalances(
    completion: @escaping (Result<[Balance]>) -> Void
  ) throws {
    try self.httpRequests.get(
      path: "/api/v1/clients/me/balances?chainId=\(self.chainId ?? 1)",
      headers: [
        "Authorization": "Bearer \(self.apiKey)",
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<[Balance]>) in
      completion(result)

      self.track(event: MetricsEvents.getBalances.rawValue, properties: ["path": "/api/v1/clients/me/balances"])
    }
  }

  /// Simulates a transaction for the client.
  /// - Parameters:
  ///   - to: The recipient address.
  ///   - value: (Optional) The transacton "value" parameter.
  ///   - data: (Optional) The transacton "data" parameter.
  ///   - maxFeePerGas: (Optional) The transacton "maxFeePerGas" parameter.
  ///   - maxPriorityFeePerGas: (Optional) The transacton "maxPriorityFeePerGas" parameter.
  ///   - gas: (Optional) The transacton "gas" parameter.
  ///   - gasPrice: (Optional) The transacton "gasPrice" parameter.
  ///   - completion: The callback that contains transaction simulation response.
  /// - Returns: Void.
  @available(*, deprecated, renamed: "simulateTransaction", message: "Please use the async/await implementation of simulateTransaction().")
  public func simulateTransaction(
    transaction: SimulateTransactionParam,
    completion: @escaping (Result<SimulatedTransaction>) -> Void
  ) throws {
    Task {
      do {
        let simulateTransactionParam = AnyEncodable(transaction)
        let response = try await simulateTransaction(simulateTransactionParam, withChainId: "eip155:\(self.chainId ?? 1)")
        completion(Result(data: response))
      } catch {
        completion(Result(error: error))
      }
    }
  }

  /// Updates the client's ejectedAt status.
  /// - Parameters:
  ///   - completion: The callback that contains the response status.
  /// - Returns: Void.
  @available(*, deprecated, renamed: "eject", message: "Please use the async/await implementation of eject().")
  public func ejectClient(completion: @escaping (Result<String>) -> Void) throws {
    Task {
      do {
        let response = try await eject()
        completion(Result(data: response))
      } catch {
        completion(Result(error: error))
      }
    }
  }

  /// Updates the client's wallet backup state to have successfully stored the client backup share with the custodian.
  /// - Parameters:
  ///   - success: Boolean indicating whether the storage operation failed.
  ///   - backupSharePairId: The `backupSharePairId` on the share.
  ///   - completion: The callback that contains the response status.
  /// - Returns: Void.
  @available(*, deprecated, renamed: "updateShareStatus", message: "Please use the async/await implementation of updateShareStatus().")
  public func storedClientBackupShare(
    success: Bool,
    backupMethod: BackupMethods.RawValue,
    completion: @escaping (Result<String>) -> Void
  ) throws {
    // Start with a dictionary containing the always-present keys
    var body: [String: Any] = [
      "backupMethod": "\(backupMethod)",
      "success": success,
    ]

    // Conditionally add isMultiBackupEnabled if it's not nil
    if let isMultiBackupEnabled = self.featureFlags?.isMultiBackupEnabled {
      body["isMultiBackupEnabled"] = isMultiBackupEnabled
    }

    try self.httpRequests.put(
      path: "/api/v2/clients/me/wallet/stored-client-backup-share",
      body: body,
      headers: [
        "Authorization": "Bearer \(self.apiKey)",
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<String>) in
      completion(result)

      self.track(
        event: MetricsEvents.storedClientBackupShare.rawValue,
        properties: ["path": "/api/v2/clients/me/wallet/stored-client-backup-share"]
      )
    }
  }

  /// Retrieve a list of backup share pairs' details for the client.
  /// - Parameter completion: The callback that contains the list of BackupSharePairs' details.
  /// - Returns: Void.
  @available(*, deprecated, renamed: "getSharePairs", message: "Please use the async/await implementation of getSharePairs().")
  public func getBackupShareMetadata(completion: @escaping (Result<[FetchedSharePair]>) -> Void) throws {
    Task {
      do {
        let walletId = try await client?.wallets.first { wallet in
          wallet.curve == .SECP256K1
        }?.id
        let response = try await getSharePairs(.backup, walletId: walletId ?? "NO-WALLET-ID-FOUND")
        completion(Result(data: response))
      } catch {
        completion(Result(error: error))
      }
    }
  }

  /// Retrieve a list of signing share pairs' details for the client.
  /// - Parameter completion: The callback that contains the list of SigningSharePairs' details.
  /// - Returns: Void.
  @available(*, deprecated, renamed: "getSharePairs", message: "Please use the async/await implementation of getSharePairs().")
  public func getSigningShareMetadata(completion: @escaping (Result<[FetchedSharePair]>) -> Void) throws {
    Task {
      do {
        let walletId = try await client?.wallets.first { wallet in
          wallet.curve == .SECP256K1
        }?.id
        let response = try await getSharePairs(.signing, walletId: walletId ?? "NO-WALLET-ID-FOUND")
        completion(Result(data: response))
      } catch {
        completion(Result(error: error))
      }
    }
  }

  func track(event: String, properties: [String: String], completion: ((Result<MetricsResponse>) -> Void)? = nil) {
    Task.init {
      do {
        let transformedProperties = properties.mapValues { AnyEncodable($0) }
        let response = try await track(event, withProperties: transformedProperties)
        completion?(Result(data: response))
      } catch {
        completion?(Result(error: error))
      }
    }
  }
}

public enum PortalApiError: Error, Equatable {
  case unableToEncodeData
  case unableToReadStringResponse
}

public enum SharePairUpdateStatus: String, Codable {
  case STORED_CLIENT
  case STORED_CLIENT_BACKUP_SHARE
  case STORED_CLIENT_BACKUP_SHARE_KEY
}

public enum TransactionOrder: String, Codable {
  case ASC
  case DESC
}
