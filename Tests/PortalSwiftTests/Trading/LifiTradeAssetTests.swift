//
//  LifiTradeAssetTests.swift
//  PortalSwift
//
//  Created by Portal Labs
//

import AnyCodable
import Foundation
@testable import PortalSwift
import XCTest

final class LifiTradeAssetTests: XCTestCase {
  var apiMock: PortalLifiTradingApiMock!

  // Fast poll options so the per-step LiFi status poll doesn't add real delays in tests.
  private let fastPollOptions = LifiPollStatusOptions(everyMs: 1, initialDelayMs: 0, timeoutMs: 5000)

  override func setUpWithError() throws {
    apiMock = PortalLifiTradingApiMock()
  }

  override func tearDownWithError() throws {
    apiMock = nil
  }

  // MARK: - Helpers

  private func makeStepWithTransactionRequest(
    from: String = "0x1234567890abcdef1234567890abcdef12345678",
    to: String = "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
    value: String = "0x0",
    data: String = "0xdeadbeef",
    tool: String = "relay",
    fromChainId: String = "8453",
    toChainId: String = "137"
  ) -> LifiStep {
    let action = LifiAction.stub(fromChainId: fromChainId, toChainId: toChainId)
    let transactionRequest = AnyCodable([
      "from": from,
      "to": to,
      "value": value,
      "data": data,
      "chainId": fromChainId,
    ])
    return LifiStep.stub(tool: tool, action: action, transactionRequest: transactionRequest)
  }

  private func makeLifi(
    signAndSend: @escaping LifiSignAndSendTransaction,
    waitForConfirmation: @escaping LifiWaitForConfirmation
  ) -> Lifi {
    Lifi(
      api: apiMock,
      signAndSendTransaction: signAndSend,
      waitForConfirmation: waitForConfirmation,
      stepPollOptions: fastPollOptions
    )
  }

  /// Builds a step whose transactionRequest carries a raw (non-String) `value` and/or `chainId` so
  /// the Int/Double parsing and CAIP-2 normalization branches can be exercised. Passing
  /// `chainId: nil` omits the key entirely (forcing the `action.fromChainId` fallback).
  private func makeStepWithRawTransaction(
    value: Any = "0x0",
    chainId: Any? = "8453",
    fromChainId: String = "8453",
    toChainId: String = "137",
    from: String = "0x1234567890abcdef1234567890abcdef12345678",
    to: String = "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
    data: String = "0xdeadbeef",
    tool: String = "relay"
  ) -> LifiStep {
    var dict: [String: Any] = ["from": from, "to": to, "value": value, "data": data]
    if let chainId {
      dict["chainId"] = chainId
    }
    let action = LifiAction.stub(fromChainId: fromChainId, toChainId: toChainId)
    return LifiStep.stub(tool: tool, action: action, transactionRequest: AnyCodable(dict))
  }

  /// Runs a single-step, single-route `tradeAsset` where `getRouteStep` returns `step`, capturing
  /// the `ETHTransactionParam` and CAIP-2 chainId passed to the signer. Resets the api mock first.
  private func runTradeAsset(
    returningStep step: LifiStep
  ) async throws -> (transaction: ETHTransactionParam?, chainId: String) {
    apiMock.reset()
    let route = LifiRoute.stub(steps: [step])
    apiMock.getRoutesReturnValue = LifiRoutesResponse.stub(
      data: LifiRoutesData(rawResponse: LifiRoutesRawResponse(routes: [route]))
    )
    apiMock.getRouteStepReturnValue = LifiStepTransactionResponse(
      data: LifiStepTransactionData(rawResponse: step), error: nil
    )
    apiMock.getStatusReturnValue = LifiStatusResponse.stub(
      data: LifiStatusData(rawResponse: LifiStatusRawResponse.stub(status: .done))
    )
    var capturedTx: ETHTransactionParam?
    var capturedChainId = ""
    let lifi = makeLifi(
      signAndSend: { tx, chainId in
        capturedTx = tx
        capturedChainId = chainId
        return "0xhash1"
      },
      waitForConfirmation: { _, _ in .confirmed }
    )
    _ = try await lifi.tradeAsset(params: LifiTradeAssetParams.stub())
    return (capturedTx, capturedChainId)
  }
}

