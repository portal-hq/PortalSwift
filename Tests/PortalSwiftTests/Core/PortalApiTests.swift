//
//  PortalApiTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import AnyCodable
@testable import PortalSwift
import XCTest

final class PortalApiTests: XCTestCase {
  private let encoder = JSONEncoder()

  var api: PortalApi?

  override func setUpWithError() throws {
    self.api = PortalApi(apiKey: MockConstants.mockApiKey, apiHost: MockConstants.mockHost, requests: MockPortalRequests())
  }

  override func tearDownWithError() throws {
    api = nil
  }

  func testGetBackupShareMetadataCompletion() throws {
    let expectation = XCTestExpectation(description: "PortalApi.getBackupShareMetadata(completion)")
    try api?.getBackupShareMetadata { result in
      XCTAssert(result.data?.count ?? 0 > 0)
      XCTAssert(result.data?[0].id == MockConstants.mockFetchedShairPair.id)
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 5.0)
  }

  func testGetSigningShareMetadataCompletion() throws {
    let expectation = XCTestExpectation(description: "PortalApi.getSigningShareMetadata(completion)")
    try api?.getSigningShareMetadata { result in
      XCTAssert(result.data?.count ?? 0 > 0)
      XCTAssert(result.data?[0].id == MockConstants.mockFetchedShairPair.id)
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 5.0)
  }

  func getGetTransactionsCompletion() throws {
    let expectation = XCTestExpectation(description: "PortalApi.getTransactions(completion)")
    let mockFetchedTransaction = MockConstants.mockFetchedTransaction
    try self.api?.getTransactions { result in
      XCTAssert(result.data?.count ?? 0 > 0)
      XCTAssert(result.data?[0].blockNum == mockFetchedTransaction.blockNum)
      XCTAssert(result.data?[0].chainId == mockFetchedTransaction.chainId)
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 5.0)
  }

  func testUpdateBackupShareStatus() async throws {
    let expectation = XCTestExpectation(description: "PortalApi.updateShareStatus(.backup)")
    try await api?.updateShareStatus(.backup, status: .STORED_CLIENT_BACKUP_SHARE_KEY, sharePairIds: [MockConstants.mockMpcShareId])
    try await self.api?.updateShareStatus(.backup, status: .STORED_CLIENT_BACKUP_SHARE, sharePairIds: [MockConstants.mockMpcShareId])
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testUpdateSigningShareStatus() async throws {
    let expectation = XCTestExpectation(description: "PortalApi.updateShareStatus(.signing)")
    try await api?.updateShareStatus(.signing, status: .STORED_CLIENT, sharePairIds: [MockConstants.mockMpcShareId])
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }
}

// MARK: - Test Helpers

extension PortalApiTests {
  func initPortalApiWith(
    apiHost: String = MockConstants.mockHost,
    requests: PortalRequestsProtocol = MockPortalRequests()
  ) {
    self.api = PortalApi(
      apiKey: MockConstants.mockApiKey,
      apiHost: apiHost,
      requests: requests
    )
  }
}

// MARK: - eject tests

extension PortalApiTests {
  func testEject() async throws {
    let expectation = XCTestExpectation(description: "PortalApi.eject()")
    let ejectResponse = try await api?.eject()
    print("⚠️ Eject response:", ejectResponse ?? "")
    XCTAssertEqual(ejectResponse, MockConstants.mockEjectResponse)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func test_eject_willCall_requestPost_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    // and given
    _ = try await api?.eject()

    // then
    XCTAssertEqual(portalRequestsSpy.postCallsCount, 1)
  }

  @available(iOS 16.0, *)
  func test_eject_willCall_requestPost_passingCorrectParams() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    // and given
    _ = try await api?.eject()

    // then
    XCTAssertEqual(portalRequestsSpy.postFromParam?.path() ?? "", "/api/v3/clients/me/eject")
    XCTAssertEqual(portalRequestsSpy.postAndPayloadParam as? [String: String] ?? [:], [
      "clientPlatform": "NATIVE_IOS",
      "clientPlatformVersion": SDK_VERSION
    ])
  }

