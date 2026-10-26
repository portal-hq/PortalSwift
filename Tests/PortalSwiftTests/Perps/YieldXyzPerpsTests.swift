//
//  YieldXyzPerpsTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import AnyCodable
@testable import PortalSwift
import XCTest

final class YieldXyzPerpsTests: XCTestCase {
  private let wallet = YieldXyzPerpsFixtures.wallet
  private let other = "0x000000000000000000000000000000000000dEaD"

  private var api: PortalYieldXyzPerpsApiMock!
  private var walletAddress: String?
  private var perps: YieldXyzPerps!

  override func setUp() {
    super.setUp()
    api = PortalYieldXyzPerpsApiMock()
    walletAddress = wallet
    perps = YieldXyzPerps(api: api, dependencies: YieldXyzPerpsExecutionDependencies(getWalletAddress: { [unowned self] in self.walletAddress }))
  }

  override func tearDown() {
    api = nil
    perps = nil
    super.tearDown()
  }

  private func assertThrows(_ expected: YieldXyzPerpsError, _ call: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
    do {
      try await call()
      XCTFail("Expected \(expected) to be thrown.", file: file, line: line)
    } catch {
      XCTAssertEqual(error as? YieldXyzPerpsError, expected, file: file, line: line)
    }
  }

  // MARK: - Pass-through methods

  func test_marketAndHealthMethods_forwardToTheApi() async throws {
    _ = try await perps.getProviders()
    _ = try await perps.getProvider(providerId: "hyperliquid")
    _ = try await perps.getMarkets(params: YieldXyzPerpsGetMarketsParams(limit: 5))
    _ = try await perps.getMarket(marketId: "hyperliquid-eth-usdc")
    _ = try await perps.getMarketCandles(marketId: "m", params: YieldXyzPerpsGetMarketCandlesParams(interval: .oneDay, from: 1))
    _ = try await perps.getAction(actionId: "act-1")
    _ = try await perps.getEvent(eventId: "evt-1")
    let health = try await perps.getHealth()
    let providersHealth = try await perps.getProvidersHealth()

    XCTAssertEqual(api.getProvidersCallsCount, 1)
    XCTAssertEqual(api.getProviderProviderIdParam, "hyperliquid")
    XCTAssertEqual(api.getMarketsParams, YieldXyzPerpsGetMarketsParams(limit: 5))
    XCTAssertEqual(api.getMarketMarketIdParam, "hyperliquid-eth-usdc")
    XCTAssertEqual(api.getMarketCandlesMarketIdParam, "m")
    XCTAssertEqual(api.getMarketCandlesParams, YieldXyzPerpsGetMarketCandlesParams(interval: .oneDay, from: 1))
    XCTAssertEqual(api.getActionActionIdParam, "act-1")
    XCTAssertEqual(api.getEventEventIdParam, "evt-1")
    XCTAssertEqual(health.data.status, .ok)
    XCTAssertEqual(providersHealth.data.providers.first?.state, .healthy)
  }

  func test_getMarkets_withoutParams_sendsNoFilters() async throws {
    _ = try await perps.getMarkets()

    XCTAssertEqual(api.getMarketsParams, YieldXyzPerpsGetMarketsParams())
  }

  // MARK: - Account data

  func test_getPositions_defaultsToTheWalletAddress() async throws {
    let response = try await perps.getPositions(params: YieldXyzPerpsPortfolioParams(providerId: "hyperliquid"))

    XCTAssertEqual(api.getPositionsRequest, YieldXyzPerpsPortfolioRequest(address: wallet, providerId: "hyperliquid"))
    XCTAssertEqual(response.data, [.stub()])
  }

  func test_getPositions_usesAnExplicitAddress() async throws {
    _ = try await perps.getPositions(params: YieldXyzPerpsPortfolioParams(address: other, providerIds: ["hyperliquid"]))

    XCTAssertEqual(api.getPositionsRequest, YieldXyzPerpsPortfolioRequest(address: other, providerIds: ["hyperliquid"]))
  }

  func test_getPositions_requiresAVenue() async {
    await assertThrows(.providerRequired(method: "getPositions")) {
      _ = try await self.perps.getPositions(params: YieldXyzPerpsPortfolioParams())
    }
    await assertThrows(.providerRequired(method: "getPositions")) {
      _ = try await self.perps.getPositions(params: YieldXyzPerpsPortfolioParams(providerId: "", providerIds: []))
    }
    await assertThrows(.providerRequired(method: "getPositions")) {
      _ = try await self.perps.getPositions(params: YieldXyzPerpsPortfolioParams(providerIds: [""]))
    }
    XCTAssertNil(api.getPositionsRequest)
  }

