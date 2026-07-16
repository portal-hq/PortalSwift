//
//  PortalApiMock.swift
//
//
//  Created by Ahmed Ragab on 03/09/2024.
//

import AnyCodable
import Foundation
@testable import PortalSwift

class PortalApiMock: PortalApiProtocol {
  var yieldxyz: PortalSwift.PortalYieldXyzApiProtocol
  var lifi: PortalSwift.PortalLifiTradingApiProtocol
  var zeroX: PortalSwift.PortalZeroXTradingApiProtocol
  var hypernative: PortalSwift.PortalHypernativeApiProtocol
  var blockaid: PortalSwift.PortalBlockaidApiProtocol
  var delegations: PortalSwift.PortalDelegationsApiProtocol
  var evmAccountType: PortalSwift.PortalEvmAccountTypeApiProtocol
  var noah: PortalSwift.PortalNoahApiProtocol

  var client: PortalSwift.ClientResponse?

  init(
    yieldxyz: PortalSwift.PortalYieldXyzApiProtocol = PortalYieldXyzApiMock(),
    lifi: PortalSwift.PortalLifiTradingApiProtocol = PortalLifiTradingApiMock(),
    zeroX: PortalSwift.PortalZeroXTradingApiProtocol = PortalZeroXTradingApiMock(),
    hypernative: PortalSwift.PortalHypernativeApiProtocol = PortalHypernativeApiMock(),
    blockaid: PortalSwift.PortalBlockaidApiProtocol = PortalBlockaidApiMock(),
    delegations: PortalSwift.PortalDelegationsApiProtocol = PortalDelegationsApiMock(),
    evmAccountType: PortalSwift.PortalEvmAccountTypeApiProtocol = PortalEvmAccountTypeApiMock(),
    noah: PortalSwift.PortalNoahApiProtocol = PortalNoahApiMock(),
    client: PortalSwift.ClientResponse? = nil
  ) {
    self.yieldxyz = yieldxyz
    self.lifi = lifi
    self.zeroX = zeroX
    self.hypernative = hypernative
    self.blockaid = blockaid
    self.delegations = delegations
    self.evmAccountType = evmAccountType
    self.noah = noah
    self.client = client
  }

  var ejectReturnValue: String?
  var ejectCallsCount: Int = 0
  var ejectTraceIdParam: String?
  func eject(traceId: String?) async throws -> String {
    ejectCallsCount += 1
    ejectTraceIdParam = traceId
    return ejectReturnValue ?? ""
  }

  var getBalancesReturnValue: [PortalSwift.FetchedBalance]?
  func getBalances(_: String) async throws -> [PortalSwift.FetchedBalance] {
    getBalancesReturnValue ?? []
  }

  var fundReturnValue: PortalSwift.FundResponse?
  func fund(chainId _: String, params _: PortalSwift.FundParams) async throws -> PortalSwift.FundResponse {
    fundReturnValue!
  }

  var getClientReturnValue: PortalSwift.ClientResponse?
  var getClientTraceIdParam: String?
  func getClient(traceId: String?) async throws -> PortalSwift.ClientResponse {
    getClientTraceIdParam = traceId
    return getClientReturnValue ?? ClientResponse.stub()
  }

  var getClientCipherTextReturnValue: String?
  var getClientCipherTextCallsCount: Int = 0
  var getClientCipherTextTraceIdParam: String?
  func getClientCipherText(_: String, traceId: String?) async throws -> String {
    getClientCipherTextCallsCount += 1
    getClientCipherTextTraceIdParam = traceId
    return getClientCipherTextReturnValue ?? ""
  }

  var getQuoteReturnValue: Quote?
  func getQuote(_: String, withArgs _: PortalSwift.QuoteArgs, forChainId _: String?) async throws -> PortalSwift.Quote {
    getQuoteReturnValue ?? Quote.stub()
  }

  var getSharePairsReturnValue: [FetchedSharePair]?
  func getSharePairs(_: PortalSwift.PortalSharePairType, walletId _: String) async throws -> [PortalSwift.FetchedSharePair] {
    getSharePairsReturnValue ?? []
  }

