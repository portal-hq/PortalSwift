//
//  PortalApiSpy.swift
//
//
//  Created by Ahmed Ragab on 21/08/2024.
//

import AnyCodable
import Foundation
@testable import PortalSwift

class PortalApiSpy: PortalApiProtocol {
  var yieldxyz: any PortalSwift.PortalYieldXyzApiProtocol
  var lifi: any PortalSwift.PortalLifiTradingApiProtocol
  var zeroX: any PortalSwift.PortalZeroXTradingApiProtocol
  var hypernative: any PortalSwift.PortalHypernativeApiProtocol

  init(
    yieldxyz: any PortalSwift.PortalYieldXyzApiProtocol = PortalYieldXyzApiSpy(),
    lifi: any PortalSwift.PortalLifiTradingApiProtocol = PortalLifiTradingApiSpy(),
    zeroX: any PortalSwift.PortalZeroXTradingApiProtocol = PortalZeroXTradingApiMock(),
    hypernative: any PortalSwift.PortalHypernativeApiProtocol = PortalHypernativeApiMock()
  ) {
    self.yieldxyz = yieldxyz
    self.lifi = lifi
    self.zeroX = zeroX
    self.hypernative = hypernative
  }

  // Property to track client access
  var clientCallsCount: Int = 0

  var mockClient: ClientResponse?

  public var client: ClientResponse? {
    get async throws {
      clientCallsCount += 1
      return mockClient
    }
  }

  // Eject method tracking
  var ejectCallsCount: Int = 0

  public func eject() async throws -> String {
    ejectCallsCount += 1
    return ""
  }

  // Get Balances method tracking
  var getBalancesCallsCount: Int = 0
  var getBalancesChainIdParam: String?

  public func getBalances(_ chainId: String) async throws -> [FetchedBalance] {
    getBalancesCallsCount += 1
    getBalancesChainIdParam = chainId
    return []
  }

  // Get Client method tracking
  var getClientCallsCount: Int = 0

  public func getClient() async throws -> ClientResponse {
    getClientCallsCount += 1
    return ClientResponse.stub()
  }

  // Get Client Cipher Text method tracking
  var getClientCipherTextCallsCount: Int = 0
  var getClientCipherTextBackupSharePairIdParam: String?

  public func getClientCipherText(_ backupSharePairId: String) async throws -> String {
    getClientCipherTextCallsCount += 1
    getClientCipherTextBackupSharePairIdParam = backupSharePairId
    return ""
  }

  // Get Quote method tracking
  var getQuoteCallsCount: Int = 0
  var getQuoteSwapsApiKeyParam: String?
  var getQuoteArgsParam: QuoteArgs?
  var getQuoteForChainIdParam: String?

  public func getQuote(_ swapsApiKey: String, withArgs args: QuoteArgs, forChainId: String?) async throws -> Quote {
    getQuoteCallsCount += 1
    getQuoteSwapsApiKeyParam = swapsApiKey
    getQuoteArgsParam = args
    getQuoteForChainIdParam = forChainId
    return Quote.stub()
  }

  // Get NFTs method tracking
  var getNFTsCallsCount: Int = 0
  var getNFTsChainIdParam: String?

  // Get Share Pairs method tracking
  var getSharePairsCallsCount: Int = 0
  var getSharePairsTypeParam: PortalSharePairType?
  var getSharePairsWalletIdParam: String?

  public func getSharePairs(_ type: PortalSharePairType, walletId: String) async throws -> [FetchedSharePair] {
    getSharePairsCallsCount += 1
    getSharePairsTypeParam = type
    getSharePairsWalletIdParam = walletId
    return []
  }

  // Get Sources method tracking
  var getSourcesCallsCount: Int = 0
  var getSourcesSwapsApiKeyParam: String?
  var getSourcesForChainIdParam: String?

  public func getSources(_ swapsApiKey: String, forChainId: String) async throws -> [String: String] {
    getSourcesCallsCount += 1
    getSourcesSwapsApiKeyParam = swapsApiKey
    getSourcesForChainIdParam = forChainId
    return [:]
  }

  // Get Transactions method tracking
  var getTransactionsCallsCount: Int = 0
  var getTransactionsChainIdParam: String?
  var getTransactionsLimitParam: Int?
  var getTransactionsOffsetParam: Int?
  var getTransactionsOrderParam: TransactionOrder?

  public func getTransactions(_ chainId: String, limit: Int?, offset: Int?, order: TransactionOrder?) async throws -> [FetchedTransaction] {
    getTransactionsCallsCount += 1
    getTransactionsChainIdParam = chainId
    getTransactionsLimitParam = limit
    getTransactionsOffsetParam = offset
    getTransactionsOrderParam = order
    return []
  }

