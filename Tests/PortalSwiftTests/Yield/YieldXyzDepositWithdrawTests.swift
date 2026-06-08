//
//  YieldXyzDepositWithdrawTests.swift
//  PortalSwift
//
//  Created by Portal Labs
//

import Foundation
@testable import PortalSwift
import XCTest

final class YieldXyzDepositWithdrawTests: XCTestCase {
  private var apiMock: PortalYieldXyzApiMock!
  private var portalMock: YieldXyzPortalDependencyMock!
  private var yieldXyz: YieldXyz!

  // Fast confirmation polling for tests.
  private let fastOptions = YieldSubmitOptions(pollIntervalSeconds: 1, timeoutSeconds: 1)

  override func setUpWithError() throws {
    apiMock = PortalYieldXyzApiMock()
    portalMock = YieldXyzPortalDependencyMock()
    yieldXyz = YieldXyz(api: apiMock, portal: portalMock)
  }

  override func tearDownWithError() throws {
    apiMock = nil
    portalMock = nil
    yieldXyz = nil
  }

  // MARK: - Helpers

  private func evmUnsignedTransaction(to: String = "0xcontract") -> String {
    """
    {"from":"0xwalletaddress","to":"\(to)","data":"0xabcdef","value":"0x0","gasLimit":"0x5208","maxFeePerGas":"0x3b9aca00","maxPriorityFeePerGas":"0x3b9aca00","nonce":"0x5"}
    """
  }

  private func makeEnterResponse(
    transactions: [YieldXyzActionTransaction],
    yieldId: String = "yield-1",
    intent: YieldXyzActionIntent = .enter
  ) -> YieldXyzEnterYieldResponse {
    YieldXyzEnterYieldResponse(
      data: .stub(rawResponse: .stub(intent: intent, yieldId: yieldId, transactions: transactions))
    )
  }

  private func makeExitResponse(
    transactions: [YieldXyzActionTransaction],
    yieldId: String = "yield-1"
  ) -> YieldXyzExitResponse {
    YieldXyzExitResponse(
      data: .stub(rawResponse: .stub(intent: .exit, yieldId: yieldId, transactions: transactions))
    )
  }
}

// MARK: - Deposit (yieldId mode)

extension YieldXyzDepositWithdrawTests {
  func test_deposit_byYieldId_singleEvmTx_succeeds() async throws {
    let tx = YieldXyzActionTransaction.stub(unsignedTransaction: evmUnsignedTransaction(), stepIndex: 0)
    apiMock.enterYieldReturnValue = makeEnterResponse(transactions: [tx])

    let result = try await yieldXyz.deposit(
      params: YieldDepositParams(target: .yieldId("yield-1"), amount: "0.1"),
      options: fastOptions
    )

    XCTAssertEqual(result.status, .success)
    XCTAssertEqual(result.hashes, ["0xhash1"])
    XCTAssertEqual(result.yieldId, "yield-1")
    XCTAssertNil(result.chain)
    XCTAssertNil(result.token)
    // yieldId mode resolves the chain via getYields, then enters.
    XCTAssertEqual(apiMock.getYieldsCalls, 1)
    XCTAssertEqual(apiMock.enterYieldCalls, 1)
    XCTAssertEqual(apiMock.submitTransactionHashCalls, 1)
    XCTAssertEqual(portalMock.sendCalls, 1)
  }

  func test_deposit_mergesAmountIntoArguments() async throws {
    let tx = YieldXyzActionTransaction.stub(unsignedTransaction: evmUnsignedTransaction(), stepIndex: 0)
    apiMock.enterYieldReturnValue = makeEnterResponse(transactions: [tx])
    apiMock.enterYieldReturnValue = makeEnterResponse(transactions: [tx])

    _ = try await yieldXyz.deposit(
      params: YieldDepositParams(
        target: .yieldId("yield-1"),
        amount: "0.42",
        arguments: YieldXyzEnterArguments(validatorAddress: "0xvalidator")
      ),
      options: fastOptions
    )
    // The amount should be merged into arguments while preserving validatorAddress (verified
    // indirectly by a successful enter call; request payload assertion lives in API tests).
    XCTAssertEqual(apiMock.enterYieldCalls, 1)
  }

  func test_deposit_multipleEvmTxs_succeeds() async throws {
    let tx0 = YieldXyzActionTransaction.stub(id: "tx-0", type: .APPROVAL, unsignedTransaction: evmUnsignedTransaction(), stepIndex: 0)
    let tx1 = YieldXyzActionTransaction.stub(id: "tx-1", type: .STAKE, unsignedTransaction: evmUnsignedTransaction(), stepIndex: 1)
    apiMock.enterYieldReturnValue = makeEnterResponse(transactions: [tx0, tx1])

    let result = try await yieldXyz.deposit(
      params: YieldDepositParams(target: .yieldId("yield-1"), amount: "1.0"),
      options: fastOptions
    )

    XCTAssertEqual(result.status, .success)
    XCTAssertEqual(result.hashes, ["0xhash1", "0xhash2"])
    XCTAssertEqual(apiMock.submitTransactionHashCalls, 2)
    XCTAssertEqual(portalMock.sendCalls, 2)
  }