// MARK: - tradeAsset success

extension LifiTradeAssetTests {
  func test_tradeAsset_singleStep_succeeds() async throws {
    // given
    let step = makeStepWithTransactionRequest()
    let route = LifiRoute.stub(steps: [step])
    apiMock.getRoutesReturnValue = LifiRoutesResponse.stub(
      data: LifiRoutesData(rawResponse: LifiRoutesRawResponse(routes: [route]))
    )
    apiMock.getRouteStepReturnValue = LifiStepTransactionResponse(
      data: LifiStepTransactionData(rawResponse: step), error: nil
    )
    apiMock.getStatusReturnValue = LifiStatusResponse.stub(
      data: LifiStatusData(rawResponse: LifiStatusRawResponse.stub(status: .done))
    )

    var signedChainIds: [String] = []
    let lifi = makeLifi(
      signAndSend: { _, chainId in
        signedChainIds.append(chainId)
        return "0xhash1"
      },
      waitForConfirmation: { _, _ in .confirmed }
    )

    // when
    let result = try await lifi.tradeAsset(params: LifiTradeAssetParams.stub())

    // then
    XCTAssertEqual(result.hashes, ["0xhash1"])
    XCTAssertEqual(result.steps.count, 1)
    XCTAssertEqual(apiMock.getRoutesCalls, 1)
    XCTAssertEqual(apiMock.getRouteStepCalls, 1)
    XCTAssertGreaterThanOrEqual(apiMock.getStatusCalls, 1)
    XCTAssertEqual(signedChainIds, ["eip155:8453"])
  }

  func test_tradeAsset_multipleSteps_executesSequentially() async throws {
    // given
    let step1 = makeStepWithTransactionRequest(data: "0x01", fromChainId: "8453")
    let step2 = makeStepWithTransactionRequest(data: "0x02", fromChainId: "137")
    let route = LifiRoute.stub(steps: [step1, step2])
    apiMock.getRoutesReturnValue = LifiRoutesResponse.stub(
      data: LifiRoutesData(rawResponse: LifiRoutesRawResponse(routes: [route]))
    )
    // Return a DISTINCT response per step (step1 then step2) so per-step transaction parsing and
    // CAIP-2 chainId resolution are actually exercised rather than reusing step1 for both.
    apiMock.getRouteStepResultSequence = [
      Swift.Result<LifiStepTransactionResponse, Error>.success(
        LifiStepTransactionResponse(data: LifiStepTransactionData(rawResponse: step1), error: nil)
      ),
      Swift.Result<LifiStepTransactionResponse, Error>.success(
        LifiStepTransactionResponse(data: LifiStepTransactionData(rawResponse: step2), error: nil)
      ),
    ]
    apiMock.getStatusReturnValue = LifiStatusResponse.stub(
      data: LifiStatusData(rawResponse: LifiStatusRawResponse.stub(status: .done))
    )

    var signCount = 0
    var signedChainIds: [String] = []
    let lifi = makeLifi(
      signAndSend: { _, chainId in
        signCount += 1
        signedChainIds.append(chainId)
        return "0xhash\(signCount)"
      },
      waitForConfirmation: { _, _ in .confirmed }
    )

    // when
    let result = try await lifi.tradeAsset(params: LifiTradeAssetParams.stub())

    // then
    XCTAssertEqual(result.hashes, ["0xhash1", "0xhash2"])
    XCTAssertEqual(result.steps.count, 2)
    XCTAssertEqual(apiMock.getRouteStepCalls, 2)
    // The last getRouteStep request must correspond to step2 (not a reused step1), so the steps
    // are fetched in order. step1/step2 are distinguished by their action.fromChainId.
    XCTAssertEqual(apiMock.getRouteStepRequestParam?.action.fromChainId, "137")
    // Each step's own chainId is resolved independently (step1 -> 8453, step2 -> 137).
    XCTAssertEqual(signedChainIds, ["eip155:8453", "eip155:137"])
  }

