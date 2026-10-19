//
//  YieldXyzPerpsActionTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import AnyCodable
import Foundation

/// A transaction within an action. Sign it according to `signingFormat`.
///
/// `network` is a CAIP-2 chain id for on-chain legs (e.g. `eip155:42161`) or an opaque venue
/// identifier (e.g. `hyperliquid`). `chainId` is Yield.xyz's raw chain id and, for EIP-712
/// payloads, the signing domain's chain (e.g. `1337` on Hyperliquid); it is not necessarily a chain
/// Portal can route to.
public struct YieldXyzPerpsTransaction: Codable, Equatable {
  public let id: String
  public let network: String
  public let chainId: String
  public let type: YieldXyzPerpsTransactionType
  public let status: YieldXyzPerpsTransactionStatus
  /// The account the transaction was built for.
  public let address: String
  public let args: YieldXyzPerpsActionArgs?
  public let signingFormat: YieldXyzPerpsSigningFormat?
  /// Opaque, returned byte-for-byte: EIP-712 typed data (an object) for `EIP712_TYPED_DATA`, or a
  /// JSON-encoded unsigned transaction for `EVM_TRANSACTION`. Any JSON value.
  public let signablePayload: AnyCodable?
  /// Opaque: the venue payload the signature commits to, returned byte-for-byte. Any JSON value.
  public let rawPayload: AnyCodable?
  /// Why a `FAILED` transaction failed, when the venue says.
  public let error: YieldXyzPerpsTransactionError?
  public let explorerUrls: [String]

  public init(
    id: String,
    network: String,
    chainId: String,
    type: YieldXyzPerpsTransactionType,
    status: YieldXyzPerpsTransactionStatus,
    address: String,
    args: YieldXyzPerpsActionArgs? = nil,
    signingFormat: YieldXyzPerpsSigningFormat? = nil,
    signablePayload: AnyCodable? = nil,
    rawPayload: AnyCodable? = nil,
    error: YieldXyzPerpsTransactionError? = nil,
    explorerUrls: [String]
  ) {
    self.id = id
    self.network = network
    self.chainId = chainId
    self.type = type
    self.status = status
    self.address = address
    self.args = args
    self.signingFormat = signingFormat
    self.signablePayload = signablePayload
    self.rawPayload = rawPayload
    self.error = error
    self.explorerUrls = explorerUrls
  }
}

/// Why a `FAILED` transaction failed, as the Portal API reports it: the venue's string `code` and
/// `message`, when it sends them.
public struct YieldXyzPerpsTransactionError: Codable, Equatable {
  /// The venue's machine-readable code. Open-ended: compare against known values, never assume a
  /// closed set.
  public let code: String?
  /// The venue's reason. Fine to show the user; do not parse it.
  public let message: String?

  public init(code: String? = nil, message: String? = nil) {
    self.code = code
    self.message = message
  }

  private enum CodingKeys: String, CodingKey {
    case code, message
  }

  /// Never fails: a key that is not a string is read as `nil`, and a bare string is the message,
  /// as the Portal API maps a venue's error.
  public init(from decoder: Decoder) throws {
    if let container = try? decoder.container(keyedBy: CodingKeys.self) {
      self.code = try? container.decodeIfPresent(String.self, forKey: .code)
      self.message = try? container.decodeIfPresent(String.self, forKey: .message)
    } else {
      self.code = nil
      self.message = try? decoder.singleValueContainer().decode(String.self)
    }
  }
}

/// A human-readable summary of what an action does. Only `type` is guaranteed; show the fields
/// that are present (for example `estimatedLiquidationPrice`) before the user signs.
public struct YieldXyzPerpsActionSummary: Codable, Equatable {
  /// A label such as `Open Position`.
  public let type: String
  public let assetId: Int?
  public let orderType: YieldXyzPerpsOrderType?
  public let direction: YieldXyzPerpsSide?
  public let asset: String?
  public let price: Double?
  public let size: String?
  public let leverage: Double?
  public let collateral: String?
  public let fee: String?
  public let orderValue: Double?
  public let stopLoss: Double?
  public let takeProfit: Double?
  public let oldLiquidationPrice: Double?
  public let estimatedLiquidationPrice: Double?
  public let oldStopLoss: Double?
  public let oldTakeProfit: Double?
  public let marginMode: YieldXyzPerpsMarginMode?
  public let orderId: String?
  public let orderIds: [String]?
  /// Known values: `tp`, `sl`.
  public let cancelledOrderTypes: [String]?
  public let amount: String?
  public let fromToken: YieldXyzPerpsTokenIdentifier?
  public let method: String?
  public let agentAddress: String?
  public let agentName: String?
  public let enabled: Bool?
  public let closedPrice: Double?
  public let pnl: String?
  /// A decimal string here, unlike `YieldXyzPerpsPosition.margin`.
  public let margin: String?
  public let entryPrice: Double?
  public let exitPrice: Double?