  func test_getOrders_defaultsToTheWalletAddress_andRequiresAVenue() async throws {
    _ = try await perps.getOrders(params: YieldXyzPerpsPortfolioParams(providerIds: ["hyperliquid", "other"]))
    XCTAssertEqual(api.getOrdersRequest, YieldXyzPerpsPortfolioRequest(address: wallet, providerIds: ["hyperliquid", "other"]))

    await assertThrows(.providerRequired(method: "getOrders")) {
      _ = try await self.perps.getOrders(params: YieldXyzPerpsPortfolioParams(address: self.other))
    }
  }

  func test_getBalances_sendsOneVenue() async throws {
    let response = try await perps.getBalances(params: YieldXyzPerpsBalancesParams(providerId: "hyperliquid"))

    XCTAssertEqual(api.getBalancesRequest, YieldXyzPerpsPortfolioRequest(address: wallet, providerId: "hyperliquid"))
    XCTAssertEqual(response.data, .stub())
  }

  func test_getBalances_rejectsAnEmptyVenue() async {
    await assertThrows(.providerRequired(method: "getBalances")) {
      _ = try await self.perps.getBalances(params: YieldXyzPerpsBalancesParams(providerId: ""))
    }
  }

  func test_createAction_rejectsAnEmptyVenue_beforeSendingAnything() async {
    await assertThrows(.providerRequired(method: "createAction")) {
      _ = try await self.perps.createAction(params: YieldXyzPerpsCreateActionParams(providerId: "", action: .open, args: YieldXyzPerpsActionArgs()))
    }
    XCTAssertEqual(api.createActionCallsCount, 0)
  }

  func test_accountRequests_failWithoutAnyAddress() async {
    walletAddress = nil

    await assertThrows(.noAddress) {
      _ = try await self.perps.getPositions(params: YieldXyzPerpsPortfolioParams(providerId: "hyperliquid"))
    }
    await assertThrows(.noAddress) {
      _ = try await self.perps.getActivity(params: YieldXyzPerpsGetActivityParams(providerId: "hyperliquid"))
    }
  }

  func test_accountRequests_failWithoutAWalletDependency() async {
    perps = YieldXyzPerps(api: api)

    await assertThrows(.noAddress) {
      _ = try await self.perps.getEvents(params: YieldXyzPerpsGetEventsParams(providerId: "hyperliquid"))
    }
  }

  /// Yield.xyz rejects these lists without a venue, and the Portal API forwards them, so the SDK
  /// refuses them before sending anything.
  func test_listRequests_requireAVenue_beforeSendingAnything() async {
    await assertThrows(.providerRequired(method: "getActions")) {
      _ = try await self.perps.getActions(params: YieldXyzPerpsGetActionsParams(limit: 10, providerIds: [""]))
    }
    await assertThrows(.providerRequired(method: "getActivity")) {
      _ = try await self.perps.getActivity(params: YieldXyzPerpsGetActivityParams(limit: 10, providerIds: [""]))
    }
    await assertThrows(.providerRequired(method: "getEvents")) {
      _ = try await self.perps.getEvents(params: YieldXyzPerpsGetEventsParams(limit: 10))
    }
    XCTAssertNil(api.getActionsRequest)
    XCTAssertNil(api.getActivityRequest)
    XCTAssertNil(api.getEventsRequest)
  }

  // MARK: - Actions

  func test_createAction_defaultsToTheWalletAddress_andSendsArgsVerbatim() async throws {
    let args = YieldXyzPerpsActionArgs(marketId: "hyperliquid-eth-usdc", stopLossPrice: 3600, takeProfitPrice: 4400, additionalFields: ["tif": "Gtc"])

    _ = try await perps.createAction(params: YieldXyzPerpsCreateActionParams(providerId: "hyperliquid", action: .setTpAndSl, args: args))

    XCTAssertEqual(api.createActionRequest, YieldXyzPerpsCreateActionRequest(providerId: "hyperliquid", address: wallet, action: .setTpAndSl, args: args))
  }

