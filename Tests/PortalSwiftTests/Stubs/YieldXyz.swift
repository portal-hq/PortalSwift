//
//  YieldXyz.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 30/10/2025.
//

import AnyCodable
import Foundation
@testable import PortalSwift

extension YieldXyzToken {
  static func stub(
    symbol: String = "ETH",
    name: String = "Ethereum",
    decimals: Int? = 18,
    network: String? = "eip155:1",
    address: String? = "0x0000000000000000000000000000000000000000",
    logoURI: String? = nil,
    isPoints: Bool? = false,
    coinGeckoId: String? = "ethereum"
  ) -> Self {
    YieldXyzToken(symbol: symbol, name: name, decimals: decimals, network: network, address: address, logoURI: logoURI, isPoints: isPoints, coinGeckoId: coinGeckoId)
  }
}

extension YieldXyzRewardRateComponent {
  static func stub(
    rate: Double = 5.0,
    rateType: YieldXyzRateType = .APR,
    token: YieldXyzToken = .stub(),
    yieldSource: YieldXyzSource = .staking,
    description: String = "Base staking reward"
  ) -> Self {
    YieldXyzRewardRateComponent(rate: rate, rateType: rateType, token: token, yieldSource: yieldSource, description: description)
  }
}

extension YieldXyzRewardRate {
  static func stub(
    total: Double = 5.0,
    rateType: YieldXyzRateType = .APR,
    components: [YieldXyzRewardRateComponent] = [.stub()]
  ) -> Self {
    YieldXyzRewardRate(total: total, rateType: rateType, components: components)
  }
}

extension YieldXyzStatus {
  static func stub(enter: Bool = true, exit: Bool = true) -> Self {
    YieldXyzStatus(enter: enter, exit: exit)
  }
}

extension YieldXyzOpportunityMetadata {
  static func stub(
    name: String = "Mock Yield",
    logoURI: String = "https://example.com/logo.png",
    description: String = "A mock yield for tests",
    documentation: String = "https://example.com/docs",
    underMaintenance: Bool = false,
    deprecated: Bool = false,
    supportedStandards: [String] = []
  ) -> Self {
    YieldXyzOpportunityMetadata(
      name: name,
      logoURI: logoURI,
      description: description,
      documentation: documentation,
      underMaintenance: underMaintenance,
      deprecated: deprecated,
      supportedStandards: supportedStandards
    )
  }
}

extension YieldXyzFee {
  static func stub(deposit: Double = 0, withdrawal: Double = 0, performance: Double = 0, management: Double = 0) -> Self {
    YieldXyzFee(deposit: deposit, withdrawal: withdrawal, performance: performance, management: management)
  }
}

extension YieldXyzEntryLimits {
  static func stub(minimum: String? = "0.0", maximum: String? = nil) -> Self {
    YieldXyzEntryLimits(minimum: minimum, maximum: maximum)
  }
}

extension YieldXyzArgument {
  static func stub(fields: [YieldXyzArgumentField] = []) -> Self {
    YieldXyzArgument(fields: fields, notes: nil)
  }
}

extension YieldXyzArguments {
  static func stub(
    enter: YieldXyzArgument = .stub(),
    exit: YieldXyzArgument = .stub(),
    manage: [String: AnyCodable]? = nil,
    balance: YieldXyzArgument? = nil
  ) -> Self {
    YieldXyzArguments(enter: enter, exit: exit, manage: manage, balance: balance)
  }
}

