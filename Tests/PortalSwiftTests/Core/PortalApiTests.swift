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

  func test_eject_willCall_execureRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    // and given
    _ = try await api?.eject()

    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
  }

  @available(iOS 16.0, *)
  func test_eject_willCall_executeRequest_passingCorrectParamsAndMethod() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    // and given
    _ = try await api?.eject()

    // then
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .post)
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path() ?? "", "/api/v3/clients/me/eject")
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.payload as? [String: String] ?? [:], [
      "clientPlatform": "NATIVE_IOS",
      "clientPlatformVersion": SDK_VERSION
    ])
  }

  func test_eject_willThrowCorrectError_whenExecuteRequestThrowError() async throws {
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

  func test_getBalances_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.getBalances("")
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
  }

  func test_getBalances_willThrowCorrectError_whenExecuteRequestThrowError() async throws {
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

  func test_getClient_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.getClient()
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
  }

  func test_getClient_willThrowCorrectError_whenExecuteRequestThrowError() async throws {
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

  func test_getClientCipherText_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.getClientCipherText("")
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
  }

  func test_getClientCipherText_willThrowCorrectError_whenExecuteRequestThrowError() async throws {
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
  func test_getQuote_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.getQuote("", withArgs: QuoteArgs.stub())
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
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

  func test_getQuote_willCall_executeRequest_passingCorrectUrlPathAndMethod() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.getQuote("", withArgs: QuoteArgs.stub(), forChainId: "dummy_chain_id")
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .post)
    if #available(iOS 16.0, *) {
      XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path(), "/api/v3/swaps/quote")
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

  func test_getSharePairs_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.getSharePairs(.backup, walletId: "dummy_wallet_id")
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
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

  func test_getSharePairs_willCall_executeRequest_passingCorrectUrlPathAndQueryAndMethod() async throws {
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
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .get)
    if #available(iOS 16.0, *) {
      XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path() ?? "", "/api/v3/clients/me/wallets/\(walletId)/\(type)-share-pairs")
    }
  }
}

// MARK: - getSources tests

extension PortalApiTests {
  func test_getSources_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.getSources("", forChainId: "")
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
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

  func test_getSources_willCall_execureRequest_passingCorrectUrlPathAndQueryAndMethod() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.getSources("", forChainId: "")
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .post)
    if #available(iOS 16.0, *) {
      XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path(), "/api/v3/swaps/sources")
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

  func test_fund_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let fundResponse = MockConstants.mockFundResponse
    portalRequestsSpy.returnData = try Data(JSONEncoder().encode(fundResponse))
    initPortalApiWith(requests: portalRequestsSpy)

    // and given
    _ = try await api?.fund(chainId: "", params: FundParams(amount: "", token: ""))

    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
  }

  @available(iOS 16.0, *)
  func test_fund_willCall_executeRequest_passingCorrectParamsAndMethod() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let fundResponse = MockConstants.mockFundResponse
    portalRequestsSpy.returnData = try Data(JSONEncoder().encode(fundResponse))
    initPortalApiWith(requests: portalRequestsSpy)

    // and given
    let amount = "0.01"
    let token = "ETH"
    let chainId = "eip155:11155111"

    // and given
    _ = try await api?.fund(chainId: chainId, params: FundParams(amount: amount, token: token))

    // then
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path() ?? "", "/api/v3/clients/me/fund")
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .post)
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.payload as? FundRequestBody, FundRequestBody(amount: amount, chainId: chainId, token: token))
  }

  func test_fund_willThrowCorrectError_whenExecuteRequestThrowError() async throws {
    // given
    let portalRequestsFailMock = PortalRequestsFailMock()
    initPortalApiWith(requests: portalRequestsFailMock)

    do {
      // and given
      _ = try await api?.fund(chainId: "", params: FundParams(amount: "", token: ""))
      XCTFail("Expected error not thrown when calling PortalApi.fund when Request throws error.")
    } catch {
      // then
      XCTAssertEqual(error as? URLError, portalRequestsFailMock.errorToThrow)
    }
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

  func test_getTransactions_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.getTransactions("")
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
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

  func test_getTransactions_willCall_executeRequest_passingCorrectUrlPathAndQueryAndMethod() async throws {
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
      XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path(), "/api/v3/clients/me/transactions")
      XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.query(), "chainId=\(chainId)&limit=\(limit)&offset=\(offset)&order=\(order)")
      XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .get)
    }
  }
}