  // Get Transactions method tracking
  var fundCallsCount: Int = 0
  var fundChainIdParam: String?
  var fundParams: FundParams?

  public func fund(chainId: String, params: FundParams) async throws -> FundResponse {
    fundCallsCount += 1
    fundChainIdParam = chainId
    fundParams = params
    return FundResponse.stub()
  }

  // Identify method tracking
  var identifyCallsCount: Int = 0
  var identifyTraitsParam: [String: AnyCodable]?

  public func identify(_ traits: [String: AnyCodable]) async throws -> MetricsResponse {
    identifyCallsCount += 1
    identifyTraitsParam = traits
    return MetricsResponse(status: true)
  }

  // Prepare Eject method tracking
  var prepareEjectCallsCount: Int = 0
  var prepareEjectWalletIdParam: String?
  var prepareEjectBackupMethodParam: BackupMethods?

  public func prepareEject(_ walletId: String, _ backupMethod: BackupMethods) async throws -> String {
    prepareEjectCallsCount += 1
    prepareEjectWalletIdParam = walletId
    prepareEjectBackupMethodParam = backupMethod
    return ""
  }

  // Refresh Client method tracking
  var refreshClientCallsCount: Int = 0

  public func refreshClient() async throws {
    refreshClientCallsCount += 1
  }

  // Simulate Transaction method tracking
  var simulateTransactionCallsCount: Int = 0
  var simulateTransactionTransactionParam: Any?
  var simulateTransactionWithChainIdParam: String?

  public func simulateTransaction(_ transaction: Any, withChainId: String) async throws -> SimulatedTransaction {
    simulateTransactionCallsCount += 1
    simulateTransactionTransactionParam = transaction
    simulateTransactionWithChainIdParam = withChainId
    return SimulatedTransaction(changes: [])
  }

  // Update Share Status method tracking
  var updateShareStatusCallsCount: Int = 0
  var updateShareStatusTypeParam: PortalSharePairType?
  var updateShareStatusStatusParam: SharePairUpdateStatus?
  var updateShareStatusSharePairIdsParam: [String]?

  public func updateShareStatus(_ type: PortalSharePairType, status: SharePairUpdateStatus, sharePairIds: [String]) async throws {
    updateShareStatusCallsCount += 1
    updateShareStatusTypeParam = type
    updateShareStatusStatusParam = status
    updateShareStatusSharePairIdsParam = sharePairIds
  }

  // getClient method with completion tracking
  var getClientWithCompletionCallsCount: Int = 0
  var getClientWithCompletionResult: Result<ClientResponse>?

  public func getClient(completion: @escaping (Result<ClientResponse>) -> Void) throws {
    getClientWithCompletionCallsCount += 1
    completion(getClientWithCompletionResult ?? Result(error: NSError()))
  }

  // getQuote method with completion tracking
  var getQuoteWithCompletionCallsCount: Int = 0
  var getQuoteWithCompletionSwapsApiKeyParam: String?
  var getQuoteWithCompletionArgsParam: QuoteArgs?
  var getQuoteWithCompletionForChainIdParam: String?
  var getQuoteWithCompletionResult: Result<Quote>?

  public func getQuote(_ swapsApiKey: String, _ args: QuoteArgs, _ forChainId: String?, completion: @escaping (Result<Quote>) -> Void) throws {
    getQuoteWithCompletionCallsCount += 1
    getQuoteWithCompletionSwapsApiKeyParam = swapsApiKey
    getQuoteWithCompletionArgsParam = args
    getQuoteWithCompletionForChainIdParam = forChainId
    completion(getQuoteWithCompletionResult ?? Result(error: NSError()))
  }

  // getSources method with completion tracking
  var getSourcesWithCompletionCallsCount: Int = 0
  var getSourcesWithCompletionSwapsApiKeyParam: String?
  var getSourcesWithCompletionResult: Result<[String: String]>?

  public func getSources(swapsApiKey: String, completion: @escaping (Result<[String: String]>) -> Void) throws {
    getSourcesWithCompletionCallsCount += 1
    getSourcesWithCompletionSwapsApiKeyParam = swapsApiKey
    completion(getSourcesWithCompletionResult ?? Result(error: NSError()))
  }

  // getTransactions method with completion tracking
  var getTransactionsWithCompletionCallsCount: Int = 0
  var getTransactionsWithCompletionLimitParam: Int?
  var getTransactionsWithCompletionOffsetParam: Int?
  var getTransactionsWithCompletionOrderParam: GetTransactionsOrder?
  var getTransactionsWithCompletionChainIdParam: Int?
  var getTransactionsWithCompletionResult: Result<[FetchedTransaction]>?

