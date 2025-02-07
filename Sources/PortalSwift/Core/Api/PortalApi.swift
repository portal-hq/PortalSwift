//
//  PortalApi.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import AnyCodable
import Foundation

public protocol PortalApiProtocol: AnyObject {
  var client: ClientResponse? { get async throws }

  func eject() async throws -> String
  func fund(chainId: String, params: FundParams) async throws -> FundResponse
  func getBalances(_ chainId: String) async throws -> [FetchedBalance]
  func getClient() async throws -> ClientResponse
  func getClientCipherText(_ backupSharePairId: String) async throws -> String
  func getQuote(_ swapsApiKey: String, withArgs: QuoteArgs, forChainId: String?) async throws -> Quote
  func getNftAssets(_ chainId: String) async throws -> [NftAsset]
  func getSharePairs(_ type: PortalSharePairType, walletId: String) async throws -> [FetchedSharePair]
  func getSources(_ swapsApiKey: String, forChainId: String) async throws -> [String: String]
  func getTransactions(_ chainId: String, limit: Int?, offset: Int?, order: TransactionOrder?) async throws -> [FetchedTransaction]
  func identify(_ traits: [String: AnyCodable]) async throws -> MetricsResponse
  func prepareEject(_ walletId: String, _ backupMethod: BackupMethods) async throws -> String
  func refreshClient() async throws
  func simulateTransaction(_ transaction: Any, withChainId: String) async throws -> SimulatedTransaction
  func updateShareStatus(_ type: PortalSharePairType, status: SharePairUpdateStatus, sharePairIds: [String]) async throws
  func getClient(completion: @escaping (Result<ClientResponse>) -> Void) throws
  func getQuote(_ swapsApiKey: String, _ args: QuoteArgs, _ forChainId: String?, completion: @escaping (Result<Quote>) -> Void) throws
  func getSources(swapsApiKey: String, completion: @escaping (Result<[String: String]>) -> Void) throws
  func getTransactions(limit: Int?, offset: Int?, order: GetTransactionsOrder?, chainId: Int?, completion: @escaping (Result<[FetchedTransaction]>) -> Void) throws
  func getBalances(completion: @escaping (Result<[FetchedBalance]>) -> Void) throws
  func simulateTransaction(transaction: SimulateTransactionParam, completion: @escaping (Result<SimulatedTransaction>) -> Void) throws
  func ejectClient(completion: @escaping (Result<String>) -> Void) throws
  func storedClientBackupShare(success: Bool, backupMethod: BackupMethods.RawValue, completion: @escaping (Result<String>) -> Void) throws
  func getBackupShareMetadata(completion: @escaping (Result<[FetchedSharePair]>) -> Void) throws
  func getSigningShareMetadata(completion: @escaping (Result<[FetchedSharePair]>) -> Void) throws
  func storeClientCipherText(_ backupSharePairId: String, cipherText: String) async throws -> Bool
  func track(_ event: String, withProperties: [String: AnyCodable]) async throws -> MetricsResponse
  func evaluateTransaction(chainId: String, transaction: EvaluateTransactionParam, operationType: EvaluateTransactionOperationType?) async throws -> BlockaidValidateTrxRes
  func buildEip155Transaction(chainId: String, params: BuildTransactionParam) async throws -> BuildEip115TransactionResponse
  func buildSolanaTransaction(chainId: String, params: BuildTransactionParam) async throws -> BuildSolanaTransactionResponse
  func getAssets(_ chainId: String) async throws -> AssetsResponse
  func getWalletCapabilities() async throws -> WalletCapabilitiesResponse
}

/// The ThreadSafeClientWrapper is just a thread-safe actor to consume the ClientResponse class, we need to refactor that later.
private actor ThreadSafeClientWrapper {
  private var _client: ClientResponse?

  func getOrCreateClient(creation: @escaping () async throws -> ClientResponse) async throws -> ClientResponse {
    if let client = _client {
      return client
    }
    let newClient = try await creation()
    _client = newClient
    return newClient
  }

  func set(client: ClientResponse) {
    _client = client
  }
}

/// The class to interface with Portal's REST API.
public class PortalApi: PortalApiProtocol {
  private let _clientStorage = ThreadSafeClientWrapper()
  private var apiKey: String
  private var baseUrl: String
  private let decoder = JSONDecoder()
  private var httpRequests: HttpRequester
  private let logger = PortalLogger()
  private let requests: PortalRequestsProtocol
  private let featureFlags: FeatureFlags?

  private var address: String? {
    self.provider?.address
  }

  private var chainId: Int? {
    self.provider?.chainId
  }

  public var client: ClientResponse? {
    get async throws {
      try await _clientStorage.getOrCreateClient {
        try await self.getClient()
      }
    }
  }

  public weak var provider: PortalProviderProtocol?

