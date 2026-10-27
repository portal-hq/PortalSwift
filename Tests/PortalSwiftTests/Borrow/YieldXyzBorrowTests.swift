//
//  YieldXyzBorrowTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

@testable import PortalSwift
import XCTest

final class YieldXyzBorrowTests: XCTestCase {
  private var api: PortalYieldXyzBorrowApiMock!
  private var borrow: YieldXyzBorrow!

  override func setUp() {
    super.setUp()
    api = PortalYieldXyzBorrowApiMock()
    borrow = YieldXyzBorrow(api: api)
  }

  override func tearDown() {
    api = nil
    borrow = nil
    super.tearDown()
  }

  // MARK: - Reads pass through

  func test_reads_passTheirParamsThrough() async throws {
    _ = try await borrow.getHealth()
    _ = try await borrow.getIntegrations()
    _ = try await borrow.getIntegration(integrationId: "aave-borrow")
    _ = try await borrow.getMarkets()
    let marketsParams = YieldXyzBorrowGetMarketsParams(network: "eip155:8453", scope: .all)
    _ = try await borrow.getMarkets(params: marketsParams)
    _ = try await borrow.getMarket(marketId: "m-1")
    let positionsParams = YieldXyzBorrowGetPositionsParams(integrationId: "aave-borrow", network: "eip155:8453", address: YieldXyzBorrowFixtures.wallet)
    _ = try await borrow.getPositions(params: positionsParams)
    let liquidationsParams = YieldXyzBorrowGetLiquidationsParams(integrationId: "morpho-blue-borrow", network: "eip155:1", address: YieldXyzBorrowFixtures.wallet)
    _ = try await borrow.getLiquidations(params: liquidationsParams)
    let actionsParams = YieldXyzBorrowGetActionsParams(address: YieldXyzBorrowFixtures.wallet, statuses: [.success])
    _ = try await borrow.getActions(params: actionsParams)
    _ = try await borrow.getAction(actionId: "act-1")
    _ = try await borrow.stepAction(actionId: "act-2")

    XCTAssertEqual(api.getHealthCallsCount, 1)
    XCTAssertEqual(api.getIntegrationsCallsCount, 1)
    XCTAssertEqual(api.getIntegrationIntegrationIdParam, "aave-borrow")
    XCTAssertEqual(api.getMarketsParams, marketsParams)
    XCTAssertEqual(api.getMarketMarketIdParam, "m-1")
    XCTAssertEqual(api.getPositionsParams, positionsParams)
    XCTAssertEqual(api.getLiquidationsParams, liquidationsParams)
    XCTAssertEqual(api.getActionsParams, actionsParams)
    XCTAssertEqual(api.getActionActionIdParam, "act-1")
    XCTAssertEqual(api.stepActionActionIdParam, "act-2")
  }

  func test_createAction_passesTheParamsThrough() async throws {
    let params = YieldXyzBorrowCreateActionParams(
      integrationId: "aave-borrow",
      action: .borrow,
      address: YieldXyzBorrowFixtures.wallet,
      args: YieldXyzBorrowActionArguments(marketId: "m-1", amount: "0.2")
    )

    _ = try await borrow.createAction(params: params)

    XCTAssertEqual(api.createActionParams, params)
  }

  // MARK: - submitTransaction

  func test_submitTransaction_requiresAHashOrASignedPayload() async throws {
    for params in [
      YieldXyzBorrowSubmitTransactionParams(),
      YieldXyzBorrowSubmitTransactionParams(transactionHash: "", signedPayload: "")
    ] {
      do {
        _ = try await borrow.submitTransaction(transactionId: "tx-1", params: params)
        XCTFail("Expected the submission to be rejected")
      } catch {
        XCTAssertEqual(error as? YieldXyzBorrowError, .submissionRequired)
      }
    }
    XCTAssertEqual(api.submitTransactionCallsCount, 0)
  }

