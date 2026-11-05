//
//  AggErrorsTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

@testable import PortalSwift
import XCTest

final class AggErrorsTests: XCTestCase {
  private static let url = "https://api.portalhq.io/api/v3/clients/me/integrations/agg/quotes"

  private static func decode<T: Decodable>(_ json: String, _ changes: [String: Any] = [:]) throws -> T {
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    changes.forEach { object[$0.key] = $0.value }
    return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: object))
  }

  // MARK: - AggApiError.from

  func test_from_readsATransportErrorThatWasNotWrapped() {
    let error = PortalRequestsError.clientError(#"409 - {"error":"Not linked","id":"AGG_LINK_REQUIRED"}"#, url: Self.url)

    XCTAssertEqual(AggApiError.from(error), AggApiError(status: 409, id: "AGG_LINK_REQUIRED", message: "Not linked"))
  }

  func test_from_aRequestError_addsItsTraceId() {
    let error = AggRequestError(
      traceId: "trace-1",
      underlyingError: PortalRequestsError.internalServerError(#"500 - {"error":"drift","id":"INTEGRATION_RESPONSE_SCHEMA_DRIFT"}"#, url: Self.url)
    )

    XCTAssertEqual(
      AggApiError.from(error),
      AggApiError(status: 500, id: "INTEGRATION_RESPONSE_SCHEMA_DRIFT", message: "drift", traceId: "trace-1")
    )
  }

  func test_from_anUnauthorizedRequest_is401WithoutABody() {
    XCTAssertEqual(AggApiError.from(PortalRequestsError.unauthorized), AggApiError(status: 401))
  }

  func test_from_aBodyThatIsNotAPortalError_keepsItAsTheMessage() {
    let error = PortalRequestsError.internalServerError("502 - <html>Bad Gateway</html>", url: Self.url)

    XCTAssertEqual(AggApiError.from(error), AggApiError(status: 502, message: "<html>Bad Gateway</html>"))
  }

  func test_from_detailsWithoutFields_haveEmptyFields() {
    let error = PortalRequestsError.clientError(#"400 - {"error":"Agg rejected the request","details":{"code":"quote_unfillable"}}"#, url: Self.url)

    XCTAssertEqual(AggApiError.from(error)?.details, AggErrorDetails(code: "quote_unfillable", fields: []))
  }

  func test_from_returnsAnAggApiErrorAsItIs() {
    let apiError = AggApiError(status: 429, message: "Slow down", traceId: "t")

    XCTAssertEqual(AggApiError.from(apiError), apiError)
  }

  func test_from_isNilForFailuresWithoutAnHttpResponse() {
    let decodingError = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unexpected shape"))
    let failures: [Error?] = [
      nil,
      URLError(.notConnectedToInternet),
      decodingError,
      PortalRequestsError.couldNotParseHttpResponse,
      AggError.noAddress,
      AggRequestError(traceId: "t", underlyingError: URLError(.timedOut)),
      AggRequestError(traceId: "t", underlyingError: decodingError)
    ]

    for failure in failures {
      XCTAssertNil(AggApiError.from(failure), "\(String(describing: failure))")
    }
  }

  // MARK: - AggApiError checks

  func test_checks_matchTheirIdsAndStatus() {
    let linkRequired = AggApiError(status: 409, id: AggErrorId.linkRequired)
    let accountAbstraction = AggApiError(status: 400, id: AggErrorId.accountAbstractionUnsupported)
    let sessionRefresh = AggApiError(status: 503, id: AggErrorId.sessionRefreshInProgress)
    let schemaDrift = AggApiError(status: 500, id: AggErrorId.integrationResponseSchemaDrift)
    let rateLimit = AggApiError(status: 429)

    XCTAssertTrue(linkRequired.isLinkRequired)
    XCTAssertTrue(accountAbstraction.isAccountAbstractionUnsupported)
    XCTAssertTrue(sessionRefresh.isSessionRefreshInProgress)
    XCTAssertTrue(schemaDrift.isSchemaDrift)
    XCTAssertTrue(rateLimit.isRateLimit)
    for error in [linkRequired, accountAbstraction, sessionRefresh, schemaDrift] {
      XCTAssertFalse(error.isRateLimit)
    }
    XCTAssertFalse(rateLimit.isLinkRequired || rateLimit.isAccountAbstractionUnsupported || rateLimit.isSessionRefreshInProgress || rateLimit.isSchemaDrift)
  }

  func test_errorIds_matchTheWire() {
    XCTAssertEqual(AggErrorId.linkRequired, "AGG_LINK_REQUIRED")
    XCTAssertEqual(AggErrorId.accountAbstractionUnsupported, "AGG_ACCOUNT_ABSTRACTION_UNSUPPORTED")
    XCTAssertEqual(AggErrorId.sessionRefreshInProgress, "AGG_SESSION_REFRESH_IN_PROGRESS")
    XCTAssertEqual(AggErrorId.integrationResponseSchemaDrift, "INTEGRATION_RESPONSE_SCHEMA_DRIFT")
  }

  // MARK: - Descriptions

  func test_requestError_describesTheUnderlyingErrorWithTheTraceId() {
    let error = AggRequestError(traceId: "trace-9", underlyingError: URLError(.timedOut))

    XCTAssertEqual(error.errorDescription, "\(URLError(.timedOut).localizedDescription) (trace id trace-9)")
  }

  func test_errorDescriptions_nameWhatFailed() throws {
    let quote: AggQuote = try Self.decode(AggFixtures.quotePaper, [
      "quoteId": "q1",
      "warnings": [["venue": "polymarket", "venueMarketOutcomeId": "o1", "reason": "Venue not available in your region (US)"]]
    ])
    let status: AggExecutionStatus = try Self.decode(AggFixtures.executionStatus, ["quoteId": "q1", "overallState": "expired", "errorReason": "Quote expired"])
    let preview: AggWithdrawalPreview = try Self.decode(AggFixtures.withdrawalPreview, ["pricingStatus": "unviable", "unviableReason": "Minimum withdrawal is 1 USDC"])
    let withdrawal: AggWithdrawal = try Self.decode(AggFixtures.withdrawalStatus, ["withdrawalId": "w1", "status": "failed", "errorMessage": "Bridge failed"])
    let request = AggWithdrawalRequest(tokenSymbol: .usdc, destinationChainId: "eip155:8453", amountRaw: "1", requestId: "r1")
    let cause = URLError(.timedOut)
    let usdc = AggSupportedChainToken(symbol: "USDC", address: "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359", decimals: 6)
    let usdcE = AggSupportedChainToken(symbol: "USDC", address: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", decimals: 6)

    let expectations: [(AggError, [String])] = [
      (.noAddress, ["No Portal EVM wallet address"]),
      (.missingRpcUrl(chainId: "eip155:137"), ["eip155:137", "rpcConfig"]),
      (.addressMismatch(expected: "0xwallet", actual: "0xother"), ["0xwallet", "0xother"]),
      (.addressMismatch(expected: "0xwallet", actual: nil), ["no address"]),
      (.emptyIdentifier(name: "quoteId"), ["quoteId must not be empty"]),
      (.invalidAmount(name: "price", value: "1.5"), ["price", "\"1.5\""]),
      (.missingDependency(name: "sendAsset"), ["sendAsset"]),
      (.unsupportedDepositToken(chainId: "eip155:8453", token: "USDT"), ["USDT", "eip155:8453"]),
      (.quoteNotTradable(quote: quote), ["q1", "polymarket: Venue not available in your region (US)"]),
      (.orderFailed(status: status), ["q1", "expired", "Quote expired"]),
      (.withdrawalNotViable(preview: preview), ["unviable", "Minimum withdrawal is 1 USDC"]),
      (.withdrawalFailed(withdrawal: withdrawal), ["w1", "Bridge failed"]),
      (.depositAddressesTimeout(last: .notReady), ["deposit addresses"]),
      (.orderTimeout(quoteId: "q1", last: nil), ["order q1"]),
      (.withdrawalTimeout(withdrawalId: "w1", last: nil), ["withdrawal w1"]),
      (.orderOutcomeUnknown(quote: quote, fill: nil, last: nil, underlyingError: cause), ["q1", "getOrder", cause.localizedDescription]),
      (.withdrawalOutcomeUnknown(request: request, withdrawal: nil, last: nil, underlyingError: cause), ["requestId r1", cause.localizedDescription]),
      (.withdrawalOutcomeUnknown(request: request, withdrawal: withdrawal, last: nil, underlyingError: cause), ["w1"]),
      (
        .ambiguousDepositToken(chainId: "eip155:137", token: "USDC", candidates: [usdcE, usdc]),
        ["USDC names 2 tokens on eip155:137", "USDC \(usdcE.address), USDC \(usdc.address)", "nothing was sent", "Pass the address"]
      ),
      (
        .ambiguousDepositToken(chainId: "eip155:137", token: "USDC", candidates: [usdc, AggSupportedChainToken(symbol: "USDC", address: usdc.address.lowercased(), decimals: 18)]),
        ["USDC on eip155:137 with conflicting decimals", "nothing was sent"]
      ),
      (
        .depositOutcomeUnknown(idempotencyKey: "k1", chainId: "eip155:8453", depositAddress: "0xDeposit", token: usdc, amount: "1.5", underlyingError: cause),
        ["1.5 USDC on eip155:8453 to 0xDeposit may have been sent", "idempotencyKey k1", "getBalances", cause.localizedDescription]
      )
    ]

    for (error, fragments) in expectations {
      let description = try XCTUnwrap(error.errorDescription)
      XCTAssertTrue(description.hasPrefix("[Agg] "), description)
      for fragment in fragments {
        XCTAssertTrue(description.contains(fragment), "\"\(description)\" does not mention \"\(fragment)\"")
      }
    }
  }

  func test_depositErrorDescriptions_readInFull() {
    let usdc = AggSupportedChainToken(symbol: "USDC", address: "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359", decimals: 6)
    let usdcE = AggSupportedChainToken(symbol: "USDC.e", address: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", decimals: 6)
    let cause = URLError(.networkConnectionLost)

    let expectations: [(AggError, String)] = [
      (.missingRpcUrl(chainId: "eip155:8453"), "[Agg] No RPC URL is configured for eip155:8453; add it to rpcConfig or use another chain."),
      (
        .ambiguousDepositToken(chainId: "eip155:137", token: "usdc", candidates: [usdcE, usdc]),
        "[Agg] usdc names 2 tokens on eip155:137 (USDC.e \(usdcE.address), USDC \(usdc.address)); nothing was sent. Pass the address of the one to deposit."
      ),
      (
        .ambiguousDepositToken(chainId: "eip155:137", token: "USDC", candidates: [usdc, AggSupportedChainToken(symbol: "USDC", address: usdc.address, decimals: 18)]),
        "[Agg] Agg lists USDC on eip155:137 with conflicting decimals; nothing was sent."
      ),
      (
        .depositOutcomeUnknown(idempotencyKey: "k1", chainId: "eip155:8453", depositAddress: "0xDeposit", token: usdc, amount: "1.5", underlyingError: cause),
        "[Agg] The deposit of 1.5 USDC on eip155:8453 to 0xDeposit may have been sent; retry it only with idempotencyKey k1, which Portal never sends twice, or read getBalances(sync: true) before depositing again: \(cause.localizedDescription)"
      )
    ]

    for (error, expected) in expectations {
      XCTAssertEqual(error.errorDescription, expected)
    }
  }

  func test_errorDescriptions_withoutTheOptionalReasons_endCleanly() throws {
    let quote: AggQuote = try Self.decode(AggFixtures.quotePaper, ["quoteId": "q1", "status": "invalid_input", "warnings": NSNull()])
    let status: AggExecutionStatus = try Self.decode(AggFixtures.executionStatus, ["quoteId": "q1", "overallState": "failed", "errorReason": NSNull()])
    let preview: AggWithdrawalPreview = try Self.decode(AggFixtures.withdrawalPreview, ["pricingStatus": "unviable", "unviableReason": NSNull()])
    let withdrawal: AggWithdrawal = try Self.decode(AggFixtures.withdrawalStatus, ["withdrawalId": "w1", "status": "failed", "errorMessage": NSNull()])
    let request = AggWithdrawalRequest(tokenSymbol: .usdc, destinationChainId: "eip155:8453", amountRaw: "1")
    let cause = URLError(.timedOut)

    let expectations: [(AggError, String)] = [
      (.quoteNotTradable(quote: quote), "[Agg] Quote q1 is not tradable: status invalid_input"),
      (.orderFailed(status: status), "[Agg] Order q1 ended failed."),
      (.withdrawalNotViable(preview: preview), "[Agg] The withdrawal is unviable."),
      (.withdrawalFailed(withdrawal: withdrawal), "[Agg] Withdrawal w1 failed."),
      (
        .withdrawalOutcomeUnknown(request: request, withdrawal: nil, last: nil, underlyingError: cause),
        "[Agg] Withdrawal with requestId none may have been sent; read it before withdrawing again: \(cause.localizedDescription)"
      )
    ]

    for (error, expected) in expectations {
      XCTAssertEqual(error.errorDescription, expected)
    }
  }
}