  var getSourcesReturnValue: [String: String]?
  func getSources(_: String, forChainId _: String) async throws -> [String: String] {
    getSourcesReturnValue ?? [:]
  }

  var getTransactionsReturnValue: [FetchedTransaction]?
  func getTransactions(_: String, limit _: Int?, offset _: Int?, order _: PortalSwift.TransactionOrder?) async throws -> [PortalSwift.FetchedTransaction] {
    getTransactionsReturnValue ?? []
  }

  var getTransactionDetailsReturnValue: GetTransactionDetailsResponse?
  func getTransactionDetails(chain _: String, signature _: String) async throws -> GetTransactionDetailsResponse {
    guard let value = getTransactionDetailsReturnValue else {
      throw URLError(.badURL)
    }
    return value
  }

  var identifyReturnValue: PortalSwift.MetricsResponse?
  func identify(_: [String: AnyCodable]) async throws -> PortalSwift.MetricsResponse {
    return identifyReturnValue ?? MetricsResponse(status: true)
  }

  var prepareEjectReturnValue: String?
  var prepareEjectCallsCount: Int = 0
  var prepareEjectTraceIdParam: String?
  func prepareEject(_: String, _: PortalSwift.BackupMethods, traceId: String?) async throws -> String {
    prepareEjectCallsCount += 1
    prepareEjectTraceIdParam = traceId
    return prepareEjectReturnValue ?? ""
  }

  var refreshClientCallsCount = 0
  var refreshClientTraceIdParam: String?
  func refreshClient(traceId: String?) async throws {
    refreshClientCallsCount += 1
    refreshClientTraceIdParam = traceId
  }

  var generatePreGeneratedSharesCallsCount = 0
  var generatePreGeneratedSharesMetadataParam: String?
  var generatePreGeneratedSharesTraceIdParam: String?
  var generatePreGeneratedSharesReturnValue: PortalSwift.GenerateApiResponse?
  var generatePreGeneratedSharesErrorToThrow: Error?
  func generatePreGeneratedShares(metadataStr: String, traceId: String?) async throws -> PortalSwift.GenerateApiResponse {
    generatePreGeneratedSharesCallsCount += 1
    generatePreGeneratedSharesMetadataParam = metadataStr
    generatePreGeneratedSharesTraceIdParam = traceId
    if let error = generatePreGeneratedSharesErrorToThrow {
      throw error
    }
    guard let value = generatePreGeneratedSharesReturnValue else {
      throw URLError(.badURL)
    }
    return value
  }

  var simulateTransactionReturnValue: PortalSwift.SimulatedTransaction?
  func simulateTransaction(_: Any, withChainId _: String) async throws -> PortalSwift.SimulatedTransaction {
    return simulateTransactionReturnValue ?? SimulatedTransaction(changes: [])
  }

  var updateShareStatusCallsCount = 0
  var updateShareStatusSharePareTypeParam: PortalSharePairType?
  var updateShareStatusStatusParam: SharePairUpdateStatus?
  var updateShareStatusTraceIdParam: String?
  func updateShareStatus(_ type: PortalSwift.PortalSharePairType, status: PortalSwift.SharePairUpdateStatus, sharePairIds _: [String], traceId: String?) async throws {
    updateShareStatusSharePareTypeParam = type
    updateShareStatusStatusParam = status
    updateShareStatusTraceIdParam = traceId
    updateShareStatusCallsCount += 1
  }

  var storeClientCipherTextReturnValue: Bool?
  var storeClientCipherTextCallsCount: Int = 0
  var storeClientCipherTextTraceIdParam: String?
  func storeClientCipherText(_: String, cipherText _: String, traceId: String?) async throws -> Bool {
    storeClientCipherTextCallsCount += 1
    storeClientCipherTextTraceIdParam = traceId
    return storeClientCipherTextReturnValue ?? false
  }

  var trackReturnValue: PortalSwift.MetricsResponse?
  func track(_: String, withProperties _: [String: AnyCodable]) async throws -> PortalSwift.MetricsResponse {
    return trackReturnValue ?? MetricsResponse(status: true)
  }