// MARK: - identify tests

extension PortalApiTests {
  func test_identify_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.identify()
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
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

  func test_identify_willCall_executeRequest_passingCorrectUrlPathAndMethod() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.identify()
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .post)
    if #available(iOS 16.0, *) {
      XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path(), "/api/v1/analytics/identify")
    }
  }
}

// MARK: - prepareEject tests

extension PortalApiTests {
  func test_prepareEject_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.prepareEject("", .GoogleDrive)
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
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

  func test_prepareEject_willCall_executeRequest_passingCorrectUrlPathAndPayloadAndMethod() async throws {
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
      XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path(), "/api/v3/clients/me/wallets/\(walletId)/prepare-eject")
      XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .post)
      XCTAssertEqual(portalRequestsSpy.executeRequestParam?.payload as? [String: String], ["backupMethod": backupMethod.rawValue])
    }
  }
}

// MARK: - refreshClient tests

extension PortalApiTests {
  func test_refreshClient_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.refreshClient()
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
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

  func test_simulateTransaction_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.simulateTransaction([:], withChainId: "")
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
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

  func test_simulateTransaction_willCall_executeRequest_passingCorrectUrlPathAndPayloadAndMethod() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)
    let chainId = "eip155:11155111"

    do {
      // and given
      _ = try await api?.simulateTransaction([:], withChainId: chainId)
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .post)
    if #available(iOS 16.0, *) {
      XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path(), "/api/v3/clients/me/simulate-transaction")
      XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.query(), "chainId=\(chainId)")
    }
  }
}

// MARK: - storeClientCipherText tests

extension PortalApiTests {
  func test_storeClientCipherText_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.storeClientCipherText("", cipherText: "")
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
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

  func test_storeClientCipherText_willCall_executeRequest_passingCorrectUrlPathAndPayloadAndMethod() async throws {
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
      XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path() ?? "", "/api/v3/clients/me/backup-share-pairs/\(backupSharePairId)")
      XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .patch)
      XCTAssertEqual((portalRequestsSpy.executeRequestParam?.payload as? AnyCodable)?.value as? [String: String], ["clientCipherText": cipherText])
    }
  }
}

// MARK: - track tests

extension PortalApiTests {
  func test_track_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.track("", withProperties: [:])
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
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

  func test_track_willCall_executeRequest_passingCorrectUrlPathAndPayloadAndMethod() async throws {
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
      XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path(), "/api/v1/analytics/track")
      XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .post)
      XCTAssertEqual((portalRequestsSpy.executeRequestParam?.payload as? MetricsTrackRequest)?.event, event)
      XCTAssertEqual((portalRequestsSpy.executeRequestParam?.payload as? MetricsTrackRequest)?.properties as? [String: AnyCodable], properties)
    }
  }
}

// MARK: - updateShareStatus tests

extension PortalApiTests {
  func test_updateShareStatus_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.updateShareStatus(.signing, status: .STORED_CLIENT, sharePairIds: [])
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
  }

  func test_updateShareStatus_willCall_executeRequest_passingCorrectUrlPathAndPayloadAndMethod_forSigningType() async throws {
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
      XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path(), "/api/v3/clients/me/\(signingType.rawValue)-share-pairs/")
      XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .patch)
      XCTAssertEqual((portalRequestsSpy.executeRequestParam?.payload as? ShareStatusUpdateRequest)?.signingSharePairIds, sharePairIds)
      XCTAssertEqual((portalRequestsSpy.executeRequestParam?.payload as? ShareStatusUpdateRequest)?.status, status)
    }
  }

  func test_updateShareStatus_willCall_executeRequest_passingCorrectUrlPathAndPayloadAndMethod_forBackupType() async throws {
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
      XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path(), "/api/v3/clients/me/\(backupType.rawValue)-share-pairs/")
      XCTAssertEqual((portalRequestsSpy.executeRequestParam?.payload as? ShareStatusUpdateRequest)?.backupSharePairIds, sharePairIds)
      XCTAssertEqual((portalRequestsSpy.executeRequestParam?.payload as? ShareStatusUpdateRequest)?.status, status)
    }
  }
}

