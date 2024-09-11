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
  var client: PortalSwift.ClientResponse?

  var ejectReturnValue: String?
  var ejectCallsCount: Int = 0
  func eject() async throws -> String {
    ejectCallsCount += 1
    return ejectReturnValue ?? ""
  }

  var getBalancesReturnValue: [PortalSwift.FetchedBalance]?
  func getBalances(_: String) async throws -> [PortalSwift.FetchedBalance] {
    getBalancesReturnValue ?? []
  }

  var getClientReturnValue: PortalSwift.ClientResponse?
  func getClient() async throws -> PortalSwift.ClientResponse {
    getClientReturnValue ?? ClientResponse.stub()
  }

  var getClientCipherTextReturnValue: String?
  var getClientCipherTextCallsCount: Int = 0
  func getClientCipherText(_: String) async throws -> String {
    getClientCipherTextCallsCount += 1
    return getClientCipherTextReturnValue ?? ""
  }

  var getQuoteReturnValue: Quote?
  func getQuote(_: String, withArgs _: PortalSwift.QuoteArgs, forChainId _: String?) async throws -> PortalSwift.Quote {
    getQuoteReturnValue ?? Quote.stub()
  }

  var getNFTsReturnValue: [FetchedNFT]?
  func getNFTs(_: String) async throws -> [PortalSwift.FetchedNFT] {
    getNFTsReturnValue ?? []
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

  var identifyReturnValue: PortalSwift.MetricsResponse?
  func identify(_: [String: AnyCodable]) async throws -> PortalSwift.MetricsResponse {
    return identifyReturnValue ?? MetricsResponse(status: true)
  }

  var prepareEjectReturnValue: String?
  var prepareEjectCallsCount: Int = 0
  func prepareEject(_: String, _: PortalSwift.BackupMethods) async throws -> String {
    prepareEjectCallsCount += 1
    return prepareEjectReturnValue ?? ""
  }

  var refreshClientCalled = false
  func refreshClient() async throws {
    refreshClientCalled = true
  }

  var simulateTransactionReturnValue: PortalSwift.SimulatedTransaction?
  func simulateTransaction(_: Any, withChainId _: String) async throws -> PortalSwift.SimulatedTransaction {
    return simulateTransactionReturnValue ?? SimulatedTransaction(changes: [])
  }

  var updateShareStatusCalled = false
  func updateShareStatus(_: PortalSwift.PortalSharePairType, status _: PortalSwift.SharePairUpdateStatus, sharePairIds _: [String]) async throws {
    updateShareStatusCalled = true
  }

  var storeClientCipherTextReturnValue: Bool?
  var storeClientCipherTextCallsCount: Int = 0
  func storeClientCipherText(_: String, cipherText _: String) async throws -> Bool {
    storeClientCipherTextCallsCount += 1
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

  var getNFTsCompletionReturnValue: [PortalSwift.FetchedNFT]?
  func getNFTs(completion: @escaping (PortalSwift.Result<[PortalSwift.FetchedNFT]>) -> Void) throws {
    if let result = getNFTsCompletionReturnValue {
      let res = Result(data: result)
      completion(res)
    } else {
      let res = Result<[PortalSwift.FetchedNFT]>(error: NSError(domain: "", code: 0, userInfo: nil))
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
}