  /// Create an instance of a PortalApi class.
  /// - Parameters:
  ///   - apiKey: The Client API key. You can create one using Portal's REST API.
  ///   - apiHost: (optional) The Portal API hostname.
  ///   - provider: The PortalProvider instance to use for stateful Provider info (chainId, address)
  public init(
    apiKey: String,
    apiHost: String = "api.portalhq.io",
    provider: PortalProviderProtocol? = nil,
    featureFlags: FeatureFlags? = nil,
    requests: PortalRequestsProtocol? = nil
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
        let body: [String: String] = [
          "clientPlatform": "NATIVE_IOS",
          "clientPlatformVersion": SDK_VERSION
        ]

        let data = try await post(url, withBearerToken: self.apiKey, andPayload: body)
        guard let ejectResponse = String(data: data, encoding: .utf8) else {
          throw PortalApiError.unableToReadStringResponse
        }

        return ejectResponse
      } catch {
        self.logger.error("PortalApi.eject() - Unable to eject: \(error.localizedDescription)")
        throw error
      }
    }

    self.logger.error("PortalApi.eject() - Unable to build request URL.")
    throw URLError(.badURL)
  }

  @available(*, deprecated, message: "This function has been moved to 'Portal'. Please use 'Portal.getBalances()' instead.") // this func need to be private thats why we deprecate it to move it to private later
  public func getBalances(_ chainId: String) async throws -> [FetchedBalance] {
    if let url = URL(string: "\(baseUrl)/api/v3/clients/me/balances?chainId=\(chainId)") {
      do {
        let data = try await get(url, withBearerToken: self.apiKey)
        let balancesResponse = try decoder.decode([FetchedBalance].self, from: data)

        return balancesResponse
      } catch {
        self.logger.error("PortalApi.getBalances() - Unable to get balances: \(error.localizedDescription)")
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

  public func getAssets(_ chainId: String) async throws -> AssetsResponse {
    if let url = URL(string: "\(baseUrl)/api/v3/clients/me/chains/\(chainId)/assets") {
      do {
        let data = try await get(url, withBearerToken: self.apiKey)
        let assets = try decoder.decode(AssetsResponse.self, from: data)

        return assets
      } catch {
        self.logger.error("PortalApi.getAssets() - Unable to fetch Assets: \(error.localizedDescription)")
        throw error
      }
    }

    self.logger.error("PortalApi.getNFTs() - Unable to build request URL.")
    throw URLError(.badURL)
  }

  public func getClientCipherText(_ backupSharePairId: String) async throws -> String {
    if let url = URL(string: "\(baseUrl)/api/v3/clients/me/backup-share-pairs/\(backupSharePairId)/cipher-text") {
      do {
        let data = try await get(url, withBearerToken: self.apiKey)
        let response = try decoder.decode(ClientCipherTextResponse.self, from: data)

        return response.cipherText
      } catch {
        throw error
      }
    }

    throw URLError(.badURL)
  }

  public func getQuote(_ swapsApiKey: String, withArgs: QuoteArgs, forChainId: String? = nil) async throws -> Quote {
    let chainId = forChainId != nil ? forChainId : "eip155:\(self.chainId ?? 1)"

    if let url = URL(string: "\(baseUrl)/api/v3/swaps/quote") {
      // Build the request body
      var body = withArgs.toDictionary()

      // Append Portal-provided values
      body["address"] = AnyCodable(self.address)
      body["apiKey"] = AnyCodable(swapsApiKey)
      body["chainId"] = AnyCodable(chainId)

      let data = try await post(url, withBearerToken: self.apiKey, andPayload: body)
      let response = try decoder.decode(Quote.self, from: data)

      return response
    }

    throw URLError(.badURL)
  }

  public func getNftAssets(_ chainId: String) async throws -> [NftAsset] {
    if let url = URL(string: "\(baseUrl)/api/v3/clients/me/chains/\(chainId)/assets/nfts") {
      do {
        let data = try await get(url, withBearerToken: self.apiKey)
        let nfts = try decoder.decode([NftAsset].self, from: data)

        return nfts
      } catch {
        self.logger.error("PortalApi.getNftAssets() - Unable to fetch NFT Assets: \(error.localizedDescription)")
        throw error
      }
    }

    self.logger.error("PortalApi.getNftAssets() - Unable to build request URL.")
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
    if let url = URL(string: "\(baseUrl)/api/v3/swaps/sources") {
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
      requestUrlString += "&" + queryParams.joined(separator: "&")
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

  public func identify(_ traits: [String: AnyCodable] = [:]) async throws -> MetricsResponse {
    if let url = URL(string: "\(baseUrl)/api/v1/analytics/identify") {
      let data = try await post(url, withBearerToken: self.apiKey, andPayload: ["traits": traits])
      let response = try decoder.decode(MetricsResponse.self, from: data)

      return response
    }

    throw URLError(.badURL)
  }

  public func prepareEject(_ walletId: String, _ backupMethod: BackupMethods) async throws -> String {
    if let url = URL(string: "\(baseUrl)/api/v3/clients/me/wallets/\(walletId)/prepare-eject") {
      let data = try await post(url, withBearerToken: self.apiKey, andPayload: ["backupMethod": backupMethod.rawValue])
      let prepareEjectResponse = try decoder.decode(PrepareEjectResponse.self, from: data)

      return prepareEjectResponse.share
    }

    throw URLError(.badURL)
  }

  public func refreshClient() async throws {
    do {
      try await _clientStorage.set(client: self.getClient())

      return
    } catch {
      self.logger.error("PortalApi.refreshClient() - Unable to refresh client: \(error.localizedDescription)")
      throw error
    }
  }

  /// Evaluate a transaction for the client.
  /// - Parameters:
  ///   - to: The recipient address.
  ///   - value: (Optional) The transaction "value" parameter.
  ///   - data: (Optional) The transaction "data" parameter.
  ///   - maxFeePerGas: (Optional) The transaction "maxFeePerGas" parameter.
  ///   - maxPriorityFeePerGas: (Optional) The transaction "maxPriorityFeePerGas" parameter.
  ///   - gas: (Optional) The transaction "gas" parameter.
  ///   - gasPrice: (Optional) The transaction "gasPrice" parameter.
  /// - Returns: BlockaidValidateTrxRes.
  public func evaluateTransaction(
    chainId: String,
    transaction: EvaluateTransactionParam,
    operationType: EvaluateTransactionOperationType? = nil
  ) async throws -> BlockaidValidateTrxRes {
    guard let chainId = chainId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
      throw PortalApiError.unableToEncodeData
    }
    if let url = URL(string: "\(baseUrl)/api/v3/clients/me/evaluate-transaction?chainId=\(chainId)") {
      do {
        var payload = transaction.toDictionary()
        if let operationType {
          payload["operationType"] = operationType.rawValue
        }
        let data = try await post(url, withBearerToken: self.apiKey, andPayload: payload)
        let response = try decoder.decode(BlockaidValidateTrxRes.self, from: data)

        return response
      } catch {
        self.logger.error("PortalApi.evaluateTransaction() - Unable to evaluate transaction: \(error.localizedDescription)")
        throw error
      }
    } else {
      self.logger.error("PortalApi.evaluateTransaction() - Unable to build request URL.")
      throw URLError(.badURL)
    }
  }

  public func storeClientCipherText(_ backupSharePairId: String, cipherText: String) async throws -> Bool {
    if let url = URL(string: "\(baseUrl)/api/v3/clients/me/backup-share-pairs/\(backupSharePairId)") {
      do {
        let payload = AnyCodable([
          "clientCipherText": cipherText
        ])
        _ = try await patch(url, withBearerToken: self.apiKey, andPayload: payload)

        return true
      } catch {
        self.logger.error("PortalApi.storeClientCipherText() - Unable to store client cipherText: \(error.localizedDescription)")
        throw error
      }
    }

    self.logger.error("PortalApi.storeClientCipherText() - Unable to build request URL.")
    throw URLError(.badURL)
  }

  public func track(_ event: String, withProperties: [String: AnyCodable]) async throws -> MetricsResponse {
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

  public func fund(chainId: String, params: FundParams) async throws -> FundResponse {
    if let url = URL(string: "\(baseUrl)/api/v3/clients/me/fund") {
      let payload = FundRequestBody(amount: params.amount, chainId: chainId, token: params.token)
      let data = try await post(url, withBearerToken: self.apiKey, andPayload: payload)
      let response = try decoder.decode(FundResponse.self, from: data)

      return response
    }

    throw URLError(.badURL)
  }

  public func buildEip155Transaction(chainId: String, params: BuildTransactionParam) async throws -> BuildEip115TransactionResponse {
    guard chainId.starts(with: "eip155:") else {
      throw PortalApiError.invalidChainId(message: "Invalid chainId: \(chainId). ChainId must start with 'eip155:'")
    }

    if let url = URL(string: "\(baseUrl)/api/v3/clients/me/chains/\(chainId)/assets/send/build-transaction") {
      let data = try await post(url, withBearerToken: self.apiKey, andPayload: params.toDictionary())
      let response = try decoder.decode(BuildEip115TransactionResponse.self, from: data)

      return response
    }

    throw URLError(.badURL)
  }

  public func buildSolanaTransaction(chainId: String, params: BuildTransactionParam) async throws -> BuildSolanaTransactionResponse {
    guard chainId.starts(with: "solana:") else {
      throw PortalApiError.invalidChainId(message: "Invalid chainId: \(chainId). ChainId must start with 'solana:'")
    }

    if let url = URL(string: "\(baseUrl)/api/v3/clients/me/chains/\(chainId)/assets/send/build-transaction") {
      let data = try await post(url, withBearerToken: self.apiKey, andPayload: params.toDictionary())
      let response = try decoder.decode(BuildSolanaTransactionResponse.self, from: data)

      return response
    }

    throw URLError(.badURL)
  }

  public func getWalletCapabilities() async throws -> WalletCapabilitiesResponse {
    if let url = URL(string: "\(baseUrl)/api/v3/clients/me/wallet_getCapabilities") {
      let data = try await get(url, withBearerToken: self.apiKey)
      let response = try decoder.decode(WalletCapabilitiesResponse.self, from: data)

      return response
    }

    throw URLError(.badURL)
  }

  /*******************************************
   * Private functions
   *******************************************/

  private func get(_ url: URL, withBearerToken: String? = nil) async throws -> Data {
    return try await self.requests.get(url, withBearerToken: withBearerToken)
  }

  private func patch(_ url: URL, withBearerToken: String? = nil, andPayload: Codable) async throws -> Data {
    return try await self.requests.patch(url, withBearerToken: withBearerToken, andPayload: andPayload)
  }

  private func post(_ url: URL, withBearerToken: String? = nil, andPayload: Codable? = nil) async throws -> Data {
    return try await self.requests.post(url, withBearerToken: withBearerToken, andPayload: andPayload)
  }

  /*******************************************
   * Deprecated functions
   *******************************************/

  /// Simulates a transaction for the client.
  /// - Parameters:
  ///   - to: The recipient address.
  ///   - value: (Optional) The transacton "value" parameter.
  ///   - data: (Optional) The transacton "data" parameter.
  ///   - maxFeePerGas: (Optional) The transacton "maxFeePerGas" parameter.
  ///   - maxPriorityFeePerGas: (Optional) The transacton "maxPriorityFeePerGas" parameter.
  ///   - gas: (Optional) The transacton "gas" parameter.
  ///   - gasPrice: (Optional) The transacton "gasPrice" parameter.
  /// - Returns: SimulatedTransaction.
  @available(*, deprecated, renamed: "evaluateTransaction", message: "Please use 'Portal.evaluateTransaction()' instead.")
  public func simulateTransaction(_ transaction: Any, withChainId: String) async throws -> SimulatedTransaction {
    guard let chainId = withChainId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
      throw PortalApiError.unableToEncodeData
    }
    if let url = URL(string: "\(baseUrl)/api/v3/clients/me/simulate-transaction?chainId=\(chainId)") {
      do {
        let transformedTransaction = AnyCodable(transaction)
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
    _ forChainId: String? = nil,
    completion: @escaping (Result<Quote>) -> Void
  ) throws {
    Task {
      do {
        let response = try await getQuote(swapsApiKey, withArgs: args, forChainId: forChainId)
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
  @available(*, deprecated, message: "This function has been moved to 'Portal'. Please use 'Portal.getBalances()' instead.")
  public func getBalances(
    completion: @escaping (Result<[FetchedBalance]>) -> Void
  ) throws {
    Task {
      do {
        let response = try await getBalances("eip155:\(self.chainId ?? 1)")
        completion(Result(data: response))
      } catch {
        completion(Result(error: error))
      }
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
  @available(*, deprecated, renamed: "evaluateTransaction", message: "Please use 'Portal.evaluateTransaction()' instead.")
  public func simulateTransaction(
    transaction: SimulateTransactionParam,
    completion: @escaping (Result<SimulatedTransaction>) -> Void
  ) throws {
    Task {
      do {
        let simulateTransactionParam = AnyCodable(transaction)
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
      "success": success
    ]

    // Conditionally add isMultiBackupEnabled if it's not nil
    if let isMultiBackupEnabled = self.featureFlags?.isMultiBackupEnabled {
      body["isMultiBackupEnabled"] = isMultiBackupEnabled
    }

    try self.httpRequests.put(
      path: "/api/v2/clients/me/wallet/stored-client-backup-share",
      body: body,
      headers: [
        "Authorization": "Bearer \(self.apiKey)"
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

  @available(*, deprecated, message: "Please use the async/await implementation of track().")
  func track(event: String, properties: [String: String], completion: ((Result<MetricsResponse>) -> Void)? = nil) {
    Task.init {
      do {
        let transformedProperties = properties.mapValues { AnyCodable($0) }
        let response = try await track(event, withProperties: transformedProperties)
        completion?(Result(data: response))
      } catch {
        completion?(Result(error: error))
      }
    }
  }
}

public enum PortalApiError: LocalizedError, Equatable {
  case unableToEncodeData
  case unableToReadStringResponse
  case invalidChainId(message: String)
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