  func test_eject_willThrowCorrectError_whenRequestPostThrowError() async throws {
    // given
    let portalRequestsFailMock = PortalRequestsFailMock()
    initPortalApiWith(requests: portalRequestsFailMock)

    do {
      // and given
      _ = try await api?.eject()
      XCTFail("Expected error not thrown when calling PortalApi.eject when Request throws error.")
    } catch {
      // then
      XCTAssertEqual(error as? URLError, portalRequestsFailMock.errorToThrow)
    }
  }
}

// MARK: - getBalances tests

extension PortalApiTests {
  func testGetBalances() async throws {
    let expectation = XCTestExpectation(description: "PortalApi.getSharePairs(.backup)")
    let mockFetchedBalance = MockConstants.mockedFetchedBalance
    let balancesResponse = try await api?.getBalances("eip155:11155111")
    XCTAssert(balancesResponse?.count ?? 0 > 0)
    XCTAssert(balancesResponse?[0].contractAddress == mockFetchedBalance.contractAddress)
    XCTAssert(balancesResponse?[0].balance == mockFetchedBalance.balance)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func test_getBalances_willCall_requestGet_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.getBalances("")
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.getCallsCount, 1)
  }

  func test_getBalances_willThrowCorrectError_whenRequestPostThrowError() async throws {
    // given
    let portalRequestsFailMock = PortalRequestsFailMock()
    initPortalApiWith(requests: portalRequestsFailMock)

    do {
      // and given
      _ = try await api?.getBalances("")
      XCTFail("Expected error not thrown when calling PortalApi.getBalances when Request throws error.")
    } catch {
      // then
      XCTAssertEqual(error as? URLError, portalRequestsFailMock.errorToThrow)
    }
  }
}

// MARK: - getClient tests

extension PortalApiTests {
  func testGetClient() async throws {
    let expectation = XCTestExpectation(description: "PortalApi.getClient()")
    let mockClientResponse = MockConstants.mockClient
    let clientResponse = try await api?.getClient()
    XCTAssert(!(clientResponse?.id.isEmpty ?? false))
    XCTAssert(clientResponse?.id == mockClientResponse.id)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testGetClientCompletion() throws {
    let expectation = XCTestExpectation(description: "PortalApi.getClient(completion)")
    let mockClientResponse = MockConstants.mockClient
    try self.api?.getClient { result in
      XCTAssert(result.data?.id == mockClientResponse.id)
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 5.0)
  }

  func test_getClient_willCall_requestGet_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.getClient()
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.getCallsCount, 1)
  }

  func test_getClient_willThrowCorrectError_whenRequestPostThrowError() async throws {
    // given
    let portalRequestsFailMock = PortalRequestsFailMock()
    initPortalApiWith(requests: portalRequestsFailMock)

    do {
      // and given
      _ = try await api?.getClient()
      XCTFail("Expected error not thrown when calling PortalApi.getBalances when Request throws error.")
    } catch {
      // then
      XCTAssertEqual(error as? URLError, portalRequestsFailMock.errorToThrow)
    }
  }
}

// MARK: - getClientCipherText tests

extension PortalApiTests {
  func test_getClientCipherText() async throws {
    // given
    let dummyCipherText = "dummy-cipher-text"
    let dummyCipherTextResponse = try encoder.encode(ClientCipherTextResponse(cipherText: dummyCipherText))
    let portalRequestMock = PortalRequestsMock()
    initPortalApiWith(requests: portalRequestMock)
    portalRequestMock.returnValueData = dummyCipherTextResponse

    // and given
    let clientCipherText = try await api?.getClientCipherText(MockConstants.mockMpcShareId)

    // then
    XCTAssertEqual(clientCipherText, dummyCipherText)
  }