  func test_tradeAsset_emitsProgressStatuses() async throws {
    // given
    let step = makeStepWithTransactionRequest()
    let route = LifiRoute.stub(steps: [step])
    apiMock.getRoutesReturnValue = LifiRoutesResponse.stub(
      data: LifiRoutesData(rawResponse: LifiRoutesRawResponse(routes: [route]))
    )
    apiMock.getRouteStepReturnValue = LifiStepTransactionResponse(
      data: LifiStepTransactionData(rawResponse: step), error: nil
    )
    apiMock.getStatusReturnValue = LifiStatusResponse.stub(
      data: LifiStatusData(rawResponse: LifiStatusRawResponse.stub(status: .done))
    )

    var statuses: [LifiTradeAssetProgressStatus] = []
    let params = LifiTradeAssetParams.stub(onProgress: { status, _ in
      statuses.append(status)
    })

    let lifi = makeLifi(
      signAndSend: { _, _ in "0xhash1" },
      waitForConfirmation: { _, _ in .confirmed }
    )

    // when
    _ = try await lifi.tradeAsset(params: params)

    // then
    XCTAssertEqual(statuses.first, .fetchingRoutes)
    XCTAssertTrue(statuses.contains(.routeSelected))
    XCTAssertTrue(statuses.contains(.preparingStep))
    XCTAssertTrue(statuses.contains(.signing))
    XCTAssertTrue(statuses.contains(.submitted))
    XCTAssertTrue(statuses.contains(.confirming))
    XCTAssertTrue(statuses.contains(.lifiPending))
    XCTAssertTrue(statuses.contains(.stepDone))
    XCTAssertEqual(statuses.last, .complete)
  }
}

// MARK: - tradeAsset failures

extension LifiTradeAssetTests {
  func test_tradeAsset_withoutSigner_throwsMissingSigner() async {
    // given
    let lifi = Lifi(api: apiMock)

    // when / then
    do {
      _ = try await lifi.tradeAsset(params: LifiTradeAssetParams.stub())
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual(error as? LifiTradeAssetError, .missingSigner)
    }
  }

  func test_tradeAsset_withoutConfirmation_throwsMissingConfirmation() async {
    // given
    let lifi = Lifi(
      api: apiMock,
      signAndSendTransaction: { _, _ in "0xhash" },
      waitForConfirmation: nil
    )

    // when / then
    do {
      _ = try await lifi.tradeAsset(params: LifiTradeAssetParams.stub())
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual(error as? LifiTradeAssetError, .missingConfirmation)
    }
  }

  func test_tradeAsset_withNoRoutes_throwsNoRoutesFound() async {
    // given
    apiMock.getRoutesReturnValue = LifiRoutesResponse.stub(
      data: LifiRoutesData(rawResponse: LifiRoutesRawResponse(routes: []))
    )
    let lifi = makeLifi(
      signAndSend: { _, _ in "0xhash" },
      waitForConfirmation: { _, _ in .confirmed }
    )

    // when / then
    do {
      _ = try await lifi.tradeAsset(params: LifiTradeAssetParams.stub())
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual(error as? LifiTradeAssetError, .noRoutesFound)
    }
  }

  func test_tradeAsset_confirmationFails_throwsAndReportsFailed() async {
    // given
    let step = makeStepWithTransactionRequest()
    let route = LifiRoute.stub(steps: [step])
    apiMock.getRoutesReturnValue = LifiRoutesResponse.stub(
      data: LifiRoutesData(rawResponse: LifiRoutesRawResponse(routes: [route]))
    )
    apiMock.getRouteStepReturnValue = LifiStepTransactionResponse(
      data: LifiStepTransactionData(rawResponse: step), error: nil
    )

    var failedReported = false
    let params = LifiTradeAssetParams.stub(onProgress: { status, _ in
      if status == .failed { failedReported = true }
    })

    let lifi = makeLifi(
      signAndSend: { _, _ in "0xhash1" },
      waitForConfirmation: { _, _ in .reverted }
    )

    // when / then
    do {
      _ = try await lifi.tradeAsset(params: params)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual(error as? LifiTradeAssetError, .transactionConfirmationFailed("0xhash1"))
      XCTAssertTrue(failedReported)
    }
  }