  public func getTransactions(limit: Int?, offset: Int?, order: GetTransactionsOrder?, chainId: Int?, completion: @escaping (Result<[FetchedTransaction]>) -> Void) throws {
    getTransactionsWithCompletionCallsCount += 1
    getTransactionsWithCompletionLimitParam = limit
    getTransactionsWithCompletionOffsetParam = offset
    getTransactionsWithCompletionOrderParam = order
    getTransactionsWithCompletionChainIdParam = chainId
    completion(getTransactionsWithCompletionResult ?? Result(error: NSError()))
  }

  // getBalances method with completion tracking
  var getBalancesWithCompletionCallsCount: Int = 0
  var getBalancesWithCompletionResult: Result<[FetchedBalance]>?

  public func getBalances(completion: @escaping (Result<[FetchedBalance]>) -> Void) throws {
    getBalancesWithCompletionCallsCount += 1
    completion(getBalancesWithCompletionResult ?? Result(error: NSError()))
  }

  // simulateTransaction method with completion tracking
  var simulateTransactionWithCompletionCallsCount: Int = 0
  var simulateTransactionWithCompletionTransactionParam: SimulateTransactionParam?
  var simulateTransactionWithCompletionResult: Result<SimulatedTransaction>?

  public func simulateTransaction(transaction: SimulateTransactionParam, completion: @escaping (Result<SimulatedTransaction>) -> Void) throws {
    simulateTransactionWithCompletionCallsCount += 1
    simulateTransactionWithCompletionTransactionParam = transaction
    completion(simulateTransactionWithCompletionResult ?? Result(error: NSError()))
  }

  // ejectClient method with completion tracking
  var ejectClientWithCompletionCallsCount: Int = 0
  var ejectClientWithCompletionResult: Result<String>?

  public func ejectClient(completion: @escaping (Result<String>) -> Void) throws {
    ejectClientWithCompletionCallsCount += 1
    completion(ejectClientWithCompletionResult ?? Result(error: NSError()))
  }

  // storedClientBackupShare method tracking
  var storedClientBackupShareCallsCount: Int = 0
  var storedClientBackupShareSuccessParam: Bool?
  var storedClientBackupShareBackupMethodParam: BackupMethods.RawValue?
  var storedClientBackupShareResult: Result<String>?

  public func storedClientBackupShare(success: Bool, backupMethod: BackupMethods.RawValue, completion: @escaping (Result<String>) -> Void) throws {
    storedClientBackupShareCallsCount += 1
    storedClientBackupShareSuccessParam = success
    storedClientBackupShareBackupMethodParam = backupMethod
    completion(storedClientBackupShareResult ?? Result(error: NSError()))
  }

  // getBackupShareMetadata method with completion tracking
  var getBackupShareMetadataWithCompletionCallsCount: Int = 0
  var getBackupShareMetadataWithCompletionResult: Result<[FetchedSharePair]>?

  public func getBackupShareMetadata(completion: @escaping (Result<[FetchedSharePair]>) -> Void) throws {
    getBackupShareMetadataWithCompletionCallsCount += 1
    completion(getBackupShareMetadataWithCompletionResult ?? Result(error: NSError()))
  }

  // getSigningShareMetadata method with completion tracking
  var getSigningShareMetadataWithCompletionCallsCount: Int = 0
  var getSigningShareMetadataWithCompletionResult: Result<[FetchedSharePair]>?

  public func getSigningShareMetadata(completion: @escaping (Result<[FetchedSharePair]>) -> Void) throws {
    getSigningShareMetadataWithCompletionCallsCount += 1
    completion(getSigningShareMetadataWithCompletionResult ?? Result(error: NSError()))
  }

  // storeClientCipherText method tracking
  var storeClientCipherTextCallsCount: Int = 0
  var storeClientCipherTextBackupSharePairIdParam: String?
  var storeClientCipherTextCipherTextParam: String?

  func storeClientCipherText(_ backupSharePairId: String, cipherText: String) async throws -> Bool {
    storeClientCipherTextCallsCount += 1
    storeClientCipherTextBackupSharePairIdParam = backupSharePairId
    storeClientCipherTextCipherTextParam = cipherText

    return true
  }

  // track method tracking
  var trackCallsCount: Int = 0
  var trackEventParam: String?
  var trackWithPropertiesParam: [String: AnyCodable]?

  func track(_ event: String, withProperties: [String: AnyCodable]) async throws -> PortalSwift.MetricsResponse {
    trackCallsCount += 1
    trackEventParam = event
    trackWithPropertiesParam = withProperties

    return MetricsResponse(status: true)
  }

  // evaluateTransaction method tracking
  var evaluateTransactionCallsCount: Int = 0
  var evaluateTransactionChainIdParam: String?
  var evaluateTransactionTransactionParam: EvaluateTransactionParam?
  var evaluateTransactionOperationType: EvaluateTransactionOperationType?