  func test_getClientCipherText_willCall_requestGet_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.getClientCipherText("")
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.getCallsCount, 1)
  }

  func test_getClientCipherText_willThrowCorrectError_whenRequestPostThrowError() async throws {
    // given
    let portalRequestsFailMock = PortalRequestsFailMock()
    initPortalApiWith(requests: portalRequestsFailMock)

    do {
      // and given
      _ = try await api?.getClientCipherText("")
      XCTFail("Expected error not thrown when calling PortalApi.getBalances when Request throws error.")
    } catch {
      // then
      XCTAssertEqual(error as? URLError, portalRequestsFailMock.errorToThrow)
    }
  }
}

// MARK: - getQuote tests

extension PortalApiTests {
  func test_getQuote_willCall_requestPost_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.getQuote("", withArgs: QuoteArgs.stub())
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.postCallsCount, 1)
  }

  func test_getQuote() async throws {
    // given
    let quoteResponse = try encoder.encode(Quote.stub())
    let portalRequestMock = PortalRequestsMock()
    initPortalApiWith(requests: portalRequestMock)
    portalRequestMock.returnValueData = quoteResponse

    do {
      // and given
      let quote = try await api?.getQuote("", withArgs: QuoteArgs.stub())
      // then
      XCTAssertEqual(quote, Quote.stub())
    } catch {}
  }

  func test_getQuote_willCall_requestPost_passingCorrectUrlPath() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.getQuote("", withArgs: QuoteArgs.stub(), forChainId: "dummy_chain_id")
    } catch {}

    // then
    if #available(iOS 16.0, *) {
      XCTAssertEqual(portalRequestsSpy.postFromParam?.path(), "/api/v3/swaps/quote")
    }
  }
}

// MARK: - getNFTs tests

// extension PortalApiTests {
//  func test_getNFTs_willCall_requestGet_onlyOnce() async throws {
//    // given
//    let portalRequestsSpy = PortalRequestsSpy()
//    initPortalApiWith(requests: portalRequestsSpy)
//
//    do {
//      // and given
//      _ = try await api?.getNFTs("")
//    } catch {}
//
//    // then
//    XCTAssertEqual(portalRequestsSpy.getCallsCount, 1)
//  }
//
//  func test_getNFTs() async throws {
//    // given
//    let fetchedNFTResponse = try encoder.encode([FetchedNFT.stub()])
//    let portalRequestMock = PortalRequestsMock()
//    initPortalApiWith(requests: portalRequestMock)
//    portalRequestMock.returnValueData = fetchedNFTResponse
//
//    do {
//      // and given
//      let fetchedNFT = try await api?.getNFTs("")
//      // then
//      XCTAssertEqual(fetchedNFT, [FetchedNFT.stub()])
//    } catch {}
//  }
//
//  func test_getNFTs_willCall_requestGet_passingCorrectUrlPathAndQuery() async throws {
//    // given
//    let portalRequestsSpy = PortalRequestsSpy()
//    initPortalApiWith(requests: portalRequestsSpy)
//    let chainId = "eip155:11155111"
//
//    do {
//      // and given
//      _ = try await api?.getNFTs(chainId)
//    } catch {}
//
//    // then
//    if #available(iOS 16.0, *) {
//      XCTAssertEqual(portalRequestsSpy.getFromParam?.path(), "/api/v3/clients/me/nfts")
//      XCTAssertEqual(portalRequestsSpy.getFromParam?.query(), "chainId=\(chainId)")
//    }
//  }
// }

// MARK: - getSharePairs tests

