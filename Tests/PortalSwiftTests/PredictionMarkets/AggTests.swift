//
//  AggTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

@testable import PortalSwift
import XCTest

final class AggTests: XCTestCase {
  private static let wallet = "0xAfE8EDC6e7cfcA23B5D3292b9A45504891FB75b9"
  private static let fastPoll = AggPollOptions(interval: 0, timeout: 5)

  private var api: PortalAggApiMock!
  private var progress: ProgressRecorder!

  override func setUpWithError() throws {
    api = PortalAggApiMock()
    progress = ProgressRecorder()
  }

  override func tearDownWithError() throws {
    api = nil
    progress = nil
  }

  // MARK: - Helpers

  private final class ProgressRecorder {
    private let lock = NSLock()
    private var events: [AggProgress] = []

    var steps: [AggHelperStep] {
      lock.lock()
      defer { lock.unlock() }
      return events.map(\.step)
    }

    func record(_ event: AggProgress) {
      lock.lock()
      events.append(event)
      lock.unlock()
    }
  }

  /// Hands out `results` one per call, repeating the last one.
  private final class Results<T> {
    private let lock = NSLock()
    private var results: [Swift.Result<T, Error>]

    init(_ results: [Swift.Result<T, Error>]) {
      self.results = results
    }

    func next() throws -> T {
      lock.lock()
      let result = results.count > 1 ? results.removeFirst() : results[0]
      lock.unlock()
      return try result.get()
    }
  }

  private final class Box<T> {
    var value: T
    init(_ value: T) {
      self.value = value
    }
  }

  private func makeAgg(dependencies: AggDependencies? = nil) -> Agg {
    let agg = Agg(api: api, dependencies: dependencies ?? linkDependencies())
    agg.transientRetryDelay = 0
    return agg
  }

  private func linkDependencies(signatures: Box<[[String]]> = Box([])) -> AggDependencies {
    AggDependencies(
      getAddress: { _ in Self.wallet },
      personalSign: { _, params in
        signatures.value.append(params)
        return "0xsig"
      },
      isChainConfigured: { _ in true }
    )
  }

  private static func decode<T: Decodable>(_ json: String) throws -> T {
    try JSONDecoder().decode(T.self, from: Data(json.utf8))
  }

  /// `json` with `changes` applied to its top-level keys (`NSNull()` for `null`).
  private static func patched(_ json: String, _ changes: [String: Any]) throws -> String {
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    changes.forEach { object[$0.key] = $0.value }
    return try XCTUnwrap(String(data: JSONSerialization.data(withJSONObject: object), encoding: .utf8))
  }

  private static func apiError(_ status: Int, _ body: String = #"{"error":"failed"}"#) -> Error {
    let message = "\(status) - \(body)"
    let underlying: PortalRequestsError = status >= 500
      ? .internalServerError(message, url: "https://api.portalhq.io")
      : .clientError(message, url: "https://api.portalhq.io")
    return AggRequestError(traceId: "trace-\(status)", underlyingError: underlying)
  }

