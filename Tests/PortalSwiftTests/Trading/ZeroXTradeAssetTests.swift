//
//  ZeroXTradeAssetTests.swift
//  PortalSwift
//
//  Created by Portal Labs
//

import Foundation
@testable import PortalSwift
import XCTest

// MARK: - Mock Portal Dependency

/// Mock implementation of `ZeroXPortalDependency` for testing `tradeAsset`.
final class ZeroXPortalDependencyMock: ZeroXPortalDependency {
  /// Hash returned for `eth_sendTransaction`.
  var sendTransactionHash: String? = "0xabc123"
  /// Error thrown for `eth_sendTransaction`.
  var sendTransactionError: Error?
  /// Status returned in the receipt for `eth_getTransactionReceipt` (e.g. "0x1", "0x0").
  var receiptStatus: String? = "0x1"
  /// When true, the first N receipt polls return a `nil` result (pending) before succeeding.
  var pendingPollsBeforeReceipt: Int = 0
  /// Error thrown for `eth_getTransactionReceipt`.
  var receiptError: Error?

  // Captured calls
  var sendTransactionCalls = 0
  var receiptCalls = 0
  var lastSendChainId: String?
  var lastSendParams: [Any]?

  func request(chainId: String, method: PortalRequestMethod, params: [Any], options _: RequestOptions?) async throws -> PortalProviderResult {
    switch method {
    case .eth_sendTransaction:
      sendTransactionCalls += 1
      lastSendChainId = chainId
      lastSendParams = params
      if let error = sendTransactionError {
        throw error
      }
      return PortalProviderResult(id: "1", result: sendTransactionHash as Any)

    case .eth_getTransactionReceipt:
      receiptCalls += 1
      if let error = receiptError {
        throw error
      }
      if receiptCalls <= pendingPollsBeforeReceipt {
        return PortalProviderResult(id: "1", result: EthTransactionResponse(id: 1, result: nil, error: nil))
      }
      let receipt = TransactionData.stubReceipt(status: receiptStatus)
      return PortalProviderResult(id: "1", result: EthTransactionResponse(id: 1, result: receipt, error: nil))

    default:
      return PortalProviderResult(id: "1", result: "" as Any)
    }
  }
}

extension TransactionData {
  /// Minimal receipt stub for confirmation tests.
  static func stubReceipt(status: String?) -> TransactionData {
    TransactionData(
      blockHash: "0xblockhash",
      blockNumber: "0x1",
      hash: "0xabc123",
      chainId: nil,
      from: "0xfrom",
      gas: nil,
      gasPrice: nil,
      input: nil,
      nonce: nil,
      r: nil,
      s: nil,
      to: "0xto",
      transactionIndex: "0x0",
      type: "0x2",
      v: nil,
      value: nil,
      accessList: nil,
      maxFeePerGas: nil,
      maxPriorityFeePerGas: nil,
      transactionHash: "0xabc123",
      logs: nil,
      contractAddress: nil,
      effectiveGasPrice: nil,
      cumulativeGasUsed: nil,
      gasUsed: nil,
      logsBloom: nil,
      status: status
    )
  }
}

final class ZeroXTradeAssetTests: XCTestCase {
  var apiMock: PortalZeroXTradingApiMock!
  var portalMock: ZeroXPortalDependencyMock!
  var zeroX: ZeroX!

  override func setUpWithError() throws {
    apiMock = PortalZeroXTradingApiMock()
    portalMock = ZeroXPortalDependencyMock()
    zeroX = ZeroX(api: apiMock, portal: portalMock)
    // Make polling fast for tests.
    zeroX.confirmationPollIntervalNanoseconds = 1_000_000 // 1ms
    zeroX.confirmationMaxAttempts = 5
  }

  override func tearDownWithError() throws {
    apiMock = nil
    portalMock = nil
    zeroX = nil
  }

  private func stubParams() -> ZeroXTradeAssetParams {
    ZeroXTradeAssetParams(
      chainId: "eip155:1",
      buyToken: "USDC",
      sellToken: "ETH",
      sellAmount: "1000000000000000000"
    )
  }
}

// MARK: - Happy Path

extension ZeroXTradeAssetTests {
  func test_tradeAsset_returnsHashOnSuccess() async throws {
    // given
    apiMock.getQuoteReturnValue = ZeroXQuoteResponse.stub()
    portalMock.sendTransactionHash = "0xdeadbeef"

    // when
    let result = try await zeroX.tradeAsset(params: stubParams())

    // then
    XCTAssertEqual(result.hashes, ["0xdeadbeef"])
    XCTAssertEqual(apiMock.getQuoteCalls, 1)
    XCTAssertEqual(portalMock.sendTransactionCalls, 1)
    XCTAssertGreaterThanOrEqual(portalMock.receiptCalls, 1)
  }

  func test_tradeAsset_emitsProgressInOrder() async throws {
    // given
    apiMock.getQuoteReturnValue = ZeroXQuoteResponse.stub()
    var statuses: [ZeroXTradeAssetProgressStatus] = []

    // when
    _ = try await zeroX.tradeAsset(params: stubParams()) { status, _ in
      statuses.append(status)
    }

    // then
    XCTAssertEqual(statuses, [.fetchingQuote, .signing, .submitted, .confirming, .confirmed])
  }

