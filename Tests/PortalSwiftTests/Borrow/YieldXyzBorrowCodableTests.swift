//
//  YieldXyzBorrowCodableTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import AnyCodable
@testable import PortalSwift
import XCTest

/// Decodes the connect-api fixtures (`src/libs/yield-xyz-borrow/fixtures.ts`) as the Portal API
/// returns them: with vendor network slugs translated to CAIP-2 and the vendor's `chainId` dropped.
final class YieldXyzBorrowCodableTests: XCTestCase {
  private let address = "0x742d35Cc6634C0532925a3b844Bc9e7595f8fB28"

  private func decode<T: Decodable>(_: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(T.self, from: Data(json.utf8))
  }

  /// The JSON object `value` encodes to.
  private func encodedObject<T: Encodable>(_ value: T) throws -> NSDictionary {
    let data = try JSONEncoder().encode(value)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? NSDictionary)
  }

  // MARK: - Health and integrations

  func test_health_decodes() throws {
    let response = try decode(YieldXyzBorrowGetHealthResponse.self, #"{"data":{"status":"OK","timestamp":"2026-08-26T10:30:00.000Z"}}"#)

    XCTAssertEqual(response.data, YieldXyzBorrowHealthStatus(status: .ok, timestamp: "2026-08-26T10:30:00.000Z"))
  }

  func test_integrations_decode_withTheActionSchemaPassedThrough() throws {
    let response = try decode(YieldXyzBorrowGetIntegrationsResponse.self, """
    {"data":[{"id":"aave-borrow","providerId":"aave","name":"Aave V3","networks":["eip155:1","eip155:137","eip155:42161","starknet"],
    "metadata":{"description":"Aave is a decentralized non-custodial liquidity protocol.","externalLink":"https://aave.com","logoURI":"https://assets.stakek.it/protocols/aave.svg"},
    "actions":[{"id":"supply","label":"Supply Collateral","schema":{"type":"object","properties":{"amount":{"type":"string","label":"Amount"}},"required":["amount"]}}]}]}
    """)

    let integration = try XCTUnwrap(response.data.first)
    XCTAssertEqual(integration.networks, ["eip155:1", "eip155:137", "eip155:42161", "starknet"])
    XCTAssertEqual(integration.actions.first?.id, .supply)
    XCTAssertEqual(integration.actions.first?.schema["required"], ["amount"])
    XCTAssertEqual(integration.actions.first?.schema["properties"], ["amount": ["type": "string", "label": "Amount"]])
  }

  // MARK: - Markets

  private let marketJSON = """
  {"id":"aave-v3-ethereum-usdc","integrationId":"aave-borrow","network":"eip155:1","type":"pool","poolAddress":"0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2",
  "loanToken":{"address":"0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48","symbol":"USDC","name":"USD Coin","decimals":6,"logoURI":"https://assets.stakek.it/tokens/usdc.svg"},
  "collateralTokens":[{"token":{"address":"0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2","symbol":"WETH","name":"Wrapped Ether","decimals":18},"priceUsd":"2800.00","maxLtv":"0.80","liquidationThreshold":"0.825","liquidationPenalty":"0.05","supplyRate":"0.02"}],
  "borrowRate":"0.0567","totalSupply":"1234567.89","totalSupplyRaw":"1234567890000000","totalBorrow":"987654.321","totalBorrowRaw":"987654321000000",
  "availableLiquidity":"246913.569","availableLiquidityRaw":"246913569000000","utilizationRate":"0.80","loanTokenPriceUsd":"1.00","isBorrowEnabled":true,
  "supplyCollateralFeeBps":"50","feeWrapperAddress":null,"originationFeeBps":"100","originationFeeWrapperAddress":null,"blueBundleOriginationFeeBps":null,"minLoan":"0.01"}
  """

  func test_marketsPage_decodes_withTheNullableFieldsSentAsNull() throws {
    let response = try decode(YieldXyzBorrowGetMarketsResponse.self, #"{"data":{"total":1,"offset":0,"limit":25,"items":[\#(marketJSON)]}}"#)

    XCTAssertEqual(response.data.total, 1)
    XCTAssertEqual(response.data.limit, 25)
    let market = try XCTUnwrap(response.data.items.first)
    XCTAssertEqual(market.type, .pool)
    XCTAssertEqual(market.network, "eip155:1")
    XCTAssertEqual(market.loanToken.decimals, 6)
    XCTAssertEqual(market.collateralTokens.first?.token.symbol, "WETH")
    XCTAssertNil(market.collateralTokens.first?.token.logoURI)
    XCTAssertNil(market.feeWrapperAddress)
    XCTAssertNil(market.originationFeeWrapperAddress)
    XCTAssertNil(market.blueBundleOriginationFeeBps)
    XCTAssertEqual(market.minLoan, "0.01")
    XCTAssertEqual(market.supplyCollateralFeeBps, "50")
    XCTAssertEqual(market.originationFeeBps, "100")
    XCTAssertEqual(market.availableLiquidityRaw, "246913569000000")
  }

  func test_market_requiresTheAlwaysSentFields() {
    // A required field the Portal API stopped sending fails decoding instead of defaulting.
    let withoutDecimals = marketJSON.replacingOccurrences(of: #""decimals":6,"#, with: "")

    XCTAssertThrowsError(try decode(YieldXyzBorrowMarket.self, withoutDecimals))
  }

  func test_token_decodesANativeTokenWithoutAddress() throws {
    let token = try decode(YieldXyzBorrowToken.self, #"{"address":null,"symbol":"MON","name":"Monad","decimals":18}"#)

    XCTAssertNil(token.address)
    XCTAssertNil(token.logoURI)
  }

  // MARK: - Positions

  func test_position_decodes_withSupplyAndDebtBalances() throws {
    let response = try decode(YieldXyzBorrowGetPositionsResponse.self, """
    {"data":{"address":"\(address)","integrationId":"aave-borrow","network":"eip155:1","totalSuppliedUsd":"5000.00","totalCollateralUsd":"4200.00",
    "totalBorrowedUsd":"2000.00","netWorthUsd":"3000.00","healthFactor":"1.85","currentLtv":"0.55","availableToBorrowUsd":"1500.00","netApy":"2.34",
    "supplyBalances":[{"marketId":"aave-v3-ethereum-usdc","tokenAddress":"0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48","tokenSymbol":"USDC","balance":"1000.00",
    "balanceRaw":"1000000000","balanceUsd":"1000.00","apy":"3.45","isCollateral":true,
    "positionState":{"currentLtv":"0.1980","liquidationThreshold":"0.8600","healthFactor":"4.3430","availableToBorrowUsd":"2.01"},
    "pendingActions":[{"type":"withdraw","label":"Withdraw USDC","args":{"marketId":"aave-v3-ethereum-usdc","amount":"1000.00"}}]}],
    "debtBalances":[{"marketId":"aave-v3-ethereum-weth","tokenAddress":"0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2","tokenSymbol":"WETH","balance":"0.5",
    "balanceRaw":"500000000000000000","balanceUsd":"1500.00","apy":"5.67","pendingActions":[]}]}}
    """)

    let position = response.data
    XCTAssertEqual(position.healthFactor, "1.85")
    XCTAssertEqual(position.availableToBorrowUsd, "1500.00")
    let supply = try XCTUnwrap(position.supplyBalances.first)
    XCTAssertTrue(supply.isCollateral)
    XCTAssertEqual(supply.positionState?.healthFactor, "4.3430")
    XCTAssertEqual(supply.pendingActions.first?.type, .withdraw)
    XCTAssertEqual(supply.pendingActions.first?.args, YieldXyzBorrowActionArguments(marketId: "aave-v3-ethereum-usdc", amount: "1000.00"))
    XCTAssertEqual(position.debtBalances.first?.balanceRaw, "500000000000000000")
    XCTAssertEqual(position.debtBalances.first?.pendingActions, [])
  }

  func test_position_decodesUnknownHealthAsNil() throws {
    let position = try decode(YieldXyzBorrowPosition.self, """
    {"address":"\(address)","integrationId":"aave-borrow","network":"eip155:1","totalSuppliedUsd":"0","totalCollateralUsd":"0","totalBorrowedUsd":"0",
    "netWorthUsd":"0","healthFactor":null,"currentLtv":"0","availableToBorrowUsd":null,"netApy":"0","supplyBalances":[],"debtBalances":[]}
    """)

    XCTAssertNil(position.healthFactor)
    XCTAssertNil(position.availableToBorrowUsd)
  }

  func test_pendingActionArgs_reEncodeAsCreateActionArgs() throws {
    let pending = try decode(YieldXyzBorrowPendingAction.self, #"{"type":"repay","label":"Repay all","args":{"marketId":"m-1","repayAll":true}}"#)

    let params = YieldXyzBorrowCreateActionParams(integrationId: "aave-borrow", action: pending.type, address: address, args: pending.args)

    XCTAssertEqual(try encodedObject(params), [
      "integrationId": "aave-borrow",
      "action": "repay",
      "address": address,
      "args": ["marketId": "m-1", "repayAll": true]
    ])
  }

  // MARK: - Liquidations

  func test_liquidationsPage_decodes() throws {
    let response = try decode(YieldXyzBorrowGetLiquidationsResponse.self, """
    {"data":{"total":1,"offset":0,"limit":25,"items":[{"id":"liq_0b3f","integrationId":"morpho-blue-borrow","network":"eip155:8453","address":"\(address)",
    "marketId":"morpho-blue-borrow-base-cbbtc-usdc-86","type":"partial","realizedBadDebt":false,"occurredAt":"2026-05-21T14:08:12.000Z","blockNumber":22118447,
    "transactionHash":"0x8a3f","transactionLink":"https://basescan.org/tx/0x8a3f","liquidator":"0x1111111111111111111111111111111111111111",
    "repaidDebt":{"tokenAddress":"0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48","tokenSymbol":"USDC","amount":"1500.000000","amountRaw":"1500000000","amountUsd":"1500.00","shares":"1487123456789012345678"},
    "seizedCollateral":{"tokenAddress":"0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf","tokenSymbol":"cbBTC","amount":"0.02356500","amountRaw":"2356500","amountUsd":"1567.34"},
    "badDebt":{"amountRaw":"0","amount":"0","amountUsd":"0.00","shares":"0"},"lif":"1.0449"}]}}
    """)

    let liquidation = try XCTUnwrap(response.data.items.first)
    XCTAssertEqual(liquidation.type, .partial)
    XCTAssertEqual(liquidation.blockNumber, 22_118_447)
    XCTAssertEqual(liquidation.repaidDebt.shares, "1487123456789012345678")
    XCTAssertEqual(liquidation.seizedCollateral.amountUsd, "1567.34")
    XCTAssertEqual(liquidation.badDebt.amountUsd, "0.00")
    XCTAssertEqual(liquidation.lif, "1.0449")
  }

  func test_liquidation_decodesAnUnknownTypeAndAmountUsdAsNil() throws {
    let liquidation = try decode(YieldXyzBorrowLiquidation.self, """
    {"id":"liq-2","integrationId":"morpho-blue-borrow","network":"eip155:1","address":"\(address)","marketId":"m","type":null,"realizedBadDebt":true,
    "occurredAt":"2026-05-21T14:08:12.000Z","blockNumber":9007199254740991,"transactionHash":"0x1","transactionLink":"https://etherscan.io/tx/0x1","liquidator":"0x2",
    "repaidDebt":{"tokenAddress":"0x3","tokenSymbol":"USDC","amount":"1","amountRaw":"1","amountUsd":null,"shares":"1"},
    "seizedCollateral":{"tokenAddress":"0x4","tokenSymbol":"WETH","amount":"1","amountRaw":"1","amountUsd":null},
    "badDebt":{"amountRaw":"5","amount":"5","amountUsd":null,"shares":"5"},"lif":"1.05"}
    """)

    XCTAssertNil(liquidation.type)
    XCTAssertTrue(liquidation.realizedBadDebt)
    XCTAssertEqual(liquidation.blockNumber, 9_007_199_254_740_991)
    XCTAssertNil(liquidation.repaidDebt.amountUsd)
    XCTAssertNil(liquidation.seizedCollateral.amountUsd)
    XCTAssertNil(liquidation.badDebt.amountUsd)
  }

  // MARK: - Actions

  private let transactionJSON = #"""
  {"id":"550e8400-e29b-41d4-a716-446655440000","network":"eip155:1","type":"SUPPLY","status":"CREATED","address":"0x742d35Cc6634C0532925a3b844Bc9e7595f8fB28",
  "signingFormat":"EVM_TRANSACTION","signablePayload":"{\"from\":\"0x742d35Cc6634C0532925a3b844Bc9e7595f8fB28\",\"gasLimit\":\"350000\",\"to\":\"0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2\"}"}
  """#

  func test_action_decodes() throws {
    let response = try decode(YieldXyzBorrowActionResponse.self, """
    {"data":{"id":"550e8400-e29b-41d4-a716-446655440001","integrationId":"aave-borrow","action":"supply","address":"\(address)","status":"CREATED",
    "transactions":[\(transactionJSON)],"hasNextStep":false,"currentStep":1,"totalSteps":1,"rawArguments":{"marketId":"aave-v3-ethereum-usdc","amount":"1.5"},
    "metadata":{"currentHealthFactor":"1.85","predictedHealthFactor":"1.42","currentLtv":"0.55","predictedLtv":"0.72","liquidationThreshold":"0.85",
    "predictedTotalSupplyUsd":"10000.00","predictedTotalDebtUsd":"7200.00"},"createdAt":"2026-08-26T10:30:00.000Z"}}
    """)

    let action = response.data
    XCTAssertEqual(action.action, .supply)
    XCTAssertEqual(action.status, .created)
    XCTAssertFalse(action.hasNextStep)
    XCTAssertEqual(action.currentStep, 1)
    XCTAssertEqual(action.totalSteps, 1)
    XCTAssertEqual(action.rawArguments, YieldXyzBorrowActionArguments(marketId: "aave-v3-ethereum-usdc", amount: "1.5"))
    XCTAssertEqual(action.metadata?.predictedHealthFactor, "1.42")
    XCTAssertNil(action.metadata?.originationFeeBps)
    let transaction = try XCTUnwrap(action.transactions.first)
    XCTAssertEqual(transaction.network, "eip155:1")
    XCTAssertEqual(transaction.type, .supply)
    XCTAssertEqual(transaction.signingFormat, .evmTransaction)
    XCTAssertEqual(
      transaction.signablePayload?.value as? String,
      #"{"from":"0x742d35Cc6634C0532925a3b844Bc9e7595f8fB28","gasLimit":"350000","to":"0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2"}"#
    )
  }

  func test_wrapAction_decodes_withUnknownHealthFactors() throws {
    let wrapPayload = #"{\"from\":\"0x742d35Cc6634C0532925a3b844Bc9e7595f8fB28\",\"gasLimit\":\"51221\",\"to\":\"0x3bd359C1119dA7Da1D913D1C4D2B7c461115433A\",\"data\":\"0xd0e30db0\",\"value\":\"5000000000000000000\"}"#
    let action = try decode(YieldXyzBorrowAction.self, """
    {"id":"act-wrap","integrationId":"morpho-blue-borrow","action":"supply","address":"\(address)","status":"CREATED",
    "transactions":[{"id":"t1","network":"eip155:143","type":"WRAP","status":"CREATED","address":"\(address)","signingFormat":"EVM_TRANSACTION","signablePayload":"\(wrapPayload)"},
    {"id":"t2","network":"eip155:143","type":"APPROVAL","status":"CREATED","address":"\(address)","signingFormat":"EVM_TRANSACTION","signablePayload":null},
    {"id":"t3","network":"eip155:143","type":"SUPPLY","status":"CREATED","address":"\(address)"}],
    "hasNextStep":false,"currentStep":1,"totalSteps":1,"rawArguments":null,
    "metadata":{"currentHealthFactor":null,"predictedHealthFactor":null,"currentLtv":"0.55","predictedLtv":"0.72","liquidationThreshold":"0.85",
    "predictedTotalSupplyUsd":"10000.00","predictedTotalDebtUsd":"7200.00","originationFeeBps":25,"feeBps":12.5,"feeAmount":"0.1"},
    "createdAt":"2026-08-26T10:30:00.000Z"}
    """)

    XCTAssertEqual(action.transactions.map(\.type), [.wrap, .approval, .supply])
    XCTAssertEqual(action.transactions.map(\.network), ["eip155:143", "eip155:143", "eip155:143"])
    XCTAssertNil(action.transactions[1].signablePayload)
    XCTAssertNil(action.transactions[2].signingFormat)
    XCTAssertNil(action.rawArguments)
    XCTAssertNil(action.metadata?.currentHealthFactor)
    XCTAssertNil(action.metadata?.predictedHealthFactor)
    XCTAssertEqual(action.metadata?.originationFeeBps, 25)
    XCTAssertEqual(action.metadata?.feeBps, 12.5)
    XCTAssertEqual(action.metadata?.feeAmount, "0.1")

    // The WRAP payload keeps its `value`: it is what wraps the native token.
    let request = try YieldXyzEvmTransactionParams.parse(action.transactions[0].signablePayload, defaultFrom: nil).get()
    XCTAssertEqual(YieldXyzEvmTransactionParams.toSendTransactionParam(request).value, "0x4563918244f40000")
  }

  func test_transaction_decodesAnObjectPayload() throws {
    let transaction = try decode(YieldXyzBorrowTransaction.self, """
    {"id":"t","network":"eip155:8453","type":"APPROVAL","status":"CREATED","address":"\(address)","signingFormat":"EVM_TRANSACTION",
    "signablePayload":{"from":"\(address)","to":"0x1","gasLimit":56240}}
    """)

    let payload = try XCTUnwrap(transaction.signablePayload?.value as? [String: Any])
    XCTAssertEqual(payload["gasLimit"] as? Int, 56240)
  }

  func test_action_roundTrips_soAPersistedActionCanBeResumed() throws {
    let action = YieldXyzBorrowFixtures.borrowAction()

    let data = try JSONEncoder().encode(action)
    let decoded = try JSONDecoder().decode(YieldXyzBorrowAction.self, from: data)

    XCTAssertEqual(decoded, action)
  }

  func test_submitResult_decodes_withAndWithoutOptionalFields() throws {
    let minimal = try decode(
      YieldXyzBorrowSubmitTransactionResponse.self,
      #"{"data":{"transactionHash":"0x1234567890abcdef","link":"https://etherscan.io/tx/0x1234567890abcdef","status":"BROADCASTED"}}"#
    )
    XCTAssertEqual(minimal.data.status, .broadcasted)
    XCTAssertNil(minimal.data.error)
    XCTAssertNil(minimal.data.details)

    let failed = try decode(
      YieldXyzBorrowSubmitTransactionResult.self,
      #"{"transactionHash":null,"link":"","status":"FAILED","error":"reverted","details":{"code":"EXECUTE_PRECONDITION_FAILED"}}"#
    )
    XCTAssertNil(failed.transactionHash)
    XCTAssertEqual(failed.status, .failed)
    XCTAssertEqual(failed.error, "reverted")
    XCTAssertEqual(failed.details?["code"], "EXECUTE_PRECONDITION_FAILED")
  }

  func test_actionsPage_decodes() throws {
    let response = try decode(YieldXyzBorrowGetActionsResponse.self, """
    {"data":{"total":1,"offset":0,"limit":25,"items":[{"id":"a","integrationId":"aave-borrow","action":"borrow","address":"\(address)","status":"SUCCESS",
    "transactions":[],"hasNextStep":false,"currentStep":2,"totalSteps":2,"createdAt":"2026-08-26T10:30:00.000Z"}]}}
    """)

    XCTAssertEqual(response.data.items.first?.status, .success)
    XCTAssertEqual(response.data.items.first?.currentStep, 2)
    XCTAssertNil(response.data.items.first?.metadata)
  }

  // MARK: - Open values

  func test_openValues_keepUnknownValues_andReEncodeThemVerbatim() throws {
    let transaction = try decode(YieldXyzBorrowTransaction.self, """
    {"id":"t","network":"tron:mainnet","type":"BRIDGE","status":"REPLACED","address":"\(address)","signingFormat":"TRON_TRANSACTION"}
    """)

    XCTAssertEqual(transaction.type.rawValue, "BRIDGE")
    XCTAssertEqual(transaction.status, YieldXyzBorrowTransactionStatus(rawValue: "REPLACED"))
    XCTAssertEqual(transaction.signingFormat?.rawValue, "TRON_TRANSACTION")
    let encoded = try encodedObject(transaction)
    XCTAssertEqual(encoded["type"] as? String, "BRIDGE")
    XCTAssertEqual(encoded["status"] as? String, "REPLACED")
  }

  func test_openValues_listTheKnownValues() {
    XCTAssertEqual(YieldXyzBorrowActionType.supplyAndBorrow.rawValue, "supplyAndBorrow")
    XCTAssertEqual(YieldXyzBorrowActionType.enableCollateral.rawValue, "enableCollateral")
    XCTAssertEqual(YieldXyzBorrowActionStatus.waitingForNext.rawValue, "WAITING_FOR_NEXT")
    XCTAssertEqual(YieldXyzBorrowTransactionStatus.waitingForSignature.rawValue, "WAITING_FOR_SIGNATURE")
    XCTAssertEqual(YieldXyzBorrowTransactionStatus.notFound.rawValue, "NOT_FOUND")
    XCTAssertEqual(YieldXyzBorrowTransactionType.disableCollateral.rawValue, "DISABLE_COLLATERAL")
    XCTAssertEqual(YieldXyzBorrowTransactionType.wrap.rawValue, "WRAP")
    XCTAssertEqual(YieldXyzBorrowSigningFormat.eip712TypedData.rawValue, "EIP712_TYPED_DATA")
    XCTAssertEqual(YieldXyzBorrowMarketType.isolated.rawValue, "isolated")
    XCTAssertEqual(YieldXyzBorrowLiquidationType.full.rawValue, "full")
    XCTAssertEqual(YieldXyzBorrowHealthStatusValue.fail.rawValue, "FAIL")
    XCTAssertEqual(YieldXyzBorrowMarketScope.enabled.rawValue, "enabled")
  }

  // MARK: - Requests

  func test_actionArguments_encodeOnlyTheFieldsSet() throws {
    let args = YieldXyzBorrowActionArguments(
      marketId: "m-1",
      tokenAddress: "0x1",
      collateralTokenAddress: "0x2",
      collateralAmount: "1",
      collateralAmountRaw: "1000",
      borrowAmount: "0.2",
      targetLtv: "0.5"
    )

    XCTAssertEqual(try encodedObject(args), [
      "marketId": "m-1",
      "tokenAddress": "0x1",
      "collateralTokenAddress": "0x2",
      "collateralAmount": "1",
      "collateralAmountRaw": "1000",
      "borrowAmount": "0.2",
      "targetLtv": "0.5"
    ])
    XCTAssertEqual(try encodedObject(YieldXyzBorrowActionArguments(marketId: "m-1")), ["marketId": "m-1"])
  }

  func test_actionArguments_decodeEveryField() throws {
    let args = try decode(YieldXyzBorrowActionArguments.self, """
    {"marketId":"m","amount":"1","amountRaw":"1000000","repayAll":false,"tokenAddress":"0x1","collateralTokenAddress":"0x2","collateralAmount":"2",
    "collateralAmountRaw":"2000","borrowAmount":"3","targetLtv":"0.6"}
    """)

    XCTAssertEqual(args, YieldXyzBorrowActionArguments(
      marketId: "m",
      amount: "1",
      amountRaw: "1000000",
      repayAll: false,
      tokenAddress: "0x1",
      collateralTokenAddress: "0x2",
      collateralAmount: "2",
      collateralAmountRaw: "2000",
      borrowAmount: "3",
      targetLtv: "0.6"
    ))
  }
}
