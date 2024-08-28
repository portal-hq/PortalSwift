//
//  PortalApiTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

@testable import PortalSwift
import XCTest

final class PortalApiTests: XCTestCase {
  var api: PortalApi? = .init(apiKey: MockConstants.mockApiKey, apiHost: MockConstants.mockHost, requests: MockPortalRequests())

  override func setUpWithError() throws {
    self.api = PortalApi(apiKey: MockConstants.mockApiKey, apiHost: MockConstants.mockHost, requests: MockPortalRequests())
  }

  override func tearDownWithError() throws {
      api = nil
  }

  func testEject() async throws {
    let expectation = XCTestExpectation(description: "PortalApi.eject()")
      let ejectResponse = try await api?.eject()
    print("⚠️ Eject response:", ejectResponse ?? "")
    XCTAssertEqual(ejectResponse, MockConstants.mockEjectResponse)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

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

  func testGetBackupShareMetadataCompletion() throws {
    let expectation = XCTestExpectation(description: "PortalApi.getBackupShareMetadata(completion)")
      try api?.getBackupShareMetadata { result in
      XCTAssert(result.data?.count ?? 0 > 0)
      XCTAssert(result.data?[0].id == MockConstants.mockFetchedShairPair.id)
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 5.0)
  }

  func testGetBackupSharePairs() async throws {
    let expectation = XCTestExpectation(description: "PortalApi.getSharePairs(.backup)")
      let backupSharesResponse = try await api?.getSharePairs(.backup, walletId: MockConstants.mockWalletId)
      XCTAssert(backupSharesResponse?.count ?? 0 > 0)
      XCTAssert(backupSharesResponse?[0].id == MockConstants.mockFetchedShairPair.id)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

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

  func testGetSigningShareMetadataCompletion() throws {
    let expectation = XCTestExpectation(description: "PortalApi.getSigningShareMetadata(completion)")
      try api?.getSigningShareMetadata { result in
      XCTAssert(result.data?.count ?? 0 > 0)
      XCTAssert(result.data?[0].id == MockConstants.mockFetchedShairPair.id)
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 5.0)
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

  func testSimulateTransaction() async throws {
    let expectation = XCTestExpectation(description: "PortalApi.simulateTransaction()")
    let transaction = AnyEncodable([:] as [String: String])
      let simulatedTransaction = try await api?.simulateTransaction(transaction, withChainId: "eip155:11155111")
      XCTAssert(simulatedTransaction?.changes.count == MockConstants.mockSimulatedTransaction.changes.count)
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 5.0)
  }

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
