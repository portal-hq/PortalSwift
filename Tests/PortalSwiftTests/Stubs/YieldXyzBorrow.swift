//
//  YieldXyzBorrow.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import AnyCodable
import Foundation
@testable import PortalSwift

/// Fixtures shared with the React Native and Web SDK tests (`__mocks/yieldXyzBorrow.ts`), so every
/// SDK signs and submits the same payloads.
enum YieldXyzBorrowFixtures {
  static let wallet = "0x8ba1f109551bD432803012645Ac136ddd64DBA72"
  static let otherWallet = "0x742d35Cc6634C0532925a3b844Bc9e7595f8fB28"

  static let base = "eip155:8453"
  static let usdcBase = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
  static let aavePoolBase = "0xA238Dd80C259a72e81d7e4664a9801593F98d1c5"
  static let marketId = "aave-borrow-base-0x833589fcd6edb6e08f4c7c32d4f71b54bda02913"

  static let approvalHash = "0x" + String(repeating: "a1", count: 32)
  static let supplyHash = "0x" + String(repeating: "b2", count: 32)
  static let userOperationHash = "0x" + String(repeating: "c3", count: 32)
  static let bundleHash = "0x" + String(repeating: "d4", count: 32)

  /// Decodes `json` as the SDK decodes a response.
  static func decode<T: Decodable>(_: T.Type = T.self, _ json: String) -> T {
    do {
      return try JSONDecoder().decode(T.self, from: Data(json.utf8))
    } catch {
      fatalError("Fixture does not decode as \(T.self): \(error)")
    }
  }

  static let approvalData = "0x095ea7b3000000000000000000000000"
    + aavePoolBase.dropFirst(2).lowercased()
    + "00000000000000000000000000000000000000000000000000000000004c4b40"

  static let supplyData = "0x617ba037000000000000000000000000" + usdcBase.dropFirst(2).lowercased()

  /// ERC-20 `approve(pool, 5 USDC)`, JSON-encoded with a decimal `gasLimit`, as the Borrow API
  /// returns it.
  static func approvalPayload(from: String = wallet) -> String {
    #"{"from":"\#(from)","gasLimit":"56240","to":"\#(usdcBase)","data":"\#(approvalData)"}"#
  }

  /// Aave V3 `supply(USDC, 5 USDC, from, 0)`.
  static func supplyPayload(from: String = wallet) -> String {
    #"{"from":"\#(from)","gasLimit":"420000","to":"\#(aavePoolBase)","data":"\#(supplyData)"}"#
  }

  static func approvalTransaction(
    id: String = "tx-approval",
    network: String = base,
    status: YieldXyzBorrowTransactionStatus = .created,
    address: String = wallet,
    signingFormat: YieldXyzBorrowSigningFormat? = .evmTransaction,
    signablePayload: AnyCodable? = AnyCodable(approvalPayload())
  ) -> YieldXyzBorrowTransaction {
    YieldXyzBorrowTransaction(
      id: id,
      network: network,
      type: .approval,
      status: status,
      address: address,
      signingFormat: signingFormat,
      signablePayload: signablePayload
    )
  }

  static func supplyTransaction(
    id: String = "tx-supply",
    network: String = base,
    status: YieldXyzBorrowTransactionStatus = .created,
    address: String = wallet,
    signingFormat: YieldXyzBorrowSigningFormat? = .evmTransaction,
    signablePayload: AnyCodable? = AnyCodable(supplyPayload())
  ) -> YieldXyzBorrowTransaction {
    YieldXyzBorrowTransaction(
      id: id,
      network: network,
      type: .supply,
      status: status,
      address: address,
      signingFormat: signingFormat,
      signablePayload: signablePayload
    )
  }

  static func borrowAction(
    id: String = "act-1",
    address: String = wallet,
    status: YieldXyzBorrowActionStatus = .created,
    transactions: [YieldXyzBorrowTransaction]? = nil,
    hasNextStep: Bool = false,
    currentStep: Int = 1,
    totalSteps: Int = 1
  ) -> YieldXyzBorrowAction {
    YieldXyzBorrowAction(
      id: id,
      integrationId: "aave-borrow",
      action: .supply,
      address: address,
      status: status,
      transactions: transactions ?? [approvalTransaction(), supplyTransaction()],
      hasNextStep: hasNextStep,
      currentStep: currentStep,
      totalSteps: totalSteps,
      rawArguments: YieldXyzBorrowActionArguments(marketId: marketId, amount: "5", tokenAddress: usdcBase),
      metadata: YieldXyzBorrowActionMetadata(
        currentLtv: "0",
        predictedLtv: "0",
        liquidationThreshold: "0.78",
        predictedTotalSupplyUsd: "5.00",
        predictedTotalDebtUsd: "0"
      ),
      createdAt: "2026-09-28T12:00:00.000Z"
    )
  }

  static func submitResult(
    transactionHash: String = approvalHash,
    status: YieldXyzBorrowTransactionStatus = .broadcasted
  ) -> YieldXyzBorrowSubmitTransactionResult {
    YieldXyzBorrowSubmitTransactionResult(
      transactionHash: transactionHash,
      link: "https://basescan.org/tx/\(transactionHash)",
      status: status
    )
  }