  func test_tradeAsset_confirmationTimedOut_throwsTimedOutAndReportsFailed() async {
    // given
    let step = makeStepWithTransactionRequest()
    let route = LifiRoute.stub(steps: [step])
    apiMock.getRoutesReturnValue = LifiRoutesResponse.stub(
      data: LifiRoutesData(rawResponse: LifiRoutesRawResponse(routes: [route]))
    )
    apiMock.getRouteStepReturnValue = LifiStepTransactionResponse(
      data: LifiStepTransactionData(rawResponse: step), error: nil
    )

    var failedReported = false
    let params = LifiTradeAssetParams.stub(onProgress: { status, _ in
      if status == .failed { failedReported = true }
    })

    let lifi = makeLifi(
      signAndSend: { _, _ in "0xhash1" },
      waitForConfirmation: { _, _ in .timedOut }
    )

    // when / then
    do {
      _ = try await lifi.tradeAsset(params: params)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual(error as? LifiTradeAssetError, .transactionConfirmationTimedOut("0xhash1"))
      XCTAssertTrue(failedReported)
    }
  }

  func test_tradeAsset_lifiStatusFailed_throwsLifiTransferFailed() async {
    // given
    let step = makeStepWithTransactionRequest()
    let route = LifiRoute.stub(steps: [step])
    apiMock.getRoutesReturnValue = LifiRoutesResponse.stub(
      data: LifiRoutesData(rawResponse: LifiRoutesRawResponse(routes: [route]))
    )
    apiMock.getRouteStepReturnValue = LifiStepTransactionResponse(
      data: LifiStepTransactionData(rawResponse: step), error: nil
    )
    apiMock.getStatusReturnValue = LifiStatusResponse.stub(
      data: LifiStatusData(rawResponse: LifiStatusRawResponse.stub(
        status: .failed,
        substatus: .unknownError,
        substatusMessage: "Bridge reverted"
      ))
    )

    let lifi = makeLifi(
      signAndSend: { _, _ in "0xhash1" },
      waitForConfirmation: { _, _ in .confirmed }
    )

    // when / then
    do {
      _ = try await lifi.tradeAsset(params: LifiTradeAssetParams.stub())
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual(error as? LifiTradeAssetError, .lifiTransferFailed("Bridge reverted"))
    }
  }

  func test_tradeAsset_routeIndexOutOfBounds_throws() async {
    // given
    let step = makeStepWithTransactionRequest()
    let route = LifiRoute.stub(steps: [step])
    apiMock.getRoutesReturnValue = LifiRoutesResponse.stub(
      data: LifiRoutesData(rawResponse: LifiRoutesRawResponse(routes: [route]))
    )
    let lifi = makeLifi(
      signAndSend: { _, _ in "0xhash1" },
      waitForConfirmation: { _, _ in .confirmed }
    )

    // when / then
    do {
      _ = try await lifi.tradeAsset(params: LifiTradeAssetParams.stub(routeIndex: 5))
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual(error as? LifiTradeAssetError, .routeIndexOutOfBounds)
    }
  }
}

// MARK: - transaction value parsing

extension LifiTradeAssetTests {
  func test_tradeAsset_parsesIntValue_usesLlxFormatWithoutTruncation() async throws {
    // A wei amount larger than UInt32.max would be truncated by %x; %llx must be used.
    let bigWei = 12_345_678_901_234
    let result = try await runTradeAsset(returningStep: makeStepWithRawTransaction(value: bigWei))
    XCTAssertEqual(result.transaction?.value, String(format: "0x%llx", UInt64(bigWei)))
  }

  func test_tradeAsset_parsesIntegralDoubleValue() async throws {
    let result = try await runTradeAsset(returningStep: makeStepWithRawTransaction(value: 1_000_000.0))
    XCTAssertEqual(result.transaction?.value, "0xf4240") // 1_000_000
  }

  func test_tradeAsset_rejectsFractionalDoubleValue_throwsInvalidTransactionRequest() async {
    do {
      _ = try await runTradeAsset(returningStep: makeStepWithRawTransaction(value: 1.5))
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual(error as? LifiTradeAssetError, .invalidTransactionRequest)
    }
  }

  func test_tradeAsset_rejectsUnsafeIntegerDoubleValue_throwsInvalidTransactionRequest() async {
    // Beyond 2^53 a Double can't represent every integer, so it must be rejected.
    let unsafe = Double(UInt64(1) << 60)
    do {
      _ = try await runTradeAsset(returningStep: makeStepWithRawTransaction(value: unsafe))
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual(error as? LifiTradeAssetError, .invalidTransactionRequest)
    }
  }
}

