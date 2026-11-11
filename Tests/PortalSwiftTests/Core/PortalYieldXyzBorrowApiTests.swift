//
//  PortalYieldXyzBorrowApiTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import AnyCodable
@testable import PortalSwift
import XCTest

final class PortalYieldXyzBorrowApiTests: XCTestCase {
  private let encoder = JSONEncoder()
  private let host = "https://\(MockConstants.mockHost)"
  private lazy var base = "\(host)/api/v3/clients/me/integrations/yield-xyz-borrow"
  private let wallet = YieldXyzBorrowFixtures.wallet

  private var spy: PortalRequestsSpy!
  private var api: PortalYieldXyzBorrowApi!

  override func setUpWithError() throws {
    spy = PortalRequestsSpy()
    api = PortalYieldXyzBorrowApi(
      credentials: StaticCredentials(MockConstants.mockApiKey),
      apiHost: MockConstants.mockHost,
      requests: spy
    )
  }

  override func tearDownWithError() throws {
    spy = nil
    api = nil
  }

  // MARK: - Helpers

  private func respond<T: Encodable>(with response: T) throws {
    spy.returnData = try encoder.encode(response)
  }

  private func respond(json: String) {
    spy.returnData = Data(json.utf8)
  }

  private var lastUrl: String? {
    spy.executeRequestParam?.url.absoluteString
  }

