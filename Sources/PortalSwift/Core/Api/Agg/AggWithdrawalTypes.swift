//
//  AggWithdrawalTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

public struct AggWithdrawalLeg: Codable, Equatable {
  public let type: String
  /// `planned` → `submitted` → `confirmed`, or `failed`.
  public let status: String
  public let sourceChainId: String
  public let destChainId: String
  public let amountRaw: String
  public let txHash: String?
  public let bridgeOperationId: String?
  public let sourceTokenSymbol: String?
  /// Status endpoint only.
  public let errorMessage: String?

  public init(
    type: String,
    status: String,
    sourceChainId: String,
    destChainId: String,
    amountRaw: String,
    txHash: String? = nil,
    bridgeOperationId: String? = nil,
    sourceTokenSymbol: String? = nil,
    errorMessage: String? = nil
  ) {
    self.type = type
    self.status = status
    self.sourceChainId = sourceChainId
    self.destChainId = destChainId
    self.amountRaw = amountRaw
    self.txHash = txHash
    self.bridgeOperationId = bridgeOperationId
    self.sourceTokenSymbol = sourceTokenSymbol
    self.errorMessage = errorMessage
  }
}

public struct AggWithdrawalSource: Codable, Equatable {
  public let sourceId: String
  public let chainId: String
  public let tokenSymbol: AggTokenSymbol
  public let tokenAddress: String
  public let decimals: Int
  public let amountRaw: String
  public let custodyKind: AggCustodyKind?
  public let venue: AggVenue?
  public let sourceVenueAccountId: String?
  public let sourceExternalAccountId: String?
  public let status: String
  public let txHash: String?
  public let bridgeOperationId: String?
  public let pendingReason: String?

  public init(
    sourceId: String,
    chainId: String,
    tokenSymbol: AggTokenSymbol,
    tokenAddress: String,
    decimals: Int,
    amountRaw: String,
    custodyKind: AggCustodyKind? = nil,
    venue: AggVenue? = nil,
    sourceVenueAccountId: String? = nil,
    sourceExternalAccountId: String? = nil,
    status: String,
    txHash: String? = nil,
    bridgeOperationId: String? = nil,
    pendingReason: String? = nil
  ) {
    self.sourceId = sourceId
    self.chainId = chainId
    self.tokenSymbol = tokenSymbol
    self.tokenAddress = tokenAddress
    self.decimals = decimals
    self.amountRaw = amountRaw
    self.custodyKind = custodyKind
    self.venue = venue
    self.sourceVenueAccountId = sourceVenueAccountId
    self.sourceExternalAccountId = sourceExternalAccountId
    self.status = status
    self.txHash = txHash
    self.bridgeOperationId = bridgeOperationId
    self.pendingReason = pendingReason
  }
}

/// A withdrawal. `legs` is the only place a transaction hash appears, one per hop.
public struct AggWithdrawal: Codable, Equatable {
  public let withdrawalId: String
  /// One of `pending`, `bridging`, `transferring`, `completed`, `partial`, `failed`.
  public let status: AggWithdrawalStatus
  public let requested: Requested
  public let completedAmountRaw: String?
  public let destination: Destination
  public let legs: [AggWithdrawalLeg]
  public let expected: Expected
  /// One of `unquoted`, `quoting`, `quoted`, `unviable`.
  public let pricingStatus: AggWithdrawalPricingStatus
  public let errorMessage: String?
  public let sources: [AggWithdrawalSource]

  public init(
    withdrawalId: String,
    status: AggWithdrawalStatus,
    requested: Requested,
    completedAmountRaw: String? = nil,
    destination: Destination,
    legs: [AggWithdrawalLeg],
    expected: Expected,
    pricingStatus: AggWithdrawalPricingStatus,
    errorMessage: String? = nil,
    sources: [AggWithdrawalSource]
  ) {
    self.withdrawalId = withdrawalId
    self.status = status
    self.requested = requested
    self.completedAmountRaw = completedAmountRaw
    self.destination = destination
    self.legs = legs
    self.expected = expected
    self.pricingStatus = pricingStatus
    self.errorMessage = errorMessage
    self.sources = sources
  }

  public struct Requested: Codable, Equatable {
    public let tokenSymbol: AggTokenSymbol
    public let amountRaw: String

    public init(tokenSymbol: AggTokenSymbol, amountRaw: String) {
      self.tokenSymbol = tokenSymbol
      self.amountRaw = amountRaw
    }
  }

  public struct Destination: Codable, Equatable {
    public let chainId: String
    public let address: String
    public let tokenSymbol: AggTokenSymbol

    public init(chainId: String, address: String, tokenSymbol: AggTokenSymbol) {
      self.chainId = chainId
      self.address = address
      self.tokenSymbol = tokenSymbol
    }
  }

  public struct Expected: Codable, Equatable {
    public let outputRaw: String?
    public let feeRaw: String?
    public let etaSeconds: Int?

    public init(outputRaw: String? = nil, feeRaw: String? = nil, etaSeconds: Int? = nil) {
      self.outputRaw = outputRaw
      self.feeRaw = feeRaw
      self.etaSeconds = etaSeconds
    }
  }
}

/// A withdrawal's fees and receive amount. Dispatches nothing.
public struct AggWithdrawalPreview: Codable, Equatable {
  public let receiveAmountRaw: String?
  public let feeRaw: String?
  public let relayFeeRaw: String?
  public let networkFeeRaw: String?
  /// `quoted` or `unviable`.
  public let pricingStatus: AggWithdrawalPricingStatus
  public let quoteExpiresAt: String?
  public let unviableReason: String?
  public let maxDeliverableRaw: String?

  public init(
    receiveAmountRaw: String? = nil,
    feeRaw: String? = nil,
    relayFeeRaw: String? = nil,
    networkFeeRaw: String? = nil,
    pricingStatus: AggWithdrawalPricingStatus,
    quoteExpiresAt: String? = nil,
    unviableReason: String? = nil,
    maxDeliverableRaw: String? = nil
  ) {
    self.receiveAmountRaw = receiveAmountRaw
    self.feeRaw = feeRaw
    self.relayFeeRaw = relayFeeRaw
    self.networkFeeRaw = networkFeeRaw
    self.pricingStatus = pricingStatus
    self.quoteExpiresAt = quoteExpiresAt
    self.unviableReason = unviableReason
    self.maxDeliverableRaw = maxDeliverableRaw
  }
}

/// How much can leave, to a given chain.
public struct AggWithdrawableQuote: Codable, Equatable {
  public let tokenSymbol: AggTokenSymbol
  public let destinationChainId: String
  public let maxDeliverableRaw: String
  public let rawBalanceRaw: String
  public let decimals: Int

  public init(
    tokenSymbol: AggTokenSymbol,
    destinationChainId: String,
    maxDeliverableRaw: String,
    rawBalanceRaw: String,
    decimals: Int
  ) {
    self.tokenSymbol = tokenSymbol
    self.destinationChainId = destinationChainId
    self.maxDeliverableRaw = maxDeliverableRaw
    self.rawBalanceRaw = rawBalanceRaw
    self.decimals = decimals
  }
}