// MARK: - getWalletCapabilities tests

extension PortalApiTests {
  func test_getWalletCapabilities_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.getWalletCapabilities()
    } catch {}

    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
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

  func test_getWalletCapabilities_willCall_executeRequest_passingCorrectUrlPathAndMethod() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    initPortalApiWith(requests: portalRequestsSpy)

    do {
      // and given
      _ = try await api?.getWalletCapabilities()
    } catch {}

    // then
    if #available(iOS 16.0, *) {
      XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path(), "/api/v3/clients/me/wallet_getCapabilities")
      XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .get)
    }
  }
}

// MARK: - buildEip155Transaction tests

extension PortalApiTests {
  func test_buildEip155Transaction() async throws {
    let expectation = XCTestExpectation(description: "PortalApi.buildEip155Transaction()")
    let portalRequestsSpy = PortalRequestsSpy()
    let mockBuildEip115TransactionResponse = BuildEip115TransactionResponse.stub()
    portalRequestsSpy.returnData = try Data(JSONEncoder().encode(mockBuildEip115TransactionResponse))
    initPortalApiWith(requests: portalRequestsSpy)

    let buildEip115TransactionResponse = try await api?.buildEip155Transaction(chainId: "eip155:11155111", params: BuildTransactionParam.stub())
    XCTAssert(buildEip115TransactionResponse == mockBuildEip115TransactionResponse)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func test_buildEip155Transaction_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let buildEip115TransactionResponse = BuildEip115TransactionResponse.stub()
    portalRequestsSpy.returnData = try Data(JSONEncoder().encode(buildEip115TransactionResponse))
    initPortalApiWith(requests: portalRequestsSpy)

    // and given
    _ = try await api?.buildEip155Transaction(chainId: "eip155:11155111", params: BuildTransactionParam.stub())

    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
  }

  @available(iOS 16.0, *)
  func test_buildEip155Transaction_willCall_executeRequest_passingCorrectParams() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let buildEip115TransactionResponse = BuildEip115TransactionResponse.stub()
    portalRequestsSpy.returnData = try Data(JSONEncoder().encode(buildEip115TransactionResponse))
    initPortalApiWith(requests: portalRequestsSpy)

    // and given
    let chainId = "eip155:11155111"
    let buildTransactionParams: BuildTransactionParam = .stub()

    // and given
    _ = try await api?.buildEip155Transaction(chainId: chainId, params: buildTransactionParams)

    // then
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path() ?? "", "/api/v3/clients/me/chains/\(chainId)/assets/send/build-transaction")
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .post)
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.payload as? [String: String], buildTransactionParams.toDictionary())
  }

  func test_buildEip155Transaction_willThrowCorrectError_whenExecuteRequestThrowError() async throws {
    // given
    let portalRequestsFailMock = PortalRequestsFailMock()
    initPortalApiWith(requests: portalRequestsFailMock)

    do {
      // and given
      _ = try await api?.buildEip155Transaction(chainId: "eip155:11155111", params: BuildTransactionParam.stub())
      XCTFail("Expected error not thrown when calling PortalApi.buildEip155Transaction when Request throws error.")
    } catch {
      // then
      XCTAssertEqual(error as? URLError, portalRequestsFailMock.errorToThrow)
    }
  }

  func test_buildEip155Transaction_willThrowCorrectError_whenPassingInvalidChainId() async throws {
    // give
    let chainId = ""
    do {
      // and given
      _ = try await api?.buildEip155Transaction(chainId: chainId, params: BuildTransactionParam.stub())
      XCTFail("Expected error not thrown when calling PortalApi.buildEip155Transaction when Request throws error.")
    } catch {
      // then
      XCTAssertEqual(error as? PortalApiError, PortalApiError.invalidChainId(message: "Invalid chainId: \(chainId). ChainId must start with 'eip155:'"))
    }
  }
}