  /// The JSON object the last request sent as its body.
  private func lastBody() throws -> NSDictionary {
    let payload = try XCTUnwrap(spy.executeRequestParam?.payload)
    let data = try encoder.encode(payload)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? NSDictionary)
  }

  // MARK: - Health and integrations

  func test_getHealth_sendsGetToHealthWithBearer() async throws {
    try respond(with: YieldXyzBorrowGetHealthResponse(data: YieldXyzBorrowHealthStatus(status: .ok, timestamp: "2026-08-26T10:30:00.000Z")))

    let response = try await api.getHealth()

    XCTAssertEqual(response.data.status, .ok)
    XCTAssertEqual(spy.executeCallsCount, 1)
    XCTAssertEqual(spy.executeRequestParam?.method, .get)
    XCTAssertEqual(lastUrl, "\(base)/health")
    XCTAssertEqual(spy.executeRequestParam?.headers["Authorization"], "Bearer \(MockConstants.mockApiKey)")
    XCTAssertNil(spy.executeRequestParam?.payload)
  }

  func test_getIntegrations_sendsGetToIntegrations() async throws {
    try respond(with: YieldXyzBorrowGetIntegrationsResponse(data: [.stub()]))

    let response = try await api.getIntegrations()

    XCTAssertEqual(response.data, [.stub()])
    XCTAssertEqual(spy.executeRequestParam?.method, .get)
    XCTAssertEqual(lastUrl, "\(base)/integrations")
  }

  func test_getIntegration_encodesTheIdAsOnePathSegment() async throws {
    try respond(with: YieldXyzBorrowGetIntegrationResponse(data: .stub()))

    _ = try await api.getIntegration(integrationId: "a/b?c")

    XCTAssertEqual(lastUrl, "\(base)/integrations/a%2Fb%3Fc")
  }

  // MARK: - Markets

  func test_getMarkets_withoutFilters_sendsNoQuery() async throws {
    try respond(with: YieldXyzBorrowGetMarketsResponse(data: YieldXyzBorrowPage(total: 0, offset: 0, limit: 25, items: [])))

    _ = try await api.getMarkets()

    XCTAssertEqual(lastUrl, "\(base)/markets")
  }

  func test_getMarkets_sendsTheFiltersInAllowListOrder() async throws {
    try respond(with: YieldXyzBorrowGetMarketsResponse(data: YieldXyzBorrowPage(total: 1, offset: 20, limit: 10, items: [.stub()])))

    let response = try await api.getMarkets(params: YieldXyzBorrowGetMarketsParams(
      offset: 20,
      limit: 10,
      integrationId: "morpho-blue-borrow",
      network: "eip155:143",
      scope: .all
    ))

    XCTAssertEqual(response.data.items, [.stub()])
    XCTAssertEqual(lastUrl, "\(base)/markets?offset=20&limit=10&integrationId=morpho-blue-borrow&network=eip155%3A143&scope=all")
  }

  func test_getMarkets_encodesTheNetworkStrictly() async throws {
    try respond(with: YieldXyzBorrowGetMarketsResponse(data: YieldXyzBorrowPage(total: 0, offset: 0, limit: 25, items: [])))

    _ = try await api.getMarkets(params: YieldXyzBorrowGetMarketsParams(network: "eip155:1"))

    XCTAssertEqual(lastUrl, "\(base)/markets?network=eip155%3A1")
  }

  func test_getMarkets_skipsEmptyValues() async throws {
    try respond(with: YieldXyzBorrowGetMarketsResponse(data: YieldXyzBorrowPage(total: 0, offset: 0, limit: 25, items: [])))

    _ = try await api.getMarkets(params: YieldXyzBorrowGetMarketsParams(integrationId: "", network: "eip155:1"))

    XCTAssertEqual(lastUrl, "\(base)/markets?network=eip155%3A1")
  }

  func test_getMarket_encodesTheIdAsOnePathSegment() async throws {
    try respond(with: YieldXyzBorrowGetMarketResponse(data: .stub()))

    _ = try await api.getMarket(marketId: "m/1#x")

    XCTAssertEqual(lastUrl, "\(base)/markets/m%2F1%23x")
  }

  // MARK: - Positions

  func test_getPositions_sendsTheQueryInOrder() async throws {
    try respond(with: YieldXyzBorrowGetPositionsResponse(data: .stub()))

    let response = try await api.getPositions(params: YieldXyzBorrowGetPositionsParams(
      integrationId: "aave-borrow",
      network: "eip155:8453",
      address: wallet
    ))

    XCTAssertEqual(response.data, .stub())
    XCTAssertEqual(spy.executeRequestParam?.method, .get)
    XCTAssertEqual(lastUrl, "\(base)/positions?integrationId=aave-borrow&network=eip155%3A8453&address=\(wallet)")
  }

  func test_getLiquidations_sendsTheQueryInOrder() async throws {
    try respond(with: YieldXyzBorrowGetLiquidationsResponse(data: YieldXyzBorrowPage(total: 1, offset: 0, limit: 25, items: [.stub()])))

    _ = try await api.getLiquidations(params: YieldXyzBorrowGetLiquidationsParams(
      offset: 0,
      limit: 25,
      integrationId: "morpho-blue-borrow",
      network: "eip155:1",
      address: wallet,
      marketId: "m-1"
    ))

    XCTAssertEqual(
      lastUrl,
      "\(base)/positions/liquidations?offset=0&limit=25&integrationId=morpho-blue-borrow&network=eip155%3A1&address=\(wallet)&marketId=m-1"
    )
  }

  // MARK: - Actions

  func test_createAction_postsExactlyTheBodyKeys() async throws {
    try respond(with: YieldXyzBorrowActionResponse(data: .stub()))

    _ = try await api.createAction(params: YieldXyzBorrowCreateActionParams(
      integrationId: "aave-borrow",
      action: .supply,
      address: wallet,
      args: YieldXyzBorrowActionArguments(marketId: YieldXyzBorrowFixtures.marketId, amount: "5", tokenAddress: YieldXyzBorrowFixtures.usdcBase)
    ))

    XCTAssertEqual(spy.executeRequestParam?.method, .post)
    XCTAssertEqual(lastUrl, "\(base)/actions")
    XCTAssertEqual(try lastBody(), [
      "integrationId": "aave-borrow",
      "action": "supply",
      "address": wallet,
      "args": [
        "marketId": YieldXyzBorrowFixtures.marketId,
        "amount": "5",
        "tokenAddress": YieldXyzBorrowFixtures.usdcBase
      ]
    ])
  }

  func test_createAction_sendsRepayAllAsABoolean() async throws {
    try respond(with: YieldXyzBorrowActionResponse(data: .stub()))

    _ = try await api.createAction(params: YieldXyzBorrowCreateActionParams(
      integrationId: "morpho-blue-borrow",
      action: .repay,
      address: wallet,
      args: YieldXyzBorrowActionArguments(marketId: "m-1", repayAll: true)
    ))

    XCTAssertEqual(try lastBody()["args"] as? NSDictionary, ["marketId": "m-1", "repayAll": true])
  }

  func test_getActions_sendsTheAllowListedFiltersInOrder() async throws {
    try respond(with: YieldXyzBorrowGetActionsResponse(data: YieldXyzBorrowPage(total: 1, offset: 0, limit: 25, items: [.stub()])))

    _ = try await api.getActions(params: YieldXyzBorrowGetActionsParams(
      offset: 5,
      limit: 25,
      address: wallet,
      integrationId: "aave-borrow",
      action: .borrow,
      status: .processing,
      statuses: [.success, .failed]
    ))

    XCTAssertEqual(
      lastUrl,
      "\(base)/actions?offset=5&limit=25&address=\(wallet)&integrationId=aave-borrow&action=borrow&status=PROCESSING&statuses=SUCCESS%2CFAILED"
    )
  }

  func test_getActions_withOnlyTheAddress_sendsOnlyIt() async throws {
    try respond(with: YieldXyzBorrowGetActionsResponse(data: YieldXyzBorrowPage(total: 0, offset: 0, limit: 25, items: [])))

    _ = try await api.getActions(params: YieldXyzBorrowGetActionsParams(address: wallet, statuses: []))

    XCTAssertEqual(lastUrl, "\(base)/actions?address=\(wallet)")
  }

  func test_getAction_encodesTheIdAsOnePathSegment() async throws {
    try respond(with: YieldXyzBorrowActionResponse(data: .stub()))

    _ = try await api.getAction(actionId: "act/1")

    XCTAssertEqual(spy.executeRequestParam?.method, .get)
    XCTAssertEqual(lastUrl, "\(base)/actions/act%2F1")
  }

  func test_stepAction_postsWithoutABody() async throws {
    try respond(with: YieldXyzBorrowActionResponse(data: .stub()))

    _ = try await api.stepAction(actionId: "act 1")

    XCTAssertEqual(spy.executeRequestParam?.method, .post)
    XCTAssertEqual(lastUrl, "\(base)/actions/act%201/step")
    XCTAssertNil(spy.executeRequestParam?.payload)
  }

  // MARK: - Transactions

  func test_submitTransaction_postsTheTransactionHashOnly() async throws {
    let hash = "0x" + String(repeating: "ab", count: 32)
    try respond(with: YieldXyzBorrowSubmitTransactionResponse(data: YieldXyzBorrowFixtures.submitResult(transactionHash: hash)))

    let response = try await api.submitTransaction(
      transactionId: "tx/1",
      params: YieldXyzBorrowSubmitTransactionParams(transactionHash: hash)
    )

    XCTAssertEqual(response.data.status, .broadcasted)
    XCTAssertEqual(spy.executeRequestParam?.method, .post)
    XCTAssertEqual(lastUrl, "\(base)/transactions/tx%2F1/submit")
    XCTAssertEqual(try lastBody(), ["transactionHash": hash])
  }

  func test_submitTransaction_postsASignedPayload() async throws {
    try respond(with: YieldXyzBorrowSubmitTransactionResponse(data: .stub()))

    _ = try await api.submitTransaction(transactionId: "tx-1", params: YieldXyzBorrowSubmitTransactionParams(signedPayload: "0xf86c"))

    XCTAssertEqual(try lastBody(), ["signedPayload": "0xf86c"])
  }

  func test_submitTransaction_dropsEmptyValues() async throws {
    try respond(with: YieldXyzBorrowSubmitTransactionResponse(data: .stub()))

    _ = try await api.submitTransaction(
      transactionId: "tx-1",
      params: YieldXyzBorrowSubmitTransactionParams(transactionHash: YieldXyzBorrowFixtures.approvalHash, signedPayload: "")
    )

    XCTAssertEqual(try lastBody(), ["transactionHash": YieldXyzBorrowFixtures.approvalHash])
  }

  // MARK: - Empty ids

  func test_emptyPathIds_areRejectedWithoutARequest() async throws {
    let calls: [(String, () async throws -> Void)] = [
      ("integrationId", { _ = try await self.api.getIntegration(integrationId: "") }),
      ("marketId", { _ = try await self.api.getMarket(marketId: "") }),
      ("actionId", { _ = try await self.api.getAction(actionId: "") }),
      ("actionId", { _ = try await self.api.stepAction(actionId: "") }),
      ("transactionId", {
        _ = try await self.api.submitTransaction(transactionId: "", params: YieldXyzBorrowSubmitTransactionParams(transactionHash: "0x1"))
      })
    ]

    for (name, call) in calls {
      do {
        try await call()
        XCTFail("Expected \(name) to be rejected")
      } catch {
        XCTAssertEqual(error as? YieldXyzBorrowError, .emptyIdentifier(name: name))
      }
    }
    XCTAssertEqual(spy.executeCallsCount, 0)
  }

  // MARK: - Errors

  func test_errors_passThroughUnchanged_andExposeThePortalError() async throws {
    spy.executeThrowableErrorSequence = [
      PortalRequestsError.internalServerError(
        #"500 - {"error":"Yield.xyz Borrow returned a response for GET /v1/markets that does not match the expected schema","id":"INTEGRATION_RESPONSE_SCHEMA_DRIFT","details":{"integration":"yield-xyz-borrow"}}"#,
        url: ""
      )
    ]

    do {
      _ = try await api.getMarkets()
      XCTFail("Expected the request to fail")
    } catch {
      XCTAssertTrue(error is PortalRequestsError)
      let apiError = try XCTUnwrap(YieldXyzBorrowApiError.from(error))
      XCTAssertEqual(apiError.status, 500)
      XCTAssertEqual(apiError.id, YieldXyzBorrowErrorId.integrationResponseSchemaDrift)
      XCTAssertTrue(apiError.isSchemaDrift)
      XCTAssertFalse(apiError.isRateLimit)
      XCTAssertEqual(apiError.details?["integration"], "yield-xyz-borrow")
    }
  }

  func test_apiError_readsAValidationFailureWithoutAnId() {
    let error = PortalRequestsError.clientError(#"400 - {"error":"Invalid request body: args: Unrecognized key: \"slippage\""}"#, url: "")

    let apiError = YieldXyzBorrowApiError.from(error)

    XCTAssertEqual(apiError?.status, 400)
    XCTAssertNil(apiError?.id)
    XCTAssertEqual(apiError?.message, #"Invalid request body: args: Unrecognized key: "slippage""#)
  }

  func test_apiError_readsARateLimit() {
    XCTAssertEqual(YieldXyzBorrowApiError.from(PortalRequestsError.clientError("429 - {}", url: ""))?.isRateLimit, true)
  }

  func test_apiError_isNilForATransportFailure() {
    XCTAssertNil(YieldXyzBorrowApiError.from(URLError(.timedOut)))
  }

  func test_apiError_unwrapsAnExecutionError() {
    let execution = YieldXyzBorrowExecutionError(
      reason: .submitRejected,
      message: "rejected",
      underlyingError: PortalRequestsError.clientError(#"400 - {"error":"bad"}"#, url: "")
    )

    XCTAssertEqual(YieldXyzBorrowApiError.from(execution)?.message, "bad")
  }

  // MARK: - Transaction lookup

  func test_lookupEvmTransaction_readsAnEoaTransaction() async throws {
    let hash = YieldXyzBorrowFixtures.approvalHash
    respond(json: """
    {"data":{"evmTransaction":{"hash":"\(hash)","from":"\(wallet)","to":null,"value":"0x0","nonce":"0x7","gas":"0xdbb0","input":"0x","type":"0x2","status":null},"evmUserOperation":null,"solanaTransaction":null,"bitcoinTransaction":null,"stellarTransaction":null,"tronTransaction":null},"metadata":{"chainId":"eip155:8453","signature":"\(hash)"}}
    """)

    let lookup = try await api.lookupEvmTransaction(chainId: "eip155:8453", hash: hash)

    XCTAssertEqual(lookup, YieldXyzEvmTransactionLookup(transactionHash: hash))
    XCTAssertEqual(spy.executeRequestParam?.method, .get)
    XCTAssertEqual(lastUrl, "\(host)/api/v3/clients/me/chains/eip155%3A8453/transactions/\(hash)")
    XCTAssertEqual(spy.executeRequestParam?.headers["Authorization"], "Bearer \(MockConstants.mockApiKey)")
  }

  func test_lookupEvmTransaction_readsAUserOperation_evenWithoutTheBundlerFields() async throws {
    let bundleHash = YieldXyzBorrowFixtures.bundleHash
    // Only the fields the execution needs: a bundler that omits the rest must not fail the lookup.
    respond(json: """
    {"data":{"evmTransaction":null,"evmUserOperation":{"success":true,"receipt":{"hash":"\(bundleHash)"}}}}
    """)

    let lookup = try await api.lookupEvmTransaction(chainId: "eip155:8453", hash: YieldXyzBorrowFixtures.userOperationHash)

    XCTAssertEqual(lookup, YieldXyzEvmTransactionLookup(userOperation: .init(success: true, receiptTransactionHash: bundleHash)))
  }

  func test_lookupEvmTransaction_readsAPendingUserOperation() async throws {
    respond(json: #"{"data":{"evmTransaction":null,"evmUserOperation":{"sender":"0x1","success":null,"receipt":null}}}"#)

    let lookup = try await api.lookupEvmTransaction(chainId: "eip155:8453", hash: YieldXyzBorrowFixtures.userOperationHash)

    XCTAssertEqual(lookup, YieldXyzEvmTransactionLookup(userOperation: .init(success: nil, receiptTransactionHash: nil)))
  }

  func test_lookupEvmTransaction_returnsNilWithoutData() async throws {
    respond(json: "{}")

    let lookup = try await api.lookupEvmTransaction(chainId: "eip155:8453", hash: YieldXyzBorrowFixtures.approvalHash)

    XCTAssertNil(lookup)
  }

  func test_lookupEvmTransaction_passesANotFoundThrough() async throws {
    spy.executeThrowableErrorSequence = [PortalRequestsError.clientError(#"404 - {"error":"Transaction not found"}"#, url: "")]

    do {
      _ = try await api.lookupEvmTransaction(chainId: "eip155:8453", hash: YieldXyzBorrowFixtures.approvalHash)
      XCTFail("Expected the lookup to fail")
    } catch {
      XCTAssertEqual(YieldXyzRequestFailure.status(of: error), 404)
    }
  }

  func test_lookupFromGetTransactionDetails_mapsTheSameFields() {
    let response = YieldXyzBorrowFixtures.decode(GetTransactionDetailsResponse.self, """
    {"data":{"evmTransaction":null,"evmUserOperation":{"sender":"0x1","nonce":"0x1","callData":"0x","callGasLimit":"0x1","verificationGasLimit":"0x1","preVerificationGas":"0x1","maxFeePerGas":"0x1","maxPriorityFeePerGas":"0x0","signature":"0x","entryPoint":"0x2","success":false,"actualGasCost":"0x0","actualGasUsed":null,"receipt":{"hash":"\(YieldXyzBorrowFixtures.bundleHash)","from":"0x3","to":null,"value":"0x0","nonce":"0x0","gas":"0x0","input":"0x","type":"0x2"}}},"metadata":{"chainId":"eip155:8453","signature":"\(YieldXyzBorrowFixtures.userOperationHash)"}}
    """)

    XCTAssertEqual(
      YieldXyzEvmTransactionLookup(response),
      YieldXyzEvmTransactionLookup(userOperation: .init(success: false, receiptTransactionHash: YieldXyzBorrowFixtures.bundleHash))
    )
  }
}