  // Completion handlers for async functions

  var getClientCompletionReturnValue: PortalSwift.ClientResponse?
  func getClient(completion: @escaping (PortalSwift.Result<PortalSwift.ClientResponse>) -> Void) throws {
    if let result = getClientCompletionReturnValue {
      let res = Result(data: result)
      completion(res)
    } else {
      let res = Result<PortalSwift.ClientResponse>(error: NSError(domain: "", code: 0, userInfo: nil))
      completion(res)
    }
  }

  var getQuoteCompletionReturnValue: PortalSwift.Quote?
  func getQuote(_: String, _: PortalSwift.QuoteArgs, _: String?, completion: @escaping (PortalSwift.Result<PortalSwift.Quote>) -> Void) throws {
    if let result = getQuoteCompletionReturnValue {
      let res = Result(data: result)
      completion(res)
    } else {
      let res = Result<PortalSwift.Quote>(error: NSError(domain: "", code: 0, userInfo: nil))
      completion(res)
    }
  }

  var getSourcesCompletionReturnValue: [String: String]?
  func getSources(swapsApiKey _: String, completion: @escaping (PortalSwift.Result<[String: String]>) -> Void) throws {
    if let result = getSourcesCompletionReturnValue {
      let res = Result(data: result)
      completion(res)
    } else {
      let res = Result<[String: String]>(error: NSError(domain: "", code: 0, userInfo: nil))
      completion(res)
    }
  }

  var getTransactionsCompletionReturnValue: [PortalSwift.FetchedTransaction]?
  func getTransactions(limit _: Int?, offset _: Int?, order _: PortalSwift.GetTransactionsOrder?, chainId _: Int?, completion: @escaping (PortalSwift.Result<[PortalSwift.FetchedTransaction]>) -> Void) throws {
    if let result = getTransactionsCompletionReturnValue {
      let res = Result(data: result)
      completion(res)
    } else {
      let res = Result<[PortalSwift.FetchedTransaction]>(error: NSError(domain: "", code: 0, userInfo: nil))
      completion(res)
    }
  }

  var getBalancesCompletionReturnValue: [PortalSwift.FetchedBalance]?
  func getBalances(completion: @escaping (PortalSwift.Result<[PortalSwift.FetchedBalance]>) -> Void) throws {
    if let result = getBalancesCompletionReturnValue {
      let res = Result(data: result)
      completion(res)
    } else {
      let res = Result<[PortalSwift.FetchedBalance]>(error: NSError(domain: "", code: 0, userInfo: nil))
      completion(res)
    }
  }

  var simulateTransactionCompletionReturnValue: PortalSwift.SimulatedTransaction?
  func simulateTransaction(transaction _: PortalSwift.SimulateTransactionParam, completion: @escaping (PortalSwift.Result<PortalSwift.SimulatedTransaction>) -> Void) throws {
    if let result = simulateTransactionCompletionReturnValue {
      let res = Result(data: result)
      completion(res)
    } else {
      let res = Result<PortalSwift.SimulatedTransaction>(error: NSError(domain: "", code: 0, userInfo: nil))
      completion(res)
    }
  }

  var ejectClientCompletionReturnValue: String?
  func ejectClient(completion: @escaping (PortalSwift.Result<String>) -> Void) throws {
    if let result = ejectClientCompletionReturnValue {
      let res = Result(data: result)
      completion(res)
    } else {
      let res = Result<String>(error: NSError(domain: "", code: 0, userInfo: nil))
      completion(res)
    }
  }

  var storedClientBackupShareCompletionReturnValue: String?
  func storedClientBackupShare(success _: Bool, backupMethod _: PortalSwift.BackupMethods.RawValue, completion: @escaping (PortalSwift.Result<String>) -> Void) throws {
    if let result = storedClientBackupShareCompletionReturnValue {
      let res = Result(data: result)
      completion(res)
    } else {
      let res = Result<String>(error: NSError(domain: "", code: 0, userInfo: nil))
      completion(res)
    }
  }