// MARK: - buildSolanaTransaction tests

extension PortalApiTests {
  func test_buildSolanaTransaction() async throws {
    let expectation = XCTestExpectation(description: "PortalApi.buildSolanaTransaction()")
    let portalRequestsSpy = PortalRequestsSpy()
    let mockBuildSolanaTransactionResponse = BuildSolanaTransactionResponse.stub()
    portalRequestsSpy.returnData = try Data(JSONEncoder().encode(mockBuildSolanaTransactionResponse))
    initPortalApiWith(requests: portalRequestsSpy)

    let buildSolanaTransactionResponse = try await api?.buildSolanaTransaction(chainId: "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1", params: BuildTransactionParam.stub())
    XCTAssert(buildSolanaTransactionResponse == mockBuildSolanaTransactionResponse)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func test_buildSolanaTransaction_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockBuildSolanaTransactionResponse = BuildSolanaTransactionResponse.stub()
    portalRequestsSpy.returnData = try Data(JSONEncoder().encode(mockBuildSolanaTransactionResponse))
    initPortalApiWith(requests: portalRequestsSpy)

    // and given
    _ = try await api?.buildSolanaTransaction(chainId: "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1", params: BuildTransactionParam.stub())

    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
  }

  @available(iOS 16.0, *)
  func test_buildSolanaTransaction_willCall_executeRequest_passingCorrectParams() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockBuildSolanaTransactionResponse = BuildSolanaTransactionResponse.stub()
    portalRequestsSpy.returnData = try Data(JSONEncoder().encode(mockBuildSolanaTransactionResponse))
    initPortalApiWith(requests: portalRequestsSpy)

    // and given
    let chainId = "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1"
    let buildTransactionParams: BuildTransactionParam = .stub()

    // and given
    _ = try await api?.buildSolanaTransaction(chainId: chainId, params: buildTransactionParams)

    // then
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path() ?? "", "/api/v3/clients/me/chains/\(chainId)/assets/send/build-transaction")
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .post)
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.payload as? [String: String], buildTransactionParams.toDictionary())
  }

  func test_buildSolanaTransaction_willThrowCorrectError_whenExecuteRequestThrowError() async throws {
    // given
    let portalRequestsFailMock = PortalRequestsFailMock()
    initPortalApiWith(requests: portalRequestsFailMock)

    do {
      // and given
      _ = try await api?.buildSolanaTransaction(chainId: "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1", params: BuildTransactionParam.stub())
      XCTFail("Expected error not thrown when calling PortalApi.buildEip155Transaction when Request throws error.")
    } catch {
      // then
      XCTAssertEqual(error as? URLError, portalRequestsFailMock.errorToThrow)
    }
  }

  func test_buildSolanaTransaction_willThrowCorrectError_whenPassingInvalidChainId() async throws {
    // give
    let chainId = ""
    do {
      // and given
      _ = try await api?.buildSolanaTransaction(chainId: chainId, params: BuildTransactionParam.stub())
      XCTFail("Expected error not thrown when calling PortalApi.buildSolanaTransaction when Request throws error.")
    } catch {
      // then
      XCTAssertEqual(error as? PortalApiError, PortalApiError.invalidChainId(message: "Invalid chainId: \(chainId). ChainId must start with 'solana:'"))
    }
  }
}

// MARK: - getNftAssets tests

extension PortalApiTests {
  func test_getNftAssets() async throws {
    let expectation = XCTestExpectation(description: "PortalApi.getNftAssets()")
    let portalRequestsSpy = PortalRequestsSpy()
    let mockGetNftAssetsResponse = [NftAsset.stub()]
    portalRequestsSpy.returnData = try Data(JSONEncoder().encode(mockGetNftAssetsResponse))
    initPortalApiWith(requests: portalRequestsSpy)

    let getNftAssetsResponse = try await api?.getNftAssets("solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1")
    XCTAssert(getNftAssetsResponse == mockGetNftAssetsResponse)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

  func test_getNftAssets_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockGetNftAssetsResponse = [NftAsset.stub()]
    portalRequestsSpy.returnData = try Data(JSONEncoder().encode(mockGetNftAssetsResponse))
    initPortalApiWith(requests: portalRequestsSpy)

    // and given
    _ = try await api?.getNftAssets("solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1")

    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
  }

