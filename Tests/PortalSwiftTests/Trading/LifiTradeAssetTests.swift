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
    // getRouteStep returns the same stub regardless; both steps share it for simplicity.
    apiMock.getRouteStepReturnValue = LifiStepTransactionResponse(
      data: LifiStepTransactionData(rawResponse: step1), error: nil
    )
    apiMock.getStatusReturnValue = LifiStatusResponse.stub(
      data: LifiStatusData(rawResponse: LifiStatusRawResponse.stub(status: .done))
    )

    var signCount = 0
    let lifi = makeLifi(
      signAndSend: { _, _ in
        signCount += 1
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
}