  func test_createAction_acceptsAPendingActionAsIs() async throws {
    let pending = YieldXyzPerpsPosition.stub().pendingActions[0]

    _ = try await perps.createAction(params: YieldXyzPerpsCreateActionParams(providerId: "hyperliquid", action: pending.type, args: pending.args, address: other))

    XCTAssertEqual(api.createActionRequest?.action, .close)
    XCTAssertEqual(api.createActionRequest?.args, pending.args)
    XCTAssertEqual(api.createActionRequest?.address, other)
  }

  func test_listRequests_defaultTheAddress_andForwardTheFilters() async throws {
    let actionsParams = YieldXyzPerpsGetActionsParams(limit: 10, providerId: "hyperliquid", type: .open, statuses: [.success])
    let activityParams = YieldXyzPerpsGetActivityParams(providerIds: ["hyperliquid"], actionStatus: .failed)
    let eventsParams = YieldXyzPerpsGetEventsParams(address: other, providerId: "hyperliquid", eventType: .liquidation, fromDate: "2026-09-01T00:00:00.000Z")

    _ = try await perps.getActions(params: actionsParams)
    _ = try await perps.getActivity(params: activityParams)
    _ = try await perps.getEvents(params: eventsParams)

    XCTAssertEqual(api.getActionsRequest, YieldXyzPerpsGetActionsRequest(address: wallet, params: actionsParams))
    XCTAssertEqual(api.getActivityRequest, YieldXyzPerpsGetActivityRequest(address: wallet, params: activityParams))
    XCTAssertEqual(api.getEventsRequest, YieldXyzPerpsGetEventsRequest(address: other, params: eventsParams))
  }

  func test_getActions_acceptsProviderIdsAlone() async throws {
    let params = YieldXyzPerpsGetActionsParams(providerIds: ["hyperliquid"])

    _ = try await perps.getActions(params: params)

    XCTAssertEqual(api.getActionsRequest, YieldXyzPerpsGetActionsRequest(address: wallet, params: params))
  }

  func test_submitTransaction_requiresASignatureOrAHash() async {
    await assertThrows(.submissionRequired) {
      _ = try await self.perps.submitTransaction(params: YieldXyzPerpsSubmitTransactionParams(transactionId: "tx", actionId: "act"))
    }
    XCTAssertTrue(api.submitTransactionParams.isEmpty)
  }

  func test_submitTransaction_requiresTheActionIdWithASignature() async {
    await assertThrows(.actionIdRequired) {
      _ = try await self.perps.submitTransaction(params: YieldXyzPerpsSubmitTransactionParams(transactionId: "tx", signedPayload: YieldXyzPerpsFixtures.signature))
    }
  }

  func test_submitTransaction_forwardsAValidSubmission() async throws {
    let signed = YieldXyzPerpsSubmitTransactionParams(transactionId: "tx", actionId: "act", signedPayload: YieldXyzPerpsFixtures.signature)
    let hashed = YieldXyzPerpsSubmitTransactionParams(transactionId: "tx", transactionHash: YieldXyzPerpsFixtures.fundingTxHash)

    _ = try await perps.submitTransaction(params: signed)
    _ = try await perps.submitTransaction(params: hashed)

    XCTAssertEqual(api.submitTransactionParams, [signed, hashed])
  }

  // MARK: - Perps facade

  func test_perps_wiresYieldxyzToThePerpsApi() async throws {
    let perpsApi = PortalYieldXyzPerpsApiMock()

    let facade = Perps(api: PortalApiMock(yieldxyzPerps: perpsApi))
    _ = try await facade.yieldxyz.getHealth()

    XCTAssertTrue(facade.yieldxyz is YieldXyzPerps)
    XCTAssertEqual(perpsApi.getHealthCallsCount, 1)
  }

  // MARK: - Errors

  func test_validationErrors_describeTheProblem() {
    XCTAssertEqual(YieldXyzPerpsError.noAddress.errorDescription, "[YieldXyzPerps] No address was provided and no Portal EVM wallet address is available.")
    XCTAssertEqual(YieldXyzPerpsError.providerRequired(method: "getOrders").errorDescription, "[YieldXyzPerps] getOrders requires providerId or providerIds.")
    XCTAssertEqual(
      YieldXyzPerpsExecutionError(reason: .timeout, message: "Action a did not reach a final status in time.").errorDescription,
      "[YieldXyzPerps] Action a did not reach a final status in time."
    )
  }