  public init(
    type: String,
    assetId: Int? = nil,
    orderType: YieldXyzPerpsOrderType? = nil,
    direction: YieldXyzPerpsSide? = nil,
    asset: String? = nil,
    price: Double? = nil,
    size: String? = nil,
    leverage: Double? = nil,
    collateral: String? = nil,
    fee: String? = nil,
    orderValue: Double? = nil,
    stopLoss: Double? = nil,
    takeProfit: Double? = nil,
    oldLiquidationPrice: Double? = nil,
    estimatedLiquidationPrice: Double? = nil,
    oldStopLoss: Double? = nil,
    oldTakeProfit: Double? = nil,
    marginMode: YieldXyzPerpsMarginMode? = nil,
    orderId: String? = nil,
    orderIds: [String]? = nil,
    cancelledOrderTypes: [String]? = nil,
    amount: String? = nil,
    fromToken: YieldXyzPerpsTokenIdentifier? = nil,
    method: String? = nil,
    agentAddress: String? = nil,
    agentName: String? = nil,
    enabled: Bool? = nil,
    closedPrice: Double? = nil,
    pnl: String? = nil,
    margin: String? = nil,
    entryPrice: Double? = nil,
    exitPrice: Double? = nil
  ) {
    self.type = type
    self.assetId = assetId
    self.orderType = orderType
    self.direction = direction
    self.asset = asset
    self.price = price
    self.size = size
    self.leverage = leverage
    self.collateral = collateral
    self.fee = fee
    self.orderValue = orderValue
    self.stopLoss = stopLoss
    self.takeProfit = takeProfit
    self.oldLiquidationPrice = oldLiquidationPrice
    self.estimatedLiquidationPrice = estimatedLiquidationPrice
    self.oldStopLoss = oldStopLoss
    self.oldTakeProfit = oldTakeProfit
    self.marginMode = marginMode
    self.orderId = orderId
    self.orderIds = orderIds
    self.cancelledOrderTypes = cancelledOrderTypes
    self.amount = amount
    self.fromToken = fromToken
    self.method = method
    self.agentAddress = agentAddress
    self.agentName = agentName
    self.enabled = enabled
    self.closedPrice = closedPrice
    self.pnl = pnl
    self.margin = margin
    self.entryPrice = entryPrice
    self.exitPrice = exitPrice
  }
}

/// An action with its transactions, in signing order, and its status.
public struct YieldXyzPerpsAction: Codable, Equatable {
  public let id: String
  public let providerId: String
  public let action: YieldXyzPerpsActionType
  public let status: YieldXyzPerpsActionStatus
  /// Always present in the response; `nil` when the venue returns no summary.
  public let summary: YieldXyzPerpsActionSummary?
  /// A hex string Yield.xyz signs that describes the action; `nil` when there is none (for example
  /// on `fund` actions). Not needed to sign or submit.
  public let signedMetadata: String?
  public let transactions: [YieldXyzPerpsTransaction]
  /// ISO-8601.
  public let createdAt: String
  /// ISO-8601; `nil` until the action completes.
  public let completedAt: String?

  public init(
    id: String,
    providerId: String,
    action: YieldXyzPerpsActionType,
    status: YieldXyzPerpsActionStatus,
    summary: YieldXyzPerpsActionSummary? = nil,
    signedMetadata: String? = nil,
    transactions: [YieldXyzPerpsTransaction],
    createdAt: String,
    completedAt: String? = nil
  ) {
    self.id = id
    self.providerId = providerId
    self.action = action
    self.status = status
    self.summary = summary
    self.signedMetadata = signedMetadata
    self.transactions = transactions
    self.createdAt = createdAt
    self.completedAt = completedAt
  }

  private enum CodingKeys: String, CodingKey {
    case id, providerId, action, status, summary, signedMetadata, transactions, createdAt, completedAt
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(String.self, forKey: .id)
    self.providerId = try container.decode(String.self, forKey: .providerId)
    self.action = try container.decode(YieldXyzPerpsActionType.self, forKey: .action)
    self.status = try container.decode(YieldXyzPerpsActionStatus.self, forKey: .status)
    self.summary = try container.decodeIfPresent(YieldXyzPerpsActionSummary.self, forKey: .summary)
    // Yield.xyz's spec types it as an object but sends a hex string: anything else reads as `nil`
    // instead of failing the whole action.
    self.signedMetadata = try? container.decodeIfPresent(String.self, forKey: .signedMetadata)
    self.transactions = try container.decode([YieldXyzPerpsTransaction].self, forKey: .transactions)
    self.createdAt = try container.decode(String.self, forKey: .createdAt)
    self.completedAt = try container.decodeIfPresent(String.self, forKey: .completedAt)
  }
}

/// The result of submitting a signature or a broadcast transaction hash.
public struct YieldXyzPerpsSubmitResult: Codable, Equatable {
  /// Absent for immediate venue actions.
  public let transactionHash: String?
  public let link: String
  /// `FAILED` means the venue rejected the transaction even though the request succeeded.
  public let status: YieldXyzPerpsTransactionStatus
  /// Present only when `status` is `FAILED`.
  public let error: String?
  /// Provider-specific fill details, opaque.
  public let details: [String: AnyCodable]?

  public init(
    transactionHash: String? = nil,
    link: String,
    status: YieldXyzPerpsTransactionStatus,
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