extension PortalApiTests {
  func testGetBackupSharePairs() async throws {
    let expectation = XCTestExpectation(description: "PortalApi.getSharePairs(.backup)")
    let backupSharesResponse = try await api?.getSharePairs(.backup, walletId: MockConstants.mockWalletId)
    XCTAssert(backupSharesResponse?.count ?? 0 > 0)
    XCTAssert(backupSharesResponse?[0].id == MockConstants.mockFetchedShairPair.id)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func testGetSigningSharePairs() async throws {
    let expectation = XCTestExpectation(description: "PortalApi.getSharePairs(.signing)")
    let mockSharesResponse = [MockConstants.mockFetchedShairPair]
    let signingSharesResponse = try await api?.getSharePairs(.signing, walletId: MockConstants.mockWalletId)
    XCTAssert(signingSharesResponse == mockSharesResponse)
    XCTAssert(signingSharesResponse?[0].id == MockConstants.mockFetchedShairPair.id)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func test_getSharePairs_willCall_requestGet_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.getSharePairs(.backup, walletId: "dummy_wallet_id")
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.getCallsCount, 1)
  }

  func test_getSharePairs() async throws {
    // given
    let fetchedSharePairResponse = try encoder.encode([FetchedSharePair.stub()])
    let portalRequestMock = PortalRequestsMock()
    initPortalApiWith(requests: portalRequestMock)
    portalRequestMock.returnValueData = fetchedSharePairResponse

    do {
      // and given
      let fetchedSharePair = try await api?.getSharePairs(.backup, walletId: "dummy_wallet_id")
      // then
      XCTAssertEqual(fetchedSharePair, [FetchedSharePair.stub()])
    } catch {}
  }

  func test_getSharePairs_willCall_requestGet_passingCorrectUrlPathAndQuery() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)
    let type: PortalSharePairType = .signing
    let walletId = MockConstants.mockWalletId

    do {
      // and given
      _ = try await api?.getSharePairs(type, walletId: walletId)
    } catch {}

    // then
    if #available(iOS 16.0, *) {
      XCTAssertEqual(portalRequestsSpy.getFromParam?.path(), "/api/v3/clients/me/wallets/\(walletId)/\(type)-share-pairs")
    }
  }
}

// MARK: - getSources tests

extension PortalApiTests {
  func test_getSources_willCall_requestPost_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.getSources("", forChainId: "")
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.postCallsCount, 1)
  }

  func test_getSources() async throws {
    // given
    let sourcesResponse = try encoder.encode(StringDictionary.stub())
    let portalRequestMock = PortalRequestsMock()
    initPortalApiWith(requests: portalRequestMock)
    portalRequestMock.returnValueData = sourcesResponse

    do {
      // and given
      let sources = try await api?.getSources("", forChainId: "")
      // then
      XCTAssertEqual(sources, Dictionary.stub())
    } catch {}
  }

  func test_getSources_willCall_requestPost_passingCorrectUrlPathAndQuery() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.getSources("", forChainId: "")
    } catch {}

    // then
    if #available(iOS 16.0, *) {
      XCTAssertEqual(portalRequestsSpy.postFromParam?.path(), "/api/v3/swaps/sources")
    }
  }
}

// MARK: - fund tests

extension PortalApiTests {
  func test_fund() async throws {
    let expectation = XCTestExpectation(description: "PortalApi.fund()")
    let mockFundResponse = MockConstants.mockFundResponse
    let fundResponse = try await api?.fund(chainId: "eip155:11155111", params: FundParams(amount: "0.01", token: "ETH"))
    XCTAssert(fundResponse?.data?.txHash == mockFundResponse.data?.txHash)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }
}

// MARK: - getTransactions tests