  func test_apiError_readsTheBodyOfA400() throws {
    let error = PortalRequestsError.clientError(
      #"400 - {"error":"Signature recovered to 0x1 but the action was built for 0x2","id":"PERPS_SIGNATURE_ADDRESS_MISMATCH","details":{"recovered":"0x1","expected":"0x2"}}"#,
      url: "https://api.portalhq.io"
    )

    let apiError = try XCTUnwrap(YieldXyzPerpsApiError.from(error))

    XCTAssertEqual(apiError.status, 400)
    XCTAssertEqual(apiError.id, YieldXyzPerpsErrorId.signatureAddressMismatch)
    XCTAssertEqual(apiError.message, "Signature recovered to 0x1 but the action was built for 0x2")
    XCTAssertEqual(apiError.details?["expected"], AnyCodable("0x2"))
    XCTAssertNil(apiError.code)
    XCTAssertNil(apiError.reason)
    XCTAssertTrue(apiError.isSignatureError)
    XCTAssertFalse(apiError.isRateLimit)
  }

  func test_apiError_readsTheVenueCodeOfA503() throws {
    let error = PortalRequestsError.internalServerError(
      #"503 - {"error":"Yield.xyz Perps is unavailable","details":{"code":"SUBMIT_BROADCAST_FAILED","integration":"yield-xyz-perps"}}"#,
      url: "https://api.portalhq.io"
    )

    let apiError = try XCTUnwrap(YieldXyzPerpsApiError.from(error))

    XCTAssertEqual(apiError.status, 503)
    XCTAssertEqual(apiError.code, "SUBMIT_BROADCAST_FAILED")
    XCTAssertEqual(apiError.details?["integration"], AnyCodable("yield-xyz-perps"))
  }

  func test_apiError_readsTheCodeAndReasonOfARejectedRequest() throws {
    let error = PortalRequestsError.clientError(
      #"400 - {"error":"Yield.xyz Perps rejected the request","details":{"code":"EXECUTE_INVALID_ARGUMENT","reason":"NO_ROUTE_AVAILABLE"}}"#,
      url: "https://api.portalhq.io"
    )

    let apiError = try XCTUnwrap(YieldXyzPerpsApiError.from(error))

    XCTAssertEqual(apiError.status, 400)
    XCTAssertEqual(apiError.code, "EXECUTE_INVALID_ARGUMENT")
    XCTAssertEqual(apiError.reason, "NO_ROUTE_AVAILABLE")
  }

  func test_apiError_readsSchemaDrift() throws {
    let error = PortalRequestsError.internalServerError(
      #"500 - {"error":"yield-xyz-perps returned a response for GET /v1/markets that does not match the expected schema","id":"INTEGRATION_RESPONSE_SCHEMA_DRIFT","details":{"integration":"yield-xyz-perps","endpoint":"GET /v1/markets","issues":[]}}"#,
      url: "https://api.portalhq.io"
    )

    let apiError = try XCTUnwrap(YieldXyzPerpsApiError.from(error))

    XCTAssertEqual(apiError.status, 500)
    XCTAssertTrue(apiError.isSchemaDrift)
    XCTAssertFalse(apiError.isEoaRequired)
  }