  @available(iOS 16.0, *)
  func test_getNftAssets_willCall_executeRequest_passingCorrectParams() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockGetNftAssetsResponse = [NftAsset.stub()]
    portalRequestsSpy.returnData = try Data(JSONEncoder().encode(mockGetNftAssetsResponse))
    initPortalApiWith(requests: portalRequestsSpy)

    // and given
    let chainId = "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1"

    // and given
    _ = try await api?.getNftAssets("solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1")

    // then
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path() ?? "", "/api/v3/clients/me/chains/\(chainId)/assets/nfts")
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .get)
  }

  func test_getNftAssets_willThrowCorrectError_whenExecuteRequestThrowError() async throws {
    // given
    let portalRequestsFailMock = PortalRequestsFailMock()
    initPortalApiWith(requests: portalRequestsFailMock)

    do {
      // and given
      _ = try await api?.getNftAssets("solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1")
      XCTFail("Expected error not thrown when calling PortalApi.buildEip155Transaction when Request throws error.")
    } catch {
      // then
      XCTAssertEqual(error as? URLError, portalRequestsFailMock.errorToThrow)
    }
  }
}

// MARK: - yieldxyz property tests

extension PortalApiTests {
  func test_yieldxyz_propertyExists() {
    // given & when
    let yieldxyzApi = api?.yieldxyz
    
    // then
    XCTAssertNotNil(yieldxyzApi)
  }
  
  func test_yieldxyz_isOfCorrectType() {
    // given & when
    let yieldxyzApi = api?.yieldxyz
    
    // then
    XCTAssertTrue(yieldxyzApi is PortalYieldXyzApiProtocol)
    XCTAssertTrue(yieldxyzApi is PortalYieldXyzApi)
  }
  
  func test_yieldxyz_returnsSameInstanceOnMultipleAccesses() {
    // given
    let firstAccess = api?.yieldxyz
    
    // when
    let secondAccess = api?.yieldxyz
    
    // then - lazy var should return the same instance
    XCTAssertTrue(firstAccess === secondAccess as AnyObject)
  }
  