  func evaluateTransaction(chainId: String, transaction: EvaluateTransactionParam, operationType: EvaluateTransactionOperationType?) async throws -> BlockaidValidateTrxRes {
    evaluateTransactionCallsCount += 1
    evaluateTransactionChainIdParam = chainId
    evaluateTransactionTransactionParam = transaction
    evaluateTransactionOperationType = operationType
    return BlockaidValidateTrxRes.stub()
  }

  // getNftAssets method tracking
  var getNftAssetsCallsCount: Int = 0
  var getNftAssetsChainIdParam: String?

  func getNftAssets(_ chainId: String) async throws -> [PortalSwift.NftAsset] {
    getNftAssetsCallsCount += 1
    getNftAssetsChainIdParam = chainId
    return []
  }

  // buildEip155Transaction method tracking
  var buildEip155TransactionCallsCount: Int = 0
  var buildEip155TransactionChainIdParam: String?
  var buildEip155TransactionParams: PortalSwift.BuildTransactionParam?

  func buildEip155Transaction(chainId: String, params: PortalSwift.BuildTransactionParam) async throws -> PortalSwift.BuildEip115TransactionResponse {
    buildEip155TransactionCallsCount += 1
    buildEip155TransactionChainIdParam = chainId
    buildEip155TransactionParams = params
    return PortalSwift.BuildEip115TransactionResponse.stub()
  }

  // buildSolanaTransaction method tracking
  var buildSolanaTransactionCallsCount: Int = 0
  var buildSolanaTransactionChainIdParam: String?
  var buildSolanaTransactionParams: PortalSwift.BuildTransactionParam?

  func buildSolanaTransaction(chainId: String, params: PortalSwift.BuildTransactionParam) async throws -> PortalSwift.BuildSolanaTransactionResponse {
    buildSolanaTransactionCallsCount += 1
    buildSolanaTransactionChainIdParam = chainId
    buildSolanaTransactionParams = params
    return PortalSwift.BuildSolanaTransactionResponse.stub()
  }

  // MARK: - Bitcoin P2WPKH build transaction spy tracking

  var buildBitcoinP2wpkhTransactionCallsCount: Int = 0
  var buildBitcoinP2wpkhTransactionChainIdParam: String?
  var buildBitcoinP2wpkhTransactionParams: PortalSwift.BuildTransactionParam?
  var buildBitcoinP2wpkhTransactionReturnValue: PortalSwift.BuildBitcoinP2wpkhTransactionResponse?

  func buildBitcoinP2wpkhTransaction(
    chainId: String,
    params: PortalSwift.BuildTransactionParam
  ) async throws -> PortalSwift.BuildBitcoinP2wpkhTransactionResponse {
    buildBitcoinP2wpkhTransactionCallsCount += 1
    buildBitcoinP2wpkhTransactionChainIdParam = chainId
    buildBitcoinP2wpkhTransactionParams = params
    return buildBitcoinP2wpkhTransactionReturnValue ?? PortalSwift.BuildBitcoinP2wpkhTransactionResponse.stub()
  }

  // MARK: - Bitcoin P2WPKH broadcast transaction spy tracking

  var broadcastBitcoinP2wpkhTransactionCallsCount: Int = 0
  var broadcastBitcoinP2wpkhTransactionChainIdParam: String?
  var broadcastBitcoinP2wpkhTransactionParams: PortalSwift.BroadcastParam?

  func broadcastBitcoinP2wpkhTransaction(
    chainId: String,
    params: PortalSwift.BroadcastParam
  ) async throws -> PortalSwift.BroadcastBitcoinP2wpkhTransactionResponse {
    broadcastBitcoinP2wpkhTransactionCallsCount += 1
    broadcastBitcoinP2wpkhTransactionChainIdParam = chainId
    broadcastBitcoinP2wpkhTransactionParams = params
    return PortalSwift.BroadcastBitcoinP2wpkhTransactionResponse.stub()
  }

  // getAssets method tracking
  var getAssetsCallsCount: Int = 0
  var getAssetsChainIdParam: String?

  func getAssets(_ chainId: String) async throws -> PortalSwift.AssetsResponse {
    getAssetsCallsCount += 1
    getAssetsChainIdParam = chainId
    return PortalSwift.AssetsResponse.stub()
  }

  // getWalletCapabilities method tracking
  var getWalletCapabilitiesCallsCount: Int = 0

  func getWalletCapabilities() async throws -> PortalSwift.WalletCapabilitiesResponse {
    getWalletCapabilitiesCallsCount += 1
    return PortalSwift.WalletCapabilitiesResponse.stub()
  }
}