  private static let linkRequired = apiError(409, #"{"error":"This client is not linked to Agg.","id":"AGG_LINK_REQUIRED"}"#)

  private func quote(status: String = "ok", warnings: Any = NSNull()) throws -> AggCreateQuoteResponse {
    try AggResponse(data: Self.decode(Self.patched(AggFixtures.quotePaper, ["quoteId": "q1", "status": status, "warnings": warnings])))
  }

  private func fill() throws -> AggCreateOrderResponse {
    try AggResponse(data: Self.decode(#"{"quoteId":"q1","orderIds":["or1"],"status":"pending"}"#))
  }

  private func execution(_ state: String, terminal: Bool) throws -> AggGetOrderResponse {
    try AggResponse(data: Self.decode(Self.patched(
      AggFixtures.executionStatus,
      ["quoteId": "q1", "overallState": state, "terminal": terminal, "pollAfterMs": NSNull()]
    )))
  }

  private func stubLink(signer: String = AggTests.wallet) throws {
    let challenge: AggLinkChallenge = try Self.decode(#"{"message":"m","signParams":["0x6d","\#(signer.lowercased())"],"expiresAt":"t"}"#)
    let link: AggLink = try Self.decode(
      #"{"linked":true,"aggUserId":"u1","linkedAddress":"\#(signer.lowercased())","linkedChainId":"eip155:137","externalIdLinked":true}"#
    )
    api.createLinkChallengeHandler = { _ in AggResponse(data: challenge) }
    api.createLinkHandler = { _ in AggResponse(data: link) }
  }

  private func stubTrade(states: [(String, Bool)]) throws {
    let quote = try quote()
    let fill = try fill()
    let reads = try Results<AggGetOrderResponse>(states.map { state, terminal in try .success(execution(state, terminal: terminal)) })
    api.createQuoteHandler = { _ in quote }
    api.createOrderHandler = { _ in fill }
    api.getOrderHandler = { _, _ in try reads.next() }
  }

  private func buyParams(amount: String = "1", autoReconnect: Bool = false, poll: AggPollOptions = AggTests.fastPoll) -> AggBuyParams {
    AggBuyParams(outcomeId: "o1", amount: amount, slippageBps: 100, mode: .paper, onProgress: progress.record, autoReconnect: autoReconnect, poll: poll)
  }

  // MARK: - connect

  func test_connect_signsTheChallengeVerbatimAndLinks() async throws {
    try stubLink()
    let signatures = Box<[[String]]>([])
    var linkSignature: String?
    let createLink = api.createLinkHandler
    api.createLinkHandler = { request in
      linkSignature = request.signature
      return try await XCTUnwrap(createLink)(request)
    }

    let link = try await makeAgg(dependencies: linkDependencies(signatures: signatures)).connect()

    XCTAssertTrue(link.linked)
    XCTAssertEqual(signatures.value, [["0x6d", Self.wallet.lowercased()]])
    XCTAssertEqual(linkSignature, "0xsig")
  }

  func test_connect_refusesAChainWithoutAnRpcUrl_beforeAnyRequest() async {
    let agg = makeAgg(dependencies: AggDependencies(getAddress: { _ in Self.wallet }, personalSign: { _, _ in "0xsig" }, isChainConfigured: { _ in false }))

    do {
      _ = try await agg.connect(chainId: "eip155:1")
      XCTFail("Expected missingRpcUrl")
    } catch AggError.missingRpcUrl(let chainId) {
      XCTAssertEqual(chainId, "eip155:1")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
    XCTAssertTrue(api.calls.isEmpty)
  }

  func test_connect_refusesAChallengeForAnotherAddress_withoutSigning() async throws {
    try stubLink(signer: "0x0000000000000000000000000000000000000001")
    let signatures = Box<[[String]]>([])

    do {
      _ = try await makeAgg(dependencies: linkDependencies(signatures: signatures)).connect()
      XCTFail("Expected addressMismatch")
    } catch AggError.addressMismatch(let expected, let actual) {
      XCTAssertEqual(expected, Self.wallet)
      XCTAssertEqual(actual, "0x0000000000000000000000000000000000000001")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
    XCTAssertTrue(signatures.value.isEmpty)
    XCTAssertEqual(api.callCount("createLink"), 0)
  }

  func test_connect_withoutAWalletAddress_failsWithNoAddress() async {
    let agg = makeAgg(dependencies: AggDependencies(getAddress: { _ in nil }, personalSign: { _, _ in "0xsig" }))

    do {
      _ = try await agg.connect()
      XCTFail("Expected noAddress")
    } catch AggError.noAddress {
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func test_isConnected_readsTheLinkStatus() async throws {
    api.getLinkHandler = { AggGetLinkResponse(data: .notLinked) }
    let notConnected = try await makeAgg().isConnected()
    XCTAssertFalse(notConnected)

    api.getLinkHandler = { AggGetLinkResponse(data: .linked(.init(aggUserId: "u1", linkedAddress: "0xabc", linkedChainId: "eip155:137", linkedAt: "t"))) }
    let connected = try await makeAgg().isConnected()
    XCTAssertTrue(connected)
  }

  // MARK: - buy and sell

  func test_buy_quotesFillsAndWaitsForTheFill() async throws {
    try stubTrade(states: [("placing", false), ("filled", true)])
    var quoteRequest: AggQuoteRequest?
    let quote = try quote()
    api.createQuoteHandler = { request in
      quoteRequest = request
      return quote
    }

    let result = try await makeAgg().buy(params: buyParams())

    XCTAssertEqual(result.status.overallState, .filled)
    XCTAssertEqual(result.quote.quoteId, "q1")
    XCTAssertEqual(quoteRequest, AggQuoteRequest(outcomeId: "o1", side: .buy, amount: "1", slippageBps: 100, mode: .paper))
    XCTAssertEqual(api.calls, ["createQuote", "createOrder", "getOrder", "getOrder"])
    XCTAssertEqual(progress.steps, [.quoting, .filling, .pollingOrder, .pollingOrder, .pollingOrder])
  }

  func test_buy_aPartialFillSucceeds() async throws {
    try stubTrade(states: [("partially_filled", true)])

    let result = try await makeAgg().buy(params: buyParams())

    XCTAssertEqual(result.status.overallState, .partiallyFilled)
  }

  func test_buy_anExpiredFill_failsWithOrderFailed() async throws {
    try stubTrade(states: [("expired", true)])

    do {
      _ = try await makeAgg().buy(params: buyParams())
      XCTFail("Expected orderFailed")
    } catch AggError.orderFailed(let status) {
      XCTAssertEqual(status.overallState, .expired)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func test_buy_aFinalStateThisSdkDoesNotKnow_failsWithOrderFailed() async throws {
    try stubTrade(states: [("rejected", true)])

    do {
      _ = try await makeAgg().buy(params: buyParams())
      XCTFail("Expected orderFailed")
    } catch AggError.orderFailed(let status) {
      XCTAssertEqual(status.overallState.rawValue, "rejected")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func test_buy_aFailedOrCancelledFill_failsWithOrderFailed() async throws {
    for state in ["failed", "cancelled"] {
      api = PortalAggApiMock()
      try stubTrade(states: [(state, true)])

      do {
        _ = try await makeAgg().buy(params: buyParams())
        XCTFail("Expected orderFailed for \(state)")
      } catch AggError.orderFailed(let status) {
        XCTAssertEqual(status.overallState.rawValue, state)
      } catch {
        XCTFail("Unexpected error for \(state): \(error)")
      }
    }
  }

  func test_buy_aQuoteWithWarnings_isNotFilled() async throws {
    let blocked = try quote(warnings: [["venue": "polymarket", "venueMarketOutcomeId": "o1", "reason": "Venue not available in your region (US)"]])
    api.createQuoteHandler = { _ in blocked }

    do {
      _ = try await makeAgg().buy(params: buyParams())
      XCTFail("Expected quoteNotTradable")
    } catch AggError.quoteNotTradable(let quote) {
      XCTAssertEqual(quote.warnings?.first?.reason, "Venue not available in your region (US)")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
    XCTAssertEqual(api.calls, ["createQuote"])
  }

  func test_buy_aQuoteThatIsNotOk_isNotFilled() async throws {
    let quote = try quote(status: "min_order_size_violated")
    api.createQuoteHandler = { _ in quote }

    do {
      _ = try await makeAgg().buy(params: buyParams())
      XCTFail("Expected quoteNotTradable")
    } catch AggError.quoteNotTradable(let quote) {
      XCTAssertEqual(quote.status, .minOrderSizeViolated)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
    XCTAssertEqual(api.callCount("createOrder"), 0)
  }

  func test_buy_aFillWhoseResponseWasLost_failsWithOutcomeUnknown() async throws {
    try stubTrade(states: [("filled", true)])
    api.createOrderHandler = { _ in throw Self.apiError(500) }

    do {
      _ = try await makeAgg().buy(params: buyParams())
      XCTFail("Expected orderOutcomeUnknown")
    } catch AggError.orderOutcomeUnknown(let quote, let fill, let last, let underlyingError) {
      XCTAssertEqual(quote.quoteId, "q1")
      XCTAssertNil(fill)
      XCTAssertNil(last)
      XCTAssertEqual(AggApiError.from(underlyingError)?.status, 500)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func test_buy_aRejectedFill_failsWithTheApiError() async throws {
    try stubTrade(states: [("filled", true)])
    api.createOrderHandler = { _ in throw Self.apiError(422, #"{"error":"Agg rejected the request: quote expired"}"#) }

    do {
      _ = try await makeAgg().buy(params: buyParams())
      XCTFail("Expected the API error")
    } catch {
      XCTAssertEqual(AggApiError.from(error)?.status, 422)
    }
  }

  func test_buy_aReadFailureAfterTheFill_failsWithOutcomeUnknownAndTheLastRead() async throws {
    let placing = try execution("placing", terminal: false)
    try stubTrade(states: [])
    let reads = Results<AggGetOrderResponse>([.success(placing), .failure(Self.apiError(400))])
    api.getOrderHandler = { _, _ in try reads.next() }

    do {
      _ = try await makeAgg().buy(params: buyParams())
      XCTFail("Expected orderOutcomeUnknown")
    } catch AggError.orderOutcomeUnknown(let quote, let fill, let last, let underlyingError) {
      XCTAssertEqual(quote.quoteId, "q1")
      XCTAssertEqual(fill?.orderIds, ["or1"])
      XCTAssertEqual(last?.overallState, .placing)
      XCTAssertEqual(AggApiError.from(underlyingError)?.status, 400)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
    XCTAssertEqual(api.callCount("createQuote"), 1)
    XCTAssertEqual(api.callCount("createOrder"), 1)
  }

  func test_buy_aTimeout_failsWithOutcomeUnknownWrappingTheOrderTimeout() async throws {
    try stubTrade(states: [("confirming", false)])

    do {
      _ = try await makeAgg().buy(params: buyParams(poll: AggPollOptions(interval: 0.01, timeout: 0.05)))
      XCTFail("Expected orderOutcomeUnknown")
    } catch AggError.orderOutcomeUnknown(_, _, let last, let underlyingError) {
      XCTAssertEqual(last?.overallState, .confirming)
      guard case let AggError.orderTimeout(quoteId, timeoutLast)? = underlyingError as? AggError else {
        return XCTFail("Expected orderTimeout, got \(underlyingError)")
      }
      XCTAssertEqual(quoteId, "q1")
      XCTAssertEqual(timeoutLast?.overallState, .confirming)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func test_buy_readsThroughTransientFailures() async throws {
    let filled = try execution("filled", terminal: true)
    try stubTrade(states: [])
    let reads = Results<AggGetOrderResponse>([.failure(Self.apiError(429)), .failure(Self.apiError(503)), .success(filled)])
    api.getOrderHandler = { _, _ in try reads.next() }

    let result = try await makeAgg().buy(params: buyParams())

    XCTAssertEqual(result.status.overallState, .filled)
    XCTAssertEqual(api.callCount("getOrder"), 3)
  }

  func test_buy_anInvalidAmount_isRefusedBeforeAnyRequest() async {
    for amount in ["0", "-1", "abc", "1.2.3", ""] {
      do {
        _ = try await makeAgg().buy(params: buyParams(amount: amount))
        XCTFail("Expected invalidAmount for \"\(amount)\"")
      } catch AggError.invalidAmount(let name, let value) {
        XCTAssertEqual(name, "amount")
        XCTAssertEqual(value, amount)
      } catch {
        XCTFail("Unexpected error for \"\(amount)\": \(error)")
      }
    }
    XCTAssertTrue(api.calls.isEmpty)
  }

  func test_sell_quotesTheShares() async throws {
    try stubTrade(states: [("filled", true)])
    var quoteRequest: AggQuoteRequest?
    let quote = try quote()
    api.createQuoteHandler = { request in
      quoteRequest = request
      return quote
    }

    _ = try await makeAgg().sell(params: AggSellParams(outcomeId: "o1", shares: "2.5", poll: Self.fastPoll))

    XCTAssertEqual(quoteRequest, AggQuoteRequest(outcomeId: "o1", side: .sell, shares: "2.5"))
  }

  func test_buy_withAutoReconnect_reconnectsOnceAndRetries() async throws {
    try stubTrade(states: [("filled", true)])
    try stubLink()
    let quote = try quote()
    let quotes = Results<AggCreateQuoteResponse>([.failure(Self.linkRequired), .success(quote)])
    api.createQuoteHandler = { _ in try quotes.next() }

    _ = try await makeAgg().buy(params: buyParams(autoReconnect: true))

    XCTAssertEqual(api.calls, ["createQuote", "createLinkChallenge", "createLink", "createQuote", "createOrder", "getOrder"])
    XCTAssertEqual(progress.steps.first(where: { $0 == .reconnecting }), .reconnecting)
  }

  func test_buy_withoutAutoReconnect_returnsLinkRequired() async throws {
    api.createQuoteHandler = { _ in throw Self.linkRequired }

    do {
      _ = try await makeAgg().buy(params: buyParams())
      XCTFail("Expected AGG_LINK_REQUIRED")
    } catch {
      XCTAssertEqual(AggApiError.from(error)?.isLinkRequired, true)
    }
    XCTAssertEqual(api.calls, ["createQuote"])
  }

  // MARK: - placeLimitOrder

  func test_placeLimitOrder_scalesThePriceAndSharesBy1e6() async throws {
    var sent: AggLimitOrderRequest?
    let order: AggLimitOrder = try Self.decode(AggFixtures.limitOrderPlaced)
    api.createLimitOrderHandler = { request in
      sent = request
      return AggResponse(data: order)
    }

    _ = try await makeAgg().placeLimitOrder(params: AggPlaceLimitOrderParams(
      venue: .polymarket, venueMarketOutcomeId: "o1", side: .buy, price: "0.2", shares: "5.0000000"
    ))

    XCTAssertEqual(sent?.limitPriceRaw, "200000")
    XCTAssertEqual(sent?.sizeRaw, "5000000")
    XCTAssertEqual(sent?.timeInForce, .gtc)
  }

  func test_placeLimitOrder_refusesAPriceOutsideZeroToOneOrWithMoreThanSixDecimals() async {
    let cases: [(price: String, shares: String, field: String)] = [
      ("1", "5", "price"),
      ("1.5", "5", "price"),
      ("0", "5", "price"),
      ("0.2000001", "5", "price"),
      ("0.2", "5.0000001", "shares"),
      ("0.2", "0", "shares")
    ]
    for testCase in cases {
      do {
        _ = try await makeAgg().placeLimitOrder(params: AggPlaceLimitOrderParams(
          venue: .polymarket, venueMarketOutcomeId: "o1", side: .buy, price: testCase.price, shares: testCase.shares
        ))
        XCTFail("Expected invalidAmount for \(testCase)")
      } catch AggError.invalidAmount(let name, _) {
        XCTAssertEqual(name, testCase.field, "\(testCase)")
      } catch {
        XCTFail("Unexpected error for \(testCase): \(error)")
      }
    }
    XCTAssertTrue(api.calls.isEmpty)
  }

  func test_toRaw_roundsDownOnlyWhenNotExact() throws {
    XCTAssertEqual(try Agg.toRaw("amount", "1.1234567", decimals: 6, exact: false), "1123456")
    XCTAssertEqual(try Agg.toRaw("amount", ".5", decimals: 6, exact: true), "500000")
    XCTAssertEqual(try Agg.toRaw("amount", "10", decimals: 18, exact: true), "10000000000000000000")
    XCTAssertThrowsError(try Agg.toRaw("amount", "0.0000001", decimals: 6, exact: false))
    XCTAssertThrowsError(try Agg.toRaw("amount", "1e6", decimals: 6, exact: false))
  }

  // MARK: - redeemAll

  private func position(redeemStatus: String, outcomes: [(winner: Bool?, ids: [String])]) -> String {
    let outcomeJson = outcomes.map { outcome -> String in
      let legs = outcome.ids.map { #"{"venue":"polymarket","venueMarketId":"m1","venueMarketOutcomeId":"\#($0)","size":1}"# }
      let winner = outcome.winner.map { $0 ? "true" : "false" } ?? "null"
      return #"{"label":"Yes","venueBreakdown":[\#(legs.joined(separator: ","))],"totalSize":1,"avgEntryPrice":0.5,"currentPrice":1,"realizedPnl":0,"totalValue":1,"unrealizedPnl":0.5,"unrealizedPnlPercent":100,"priceSource":"resolution","winner":\#(winner)}"#
    }
    return #"{"targetMarketId":"t1","redeemStatus":"\#(redeemStatus)","status":"closed","venueMarket":{"venueEventId":"e1","question":"q","status":"resolved","venueMarketOutcomes":[\#(outcomeJson.joined(separator: ","))]}}"#
  }

  func test_redeemAll_redeemsEveryEligibleWinningHoldingInBatchesOf20() async throws {
    let manyIds = (1 ... 22).map { "v\($0)" }
    let firstPage: AggListPositionsResponse = try AggResponse(data: Self.decode(#"""
    {"data":[\#(position(redeemStatus: "eligible", outcomes: [(true, Array(manyIds.prefix(12))), (false, ["lost"])])),\#(position(redeemStatus: "ineligible", outcomes: [(nil, ["open"])]))],"nextCursor":"p2","hasMore":true}
    """#))
    let secondPage: AggListPositionsResponse = try AggResponse(data: Self.decode(#"""
    {"data":[\#(position(redeemStatus: "eligible", outcomes: [(nil, Array(manyIds.suffix(10)) + ["v1"])]))],"nextCursor":null,"hasMore":false}
    """#))
    var cursors: [String?] = []
    api.listPositionsHandler = { params in
      cursors.append(params.cursor)
      return params.cursor == nil ? firstPage : secondPage
    }
    var batches: [[String]] = []
    let redeemed: AggRedeemResult = try Self.decode(AggFixtures.redeem)
    api.redeemPositionsHandler = { request in
      batches.append(request.venueMarketOutcomeIds)
      return AggResponse(data: redeemed)
    }

    let results = try await makeAgg().redeemAll()

    XCTAssertEqual(cursors, [nil, "p2"])
    XCTAssertEqual(batches, [Array(manyIds.prefix(20)), Array(manyIds.suffix(2))])
    XCTAssertEqual(results.count, 2)
  }

  func test_redeemAll_withNothingEligible_redeemsNothing() async throws {
    let page: AggListPositionsResponse = try AggResponse(data: Self.decode(
      #"{"data":[\#(position(redeemStatus: "ineligible", outcomes: [(nil, ["v1"])]))],"nextCursor":null,"hasMore":false}"#
    ))
    api.listPositionsHandler = { _ in page }

    let results = try await makeAgg().redeemAll()

    XCTAssertTrue(results.isEmpty)
    XCTAssertEqual(api.callCount("redeemPositions"), 0)
  }

  // MARK: - withdraw

  private func stubWithdrawal(created: String = "pending", reads: [Swift.Result<String, Error>] = [.success("completed")], pricingStatus: String = "quoted") throws {
    let withdrawable: AggWithdrawableQuote = try Self.decode(Self.patched(AggFixtures.withdrawableQuote, ["decimals": 6]))
    let preview: AggWithdrawalPreview = try Self.decode(Self.patched(AggFixtures.withdrawalPreview, ["pricingStatus": pricingStatus]))
    let createdWithdrawal: AggWithdrawal = try Self.decode(Self.patched(AggFixtures.withdrawalSubmit, ["withdrawalId": "w1", "status": created]))
    let statuses = try Results<AggWithdrawalResponse>(reads.map { result -> Swift.Result<AggWithdrawalResponse, Error> in
      switch result {
      case let .success(status):
        return try .success(AggResponse(data: Self.decode(Self.patched(AggFixtures.withdrawalStatus, ["withdrawalId": "w1", "status": status]))))
      case let .failure(error):
        return .failure(error)
      }
    })
    api.quoteWithdrawableHandler = { _ in AggResponse(data: withdrawable) }
    api.previewWithdrawalHandler = { _ in AggResponse(data: preview) }
    api.createWithdrawalHandler = { _ in AggResponse(data: createdWithdrawal) }
    api.getWithdrawalHandler = { _ in try statuses.next() }
  }

  private func withdrawParams(amount: String = "1.5", poll: AggPollOptions = AggTests.fastPoll) -> AggWithdrawParams {
    AggWithdrawParams(amount: amount, tokenSymbol: .usdc, destinationChainId: "eip155:8453", requestId: "r1", onProgress: progress.record, poll: poll)
  }

  func test_withdraw_previewsWithoutTheRequestIdThenSendsItAndWaits() async throws {
    try stubWithdrawal()
    var previewed: AggWithdrawalRequest?
    var created: AggWithdrawalRequest?
    let preview = api.previewWithdrawalHandler
    let create = api.createWithdrawalHandler
    api.previewWithdrawalHandler = { request in
      previewed = request
      return try await XCTUnwrap(preview)(request)
    }
    api.createWithdrawalHandler = { request in
      created = request
      return try await XCTUnwrap(create)(request)
    }

    let withdrawal = try await makeAgg().withdraw(params: withdrawParams())

    XCTAssertEqual(withdrawal.status, .completed)
    XCTAssertEqual(previewed, AggWithdrawalRequest(tokenSymbol: .usdc, destinationChainId: "eip155:8453", amountRaw: "1500000"))
    XCTAssertEqual(created, AggWithdrawalRequest(tokenSymbol: .usdc, destinationChainId: "eip155:8453", amountRaw: "1500000", requestId: "r1"))
    XCTAssertEqual(api.calls, ["quoteWithdrawable", "previewWithdrawal", "createWithdrawal", "getWithdrawal"])
    XCTAssertEqual(progress.steps, [.previewingWithdrawal, .withdrawing, .pollingWithdrawal, .pollingWithdrawal])
  }

  func test_withdraw_anUnviablePreview_sendsNothing() async throws {
    try stubWithdrawal(pricingStatus: "unviable")

    do {
      _ = try await makeAgg().withdraw(params: withdrawParams())
      XCTFail("Expected withdrawalNotViable")
    } catch AggError.withdrawalNotViable(let preview) {
      XCTAssertEqual(preview.pricingStatus, .unviable)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
    XCTAssertEqual(api.callCount("createWithdrawal"), 0)
  }

  func test_withdraw_aFailedWithdrawal_failsWithWithdrawalFailed() async throws {
    try stubWithdrawal(reads: [.success("failed")])

    do {
      _ = try await makeAgg().withdraw(params: withdrawParams())
      XCTFail("Expected withdrawalFailed")
    } catch AggError.withdrawalFailed(let withdrawal) {
      XCTAssertEqual(withdrawal.status, .failed)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func test_withdraw_retriesATransientCreateWithTheSameRequestId() async throws {
    try stubWithdrawal()
    let created: AggWithdrawal = try Self.decode(Self.patched(AggFixtures.withdrawalSubmit, ["withdrawalId": "w1", "status": "pending"]))
    let attempts = Results<AggWithdrawalResponse>([.failure(Self.apiError(503)), .success(AggResponse(data: created))])
    var requestIds: [String?] = []
    api.createWithdrawalHandler = { request in
      requestIds.append(request.requestId)
      return try attempts.next()
    }

    _ = try await makeAgg().withdraw(params: withdrawParams())

    XCTAssertEqual(requestIds, ["r1", "r1"])
  }

  func test_withdraw_aCreateWhoseResponseWasLost_failsWithOutcomeUnknownCarryingTheRequest() async throws {
    try stubWithdrawal()
    api.createWithdrawalHandler = { _ in throw Self.apiError(500) }

    do {
      _ = try await makeAgg().withdraw(params: withdrawParams())
      XCTFail("Expected withdrawalOutcomeUnknown")
    } catch AggError.withdrawalOutcomeUnknown(let request, let withdrawal, _, _) {
      XCTAssertEqual(request.requestId, "r1")
      XCTAssertNil(withdrawal)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
    XCTAssertEqual(api.callCount("createWithdrawal"), 1)
  }

  func test_withdraw_aReadFailureAfterCreating_failsWithOutcomeUnknownCarryingTheWithdrawal() async throws {
    try stubWithdrawal(reads: [.success("transferring"), .failure(Self.apiError(404))])

    do {
      _ = try await makeAgg().withdraw(params: withdrawParams())
      XCTFail("Expected withdrawalOutcomeUnknown")
    } catch AggError.withdrawalOutcomeUnknown(_, let withdrawal, let last, let underlyingError) {
      XCTAssertEqual(withdrawal?.withdrawalId, "w1")
      XCTAssertEqual(last?.status, .transferring)
      XCTAssertEqual(AggApiError.from(underlyingError)?.status, 404)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func test_withdraw_roundsTheAmountDownToTheTokenDecimals() async throws {
    try stubWithdrawal()
    var amountRaw: String?
    let preview = api.previewWithdrawalHandler
    api.previewWithdrawalHandler = { request in
      amountRaw = request.amountRaw
      return try await XCTUnwrap(preview)(request)
    }

    _ = try await makeAgg().withdraw(params: withdrawParams(amount: "1.1234567"))

    XCTAssertEqual(amountRaw, "1123456")
  }

  // MARK: - deposit

  private static let depositAddresses = #"""
  {"ready":true,"evmAddress":"0xDeposit","svmAddress":"SoLDeposit","supportedChains":[
    {"chainId":"eip155:8453","name":"Base","tokens":[{"symbol":"USDC","address":"0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913","decimals":6}]},
    {"chainId":"solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp","name":"Solana","tokens":[{"symbol":"USDC","address":"EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v","decimals":6}]}]}
  """#

  func test_deposit_waitsForTheAddressesThenSendsWithTheIdempotencyKey() async throws {
    let ready: AggDepositAddresses = try Self.decode(Self.depositAddresses)
    let reads = Results<AggGetDepositAddressesResponse>([.success(AggGetDepositAddressesResponse(data: .notReady)), .success(AggResponse(data: ready))])
    api.getDepositAddressesHandler = { try reads.next() }
    var sent: (String, SendAssetParams)?
    let agg = makeAgg(dependencies: AggDependencies(sendAsset: { chainId, params in
      sent = (chainId, params)
      return "0xtx"
    }))

    let result = try await agg.deposit(params: AggDepositParams(
      chainId: "eip155:8453", token: "usdc", amount: "1", idempotencyKey: "k1", onProgress: progress.record, addressPoll: Self.fastPoll
    ))

    XCTAssertEqual(result.txHash, "0xtx")
    XCTAssertEqual(result.depositAddress, "0xDeposit")
    XCTAssertEqual(sent?.0, "eip155:8453")
    XCTAssertEqual(sent?.1.to, "0xDeposit")
    XCTAssertEqual(sent?.1.token, "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913")
    XCTAssertEqual(sent?.1.amount, "1")
    XCTAssertEqual(sent?.1.idempotencyKey, "k1")
    XCTAssertEqual(api.callCount("getDepositAddresses"), 2)
    XCTAssertEqual(progress.steps, [.awaitingDepositAddresses, .sendingDeposit, .depositSent])
  }

  func test_deposit_onSolana_sendsToTheSvmAddress() async throws {
    let ready: AggDepositAddresses = try Self.decode(Self.depositAddresses)
    api.getDepositAddressesHandler = { AggResponse(data: ready) }
    var to: String?
    let agg = makeAgg(dependencies: AggDependencies(sendAsset: { _, params in
      to = params.to
      return "sig"
    }))

    _ = try await agg.deposit(params: AggDepositParams(chainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp", token: "USDC", amount: "1", addressPoll: Self.fastPoll))

    XCTAssertEqual(to, "SoLDeposit")
  }

  func test_deposit_aTokenAggDoesNotTake_sendsNothing() async throws {
    let ready: AggDepositAddresses = try Self.decode(Self.depositAddresses)
    api.getDepositAddressesHandler = { AggResponse(data: ready) }
    var sends = 0
    let agg = makeAgg(dependencies: AggDependencies(sendAsset: { _, _ in
      sends += 1
      return "0xtx"
    }))

    do {
      _ = try await agg.deposit(params: AggDepositParams(chainId: "eip155:8453", token: "USDT", amount: "1", addressPoll: Self.fastPoll))
      XCTFail("Expected unsupportedDepositToken")
    } catch AggError.unsupportedDepositToken(let chainId, let token) {
      XCTAssertEqual(chainId, "eip155:8453")
      XCTAssertEqual(token, "USDT")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
    XCTAssertEqual(sends, 0)
  }

  func test_deposit_addressesThatNeverGetReady_timeOut() async throws {
    api.getDepositAddressesHandler = { AggGetDepositAddressesResponse(data: .notReady) }
    let agg = makeAgg(dependencies: AggDependencies(sendAsset: { _, _ in "0xtx" }))

    do {
      _ = try await agg.deposit(params: AggDepositParams(chainId: "eip155:8453", token: "USDC", amount: "1", addressPoll: AggPollOptions(interval: 0.01, timeout: 0.05)))
      XCTFail("Expected depositAddressesTimeout")
    } catch AggError.depositAddressesTimeout(let last) {
      XCTAssertEqual(last, .notReady)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  // MARK: - Wiring

  func test_predictionMarkets_routesAggThroughTheApisAgg() async throws {
    api.getLinkHandler = { AggGetLinkResponse(data: .notLinked) }
    let predictionMarkets = PredictionMarkets(api: PortalApiMock(agg: api))

    _ = try await predictionMarkets.agg.getLink()

    XCTAssertEqual(api.calls, ["getLink"])
  }
}
