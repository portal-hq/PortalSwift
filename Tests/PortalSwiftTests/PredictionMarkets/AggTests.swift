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

    var idempotencyKeys: [String?] {
      lock.lock()
      defer { lock.unlock() }
      return events.map(\.idempotencyKey)
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

  /// A value two tasks read and write at once.
  private final class Locked<T> {
    private let lock = NSLock()
    private var stored: T

    init(_ value: T) {
      self.stored = value
    }

    var value: T {
      get {
        lock.lock()
        defer { lock.unlock() }
        return stored
      }
      set {
        lock.lock()
        stored = newValue
        lock.unlock()
      }
    }
  }

  private func makeAgg(dependencies: AggDependencies? = nil) -> Agg {
    Agg(api: api, dependencies: dependencies ?? linkDependencies(), transientRetryDelay: 0)
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

  private func quote(status: String = "ok", warnings: Any = NSNull(), error: Any = NSNull()) throws -> AggCreateQuoteResponse {
    try AggResponse(data: Self.decode(Self.patched(AggFixtures.quotePaper, ["quoteId": "q1", "status": status, "warnings": warnings, "error": error])))
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

  /// Agg can attach an `error` to a quote whose `status` is `ok` and that carries no warning (seen
  /// live: an unfunded venue balance). Paper mode fills such a quote; the helpers refuse it.
  func test_buy_aQuoteWithAnErrorButStatusOk_isNotFilled() async throws {
    let message = "Insufficient Kalshi venue balance for this order. Fund the venue account and re-quote."
    let quote = try quote(error: message)
    api.createQuoteHandler = { _ in quote }

    do {
      _ = try await makeAgg().buy(params: buyParams())
      XCTFail("Expected quoteNotTradable")
    } catch AggError.quoteNotTradable(let quote) {
      XCTAssertEqual(quote.status, .ok)
      XCTAssertNil(quote.warnings)
      XCTAssertEqual(quote.error, message)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
    XCTAssertEqual(api.calls, ["createQuote"])
  }

  func test_sell_aQuoteWithAnErrorButStatusOk_isNotFilled() async throws {
    let quote = try quote(error: "Insufficient position")
    api.createQuoteHandler = { _ in quote }

    do {
      _ = try await makeAgg().sell(params: AggSellParams(outcomeId: "o1", shares: "2", poll: Self.fastPoll))
      XCTFail("Expected quoteNotTradable")
    } catch AggError.quoteNotTradable(let quote) {
      XCTAssertEqual(quote.error, "Insufficient position")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
    XCTAssertEqual(api.calls, ["createQuote"])
  }

  /// An empty `error` says nothing, so it does not block an otherwise tradable quote.
  func test_buy_aQuoteWithAnEmptyError_isFilled() async throws {
    try stubTrade(states: [("filled", true)])
    let quote = try quote(error: "")
    api.createQuoteHandler = { _ in quote }

    let result = try await makeAgg().buy(params: buyParams())

    XCTAssertEqual(result.status.overallState, .filled)
    XCTAssertEqual(api.callCount("createOrder"), 1)
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
    XCTAssertEqual(api.callCount("createOrder"), 1)
    XCTAssertEqual(api.callCount("getOrder"), 0)
  }

  /// A refusal is not repeated and not an unknown outcome: Agg declined the fill, so nothing traded.
  func test_buy_aRejectedFill_failsWithTheApiError() async throws {
    try stubTrade(states: [("filled", true)])
    api.createOrderHandler = { _ in throw Self.apiError(422, #"{"error":"Agg rejected the request: quote expired"}"#) }

    do {
      _ = try await makeAgg().buy(params: buyParams())
      XCTFail("Expected the API error")
    } catch {
      XCTAssertEqual(AggApiError.from(error)?.status, 422)
    }
    XCTAssertEqual(api.callCount("createOrder"), 1)
    XCTAssertEqual(api.callCount("getOrder"), 0)
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

  /// The regression this guards: the fill used to be repeated after a gateway error. In paper mode a
  /// first attempt filled, its answer was lost, the repeat of the same quote was refused with a 400
  /// (`quote_not_found`, "Quote has expired"), and that refusal reached the caller as a plain error
  /// that hid the trade. The fill is sent once, and a lost answer is an unknown outcome: the second
  /// response stubbed here must never be requested.
  func test_buy_aFillWhoseAnswerWasLost_isNotSentAgainAndIsOutcomeUnknown() async throws {
    try stubTrade(states: [("filled", true)])
    let replayRefused = Self.apiError(400, #"{"error":"Agg rejected the request: Quote has expired","details":{"code":"quote_not_found"}}"#)
    let attempts = Results<AggCreateOrderResponse>([.failure(Self.apiError(503)), .failure(replayRefused)])
    var quoteIds: [String] = []
    api.createOrderHandler = { request in
      quoteIds.append(request.quoteId)
      return try attempts.next()
    }

    do {
      _ = try await makeAgg().buy(params: buyParams())
      XCTFail("Expected orderOutcomeUnknown")
    } catch AggError.orderOutcomeUnknown(let quote, let fill, let last, let underlyingError) {
      XCTAssertEqual(quote.quoteId, "q1")
      XCTAssertNil(fill)
      XCTAssertNil(last)
      XCTAssertEqual(AggApiError.from(underlyingError)?.status, 503)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
    XCTAssertEqual(quoteIds, ["q1"])
    XCTAssertEqual(api.callCount("getOrder"), 0)
  }

  /// Every failure after which the fill may have reached Agg (a 5xx, a network error, an answer that
  /// did not decode) ends the trade after one attempt, as an unknown outcome carrying that failure.
  func test_buy_everyAmbiguousFillFailure_isOutcomeUnknownAfterOneAttempt() async throws {
    let decodingError = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unexpected shape"))
    let failures: [(String, AggRequestError)] = [
      ("500", Self.apiError(500) as! AggRequestError),
      ("502", Self.apiError(502) as! AggRequestError),
      ("503", Self.apiError(503) as! AggRequestError),
      ("504", Self.apiError(504) as! AggRequestError),
      ("timed out", AggRequestError(traceId: "t-timeout", underlyingError: URLError(.timedOut))),
      ("connection lost", AggRequestError(traceId: "t-lost", underlyingError: URLError(.networkConnectionLost))),
      ("no connection", AggRequestError(traceId: "t-offline", underlyingError: URLError(.notConnectedToInternet))),
      ("did not decode", AggRequestError(traceId: "t-decode", underlyingError: decodingError))
    ]
    for (name, failure) in failures {
      api = PortalAggApiMock()
      try stubTrade(states: [("filled", true)])
      api.createOrderHandler = { _ in throw failure }

      do {
        _ = try await makeAgg().buy(params: buyParams())
        XCTFail("Expected orderOutcomeUnknown for \(name)")
      } catch AggError.orderOutcomeUnknown(let quote, let fill, let last, let underlyingError) {
        XCTAssertEqual(quote.quoteId, "q1", name)
        XCTAssertNil(fill, name)
        XCTAssertNil(last, name)
        XCTAssertEqual((underlyingError as? AggRequestError)?.traceId, failure.traceId, name)
      } catch {
        XCTFail("Unexpected error for \(name): \(error)")
      }
      XCTAssertEqual(api.callCount("createOrder"), 1, name)
      XCTAssertEqual(api.callCount("getOrder"), 0, name)
    }
  }

  /// A rate limit refused the fill before Agg acted on it, so it is not an unknown outcome; like
  /// every fill failure it is not repeated either. The caller quotes again.
  func test_buy_aRateLimitedFill_isThrownAsIsAfterOneAttempt() async throws {
    try stubTrade(states: [("filled", true)])
    api.createOrderHandler = { _ in throw Self.apiError(429, #"{"error":"Too many requests"}"#) }

    do {
      _ = try await makeAgg().buy(params: buyParams())
      XCTFail("Expected the API error")
    } catch let error as AggRequestError {
      XCTAssertEqual(AggApiError.from(error)?.status, 429)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
    XCTAssertEqual(api.callCount("createOrder"), 1)
    XCTAssertEqual(api.callCount("getOrder"), 0)
  }

  /// A fill refused for the link did nothing, so a reconnect that fails afterwards is not an
  /// unknown outcome.
  func test_buy_aFailedReconnectAfterTheFillWasRefused_isNotOutcomeUnknown() async throws {
    try stubTrade(states: [("filled", true)])
    try stubLink()
    api.createOrderHandler = { _ in throw Self.linkRequired }
    let declined = NSError(domain: "AggTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Signature declined"])
    let agg = makeAgg(dependencies: AggDependencies(
      getAddress: { _ in Self.wallet },
      personalSign: { _, _ in throw declined },
      isChainConfigured: { _ in true }
    ))

    do {
      _ = try await agg.buy(params: buyParams(autoReconnect: true))
      XCTFail("Expected reconnectFailed")
    } catch AggError.reconnectFailed(let underlyingError as NSError) {
      XCTAssertEqual(underlyingError.domain, "AggTests")
      XCTAssertEqual(underlyingError.code, 1)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
    XCTAssertEqual(api.calls, ["createQuote", "createOrder", "createLinkChallenge"])
  }

  /// A reconnect that fails with a gateway error after the fill was refused for the link: the fill
  /// did nothing, so the buy is neither an unknown outcome nor retried (which would ask the user to
  /// sign again).
  func test_buy_aFillRefusedForTheLinkWhoseReconnectFailsTransiently_signsOnceAndIsReconnectFailed() async throws {
    try stubTrade(states: [("filled", true)])
    try stubLink()
    api.createOrderHandler = { _ in throw Self.linkRequired }
    api.createLinkHandler = { _ in throw Self.apiError(502) }
    let signatures = Box<[[String]]>([])

    do {
      _ = try await makeAgg(dependencies: linkDependencies(signatures: signatures)).buy(params: buyParams(autoReconnect: true))
      XCTFail("Expected reconnectFailed")
    } catch AggError.reconnectFailed(let underlyingError) {
      XCTAssertEqual(AggApiError.from(underlyingError)?.status, 502)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
    XCTAssertEqual(api.calls, ["createQuote", "createOrder", "createLinkChallenge", "createLink"])
    XCTAssertEqual(signatures.value.count, 1)
  }

  func test_withdraw_aWithdrawalRefusedForTheLinkWhoseReconnectFailsTransiently_signsOnceAndIsReconnectFailed() async throws {
    try stubWithdrawal()
    try stubLink()
    api.createWithdrawalHandler = { _ in throw Self.linkRequired }
    api.createLinkChallengeHandler = { _ in throw AggRequestError(traceId: "t", underlyingError: URLError(.networkConnectionLost)) }
    let signatures = Box<[[String]]>([])

    do {
      _ = try await makeAgg(dependencies: linkDependencies(signatures: signatures)).withdraw(params: AggWithdrawParams(
        amount: "1.5", tokenSymbol: .usdc, destinationChainId: "eip155:8453", autoReconnect: true, poll: Self.fastPoll
      ))
      XCTFail("Expected reconnectFailed")
    } catch AggError.reconnectFailed(let underlyingError) {
      XCTAssertEqual(((underlyingError as? AggRequestError)?.underlyingError as? URLError)?.code, .networkConnectionLost)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
    XCTAssertEqual(api.callCount("createWithdrawal"), 1)
    XCTAssertEqual(api.callCount("createLinkChallenge"), 1)
    XCTAssertEqual(signatures.value.count, 0)
  }

  /// Reading a fill that was placed, refused for the link, with a reconnect that fails with a
  /// gateway error: the read is not repeated (each repeat would sign again), and the fill's outcome
  /// is unknown.
  func test_buy_aFillReadRefusedForTheLinkWhoseReconnectFailsTransiently_signsOnceAndIsOutcomeUnknown() async throws {
    try stubTrade(states: [("filled", true)])
    try stubLink()
    api.getOrderHandler = { _, _ in throw Self.linkRequired }
    api.createLinkHandler = { _ in throw Self.apiError(503) }
    let signatures = Box<[[String]]>([])

    do {
      _ = try await makeAgg(dependencies: linkDependencies(signatures: signatures)).buy(params: buyParams(autoReconnect: true))
      XCTFail("Expected orderOutcomeUnknown")
    } catch let AggError.orderOutcomeUnknown(quote, fill, _, underlyingError) {
      XCTAssertEqual(quote.quoteId, "q1")
      XCTAssertNotNil(fill)
      guard case let AggError.reconnectFailed(cause)? = underlyingError as? AggError else {
        return XCTFail("Expected reconnectFailed, got \(underlyingError)")
      }
      XCTAssertEqual(AggApiError.from(cause)?.status, 503)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
    XCTAssertEqual(api.callCount("getOrder"), 1)
    XCTAssertEqual(api.callCount("createLink"), 1)
    XCTAssertEqual(signatures.value.count, 1)
  }

  func test_deposit_addressesRefusedForTheLinkWhoseReconnectFailsTransiently_signsOnceAndSendsNothing() async throws {
    try stubLink()
    api.getDepositAddressesHandler = { throw Self.linkRequired }
    api.createLinkHandler = { _ in throw Self.apiError(504) }
    let signatures = Box<[[String]]>([])
    let sends = Locked(0)
    var dependencies = linkDependencies(signatures: signatures)
    dependencies.sendAsset = { _, _ in
      sends.value += 1
      return "0xtx"
    }

    do {
      _ = try await makeAgg(dependencies: dependencies).deposit(params: AggDepositParams(
        chainId: "eip155:8453", token: "USDC", amount: "1", autoReconnect: true, addressPoll: Self.fastPoll
      ))
      XCTFail("Expected reconnectFailed")
    } catch AggError.reconnectFailed(let underlyingError) {
      XCTAssertEqual(AggApiError.from(underlyingError)?.status, 504)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
    XCTAssertEqual(api.callCount("getDepositAddresses"), 1)
    XCTAssertEqual(signatures.value.count, 1)
    XCTAssertEqual(sends.value, 0)
  }

  func test_reconnectFailed_isNeitherTransientNorAmbiguous() {
    let failed = AggError.reconnectFailed(underlyingError: Self.apiError(503))

    XCTAssertFalse(AggRequestFailure.isTransient(failed))
    XCTAssertFalse(AggRequestFailure.isAmbiguous(failed))
  }

  func test_autoReconnect_linksAgainOnTheChainTheLastConnectUsed() async throws {
    try stubTrade(states: [("filled", true)])
    try stubLink()
    var challengeChains: [String?] = []
    let createLinkChallenge = api.createLinkChallengeHandler
    api.createLinkChallengeHandler = { request in
      challengeChains.append(request.chainId)
      return try await XCTUnwrap(createLinkChallenge)(request)
    }
    let quote = try quote()
    let quotes = Results<AggCreateQuoteResponse>([.failure(Self.linkRequired), .success(quote)])
    api.createQuoteHandler = { _ in try quotes.next() }
    let agg = makeAgg()

    _ = try await agg.connect(chainId: "eip155:8453")
    _ = try await agg.buy(params: buyParams(autoReconnect: true))

    XCTAssertEqual(challengeChains, ["eip155:8453", "eip155:8453"])
  }

  func test_autoReconnect_beforeAnyConnect_linksOnPolygon() async throws {
    try stubTrade(states: [("filled", true)])
    try stubLink()
    var challengeChains: [String?] = []
    let createLinkChallenge = api.createLinkChallengeHandler
    api.createLinkChallengeHandler = { request in
      challengeChains.append(request.chainId)
      return try await XCTUnwrap(createLinkChallenge)(request)
    }
    let quote = try quote()
    let quotes = Results<AggCreateQuoteResponse>([.failure(Self.linkRequired), .success(quote)])
    api.createQuoteHandler = { _ in try quotes.next() }

    _ = try await makeAgg().buy(params: buyParams(autoReconnect: true))

    XCTAssertEqual(challengeChains, [Agg.defaultLinkChainId])
  }

  /// Two buys refused for the link while the account is unlinked. The signature waits until both
  /// report `.reconnecting`, which a helper does once it holds the reconnect it waits for, so both
  /// wait for the same one.
  private func stubTwoHelpersRefusedForTheLink(personalSign: @escaping () throws -> String) throws -> (Agg, Locked<Int>) {
    try stubTrade(states: [("filled", true)])
    try stubLink()
    let quote = try quote()
    let linked = Locked(false)
    let signatures = Locked(0)
    let progress = try XCTUnwrap(self.progress)
    api.createQuoteHandler = { _ in
      guard linked.value else {
        throw Self.linkRequired
      }
      return quote
    }
    let createLink = api.createLinkHandler
    api.createLinkHandler = { request in
      let link = try await XCTUnwrap(createLink)(request)
      linked.value = true
      return link
    }
    let agg = makeAgg(dependencies: AggDependencies(
      getAddress: { _ in Self.wallet },
      personalSign: { _, _ in
        signatures.value += 1
        let deadline = Date().addingTimeInterval(5)
        while progress.steps.filter({ $0 == .reconnecting }).count < 2, Date() < deadline {
          try await Task.sleep(nanoseconds: 1_000_000)
        }
        return try personalSign()
      },
      isChainConfigured: { _ in true }
    ))
    return (agg, signatures)
  }

  private func outcome(of agg: Agg, _ params: AggBuyParams) async -> Swift.Result<AggTradeResult, Error> {
    do {
      return try await .success(agg.buy(params: params))
    } catch {
      return .failure(error)
    }
  }

  func test_autoReconnect_helpersRefusedAtTheSameTime_shareOneSignature() async throws {
    let (agg, signatures) = try stubTwoHelpersRefusedForTheLink { "0xsig" }
    let params = buyParams(autoReconnect: true)

    async let first = agg.buy(params: params)
    async let second = agg.buy(params: params)
    let results = try await [first, second]

    XCTAssertEqual(results.map(\.status.overallState), [.filled, .filled])
    XCTAssertEqual(signatures.value, 1)
    XCTAssertEqual(api.callCount("createLinkChallenge"), 1)
    XCTAssertEqual(api.callCount("createLink"), 1)
  }

  func test_autoReconnect_aSharedReconnectThatFails_failsEveryHelperWaitingForIt() async throws {
    let declined = NSError(domain: "AggTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Signature declined"])
    let (agg, signatures) = try stubTwoHelpersRefusedForTheLink { throw declined }
    let params = buyParams(autoReconnect: true)

    async let first = outcome(of: agg, params)
    async let second = outcome(of: agg, params)
    let results = await [first, second]

    for result in results {
      guard case let .failure(AggError.reconnectFailed(error as NSError)) = result else {
        return XCTFail("Expected the declined signature, got \(result)")
      }
      XCTAssertEqual(error.domain, "AggTests")
      XCTAssertEqual(error.code, 2)
    }
    XCTAssertEqual(signatures.value, 1)
    XCTAssertEqual(api.callCount("createLink"), 0)
  }

  func test_autoReconnect_aCallSentBeforeALinkThatCompleted_isRetriedWithoutSigningAgain() async throws {
    try stubTrade(states: [("filled", true)])
    try stubLink()
    let signatures = Box<[[String]]>([])
    let agg = makeAgg(dependencies: linkDependencies(signatures: signatures))
    let quote = try quote()
    let quoteCalls = Locked(0)
    api.createQuoteHandler = { _ in
      quoteCalls.value += 1
      guard quoteCalls.value > 1 else {
        // The account links while this call is in flight, and the call is still refused.
        _ = try await agg.connect()
        throw Self.linkRequired
      }
      return quote
    }

    _ = try await agg.buy(params: buyParams(autoReconnect: true))

    XCTAssertEqual(signatures.value.count, 1)
    XCTAssertEqual(api.callCount("createQuote"), 2)
    XCTAssertFalse(progress.steps.contains(.reconnecting))
  }

  // MARK: - Transient failures

  func test_isTransient_coversRateLimitsGatewayErrorsAndNetworkFailures() {
    let transient: [Error] = [
      Self.apiError(429),
      Self.apiError(502),
      Self.apiError(503),
      Self.apiError(504),
      AggRequestError(traceId: "t", underlyingError: URLError(.timedOut)),
      AggRequestError(traceId: "t", underlyingError: URLError(.networkConnectionLost)),
      AggRequestError(traceId: "t", underlyingError: URLError(.notConnectedToInternet)),
      AggRequestError(traceId: "t", underlyingError: URLError(.cannotConnectToHost)),
      AggRequestError(traceId: "t", underlyingError: URLError(.cannotFindHost)),
      AggRequestError(traceId: "t", underlyingError: URLError(.dnsLookupFailed))
    ]
    let lasting: [Error] = [
      Self.apiError(400),
      Self.apiError(409),
      Self.apiError(500),
      AggRequestError(traceId: "t", underlyingError: URLError(.serverCertificateUntrusted)),
      AggRequestError(traceId: "t", underlyingError: URLError(.secureConnectionFailed)),
      AggRequestError(traceId: "t", underlyingError: URLError(.clientCertificateRejected)),
      AggRequestError(traceId: "t", underlyingError: DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "x"))),
      URLError(.timedOut),
      AggError.noAddress
    ]

    for error in transient {
      XCTAssertTrue(AggRequestFailure.isTransient(error), "\(error)")
    }
    for error in lasting {
      XCTAssertFalse(AggRequestFailure.isTransient(error), "\(error)")
    }
  }

  func test_buy_aCertificateFailure_isNotReadThrough() async throws {
    try stubTrade(states: [])
    api.getOrderHandler = { _, _ in throw AggRequestError(traceId: "t", underlyingError: URLError(.serverCertificateUntrusted)) }

    do {
      _ = try await makeAgg().buy(params: buyParams())
      XCTFail("Expected orderOutcomeUnknown")
    } catch AggError.orderOutcomeUnknown(_, let fill, _, let underlyingError) {
      XCTAssertNotNil(fill)
      XCTAssertEqual(((underlyingError as? AggRequestError)?.underlyingError as? URLError)?.code, .serverCertificateUntrusted)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
    XCTAssertEqual(api.callCount("getOrder"), 1)
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

  func test_redeemAll_stopsReadingWhenAggSendsACursorAgain_andRedeemsWhatItRead() async throws {
    let page: AggListPositionsResponse = try AggResponse(data: Self.decode(
      #"{"data":[\#(position(redeemStatus: "eligible", outcomes: [(true, ["v1"])]))],"nextCursor":"same","hasMore":true}"#
    ))
    var cursors: [String?] = []
    api.listPositionsHandler = { params in
      cursors.append(params.cursor)
      return page
    }
    var batches: [[String]] = []
    let redeemed: AggRedeemResult = try Self.decode(AggFixtures.redeem)
    api.redeemPositionsHandler = { request in
      batches.append(request.venueMarketOutcomeIds)
      return AggResponse(data: redeemed)
    }

    _ = try await makeAgg().redeemAll()

    XCTAssertEqual(cursors, [nil, "same"])
    XCTAssertEqual(batches, [["v1"]])
  }

  func test_redeemAll_readsAtMost100Pages() async throws {
    var calls = 0
    api.listPositionsHandler = { _ in
      calls += 1
      return try AggResponse(data: Self.decode(#"{"data":[],"nextCursor":"c\#(calls)","hasMore":true}"#))
    }

    let results = try await makeAgg().redeemAll()

    XCTAssertTrue(results.isEmpty)
    XCTAssertEqual(calls, Agg.maxPositionPages)
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

  func test_withdraw_aTimeout_failsWithOutcomeUnknownWrappingTheWithdrawalTimeout() async throws {
    try stubWithdrawal(reads: [.success("transferring")])

    do {
      _ = try await makeAgg().withdraw(params: withdrawParams(poll: AggPollOptions(interval: 0.01, timeout: 0.05)))
      XCTFail("Expected withdrawalOutcomeUnknown")
    } catch AggError.withdrawalOutcomeUnknown(let request, let withdrawal, let last, let underlyingError) {
      XCTAssertEqual(request.requestId, "r1")
      XCTAssertEqual(withdrawal?.withdrawalId, "w1")
      XCTAssertEqual(last?.status, .transferring)
      guard case let AggError.withdrawalTimeout(withdrawalId, timeoutLast)? = underlyingError as? AggError else {
        return XCTFail("Expected withdrawalTimeout, got \(underlyingError)")
      }
      XCTAssertEqual(withdrawalId, "w1")
      XCTAssertEqual(timeoutLast?.status, .transferring)
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
    XCTAssertEqual(result.idempotencyKey, "k1")
    XCTAssertEqual(sent?.0, "eip155:8453")
    XCTAssertEqual(sent?.1.to, "0xDeposit")
    XCTAssertEqual(sent?.1.token, "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913")
    XCTAssertEqual(sent?.1.amount, "1")
    XCTAssertEqual(sent?.1.idempotencyKey, "k1")
    XCTAssertEqual(api.callCount("getDepositAddresses"), 2)
    XCTAssertEqual(progress.steps, [.awaitingDepositAddresses, .sendingDeposit, .depositSent])
    XCTAssertEqual(progress.idempotencyKeys, [nil, "k1", "k1"])
  }

  func test_deposit_withoutAKey_reportsTheGeneratedOneItSentWith() async throws {
    let ready: AggDepositAddresses = try Self.decode(Self.depositAddresses)
    api.getDepositAddressesHandler = { AggResponse(data: ready) }
    let sentKey = Locked<String?>(nil)
    let agg = makeAgg(dependencies: AggDependencies(sendAsset: { _, params in
      sentKey.value = params.idempotencyKey
      return "0xtx"
    }))

    let result = try await agg.deposit(params: AggDepositParams(chainId: "eip155:8453", token: "USDC", amount: "1", onProgress: progress.record, addressPoll: Self.fastPoll))

    XCTAssertFalse(result.idempotencyKey.isEmpty)
    XCTAssertEqual(sentKey.value, result.idempotencyKey)
    XCTAssertEqual(progress.idempotencyKeys, [nil, result.idempotencyKey, result.idempotencyKey])
  }

  func test_deposit_onAChainWithoutAnRpcUrl_sendsNothing() async throws {
    let checked = Locked<[String]>([])
    let sends = Locked(0)
    let agg = makeAgg(dependencies: AggDependencies(
      isChainConfigured: { chainId in
        checked.value.append(chainId)
        return false
      },
      sendAsset: { _, _ in
        sends.value += 1
        return "0xtx"
      }
    ))

    do {
      _ = try await agg.deposit(params: AggDepositParams(chainId: "eip155:8453", token: "USDC", amount: "1", addressPoll: Self.fastPoll))
      XCTFail("Expected missingRpcUrl")
    } catch AggError.missingRpcUrl(let chainId) {
      XCTAssertEqual(chainId, "eip155:8453")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
    XCTAssertEqual(checked.value, ["eip155:8453"])
    XCTAssertTrue(api.calls.isEmpty)
    XCTAssertEqual(sends.value, 0)
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

  // MARK: - deposit token

  // Agg identifies a deposit token by chain and address: a symbol is only a lookup convenience, and
  // the order of its token list means nothing.

  private static let polygon = "eip155:137"
  private static let polygonUsdc = AggSupportedChainToken(symbol: "USDC", address: "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359", decimals: 6)
  private static let polygonUsdcE = AggSupportedChainToken(symbol: "USDC.e", address: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", decimals: 6)

  private static func listing(_ chains: [(chainId: String, tokens: [AggSupportedChainToken])]) -> AggGetDepositAddressesResponse {
    AggResponse(data: .ready(AggDepositAddresses.Ready(
      evmAddress: "0xDeposit",
      svmAddress: "SoLDeposit",
      supportedChains: chains.map { AggDepositAddresses.Ready.SupportedChain(chainId: $0.chainId, name: $0.chainId, tokens: $0.tokens) }
    )))
  }

  private static func inBothOrders(_ tokens: [AggSupportedChainToken]) -> [[AggSupportedChainToken]] {
    [tokens, tokens.reversed()]
  }

  /// An `Agg` whose `sendAsset` records the token address of each send.
  private func recordingAgg(_ sentTokens: Locked<[String]>) -> Agg {
    makeAgg(dependencies: AggDependencies(sendAsset: { _, params in
      sentTokens.value.append(params.token)
      return "0xtx"
    }))
  }

  private func deposit(_ agg: Agg, on chainId: String, token: String, autoReconnect: Bool = false) async throws -> AggDepositResult {
    try await agg.deposit(params: AggDepositParams(chainId: chainId, token: token, amount: "10", autoReconnect: autoReconnect, addressPoll: Self.fastPoll))
  }

  /// The `ambiguousDepositToken` that `call` fails with; `nil`, failing the test, when it fails with
  /// anything else or succeeds.
  private func ambiguousDepositToken(
    _ call: () async throws -> AggDepositResult,
    file: StaticString = #filePath,
    line: UInt = #line
  ) async -> (chainId: String, token: String, candidates: [AggSupportedChainToken], error: AggError)? {
    do {
      _ = try await call()
      XCTFail("Expected ambiguousDepositToken", file: file, line: line)
    } catch let error as AggError {
      if case let .ambiguousDepositToken(chainId, token, candidates) = error {
        return (chainId, token, candidates, error)
      }
      XCTFail("Unexpected error: \(error)", file: file, line: line)
    } catch {
      XCTFail("Unexpected error: \(error)", file: file, line: line)
    }
    return nil
  }

  func test_deposit_ofUsdcAndUsdcE_inEitherOrder_sendsTheTokenEachSymbolAndAddressNames() async throws {
    for tokens in Self.inBothOrders([Self.polygonUsdc, Self.polygonUsdcE]) {
      let sent = Locked<[String]>([])
      let agg = recordingAgg(sent)
      api.getDepositAddressesHandler = { Self.listing([(Self.polygon, tokens)]) }

      for token in ["usdc", "USDC.e", Self.polygonUsdc.address.lowercased(), "0x" + Self.polygonUsdcE.address.dropFirst(2).uppercased()] {
        _ = try await deposit(agg, on: Self.polygon, token: token)
      }

      XCTAssertEqual(sent.value, [Self.polygonUsdc.address, Self.polygonUsdcE.address, Self.polygonUsdc.address, Self.polygonUsdcE.address])
    }
  }

  func test_deposit_ofASymbolTwoTokensShare_inEitherOrder_isAmbiguousAndSendsNothing() async throws {
    let bridged = AggSupportedChainToken(symbol: "USDC", address: Self.polygonUsdcE.address, decimals: 6)
    let sent = Locked<[String]>([])
    let agg = recordingAgg(sent)
    for tokens in Self.inBothOrders([Self.polygonUsdc, bridged]) {
      api.getDepositAddressesHandler = { Self.listing([(Self.polygon, tokens)]) }

      let failure = await ambiguousDepositToken { try await self.deposit(agg, on: Self.polygon, token: "USDC") }

      XCTAssertEqual(failure?.chainId, Self.polygon)
      XCTAssertEqual(failure?.token, "USDC")
      // Sorted by address, whatever order Agg listed them in.
      XCTAssertEqual(failure?.candidates, [bridged, Self.polygonUsdc])
      let description = failure?.error.errorDescription ?? ""
      XCTAssertTrue(description.contains(Self.polygonUsdc.address), description)
      XCTAssertTrue(description.contains(bridged.address), description)
      XCTAssertNil(AggApiError.from(failure?.error))
    }
    XCTAssertEqual(sent.value, [])
  }

  func test_deposit_byAddress_picksOneOfTwoTokensThatShareASymbol() async throws {
    let sent = Locked<[String]>([])
    api.getDepositAddressesHandler = {
      Self.listing([(Self.polygon, [Self.polygonUsdc, AggSupportedChainToken(symbol: "USDC", address: Self.polygonUsdcE.address, decimals: 6)])])
    }

    let result = try await deposit(recordingAgg(sent), on: Self.polygon, token: Self.polygonUsdcE.address)

    XCTAssertEqual(sent.value, [Self.polygonUsdcE.address])
    XCTAssertEqual(result.token.address, Self.polygonUsdcE.address)
  }

  func test_deposit_ofASolanaMint_matchesItExactly_neverInAnotherCase() async throws {
    let solana = "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp"
    let mint = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"
    let sent = Locked<[String]>([])
    let agg = recordingAgg(sent)
    api.getDepositAddressesHandler = { Self.listing([(solana, [AggSupportedChainToken(symbol: "USDC", address: mint, decimals: 6)])]) }

    _ = try await deposit(agg, on: solana, token: mint)
    do {
      _ = try await deposit(agg, on: solana, token: mint.lowercased())
      XCTFail("Expected unsupportedDepositToken")
    } catch AggError.unsupportedDepositToken(let chainId, let token) {
      XCTAssertEqual(chainId, solana)
      XCTAssertEqual(token, mint.lowercased())
    }

    XCTAssertEqual(sent.value, [mint])
  }

  func test_deposit_byAnAddressListedUnderTwoSymbols_inEitherOrder_resolvesItTheSameWay() async throws {
    let native = AggSupportedChainToken(symbol: "USDC.native", address: Self.polygonUsdc.address, decimals: 6)
    for tokens in Self.inBothOrders([Self.polygonUsdc, native]) {
      let sent = Locked<[String]>([])
      api.getDepositAddressesHandler = { Self.listing([(Self.polygon, tokens)]) }

      let result = try await deposit(recordingAgg(sent), on: Self.polygon, token: Self.polygonUsdc.address)

      XCTAssertEqual(result.token, Self.polygonUsdc)
      XCTAssertEqual(sent.value, [Self.polygonUsdc.address])
    }
  }

  func test_deposit_ofATokenListedTwice_inEitherOrder_sendsItAsOneToken() async throws {
    for tokens in Self.inBothOrders([Self.polygonUsdc, Self.polygonUsdcE, Self.polygonUsdc]) {
      let sent = Locked<[String]>([])
      api.getDepositAddressesHandler = { Self.listing([(Self.polygon, tokens)]) }

      let result = try await deposit(recordingAgg(sent), on: Self.polygon, token: "USDC")

      XCTAssertEqual(result.token, Self.polygonUsdc)
      XCTAssertEqual(sent.value, [Self.polygonUsdc.address])
    }
  }

  func test_deposit_ofAnEvmAddressListedInAnotherCase_isOneToken() async throws {
    let lowercased = AggSupportedChainToken(symbol: "USDC", address: Self.polygonUsdc.address.lowercased(), decimals: 6)
    for tokens in Self.inBothOrders([Self.polygonUsdc, lowercased]) {
      let sent = Locked<[String]>([])
      api.getDepositAddressesHandler = { Self.listing([(Self.polygon, tokens)]) }

      let result = try await deposit(recordingAgg(sent), on: Self.polygon, token: "USDC")

      XCTAssertEqual(result.token, Self.polygonUsdc)
      XCTAssertEqual(sent.value, [Self.polygonUsdc.address])
    }
  }

  func test_deposit_ofAnAddressListedWithConflictingDecimals_inEitherOrder_isRefusedBySymbolAndByAddress() async throws {
    let wide = AggSupportedChainToken(symbol: "USDC", address: Self.polygonUsdc.address, decimals: 18)
    let sent = Locked<[String]>([])
    let agg = recordingAgg(sent)
    for tokens in Self.inBothOrders([Self.polygonUsdc, wide]) {
      api.getDepositAddressesHandler = { Self.listing([(Self.polygon, tokens)]) }

      for token in ["USDC", Self.polygonUsdc.address] {
        let failure = await ambiguousDepositToken { try await self.deposit(agg, on: Self.polygon, token: token) }

        XCTAssertEqual(failure?.candidates, [Self.polygonUsdc, wide])
        let description = failure?.error.errorDescription ?? ""
        XCTAssertTrue(description.contains("conflicting decimals"), description)
      }
    }
    XCTAssertEqual(sent.value, [])
  }

  func test_deposit_ofASymbolListedOnAnotherChainToo_isNotAConflict() async throws {
    let base = "eip155:8453"
    let baseUsdc = AggSupportedChainToken(symbol: "USDC", address: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", decimals: 6)
    let sent = Locked<[String]>([])
    let agg = recordingAgg(sent)
    api.getDepositAddressesHandler = { Self.listing([(base, [baseUsdc]), (Self.polygon, [Self.polygonUsdc])]) }

    _ = try await deposit(agg, on: base, token: "USDC")
    _ = try await deposit(agg, on: Self.polygon, token: "USDC")

    XCTAssertEqual(sent.value, [baseUsdc.address, Self.polygonUsdc.address])
  }

  func test_deposit_onAChainListedInTwoEntries_searchesThemBoth() async throws {
    let reads = Results<AggGetDepositAddressesResponse>([
      .success(Self.listing([(Self.polygon, [Self.polygonUsdc]), (Self.polygon, [Self.polygonUsdcE])])),
      .success(Self.listing([(Self.polygon, [Self.polygonUsdc]), (Self.polygon, [AggSupportedChainToken(symbol: "USDC", address: Self.polygonUsdcE.address, decimals: 6)])]))
    ])
    api.getDepositAddressesHandler = { try reads.next() }
    let sent = Locked<[String]>([])
    let agg = recordingAgg(sent)

    _ = try await deposit(agg, on: Self.polygon, token: "USDC.e")
    let failure = await ambiguousDepositToken { try await self.deposit(agg, on: Self.polygon, token: "USDC") }

    XCTAssertEqual(sent.value, [Self.polygonUsdcE.address])
    XCTAssertEqual(failure?.candidates.count, 2)
  }

  func test_deposit_ofAnAmbiguousSymbol_isNeitherRetriedNorAReconnect() async throws {
    api.getDepositAddressesHandler = {
      Self.listing([(Self.polygon, [Self.polygonUsdc, AggSupportedChainToken(symbol: "USDC", address: Self.polygonUsdcE.address, decimals: 6)])])
    }
    let sent = Locked<[String]>([])
    let agg = recordingAgg(sent)

    _ = await ambiguousDepositToken { try await self.deposit(agg, on: Self.polygon, token: "USDC", autoReconnect: true) }

    XCTAssertEqual(api.callCount("getDepositAddresses"), 1)
    XCTAssertEqual(api.callCount("createLinkChallenge"), 0)
    XCTAssertEqual(api.callCount("createLink"), 0)
    XCTAssertEqual(sent.value, [])
  }

  func test_isSameTokenAddress_ignoresCaseOnlyForEvmAddressesOnEvmChains() {
    let evm = Self.polygonUsdc.address
    let mint = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"

    XCTAssertTrue(Agg.isSameTokenAddress(chainId: Self.polygon, evm, evm.lowercased()))
    XCTAssertTrue(Agg.isSameTokenAddress(chainId: Self.polygon, evm, "0x" + evm.dropFirst(2).uppercased()))
    // Only a whole EVM address compares in any case; anything else on an EVM chain is exact.
    XCTAssertFalse(Agg.isSameTokenAddress(chainId: Self.polygon, "NATIVE", "native"))
    XCTAssertFalse(Agg.isSameTokenAddress(chainId: Self.polygon, evm + "\n", evm.lowercased() + "\n"))
    // Off EVM chains, an address is exact even when it looks like an EVM one.
    XCTAssertFalse(Agg.isSameTokenAddress(chainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp", mint, mint.lowercased()))
    XCTAssertFalse(Agg.isSameTokenAddress(chainId: "hyperliquid:mainnet", evm, evm.lowercased()))
    XCTAssertTrue(Agg.isSameTokenAddress(chainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp", mint, mint))
  }

  // MARK: - deposit outcome

  /// An `Agg` whose `sendAsset` counts its calls and answers with `send`.
  private func sendingAgg(_ sends: Locked<Int>, _ send: @escaping () async throws -> String) -> Agg {
    makeAgg(dependencies: AggDependencies(sendAsset: { _, _ in
      sends.value += 1
      return try await send()
    }))
  }

  private func baseDeposit(_ agg: Agg) async throws -> AggDepositResult {
    try await agg.deposit(params: AggDepositParams(
      chainId: "eip155:8453", token: "USDC", amount: "1.5", idempotencyKey: "k1", onProgress: progress.record, autoReconnect: true, addressPoll: Self.fastPoll
    ))
  }

  private static let buildTransactionUrl = "https://api.portalhq.io/api/v3/clients/me/chains/eip155:8453/assets/send/build-transaction"

  private static func mpcError(_ id: String) -> PortalMpcError {
    PortalMpcError(PortalError(code: 400, id: id, message: "failed"))
  }

  func test_deposit_aSendThatMayHaveBeenBroadcast_failsWithOutcomeUnknownAndTheKeyToRetryWith() async throws {
    let ready: AggDepositAddresses = try Self.decode(Self.depositAddresses)
    api.getDepositAddressesHandler = { AggResponse(data: ready) }
    let failures: [Error] = [
      URLError(.timedOut),
      URLError(.networkConnectionLost),
      // The node may have accepted the transaction before the call failed.
      Self.mpcError("RPC_OP_FAILED"),
      // A retry of a send that already went out: Portal does not say whether it landed.
      Self.mpcError(PortalIdempotencyErrorId.requestAlreadyCompleted),
      Self.mpcError(PortalIdempotencyErrorId.requestPreviouslyFailed),
      Self.mpcError(PortalIdempotencyErrorId.keyReused),
      PortalClassError.invalidResponseTypeForRequest,
      PortalRequestsError.internalServerError("500 - failed", url: "https://mpc.portalhq.io"),
      // Requests other than the build may come after the transaction was signed.
      PortalRequestsError.clientError("400 - failed", url: "https://rpc.example.com/eip155:8453"),
      URLError(.networkConnectionLost, userInfo: [NSURLErrorFailingURLErrorKey: URL(string: "https://rpc.example.com/eip155:8453")!]),
      // A cancellation the deposit did not ask for: the send may still have gone out.
      CancellationError()
    ]

    for failure in failures {
      let sends = Locked(0)
      let agg = sendingAgg(sends) { throw failure }
      progress = ProgressRecorder()

      do {
        _ = try await baseDeposit(agg)
        XCTFail("Expected depositOutcomeUnknown for \(failure)")
      } catch let AggError.depositOutcomeUnknown(idempotencyKey, chainId, depositAddress, token, amount, underlyingError) {
        XCTAssertEqual(idempotencyKey, "k1")
        XCTAssertEqual(chainId, "eip155:8453")
        XCTAssertEqual(depositAddress, "0xDeposit")
        XCTAssertEqual(token, AggSupportedChainToken(symbol: "USDC", address: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", decimals: 6))
        XCTAssertEqual(amount, "1.5")
        XCTAssertEqual(String(describing: underlyingError), String(describing: failure))
      } catch {
        XCTFail("Unexpected error for \(failure): \(error)")
      }
      // Sent once: neither retried nor taken for a link failure.
      XCTAssertEqual(sends.value, 1, "\(failure)")
      XCTAssertEqual(progress.steps, [.awaitingDepositAddresses, .sendingDeposit], "\(failure)")
    }
    XCTAssertEqual(api.callCount("createLinkChallenge"), 0)
  }

  func test_deposit_aSendRefusedBeforeItCouldBroadcast_failsWithItsOwnError() async throws {
    let ready: AggDepositAddresses = try Self.decode(Self.depositAddresses)
    api.getDepositAddressesHandler = { AggResponse(data: ready) }
    let failures: [Error] = [
      PortalIdempotencyError.invalidKey("idempotencyKey must not be empty or whitespace-only"),
      PortalIdempotencyError.unsupportedBitcoinSendAsset,
      PortalCredentialError.sessionInvalidated,
      ProviderSigningError.userDeclinedApproval,
      ProviderSigningError.walletRequestRejected,
      Self.mpcError("AUTH_FAILED"),
      Self.mpcError("INSUFFICIENT_FUNDS"),
      Self.mpcError("TX_BUILD_FAILED"),
      Self.mpcError("ADDRESS_BLOCKED"),
      PortalClassError.clientNotAvailable,
      PortalClassError.invalidParameters("Missing required parameters: to, token, or amount"),
      PortalClassError.invalidChainId("eip155"),
      PortalClassError.unsupportedChainId("eip155:8453"),
      // Nothing is signed until the build returns, so a failed build sent nothing.
      PortalRequestsError.clientError(#"400 - {"error":"Balance 1 is short of 2"}"#, url: Self.buildTransactionUrl),
      PortalRequestsError.internalServerError("500 - failed", url: Self.buildTransactionUrl),
      URLError(.networkConnectionLost, userInfo: [NSURLErrorFailingURLErrorKey: URL(string: Self.buildTransactionUrl)!])
    ]

    for failure in failures {
      let sends = Locked(0)
      let agg = sendingAgg(sends) { throw failure }

      do {
        _ = try await baseDeposit(agg)
        XCTFail("Expected \(failure)")
      } catch {
        XCTAssertFalse(error is AggError, "\(failure) became \(error)")
        XCTAssertEqual(String(describing: error), String(describing: failure))
        XCTAssertTrue(type(of: error) == type(of: failure), "\(failure) became \(error)")
      }
      XCTAssertEqual(sends.value, 1, "\(failure)")
    }
  }

  func test_deposit_aSendThatReturnsNoTransactionHash_failsWithOutcomeUnknown() async throws {
    let ready: AggDepositAddresses = try Self.decode(Self.depositAddresses)
    api.getDepositAddressesHandler = { AggResponse(data: ready) }
    let sends = Locked(0)

    do {
      _ = try await baseDeposit(sendingAgg(sends) { "" })
      XCTFail("Expected depositOutcomeUnknown")
    } catch let AggError.depositOutcomeUnknown(idempotencyKey, _, _, _, _, underlyingError) {
      XCTAssertEqual(idempotencyKey, "k1")
      XCTAssertTrue(underlyingError is AggMissingTransactionHash, "\(underlyingError)")
      XCTAssertEqual(underlyingError.localizedDescription, "[Agg] sendAsset returned no transaction hash.")
    }
    XCTAssertEqual(sends.value, 1)
    XCTAssertEqual(progress.steps, [.awaitingDepositAddresses, .sendingDeposit])
  }

  func test_deposit_cancelledOnceSending_finishesTheSendAndReturnsIt() async throws {
    let ready: AggDepositAddresses = try Self.decode(Self.depositAddresses)
    api.getDepositAddressesHandler = { AggResponse(data: ready) }
    let sending = expectation(description: "Sending")
    let released = Locked(false)
    let sendSawCancellation = Locked<Bool?>(nil)
    let agg = makeAgg(dependencies: AggDependencies(sendAsset: { _, _ in
      sending.fulfill()
      // A cancellation that reached the send would end this sleep with a `CancellationError`.
      while !released.value {
        try await Task.sleep(nanoseconds: 5_000_000)
      }
      sendSawCancellation.value = Task.isCancelled
      return "0xtx"
    }))
    let task = Task { try await self.baseDeposit(agg) }

    await fulfillment(of: [sending], timeout: 5)
    task.cancel()
    try await Task.sleep(nanoseconds: 50_000_000)
    released.value = true

    let result = try await task.value
    XCTAssertEqual(result.txHash, "0xtx")
    XCTAssertEqual(result.idempotencyKey, "k1")
    XCTAssertEqual(sendSawCancellation.value, false)
    XCTAssertEqual(progress.steps, [.awaitingDepositAddresses, .sendingDeposit, .depositSent])
  }

  func test_deposit_cancelledWhileWaitingForTheAddresses_sendsNothing() async throws {
    let reading = expectation(description: "Reading the deposit addresses")
    api.getDepositAddressesHandler = {
      reading.fulfill()
      try await Task.sleep(nanoseconds: 10_000_000_000)
      return AggGetDepositAddressesResponse(data: .notReady)
    }
    let sends = Locked(0)
    let agg = sendingAgg(sends) { "0xtx" }
    let task = Task { try await self.baseDeposit(agg) }

    await fulfillment(of: [reading], timeout: 5)
    task.cancel()

    do {
      _ = try await task.value
      XCTFail("Expected a cancellation")
    } catch {
      XCTAssertTrue(error is CancellationError, "\(error)")
    }
    XCTAssertEqual(sends.value, 0)
  }

  // MARK: - Missing dependencies

  func test_connect_withoutAPersonalSignDependency_failsBeforeAnyRequest() async {
    let agg = makeAgg(dependencies: AggDependencies(getAddress: { _ in Self.wallet }))

    do {
      _ = try await agg.connect()
      XCTFail("Expected missingDependency")
    } catch AggError.missingDependency(let name) {
      XCTAssertEqual(name, "personalSign")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
    XCTAssertTrue(api.calls.isEmpty)
  }

  func test_deposit_withoutASendAssetDependency_failsBeforeAnyRequest() async {
    do {
      _ = try await makeAgg().deposit(params: AggDepositParams(chainId: "eip155:8453", token: "USDC", amount: "1"))
      XCTFail("Expected missingDependency")
    } catch AggError.missingDependency(let name) {
      XCTAssertEqual(name, "sendAsset")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
    XCTAssertTrue(api.calls.isEmpty)
  }

  // MARK: - Polling

  func test_buy_readsThroughANetworkError() async throws {
    let filled = try execution("filled", terminal: true)
    try stubTrade(states: [])
    let networkError = AggRequestError(traceId: "t", underlyingError: URLError(.networkConnectionLost))
    let reads = Results<AggGetOrderResponse>([.failure(networkError), .success(filled)])
    api.getOrderHandler = { _, _ in try reads.next() }

    let result = try await makeAgg().buy(params: buyParams())

    XCTAssertEqual(result.status.overallState, .filled)
    XCTAssertEqual(api.callCount("getOrder"), 2)
  }

  func test_buy_aReadThatDoesNotDecode_endsTheWaitWithOutcomeUnknown() async throws {
    try stubTrade(states: [])
    let decodingError = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unexpected shape"))
    api.getOrderHandler = { _, _ in throw AggRequestError(traceId: "t", underlyingError: decodingError) }

    do {
      _ = try await makeAgg().buy(params: buyParams())
      XCTFail("Expected orderOutcomeUnknown")
    } catch AggError.orderOutcomeUnknown(_, let fill, _, let underlyingError) {
      XCTAssertNotNil(fill)
      XCTAssertTrue((underlyingError as? AggRequestError)?.underlyingError is DecodingError)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
    XCTAssertEqual(api.callCount("getOrder"), 1)
  }

  func test_buy_waitsAtLeastAQuarterSecondWhenAggAsksForLess() async throws {
    let placing = try AggResponse<AggExecutionStatus>(data: Self.decode(Self.patched(
      AggFixtures.executionStatus,
      ["quoteId": "q1", "overallState": "placing", "terminal": false, "pollAfterMs": 1]
    )))
    let filled = try execution("filled", terminal: true)
    try stubTrade(states: [])
    let reads = Results<AggGetOrderResponse>([.success(placing), .success(filled)])
    api.getOrderHandler = { _, _ in try reads.next() }
    let start = Date()

    _ = try await makeAgg().buy(params: buyParams())

    XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(start), Agg.minOrderPollInterval)
  }

  func test_orderPollWait_keepsAggsPollAfterMsBetweenAQuarterSecondAndTenSeconds() {
    XCTAssertNil(Agg.orderPollWait(pollAfterMs: nil))
    XCTAssertEqual(Agg.orderPollWait(pollAfterMs: 0), 0.25)
    XCTAssertEqual(Agg.orderPollWait(pollAfterMs: 100), 0.25)
    XCTAssertEqual(Agg.orderPollWait(pollAfterMs: 1500), 1.5)
    XCTAssertEqual(Agg.orderPollWait(pollAfterMs: 60000), 10)
  }

  // MARK: - Cancellation

  func test_buy_cancelledWhileWaitingForTheFill_throwsCancellationNotOutcomeUnknown() async throws {
    try stubTrade(states: [])
    let polling = expectation(description: "Reading the fill")
    api.getOrderHandler = { _, _ in
      polling.fulfill()
      try await Task.sleep(nanoseconds: 10_000_000_000)
      throw URLError(.timedOut)
    }
    let agg = makeAgg()
    let params = buyParams(poll: AggPollOptions(interval: 0, timeout: 30))
    let task = Task { try await agg.buy(params: params) }

    await fulfillment(of: [polling], timeout: 5)
    task.cancel()

    do {
      _ = try await task.value
      XCTFail("Expected a cancellation")
    } catch {
      XCTAssertTrue(error is CancellationError, "\(error)")
    }
  }

  func test_withdraw_cancelledWhileWaitingForTheWithdrawal_throwsCancellationNotOutcomeUnknown() async throws {
    try stubWithdrawal()
    let polling = expectation(description: "Reading the withdrawal")
    api.getWithdrawalHandler = { _ in
      polling.fulfill()
      try await Task.sleep(nanoseconds: 10_000_000_000)
      throw URLError(.timedOut)
    }
    let agg = makeAgg()
    let params = withdrawParams(poll: AggPollOptions(interval: 0, timeout: 30))
    let task = Task { try await agg.withdraw(params: params) }

    await fulfillment(of: [polling], timeout: 5)
    task.cancel()

    do {
      _ = try await task.value
      XCTFail("Expected a cancellation")
    } catch {
      XCTAssertTrue(error is CancellationError, "\(error)")
    }
  }

  // MARK: - Route methods

  /// What a mock route received, thrown back so the test sees exactly what `Agg` passed on.
  private struct Forwarded: Error, Equatable {
    let method: String
    let arguments: String

    init(_ method: String, _ arguments: Any...) {
      self.method = method
      self.arguments = arguments.map { "\($0)" }.joined(separator: " | ")
    }
  }

  private func assertForwards(_ expected: Forwarded, _ call: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
    do {
      try await call()
      XCTFail("\(expected.method) did not reach the API", file: file, line: line)
    } catch let forwarded as Forwarded {
      XCTAssertEqual(forwarded, expected, file: file, line: line)
    } catch {
      XCTFail("\(expected.method) failed with \(error)", file: file, line: line)
    }
  }

  func test_everyRouteMethod_forwardsItsArgumentsToTheApiAndItsFailureUnchanged() async {
    api.createLinkChallengeHandler = { throw Forwarded("createLinkChallenge", $0) }
    api.createLinkHandler = { throw Forwarded("createLink", $0) }
    api.getLinkHandler = { throw Forwarded("getLink") }
    api.deleteLinkHandler = { throw Forwarded("deleteLink") }
    api.listEventsHandler = { throw Forwarded("listEvents", $0) }
    api.getEventHandler = { throw Forwarded("getEvent", $0, $1 as Any) }
    api.getEventBootstrapHandler = { throw Forwarded("getEventBootstrap", $0, $1 as Any) }
    api.listMarketsHandler = { throw Forwarded("listMarkets", $0) }
    api.searchHandler = { throw Forwarded("search", $0) }
    api.listCategoriesHandler = { throw Forwarded("listCategories", $0) }
    api.getVenueGeoPolicyHandler = { throw Forwarded("getVenueGeoPolicy") }
    api.getAppConfigHandler = { throw Forwarded("getAppConfig") }
    api.getMidpointsHandler = { throw Forwarded("getMidpoints", $0, $1 as Any) }
    api.getOrderbooksHandler = { throw Forwarded("getOrderbooks", $0, $1 as Any) }
    api.getOutcomeOrderbookHandler = { throw Forwarded("getOutcomeOrderbook", $0, $1 as Any) }
    api.getChartBarsHandler = { throw Forwarded("getChartBars", $0) }
    api.getChartHistoryManifestHandler = { throw Forwarded("getChartHistoryManifest", $0) }
    api.getUserHandler = { throw Forwarded("getUser") }
    api.getDepositAddressesHandler = { throw Forwarded("getDepositAddresses") }
    api.getBalancesHandler = { throw Forwarded("getBalances", $0 as Any, $1 as Any) }
    api.listPositionsHandler = { throw Forwarded("listPositions", $0) }
    api.listOrdersHandler = { throw Forwarded("listOrders", $0) }
    api.listActivityHandler = { throw Forwarded("listActivity", $0) }
    api.createQuoteHandler = { throw Forwarded("createQuote", $0) }
    api.createOrderHandler = { throw Forwarded("createOrder", $0) }
    api.getOrderHandler = { throw Forwarded("getOrder", $0, $1 as Any) }
    api.createLimitOrderHandler = { throw Forwarded("createLimitOrder", $0) }
    api.createDirectOrderHandler = { throw Forwarded("createDirectOrder", $0) }
    api.cancelOrderHandler = { throw Forwarded("cancelOrder", $0) }
    api.redeemPositionsHandler = { throw Forwarded("redeemPositions", $0) }
    api.quoteWithdrawableHandler = { throw Forwarded("quoteWithdrawable", $0) }
    api.previewWithdrawalHandler = { throw Forwarded("previewWithdrawal", $0) }
    api.createWithdrawalHandler = { throw Forwarded("createWithdrawal", $0) }
    api.getWithdrawalHandler = { throw Forwarded("getWithdrawal", $0) }

    let agg = makeAgg()
    let challenge = AggLinkChallengeRequest(chainId: "eip155:1")
    let link = AggLinkRequest(signature: "0xsig")
    let events = AggListEventsParams(status: .open, venues: [.kalshi], limit: 3)
    let markets = AggListMarketsParams(venueEventId: "ev1", projection: .summary)
    let search = AggSearchParams(q: "fed", type: .markets, limit: 2)
    let categories = AggListCategoriesParams(parentId: "p1")
    let chart = AggChartParams(venueMarketOutcomeId: "o1", to: 2000, from: 1000, resolution: .oneHour, countBack: 5)
    let positions = AggListPositionsParams(status: .closed, mode: .paper)
    let orders = AggListOrdersParams(quoteId: "q1", orderType: .limit)
    let activity = AggListActivityParams(type: .redeem, limit: 4)
    let quote = AggQuoteRequest(outcomeId: "o1", side: .buy, amount: "1", mode: .paper)
    let order = AggOrderRequest(quoteId: "q1", mode: .paper)
    let limitOrder = AggLimitOrderRequest(venue: .polymarket, venueMarketOutcomeId: "o1", side: .sell, limitPriceRaw: "1", sizeRaw: "2", timeInForce: .fok)
    let directOrder = AggDirectOrderRequest(venue: .limitless, venueMarketOutcomeId: "o1", side: .buy, externalId: "x1", maxSpend: 1)
    let cancel = AggCancelOrderRequest(orderId: "or1")
    let redeem = AggRedeemRequest(venueMarketOutcomeIds: ["v1", "v2"])
    let withdrawable = AggWithdrawableQuoteRequest(tokenSymbol: .usdt, destinationChainId: "eip155:56")
    let withdrawal = AggWithdrawalRequest(tokenSymbol: .usdc, destinationChainId: "eip155:8453", amountRaw: "1", requestId: "r1")

    await assertForwards(Forwarded("createLinkChallenge", challenge)) { _ = try await agg.createLinkChallenge(request: challenge) }
    await assertForwards(Forwarded("createLink", link)) { _ = try await agg.createLink(request: link) }
    await assertForwards(Forwarded("getLink")) { _ = try await agg.getLink() }
    await assertForwards(Forwarded("deleteLink")) { _ = try await agg.deleteLink() }
    await assertForwards(Forwarded("listEvents", events)) { _ = try await agg.listEvents(params: events) }
    await assertForwards(Forwarded("getEvent", "e1", Bool?.some(true) as Any)) { _ = try await agg.getEvent(eventId: "e1", cluster: true) }
    await assertForwards(Forwarded("getEventBootstrap", "e1", Int?.some(5) as Any)) { _ = try await agg.getEventBootstrap(eventId: "e1", limit: 5) }
    await assertForwards(Forwarded("listMarkets", markets)) { _ = try await agg.listMarkets(params: markets) }
    await assertForwards(Forwarded("search", search)) { _ = try await agg.search(params: search) }
    await assertForwards(Forwarded("listCategories", categories)) { _ = try await agg.listCategories(params: categories) }
    await assertForwards(Forwarded("getVenueGeoPolicy")) { _ = try await agg.getVenueGeoPolicy() }
    await assertForwards(Forwarded("getAppConfig")) { _ = try await agg.getAppConfig() }
    await assertForwards(Forwarded("getMidpoints", ["m1", "m2"], Bool?.some(true) as Any)) {
      _ = try await agg.getMidpoints(venueMarketIds: ["m1", "m2"], bestPrice: true)
    }
    await assertForwards(Forwarded("getOrderbooks", ["m1"], Int?.some(10) as Any)) { _ = try await agg.getOrderbooks(venueMarketIds: ["m1"], depth: 10) }
    await assertForwards(Forwarded("getOutcomeOrderbook", "o1", Int?.some(3) as Any)) { _ = try await agg.getOutcomeOrderbook(outcomeId: "o1", depth: 3) }
    await assertForwards(Forwarded("getChartBars", chart)) { _ = try await agg.getChartBars(params: chart) }
    await assertForwards(Forwarded("getChartHistoryManifest", chart)) { _ = try await agg.getChartHistoryManifest(params: chart) }
    await assertForwards(Forwarded("getUser")) { _ = try await agg.getUser() }
    await assertForwards(Forwarded("getDepositAddresses")) { _ = try await agg.getDepositAddresses() }
    await assertForwards(Forwarded("getBalances", Bool?.some(true) as Any, AggMode?.some(.paper) as Any)) { _ = try await agg.getBalances(sync: true, mode: .paper) }
    await assertForwards(Forwarded("listPositions", positions)) { _ = try await agg.listPositions(params: positions) }
    await assertForwards(Forwarded("listOrders", orders)) { _ = try await agg.listOrders(params: orders) }
    await assertForwards(Forwarded("listActivity", activity)) { _ = try await agg.listActivity(params: activity) }
    await assertForwards(Forwarded("createQuote", quote)) { _ = try await agg.createQuote(request: quote) }
    await assertForwards(Forwarded("createOrder", order)) { _ = try await agg.createOrder(request: order) }
    await assertForwards(Forwarded("getOrder", "q1", AggMode?.some(.live) as Any)) { _ = try await agg.getOrder(quoteId: "q1", mode: .live) }
    await assertForwards(Forwarded("createLimitOrder", limitOrder)) { _ = try await agg.createLimitOrder(request: limitOrder) }
    await assertForwards(Forwarded("createDirectOrder", directOrder)) { _ = try await agg.createDirectOrder(request: directOrder) }
    await assertForwards(Forwarded("cancelOrder", cancel)) { _ = try await agg.cancelOrder(request: cancel) }
    await assertForwards(Forwarded("redeemPositions", redeem)) { _ = try await agg.redeemPositions(request: redeem) }
    await assertForwards(Forwarded("quoteWithdrawable", withdrawable)) { _ = try await agg.quoteWithdrawable(request: withdrawable) }
    await assertForwards(Forwarded("previewWithdrawal", withdrawal)) { _ = try await agg.previewWithdrawal(request: withdrawal) }
    await assertForwards(Forwarded("createWithdrawal", withdrawal)) { _ = try await agg.createWithdrawal(request: withdrawal) }
    await assertForwards(Forwarded("getWithdrawal", "w1")) { _ = try await agg.getWithdrawal(withdrawalId: "w1") }
    XCTAssertEqual(Set(api.calls).count, 34)
  }

  // MARK: - Wiring

  func test_predictionMarkets_canWrapAnAggImplementation() {
    let agg = makeAgg()

    XCTAssertTrue(PredictionMarkets(agg: agg).agg === agg)
  }

  func test_predictionMarkets_routesAggThroughTheApisAgg() async throws {
    api.getLinkHandler = { AggGetLinkResponse(data: .notLinked) }
    let predictionMarkets = PredictionMarkets(api: PortalApiMock(agg: api))

    _ = try await predictionMarkets.agg.getLink()

    XCTAssertEqual(api.calls, ["getLink"])
  }
}
