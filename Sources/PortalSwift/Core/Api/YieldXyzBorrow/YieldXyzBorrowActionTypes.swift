//
//  YieldXyzBorrowActionTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import AnyCodable
import Foundation

/// Arguments of a lending action. `marketId` is always required; which other fields apply depends
/// on the integration and action: `getIntegration` returns the exact schema of each action's
/// `args`. Fields left `nil` are not sent; the Portal API rejects keys it does not know.
public struct YieldXyzBorrowActionArguments: Codable, Equatable {
  /// The market id as returned by `getMarkets`; treat it as opaque.
  public var marketId: String
  /// Human-readable amount (e.g. `"1.5"`). Provide either `amount` or `amountRaw`.
  public var amount: String?
  /// Amount in raw token units. Provide either `amount` or `amountRaw`.
  public var amountRaw: String?
  /// `repay` only: repay the full debt; omit `amount` and `amountRaw`.
  public var repayAll: Bool?
  /// Required for `supply` and `withdraw` on pool-based protocols (Aave): the market's
  /// `loanToken.address`, or one of `collateralTokens[].token.address`. Isolated-market protocols
  /// (Morpho Blue) infer it from `marketId`; on them `supply` only posts collateral, and passing the
  /// loan token is rejected.
  public var tokenAddress: String?
  public var collateralTokenAddress: String?
  public var collateralAmount: String?
  public var collateralAmountRaw: String?
  public var borrowAmount: String?
  public var targetLtv: String?

  public init(
    marketId: String,
    amount: String? = nil,
    amountRaw: String? = nil,
    repayAll: Bool? = nil,
    tokenAddress: String? = nil,
    collateralTokenAddress: String? = nil,
    collateralAmount: String? = nil,
    collateralAmountRaw: String? = nil,
    borrowAmount: String? = nil,
    targetLtv: String? = nil
  ) {
    self.marketId = marketId
    self.amount = amount
    self.amountRaw = amountRaw
    self.repayAll = repayAll
    self.tokenAddress = tokenAddress
    self.collateralTokenAddress = collateralTokenAddress
    self.collateralAmount = collateralAmount
    self.collateralAmountRaw = collateralAmountRaw
    self.borrowAmount = borrowAmount
    self.targetLtv = targetLtv
  }
}

/// A transaction of the action's current step. The SDK signs `EVM_TRANSACTION` only.
public struct YieldXyzBorrowTransaction: Codable, Equatable {
  public let id: String
  /// CAIP-2 for chains Portal supports (e.g. `eip155:8453`); the Yield.xyz network name otherwise.
  public let network: String
  public let type: YieldXyzBorrowTransactionType
  public let status: YieldXyzBorrowTransactionStatus
  /// The account the transaction was built for.
  public let address: String
  public let signingFormat: YieldXyzBorrowSigningFormat?
  /// For `EVM_TRANSACTION`, a JSON-encoded unsigned transaction (a string), or the same transaction
  /// as an object; passed through as returned.
  public let signablePayload: AnyCodable?

  public init(
    id: String,
    network: String,
    type: YieldXyzBorrowTransactionType,
    status: YieldXyzBorrowTransactionStatus,
    address: String,
    signingFormat: YieldXyzBorrowSigningFormat? = nil,
    signablePayload: AnyCodable? = nil
  ) {
    self.id = id
    self.network = network
    self.type = type
    self.status = status
    self.address = address
    self.signingFormat = signingFormat
    self.signablePayload = signablePayload
  }
}

/// The predicted impact of an action on the position; show it before the user signs. Decimal
/// values are strings. A `nil` health factor means unknown, never safe.
public struct YieldXyzBorrowActionMetadata: Codable, Equatable {
  /// Always sent; `nil` when unknown.
  public let currentHealthFactor: String?
  /// Always sent; `nil` when unknown.
  public let predictedHealthFactor: String?
  public let currentLtv: String
  public let predictedLtv: String
  public let liquidationThreshold: String
  public let predictedTotalSupplyUsd: String
  public let predictedTotalDebtUsd: String
  /// A number here, unlike `YieldXyzBorrowMarket.originationFeeBps`.
  public let originationFeeBps: Double?
  public let originationFeeAmount: String?
  public let effectivePrincipalAmount: String?
  public let feeAmount: String?
  public let feeBps: Double?
  public let effectiveCollateralAmount: String?