  func test_submitTransaction_acceptsEitherOrBoth() async throws {
    let hash = YieldXyzBorrowFixtures.approvalHash

    _ = try await borrow.submitTransaction(transactionId: "tx-1", params: YieldXyzBorrowSubmitTransactionParams(transactionHash: hash))
    _ = try await borrow.submitTransaction(transactionId: "tx-2", params: YieldXyzBorrowSubmitTransactionParams(signedPayload: "0xf86c"))
    _ = try await borrow.submitTransaction(transactionId: "tx-3", params: YieldXyzBorrowSubmitTransactionParams(transactionHash: hash, signedPayload: "0xf86c"))

    XCTAssertEqual(api.submitTransactionCalls.map(\.transactionId), ["tx-1", "tx-2", "tx-3"])
  }

  // MARK: - Errors

  func test_errorMessages_arePrefixed() {
    XCTAssertEqual(YieldXyzBorrowError.submissionRequired.errorDescription, "[YieldXyzBorrow] submitTransaction requires a transactionHash or a signedPayload.")
    XCTAssertEqual(YieldXyzBorrowError.emptyIdentifier(name: "marketId").errorDescription, "[YieldXyzBorrow] marketId must not be empty.")
    XCTAssertEqual(
      YieldXyzBorrowExecutionError(reason: .timeout, message: "Waiting timed out.").errorDescription,
      "[YieldXyzBorrow] Waiting timed out."
    )
  }

  func test_executionErrorReasons_matchTheOtherSdks() {
    let reasons: [YieldXyzBorrowExecutionErrorReason] = [
      .unsupportedSigningFormat, .unsupportedNetwork, .invalidSignablePayload, .missingWalletAddress, .signerAddressMismatch,
      .signingChainNotConfigured, .dependencyUnavailable, .signatureRejected, .invalidTransactionHash, .signingFailed,
      .transactionAlreadyBroadcast, .broadcastOutcomeUnknown, .userOperationFailed, .transactionFailed, .submitRejected, .submitFailed,
      .submitOutcomeUnknown, .nextStepFailed, .actionFailed, .actionInProgress, .pollingFailed, .timeout
    ]

    XCTAssertEqual(reasons.map(\.rawValue), [
      "UNSUPPORTED_SIGNING_FORMAT", "UNSUPPORTED_NETWORK", "INVALID_SIGNABLE_PAYLOAD", "MISSING_WALLET_ADDRESS", "SIGNER_ADDRESS_MISMATCH",
      "SIGNING_CHAIN_NOT_CONFIGURED", "DEPENDENCY_UNAVAILABLE", "SIGNATURE_REJECTED", "INVALID_TRANSACTION_HASH", "SIGNING_FAILED",
      "TRANSACTION_ALREADY_BROADCAST", "BROADCAST_OUTCOME_UNKNOWN", "USER_OPERATION_FAILED", "TRANSACTION_FAILED", "SUBMIT_REJECTED", "SUBMIT_FAILED",
      "SUBMIT_OUTCOME_UNKNOWN", "NEXT_STEP_FAILED", "ACTION_FAILED", "ACTION_IN_PROGRESS", "POLLING_FAILED", "TIMEOUT"
    ])
  }

  // MARK: - Facade

  func test_borrowFacade_prefersTheApiTransactionLookup() {
    let lookupApi = PortalYieldXyzBorrowApi(credentials: StaticCredentials(MockConstants.mockApiKey), apiHost: MockConstants.mockHost, requests: PortalRequestsSpy())

    XCTAssertNotNil(YieldXyzBorrow.lookup(from: lookupApi))
    XCTAssertNil(YieldXyzBorrow.lookup(from: api))
  }

  func test_idempotencyKey_usesTheBorrowPrefix() {
    XCTAssertEqual(YieldXyzBorrow.idempotencyKey(forTransactionId: "550e8400-e29b-41d4-a716-446655440000"), "yieldxyz-borrow-550e8400-e29b-41d4-a716-446655440000")
    XCTAssertNil(YieldXyzBorrow.idempotencyKey(forTransactionId: ""))
    XCTAssertNil(YieldXyzBorrow.idempotencyKey(forTransactionId: "has space"))
  }
}
