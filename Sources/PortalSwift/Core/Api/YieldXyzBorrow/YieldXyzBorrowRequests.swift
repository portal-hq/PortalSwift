//
//  YieldXyzBorrowRequests.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Filters for `getMarkets`.
public struct YieldXyzBorrowGetMarketsParams: Equatable {
  public var offset: Int?
  /// 1–100.
  public var limit: Int?
  public var integrationId: String?
  /// A CAIP-2 chain id Portal supports, e.g. `eip155:8453`. Of an integration's `networks`, only the
  /// CAIP-2 entries are accepted.
  public var network: String?
  /// `enabled` lists the markets enabled in the Yield.xyz dashboard; Yield.xyz applies it when
  /// `scope` is omitted.
  public var scope: YieldXyzBorrowMarketScope?

  public init(
    offset: Int? = nil,
    limit: Int? = nil,
    integrationId: String? = nil,
    network: String? = nil,
    scope: YieldXyzBorrowMarketScope? = nil
  ) {
    self.offset = offset
    self.limit = limit
    self.integrationId = integrationId
    self.network = network
    self.scope = scope
  }
}

/// The position `getPositions` reads.
public struct YieldXyzBorrowGetPositionsParams: Equatable {
  public var integrationId: String
  /// A CAIP-2 chain id Portal supports, e.g. `eip155:8453`.
  public var network: String
  /// The wallet's EVM address (the smart-account address for account-abstracted clients).
  public var address: String

  public init(integrationId: String, network: String, address: String) {
    self.integrationId = integrationId
    self.network = network
    self.address = address
  }
}

/// Filters for `getLiquidations`.
public struct YieldXyzBorrowGetLiquidationsParams: Equatable {
  public var offset: Int?
  /// 1–100.
  public var limit: Int?
  public var integrationId: String
  /// A CAIP-2 chain id Portal supports, e.g. `eip155:8453`.
  public var network: String
  public var address: String
  public var marketId: String?

  public init(
    offset: Int? = nil,
    limit: Int? = nil,
    integrationId: String,
    network: String,
    address: String,
    marketId: String? = nil
  ) {
    self.offset = offset
    self.limit = limit
    self.integrationId = integrationId
    self.network = network
    self.address = address
    self.marketId = marketId
  }
}

/// Filters for `getActions`.
public struct YieldXyzBorrowGetActionsParams: Equatable {
  public var offset: Int?
  /// 1–100.
  public var limit: Int?
  public var address: String
  public var integrationId: String?
  public var action: YieldXyzBorrowActionType?
  public var status: YieldXyzBorrowActionStatus?
  public var statuses: [YieldXyzBorrowActionStatus]?

  public init(
    offset: Int? = nil,
    limit: Int? = nil,
    address: String,
    integrationId: String? = nil,
    action: YieldXyzBorrowActionType? = nil,
    status: YieldXyzBorrowActionStatus? = nil,
    statuses: [YieldXyzBorrowActionStatus]? = nil
  ) {
    self.offset = offset
    self.limit = limit
    self.address = address
    self.integrationId = integrationId
    self.action = action
    self.status = status
    self.statuses = statuses
  }
}

/// The action `createAction` builds; sent as the request body. The Portal API rejects keys it does
/// not know, here and in `args`.
public struct YieldXyzBorrowCreateActionParams: Codable, Equatable {
  public var integrationId: String
  public var action: YieldXyzBorrowActionType
  /// The wallet's EVM address (the smart-account address for account-abstracted clients).
  public var address: String
  public var args: YieldXyzBorrowActionArguments

  public init(
    integrationId: String,
    action: YieldXyzBorrowActionType,
    address: String,
    args: YieldXyzBorrowActionArguments
  ) {
    self.integrationId = integrationId
    self.action = action
    self.address = address
    self.args = args
  }
}

/// A submission for one transaction: the hash of a transaction already broadcast, or a signed
/// payload for Yield.xyz to broadcast. At least one is required; empty values are not sent.
public struct YieldXyzBorrowSubmitTransactionParams: Equatable {
  public var transactionHash: String?
  public var signedPayload: String?

  public init(transactionHash: String? = nil, signedPayload: String? = nil) {
    self.transactionHash = transactionHash
    self.signedPayload = signedPayload
  }
}

/// The body of `POST /transactions/{transactionId}/submit`; the transaction id travels in the path.
/// Empty values are not sent: the Portal API rejects an empty string.
struct YieldXyzBorrowSubmitTransactionBody: Codable, Equatable {
  let transactionHash: String?
  let signedPayload: String?

  init(_ params: YieldXyzBorrowSubmitTransactionParams) {
    self.transactionHash = params.transactionHash.flatMap { $0.isEmpty ? nil : $0 }
    self.signedPayload = params.signedPayload.flatMap { $0.isEmpty ? nil : $0 }
  }
}
