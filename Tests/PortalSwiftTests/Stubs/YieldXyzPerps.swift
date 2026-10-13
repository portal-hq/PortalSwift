//
//  YieldXyzPerps.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import AnyCodable
import Foundation
@testable import PortalSwift

/// Fixtures shared with the React Native and Web SDK tests (`__mocks/yieldXyzPerps.ts`), so every
/// SDK signs and submits the same payloads.
enum YieldXyzPerpsFixtures {
  static let wallet = "0x8ba1f109551bD432803012645Ac136ddd64DBA72"
  static let signature = "0x" + String(repeating: "a1", count: 32) + String(repeating: "b2", count: 32) + "1b"
  static let arbitrumUsdc = "0xaf88d065e77c8cC2239327C5EDb3A432268e5831"
  static let hyperliquidBridge2 = "0x2Df1c51E09aECF9cacB7bc98cB1742757f163dF7"
  static let fundingTxHash = "0x" + String(repeating: "5e", count: 32)

  /// Decodes `json` as the SDK decodes a response.
  static func decode<T: Decodable>(_: T.Type = T.self, _ json: String) -> T {
    do {
      return try JSONDecoder().decode(T.self, from: Data(json.utf8))
    } catch {
      fatalError("Fixture does not decode as \(T.self): \(error)")
    }
  }

  static let hyperliquidOrderTypedDataJSON = """
  {
    "domain": { "name": "Exchange", "version": "1", "chainId": 1337, "verifyingContract": "0x0000000000000000000000000000000000000000" },
    "types": { "Agent": [ { "name": "source", "type": "string" }, { "name": "connectionId", "type": "bytes32" } ] },
    "primaryType": "Agent",
    "message": { "source": "a", "connectionId": "0x\(String(repeating: "c4", count: 32))" }
  }
  """

  static func hyperliquidOrderTypedData() -> AnyCodable {
    decode(AnyCodable.self, hyperliquidOrderTypedDataJSON)
  }

  static let fundingTransferData = "0xa9059cbb000000000000000000000000"
    + hyperliquidBridge2.dropFirst(2).lowercased()
    + "0000000000000000000000000000000000000000000000000000000005f5e100"

  /// An unsigned Arbitrum USDC transfer to the Hyperliquid bridge, JSON-encoded as Yield.xyz
  /// returns it, with the vendor fields the SDK must drop.
  static func fundingTransactionPayload(from: String = wallet) -> String {
    """
    {"from":"\(from)","to":"\(arbitrumUsdc)","data":"\(fundingTransferData)","value":"0x0","gasLimit":"0x186a0","maxFeePerGas":"0x1312d00","maxPriorityFeePerGas":"0x0","nonce":7,"chainId":42161,"type":2}
    """
  }

  static func orderTransaction(
    id: String = "tx-order-1",
    status: YieldXyzPerpsTransactionStatus = .created,
    address: String = wallet,
    signingFormat: YieldXyzPerpsSigningFormat? = .eip712TypedData,
    signablePayload: AnyCodable? = hyperliquidOrderTypedData()
  ) -> YieldXyzPerpsTransaction {
    YieldXyzPerpsTransaction(
      id: id,
      network: "hyperliquid",
      chainId: "1337",
      type: .openPosition,
      status: status,
      address: address,
      args: YieldXyzPerpsActionArgs(marketId: "hyperliquid-eth-usdc", side: .long, size: "0.215", leverage: 20, marginMode: .isolated),
      signingFormat: signingFormat,
      signablePayload: signablePayload,
      rawPayload: AnyCodable("{\"action\":{\"type\":\"order\"},\"nonce\":1756207800000}"),
      explorerUrls: []
    )
  }

  static func fundingTransaction(
    id: String = "tx-fund-1",
    status: YieldXyzPerpsTransactionStatus = .created,
    network: String = "eip155:42161",
    chainId: String = "42161",
    address: String = wallet,
    signablePayload: AnyCodable? = AnyCodable(fundingTransactionPayload())
  ) -> YieldXyzPerpsTransaction {
    YieldXyzPerpsTransaction(
      id: id,
      network: network,
      chainId: chainId,
      type: .fund,
      status: status,
      address: address,
      args: YieldXyzPerpsActionArgs(
        amount: "100",
        fromToken: YieldXyzPerpsTokenIdentifier(network: "eip155:42161", address: arbitrumUsdc),
        fundingMethod: .bridge2
      ),
      signingFormat: .evmTransaction,
      signablePayload: signablePayload,
      explorerUrls: []
    )
  }

  static func perpsAction(
    id: String = "act-1",
    status: YieldXyzPerpsActionStatus = .created,
    transactions: [YieldXyzPerpsTransaction] = [orderTransaction()]
  ) -> YieldXyzPerpsAction {
    YieldXyzPerpsAction(
      id: id,
      providerId: "hyperliquid",
      action: .open,
      status: status,
      summary: YieldXyzPerpsActionSummary(type: "Open Position", orderType: .market, direction: .long, asset: "ETH", size: "0.215", leverage: 20),
      signedMetadata: AnyCodable("01012b02010181d0010081d1040000000b24034152421547"),
      transactions: transactions,
      createdAt: "2026-09-20T10:30:00.000Z",
      completedAt: nil
    )
  }

  static func submitResult(_ status: YieldXyzPerpsTransactionStatus = .confirmed, error: String? = nil) -> YieldXyzPerpsSubmitResult {
    YieldXyzPerpsSubmitResult(
      transactionHash: "0x" + String(repeating: "9d", count: 32),
      link: "https://app.hyperliquid.xyz/explorer/tx/0x9d",
      status: status,
      error: error
    )
  }
}