  func test_tradeAsset_passesZeroXApiKeyToQuote() async throws {
    // given
    apiMock.getQuoteReturnValue = ZeroXQuoteResponse.stub()
    let params = ZeroXTradeAssetParams(
      chainId: "eip155:1",
      buyToken: "USDC",
      sellToken: "ETH",
      sellAmount: "1000000000000000000",
      zeroXApiKey: "custom-key"
    )

    // when
    _ = try await zeroX.tradeAsset(params: params)

    // then
    XCTAssertEqual(apiMock.getQuoteZeroXApiKeyParam, "custom-key")
  }

  func test_tradeAsset_waitsForPendingReceipt() async throws {
    // given
    apiMock.getQuoteReturnValue = ZeroXQuoteResponse.stub()
    portalMock.pendingPollsBeforeReceipt = 2

    // when
    let result = try await zeroX.tradeAsset(params: stubParams())

    // then
    XCTAssertEqual(result.hashes.count, 1)
    XCTAssertEqual(portalMock.receiptCalls, 3)
  }
}

// MARK: - Failure Paths

extension ZeroXTradeAssetTests {
  func test_tradeAsset_throwsWhenPortalNotSet() async throws {
    // given
    let zeroXNoPortal = ZeroX(api: apiMock)
    var statuses: [ZeroXTradeAssetProgressStatus] = []

    // when / then
    do {
      _ = try await zeroXNoPortal.tradeAsset(params: stubParams()) { status, _ in statuses.append(status) }
      XCTFail("Expected error")
    } catch {
      XCTAssertEqual(error as? ZeroXTradeAssetError, .portalNotInitialized)
      XCTAssertEqual(statuses, [.failed])
    }
  }

  func test_tradeAsset_throwsOnQuoteError() async throws {
    // given
    apiMock.getQuoteReturnValue = ZeroXQuoteResponse(data: nil, error: "no liquidity")
    var statuses: [ZeroXTradeAssetProgressStatus] = []

    // when / then
    do {
      _ = try await zeroX.tradeAsset(params: stubParams()) { status, _ in statuses.append(status) }
      XCTFail("Expected error")
    } catch {
      XCTAssertEqual(error as? ZeroXTradeAssetError, .quoteError("no liquidity"))
      XCTAssertEqual(statuses, [.fetchingQuote, .failed])
      XCTAssertEqual(portalMock.sendTransactionCalls, 0)
    }
  }

  func test_tradeAsset_throwsWhenGetQuoteThrows() async throws {
    // given
    apiMock.getQuoteError = NSError(domain: "Test", code: 400, userInfo: nil)
    var statuses: [ZeroXTradeAssetProgressStatus] = []

    // when / then
    do {
      _ = try await zeroX.tradeAsset(params: stubParams()) { status, _ in statuses.append(status) }
      XCTFail("Expected error")
    } catch {
      XCTAssertEqual((error as NSError).code, 400)
      XCTAssertEqual(statuses, [.fetchingQuote, .failed])
    }
  }

  func test_tradeAsset_throwsOnMissingTransactionTo() async throws {
    // given
    let rawResponse = ZeroXQuoteRawResponse.stub(transaction: ZeroXTransaction.stub(to: ""))
    apiMock.getQuoteReturnValue = ZeroXQuoteResponse(data: ZeroXQuoteResponseData(rawResponse: rawResponse))
    var statuses: [ZeroXTradeAssetProgressStatus] = []

    // when / then
    do {
      _ = try await zeroX.tradeAsset(params: stubParams()) { status, _ in statuses.append(status) }
      XCTFail("Expected error")
    } catch {
      XCTAssertEqual(error as? ZeroXTradeAssetError, .missingTransaction)
      XCTAssertEqual(statuses, [.fetchingQuote, .failed])
    }
  }

  func test_tradeAsset_throwsOnEmptyHash() async throws {
    // given
    apiMock.getQuoteReturnValue = ZeroXQuoteResponse.stub()
    portalMock.sendTransactionHash = ""
    var statuses: [ZeroXTradeAssetProgressStatus] = []

    // when / then
    do {
      _ = try await zeroX.tradeAsset(params: stubParams()) { status, _ in statuses.append(status) }
      XCTFail("Expected error")
    } catch {
      XCTAssertEqual(error as? ZeroXTradeAssetError, .invalidTransactionHash)
      XCTAssertTrue(statuses.contains(.failed))
    }
  }

  func test_tradeAsset_throwsOnRevert() async throws {
    // given
    apiMock.getQuoteReturnValue = ZeroXQuoteResponse.stub()
    portalMock.receiptStatus = "0x0"
    var statuses: [ZeroXTradeAssetProgressStatus] = []

    // when / then
    do {
      _ = try await zeroX.tradeAsset(params: stubParams()) { status, _ in statuses.append(status) }
      XCTFail("Expected error")
    } catch {
      guard case .confirmationFailed = (error as? ZeroXTradeAssetError) else {
        return XCTFail("Expected confirmationFailed, got \(error)")
      }
      XCTAssertEqual(statuses.last, .failed)
    }
  }

  func test_tradeAsset_throwsOnConfirmationTimeout() async throws {
    // given - receipt always pending
    apiMock.getQuoteReturnValue = ZeroXQuoteResponse.stub()
    portalMock.pendingPollsBeforeReceipt = Int.max

    // when / then
    do {
      _ = try await zeroX.tradeAsset(params: stubParams())
      XCTFail("Expected error")
    } catch {
      guard case .confirmationFailed = (error as? ZeroXTradeAssetError) else {
        return XCTFail("Expected confirmationFailed, got \(error)")
      }
      XCTAssertEqual(portalMock.receiptCalls, 5)
    }
  }
}