  public init(
    currentHealthFactor: String? = nil,
    predictedHealthFactor: String? = nil,
    currentLtv: String,
    predictedLtv: String,
    liquidationThreshold: String,
    predictedTotalSupplyUsd: String,
    predictedTotalDebtUsd: String,
    originationFeeBps: Double? = nil,
    originationFeeAmount: String? = nil,
    effectivePrincipalAmount: String? = nil,
    feeAmount: String? = nil,
    feeBps: Double? = nil,
    effectiveCollateralAmount: String? = nil
  ) {
    self.currentHealthFactor = currentHealthFactor
    self.predictedHealthFactor = predictedHealthFactor
    self.currentLtv = currentLtv
    self.predictedLtv = predictedLtv
    self.liquidationThreshold = liquidationThreshold
    self.predictedTotalSupplyUsd = predictedTotalSupplyUsd
    self.predictedTotalDebtUsd = predictedTotalDebtUsd
    self.originationFeeBps = originationFeeBps
    self.originationFeeAmount = originationFeeAmount
    self.effectivePrincipalAmount = effectivePrincipalAmount
    self.feeAmount = feeAmount
    self.feeBps = feeBps
    self.effectiveCollateralAmount = effectiveCollateralAmount
  }
}

/// A lending action and the transactions of its current step.
public struct YieldXyzBorrowAction: Codable, Equatable {
  public let id: String
  public let integrationId: String
  public let action: YieldXyzBorrowActionType
  public let address: String
  public let status: YieldXyzBorrowActionStatus
  /// Transactions of the current step. On `createAction` and `stepAction` responses the order is
  /// the signing order; `getAction` may list them in a different order.
  public let transactions: [YieldXyzBorrowTransaction]
  /// Whether more transactions follow once the current step is confirmed; fetch them with
  /// `stepAction`.
  public let hasNextStep: Bool
  /// 1-indexed.
  public let currentStep: Int
  public let totalSteps: Int
  public let rawArguments: YieldXyzBorrowActionArguments?
  /// Predicted position impact; show it before the user signs.
  public let metadata: YieldXyzBorrowActionMetadata?
  public let createdAt: String

  public init(
    id: String,
    integrationId: String,
    action: YieldXyzBorrowActionType,
    address: String,
    status: YieldXyzBorrowActionStatus,
    transactions: [YieldXyzBorrowTransaction],
    hasNextStep: Bool,
    currentStep: Int,
    totalSteps: Int,
    rawArguments: YieldXyzBorrowActionArguments? = nil,
    metadata: YieldXyzBorrowActionMetadata? = nil,
    createdAt: String
  ) {
    self.id = id
    self.integrationId = integrationId
    self.action = action
    self.address = address
    self.status = status
    self.transactions = transactions
    self.hasNextStep = hasNextStep
    self.currentStep = currentStep
    self.totalSteps = totalSteps
    self.rawArguments = rawArguments
    self.metadata = metadata
    self.createdAt = createdAt
  }

  /// The action with `transactions` replaced.
  func with(transactions: [YieldXyzBorrowTransaction]) -> YieldXyzBorrowAction {
    YieldXyzBorrowAction(
      id: id,
      integrationId: integrationId,
      action: action,
      address: address,
      status: status,
      transactions: transactions,
      hasNextStep: hasNextStep,
      currentStep: currentStep,
      totalSteps: totalSteps,
      rawArguments: rawArguments,
      metadata: metadata,
      createdAt: createdAt
    )
  }
}

/// The result of submitting a transaction. A `status` of `FAILED` is still a failure.
public struct YieldXyzBorrowSubmitTransactionResult: Codable, Equatable {
  public let transactionHash: String?
  public let link: String
  public let status: YieldXyzBorrowTransactionStatus
  public let error: String?
  public let details: [String: AnyCodable]?

  public init(
    transactionHash: String? = nil,
    link: String,
    status: YieldXyzBorrowTransactionStatus,
    error: String? = nil,
    details: [String: AnyCodable]? = nil
  ) {
    self.transactionHash = transactionHash
    self.link = link
    self.status = status
    self.error = error
    self.details = details
  }
}
