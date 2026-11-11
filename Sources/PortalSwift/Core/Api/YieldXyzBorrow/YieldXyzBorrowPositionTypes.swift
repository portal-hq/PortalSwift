//
//  YieldXyzBorrowPositionTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// The risk state of the position a supply balance belongs to. A `nil` health factor means
/// unknown, never safe.
public struct YieldXyzBorrowPositionState: Codable, Equatable {
  public let currentLtv: String
  public let liquidationThreshold: String
  /// Always sent; `nil` when unknown.
  public let healthFactor: String?
  public let availableToBorrowUsd: String

  public init(currentLtv: String, liquidationThreshold: String, healthFactor: String? = nil, availableToBorrowUsd: String) {
    self.currentLtv = currentLtv
    self.liquidationThreshold = liquidationThreshold
    self.healthFactor = healthFactor
    self.availableToBorrowUsd = availableToBorrowUsd
  }
}

/// An action available on a balance.
public struct YieldXyzBorrowPendingAction: Codable, Equatable {
  public let type: YieldXyzBorrowActionType
  public let label: String
  /// Pre-filled arguments that can be passed to `createAction` as they are.
  public let args: YieldXyzBorrowActionArguments

  public init(type: YieldXyzBorrowActionType, label: String, args: YieldXyzBorrowActionArguments) {
    self.type = type
    self.label = label
    self.args = args
  }
}

/// The fields shared by supply and debt balances, and the shape of a debt balance. Decimal values
/// are strings.
public struct YieldXyzBorrowBalance: Codable, Equatable {
  public let marketId: String
  public let tokenAddress: String
  public let tokenSymbol: String
  public let balance: String
  public let balanceRaw: String
  public let balanceUsd: String
  public let apy: String
  public let pendingActions: [YieldXyzBorrowPendingAction]

  public init(
    marketId: String,
    tokenAddress: String,
    tokenSymbol: String,
    balance: String,
    balanceRaw: String,
    balanceUsd: String,
    apy: String,
    pendingActions: [YieldXyzBorrowPendingAction]
  ) {
    self.marketId = marketId
    self.tokenAddress = tokenAddress
    self.tokenSymbol = tokenSymbol
    self.balance = balance
    self.balanceRaw = balanceRaw
    self.balanceUsd = balanceUsd
    self.apy = apy
    self.pendingActions = pendingActions
  }
}

/// A debt balance.
public typealias YieldXyzBorrowDebtBalance = YieldXyzBorrowBalance

/// A supply balance: the balance fields, plus whether it is collateral and its position's state.
public struct YieldXyzBorrowSupplyBalance: Codable, Equatable {
  public let marketId: String
  public let tokenAddress: String
  public let tokenSymbol: String
  public let balance: String
  public let balanceRaw: String
  public let balanceUsd: String
  public let apy: String
  public let pendingActions: [YieldXyzBorrowPendingAction]
  public let isCollateral: Bool
  public let positionState: YieldXyzBorrowPositionState?

  public init(
    marketId: String,
    tokenAddress: String,
    tokenSymbol: String,
    balance: String,
    balanceRaw: String,
    balanceUsd: String,
    apy: String,
    pendingActions: [YieldXyzBorrowPendingAction],
    isCollateral: Bool,
    positionState: YieldXyzBorrowPositionState? = nil
  ) {
    self.marketId = marketId
    self.tokenAddress = tokenAddress
    self.tokenSymbol = tokenSymbol
    self.balance = balance
    self.balanceRaw = balanceRaw
    self.balanceUsd = balanceUsd
    self.apy = apy
    self.pendingActions = pendingActions
    self.isCollateral = isCollateral
    self.positionState = positionState
  }
}

/// An address's supply and borrow position on one integration and chain. Decimal values are
/// strings; a `nil` health factor means unknown, never safe.
public struct YieldXyzBorrowPosition: Codable, Equatable {
  public let address: String
  public let integrationId: String
  /// CAIP-2 for chains Portal supports; the Yield.xyz network name otherwise.
  public let network: String
  public let totalSuppliedUsd: String
  public let totalCollateralUsd: String
  public let totalBorrowedUsd: String
  public let netWorthUsd: String
  /// Always sent; `nil` when unknown.
  public let healthFactor: String?
  public let currentLtv: String
  /// Always sent; `nil` when unknown.
  public let availableToBorrowUsd: String?
  public let netApy: String
  public let supplyBalances: [YieldXyzBorrowSupplyBalance]
  public let debtBalances: [YieldXyzBorrowDebtBalance]

  public init(
    address: String,
    integrationId: String,
    network: String,
    totalSuppliedUsd: String,
    totalCollateralUsd: String,
    totalBorrowedUsd: String,
    netWorthUsd: String,
    healthFactor: String? = nil,
    currentLtv: String,
    availableToBorrowUsd: String? = nil,
    netApy: String,
    supplyBalances: [YieldXyzBorrowSupplyBalance],
    debtBalances: [YieldXyzBorrowDebtBalance]
  ) {
    self.address = address
    self.integrationId = integrationId
    self.network = network
    self.totalSuppliedUsd = totalSuppliedUsd
    self.totalCollateralUsd = totalCollateralUsd
    self.totalBorrowedUsd = totalBorrowedUsd
    self.netWorthUsd = netWorthUsd
    self.healthFactor = healthFactor
    self.currentLtv = currentLtv
    self.availableToBorrowUsd = availableToBorrowUsd
    self.netApy = netApy
    self.supplyBalances = supplyBalances
    self.debtBalances = debtBalances
  }
}