  var getBackupShareMetadataCompletionReturnValue: [PortalSwift.FetchedSharePair]?
  func getBackupShareMetadata(completion: @escaping (PortalSwift.Result<[PortalSwift.FetchedSharePair]>) -> Void) throws {
    if let result = getBackupShareMetadataCompletionReturnValue {
      let res = Result(data: result)
      completion(res)
    } else {
      let res = Result<[PortalSwift.FetchedSharePair]>(error: NSError(domain: "", code: 0, userInfo: nil))
      completion(res)
    }
  }

  var getSigningShareMetadataCompletionReturnValue: [PortalSwift.FetchedSharePair]?
  func getSigningShareMetadata(completion: @escaping (PortalSwift.Result<[PortalSwift.FetchedSharePair]>) -> Void) throws {
    if let result = getSigningShareMetadataCompletionReturnValue {
      let res = Result(data: result)
      completion(res)
    } else {
      let res = Result<[PortalSwift.FetchedSharePair]>(error: NSError(domain: "", code: 0, userInfo: nil))
      completion(res)
    }
  }

  var evaluateTransactionReturnValue: BlockaidValidateTrxRes?
  func evaluateTransaction(chainId _: String, transaction _: EvaluateTransactionParam, operationType _: EvaluateTransactionOperationType?) async throws -> BlockaidValidateTrxRes {
    return evaluateTransactionReturnValue ?? BlockaidValidateTrxRes.stub()
  }

  var getNftAssetsReturnValue: [PortalSwift.NftAsset]?
  func getNftAssets(_: String) async throws -> [PortalSwift.NftAsset] {
    return getNftAssetsReturnValue ?? []
  }

  var buildEip115TransactionReturnValue: PortalSwift.BuildEip115TransactionResponse?
  func buildEip155Transaction(chainId _: String, params _: PortalSwift.BuildTransactionParam, traceId _: String?) async throws -> PortalSwift.BuildEip115TransactionResponse {
    return buildEip115TransactionReturnValue ?? PortalSwift.BuildEip115TransactionResponse.stub()
  }

  var buildSolanaTransactionReturnValue: PortalSwift.BuildSolanaTransactionResponse?
  func buildSolanaTransaction(chainId _: String, params _: PortalSwift.BuildTransactionParam, traceId _: String?) async throws -> PortalSwift.BuildSolanaTransactionResponse {
    return buildSolanaTransactionReturnValue ?? PortalSwift.BuildSolanaTransactionResponse.stub()
  }

  var buildBitcoinP2wpkhTransactionReturnValue: PortalSwift.BuildBitcoinP2wpkhTransactionResponse?
  func buildBitcoinP2wpkhTransaction(chainId _: String, params _: PortalSwift.BuildTransactionParam, traceId _: String?) async throws -> PortalSwift.BuildBitcoinP2wpkhTransactionResponse {
    return buildBitcoinP2wpkhTransactionReturnValue ?? PortalSwift.BuildBitcoinP2wpkhTransactionResponse.stub()
  }

  var broadcastBitcoinP2wpkhTransactionReturnValue: PortalSwift.BroadcastBitcoinP2wpkhTransactionResponse?
  func broadcastBitcoinP2wpkhTransaction(chainId _: String, params _: PortalSwift.BroadcastParam, traceId _: String?) async throws -> PortalSwift.BroadcastBitcoinP2wpkhTransactionResponse {
    return broadcastBitcoinP2wpkhTransactionReturnValue ?? PortalSwift.BroadcastBitcoinP2wpkhTransactionResponse.stub()
  }

  var getAssetsReturnValue: PortalSwift.AssetsResponse?
  func getAssets(_: String) async throws -> PortalSwift.AssetsResponse {
    return getAssetsReturnValue ?? PortalSwift.AssetsResponse.stub()
  }

  var getWalletCapabilitiesTraceIdParam: String?
  func getWalletCapabilities(traceId: String?) async throws -> PortalSwift.WalletCapabilitiesResponse {
    getWalletCapabilitiesTraceIdParam = traceId
    return [:]
  }
}