extension YieldXyzMechanics {
  static func stub(
    type: YieldXyzMechanicsType = .staking,
    requiresValidatorSelection: Bool = false,
    rewardSchedule: YieldXyzRewardSchedule = .day,
    rewardClaiming: YieldXyzRewardClaiming = .auto,
    gasFeeToken: YieldXyzToken = .stub(),
    lockupPeriod: YieldXyzLockupPeriod? = nil,
    cooldownPeriod: YieldXyzCooldownPeriod? = nil,
    warmupPeriod: YieldXyzWarmupPeriod? = nil,
    fee: YieldXyzFee? = .stub(),
    entryLimits: YieldXyzEntryLimits = .stub(),
    supportsLedgerWalletApi: Bool = true,
    extraTransactionFormatsSupported: [String]? = nil,
    arguments: YieldXyzArguments = .stub(),
    possibleFeeTakingMechanisms: YieldXyzPossibleFeeTakingMechanisms = .init(depositFee: false, managementFee: false, performanceFee: false, validatorRebates: false)
  ) -> Self {
    YieldXyzMechanics(
      type: type,
      requiresValidatorSelection: requiresValidatorSelection,
      rewardSchedule: rewardSchedule,
      rewardClaiming: rewardClaiming,
      gasFeeToken: gasFeeToken,
      lockupPeriod: lockupPeriod,
      cooldownPeriod: cooldownPeriod,
      warmupPeriod: warmupPeriod,
      fee: fee,
      entryLimits: entryLimits,
      supportsLedgerWalletApi: supportsLedgerWalletApi,
      extraTransactionFormatsSupported: extraTransactionFormatsSupported,
      arguments: arguments,
      possibleFeeTakingMechanisms: possibleFeeTakingMechanisms
    )
  }
}

// MARK: - Yields list

extension YieldXyzOpportunity {
  static func stub(
    id: String = "yield-1",
    network: String = "eip155:1",
    inputTokens: [YieldXyzToken] = [.stub()],
    outputToken: YieldXyzToken = .stub(),
    token: YieldXyzToken = .stub(),
    rewardRate: YieldXyzRewardRate = .stub(),
    statistics: YieldXyzStatistics? = .init(tvlUsd: "1000000", tvl: 1_000_000, uniqueUsers: 1000, averagePositionSizeUsd: 1000, averagePositionSize: 1),
    status: YieldXyzStatus = .stub(),
    metadata: YieldXyzOpportunityMetadata = .stub(),
    mechanics: YieldXyzMechanics = .stub(),
    providerId: String = "provider-1",
    tags: [String] = ["staking"]
  ) -> Self {
    YieldXyzOpportunity(
      id: id,
      network: network,
      inputTokens: inputTokens,
      outputToken: outputToken,
      token: token,
      rewardRate: rewardRate,
      statistics: statistics,
      status: status,
      metadata: metadata,
      mechanics: mechanics,
      providerId: providerId,
      tags: tags
    )
  }
}

extension YieldXyzGetYieldsRawResponse {
  static func stub(items: [YieldXyzOpportunity] = [.stub()], limit: Int = 10, offset: Int = 0, total: Int = 1) -> Self {
    YieldXyzGetYieldsRawResponse(items: items, limit: limit, offset: offset, total: total)
  }
}

extension YieldXyzGetYieldsData {
  static func stub(rawResponse: YieldXyzGetYieldsRawResponse = .stub()) -> Self {
    YieldXyzGetYieldsData(rawResponse: rawResponse)
  }
}

extension YieldXyzGetYieldsResponse {
  static func stub(data: YieldXyzGetYieldsData? = .stub(), error: String? = nil) -> Self {
    YieldXyzGetYieldsResponse(data: data, error: error)
  }
}

// MARK: - Actions common

extension YieldXyzActionTransaction {
  static func stub(
    id: String = "tx-1",
    title: String = "Stake",
    network: String = "eip155:1",
    status: YieldXyzActionTransactionStatus = .CREATED,
    type: YieldXyzActionTransactionType = .STAKE,
    hash: String? = nil,
    createdAt: String = "created-at",
    broadcastedAt: String? = nil,
    signedTransaction: String? = nil,
    unsignedTransaction: String? = "0x00",
    annotatedTransaction: [String: AnyCodable]? = nil,
    structuredTransaction: [String: AnyCodable]? = nil,
    stepIndex: Int = 0,
    description: String? = nil,
    error: String? = nil,
    gasEstimate: String? = "21000",
    explorerUrl: String? = nil,
    isMessage: Bool? = false
  ) -> Self {
    YieldXyzActionTransaction(
      id: id,
      title: title,
      network: network,
      status: status,
      type: type,
      hash: hash,
      createdAt: createdAt,
      broadcastedAt: broadcastedAt,
      signedTransaction: signedTransaction,
      unsignedTransaction: unsignedTransaction,
      annotatedTransaction: annotatedTransaction,
      structuredTransaction: structuredTransaction,
      stepIndex: stepIndex,
      description: description,
      error: error,
      gasEstimate: gasEstimate,
      explorerUrl: explorerUrl,
      isMessage: isMessage
    )
  }
}

