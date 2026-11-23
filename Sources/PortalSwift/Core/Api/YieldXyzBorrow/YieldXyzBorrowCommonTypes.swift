//
//  YieldXyzBorrowCommonTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - Envelope

/// The success envelope every Yield.xyz Borrow endpoint returns: `{ "data": ... }`.
public struct YieldXyzBorrowResponse<T: Codable & Equatable>: Codable, Equatable {
  public let data: T

  public init(data: T) {
    self.data = data
  }
}

/// A page of results, as returned by the paginated list endpoints.
public struct YieldXyzBorrowPage<Item: Codable & Equatable>: Codable, Equatable {
  public let total: Int
  public let offset: Int
  public let limit: Int
  public let items: [Item]

  public init(total: Int, offset: Int, limit: Int, items: [Item]) {
    self.total = total
    self.offset = offset
    self.limit = limit
    self.items = items
  }
}

// MARK: - Open values

/// A lending action. Known values are the ones Portal accepts on `createAction`.
public struct YieldXyzBorrowActionType: YieldXyzOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let supply: Self = "supply"
  public static let borrow: Self = "borrow"
  public static let repay: Self = "repay"
  public static let withdraw: Self = "withdraw"
  public static let enableCollateral: Self = "enableCollateral"
  public static let disableCollateral: Self = "disableCollateral"
  public static let supplyAndBorrow: Self = "supplyAndBorrow"
}

/// The lifecycle status of an action. Known values are the ones Portal accepts as `getActions`
/// filters.
public struct YieldXyzBorrowActionStatus: YieldXyzOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let canceled: Self = "CANCELED"
  public static let created: Self = "CREATED"
  public static let waitingForNext: Self = "WAITING_FOR_NEXT"
  public static let processing: Self = "PROCESSING"
  public static let failed: Self = "FAILED"
  public static let success: Self = "SUCCESS"
  public static let stale: Self = "STALE"
}

/// The lifecycle status of a transaction within an action.
public struct YieldXyzBorrowTransactionStatus: YieldXyzOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let notFound: Self = "NOT_FOUND"
  public static let created: Self = "CREATED"
  public static let blocked: Self = "BLOCKED"
  public static let waitingForSignature: Self = "WAITING_FOR_SIGNATURE"
  public static let signed: Self = "SIGNED"
  public static let broadcasted: Self = "BROADCASTED"
  public static let pending: Self = "PENDING"
  public static let confirmed: Self = "CONFIRMED"
  public static let failed: Self = "FAILED"
  public static let skipped: Self = "SKIPPED"
}

/// The kind of a transaction within an action.
public struct YieldXyzBorrowTransactionType: YieldXyzOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let approval: Self = "APPROVAL"
  public static let authorize: Self = "AUTHORIZE"
  public static let deauthorize: Self = "DEAUTHORIZE"
  public static let supply: Self = "SUPPLY"
  public static let borrow: Self = "BORROW"
  public static let repay: Self = "REPAY"
  public static let withdraw: Self = "WITHDRAW"
  public static let enableCollateral: Self = "ENABLE_COLLATERAL"
  public static let disableCollateral: Self = "DISABLE_COLLATERAL"
  public static let bundle: Self = "BUNDLE"
  /// Wraps the native token (e.g. MON → WMON) ahead of a collateral supply.
  public static let wrap: Self = "WRAP"
}

/// How a transaction must be signed. The SDK signs `EVM_TRANSACTION` only.
public struct YieldXyzBorrowSigningFormat: YieldXyzOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let evmTransaction: Self = "EVM_TRANSACTION"
  public static let eip712TypedData: Self = "EIP712_TYPED_DATA"
  public static let solanaTransaction: Self = "SOLANA_TRANSACTION"
  public static let cosmosTransaction: Self = "COSMOS_TRANSACTION"
}

/// The kind of a lending market.
public struct YieldXyzBorrowMarketType: YieldXyzOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  /// A shared pool (e.g. Aave).
  public static let pool: Self = "pool"
  /// An isolated market (e.g. Morpho Blue).
  public static let isolated: Self = "isolated"
}

/// How much of a position a liquidation closed.
public struct YieldXyzBorrowLiquidationType: YieldXyzOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let partial: Self = "partial"
  public static let full: Self = "full"
}

/// The overall Yield.xyz Borrow API health.
public struct YieldXyzBorrowHealthStatusValue: YieldXyzOpenValue {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }

  public static let ok: Self = "OK"
  public static let fail: Self = "FAIL"
}

/// Which markets `getMarkets` lists. The Portal API accepts only these two values.
public enum YieldXyzBorrowMarketScope: String, Codable, Equatable {
  /// The markets enabled in the Yield.xyz dashboard; Yield.xyz applies it when `scope` is omitted.
  case enabled
  /// Every market.
  case all
}