extension PortalApiTests {
  func testGetTransactions() async throws {
    let expectation = XCTestExpectation(description: "PortalApi.getTransactions()")
    let mockFetchedTransaction = MockConstants.mockFetchedTransaction
    let mockTransactionsResponse = try await api?.getTransactions("eip155:11155111")
    XCTAssert(mockTransactionsResponse?.count ?? 0 > 0)
    XCTAssert(mockTransactionsResponse?[0].blockNum == mockFetchedTransaction.blockNum)
    XCTAssert(mockTransactionsResponse?[0].chainId == mockFetchedTransaction.chainId)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func test_getTransactions_willCall_requestGet_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.getTransactions("")
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.getCallsCount, 1)
  }

  func test_getTransactions() async throws {
    // given
    let fetchedTransactionsResponse = try encoder.encode([FetchedTransaction.stub()])
    let portalRequestMock = PortalRequestsMock()
    initPortalApiWith(requests: portalRequestMock)
    portalRequestMock.returnValueData = fetchedTransactionsResponse

    do {
      // and given
      let transactions = try await api?.getTransactions("")
      // then
      XCTAssertEqual(transactions, [FetchedTransaction.stub()])
    } catch {}
  }

  func test_getTransactions_willCall_requestGet_passingCorrectUrlPathAndQuery() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)
    let chainId = "eip155:11155111"
    let limit = 2
    let offset = 4
    let order: TransactionOrder = .ASC

    do {
      // and given
      _ = try await api?.getTransactions(chainId, limit: limit, offset: offset, order: order)
    } catch {}

    // then
    if #available(iOS 16.0, *) {
      XCTAssertEqual(portalRequestsSpy.getFromParam?.path(), "/api/v3/clients/me/transactions")
      XCTAssertEqual(portalRequestsSpy.getFromParam?.query(), "chainId=\(chainId)&limit=\(limit)&offset=\(offset)&order=\(order)")
    }
  }
}

// MARK: - identify tests

extension PortalApiTests {
  func test_identify_willCall_requestPost_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.identify()
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.postCallsCount, 1)
  }

  func test_identify() async throws {
    // given
    let metricsResponseStub = MetricsResponse(status: false)
    let metricsResponse = try encoder.encode(metricsResponseStub)
    let portalRequestMock = PortalRequestsMock()
    initPortalApiWith(requests: portalRequestMock)
    portalRequestMock.returnValueData = metricsResponse

    do {
      // and given
      let metrics = try await api?.identify()
      // then
      XCTAssertEqual(metrics, metricsResponseStub)
    } catch {}
  }

  func test_identify_willCall_requestPost_passingCorrectUrlPath() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.identify()
    } catch {}

    // then
    if #available(iOS 16.0, *) {
      XCTAssertEqual(portalRequestsSpy.postFromParam?.path(), "/api/v1/analytics/identify")
    }
  }
}

// MARK: - prepareEject tests

extension PortalApiTests {
  func test_prepareEject_willCall_requestPost_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.prepareEject("", .GoogleDrive)
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.postCallsCount, 1)
  }

  func test_prepareEject() async throws {
    // given
    let share = "dummy_share"
    let prepareEjectResponseStub = PrepareEjectResponse(share: share)
    let prepareEjectResponse = try encoder.encode(prepareEjectResponseStub)
    let portalRequestMock = PortalRequestsMock()
    initPortalApiWith(requests: portalRequestMock)
    portalRequestMock.returnValueData = prepareEjectResponse

    do {
      // and given
      let ejectedShare = try await api?.prepareEject("", .Passkey)
      // then
      XCTAssertEqual(ejectedShare, share)
    } catch {}
  }

  func test_prepareEject_willCall_requestPost_passingCorrectUrlPathAndPayload() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let backupMethod: BackupMethods = .iCloud
    initPortalApiWith(requests: portalRequestsSpy)
    let walletId = MockConstants.mockWalletId

    do {
      // and given
      _ = try await api?.prepareEject(walletId, backupMethod)
    } catch {}

    // then
    if #available(iOS 16.0, *) {
      XCTAssertEqual(portalRequestsSpy.postFromParam?.path(), "/api/v3/clients/me/wallets/\(walletId)/prepare-eject")
      XCTAssertEqual(portalRequestsSpy.postAndPayloadParam as? [String: String], ["backupMethod": backupMethod.rawValue])
    }
  }
}

// MARK: - refreshClient tests

extension PortalApiTests {
  func test_refreshClient_willCall_requestGet_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.refreshClient()
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.getCallsCount, 1)
  }
}