// MARK: - Enter

extension YieldXyzEnterRawResponse {
  static func stub(
    id: String = "action-1",
    intent: YieldXyzActionIntent = .enter,
    type: YieldXyzActionType = .STAKE,
    yieldId: String = "yield-1",
    address: String = "0x0000000000000000000000000000000000000000",
    amount: String? = "1.0",
    amountRaw: String? = "1000000000000000000",
    amountUsd: String? = "3000",
    transactions: [YieldXyzActionTransaction] = [.stub()],
    executionPattern: YieldXyzActionExecutionPattern = .synchronous,
    rawArguments: YieldXyzEnterArguments? = .init(amount: "1"),
    createdAt: String = "created-at",
    completedAt: String? = nil,
    status: YieldXyzActionStatus = .CREATED
  ) -> Self {
    YieldXyzEnterRawResponse(
      id: id,
      intent: intent,
      type: type,
      yieldId: yieldId,
      address: address,
      amount: amount,
      amountRaw: amountRaw,
      amountUsd: amountUsd,
      transactions: transactions,
      executionPattern: executionPattern,
      rawArguments: rawArguments,
      createdAt: createdAt,
      completedAt: completedAt,
      status: status
    )
  }
}

extension YieldXyzEnterYieldData {
  static func stub(rawResponse: YieldXyzEnterRawResponse = .stub()) -> Self {
    YieldXyzEnterYieldData(rawResponse: rawResponse)
  }
}

extension YieldXyzEnterYieldResponse {
  static func stub(data: YieldXyzEnterYieldData? = .stub(), error: String? = nil) -> Self {
    YieldXyzEnterYieldResponse(data: data, error: error)
  }
}

// MARK: - Exit

extension YieldXyzExitRawResponse {
  static func stub(
    id: String = "action-2",
    intent: YieldXyzActionIntent = .exit,
    type: YieldXyzActionType = .UNSTAKE,
    yieldId: String = "yield-1",
    address: String = "0x0000000000000000000000000000000000000000",
    amount: String? = "1.0",
    amountRaw: String? = "1000000000000000000",
    amountUsd: String? = "3000",
    transactions: [YieldXyzActionTransaction] = [.stub(type: .UNSTAKE)],
    executionPattern: YieldXyzActionExecutionPattern = .synchronous,
    rawArguments: YieldXyzEnterArguments? = .init(amount: "1"),
    createdAt: String = "created-at",
    completedAt: String? = nil,
    status: YieldXyzActionStatus = .CREATED
  ) -> Self {
    YieldXyzExitRawResponse(
      id: id,
      intent: intent,
      type: type,
      yieldId: yieldId,
      address: address,
      amount: amount,
      amountRaw: amountRaw,
      amountUsd: amountUsd,
      transactions: transactions,
      executionPattern: executionPattern,
      rawArguments: rawArguments,
      createdAt: createdAt,
      completedAt: completedAt,
      status: status
    )
  }
}

extension YieldXyzExitData {
  static func stub(rawResponse: YieldXyzExitRawResponse = .stub()) -> Self {
    YieldXyzExitData(rawResponse: rawResponse)
  }
}

extension YieldXyzExitResponse {
  static func stub(data: YieldXyzExitData? = .stub(), error: String? = nil) -> Self {
    YieldXyzExitResponse(data: data, error: error)
  }
}

// MARK: - Manage