// MARK: - CAIP-2 normalization

extension LifiTradeAssetTests {
  func test_tradeAsset_caip2Normalization_variants() async throws {
    // decimal string
    var r = try await runTradeAsset(returningStep: makeStepWithRawTransaction(chainId: "8453"))
    XCTAssertEqual(r.chainId, "eip155:8453")
    // hex string
    r = try await runTradeAsset(returningStep: makeStepWithRawTransaction(chainId: "0x2105"))
    XCTAssertEqual(r.chainId, "eip155:8453")
    // already-prefixed eip155 (no double prefix)
    r = try await runTradeAsset(returningStep: makeStepWithRawTransaction(chainId: "eip155:8453"))
    XCTAssertEqual(r.chainId, "eip155:8453")
    // Int
    r = try await runTradeAsset(returningStep: makeStepWithRawTransaction(chainId: 8453))
    XCTAssertEqual(r.chainId, "eip155:8453")
    // integral Double
    r = try await runTradeAsset(returningStep: makeStepWithRawTransaction(chainId: 8453.0))
    XCTAssertEqual(r.chainId, "eip155:8453")
    // missing chainId -> falls back to action.fromChainId
    r = try await runTradeAsset(returningStep: makeStepWithRawTransaction(chainId: nil, fromChainId: "42161"))
    XCTAssertEqual(r.chainId, "eip155:42161")
  }
}

// MARK: - tradeAsset error cases

extension LifiTradeAssetTests {
  func test_tradeAsset_routeHasNoSteps_throws() async {
    apiMock.getRoutesReturnValue = LifiRoutesResponse.stub(
      data: LifiRoutesData(rawResponse: LifiRoutesRawResponse(routes: [LifiRoute.stub(steps: [])]))
    )
    let lifi = makeLifi(signAndSend: { _, _ in "0xhash" }, waitForConfirmation: { _, _ in .confirmed })

    do {
      _ = try await lifi.tradeAsset(params: LifiTradeAssetParams.stub())
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual(error as? LifiTradeAssetError, .routeHasNoSteps)
    }
  }

  func test_tradeAsset_missingTransactionRequest_throws() async {
    let route = LifiRoute.stub(steps: [makeStepWithTransactionRequest()])
    apiMock.getRoutesReturnValue = LifiRoutesResponse.stub(
      data: LifiRoutesData(rawResponse: LifiRoutesRawResponse(routes: [route]))
    )
    // getRouteStep returns a step with no transactionRequest at all.
    apiMock.getRouteStepReturnValue = LifiStepTransactionResponse(
      data: LifiStepTransactionData(rawResponse: LifiStep.stub(transactionRequest: nil)), error: nil
    )
    let lifi = makeLifi(signAndSend: { _, _ in "0xhash" }, waitForConfirmation: { _, _ in .confirmed })

    do {
      _ = try await lifi.tradeAsset(params: LifiTradeAssetParams.stub())
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual(error as? LifiTradeAssetError, .missingTransactionRequest)
    }
  }

  func test_tradeAsset_invalidTransactionRequest_throws() async {
    let route = LifiRoute.stub(steps: [makeStepWithTransactionRequest()])
    apiMock.getRoutesReturnValue = LifiRoutesResponse.stub(
      data: LifiRoutesData(rawResponse: LifiRoutesRawResponse(routes: [route]))
    )
    // transactionRequest present but not an object — malformed, not missing.
    apiMock.getRouteStepReturnValue = LifiStepTransactionResponse(
      data: LifiStepTransactionData(rawResponse: LifiStep.stub(transactionRequest: AnyCodable("not-an-object"))),
      error: nil
    )
    let lifi = makeLifi(signAndSend: { _, _ in "0xhash" }, waitForConfirmation: { _, _ in .confirmed })

    do {
      _ = try await lifi.tradeAsset(params: LifiTradeAssetParams.stub())
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual(error as? LifiTradeAssetError, .invalidTransactionRequest)
    }
  }
}

// MARK: - pollStatus

