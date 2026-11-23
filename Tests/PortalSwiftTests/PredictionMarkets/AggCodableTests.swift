//
//  AggCodableTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

@testable import PortalSwift
import XCTest

final class AggCodableTests: XCTestCase {
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()

  private func decode<T: Decodable>(_: T.Type, _ json: String, file: StaticString = #filePath, line: UInt = #line) throws -> T {
    do {
      return try decoder.decode(T.self, from: Data(json.utf8))
    } catch {
      XCTFail("\(T.self) did not decode: \(error)", file: file, line: line)
      throw error
    }
  }

  /// The JSON object `value` encodes to.
  private func encodedObject<T: Encodable>(_ value: T) throws -> NSDictionary {
    try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(value)) as? NSDictionary)
  }

  // MARK: - Every captured response decodes

  /// `decode` records each failure with its type and `try?` carries on, so one run names every type
  /// that no longer decodes.
  func test_everyCapturedResponse_decodesIntoItsType() {
    _ = try? decode(AggPage<AggActivityItem>.self, AggFixtures.activity)
    _ = try? decode(AggAppConfig.self, AggFixtures.appConfig)
    _ = try? decode(AggBalances.self, AggFixtures.balances)
    _ = try? decode(AggBalances.self, AggFixtures.balancesPaper)
    _ = try? decode(AggCancelResult.self, AggFixtures.cancel)
    _ = try? decode(AggPage<AggCategory>.self, AggFixtures.categories)
    _ = try? decode(AggChartBars.self, AggFixtures.chartBars)
    _ = try? decode(AggChartHistoryManifest.self, AggFixtures.chartHistoryManifest)
    _ = try? decode(AggDepositAddresses.self, AggFixtures.depositAddresses)
    _ = try? decode(AggExecutionStatus.self, AggFixtures.executionStatus)
    _ = try? decode(AggExecutionStatus.self, AggFixtures.executionStatusPaper)
    _ = try? decode(AggFill.self, AggFixtures.fill)
    _ = try? decode(AggFill.self, AggFixtures.fillPaper)
    _ = try? decode(AggLimitOrder.self, AggFixtures.limitOrderPlaced)
    _ = try? decode(AggMidpoints.self, AggFixtures.midpoints)
    _ = try? decode(AggOutcomeOrderbook.self, AggFixtures.orderbookOutcome)
    _ = try? decode(AggOutcomeOrderbook.self, AggFixtures.orderbookOutcomeDepth)
    _ = try? decode(AggOrderbooks.self, AggFixtures.orderbooks)
    _ = try? decode(AggPage<AggOrder>.self, AggFixtures.orders)
    _ = try? decode(AggPage<AggOrder>.self, AggFixtures.ordersWithFees)
    _ = try? decode(AggPage<AggPosition>.self, AggFixtures.positionsPaper)
    _ = try? decode(AggPage<AggPosition>.self, AggFixtures.positionsResolved)
    _ = try? decode(AggQuote.self, AggFixtures.quote)
    _ = try? decode(AggQuote.self, AggFixtures.quoteCompareVenues)
    _ = try? decode(AggQuote.self, AggFixtures.quoteNoOrderbooks)
    _ = try? decode(AggQuote.self, AggFixtures.quotePaper)
    _ = try? decode(AggQuote.self, AggFixtures.quotePaperSell)
    _ = try? decode(AggRedeemResult.self, AggFixtures.redeem)
    _ = try? decode(AggSearchResults.self, AggFixtures.searchEvents)
    _ = try? decode(AggSearchResults.self, AggFixtures.searchMarkets)
    _ = try? decode(AggUserProfile.self, AggFixtures.usersMe)
    _ = try? decode(AggVenueEventBootstrap.self, AggFixtures.venueEventBootstrap)
    _ = try? decode(AggVenueEvent.self, AggFixtures.venueEventDetail)
    _ = try? decode(AggPage<AggVenueEvent>.self, AggFixtures.venueEvents)
    _ = try? decode(AggPage<AggVenueEvent>.self, AggFixtures.venueEventsResolved)
    _ = try? decode(AggVenueGeoPolicy.self, AggFixtures.venueGeoPolicy)
    _ = try? decode(AggPage<AggVenueMarket>.self, AggFixtures.venueMarkets)
    _ = try? decode(AggWithdrawableQuote.self, AggFixtures.withdrawableQuote)
    _ = try? decode(AggWithdrawalPreview.self, AggFixtures.withdrawalPreview)
    _ = try? decode(AggWithdrawal.self, AggFixtures.withdrawalStatus)
    _ = try? decode(AggWithdrawal.self, AggFixtures.withdrawalSubmit)
  }

  func test_capturedResponses_roundTripUnchanged() throws {
    try assertRoundTrips(AggQuote.self, AggFixtures.quote)
    try assertRoundTrips(AggExecutionStatus.self, AggFixtures.executionStatus)
    try assertRoundTrips(AggPage<AggActivityItem>.self, AggFixtures.activity)
    try assertRoundTrips(AggSearchResults.self, AggFixtures.searchEvents)
    try assertRoundTrips(AggDepositAddresses.self, AggFixtures.depositAddresses)
    try assertRoundTrips(AggWithdrawal.self, AggFixtures.withdrawalStatus)
  }

  private func assertRoundTrips<T: Codable & Equatable>(_: T.Type, _ json: String, file: StaticString = #filePath, line: UInt = #line) throws {
    let value = try decode(T.self, json, file: file, line: line)
    XCTAssertEqual(try decoder.decode(T.self, from: encoder.encode(value)), value, file: file, line: line)
  }

  // MARK: - Fields the helpers rely on

  func test_executionStatus_readsStateStepsAndOrders() throws {
    let status = try decode(AggExecutionStatus.self, AggFixtures.executionStatus)

    XCTAssertTrue(status.terminal)
    XCTAssertFalse(status.steps.isEmpty)
    XCTAssertFalse(status.orders.isEmpty)
    XCTAssertFalse(status.overallState.rawValue.isEmpty)
  }

  func test_positions_carryTheVenueOutcomeIdsRedemptionTakes() throws {
    let page = try decode(AggPage<AggPosition>.self, AggFixtures.positionsResolved)

    let ids = page.data.flatMap { $0.venueMarket.venueMarketOutcomes.flatMap { $0.venueBreakdown.compactMap(\.venueMarketOutcomeId) } }
    XCTAssertFalse(ids.isEmpty)
  }

  func test_withdrawalStatus_carriesTheTransactionHashInItsLegs() throws {
    let withdrawal = try decode(AggWithdrawal.self, AggFixtures.withdrawalStatus)

    XCTAssertTrue(withdrawal.legs.first?.txHash?.hasPrefix("0x") == true)
  }

  func test_depositAddresses_readyCarriesTheAddressesAndTokens() throws {
    let addresses = try decode(AggDepositAddresses.self, AggFixtures.depositAddresses)

    guard case let .ready(ready) = addresses else {
      return XCTFail("Expected ready deposit addresses, got \(addresses)")
    }
    XCTAssertFalse(ready.evmAddress.isEmpty)
    XCTAssertFalse(ready.supportedChains.flatMap(\.tokens).isEmpty)
  }

  // MARK: - Unions

  func test_linkStatus_decodesBothVariantsAndRoundTrips() throws {
    let linked = try decode(
      AggLinkStatus.self,
      #"{"linked":true,"aggUserId":"u1","linkedAddress":"0xabc","linkedChainId":"eip155:137","linkedAt":"2026-10-29T13:25:40.000Z"}"#
    )
    XCTAssertEqual(linked, .linked(.init(aggUserId: "u1", linkedAddress: "0xabc", linkedChainId: "eip155:137", linkedAt: "2026-10-29T13:25:40.000Z")))
    XCTAssertTrue(linked.isLinked)
    XCTAssertEqual(try encodedObject(linked)["linked"] as? Bool, true)

    let notLinked = try decode(AggLinkStatus.self, #"{"linked":false}"#)
    XCTAssertEqual(notLinked, .notLinked)
    XCTAssertEqual(try encodedObject(notLinked), ["linked": false])
  }

  func test_depositAddresses_decodesAndEncodesNotReady() throws {
    XCTAssertEqual(try decode(AggDepositAddresses.self, #"{"ready":false}"#), .notReady)
    XCTAssertEqual(try encodedObject(AggDepositAddresses.notReady), ["ready": false])
  }

  func test_activityItem_keepsAnUnknownTypeInsteadOfFailingThePage() throws {
    let page = try decode(
      AggPage<AggActivityItem>.self,
      #"{"data":[{"type":"airdrop","id":"a1"}],"nextCursor":null,"hasMore":false}"#
    )

    XCTAssertEqual(page.data, [.unknown(type: "airdrop")])
    XCTAssertEqual(try encodedObject(page.data[0]), ["type": "airdrop"])
  }

  func test_activityItem_decodesUserOpFromItsWireName() throws {
    let item = try decode(
      AggActivityItem.self,
      #"{"type":"user_op","id":"op1","createdAt":"t","updatedAt":"t","status":"confirmed","callsId":"c1","chainId":"eip155:8453","walletAddress":"0xabc"}"#
    )

    guard case let .userOp(userOp) = item else {
      return XCTFail("Expected a user operation, got \(item)")
    }
    XCTAssertEqual(userOp.callsId, "c1")
    XCTAssertEqual(item.type, "user_op")
  }

  func test_searchResults_rejectsATypeTheRequestCouldNotHaveAskedFor() {
    XCTAssertThrowsError(try decoder.decode(AggSearchResults.self, from: Data(#"{"type":"series","data":[],"hasMore":false}"#.utf8)))
  }

  // MARK: - Open values

  func test_openValues_keepAValueThisSdkDoesNotKnow() throws {
    let state = try decode(AggExecutionState.self, #""settling""#)

    XCTAssertEqual(state.rawValue, "settling")
    XCTAssertEqual(try String(data: encoder.encode(state), encoding: .utf8), #""settling""#)
  }

  func test_openValues_matchTheWireNames() {
    XCTAssertEqual(AggExecutionState.partiallyFilled.rawValue, "partially_filled")
    XCTAssertEqual(AggOrderStatus.partialFill.rawValue, "partial_fill")
    XCTAssertEqual(AggOrderStatus.pendingBridge.rawValue, "pending_bridge")
    XCTAssertEqual(AggQuoteStatus.noBidsAboveMinPrice.rawValue, "no_bids_above_min_price")
    XCTAssertEqual(AggTokenSymbol.usdcE.rawValue, "USDC.e")
    XCTAssertEqual(AggChartResolution.oneDay.rawValue, "1D")
    XCTAssertEqual(AggActivityType.userOp.rawValue, "user_op")
  }

  func test_openValues_matchFromALiteralAndPrintTheirRawValue() {
    let status: AggOrderStatus = "filled"

    switch status {
    case .filled:
      break
    default:
      XCTFail("Expected .filled to match.")
    }
    XCTAssertEqual(status.description, "filled")
  }

  // MARK: - Requests

  func test_quoteRequest_encodesItsFieldsAndLeavesOutUnsetOnes() throws {
    let request = AggQuoteRequest(outcomeId: "o1", side: .buy, amount: "1", slippageBps: 100, venues: [.polymarket], mode: .paper)

    XCTAssertEqual(try encodedObject(request), [
      "outcomeId": "o1",
      "side": "buy",
      "amount": "1",
      "slippageBps": 100,
      "venues": ["polymarket"],
      "mode": "paper"
    ])
    XCTAssertEqual(try encodedObject(AggQuoteRequest(outcomeId: "o1", side: .sell, shares: "2")), [
      "outcomeId": "o1",
      "side": "sell",
      "shares": "2"
    ])
  }

  func test_limitOrderRequest_encodesTimeInForceAsTheApiSpellsIt() throws {
    let request = AggLimitOrderRequest(
      venue: .polymarket,
      venueMarketOutcomeId: "o1",
      side: .buy,
      limitPriceRaw: "200000",
      sizeRaw: "5000000",
      timeInForce: .gtc
    )

    XCTAssertEqual(try encodedObject(request)["timeInForce"] as? String, "GTC")
  }
}
