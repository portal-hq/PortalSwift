//
//  YieldXyzPerpsCodableTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import AnyCodable
@testable import PortalSwift
import XCTest

/// Decodes the payloads the Portal API returns (connect-api `src/libs/yield-xyz-perps/fixtures.ts`,
/// with networks translated to CAIP-2 as the client receives them) and checks the codecs that are
/// written by hand.
final class YieldXyzPerpsCodableTests: XCTestCase {
  private func decode<T: Decodable>(_: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(T.self, from: Data(json.utf8))
  }

  private func encodedObject<T: Encodable>(_ value: T) throws -> NSDictionary {
    let data = try JSONEncoder().encode(value)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? NSDictionary)
  }

  // MARK: - Providers and markets

  func test_provider_decodes() throws {
    let response = try decode(YieldXyzPerpsGetProvidersResponse.self, """
    {"data":[{"id":"hyperliquid","name":"Hyperliquid","network":"hyperliquid",
      "metadata":{"description":"Hyperliquid is a high-performance L1 optimized for perpetual futures trading.","externalLink":"https://hyperliquid.xyz","logoURI":"https://assets.stakek.it/providers/hyperliquid.svg"},
      "supportedActions":["open","close","updateLeverage","stopLoss","takeProfit","fund","withdraw","approveAgent"],
      "argumentSchemas":{"open":{"type":"object","properties":{"marketId":{"type":"string","label":"Market"},"side":{"type":"string","enum":["long","short"]}},"required":["marketId","side","size"],"additionalProperties":false}}}]}
    """)

    let provider = try XCTUnwrap(response.data.first)
    XCTAssertEqual(provider.id, "hyperliquid")
    XCTAssertEqual(provider.supportedActions.first, .open)
    XCTAssertEqual(provider.supportedActions.count, 8)
    XCTAssertEqual(provider.metadata.externalLink, "https://hyperliquid.xyz")
    let openSchema = try XCTUnwrap(provider.argumentSchemas["open"]?.value as? [String: Any])
    XCTAssertEqual(openSchema["required"] as? [String], ["marketId", "side", "size"])
  }

  func test_providerMetadata_toleratesNullAndMissingFields() throws {
    let provider = try decode(YieldXyzPerpsProvider.self, """
    {"id":"v","name":"V","network":"v","metadata":{"description":null},"supportedActions":[],"argumentSchemas":{}}
    """)

    XCTAssertNil(provider.metadata.description)
    XCTAssertNil(provider.metadata.externalLink)
    XCTAssertNil(provider.metadata.logoURI)
  }

  func test_market_decodes_withMissingNullishFields() throws {
    let market = try decode(YieldXyzPerpsMarket.self, """
    {"id":"hyperliquid-eth-usdc","providerId":"hyperliquid",
      "baseAsset":{"symbol":"ETH","name":"Ethereum","network":"hyperliquid","decimals":18},
      "quoteAsset":{"symbol":"USDC","name":"USD Coin","network":"hyperliquid","decimals":6,"address":"0xaf88d065e77c8cC2239327C5EDb3A432268e5831"},
      "leverageRange":[1,50],"supportedMarginModes":["isolated","cross"],"markPrice":3125.4,"oraclePrice":3125.1,
      "priceChange24h":-1.233,"priceChangePercent24h":-5.01,"volume24h":12500000,"openInterest":3400,
      "fundingRate":"0.00012","fundingRateIntervalHours":8,"minSize":10.22,
      "metadata":{"name":"ETH-USDC Perpetual","logoURI":null}}
    """)

    XCTAssertEqual(market.leverageRange, [1, 50])
    XCTAssertEqual(market.supportedMarginModes, [.isolated, .cross])
    XCTAssertNil(market.baseAsset.address)
    XCTAssertNil(market.makerFee)
    XCTAssertNil(market.takerFee)
    XCTAssertEqual(market.fundingRate, "0.00012")
    XCTAssertEqual(market.minSize, 10.22)
    XCTAssertNil(market.metadata.logoURI)
  }

  func test_candles_decode() throws {
    let candles = try decode(YieldXyzPerpsGetMarketCandlesResponse.self, """
    {"data":{"marketId":"hyperliquid-btc-usdc","interval":"1h","candles":[{"openTime":1704067200000,"closeTime":1704070799999,"open":"42150.5","high":"42500.0","low":"42000.0","close":"42350.25","volume":"1234.56","trades":482}]}}
    """).data

    XCTAssertEqual(candles.interval, .oneHour)
    XCTAssertEqual(candles.candles.first?.openTime, 1_704_067_200_000)
    XCTAssertEqual(candles.candles.first?.close, "42350.25")
    XCTAssertEqual(candles.candles.first?.trades, 482)
  }

  // MARK: - Account

  func test_positions_decode_withPendingActionArgs() throws {
    let positions = try decode(YieldXyzPerpsGetPositionsResponse.self, """
    {"data":[{"marketId":"hyperliquid-eth-usdc","side":"long","size":"0.215","entryPrice":4000,"markPrice":3975,"leverage":20,
      "marginMode":"isolated","margin":43,"unrealizedPnl":5.38,"funding":-1.24,"liquidationPrice":4200,
      "pendingActions":[{"type":"close","label":"Close Position","args":{"marketId":"hyperliquid-eth-usdc"}}]}]}
    """).data

    XCTAssertEqual(positions, [.stub()])
  }

  func test_order_decodes_withMissingNullishFields() throws {
    let order = try decode(YieldXyzPerpsOrder.self, """
    {"marketId":"hyperliquid-eth-usdc","side":"long","type":"limit","size":"0.5","limitPrice":3900,"reduceOnly":false,"createdAt":1733332000,
      "pendingActions":[{"type":"cancelOrder","label":"Cancel Order","args":{"orderId":"12345"}}]}
    """)

    XCTAssertEqual(order, .stub())
    XCTAssertNil(order.triggerPrice)
  }

  func test_order_decodesAFractionalCreatedAt() throws {
    let order = try decode(YieldXyzPerpsOrder.self, """
    {"marketId":"m","side":"short","type":"stop_loss","size":"1","triggerPrice":3600,"reduceOnly":true,"createdAt":1733332000.5,"pendingActions":[]}
    """)

    XCTAssertEqual(order.createdAt, 1_733_332_000.5)
    XCTAssertEqual(order.type, .stopLoss)
  }

  func test_balance_decodes() throws {
    let balance = try decode(YieldXyzPerpsGetBalancesResponse.self, """
    {"data":{"providerId":"hyperliquid","collateral":{"symbol":"USDC","name":"USD Coin","network":"hyperliquid","decimals":6,"address":"0xaf88d065e77c8cC2239327C5EDb3A432268e5831"},
      "accountValue":1280.44,"usedMargin":320.13,"availableBalance":960.31,"unrealizedPnl":12.8,"unifiedAccountMode":false}}
    """).data

    XCTAssertEqual(balance, .stub())
  }

  // MARK: - Actions

  private let actionJSON = """
  {"id":"550e8400-e29b-41d4-a716-446655440001","providerId":"hyperliquid","action":"open","status":"CREATED",
    "summary":{"type":"Open Position","orderType":"market","direction":"long","asset":"ETH","price":3500,"size":"0.215","leverage":20,
      "collateral":"43.00","fee":"0.0005","marginMode":"isolated","estimatedLiquidationPrice":4200},
    "signedMetadata":"01012b02010181d0010081d1040000000b24034152421547",
    "transactions":[
      {"id":"550e8400-e29b-41d4-a716-446655440000","network":"hyperliquid","chainId":"1337","type":"OPEN_POSITION","status":"CREATED",
        "address":"0x1234567890abcdef1234567890abcdef12345678",
        "args":{"marketId":"hyperliquid-eth-usdc","side":"long","size":"0.215","leverage":20,"marginMode":"isolated"},
        "signingFormat":"EIP712_TYPED_DATA",
        "signablePayload":{"domain":{"name":"Exchange","version":"1","chainId":1337},"primaryType":"Agent","message":{"source":"a","connectionId":"0xabc123"}},
        "rawPayload":"{\\"action\\":{\\"type\\":\\"order\\"},\\"nonce\\":1756207800000}",
        "explorerUrls":["https://app.hyperliquid.xyz/explorer/tx/0x8a3fb2c1d4e5f67890abcdef12345678"]},
      {"id":"550e8400-e29b-41d4-a716-446655440002","network":"eip155:42161","chainId":"42161","type":"FUND","status":"CREATED",
        "address":"0x1234567890abcdef1234567890abcdef12345678","signingFormat":"EVM_TRANSACTION","signablePayload":"0xdeadbeef","rawPayload":null,"explorerUrls":[]}
    ],
    "createdAt":"2026-08-26T10:30:00.000Z","completedAt":"2026-08-26T10:30:05.000Z"}
  """

  func test_action_decodes_withBothSigningFormats() throws {
    let action = try decode(YieldXyzPerpsAction.self, actionJSON)

    XCTAssertEqual(action.action, .open)
    XCTAssertEqual(action.status, .created)
    XCTAssertEqual(action.summary?.estimatedLiquidationPrice, 4200)
    XCTAssertEqual(action.summary?.collateral, "43.00")
    XCTAssertEqual(action.signedMetadata, AnyCodable("01012b02010181d0010081d1040000000b24034152421547"))
    XCTAssertEqual(action.completedAt, "2026-08-26T10:30:05.000Z")

    let order = action.transactions[0]
    XCTAssertEqual(order.chainId, "1337")
    XCTAssertEqual(order.signingFormat, .eip712TypedData)
    XCTAssertEqual(order.args?.leverage, 20)
    let typedData = try XCTUnwrap(order.signablePayload?.value as? [String: Any])
    XCTAssertEqual(typedData["primaryType"] as? String, "Agent")
    XCTAssertEqual(order.rawPayload?.value as? String, "{\"action\":{\"type\":\"order\"},\"nonce\":1756207800000}")

    let funding = action.transactions[1]
    XCTAssertEqual(funding.network, "eip155:42161")
    XCTAssertEqual(funding.signingFormat, .evmTransaction)
    XCTAssertEqual(funding.signablePayload?.value as? String, "0xdeadbeef")
    XCTAssertNil(funding.rawPayload)
    XCTAssertNil(funding.args)
  }

  func test_action_decodes_withNullSummaryAndPendingCompletion() throws {
    let action = try decode(YieldXyzPerpsAction.self, """
    {"id":"a","providerId":"hyperliquid","action":"approveAgent","status":"WAITING_FOR_NEXT","summary":null,"transactions":[],"createdAt":"2026-08-26T10:30:00.000Z","completedAt":null}
    """)

    XCTAssertNil(action.summary)
    XCTAssertNil(action.signedMetadata)
    XCTAssertNil(action.completedAt)
    XCTAssertEqual(action.status, .waitingForNext)
  }

  func test_fundActionSummary_decodesFundingFields() throws {
    let summary = try decode(YieldXyzPerpsActionSummary.self, """
    {"type":"Fund Account","method":"bridge2","amount":"100","fromToken":{"network":"eip155:42161","address":"0xaf88d065e77c8cC2239327C5EDb3A432268e5831"}}
    """)

    XCTAssertEqual(summary.method, "bridge2")
    XCTAssertEqual(summary.amount, "100")
    XCTAssertEqual(summary.fromToken, YieldXyzPerpsTokenIdentifier(network: "eip155:42161", address: YieldXyzPerpsFixtures.arbitrumUsdc))
  }

  func test_actionSummary_decodesEveryRuntimeField() throws {
    let summary = try decode(YieldXyzPerpsActionSummary.self, """
    {"type":"Close Position","assetId":1,"orderValue":860,"stopLoss":3600,"takeProfit":4400,"oldLiquidationPrice":4100,"oldStopLoss":3500,
      "oldTakeProfit":4500,"orderId":"1","orderIds":["1","2"],"cancelledOrderTypes":["tp","sl"],"agentAddress":"0x1","agentName":"my-app",
      "enabled":true,"closedPrice":3990.5,"pnl":"-12.45","margin":"43.00","entryPrice":4000,"exitPrice":3990.5}
    """)

    XCTAssertEqual(summary.assetId, 1)
    XCTAssertEqual(summary.cancelledOrderTypes, ["tp", "sl"])
    XCTAssertEqual(summary.margin, "43.00")
    XCTAssertEqual(summary.pnl, "-12.45")
    XCTAssertEqual(summary.enabled, true)
    XCTAssertEqual(summary.exitPrice, 3990.5)
  }

  func test_failedTransaction_decodesItsErrorAndAnArrayPayload() throws {
    let transaction = try decode(YieldXyzPerpsTransaction.self, """
    {"id":"t","network":"hyperliquid","chainId":"1337","type":"CLOSE_POSITION","status":"FAILED","address":"0x1",
      "signingFormat":null,"rawPayload":[1,"two",{"three":3}],"error":{"code":"ORDER_REJECTED","reason":"Insufficient margin"},"explorerUrls":[]}
    """)

    XCTAssertEqual(transaction.status, .failed)
    XCTAssertNil(transaction.signingFormat)
    XCTAssertNil(transaction.signablePayload)
    XCTAssertEqual(transaction.error?["code"], AnyCodable("ORDER_REJECTED"))
    XCTAssertEqual((transaction.rawPayload?.value as? [Any])?.count, 3)
  }

  func test_submitResult_decodes_withAndWithoutHash() throws {
    let filled = try decode(YieldXyzPerpsSubmitTransactionResponse.self, """
    {"data":{"transactionHash":"0x1234567890abcdef...","link":"https://app.hyperliquid.xyz/exchange","status":"CONFIRMED","details":{"orderStatus":"filled","fillPrice":3900}}}
    """).data
    XCTAssertEqual(filled.status, .confirmed)
    XCTAssertEqual(filled.details?["fillPrice"], AnyCodable(3900))

    let immediate = try decode(YieldXyzPerpsSubmitResult.self, """
    {"link":"https://app.hyperliquid.xyz/exchange","status":"FAILED","error":"Order rejected"}
    """)
    XCTAssertNil(immediate.transactionHash)
    XCTAssertEqual(immediate.status, .failed)
    XCTAssertEqual(immediate.error, "Order rejected")
  }

  // MARK: - History

  private let eventJSON = """
  {"id":"550e8400-e29b-41d4-a716-446655440010","eventType":"order_filled","providerId":"hyperliquid","occurredAt":"2026-04-23T07:52:05.187Z",
    "marketId":"hyperliquid-eth-usdc","perpActionId":"550e8400-e29b-41d4-a716-446655440001","providerOrderId":"394438950581",
    "explorerUrl":"https://app.hyperliquid.xyz/explorer/tx/0x8a3f",
    "order":{"orderId":"394438950581","marketId":"hyperliquid-eth-usdc","asset":"ETH","side":"buy","type":"market","originalSizeBase":"0.0063",
      "remainingSizeBase":"0.0","limitPrice":2395.2,"timeInForce":"ioc","reduceOnly":false,"isPositionLevel":false,"clientOrderId":null,
      "childOrderIds":[],"createdAt":"2026-04-23T07:52:05.187Z","closedPnl":"-12.45","fillPrice":2500.5}}
  """

  func test_event_decodes() throws {
    let event = try decode(YieldXyzPerpsEvent.self, eventJSON)

    XCTAssertEqual(event.eventType, .orderFilled)
    XCTAssertEqual(event.order.side, "buy")
    XCTAssertEqual(event.order.type, .market)
    XCTAssertEqual(event.order.timeInForce, "ioc")
    XCTAssertNil(event.order.clientOrderId)
    XCTAssertEqual(event.order.fillPrice, 2500.5)
    XCTAssertEqual(event.order.closedPnl, "-12.45")
  }

  func test_liquidationEvent_decodesNullIds() throws {
    let event = try decode(YieldXyzPerpsEvent.self, """
    {"id":"e","eventType":"liquidation","providerId":"hyperliquid","occurredAt":"2026-04-23T09:15:00.000Z","marketId":"hyperliquid-eth-usdc",
      "perpActionId":null,"providerOrderId":null,"explorerUrl":null,
      "order":{"orderId":"1","marketId":"hyperliquid-eth-usdc","asset":"ETH","side":"sell","type":"market","originalSizeBase":"1","remainingSizeBase":"0",
        "reduceOnly":true,"isPositionLevel":true,"clientOrderId":{"cloid":"0xabc"},"childOrderIds":["2"],"createdAt":"2026-04-23T09:15:00.000Z"}}
    """)

    XCTAssertEqual(event.eventType, .liquidation)
    XCTAssertNil(event.perpActionId)
    XCTAssertNil(event.providerOrderId)
    XCTAssertNil(event.explorerUrl)
    XCTAssertEqual((event.order.clientOrderId?.value as? [String: Any])?["cloid"] as? String, "0xabc")
    XCTAssertNil(event.order.limitPrice)
  }

  func test_eventOrder_decodesAStringClientOrderId() throws {
    let event = try decode(YieldXyzPerpsEvent.self, eventJSON.replacingOccurrences(of: "\"clientOrderId\":null", with: "\"clientOrderId\":\"cl-1\""))

    XCTAssertEqual(event.order.clientOrderId, AnyCodable("cl-1"))
  }

  func test_activity_decodesEventActionAndUnknownItems() throws {
    let page = try decode(YieldXyzPerpsGetActivityResponse.self, """
    {"data":{"total":3,"offset":0,"limit":100,"items":[{"type":"event","event":\(eventJSON)},{"type":"action","action":\(actionJSON)},{"type":"transfer","transfer":{}}]}}
    """).data

    XCTAssertEqual(page.total, 3)
    guard case let .event(event) = page.items[0] else {
      return XCTFail("Expected an event item.")
    }
    XCTAssertEqual(event.eventType, .orderFilled)
    guard case let .action(action) = page.items[1] else {
      return XCTFail("Expected an action item.")
    }
    XCTAssertEqual(action.transactions.count, 2)
    XCTAssertEqual(page.items[2], .unknown(type: "transfer"))
    XCTAssertEqual(page.items.map(\.type), ["event", "action", "transfer"])
  }

  func test_activityItem_roundTrips() throws {
    let item = YieldXyzPerpsActivityItem.event(.stub())

    let decoded = try JSONDecoder().decode(YieldXyzPerpsActivityItem.self, from: JSONEncoder().encode(item))

    XCTAssertEqual(decoded, item)
  }

  // MARK: - Health

  func test_health_decodes() throws {
    let health = try decode(YieldXyzPerpsGetHealthResponse.self, #"{"data":{"status":"OK","timestamp":"2026-08-26T10:30:00.000Z"}}"#).data
    XCTAssertEqual(health.status, .ok)

    let providers = try decode(YieldXyzPerpsGetProvidersHealthResponse.self, """
    {"data":{"generatedAt":"2026-08-26T10:30:00.000Z","providers":[{"providerId":"hyperliquid","state":"degraded","message":"Slow fills","setAt":null}]}}
    """).data
    XCTAssertEqual(providers.providers.first?.state, .degraded)
    XCTAssertEqual(providers.providers.first?.message, "Slow fills")
    XCTAssertNil(providers.providers.first?.setAt)
  }

  // MARK: - Envelope

  func test_envelope_ignoresAKeyItDoesNotModel() throws {
    let response = try decode(YieldXyzPerpsGetHealthResponse.self, #"{"data":{"status":"FAIL","timestamp":"t"},"metadata":{"requestId":"r-1"}}"#)

    XCTAssertEqual(response.data.status, .fail)
  }

  // MARK: - Open values

  func test_openValue_keepsAnUnknownValue_andEncodesItVerbatim() throws {
    let pendingAction = try decode(YieldXyzPerpsPendingAction.self, #"{"type":"closeAll","label":"Close All","args":{}}"#)

    XCTAssertEqual(pendingAction.type.rawValue, "closeAll")
    XCTAssertNotEqual(pendingAction.type, .close)
    XCTAssertEqual(try encodedObject(pendingAction)["type"] as? String, "closeAll")
  }

  func test_openValue_encodesAsABareString() throws {
    let data = try JSONEncoder().encode([YieldXyzPerpsActionStatus.waitingForNext])

    XCTAssertEqual(String(data: data, encoding: .utf8), #"["WAITING_FOR_NEXT"]"#)
  }

  func test_openValue_supportsSwitchAndStringLiterals() {
    let status: YieldXyzPerpsActionStatus = "SUCCESS"

    switch status {
    case .success:
      break
    default:
      XCTFail("Expected .success to match.")
    }
    XCTAssertEqual(status.description, "SUCCESS")
  }

  // MARK: - Loose objects

  func test_actionArgs_keepUnknownKeys_andSendThemBack() throws {
    let args = try decode(YieldXyzPerpsActionArgs.self, """
    {"marketId":"m","leverage":10,"fromToken":{"network":"eip155:42161","address":"0x1","symbol":"USDC"},"tif":"Gtc","nested":{"a":[1,2]}}
    """)

    XCTAssertEqual(args.marketId, "m")
    XCTAssertEqual(args.leverage, 10)
    XCTAssertEqual(args.fromToken?.additionalFields["symbol"], AnyCodable("USDC"))
    XCTAssertEqual(args.additionalFields["tif"], AnyCodable("Gtc"))
    XCTAssertEqual(Set(args.additionalFields.keys), ["tif", "nested"])

    let encoded = try encodedObject(args)
    XCTAssertEqual(encoded, [
      "marketId": "m",
      "leverage": 10,
      "fromToken": ["network": "eip155:42161", "address": "0x1", "symbol": "USDC"],
      "tif": "Gtc",
      "nested": ["a": [1, 2]]
    ])
  }

  func test_actionArgs_omitNilFields() throws {
    XCTAssertEqual(try encodedObject(YieldXyzPerpsActionArgs()), [:])
    XCTAssertEqual(try encodedObject(YieldXyzPerpsActionArgs(side: .short, validUntil: 1_767_225_600, skipApproval: false)), [
      "side": "short",
      "validUntil": 1_767_225_600,
      "skipApproval": false
    ])
  }

  func test_actionArgs_ignoreAnAdditionalKeyNamedLikeATypedField() throws {
    let args = YieldXyzPerpsActionArgs(marketId: "typed", additionalFields: ["marketId": AnyCodable("extra"), "size": AnyCodable("9")])

    XCTAssertEqual(try encodedObject(args), ["marketId": "typed"])
  }

  func test_tokenIdentifier_requiresNetwork() {
    XCTAssertThrowsError(try decode(YieldXyzPerpsTokenIdentifier.self, #"{"address":"0x1"}"#))
  }
}