// MARK: - simulateTransaction tests

extension PortalApiTests {
  func testSimulateTransaction() async throws {
    let expectation = XCTestExpectation(description: "PortalApi.simulateTransaction()")
    let transaction = AnyEncodable([:] as [String: String])
    let simulatedTransaction = try await api?.simulateTransaction(transaction, withChainId: "eip155:11155111")
    XCTAssert(simulatedTransaction?.changes.count == MockConstants.mockSimulatedTransaction.changes.count)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func test_simulateTransaction_willCall_requestPost_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.simulateTransaction([:], withChainId: "")
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.postCallsCount, 1)
  }

  func test_simulateTransaction() async throws {
    // given
    let simulatedTransactionResponse = try encoder.encode(SimulatedTransaction.stub())
    let portalRequestMock = PortalRequestsMock()
    initPortalApiWith(requests: portalRequestMock)
    portalRequestMock.returnValueData = simulatedTransactionResponse

    do {
      // and given
      let simulatedTransaction = try await api?.simulateTransaction([:], withChainId: "")
      // then
      XCTAssertEqual(simulatedTransaction, SimulatedTransaction.stub())
    } catch {}
  }

  func test_simulateTransaction_willCall_requestPost_passingCorrectUrlPathAndPayload() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)
    let chainId = "eip155:11155111"

    do {
      // and given
      _ = try await api?.simulateTransaction([:], withChainId: chainId)
    } catch {}

    // then
    if #available(iOS 16.0, *) {
      XCTAssertEqual(portalRequestsSpy.postFromParam?.path(), "/api/v3/clients/me/simulate-transaction")
      XCTAssertEqual(portalRequestsSpy.postFromParam?.query(), "chainId=\(chainId)")
    }
  }
}

// MARK: - storeClientCipherText tests

extension PortalApiTests {
  func test_storeClientCipherText_willCall_requestPatch_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.storeClientCipherText("", cipherText: "")
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.patchCallsCount, 1)
  }

  func test_storeClientCipherText() async throws {
    // given
    let successResponse = try encoder.encode(true)
    let portalRequestMock = PortalRequestsMock()
    initPortalApiWith(requests: portalRequestMock)
    portalRequestMock.returnValueData = successResponse

    do {
      // and given
      let isStored = try await api?.storeClientCipherText("", cipherText: "")
      // then
      XCTAssertEqual(isStored, true)
    } catch {}
  }

  func test_storeClientCipherText_willCall_requestPatch_passingCorrectUrlPathAndPayload() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)
    let backupSharePairId = "dummy_backup_share_pair_id"
    let cipherText = "dummy_cipher_text"

    do {
      // and given
      _ = try await api?.storeClientCipherText(backupSharePairId, cipherText: cipherText)
    } catch {}

    // then
    if #available(iOS 16.0, *) {
      XCTAssertEqual(portalRequestsSpy.patchFromParam?.path(), "/api/v3/clients/me/backup-share-pairs/\(backupSharePairId)")
      XCTAssertEqual((portalRequestsSpy.patchAndPayloadParam as? AnyCodable)?.value as? [String: String], ["clientCipherText": cipherText])
    }
  }
}

// MARK: - track tests

extension PortalApiTests {
  func test_track_willCall_requestPost_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.track("", withProperties: [:])
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.postCallsCount, 1)
  }

  func test_track() async throws {
    let metricsResponseStub = MetricsResponse(status: true)
    let metricsResponse = try encoder.encode(metricsResponseStub)
    let portalRequestMock = PortalRequestsMock()
    initPortalApiWith(requests: portalRequestMock)
    portalRequestMock.returnValueData = metricsResponse

    do {
      // and given
      let metrics = try await api?.track("", withProperties: [:])
      // then
      XCTAssertEqual(metrics, metricsResponseStub)
    } catch {}
  }

  func test_track_willCall_requestPost_passingCorrectUrlPathAndPayload() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)
    let event = "dummy_event"
    let properties = ["propKey": AnyCodable("porpValue")]

    do {
      // and given
      _ = try await api?.track(event, withProperties: properties)
    } catch {}

    // then
    if #available(iOS 16.0, *) {
      XCTAssertEqual(portalRequestsSpy.postFromParam?.path(), "/api/v1/analytics/track")
      XCTAssertEqual((portalRequestsSpy.postAndPayloadParam as? MetricsTrackRequest)?.event, event)
      XCTAssertEqual((portalRequestsSpy.postAndPayloadParam as? MetricsTrackRequest)?.properties as? [String: AnyCodable], properties)
    }
  }
}