extension YieldXyzManageYieldRawResponse {
  static func stub(
    id: String = "action-3",
    intent: YieldXyzActionIntent = .manage,
    type: YieldXyzActionType = .CLAIM_REWARDS,
    yieldId: String = "yield-1",
    address: String = "0x0000000000000000000000000000000000000000",
    amount: String? = nil,
    amountRaw: String? = nil,
    amountUsd: String? = nil,
    transactions: [YieldXyzActionTransaction] = [.stub(type: .CLAIM_REWARDS)],
    executionPattern: YieldXyzActionExecutionPattern = .synchronous,
    rawArguments: YieldXyzEnterArguments? = nil,
    createdAt: String = "created-at",
    completedAt: String? = nil,
    status: YieldXyzActionStatus = .CREATED
  ) -> Self {
    YieldXyzManageYieldRawResponse(
      id: id,
      intent: intent,
      type: type,
      yieldId: yieldId,
      address: address,
      amount: amount,
      amountRaw: amountRaw,
      amountUsd: amountUsd,
      transactions: transactions,
      executionPattern: executionPattern,
      rawArguments: rawArguments,
      createdAt: createdAt,
      completedAt: completedAt,
      status: status
    )
  }
}

extension YieldXyzManageYieldData {
  static func stub(rawResponse: YieldXyzManageYieldRawResponse = .stub()) -> Self {
    YieldXyzManageYieldData(rawResponse: rawResponse)
  }
}

extension YieldXyzManageYieldResponse {
  static func stub(data: YieldXyzManageYieldData? = .stub(), error: String? = nil) -> Self {
    YieldXyzManageYieldResponse(data: data, error: error)
  }
}

// MARK: - Balances

extension YieldXyzBalanceToken {
  static func stub(
    address: String = "0x0000000000000000000000000000000000000000",
    symbol: String = "ETH",
    name: String = "Ethereum",
    decimals: Int = 18,
    logoURI: String? = nil,
    network: String = "eip155:1",
    isPoints: Bool? = false
  ) -> Self {
    YieldXyzBalanceToken(address: address, symbol: symbol, name: name, decimals: decimals, logoURI: logoURI, network: network, isPoints: isPoints)
  }
}

extension YieldXyzBalance {
  static func stub(
    address: String = "0x0000000000000000000000000000000000000000",
    amount: String = "1.0",
    amountRaw: String = "1000000000000000000",
    type: String = "STAKED",
    token: YieldXyzBalanceToken = .stub(),
    pendingActions: [YieldXyzBalancePendingAction] = [],
    amountUsd: String? = "3000",
    isEarning: Bool? = true
  ) -> Self {
    YieldXyzBalance(address: address, amount: amount, amountRaw: amountRaw, type: type, token: token, pendingActions: pendingActions, amountUsd: amountUsd, isEarning: isEarning)
  }
}

extension YieldXyzGetBalancesItem {
  static func stub(yieldId: String = "yield-1", balances: [YieldXyzBalance] = [.stub()]) -> Self {
    YieldXyzGetBalancesItem(yieldId: yieldId, balances: balances)
  }
}

extension YieldXyzGetBalancesRawResponse {
  static func stub(items: [YieldXyzGetBalancesItem] = [.stub()], errors: [String] = []) -> Self {
    YieldXyzGetBalancesRawResponse(items: items, errors: errors)
  }
}

extension YieldXyzGetBalancesData {
  static func stub(rawResponse: YieldXyzGetBalancesRawResponse = .stub()) -> Self {
    YieldXyzGetBalancesData(rawResponse: rawResponse)
  }
}

extension YieldXyzGetBalancesMetadata {
  static func stub(clientId: String? = "client-id") -> Self {
    YieldXyzGetBalancesMetadata(clientId: clientId)
  }
}

extension YieldXyzGetBalancesResponse {
  static func stub(data: YieldXyzGetBalancesData? = .stub(), metadata: YieldXyzGetBalancesMetadata? = .stub(), error: String? = nil) -> Self {
    YieldXyzGetBalancesResponse(data: data, metadata: metadata, error: error)
  }
}

// MARK: - Historical actions

extension YieldXyzGetHistoricalActionsRawResponse {
  static func stub(items: [YieldXyzEnterRawResponse] = [.stub()], total: Int? = 1, offset: Int? = 0, limit: Int? = 10) -> Self {
    YieldXyzGetHistoricalActionsRawResponse(items: items, total: total, offset: offset, limit: limit)
  }
}