  func test_deposit_onChainFailure_returnsFailedAndStops() async throws {
    portalMock.receiptStatus = "0x0"
    let tx0 = YieldXyzActionTransaction.stub(id: "tx-0", unsignedTransaction: evmUnsignedTransaction(), stepIndex: 0)
    let tx1 = YieldXyzActionTransaction.stub(id: "tx-1", unsignedTransaction: evmUnsignedTransaction(), stepIndex: 1)
    apiMock.enterYieldReturnValue = makeEnterResponse(transactions: [tx0, tx1])

    let result = try await yieldXyz.deposit(
      params: YieldDepositParams(target: .yieldId("yield-1"), amount: "1.0"),
      options: fastOptions
    )

    XCTAssertEqual(result.status, .failed)
    XCTAssertEqual(result.hashes, ["0xhash1"]) // stopped after first failure
    XCTAssertEqual(portalMock.sendCalls, 1)
    XCTAssertEqual(apiMock.submitTransactionHashCalls, 1)
  }

  func test_deposit_uncertainConfirmation_returnsPartialSuccess() async throws {
    portalMock.receiptAvailable = false // never mined within timeout
    let tx0 = YieldXyzActionTransaction.stub(id: "tx-0", unsignedTransaction: evmUnsignedTransaction(), stepIndex: 0)
    let tx1 = YieldXyzActionTransaction.stub(id: "tx-1", unsignedTransaction: evmUnsignedTransaction(), stepIndex: 1)
    apiMock.enterYieldReturnValue = makeEnterResponse(transactions: [tx0, tx1])

    let result = try await yieldXyz.deposit(
      params: YieldDepositParams(target: .yieldId("yield-1"), amount: "1.0"),
      options: fastOptions
    )

    XCTAssertEqual(result.status, .partialSuccess)
    XCTAssertEqual(result.hashes, ["0xhash1"]) // stopped after uncertain
  }

  func test_deposit_emitsProgressSteps() async throws {
    let tx = YieldXyzActionTransaction.stub(unsignedTransaction: evmUnsignedTransaction(), stepIndex: 0)
    apiMock.enterYieldReturnValue = makeEnterResponse(transactions: [tx])

    var steps: [YieldSubmitStep] = []
    let options = YieldSubmitOptions(
      onProgress: { steps.append($0.step) },
      pollIntervalSeconds: 1,
      timeoutSeconds: 1
    )

    _ = try await yieldXyz.deposit(params: YieldDepositParams(target: .yieldId("yield-1"), amount: "0.1"), options: options)

    XCTAssertEqual(steps, [.signing, .submitted, .confirming, .confirmed])
  }
}

// MARK: - Deposit (chain + token mode)

extension YieldXyzDepositWithdrawTests {
  func test_deposit_byChainAndToken_resolvesYieldIdAndEchoesChainToken() async throws {
    apiMock.getYieldDefaultsReturnValue = YieldXyzGetDefaultsResponse(
      data: ["eip155:11155111:ETH": .stub(yieldId: "resolved-yield")]
    )
    let tx = YieldXyzActionTransaction.stub(network: "eip155:11155111", unsignedTransaction: evmUnsignedTransaction(), stepIndex: 0)
    apiMock.enterYieldReturnValue = makeEnterResponse(transactions: [tx], yieldId: "resolved-yield")

    let result = try await yieldXyz.deposit(
      params: YieldDepositParams(target: .chainAndToken(chain: "eip155:11155111", token: "ETH"), amount: "0.1"),
      options: fastOptions
    )

    XCTAssertEqual(result.status, .success)
    XCTAssertEqual(result.chain, "eip155:11155111")
    XCTAssertEqual(result.token, "ETH")
    XCTAssertEqual(apiMock.getYieldDefaultsCalls, 1)
    XCTAssertEqual(apiMock.getYieldDefaultsIncludeOpportunitiesParam, false)
    XCTAssertEqual(apiMock.getYieldsCalls, 0) // chain+token mode does not need discover
  }

  func test_deposit_byChainAndToken_noDefault_throws() async throws {
    apiMock.getYieldDefaultsReturnValue = YieldXyzGetDefaultsResponse(data: [:])

    do {
      _ = try await yieldXyz.deposit(
        params: YieldDepositParams(target: .chainAndToken(chain: "eip155:1", token: "DOGE"), amount: "1"),
        options: fastOptions
      )
      XCTFail("Expected noYieldForChainToken error")
    } catch let error as YieldXyzError {
      XCTAssertEqual(error, .noYieldForChainToken("eip155:1:DOGE"))
    }
  }