// MARK: - updateShareStatus tests

extension PortalApiTests {
  func test_updateShareStatus_willCall_requestPatch_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.updateShareStatus(.signing, status: .STORED_CLIENT, sharePairIds: [])
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.patchCallsCount, 1)
  }

  func test_updateShareStatus_willCall_requestPatch_passingCorrectUrlPathAndPayload_forSigningType() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)
    let signingType: PortalSharePairType = .signing
    let status: SharePairUpdateStatus = .STORED_CLIENT
    let sharePairIds = ["123", "321"]

    do {
      // and given
      _ = try await api?.updateShareStatus(signingType, status: status, sharePairIds: sharePairIds)
    } catch {}

    // then
    if #available(iOS 16.0, *) {
      XCTAssertEqual(portalRequestsSpy.patchFromParam?.path(), "/api/v3/clients/me/\(signingType.rawValue)-share-pairs/")
      XCTAssertEqual((portalRequestsSpy.patchAndPayloadParam as? ShareStatusUpdateRequest)?.signingSharePairIds, sharePairIds)
      XCTAssertEqual((portalRequestsSpy.patchAndPayloadParam as? ShareStatusUpdateRequest)?.status, status)
    }
  }

  func test_updateShareStatus_willCall_requestPatch_passingCorrectUrlPathAndPayload_forBackupType() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)
    let backupType: PortalSharePairType = .backup
    let status: SharePairUpdateStatus = .STORED_CLIENT
    let sharePairIds = ["123", "321"]

    do {
      // and given
      _ = try await api?.updateShareStatus(backupType, status: status, sharePairIds: sharePairIds)
    } catch {}

    // then
    if #available(iOS 16.0, *) {
      XCTAssertEqual(portalRequestsSpy.patchFromParam?.path(), "/api/v3/clients/me/\(backupType.rawValue)-share-pairs/")
      XCTAssertEqual((portalRequestsSpy.patchAndPayloadParam as? ShareStatusUpdateRequest)?.backupSharePairIds, sharePairIds)
      XCTAssertEqual((portalRequestsSpy.patchAndPayloadParam as? ShareStatusUpdateRequest)?.status, status)
    }
  }
}

// MARK: - getWalletCapabilities tests

extension PortalApiTests {
  func test_getWalletCapabilities_willCall_requestPost_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.getWalletCapabilities()
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.getCallsCount, 1)
  }

  func test_getWalletCapabilities() async throws {
    // given
    let quoteResponse = try encoder.encode(Quote.stub())
    let portalRequestMock = PortalRequestsMock()
    initPortalApiWith(requests: portalRequestMock)
    portalRequestMock.returnValueData = quoteResponse

    do {
      // and given
      let walletCapabilities = try await api?.getWalletCapabilities()
      // then
      XCTAssertEqual(walletCapabilities, WalletCapabilitiesResponse.stub())
    } catch {}
  }

  func test_getWalletCapabilities_willCall_requestGet_passingCorrectUrlPath() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.getWalletCapabilities()
    } catch {}

    // then
    if #available(iOS 16.0, *) {
      XCTAssertEqual(portalRequestsSpy.getFromParam?.path(), "/api/v3/clients/me/wallet_getCapabilities")
    }
  }
}