  func test_yieldxyz_canCallGetYields() async throws {
    // given
    let expectation = XCTestExpectation(description: "PortalApi.yieldxyz.getYields()")
    let mockResponse = YieldXyzGetYieldsResponse.stub()
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try JSONEncoder().encode(mockResponse)
    initPortalApiWith(requests: portalRequestsSpy)
    
    // when
    let response = try await api?.yieldxyz.getYields(request: YieldXyzGetYieldsRequest())
    
    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response?.data)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }
  
  func test_yieldxyz_canCallEnterYield() async throws {
    // given
    let expectation = XCTestExpectation(description: "PortalApi.yieldxyz.enterYield()")
    let mockResponse = YieldXyzEnterYieldResponse.stub()
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try JSONEncoder().encode(mockResponse)
    initPortalApiWith(requests: portalRequestsSpy)
    
    let request = YieldXyzEnterRequest(
      yieldId: "yield-1",
      address: "0x1234567890abcdef1234567890abcdef12345678"
    )
    
    // when
    let response = try await api?.yieldxyz.enterYield(request: request)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response?.data)
    XCTAssertEqual(response?.data?.rawResponse.intent, .enter)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }
  
  func test_yieldxyz_canCallExitYield() async throws {
    // given
    let expectation = XCTestExpectation(description: "PortalApi.yieldxyz.exitYield()")
    let mockResponse = YieldXyzExitResponse.stub()
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try JSONEncoder().encode(mockResponse)
    initPortalApiWith(requests: portalRequestsSpy)
    
    let request = YieldXyzExitRequest(
      yieldId: "yield-1",
      address: "0x1234567890abcdef1234567890abcdef12345678"
    )
    
    // when
    let response = try await api?.yieldxyz.exitYield(request: request)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response?.data)
    XCTAssertEqual(response?.data?.rawResponse.intent, .exit)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }
  
  func test_yieldxyz_canCallManageYield() async throws {
    // given
    let expectation = XCTestExpectation(description: "PortalApi.yieldxyz.manageYield()")
    let mockResponse = YieldXyzManageYieldResponse.stub()
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try JSONEncoder().encode(mockResponse)
    initPortalApiWith(requests: portalRequestsSpy)
    
    let request = YieldXyzManageYieldRequest(
      yieldId: "yield-1",
      address: "0x1234567890abcdef1234567890abcdef12345678",
      arguments: YieldXyzEnterArguments(),
      action: .CLAIM_REWARDS,
      passthrough: "passthrough-data"
    )
    
    // when
    let response = try await api?.yieldxyz.manageYield(request: request)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response?.data)
    XCTAssertEqual(response?.data?.rawResponse.intent, .manage)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }
  
  func test_yieldxyz_canCallGetYieldBalances() async throws {
    // given
    let expectation = XCTestExpectation(description: "PortalApi.yieldxyz.getYieldBalances()")
    let mockResponse = YieldXyzGetBalancesResponse.stub()
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try JSONEncoder().encode(mockResponse)
    initPortalApiWith(requests: portalRequestsSpy)
    
    let query = YieldXyzBalanceQuery(
      address: "0x1234567890abcdef1234567890abcdef12345678",
      network: "eip155:1",
      yieldId: "yield-1"
    )
    let request = YieldXyzGetBalancesRequest(queries: [query])
    
    // when
    let response = try await api?.yieldxyz.getYieldBalances(request: request)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response?.data)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }
  
  func test_yieldxyz_canCallGetHistoricalYieldActions() async throws {
    // given
    let expectation = XCTestExpectation(description: "PortalApi.yieldxyz.getHistoricalYieldActions()")
    let mockResponse = YieldXyzGetHistoricalActionsResponse.stub()
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try JSONEncoder().encode(mockResponse)
    initPortalApiWith(requests: portalRequestsSpy)
    
    let request = YieldXyzGetHistoricalActionsRequest(
      address: "0x1234567890abcdef1234567890abcdef12345678"
    )
    
    // when
    let response = try await api?.yieldxyz.getHistoricalYieldActions(request: request)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response?.data)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }
  
  func test_yieldxyz_canCallGetYieldTransaction() async throws {
    // given
    let expectation = XCTestExpectation(description: "PortalApi.yieldxyz.getYieldTransaction()")
    let mockResponse = YieldXyzGetTransactionResponse.stub()
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try JSONEncoder().encode(mockResponse)
    initPortalApiWith(requests: portalRequestsSpy)
    
    let transactionId = "tx-123"
    
    // when
    let response = try await api?.yieldxyz.getYieldTransaction(transactionId: transactionId)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response?.data)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }
  
  func test_yieldxyz_canCallSubmitTransactionHash() async throws {
    // given
    let expectation = XCTestExpectation(description: "PortalApi.yieldxyz.submitTransactionHash()")
    let mockResponse = YieldXyzTrackTransactionResponse.stub()
    let portalRequestsSpy = PortalRequestsSpy()
    portalRequestsSpy.returnData = try JSONEncoder().encode(mockResponse)
    initPortalApiWith(requests: portalRequestsSpy)
    
    let request = YieldXyzTrackTransactionRequest(
      transactionId: "tx-123",
      hash: "0xhash123"
    )
    
    // when
    let response = try await api?.yieldxyz.submitTransactionHash(request: request)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response?.data)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }
  
  func test_yieldxyz_usesCorrectApiKey() async throws {
    // given
    let customApiKey = "custom-test-api-key"
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzGetYieldsResponse.stub()
    portalRequestsSpy.returnData = try JSONEncoder().encode(mockResponse)
    
    let customApi = PortalApi(
      apiKey: customApiKey,
      apiHost: MockConstants.mockHost,
      requests: portalRequestsSpy
    )
    
    // when
    _ = try await customApi.yieldxyz.getYields(request: YieldXyzGetYieldsRequest())
    
    // then
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.headers["Authorization"], "Bearer \(customApiKey)")
  }
  
    @available(iOS 16.0, *)
    func test_yieldxyz_usesCorrectApiHost() async throws {
    // given
    let customApiHost = "custom.api.host.com"
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzGetYieldsResponse.stub()
    portalRequestsSpy.returnData = try JSONEncoder().encode(mockResponse)
    
    let customApi = PortalApi(
      apiKey: MockConstants.mockApiKey,
      apiHost: customApiHost,
      requests: portalRequestsSpy
    )
    
    // when
    _ = try await customApi.yieldxyz.getYields(request: YieldXyzGetYieldsRequest())
    
    // then
    XCTAssertTrue(portalRequestsSpy.executeRequestParam?.url.host()?.contains(customApiHost) ?? false)
  }
  
  func test_yieldxyz_sharesRequestsInstance() async throws {
    // given
    let sharedRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzGetYieldsResponse.stub()
    sharedRequestsSpy.returnData = try JSONEncoder().encode(mockResponse)
    
    initPortalApiWith(requests: sharedRequestsSpy)
    
    // when
    _ = try await api?.yieldxyz.getYields(request: YieldXyzGetYieldsRequest())
    
    // then - should use the same requests instance
    XCTAssertEqual(sharedRequestsSpy.executeCallsCount, 1)
  }
  
  func test_yieldxyz_withLocalhostHost() async throws {
    // given
    let localhostHost = "localhost:3000"
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzGetYieldsResponse.stub()
    portalRequestsSpy.returnData = try JSONEncoder().encode(mockResponse)
    
    let customApi = PortalApi(
      apiKey: MockConstants.mockApiKey,
      apiHost: localhostHost,
      requests: portalRequestsSpy
    )
    
    // when
    _ = try await customApi.yieldxyz.getYields(request: YieldXyzGetYieldsRequest())
    
    // then
    XCTAssertTrue(portalRequestsSpy.executeRequestParam?.url.absoluteString.contains(localhostHost) ?? false)
  }
  
  func test_yieldxyz_errorPropagation() async throws {
    // given
    let portalRequestsFailMock = PortalRequestsFailMock()
    initPortalApiWith(requests: portalRequestsFailMock)
    
    do {
      // when
      _ = try await api?.yieldxyz.getYields(request: YieldXyzGetYieldsRequest())
      XCTFail("Expected error not thrown when calling PortalApi.yieldxyz.getYields when Request throws error.")
    } catch {
      // then - error should propagate correctly
      XCTAssertEqual(error as? URLError, portalRequestsFailMock.errorToThrow)
    }
  }
  
  func test_yieldxyz_multipleMethodCallsShareSameInstance() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockGetYieldsResponse = YieldXyzGetYieldsResponse.stub()
    let mockEnterYieldResponse = YieldXyzEnterYieldResponse.stub()
    portalRequestsSpy.returnData = try JSONEncoder().encode(mockGetYieldsResponse)
    initPortalApiWith(requests: portalRequestsSpy)
    
    let firstYieldxyz = api?.yieldxyz
    
    // when - make first call
    _ = try await firstYieldxyz?.getYields(request: YieldXyzGetYieldsRequest())
    
    // Update return data for second call
    portalRequestsSpy.returnData = try JSONEncoder().encode(mockEnterYieldResponse)
    
    let secondYieldxyz = api?.yieldxyz
    
    // when - make second call
    let enterRequest = YieldXyzEnterRequest(
      yieldId: "yield-1",
      address: "0x1234567890abcdef1234567890abcdef12345678"
    )
    _ = try await secondYieldxyz?.enterYield(request: enterRequest)
    
    // then - should be same instance
    XCTAssertTrue(firstYieldxyz === secondYieldxyz as AnyObject)
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 2)
  }
}