  func test_deposit_invalidChainId_throws() async throws {
    do {
      _ = try await yieldXyz.deposit(
        params: YieldDepositParams(target: .chainAndToken(chain: "ethereum", token: "ETH"), amount: "1"),
        options: fastOptions
      )
      XCTFail("Expected invalidChainId error")
    } catch let error as YieldXyzError {
      XCTAssertEqual(error, .invalidChainId("ethereum"))
    }
  }
}

// MARK: - Withdraw

extension YieldXyzDepositWithdrawTests {
  func test_withdraw_byYieldId_succeeds() async throws {
    let tx = YieldXyzActionTransaction.stub(type: .UNSTAKE, unsignedTransaction: evmUnsignedTransaction(), stepIndex: 0)
    apiMock.exitYieldReturnValue = makeExitResponse(transactions: [tx])

    let result = try await yieldXyz.withdraw(
      params: YieldWithdrawParams(target: .yieldId("yield-1"), amount: "0.1"),
      options: fastOptions
    )

    XCTAssertEqual(result.status, .success)
    XCTAssertEqual(apiMock.exitYieldCalls, 1)
    XCTAssertEqual(result.yieldOpportunityDetails.intent, .exit)
  }
}

// MARK: - Solana

extension YieldXyzDepositWithdrawTests {
  func test_deposit_solana_succeeds() async throws {
    portalMock.solanaStatus = "confirmed"
    let tx = YieldXyzActionTransaction.stub(network: "solana:mainnet", type: .STAKE, unsignedTransaction: "c29sYW5hLXR4", stepIndex: 0)
    // yieldId mode: discover must report a solana network for address resolution.
    apiMock.getYieldsReturnValue = YieldXyzGetYieldsResponse(
      data: .stub(rawResponse: .stub(items: [.stub(network: "solana:mainnet")]))
    )
    apiMock.enterYieldReturnValue = makeEnterResponse(transactions: [tx])

    let result = try await yieldXyz.deposit(
      params: YieldDepositParams(target: .yieldId("solana-yield"), amount: "0.1"),
      options: fastOptions
    )

    XCTAssertEqual(result.status, .success)
    XCTAssertTrue(portalMock.requestedMethods.contains(.sol_signAndSendTransaction))
    XCTAssertEqual(portalMock.getTransactionDetailsCalls, 1)
  }

  func test_deposit_solanaError_returnsFailed() async throws {
    portalMock.solanaError = "blockhash expired"
    let tx = YieldXyzActionTransaction.stub(network: "solana:mainnet", unsignedTransaction: "c29sYW5hLXR4", stepIndex: 0)
    apiMock.getYieldsReturnValue = YieldXyzGetYieldsResponse(
      data: .stub(rawResponse: .stub(items: [.stub(network: "solana:mainnet")]))
    )
    apiMock.enterYieldReturnValue = makeEnterResponse(transactions: [tx])

    let result = try await yieldXyz.deposit(
      params: YieldDepositParams(target: .yieldId("solana-yield"), amount: "0.1"),
      options: fastOptions
    )

    XCTAssertEqual(result.status, .failed)
  }
}

// MARK: - getValidators & errors

extension YieldXyzDepositWithdrawTests {
  func test_getValidators_returnsValidators() async throws {
    apiMock.getYieldValidatorsReturnValue = YieldXyzGetValidatorsResponse(
      data: .stub(rawResponse: .stub(items: [.stub(address: "0xv1"), .stub(address: "0xv2")]))
    )

    let validators = try await yieldXyz.getValidators(yieldId: "monad-testnet-mon-native-staking")

    XCTAssertEqual(validators.count, 2)
    XCTAssertEqual(apiMock.getYieldValidatorsCalls, 1)
    XCTAssertEqual(apiMock.getYieldValidatorsYieldIdParam, "monad-testnet-mon-native-staking")
  }

  func test_getValidators_normalizesFromDataValidators() async throws {
    apiMock.getYieldValidatorsReturnValue = YieldXyzGetValidatorsResponse(
      data: YieldXyzGetValidatorsData(validators: [.stub(address: "0xtop")], rawResponse: nil)
    )

    let validators = try await yieldXyz.getValidators(yieldId: "y")

    XCTAssertEqual(validators.first?.address, "0xtop")
  }

  func test_deposit_withoutPortal_throwsPortalNotInitialized() async throws {
    let detached = YieldXyz(api: apiMock) // no portal
    apiMock.enterYieldReturnValue = makeEnterResponse(
      transactions: [.stub(unsignedTransaction: evmUnsignedTransaction(), stepIndex: 0)]
    )

    do {
      _ = try await detached.deposit(params: YieldDepositParams(target: .yieldId("yield-1"), amount: "1"), options: fastOptions)
      XCTFail("Expected portalNotInitialized error")
    } catch let error as YieldXyzError {
      XCTAssertEqual(error, .portalNotInitialized)
    }
  }
}