  /// The lookup of an EOA transaction: the hash is the transaction's.
  static func evmTransactionLookup(_ hash: String) -> YieldXyzEvmTransactionLookup {
    YieldXyzEvmTransactionLookup(transactionHash: hash)
  }

  /// The lookup of a user operation, included in `receiptHash` (`nil` until it is mined).
  static func userOperationLookup(receiptHash: String?, success: Bool? = nil) -> YieldXyzEvmTransactionLookup {
    YieldXyzEvmTransactionLookup(userOperation: .init(
      success: success ?? (receiptHash == nil ? nil : true),
      receiptTransactionHash: receiptHash
    ))
  }
}

// MARK: - Stubs

extension YieldXyzBorrowToken {
  static func stub(address: String? = YieldXyzBorrowFixtures.usdcBase, symbol: String = "USDC", decimals: Int = 6) -> Self {
    YieldXyzBorrowToken(address: address, symbol: symbol, name: "USD Coin", decimals: decimals, logoURI: "https://assets.yield.xyz/usdc.png")
  }
}

extension YieldXyzBorrowIntegration {
  static func stub(id: String = "aave-borrow") -> Self {
    YieldXyzBorrowIntegration(
      id: id,
      providerId: "aave",
      name: "Aave V3",
      networks: ["eip155:1", "eip155:8453"],
      metadata: YieldXyzBorrowIntegrationMetadata(
        description: "Aave V3 lending",
        externalLink: "https://aave.com",
        logoURI: "https://assets.yield.xyz/aave.png"
      ),
      actions: [YieldXyzBorrowActionDefinition(id: .supply, label: "Supply", schema: ["type": "object"])]
    )
  }
}

extension YieldXyzBorrowMarket {
  static func stub(id: String = YieldXyzBorrowFixtures.marketId) -> Self {
    YieldXyzBorrowMarket(
      id: id,
      integrationId: "aave-borrow",
      network: YieldXyzBorrowFixtures.base,
      type: .pool,
      poolAddress: YieldXyzBorrowFixtures.aavePoolBase,
      loanToken: .stub(),
      collateralTokens: [YieldXyzBorrowCollateralToken(
        token: .stub(address: "0x4200000000000000000000000000000000000006", symbol: "WETH", decimals: 18),
        priceUsd: "2800.00",
        maxLtv: "0.80",
        liquidationThreshold: "0.825",
        liquidationPenalty: "0.05",
        supplyRate: "0.02"
      )],
      borrowRate: "0.0567",
      totalSupply: "1000000.00",
      totalSupplyRaw: "1000000000000",
      totalBorrow: "800000.00",
      totalBorrowRaw: "800000000000",
      availableLiquidity: "200000.00",
      availableLiquidityRaw: "200000000000",
      utilizationRate: "0.80",
      loanTokenPriceUsd: "1.00",
      isBorrowEnabled: true,
      supplyCollateralFeeBps: "50",
      originationFeeBps: "100",
      minLoan: "0.01"
    )
  }
}

extension YieldXyzBorrowPosition {
  static func stub() -> Self {
    YieldXyzBorrowPosition(
      address: YieldXyzBorrowFixtures.wallet,
      integrationId: "aave-borrow",
      network: YieldXyzBorrowFixtures.base,
      totalSuppliedUsd: "5000.00",
      totalCollateralUsd: "4200.00",
      totalBorrowedUsd: "2000.00",
      netWorthUsd: "3000.00",
      healthFactor: "1.85",
      currentLtv: "0.55",
      availableToBorrowUsd: "1500.00",
      netApy: "2.34",
      supplyBalances: [],
      debtBalances: []
    )
  }
}

extension YieldXyzBorrowLiquidation {
  static func stub() -> Self {
    YieldXyzBorrowLiquidation(
      id: "liq_0b3f",
      integrationId: "morpho-blue-borrow",
      network: "eip155:1",
      address: YieldXyzBorrowFixtures.wallet,
      marketId: YieldXyzBorrowFixtures.marketId,
      type: .partial,
      realizedBadDebt: false,
      occurredAt: "2026-08-20T08:15:00.000Z",
      blockNumber: 22_118_447,
      transactionHash: "0x8a3f",
      transactionLink: "https://etherscan.io/tx/0x8a3f",
      liquidator: YieldXyzBorrowFixtures.otherWallet,
      repaidDebt: YieldXyzBorrowRepaidDebt(
        tokenAddress: YieldXyzBorrowFixtures.usdcBase,
        tokenSymbol: "USDC",
        amount: "1500.000000",
        amountRaw: "1500000000",
        amountUsd: "1500.00",
        shares: "1487123456789012345678"
      ),
      seizedCollateral: YieldXyzBorrowSeizedCollateral(
        tokenAddress: "0x4200000000000000000000000000000000000006",
        tokenSymbol: "WETH",
        amount: "0.55",
        amountRaw: "550000000000000000",
        amountUsd: "1567.50"
      ),
      badDebt: YieldXyzBorrowBadDebt(amountRaw: "0", amount: "0", amountUsd: "0.00", shares: "0"),
      lif: "1.0449"
    )
  }
}

extension YieldXyzBorrowAction {
  static func stub() -> Self {
    YieldXyzBorrowFixtures.borrowAction()
  }
}

extension YieldXyzBorrowSubmitTransactionResult {
  static func stub() -> Self {
    YieldXyzBorrowFixtures.submitResult()
  }
}