extension YieldXyzGetHistoricalActionsData {
  static func stub(rawResponse: YieldXyzGetHistoricalActionsRawResponse = .stub()) -> Self {
    YieldXyzGetHistoricalActionsData(rawResponse: rawResponse)
  }
}

extension YieldXyzGetHistoricalActionsResponse {
  static func stub(data: YieldXyzGetHistoricalActionsData? = .stub(), metadata: YieldXyzGetBalancesMetadata? = .stub(), error: String? = nil) -> Self {
    YieldXyzGetHistoricalActionsResponse(data: data, metadata: metadata, error: error)
  }
}

// MARK: - Transactions

extension YieldXyzGetTransactionRawResponse {
  static func stub(
    id: String = "tx-1",
    title: String = "Stake",
    network: String = "eip155:1",
    status: YieldXyzActionTransactionStatus = .CREATED,
    type: YieldXyzActionTransactionType = .STAKE,
    hash: String? = nil,
    createdAt: String = "created-at",
    broadcastedAt: String? = nil,
    signedTransaction: String? = nil,
    unsignedTransaction: String? = "0x00",
    stepIndex: Int = 0,
    gasEstimate: String? = "21000"
  ) -> Self {
    YieldXyzGetTransactionRawResponse(
      id: id,
      title: title,
      network: network,
      status: status,
      type: type,
      hash: hash,
      createdAt: createdAt,
      broadcastedAt: broadcastedAt,
      signedTransaction: signedTransaction,
      unsignedTransaction: unsignedTransaction,
      stepIndex: stepIndex,
      gasEstimate: gasEstimate
    )
  }
}

extension YieldXyzGetTransactionData {
  static func stub(rawResponse: YieldXyzGetTransactionRawResponse = .stub()) -> Self {
    YieldXyzGetTransactionData(rawResponse: rawResponse)
  }
}

extension YieldXyzGetTransactionMetadata {
  static func stub(clientId: String? = "client-id", transactionId: String? = "tx-1") -> Self {
    YieldXyzGetTransactionMetadata(clientId: clientId, transactionId: transactionId)
  }
}

extension YieldXyzGetTransactionResponse {
  static func stub(data: YieldXyzGetTransactionData? = .stub(), metadata: YieldXyzGetTransactionMetadata? = .stub(), error: String? = nil) -> Self {
    YieldXyzGetTransactionResponse(data: data, metadata: metadata, error: error)
  }
}

// MARK: - Track Transaction

extension YieldXyzTrackTransactionRawResponse {
  static func stub(
    id: String = "tx-1",
    title: String = "Stake",
    network: String = "eip155:1",
    status: YieldXyzActionTransactionStatus = .BROADCASTED,
    type: YieldXyzActionTransactionType = .STAKE,
    hash: String? = nil,
    createdAt: String = "created-at",
    broadcastedAt: String? = "created-at",
    signedTransaction: String? = nil,
    unsignedTransaction: String? = "0x00",
    stepIndex: Int = 0,
    gasEstimate: String? = "21000"
  ) -> Self {
    YieldXyzTrackTransactionRawResponse(
      id: id,
      title: title,
      network: network,
      status: status,
      type: type,
      hash: hash,
      createdAt: createdAt,
      broadcastedAt: broadcastedAt,
      signedTransaction: signedTransaction,
      unsignedTransaction: unsignedTransaction,
      stepIndex: stepIndex,
      gasEstimate: gasEstimate
    )
  }
}

extension YieldXyzTrackTransactionData {
  static func stub(rawResponse: YieldXyzTrackTransactionRawResponse = .stub()) -> Self {
    YieldXyzTrackTransactionData(rawResponse: rawResponse)
  }
}

extension YieldXyzTrackTransactionResponse {
  static func stub(data: YieldXyzTrackTransactionData? = .stub(), error: String? = nil) -> Self {
    YieldXyzTrackTransactionResponse(data: data, error: error)
  }
}
