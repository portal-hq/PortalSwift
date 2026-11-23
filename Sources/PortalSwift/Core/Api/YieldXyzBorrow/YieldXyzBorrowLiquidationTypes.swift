//
//  YieldXyzBorrowLiquidationTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// The debt a liquidation repaid. Decimal values are strings.
public struct YieldXyzBorrowRepaidDebt: Codable, Equatable {
  public let tokenAddress: String
  public let tokenSymbol: String
  public let amount: String
  public let amountRaw: String
  /// Always sent; `nil` when unknown.
  public let amountUsd: String?
  public let shares: String

  public init(tokenAddress: String, tokenSymbol: String, amount: String, amountRaw: String, amountUsd: String? = nil, shares: String) {
    self.tokenAddress = tokenAddress
    self.tokenSymbol = tokenSymbol
    self.amount = amount
    self.amountRaw = amountRaw
    self.amountUsd = amountUsd
    self.shares = shares
  }
}

/// The collateral a liquidation seized. Decimal values are strings.
public struct YieldXyzBorrowSeizedCollateral: Codable, Equatable {
  public let tokenAddress: String
  public let tokenSymbol: String
  public let amount: String
  public let amountRaw: String
  /// Always sent; `nil` when unknown.
  public let amountUsd: String?

  public init(tokenAddress: String, tokenSymbol: String, amount: String, amountRaw: String, amountUsd: String? = nil) {
    self.tokenAddress = tokenAddress
    self.tokenSymbol = tokenSymbol
    self.amount = amount
    self.amountRaw = amountRaw
    self.amountUsd = amountUsd
  }
}

/// The bad debt a liquidation realized. Decimal values are strings.
public struct YieldXyzBorrowBadDebt: Codable, Equatable {
  public let amountRaw: String
  public let amount: String
  /// Always sent; `nil` when unknown.
  public let amountUsd: String?
  public let shares: String

  public init(amountRaw: String, amount: String, amountUsd: String? = nil, shares: String) {
    self.amountRaw = amountRaw
    self.amount = amount
    self.amountUsd = amountUsd
    self.shares = shares
  }
}

/// A liquidation of an address's position.
public struct YieldXyzBorrowLiquidation: Codable, Equatable {
  public let id: String
  public let integrationId: String
  /// CAIP-2 for chains Portal supports; the Yield.xyz network name otherwise.
  public let network: String
  public let address: String
  public let marketId: String
  /// Always sent; `nil` when unknown.
  public let type: YieldXyzBorrowLiquidationType?
  public let realizedBadDebt: Bool
  public let occurredAt: String
  public let blockNumber: Int64
  public let transactionHash: String
  public let transactionLink: String
  public let liquidator: String
  public let repaidDebt: YieldXyzBorrowRepaidDebt
  public let seizedCollateral: YieldXyzBorrowSeizedCollateral
  public let badDebt: YieldXyzBorrowBadDebt
  /// The liquidation incentive factor.
  public let lif: String

  public init(
    id: String,
    integrationId: String,
    network: String,
    address: String,
    marketId: String,
    type: YieldXyzBorrowLiquidationType? = nil,
    realizedBadDebt: Bool,
    occurredAt: String,
    blockNumber: Int64,
    transactionHash: String,
    transactionLink: String,
    liquidator: String,
    repaidDebt: YieldXyzBorrowRepaidDebt,
    seizedCollateral: YieldXyzBorrowSeizedCollateral,
    badDebt: YieldXyzBorrowBadDebt,
    lif: String
  ) {
    self.id = id
    self.integrationId = integrationId
    self.network = network
    self.address = address
    self.marketId = marketId
    self.type = type
    self.realizedBadDebt = realizedBadDebt
    self.occurredAt = occurredAt
    self.blockNumber = blockNumber
    self.transactionHash = transactionHash
    self.transactionLink = transactionLink
    self.liquidator = liquidator
    self.repaidDebt = repaidDebt
    self.seizedCollateral = seizedCollateral
    self.badDebt = badDebt
    self.lif = lif
  }
}