  func test_apiError_readsTheEoaRequirementAndRateLimits() throws {
    let eoa = PortalRequestsError.clientError(#"400 - {"error":"Perps require an EOA client","id":"INTEGRATION_REQUIRES_EOA_CLIENT"}"#, url: "")
    let rateLimited = PortalRequestsError.clientError(#"429 - {"error":"Yield.xyz Perps rate limit exceeded"}"#, url: "")

    XCTAssertEqual(YieldXyzPerpsApiError.from(eoa)?.isEoaRequired, true)
    XCTAssertEqual(YieldXyzPerpsApiError.from(rateLimited)?.isRateLimit, true)
  }

  func test_apiError_keepsANonJsonBodyAsTheMessage() {
    let apiError = YieldXyzPerpsApiError.from(PortalRequestsError.internalServerError("503 - Service Unavailable", url: ""))

    XCTAssertEqual(apiError, YieldXyzPerpsApiError(status: 503, message: "Service Unavailable"))
  }

  func test_apiError_keepsTheRawBodyWhenItHasNoErrorMessage() {
    let apiError = YieldXyzPerpsApiError.from(PortalRequestsError.internalServerError(#"502 - {"message":"Bad gateway"}"#, url: ""))

    XCTAssertEqual(apiError?.status, 502)
    XCTAssertEqual(apiError?.message, #"{"message":"Bad gateway"}"#)
  }

  func test_apiError_mapsUnauthorizedTo401() {
    XCTAssertEqual(YieldXyzPerpsApiError.from(PortalRequestsError.unauthorized), YieldXyzPerpsApiError(status: 401))
  }

  func test_apiError_unwrapsAnExecutionError() {
    let cause = PortalRequestsError.clientError(#"400 - {"error":"x","id":"PERPS_SIGNATURE_INVALID"}"#, url: "")
    let execution = YieldXyzPerpsExecutionError(reason: .submitRejected, message: "rejected", underlyingError: cause)

    XCTAssertEqual(YieldXyzPerpsApiError.from(execution)?.id, YieldXyzPerpsErrorId.signatureInvalid)
  }

  func test_apiError_isNilForNonHttpFailures() {
    XCTAssertNil(YieldXyzPerpsApiError.from(URLError(.timedOut)))
    XCTAssertNil(YieldXyzPerpsApiError.from(PortalRequestsError.couldNotParseHttpResponse))
    XCTAssertNil(YieldXyzPerpsApiError.from(nil))
    XCTAssertNil(YieldXyzPerpsApiError.from(YieldXyzPerpsExecutionError(reason: .timeout, message: "t")))
  }

  func test_requestFailure_classification() {
    XCTAssertTrue(YieldXyzRequestFailure.isTransient(PortalRequestsError.clientError("429 - {}", url: "")))
    XCTAssertTrue(YieldXyzRequestFailure.isTransient(PortalRequestsError.internalServerError("503 - {}", url: "")))
    XCTAssertTrue(YieldXyzRequestFailure.isTransient(URLError(.networkConnectionLost)))
    XCTAssertFalse(YieldXyzRequestFailure.isTransient(PortalRequestsError.clientError("404 - {}", url: "")))
    XCTAssertFalse(YieldXyzRequestFailure.isTransient(PortalRequestsError.unauthorized))

    XCTAssertTrue(YieldXyzRequestFailure.isAmbiguous(PortalRequestsError.internalServerError("502 - {}", url: "")))
    XCTAssertTrue(YieldXyzRequestFailure.isAmbiguous(URLError(.timedOut)))
    XCTAssertFalse(YieldXyzRequestFailure.isAmbiguous(PortalRequestsError.clientError("429 - {}", url: "")))
    XCTAssertFalse(YieldXyzRequestFailure.isAmbiguous(PortalRequestsError.unauthorized))
    XCTAssertFalse(YieldXyzRequestFailure.isAmbiguous(PortalCredentialError.sessionInvalidated))
  }

  func test_pollLoop_aZeroTimeoutTicksOnce_unlessTickingPastTheDeadlineIsOff() async throws {
    var ticks = 0
    do {
      _ = try await YieldXyzPollLoop.run(intervalSeconds: 0.001, timeoutSeconds: 0, maxIntervalSeconds: 0.001) { () -> YieldXyzPollStep<Int> in
        ticks += 1
        return .continue
      }
      XCTFail("Expected a timeout")
    } catch is YieldXyzPollLoopTimeout {}
    XCTAssertEqual(ticks, 1)

    ticks = 0
    do {
      _ = try await YieldXyzPollLoop.run(
        intervalSeconds: 0.001,
        timeoutSeconds: 0,
        maxIntervalSeconds: 0.001,
        ticksPastDeadline: false
      ) { () -> YieldXyzPollStep<Int> in
        ticks += 1
        return .continue
      }
      XCTFail("Expected a timeout")
    } catch is YieldXyzPollLoopTimeout {}
    XCTAssertEqual(ticks, 0)
  }

  func test_pollLoop_withoutTickingPastTheDeadline_startsNoTickOnceTheWaitUsesUpTheTimeout() async throws {
    for ticksPastDeadline in [false, true] {
      var ticks = 0
      do {
        // The interval far exceeds the timeout, and the timeout leaves the first tick ample time.
        _ = try await YieldXyzPollLoop.run(
          intervalSeconds: 10,
          timeoutSeconds: 0.3,
          maxIntervalSeconds: 10,
          ticksPastDeadline: ticksPastDeadline
        ) { () -> YieldXyzPollStep<Int> in
          ticks += 1
          return .continue
        }
        XCTFail("Expected a timeout")
      } catch is YieldXyzPollLoopTimeout {}
      // The interval exceeds the timeout, so the loop sleeps until the deadline after the first tick.
      XCTAssertEqual(ticks, ticksPastDeadline ? 2 : 1, "ticksPastDeadline: \(ticksPastDeadline)")
    }
  }

  func test_pollLoop_stopsACancelledTask_evenWhenItsTickReturnsAValue() async {
    let cancelledBefore = Task { () -> (ticks: Int, error: Error?) in
      withUnsafeCurrentTask { $0?.cancel() }
      var ticks = 0
      do {
        _ = try await YieldXyzPollLoop.run(intervalSeconds: 0.001, timeoutSeconds: 1, maxIntervalSeconds: 0.001) { () -> YieldXyzPollStep<Int> in
          ticks += 1
          return .stop(1)
        }
        return (ticks, nil)
      } catch {
        return (ticks, error)
      }
    }
    let before = await cancelledBefore.value
    XCTAssertEqual(before.ticks, 0)
    XCTAssertTrue(before.error is CancellationError, "\(String(describing: before.error))")

    let cancelledDuring = Task { () -> Error? in
      do {
        _ = try await YieldXyzPollLoop.run(intervalSeconds: 0.001, timeoutSeconds: 1, maxIntervalSeconds: 0.001) { () -> YieldXyzPollStep<Int> in
          // A tick that ignores cancellation, such as a cached response.
          withUnsafeCurrentTask { $0?.cancel() }
          return .stop(1)
        }
        return nil
      } catch {
        return error
      }
    }
    let during = await cancelledDuring.value
    XCTAssertTrue(during is CancellationError, "\(String(describing: during))")
  }

  func test_pollLoop_reportsACancelledTaskAsCancelled_notTimedOut() async {
    // Past the deadline before the first tick.
    let pastDeadline = Task { () -> (ticks: Int, error: Error?) in
      withUnsafeCurrentTask { $0?.cancel() }
      var ticks = 0
      do {
        _ = try await YieldXyzPollLoop.run(
          intervalSeconds: 0.001,
          timeoutSeconds: 0,
          maxIntervalSeconds: 0.001,
          ticksPastDeadline: false
        ) { () -> YieldXyzPollStep<Int> in
          ticks += 1
          return .continue
        }
        return (ticks, nil)
      } catch {
        return (ticks, error)
      }
    }
    let before = await pastDeadline.value
    XCTAssertEqual(before.ticks, 0)
    XCTAssertTrue(before.error is CancellationError, "\(String(describing: before.error))")

    // Cancelled during a tick that returns "not done" as the deadline passes.
    let afterTick = Task { () -> Error? in
      do {
        _ = try await YieldXyzPollLoop.run(intervalSeconds: 0.001, timeoutSeconds: 0, maxIntervalSeconds: 0.001) { () -> YieldXyzPollStep<Int> in
          withUnsafeCurrentTask { $0?.cancel() }
          return .continue
        }
        return nil
      } catch {
        return error
      }
    }
    let after = await afterTick.value
    XCTAssertTrue(after is CancellationError, "\(String(describing: after))")
  }

  func test_cancellation_countsACancelledURLSessionRequestOnlyWhileTheTaskIsCancelled() async {
    XCTAssertTrue(YieldXyzCancellation.isCancellation(CancellationError()))
    XCTAssertFalse(YieldXyzCancellation.isCancellation(URLError(.cancelled)))
    let cancelled = Task { () -> Bool in
      withUnsafeCurrentTask { $0?.cancel() }
      return YieldXyzCancellation.isCancellation(URLError(.cancelled))
    }
    let counted = await cancelled.value
    XCTAssertTrue(counted)
  }

  func test_requestFailure_aRequestNeverSentIsNeitherTransientNorAmbiguous() {
    let neverSent: [Error] = [
      YieldXyzPerpsError.emptyIdentifier(name: "actionId"),
      YieldXyzPerpsError.submissionRequired,
      YieldXyzBorrowError.emptyIdentifier(name: "actionId"),
      YieldXyzBorrowError.submissionRequired,
      PortalApiError.unableToEncodeData,
      URLError(.badURL)
    ]
    for error in neverSent {
      XCTAssertTrue(YieldXyzRequestFailure.isRefusedBeforeSending(error), "\(error)")
      XCTAssertFalse(YieldXyzRequestFailure.isTransient(error), "\(error)")
      XCTAssertFalse(YieldXyzRequestFailure.isAmbiguous(error), "\(error)")
    }
    XCTAssertFalse(YieldXyzRequestFailure.isRefusedBeforeSending(URLError(.timedOut)))
    XCTAssertFalse(YieldXyzRequestFailure.isRefusedBeforeSending(PortalApiError.unableToReadStringResponse))
  }
}