extension LifiTradeAssetTests {
  func test_pollStatus_done_returnsTerminal() async throws {
    // given
    apiMock.getStatusReturnValue = LifiStatusResponse.stub(
      data: LifiStatusData(rawResponse: LifiStatusRawResponse.stub(status: .done))
    )
    let lifi = Lifi(api: apiMock)

    // when
    let terminal = try await lifi.pollStatus(request: LifiStatusRequest.stub(), options: fastPollOptions)

    // then
    XCTAssertEqual(terminal.status, .done)
    XCTAssertGreaterThanOrEqual(apiMock.getStatusCalls, 1)
  }

  func test_pollStatus_failed_throws() async {
    // given
    apiMock.getStatusReturnValue = LifiStatusResponse.stub(
      data: LifiStatusData(rawResponse: LifiStatusRawResponse.stub(
        status: .failed,
        substatusMessage: "Failed transfer"
      ))
    )
    let lifi = Lifi(api: apiMock)

    // when / then
    do {
      _ = try await lifi.pollStatus(request: LifiStatusRequest.stub(), options: fastPollOptions)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual(error as? LifiTradeAssetError, .lifiTransferFailed("Failed transfer"))
    }
  }

  func test_pollStatus_onUpdateReturningFalse_stops() async throws {
    // given a pending status that never resolves
    apiMock.getStatusReturnValue = LifiStatusResponse.stub(
      data: LifiStatusData(rawResponse: LifiStatusRawResponse.stub(status: .pending))
    )
    let lifi = Lifi(api: apiMock)

    // when - onUpdate returns false to stop after the first poll
    let result = try await lifi.pollStatus(
      request: LifiStatusRequest.stub(),
      onUpdate: { _ in false }
    )

    // then
    XCTAssertEqual(result.status, .pending)
  }

  func test_pollStatus_timesOut_throwsPollTimeout() async {
    // given a status that never reaches a terminal state and a tiny timeout
    apiMock.getStatusReturnValue = LifiStatusResponse.stub(
      data: LifiStatusData(rawResponse: LifiStatusRawResponse.stub(status: .pending))
    )
    let lifi = Lifi(api: apiMock)
    let options = LifiPollStatusOptions(everyMs: 1, initialDelayMs: 0, timeoutMs: 1)

    // when / then
    do {
      _ = try await lifi.pollStatus(request: LifiStatusRequest.stub(), options: options)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual(error as? LifiTradeAssetError, .pollTimeout)
    }
  }

  func test_pollStatus_transientErrorThenRecovers_returnsTerminal() async throws {
    // given a transient network error on the first poll, then a DONE status
    struct TransientError: Error {}
    apiMock.getStatusResultSequence = [
      Swift.Result<LifiStatusResponse, Error>.failure(TransientError()),
      Swift.Result<LifiStatusResponse, Error>.success(LifiStatusResponse.stub(
        data: LifiStatusData(rawResponse: LifiStatusRawResponse.stub(status: .done))
      )),
    ]
    let lifi = Lifi(api: apiMock)

    // when
    let terminal = try await lifi.pollStatus(request: LifiStatusRequest.stub(), options: fastPollOptions)

    // then - the transient error was retried, not surfaced
    XCTAssertEqual(terminal.status, .done)
    XCTAssertEqual(apiMock.getStatusCalls, 2)
  }

  func test_pollStatus_cancellation_throwsCancellationError() async {
    // given a status that never resolves and a long poll interval so the task parks in sleep
    apiMock.getStatusReturnValue = LifiStatusResponse.stub(
      data: LifiStatusData(rawResponse: LifiStatusRawResponse.stub(status: .pending))
    )
    let lifi = Lifi(api: apiMock)
    let options = LifiPollStatusOptions(everyMs: 10_000, initialDelayMs: 0, timeoutMs: 600_000)

    let task = Task { () -> LifiStatusRawResponse in
      try await lifi.pollStatus(request: LifiStatusRequest.stub(), options: options)
    }

    // let it enter the polling loop, then cancel
    try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
    task.cancel()

    // then
    do {
      _ = try await task.value
      XCTFail("Expected cancellation to propagate")
    } catch {
      XCTAssertTrue(error is CancellationError, "Expected CancellationError, got \(error)")
    }
  }
}
