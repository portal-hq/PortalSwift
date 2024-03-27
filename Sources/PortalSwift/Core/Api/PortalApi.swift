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
  private let logger = PortalLogger()
  private var provider: PortalProvider
  private var requests: HttpRequester
  private let featureFlags: FeatureFlags?

  private var address: String? {
    self.provider.address
  }

  private var chainId: Int {
    self.provider.chainId
  }

  public var client: ClientResponse? {
    get async {
      if self._client == nil {
        do {
          self._client = try await self.getClient()
        } catch {
          self.logger.error("PortalApi.client - Error getting client: \(error.localizedDescription)")
          return nil
        }
      }

      return self._client
    }
  }

  /// Create an instance of a PortalApi class.
  /// - Parameters:
  ///   - apiKey: The Client API key. You can create one using Portal's REST API.
  ///   - apiHost: (optional) The Portal API hostname.
  ///   - provider: The PortalProvider instance to use for stateful Provider info (chainId, address)
  init(
    apiKey: String,
    apiHost: String = "api.portalhq.io",
    provider: PortalProvider,
    mockRequests: Bool = false,
    featureFlags: FeatureFlags? = nil
  ) {
    self.apiKey = apiKey
    self.provider = provider

    self.baseUrl = apiHost.starts(with: "localhost") ? "http://\(apiHost)" : "https://\(apiHost)"
    self.requests = mockRequests ? MockHttpRequester(baseUrl: self.baseUrl) : HttpRequester(baseUrl: self.baseUrl)

    self.featureFlags = featureFlags
  }

  /*******************************************
   * Public functions
   *******************************************/

  public func eject(_: String) async throws -> String {
    if let url = URL(string: "\(baseUrl)/api/v3/clients/me/eject") {
      do {
        let data = try await PortalRequests.get(url, withBearerToken: self.apiKey)
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
        let data = try await PortalRequests.get(url, withBearerToken: self.apiKey)
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
    self.logger.debug("getClient URL: \(self.baseUrl)/api/v3/clients/me")
    if let url = URL(string: "\(baseUrl)/api/v3/clients/me") {
      do {
        let data = try await PortalRequests.get(url, withBearerToken: self.apiKey)

        self.logger.debug("Data: \(String(data: data, encoding: .utf8) ?? "")")

        let clientResponse = try decoder.decode(ClientResponse.self, from: data)

        self.logger.debug("Client: \(clientResponse)")

        return clientResponse
      } catch {
        throw error
      }
    }

    throw URLError(.badURL)
  }

  public func getNFTs(_ chainId: String) async throws -> [FetchedNFT] {
    if let url = URL(string: "\(baseUrl)/api/v3/clients/me/nfts?chainId=\(chainId)") {
      do {
        let data = try await PortalRequests.get(url, withBearerToken: self.apiKey)
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
        let data = try await PortalRequests.get(url, withBearerToken: self.apiKey)
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
        let data = try await PortalRequests.get(url, withBearerToken: self.apiKey)
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

  public func refreshClient() async throws {
    do {
      self._client = try await self.getClient()

      return
    } catch {
      self.logger.error("PortalApi.refreshClient() - Unable to refresh user: \(error.localizedDescription)")
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
  public func simulateTransaction(_ transaction: AnyEncodable, withChainId _: String) async throws -> SimulatedTransaction {
    if let url = URL(string: "\(baseUrl)/api/v3/clients/me/simulate-transaction?chainId=\(chainId)") {
      do {
        let data = try await PortalRequests.post(url, withBearerToken: self.apiKey, andPayload: transaction)
        let simulatedTransaction = try decoder.decode(SimulatedTransaction.self, from: data)

        return simulatedTransaction
      } catch {
        self.logger.error("PortalApi.simulateTransaction() - Unable to simulate transaction: \(error.localizedDescription)")
      }
    }

    self.logger.error("PortalApi.simulateTransaction() - Unable to build request URL.")
    throw URLError(.badURL)
  }

  public func updateShareStatus(
    _ type: PortalSharePairType,
    status: SharePairUpdateStatus,
    sharePairIds: [String]
  ) async throws -> ShareStatusUpdateResponse {
    if let url = URL(string: "\(baseUrl)/api/v3/clients/me/\(type)-share-pairs/") {
      do {
        let payload = ShareStatusUpdateRequest(
          backupSharePairIds: type == .backup ? sharePairIds : nil,
          signingSharePairIds: type == .signing ? sharePairIds : nil,
          status: status
        )

        let data = try await PortalRequests.patch(url, withBearerToken: self.apiKey, andPayload: payload)
        let updateResponse = try decoder.decode(ShareStatusUpdateResponse.self, from: data)

        return updateResponse
      } catch {
        self.logger.error("PortalApi.updateShareStatus() - Unable to update share status: \(error.localizedDescription)")
        throw error
      }
    }

    self.logger.error("PortalApi.updateShareStatus() - Unable to build request URL.")
    throw URLError(.badURL)
  }

  /*******************************************
   * Deprecated functions
   *******************************************/

  /// Retrieve the client by API key.
  /// - Parameter completion: The callback that contains the Client.
  /// - Returns: Void.
  public func getClient(completion: @escaping (Result<Client>) -> Void) throws {
    try self.requests.get(
      path: "/api/v1/clients/me",
      headers: [
        "Authorization": "Bearer \(self.apiKey)",
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<Client>) in
      if result.error != nil {
        completion(Result<Client>(error: result.error!))
      } else if result.data != nil {
        completion(Result<Client>(data: result.data!))
      }

      self.track(event: MetricsEvents.getClient.rawValue, properties: ["path": "/api/v1/clients/me"])
    }
  }

  /// Retrieve a list of enabled dapps for the client.
  /// - Parameter completion: The callback that contains the list of Dapps.
  /// - Returns: Void.
  public func getEnabledDapps(completion: @escaping (Result<[Dapp]>) -> Void) throws {
    try self.requests.get(
      path: "/api/v1/config/dapps",
      headers: [
        "Authorization": "Bearer \(self.apiKey)",
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<[Dapp]>) in
      completion(result)

      self.track(event: MetricsEvents.getEnabledDapps.rawValue, properties: ["path": "/api/v1/config/dapps"])
    }
  }

  public func getQuote(
    _ swapsApiKey: String,
    _ args: QuoteArgs,
    completion: @escaping (Result<Quote>) -> Void
  ) throws {
    // Build the request body
    var body = args.toDictionary()
    // Append Portal-provided values
    body["address"] = self.address
    body["apiKey"] = swapsApiKey
    body["chainId"] = self.chainId

    // Make the request
    try self.requests.post(
      path: "/api/v1/swaps/quote",
      body: body,
      headers: [
        "Authorization": "Bearer \(self.apiKey)",
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<Quote>) in
      completion(result)

      self.track(event: MetricsEvents.getQuote.rawValue, properties: ["path": "/api/v1/swaps/quote"])
    }
  }

  public func getSources(swapsApiKey: String, completion: @escaping (Result<[String: String]>) -> Void) throws {
    try self.requests.post(
      path: "/api/v1/swaps/sources",
      body: [
        "apiKey": swapsApiKey,
        "chainId": self.chainId,
      ],
      headers: [
        "Authorization": "Bearer \(self.apiKey)",
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<[String: String]>) in
      completion(result)

      self.track(event: MetricsEvents.getSources.rawValue, properties: ["path": "/api/v1/swaps/sources"])
    }
  }

  /// Retrieves a list of supported networks.
  /// - Parameter completion: The callback that contains the list of Networks.
  /// - Returns: Void.
  public func getSupportedNetworks(completion: @escaping (Result<[ContractNetwork]>) -> Void) throws {
    try self.requests.get(
      path: "/api/v1/config/networks",
      headers: [
        "Authorization": "Bearer \(self.apiKey)",
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<[ContractNetwork]>) in
      completion(result)

      self.track(event: MetricsEvents.getNetworks.rawValue, properties: ["path": "/api/v1/config/networks"])
    }
  }

  /// Retrieve a list of NFTs for the client.
  /// - Parameters:
  ///   - completion: The callback that contains the list of NFTs.
  /// - Returns: Void.
  public func getNFTs(completion: @escaping (Result<[NFT]>) -> Void) throws {
    try self.requests.get(
      path: "/api/v1/clients/me/nfts?chainId=\(self.chainId)",
      headers: [
        "Authorization": "Bearer \(self.apiKey)",
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<[NFT]>) in
      completion(result)

      self.track(event: MetricsEvents.getNFTs.rawValue, properties: ["path": "/api/v1/clients/me/nfts"])
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
  public func getTransactions(
    limit: Int? = nil,
    offset: Int? = nil,
    order: GetTransactionsOrder? = nil,
    chainId: Int? = nil,
    completion: @escaping (Result<[Transaction]>) -> Void
  ) throws {
    var path = "/api/v1/clients/me/transactions"

    // Start building query parameters
    var queryParams: [String] = []

    // Use provided chainId or default to self.chainId
    let effectiveChainId = chainId ?? self.chainId
    queryParams.append("chainId=\(effectiveChainId)")

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
      path += "?" + queryParams.joined(separator: "&")
    }
    print("path:", path)

    try self.requests.get(
      path: path,
      headers: [
        "Authorization": "Bearer \(self.apiKey)",
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<[Transaction]>) in
      completion(result)
      self.track(event: MetricsEvents.getTransactions.rawValue, properties: ["path": path])
    }
  }

  /// Retrieve a list of Balances for the client.
  /// - Parameters:
  ///   - completion: The callback that contains the list of Balances.
  /// - Returns: Void.
  public func getBalances(
    completion: @escaping (Result<[Balance]>) -> Void
  ) throws {
    try self.requests.get(
      path: "/api/v1/clients/me/balances?chainId=\(self.chainId)",
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
  public func simulateTransaction(
    transaction: SimulateTransactionParam,
    completion: @escaping (Result<SimulatedTransaction>) -> Void
  ) throws {
    var requestBody: [String: String] = ["to": transaction.to]

    if let value = transaction.value { requestBody["value"] = value }
    if let data = transaction.data { requestBody["data"] = data }
    if let maxFeePerGas = transaction.maxFeePerGas { requestBody["maxFeePerGas"] = maxFeePerGas }
    if let maxPriorityFeePerGas = transaction.maxPriorityFeePerGas {
      requestBody["maxPriorityFeePerGas"] = maxPriorityFeePerGas
    }
    if let gas = transaction.gas { requestBody["gas"] = gas }
    if let gasPrice = transaction.gasPrice { requestBody["gasPrice"] = gasPrice }

    try self.requests.post(
      path: "/api/v1/clients/me/simulate-transaction?chainId=\(self.chainId)",
      body: requestBody,
      headers: [
        "Authorization": "Bearer \(self.apiKey)",
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<SimulatedTransaction>) in
      completion(result)

      self.track(event: MetricsEvents.simulateTransaction.rawValue, properties: ["path": "/api/v1/clients/me/simulate-transaction"])
    }
  }

  /// Updates the client's wallet state to be stored on the client.
  /// - Parameters:
  ///   - signingSharePairId: The ID related to the signing share pair.
  ///   - completion: The callback that contains the response status.
  /// - Returns: Void.
  public func storedClientSigningShare(
    signingSharePairId: String,
    completion: @escaping (Result<String>) -> Void
  ) throws {
    let path = "/api/v2/clients/me/wallet/stored-on-client"

    let requestBody: [String: Any] = ["signingSharePairId": signingSharePairId]

    try self.requests.put(
      path: path,
      body: requestBody,
      headers: [
        "Authorization": "Bearer \(self.apiKey)",
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<String>) in
      completion(result)

      self.track(event: MetricsEvents.storedClientSigningShare.rawValue, properties: ["path": path])
    }
  }

  /// Updates the client's wallet backup state to have successfully stored the client backup share key in the client's storage (e.g. gdrive, icloud, etc).
  /// - Parameters:
  ///   - success: Boolean indicating whether the storage operation failed.
  ///   - backupMethod: The `BackupMethod` used to create the  backup share.
  ///   - completion: The callback that contains the response status.
  /// - Returns: Void.
  public func storedClientBackupShareKey(
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

    try self.requests.put(
      path: "/api/v2/clients/me/wallet/stored-client-backup-share-key",
      body: body,
      headers: [
        "Authorization": "Bearer \(self.apiKey)",
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<String>) in
      completion(result)

      self.track(event: MetricsEvents.storedClientBackupShareKey.rawValue, properties: ["path": "/api/v2/clients/me/wallet/stored-client-backup-share-key"])
    }
  }

  /// Updates the client's ejectedAt status.
  /// - Parameters:
  ///   - completion: The callback that contains the response status.
  /// - Returns: Void.
  public func ejectClient(completion: @escaping (Result<String>) -> Void) throws {
    try self.requests.post(
      path: "/api/v1/clients/eject",
      body: [:],
      headers: ["Authorization": "Bearer \(self.apiKey)"],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<String>) in
      completion(result)
    }
  }

  /// Updates the client's wallet backup state to have successfully stored the client backup share with the custodian.
  /// - Parameters:
  ///   - success: Boolean indicating whether the storage operation failed.
  ///   - backupSharePairId: The `backupSharePairId` on the share.
  ///   - completion: The callback that contains the response status.
  /// - Returns: Void.
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

    try self.requests.put(
      path: "/api/v2/clients/me/wallet/stored-client-backup-share",
      body: body,
      headers: [
        "Authorization": "Bearer \(self.apiKey)",
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<String>) in
      completion(result)

      self.track(event: MetricsEvents.storedClientBackupShare.rawValue, properties: ["path": "/api/v2/clients/me/wallet/stored-client-backup-share"])
    }
  }

  /// Retrieve a list of backup share pairs' details for the client.
  /// - Parameter completion: The callback that contains the list of BackupSharePairs' details.
  /// - Returns: Void.
  public func getBackupShareMetadata(completion: @escaping (Result<[BackupSharePair]>) -> Void) throws {
    try self.requests.get(
      path: "/api/v1/clients/me/backup-share-pairs",
      headers: [
        "Authorization": "Bearer \(self.apiKey)",
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<[BackupSharePair]>) in
      completion(result)

      self.track(event: MetricsEvents.getBackupShareMetadata.rawValue, properties: ["path": "/api/v1/clients/me/backup-share-pairs"])
    }
  }

  /// Retrieve a list of signing share pairs' details for the client.
  /// - Parameter completion: The callback that contains the list of SigningSharePairs' details.
  /// - Returns: Void.
  public func getSigningShareMetadata(completion: @escaping (Result<[SigningSharePair]>) -> Void) throws {
    try self.requests.get(
      path: "/api/v1/clients/me/signing-share-pairs",
      headers: [
        "Authorization": "Bearer \(self.apiKey)",
      ],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<[SigningSharePair]>) in
      completion(result)

      self.track(event: MetricsEvents.getSigningShareMetadata.rawValue, properties: ["path": "/api/v1/clients/me/signing-share-pairs"])
    }
  }

  public func identify(traits: [String: Any] = [:], completion: @escaping (Result<MetricsResponse>) -> Void) throws {
    let body: [String: Any] = [
      "traits": traits,
    ]

    try self.requests.post(
      path: "/api/v1/analytics/identify",
      body: body,
      headers: ["Authorization": "Bearer \(self.apiKey)"],
      requestType: HttpRequestType.CustomRequest
    ) { (result: Result<MetricsResponse>) in
      completion(result)
    }
  }

  func track(event: String, properties: [String: Any], completion: ((Result<MetricsResponse>) -> Void)? = nil) {
    let body: [String: Any] = [
      "event": event,
      "properties": properties,
    ]

    do {
      try self.requests.post(
        path: "/api/v1/analytics/track",
        body: body,
        headers: ["Authorization": "Bearer \(self.apiKey)"],
        requestType: HttpRequestType.CustomRequest
      ) { (result: Result<MetricsResponse>) in
        completion?(result)
      }
    } catch {
      print("Failed to track event")
    }
  }
}

public enum PortalApiError: Error, Equatable {
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

  init?(_ fromString: String) {
    self.init(rawValue: fromString)
  }
}