extension YieldXyzPerpsProvider {
  static func stub(id: String = "hyperliquid") -> YieldXyzPerpsProvider {
    YieldXyzPerpsProvider(
      id: id,
      name: "Hyperliquid",
      network: "hyperliquid",
      metadata: YieldXyzPerpsProviderMetadata(description: "Perpetual futures DEX", externalLink: "https://hyperliquid.xyz", logoURI: nil),
      supportedActions: [.open, .close, .fund, .withdraw, .approveAgent],
      argumentSchemas: ["open": AnyCodable(["type": "object"])]
    )
  }
}

extension YieldXyzPerpsToken {
  static func stub(symbol: String = "USDC", network: String = "hyperliquid") -> YieldXyzPerpsToken {
    YieldXyzPerpsToken(symbol: symbol, name: "USD Coin", network: network, decimals: 6, address: YieldXyzPerpsFixtures.arbitrumUsdc)
  }
}

extension YieldXyzPerpsMarket {
  static func stub(id: String = "hyperliquid-eth-usdc") -> YieldXyzPerpsMarket {
    YieldXyzPerpsMarket(
      id: id,
      providerId: "hyperliquid",
      baseAsset: .stub(symbol: "ETH"),
      quoteAsset: .stub(),
      leverageRange: [1, 50],
      supportedMarginModes: [.isolated, .cross],
      markPrice: 3125.4,
      oraclePrice: 3125.1,
      priceChange24h: -1.233,
      priceChangePercent24h: -5.01,
      volume24h: 12_500_000,
      openInterest: 3400,
      makerFee: "0.0002",
      takerFee: "0.0004",
      fundingRate: "0.00012",
      fundingRateIntervalHours: 8,
      minSize: 10.22,
      metadata: YieldXyzPerpsMarketMetadata(name: "ETH-USDC Perpetual")
    )
  }
}

extension YieldXyzPerpsCandles {
  static func stub() -> YieldXyzPerpsCandles {
    YieldXyzPerpsCandles(
      marketId: "hyperliquid-eth-usdc",
      interval: .oneHour,
      candles: [YieldXyzPerpsCandle(openTime: 1_704_067_200_000, closeTime: 1_704_070_799_999, open: "42150.5", high: "42500.0", low: "42000.0", close: "42350.25", volume: "1234.56", trades: 482)]
    )
  }
}

extension YieldXyzPerpsPosition {
  static func stub() -> YieldXyzPerpsPosition {
    YieldXyzPerpsPosition(
      marketId: "hyperliquid-eth-usdc",
      side: .long,
      size: "0.215",
      entryPrice: 4000,
      markPrice: 3975,
      leverage: 20,
      marginMode: .isolated,
      margin: 43,
      unrealizedPnl: 5.38,
      funding: -1.24,
      liquidationPrice: 4200,
      pendingActions: [YieldXyzPerpsPendingAction(type: .close, label: "Close Position", args: YieldXyzPerpsActionArgs(marketId: "hyperliquid-eth-usdc"))]
    )
  }
}

extension YieldXyzPerpsOrder {
  static func stub() -> YieldXyzPerpsOrder {
    YieldXyzPerpsOrder(
      marketId: "hyperliquid-eth-usdc",
      side: .long,
      type: .limit,
      size: "0.5",
      limitPrice: 3900,
      reduceOnly: false,
      createdAt: 1_733_332_000,
      pendingActions: [YieldXyzPerpsPendingAction(type: .cancelOrder, label: "Cancel Order", args: YieldXyzPerpsActionArgs(orderId: "12345"))]
    )
  }
}

extension YieldXyzPerpsBalance {
  static func stub() -> YieldXyzPerpsBalance {
    YieldXyzPerpsBalance(
      providerId: "hyperliquid",
      collateral: .stub(),
      accountValue: 1280.44,
      usedMargin: 320.13,
      availableBalance: 960.31,
      unrealizedPnl: 12.8,
      unifiedAccountMode: false
    )
  }
}

extension YieldXyzPerpsAction {
  static func stub() -> YieldXyzPerpsAction {
    YieldXyzPerpsFixtures.perpsAction()
  }
}

extension YieldXyzPerpsSubmitResult {
  static func stub() -> YieldXyzPerpsSubmitResult {
    YieldXyzPerpsFixtures.submitResult()
  }
}

extension YieldXyzPerpsEvent {
  static func stub(id: String = "550e8400-e29b-41d4-a716-446655440010") -> YieldXyzPerpsEvent {
    YieldXyzPerpsEvent(
      id: id,
      eventType: .orderFilled,
      providerId: "hyperliquid",
      occurredAt: "2026-04-23T07:52:05.187Z",
      marketId: "hyperliquid-eth-usdc",
      perpActionId: "550e8400-e29b-41d4-a716-446655440001",
      providerOrderId: "394438950581",
      order: YieldXyzPerpsEventOrder(
        orderId: "394438950581",
        marketId: "hyperliquid-eth-usdc",
        asset: "ETH",
        side: "buy",
        type: .market,
        originalSizeBase: "0.0063",
        remainingSizeBase: "0.0",
        reduceOnly: false,
        isPositionLevel: false,
        childOrderIds: [],
        createdAt: "2026-04-23T07:52:05.187Z"
      )
    )
  }
}
