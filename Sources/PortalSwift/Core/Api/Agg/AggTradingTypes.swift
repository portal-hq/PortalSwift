//
//  AggTradingTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

public struct AggSetupCost: Codable, Equatable {
  /// One of `chainApproval`, `venueMarketAta`, `hyperliquidActivation`.
  public let kind: String
  public let venue: AggVenue
  public let chainId: String?
  public let venueMarketId: String?
  public let costUsd: Double
  public let alreadyPaid: Bool

  public init(
    kind: String,
    venue: AggVenue,
    chainId: String? = nil,
    venueMarketId: String? = nil,
    costUsd: Double,
    alreadyPaid: Bool
  ) {
    self.kind = kind
    self.venue = venue
    self.chainId = chainId
    self.venueMarketId = venueMarketId
    self.costUsd = costUsd
    self.alreadyPaid = alreadyPaid
  }
}

public struct AggFeeBreakdown: Codable, Equatable {
  public let rawExecCost: Double
  public let venueFees: Double
  public let builderFee: Double?
  public let executionReserve: Double?
  public let bridgeFees: Double
  public let executionGas: Double
  public let totalCost: Double
  public let appFee: Double?
  public let appFeeBips: Double?
  /// Keyed by venue slug.
  public let appFeeBipsByVenue: [String: Double]?
  public let appFeeCategory: String?
  public let referralFee: Double?
  /// Keyed by venue slug.
  public let referralFeeBipsByVenue: [String: Double]?
  public let setupCosts: [AggSetupCost]?
  public let setupCostsTotal: Double?
  public let gasReimbursement: Double?

  public init(
    rawExecCost: Double,
    venueFees: Double,
    builderFee: Double? = nil,
    executionReserve: Double? = nil,
    bridgeFees: Double,
    executionGas: Double,
    totalCost: Double,
    appFee: Double? = nil,
    appFeeBips: Double? = nil,
    appFeeBipsByVenue: [String: Double]? = nil,
    appFeeCategory: String? = nil,
    referralFee: Double? = nil,
    referralFeeBipsByVenue: [String: Double]? = nil,
    setupCosts: [AggSetupCost]? = nil,
    setupCostsTotal: Double? = nil,
    gasReimbursement: Double? = nil
  ) {
    self.rawExecCost = rawExecCost
    self.venueFees = venueFees
    self.builderFee = builderFee
    self.executionReserve = executionReserve
    self.bridgeFees = bridgeFees
    self.executionGas = executionGas
    self.totalCost = totalCost
    self.appFee = appFee
    self.appFeeBips = appFeeBips
    self.appFeeBipsByVenue = appFeeBipsByVenue
    self.appFeeCategory = appFeeCategory
    self.referralFee = referralFee
    self.referralFeeBipsByVenue = referralFeeBipsByVenue
    self.setupCosts = setupCosts
    self.setupCostsTotal = setupCostsTotal
    self.gasReimbursement = gasReimbursement
  }
}

public struct AggBookFill: Codable, Equatable {
  public let price: Double
  public let size: Double
  public let fill: Double

  public init(price: Double, size: Double, fill: Double) {
    self.price = price
    self.size = size
    self.fill = fill
  }
}

public struct AggVenueFill: Codable, Equatable {
  public let venue: AggVenue
  public let venueMarketId: String
  public let venueMarketOutcomeId: String
  /// CAIP-2 chain the part settles on, or `venue-cash` for cash at a venue.
  public let chain: String
  public let inAmount: String?
  public let outAmount: String?
  public let limitPriceMicroUsdc: String?
  public let avgPrice: Double
  public let yesPrice: Double
  public let noPrice: Double
  public let fills: [AggBookFill]
  /// ProphetX only: `clearinghouse` or `direct`.
  public let executionBackend: String?
  public let venueAccountId: String?
  public let venueQty: Double
  public let venueFee: Double?
  public let builderFee: Double?
  public let settlementFee: Double?
  public let executionReserve: Double?
  public let feeReserve: Double?
  /// Milliseconds.
  public let bookAgeMs: Int?
  /// `r3` or `r4`.
  public let freshnessRow: String?

  public init(
    venue: AggVenue,
    venueMarketId: String,
    venueMarketOutcomeId: String,
    chain: String,
    inAmount: String? = nil,
    outAmount: String? = nil,
    limitPriceMicroUsdc: String? = nil,
    avgPrice: Double,
    yesPrice: Double,
    noPrice: Double,
    fills: [AggBookFill],
    executionBackend: String? = nil,
    venueAccountId: String? = nil,
    venueQty: Double,
    venueFee: Double? = nil,
    builderFee: Double? = nil,
    settlementFee: Double? = nil,
    executionReserve: Double? = nil,
    feeReserve: Double? = nil,
    bookAgeMs: Int? = nil,
    freshnessRow: String? = nil
  ) {
    self.venue = venue
    self.venueMarketId = venueMarketId
    self.venueMarketOutcomeId = venueMarketOutcomeId
    self.chain = chain
    self.inAmount = inAmount
    self.outAmount = outAmount
    self.limitPriceMicroUsdc = limitPriceMicroUsdc
    self.avgPrice = avgPrice
    self.yesPrice = yesPrice
    self.noPrice = noPrice
    self.fills = fills
    self.executionBackend = executionBackend
    self.venueAccountId = venueAccountId
    self.venueQty = venueQty
    self.venueFee = venueFee
    self.builderFee = builderFee
    self.settlementFee = settlementFee
    self.executionReserve = executionReserve
    self.feeReserve = feeReserve
    self.bookAgeMs = bookAgeMs
    self.freshnessRow = freshnessRow
  }
}

public struct AggAllocation: Codable, Equatable {
  public let sourceChainId: String
  public let venue: AggVenue
  public let amount: Double
  public let sourceTokenAddress: String?
  public let sourceTokenSymbol: String?
  /// One of `EOA`, `DEPOSIT_WALLET`, `POLYMARKET_LEGACY`, `VENUE_ACCOUNT`.
  public let custodyKind: AggCustodyKind?
  public let custodyAddress: String?
  public let sourceVenueAccountId: String?
  public let sourceExternalAccountId: String?
  public let sourceAddress: String?
  public let exactToken: Bool?

  public init(
    sourceChainId: String,
    venue: AggVenue,
    amount: Double,
    sourceTokenAddress: String? = nil,
    sourceTokenSymbol: String? = nil,
    custodyKind: AggCustodyKind? = nil,
    custodyAddress: String? = nil,
    sourceVenueAccountId: String? = nil,
    sourceExternalAccountId: String? = nil,
    sourceAddress: String? = nil,
    exactToken: Bool? = nil
  ) {
    self.sourceChainId = sourceChainId
    self.venue = venue
    self.amount = amount
    self.sourceTokenAddress = sourceTokenAddress
    self.sourceTokenSymbol = sourceTokenSymbol
    self.custodyKind = custodyKind
    self.custodyAddress = custodyAddress
    self.sourceVenueAccountId = sourceVenueAccountId
    self.sourceExternalAccountId = sourceExternalAccountId
    self.sourceAddress = sourceAddress
    self.exactToken = exactToken
  }
}

public struct AggBridgeStep: Codable, Equatable {
  public let sourceChainId: String
  public let destChainId: String
  public let amount: Double
  public let cost: Double
  public let sourceTokenAddress: String?
  public let destTokenAddress: String?
  public let sourceTokenSymbol: String?
  public let destTokenSymbol: String?

  public init(
    sourceChainId: String,
    destChainId: String,
    amount: Double,
    cost: Double,
    sourceTokenAddress: String? = nil,
    destTokenAddress: String? = nil,
    sourceTokenSymbol: String? = nil,
    destTokenSymbol: String? = nil
  ) {
    self.sourceChainId = sourceChainId
    self.destChainId = destChainId
    self.amount = amount
    self.cost = cost
    self.sourceTokenAddress = sourceTokenAddress
    self.destTokenAddress = destTokenAddress
    self.sourceTokenSymbol = sourceTokenSymbol
    self.destTokenSymbol = destTokenSymbol
  }
}

public struct AggQuoteFailure: Codable, Equatable {
  public let venue: AggVenue
  /// The venue quoting service's error code. Open set.
  public let code: String
  public let retryAt: String?

  public init(venue: AggVenue, code: String, retryAt: String? = nil) {
    self.venue = venue
    self.code = code
    self.retryAt = retryAt
  }
}

public struct AggVenueSoloQuote: Codable, Equatable {
  public let quoteFailure: AggQuoteFailure?
  /// Quote id to fill on this venue alone; `nil` when display-only.
  public let quoteId: String?
  /// Why this venue cannot be filled alone, e.g. `geo_blocked`. Open set.
  public let unavailableReason: String?
  public let venue: AggVenue
  public let venueMarketOutcomeId: String?
  public let avgPrice: Double?
  public let filledQty: Double
  public let rawExecCost: Double
  public let estimatedPayout: Double
  public let estimatedProfit: Double
  public let returnPct: Double
  public let totalCostIncFees: Double?
  public let status: String
  public let fills: [AggVenueFill]
  public let allocations: [AggAllocation]?
  public let bridgeSteps: [AggBridgeStep]?
  public let setupCosts: [AggSetupCost]?
  public let setupCostsTotal: Double?
  public let feeBreakdown: AggFeeBreakdown?

  public init(
    quoteFailure: AggQuoteFailure? = nil,
    quoteId: String? = nil,
    unavailableReason: String? = nil,
    venue: AggVenue,
    venueMarketOutcomeId: String? = nil,
    avgPrice: Double? = nil,
    filledQty: Double,
    rawExecCost: Double,
    estimatedPayout: Double,
    estimatedProfit: Double,
    returnPct: Double,
    totalCostIncFees: Double? = nil,
    status: String,
    fills: [AggVenueFill],
    allocations: [AggAllocation]? = nil,
    bridgeSteps: [AggBridgeStep]? = nil,
    setupCosts: [AggSetupCost]? = nil,
    setupCostsTotal: Double? = nil,
    feeBreakdown: AggFeeBreakdown? = nil
  ) {
    self.quoteFailure = quoteFailure
    self.quoteId = quoteId
    self.unavailableReason = unavailableReason
    self.venue = venue
    self.venueMarketOutcomeId = venueMarketOutcomeId
    self.avgPrice = avgPrice
    self.filledQty = filledQty
    self.rawExecCost = rawExecCost
    self.estimatedPayout = estimatedPayout
    self.estimatedProfit = estimatedProfit
    self.returnPct = returnPct
    self.totalCostIncFees = totalCostIncFees
    self.status = status
    self.fills = fills
    self.allocations = allocations
    self.bridgeSteps = bridgeSteps
    self.setupCosts = setupCosts
    self.setupCostsTotal = setupCostsTotal
    self.feeBreakdown = feeBreakdown
  }
}

public struct AggSlippage: Codable, Equatable {
  public let vwap: Double
  public let refMidpoint: Double
  public let slippage: Double
  public let slippageBps: Double

  public init(
    vwap: Double,
    refMidpoint: Double,
    slippage: Double,
    slippageBps: Double
  ) {
    self.vwap = vwap
    self.refMidpoint = refMidpoint
    self.slippage = slippage
    self.slippageBps = slippageBps
  }
}

public struct AggQuoteWarning: Codable, Equatable {
  public let venue: AggVenue
  public let venueMarketOutcomeId: String
  /// Why the venue cannot fill. Either a code such as `stale_orderbook` or
  /// `min_order_size_violated`, or readable text such as "Venue not available in your region (US)";
  /// show it as is.
  public let reason: String

  public init(venue: AggVenue, venueMarketOutcomeId: String, reason: String) {
    self.venue = venue
    self.venueMarketOutcomeId = venueMarketOutcomeId
    self.reason = reason
  }
}

public struct AggSettlementPlan: Codable, Equatable {
  public let redeemId: String
  /// `redeem_only` or `partial_redeem`.
  public let status: String
  public let message: String
  public let totalRedeemableShares: Double
  public let totalRedeemShares: Double
  public let totalSellShares: Double
  public let redeemLegs: [RedeemLeg]

  public init(
    redeemId: String,
    status: String,
    message: String,
    totalRedeemableShares: Double,
    totalRedeemShares: Double,
    totalSellShares: Double,
    redeemLegs: [RedeemLeg]
  ) {
    self.redeemId = redeemId
    self.status = status
    self.message = message
    self.totalRedeemableShares = totalRedeemableShares
    self.totalRedeemShares = totalRedeemShares
    self.totalSellShares = totalSellShares
    self.redeemLegs = redeemLegs
  }

  public struct RedeemLeg: Codable, Equatable {
    public let action: String
    public let venue: AggVenue
    public let venueMarketId: String
    public let venueMarketOutcomeId: String
    public let positionId: String
    /// Shares, as a decimal string.
    public let size: String
    /// `evm` or `svm`.
    public let redeemPath: String

    public init(
      action: String,
      venue: AggVenue,
      venueMarketId: String,
      venueMarketOutcomeId: String,
      positionId: String,
      size: String,
      redeemPath: String
    ) {
      self.action = action
      self.venue = venue
      self.venueMarketId = venueMarketId
      self.venueMarketOutcomeId = venueMarketOutcomeId
      self.positionId = positionId
      self.size = size
      self.redeemPath = redeemPath
    }
  }
}

/// A quote across venues. Only `status: "ok"` with no `warnings` is tradable; branch per venue on
/// `venueSoloQuotes[].unavailableReason`. Quotes expire at `expiresAt`.
public struct AggQuote: Codable, Equatable {
  public let quoteId: String
  public let status: AggQuoteStatus
  public let error: String?
  public let createdAt: String?
  public let expiresAt: String
  public let refreshAt: String
  public let quoteRefreshNotBefore: String?
  public let quoteFailure: AggQuoteFailure?
  public let venueMarketId: String
  public let venueMarketOutcomeId: String
  /// `buy` or `sell`.
  public let tradeSide: String?
  /// Echo of a sell request.
  public let sellShares: Double?
  /// The user's Polymarket deposit wallet.
  public let depositWalletAddress: String?
  public let estimatedCostRaw: String
  public let rawExecCost: Double
  public let totalFilled: Double
  /// Milliseconds.
  public let solveTimeMs: Double
  public let verifyTimeMs: Double
  public let estDurationMs: Int?
  public let fills: [AggVenueFill]
  public let matchedMarkets: [MatchedMarket]
  public let venueSoloQuotes: [AggVenueSoloQuote]?
  public let allocations: [AggAllocation]?
  public let bridgeSteps: [AggBridgeStep]?
  public let feeBreakdown: AggFeeBreakdown?
  /// App fee terms frozen at quote time; `nil` when the app charges none.
  public let appFee: AppFee?
  /// The referral this quote pays; `nil` without a referrer.
  public let referral: Referral?
  public let slippage: AggSlippage?
  /// The best each objective could reach on its own, for comparison.
  public let optima: Optima?
  public let warnings: [AggQuoteWarning]?
  public let message: String?
  public let settlementPlan: AggSettlementPlan?
  public let estimatedPayout: Double?
  public let totalCostIncFees: Double?
  /// What a sell nets after fees.
  public let estimatedNetProceeds: Double?
  public let estimatedProfit: Double?
  public let returnPct: Double?
  /// Sell quotes: the shares the user can sell, where.
  public let positionAvailability: PositionAvailability?
  /// Limit-order size constraints, in 6-decimal share units: a multiple of `sizeStepRaw`, at least
  /// `minSizeRaw`.
  public let sizeStepRaw: String?
  public let minSizeRaw: String?
  /// Worst accepted price per leg, before venue fees.
  public let legBounds: [LegBound]?

  public init(
    quoteId: String,
    status: AggQuoteStatus,
    error: String? = nil,
    createdAt: String? = nil,
    expiresAt: String,
    refreshAt: String,
    quoteRefreshNotBefore: String? = nil,
    quoteFailure: AggQuoteFailure? = nil,
    venueMarketId: String,
    venueMarketOutcomeId: String,
    tradeSide: String? = nil,
    sellShares: Double? = nil,
    depositWalletAddress: String? = nil,
    estimatedCostRaw: String,
    rawExecCost: Double,
    totalFilled: Double,
    solveTimeMs: Double,
    verifyTimeMs: Double,
    estDurationMs: Int? = nil,
    fills: [AggVenueFill],
    matchedMarkets: [MatchedMarket],
    venueSoloQuotes: [AggVenueSoloQuote]? = nil,
    allocations: [AggAllocation]? = nil,
    bridgeSteps: [AggBridgeStep]? = nil,
    feeBreakdown: AggFeeBreakdown? = nil,
    appFee: AppFee? = nil,
    referral: Referral? = nil,
    slippage: AggSlippage? = nil,
    optima: Optima? = nil,
    warnings: [AggQuoteWarning]? = nil,
    message: String? = nil,
    settlementPlan: AggSettlementPlan? = nil,
    estimatedPayout: Double? = nil,
    totalCostIncFees: Double? = nil,
    estimatedNetProceeds: Double? = nil,
    estimatedProfit: Double? = nil,
    returnPct: Double? = nil,
    positionAvailability: PositionAvailability? = nil,
    sizeStepRaw: String? = nil,
    minSizeRaw: String? = nil,
    legBounds: [LegBound]? = nil
  ) {
    self.quoteId = quoteId
    self.status = status
    self.error = error
    self.createdAt = createdAt
    self.expiresAt = expiresAt
    self.refreshAt = refreshAt
    self.quoteRefreshNotBefore = quoteRefreshNotBefore
    self.quoteFailure = quoteFailure
    self.venueMarketId = venueMarketId
    self.venueMarketOutcomeId = venueMarketOutcomeId
    self.tradeSide = tradeSide
    self.sellShares = sellShares
    self.depositWalletAddress = depositWalletAddress
    self.estimatedCostRaw = estimatedCostRaw
    self.rawExecCost = rawExecCost
    self.totalFilled = totalFilled
    self.solveTimeMs = solveTimeMs
    self.verifyTimeMs = verifyTimeMs
    self.estDurationMs = estDurationMs
    self.fills = fills
    self.matchedMarkets = matchedMarkets
    self.venueSoloQuotes = venueSoloQuotes
    self.allocations = allocations
    self.bridgeSteps = bridgeSteps
    self.feeBreakdown = feeBreakdown
    self.appFee = appFee
    self.referral = referral
    self.slippage = slippage
    self.optima = optima
    self.warnings = warnings
    self.message = message
    self.settlementPlan = settlementPlan
    self.estimatedPayout = estimatedPayout
    self.totalCostIncFees = totalCostIncFees
    self.estimatedNetProceeds = estimatedNetProceeds
    self.estimatedProfit = estimatedProfit
    self.returnPct = returnPct
    self.positionAvailability = positionAvailability
    self.sizeStepRaw = sizeStepRaw
    self.minSizeRaw = minSizeRaw
    self.legBounds = legBounds
  }

  public struct MatchedMarket: Codable, Equatable {
    public let venue: AggVenue
    public let venueMarketId: String

    public init(venue: AggVenue, venueMarketId: String) {
      self.venue = venue
      self.venueMarketId = venueMarketId
    }
  }

  public struct AppFee: Codable, Equatable {
    public let bips: Int
    public let categoryKey: String
    public let quotedAppFeeRaw: String
    public let bipsByVenue: [String: Double]?

    public init(
      bips: Int,
      categoryKey: String,
      quotedAppFeeRaw: String,
      bipsByVenue: [String: Double]? = nil
    ) {
      self.bips = bips
      self.categoryKey = categoryKey
      self.quotedAppFeeRaw = quotedAppFeeRaw
      self.bipsByVenue = bipsByVenue
    }
  }

  public struct Referral: Codable, Equatable {
    public let referrer: String
    public let feeBips: Double
    public let feeBipsByVenue: [String: Double]?
    public let payer: String
    public let payerAddress: String?
    public let activationSponsorAddress: String?
    public let quotedFeeUsd: Double

    public init(
      referrer: String,
      feeBips: Double,
      feeBipsByVenue: [String: Double]? = nil,
      payer: String,
      payerAddress: String? = nil,
      activationSponsorAddress: String? = nil,
      quotedFeeUsd: Double
    ) {
      self.referrer = referrer
      self.feeBips = feeBips
      self.feeBipsByVenue = feeBipsByVenue
      self.payer = payer
      self.payerAddress = payerAddress
      self.activationSponsorAddress = activationSponsorAddress
      self.quotedFeeUsd = quotedFeeUsd
    }
  }

  /// The best each objective could reach on its own, for comparison.
  public struct Optima: Codable, Equatable {
    public let maxFilledQty: Double
    public let minSlippage: Double
    public let minCost: Double
    public let minRisk: Double
    public let minBridges: Int
    public let minVenues: Int

    public init(
      maxFilledQty: Double,
      minSlippage: Double,
      minCost: Double,
      minRisk: Double,
      minBridges: Int,
      minVenues: Int
    ) {
      self.maxFilledQty = maxFilledQty
      self.minSlippage = minSlippage
      self.minCost = minCost
      self.minRisk = minRisk
      self.minBridges = minBridges
      self.minVenues = minVenues
    }
  }

  /// Sell quotes: the shares the user can sell, where.
  public struct PositionAvailability: Codable, Equatable {
    public let totalSellableShares: Double
    public let venueMarketOutcomes: [VenueMarketOutcome]

    public init(totalSellableShares: Double, venueMarketOutcomes: [VenueMarketOutcome]) {
      self.totalSellableShares = totalSellableShares
      self.venueMarketOutcomes = venueMarketOutcomes
    }

    public struct VenueMarketOutcome: Codable, Equatable {
      public let id: String
      public let venue: AggVenue
      public let venueMarketId: String
      public let availableShares: Double

      public init(
        id: String,
        venue: AggVenue,
        venueMarketId: String,
        availableShares: Double
      ) {
        self.id = id
        self.venue = venue
        self.venueMarketId = venueMarketId
        self.availableShares = availableShares
      }
    }
  }

  public struct LegBound: Codable, Equatable {
    public let venue: AggVenue
    public let venueMarketOutcomeId: String
    public let side: String
    public let worstPrice: Double
    public let effectiveSlippageBps: Double

    public init(
      venue: AggVenue,
      venueMarketOutcomeId: String,
      side: String,
      worstPrice: Double,
      effectiveSlippageBps: Double
    ) {
      self.venue = venue
      self.venueMarketOutcomeId = venueMarketOutcomeId
      self.side = side
      self.worstPrice = worstPrice
      self.effectiveSlippageBps = effectiveSlippageBps
    }
  }
}

/// An accepted fill. Poll `getOrder` with `quoteId` until it is terminal.
public struct AggFill: Codable, Equatable {
  public let quoteId: String
  public let orderIds: [String]
  /// Always `pending`: accepted, not yet executed.
  public let status: AggOrderStatus
  public let alreadyAccepted: Bool?
  public let redeemId: String?
  public let message: String?

  public init(
    quoteId: String,
    orderIds: [String],
    status: AggOrderStatus,
    alreadyAccepted: Bool? = nil,
    redeemId: String? = nil,
    message: String? = nil
  ) {
    self.quoteId = quoteId
    self.orderIds = orderIds
    self.status = status
    self.alreadyAccepted = alreadyAccepted
    self.redeemId = redeemId
    self.message = message
  }
}

public struct AggExecutionStep: Codable, Equatable {
  /// Position in the plan, from 1; `0` is the "order submitted" step.
  public let sequence: Int
  /// Machine name, for logs and support. Open set.
  public let stepType: String
  /// One of `pending`, `in_progress`, `completed`, `failed`, `skipped`.
  public let status: AggExecutionStepStatus
  public let attempt: Int
  public let startedAt: String?
  public let completedAt: String?
  public let errorReason: String?
  public let orderIds: [String]
  /// One of `submit`, `setup`, `bridge`, `fill`, `internal`.
  public let kind: AggExecutionStepKind
  public let groupId: String
  public let groupStatus: String
  /// Ready-to-show text for the row's current status.
  public let label: String
  /// Only on `kind: "bridge"`. Chains are display names, e.g. "Polygon".
  public let bridge: Bridge?

  public init(
    sequence: Int,
    stepType: String,
    status: AggExecutionStepStatus,
    attempt: Int,
    startedAt: String? = nil,
    completedAt: String? = nil,
    errorReason: String? = nil,
    orderIds: [String],
    kind: AggExecutionStepKind,
    groupId: String,
    groupStatus: String,
    label: String,
    bridge: Bridge? = nil
  ) {
    self.sequence = sequence
    self.stepType = stepType
    self.status = status
    self.attempt = attempt
    self.startedAt = startedAt
    self.completedAt = completedAt
    self.errorReason = errorReason
    self.orderIds = orderIds
    self.kind = kind
    self.groupId = groupId
    self.groupStatus = groupStatus
    self.label = label
    self.bridge = bridge
  }

  /// Only on `kind: "bridge"`. Chains are display names, e.g. "Polygon".
  public struct Bridge: Codable, Equatable {
    public let amount: String
    public let tokenSymbol: AggTokenSymbol
    public let fromChain: String
    public let toChain: String

    public init(
      amount: String,
      tokenSymbol: AggTokenSymbol,
      fromChain: String,
      toChain: String
    ) {
      self.amount = amount
      self.tokenSymbol = tokenSymbol
      self.fromChain = fromChain
      self.toChain = toChain
    }
  }
}

public struct AggExecutionOrder: Codable, Equatable {
  public let orderId: String
  public let venue: AggVenue
  public let status: AggOrderStatus
  /// Terminal outcome (`filled`, `partial_fill`, `failed`); `nil` in flight.
  public let event: String?
  public let filledAmountRaw: String?
  public let remainingAmountRaw: String?
  public let quotedSharesRaw: String?
  public let actualSharesRaw: String?
  public let quotedToWinRaw: String?
  public let actualToWinRaw: String?
  public let quotedPriceRaw: String?
  public let executionPriceRaw: String?
  public let partialFillReason: String?
  public let errorReason: String?
  public let venueOrderId: String?
  public let txHash: String?
  public let updatedAt: String

  public init(
    orderId: String,
    venue: AggVenue,
    status: AggOrderStatus,
    event: String? = nil,
    filledAmountRaw: String? = nil,
    remainingAmountRaw: String? = nil,
    quotedSharesRaw: String? = nil,
    actualSharesRaw: String? = nil,
    quotedToWinRaw: String? = nil,
    actualToWinRaw: String? = nil,
    quotedPriceRaw: String? = nil,
    executionPriceRaw: String? = nil,
    partialFillReason: String? = nil,
    errorReason: String? = nil,
    venueOrderId: String? = nil,
    txHash: String? = nil,
    updatedAt: String
  ) {
    self.orderId = orderId
    self.venue = venue
    self.status = status
    self.event = event
    self.filledAmountRaw = filledAmountRaw
    self.remainingAmountRaw = remainingAmountRaw
    self.quotedSharesRaw = quotedSharesRaw
    self.actualSharesRaw = actualSharesRaw
    self.quotedToWinRaw = quotedToWinRaw
    self.actualToWinRaw = actualToWinRaw
    self.quotedPriceRaw = quotedPriceRaw
    self.executionPriceRaw = executionPriceRaw
    self.partialFillReason = partialFillReason
    self.errorReason = errorReason
    self.venueOrderId = venueOrderId
    self.txHash = txHash
    self.updatedAt = updatedAt
  }
}

public struct AggDagProgress: Codable, Equatable {
  public let dagRunId: String
  public let totalSteps: Int
  public let currentSequence: Int
  public let currentStepType: String?
  public let completedSequences: [Int]
  /// `sequence` (as a string key) to `stepType`.
  public let stepTypes: [String: String]
  /// `running`, `completed` or `failed`.
  public let status: String
  public let errorReason: String?

  public init(
    dagRunId: String,
    totalSteps: Int,
    currentSequence: Int,
    currentStepType: String? = nil,
    completedSequences: [Int],
    stepTypes: [String: String],
    status: String,
    errorReason: String? = nil
  ) {
    self.dagRunId = dagRunId
    self.totalSteps = totalSteps
    self.currentSequence = currentSequence
    self.currentStepType = currentStepType
    self.completedSequences = completedSequences
    self.stepTypes = stepTypes
    self.status = status
    self.errorReason = errorReason
  }
}

/// The progress of a fill. Poll until `terminal`, waiting `pollAfterMs` between reads.
public struct AggExecutionStatus: Codable, Equatable {
  public let quoteId: String
  public let executionId: String?
  public let overallState: AggExecutionState
  public let terminal: Bool
  public let errorReason: String?
  /// `nil` once terminal.
  public let pollAfterMs: Int?
  public let dagProgress: AggDagProgress?
  public let orderIds: [String]
  public let steps: [AggExecutionStep]
  public let orders: [AggExecutionOrder]

  public init(
    quoteId: String,
    executionId: String? = nil,
    overallState: AggExecutionState,
    terminal: Bool,
    errorReason: String? = nil,
    pollAfterMs: Int? = nil,
    dagProgress: AggDagProgress? = nil,
    orderIds: [String],
    steps: [AggExecutionStep],
    orders: [AggExecutionOrder]
  ) {
    self.quoteId = quoteId
    self.executionId = executionId
    self.overallState = overallState
    self.terminal = terminal
    self.errorReason = errorReason
    self.pollAfterMs = pollAfterMs
    self.dagProgress = dagProgress
    self.orderIds = orderIds
    self.steps = steps
    self.orders = orders
  }
}

public struct AggOrderFees: Codable, Equatable {
  /// One of `fill`, `fill_in_game_only`, `winnings`, `exit`.
  public let venueFeeBasis: String?
  public let quoted: Quoted
  public let actual: Actual

  public init(venueFeeBasis: String? = nil, quoted: Quoted, actual: Actual) {
    self.venueFeeBasis = venueFeeBasis
    self.quoted = quoted
    self.actual = actual
  }

  public struct Quoted: Codable, Equatable {
    public let venueFeeRaw: String?
    public let appFeeRaw: String?
    public let appFeeBips: Int?
    public let referralFeeRaw: String?

    public init(
      venueFeeRaw: String? = nil,
      appFeeRaw: String? = nil,
      appFeeBips: Int? = nil,
      referralFeeRaw: String? = nil
    ) {
      self.venueFeeRaw = venueFeeRaw
      self.appFeeRaw = appFeeRaw
      self.appFeeBips = appFeeBips
      self.referralFeeRaw = referralFeeRaw
    }
  }

  public struct Actual: Codable, Equatable {
    public let dagRunId: String?
    public let venueFeeRaw: String?
    public let appFee: AppFee?
    public let bridge: Bridge?
    public let referral: Referral?

    public init(
      dagRunId: String? = nil,
      venueFeeRaw: String? = nil,
      appFee: AppFee? = nil,
      bridge: Bridge? = nil,
      referral: Referral? = nil
    ) {
      self.dagRunId = dagRunId
      self.venueFeeRaw = venueFeeRaw
      self.appFee = appFee
      self.bridge = bridge
      self.referral = referral
    }

    public struct AppFee: Codable, Equatable {
      public let bips: Int
      public let dueRaw: String
      public let collectedRaw: String
      public let status: String

      public init(
        bips: Int,
        dueRaw: String,
        collectedRaw: String,
        status: String
      ) {
        self.bips = bips
        self.dueRaw = dueRaw
        self.collectedRaw = collectedRaw
        self.status = status
      }
    }

    public struct Bridge: Codable, Equatable {
      /// USD decimal strings.
      public let relayFeeUsd: String?
      public let originGasCostUsd: String?
      public let operationCount: Int
      public let pricedOperationCount: Int

      public init(
        relayFeeUsd: String? = nil,
        originGasCostUsd: String? = nil,
        operationCount: Int,
        pricedOperationCount: Int
      ) {
        self.relayFeeUsd = relayFeeUsd
        self.originGasCostUsd = originGasCostUsd
        self.operationCount = operationCount
        self.pricedOperationCount = pricedOperationCount
      }
    }

    public struct Referral: Codable, Equatable {
      public let referrer: String
      /// `user` or `app`.
      public let payer: String
      public let feeBips: Double
      public let dueRaw: String
      public let paidRaw: String
      public let status: String

      public init(
        referrer: String,
        payer: String,
        feeBips: Double,
        dueRaw: String,
        paidRaw: String,
        status: String
      ) {
        self.referrer = referrer
        self.payer = payer
        self.feeBips = feeBips
        self.dueRaw = dueRaw
        self.paidRaw = paidRaw
        self.status = status
      }
    }
  }
}

/// An order row.
public struct AggOrder: Codable, Equatable {
  /// The order id, which `cancelOrder` takes.
  public let id: String
  /// Shared by every order of a split trade.
  public let quoteId: String?
  public let externalId: String?
  public let clientOrderId: String?
  public let venue: AggVenue
  public let status: AggOrderStatus
  /// `buy` or `sell`.
  public let side: String
  public let amountRaw: String
  /// `market` or `limit`; absent on paper orders.
  public let orderType: String?
  public let limitPriceRaw: String?
  public let limitSizeRaw: String?
  public let timeInForce: String?
  public let postOnly: Bool?
  public let expiresAt: String?
  public let reservedCostRaw: String?
  public let filledSizeRaw: String?
  public let filledCostRaw: String?
  public let remainingSizeRaw: String?
  public let averageFillPriceRaw: String?
  public let venueOrderId: String?
  public let tokenId: String?
  public let cancelRequestedAt: String?
  public let cancelledAt: String?
  public let cancelReason: String?
  public let slippageBps: Double?
  public let quotedPriceRaw: String?
  public let quotedCostRaw: String?
  public let quotedSharesRaw: String?
  public let quotedToWinRaw: String?
  public let filledAmountRaw: String?
  /// Decimal USD per share.
  public let executionPrice: String?
  public let actualSharesRaw: String?
  public let actualToWinRaw: String?
  public let partialFillReason: String?
  public let fees: AggOrderFees?
  public let txHash: String?
  public let errorMessage: String?
  public let dagRunId: String?
  public let createdAt: String
  public let updatedAt: String
  public let venueMarket: VenueMarket?
  public let venueMarketOutcome: VenueMarketOutcome?

  public init(
    id: String,
    quoteId: String? = nil,
    externalId: String? = nil,
    clientOrderId: String? = nil,
    venue: AggVenue,
    status: AggOrderStatus,
    side: String,
    amountRaw: String,
    orderType: String? = nil,
    limitPriceRaw: String? = nil,
    limitSizeRaw: String? = nil,
    timeInForce: String? = nil,
    postOnly: Bool? = nil,
    expiresAt: String? = nil,
    reservedCostRaw: String? = nil,
    filledSizeRaw: String? = nil,
    filledCostRaw: String? = nil,
    remainingSizeRaw: String? = nil,
    averageFillPriceRaw: String? = nil,
    venueOrderId: String? = nil,
    tokenId: String? = nil,
    cancelRequestedAt: String? = nil,
    cancelledAt: String? = nil,
    cancelReason: String? = nil,
    slippageBps: Double? = nil,
    quotedPriceRaw: String? = nil,
    quotedCostRaw: String? = nil,
    quotedSharesRaw: String? = nil,
    quotedToWinRaw: String? = nil,
    filledAmountRaw: String? = nil,
    executionPrice: String? = nil,
    actualSharesRaw: String? = nil,
    actualToWinRaw: String? = nil,
    partialFillReason: String? = nil,
    fees: AggOrderFees? = nil,
    txHash: String? = nil,
    errorMessage: String? = nil,
    dagRunId: String? = nil,
    createdAt: String,
    updatedAt: String,
    venueMarket: VenueMarket? = nil,
    venueMarketOutcome: VenueMarketOutcome? = nil
  ) {
    self.id = id
    self.quoteId = quoteId
    self.externalId = externalId
    self.clientOrderId = clientOrderId
    self.venue = venue
    self.status = status
    self.side = side
    self.amountRaw = amountRaw
    self.orderType = orderType
    self.limitPriceRaw = limitPriceRaw
    self.limitSizeRaw = limitSizeRaw
    self.timeInForce = timeInForce
    self.postOnly = postOnly
    self.expiresAt = expiresAt
    self.reservedCostRaw = reservedCostRaw
    self.filledSizeRaw = filledSizeRaw
    self.filledCostRaw = filledCostRaw
    self.remainingSizeRaw = remainingSizeRaw
    self.averageFillPriceRaw = averageFillPriceRaw
    self.venueOrderId = venueOrderId
    self.tokenId = tokenId
    self.cancelRequestedAt = cancelRequestedAt
    self.cancelledAt = cancelledAt
    self.cancelReason = cancelReason
    self.slippageBps = slippageBps
    self.quotedPriceRaw = quotedPriceRaw
    self.quotedCostRaw = quotedCostRaw
    self.quotedSharesRaw = quotedSharesRaw
    self.quotedToWinRaw = quotedToWinRaw
    self.filledAmountRaw = filledAmountRaw
    self.executionPrice = executionPrice
    self.actualSharesRaw = actualSharesRaw
    self.actualToWinRaw = actualToWinRaw
    self.partialFillReason = partialFillReason
    self.fees = fees
    self.txHash = txHash
    self.errorMessage = errorMessage
    self.dagRunId = dagRunId
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.venueMarket = venueMarket
    self.venueMarketOutcome = venueMarketOutcome
  }

  public struct VenueMarket: Codable, Equatable {
    public let id: String
    public let venueEventId: String
    public let question: String
    public let image: String?

    public init(
      id: String,
      venueEventId: String,
      question: String,
      image: String? = nil
    ) {
      self.id = id
      self.venueEventId = venueEventId
      self.question = question
      self.image = image
    }
  }

  public struct VenueMarketOutcome: Codable, Equatable {
    public let label: String
    public let title: String?

    public init(label: String, title: String? = nil) {
      self.label = label
      self.title = title
    }
  }
}

/// A placed direct order.
public struct AggDirectOrder: Codable, Equatable {
  public let orderId: String
  public let externalId: String
  public let venue: AggVenue
  public let status: AggOrderStatus
  public let quoteId: String
  /// Decimal string, e.g. "0.53".
  public let quotedPriceRaw: String?
  public let quotedCostRaw: String?
  public let quotedSharesRaw: String?

  public init(
    orderId: String,
    externalId: String,
    venue: AggVenue,
    status: AggOrderStatus,
    quoteId: String,
    quotedPriceRaw: String? = nil,
    quotedCostRaw: String? = nil,
    quotedSharesRaw: String? = nil
  ) {
    self.orderId = orderId
    self.externalId = externalId
    self.venue = venue
    self.status = status
    self.quoteId = quoteId
    self.quotedPriceRaw = quotedPriceRaw
    self.quotedCostRaw = quotedCostRaw
    self.quotedSharesRaw = quotedSharesRaw
  }
}

/// A placed limit order.
public struct AggLimitOrder: Codable, Equatable {
  public let orderId: String
  public let quoteId: String?
  public let status: AggOrderStatus
  public let venue: AggVenue
  public let venueOrderId: String?
  public let reservedCostRaw: String?
  public let limitPriceRaw: String
  public let limitSizeRaw: String
  public let filledSizeRaw: String
  public let remainingSizeRaw: String

  public init(
    orderId: String,
    quoteId: String? = nil,
    status: AggOrderStatus,
    venue: AggVenue,
    venueOrderId: String? = nil,
    reservedCostRaw: String? = nil,
    limitPriceRaw: String,
    limitSizeRaw: String,
    filledSizeRaw: String,
    remainingSizeRaw: String
  ) {
    self.orderId = orderId
    self.quoteId = quoteId
    self.status = status
    self.venue = venue
    self.venueOrderId = venueOrderId
    self.reservedCostRaw = reservedCostRaw
    self.limitPriceRaw = limitPriceRaw
    self.limitSizeRaw = limitSizeRaw
    self.filledSizeRaw = filledSizeRaw
    self.remainingSizeRaw = remainingSizeRaw
  }
}

/// A cancel request.
public struct AggCancelResult: Codable, Equatable {
  public let quoteId: String?
  public let orderIds: [String]
  /// `cancel_pending` or `cancelled`.
  public let status: AggOrderStatus

  public init(quoteId: String? = nil, orderIds: [String], status: AggOrderStatus) {
    self.quoteId = quoteId
    self.orderIds = orderIds
    self.status = status
  }
}

/// A redemption, one result per outcome.
public struct AggRedeemResult: Codable, Equatable {
  public let redeemId: String
  public let results: [OutcomeResult]

  public init(redeemId: String, results: [OutcomeResult]) {
    self.redeemId = redeemId
    self.results = results
  }

  public struct OutcomeResult: Codable, Equatable {
    public let venueMarketOutcomeId: String
    /// One of `submitted`, `confirmed`, `ineligible`, `rejected`.
    public let status: String
    public let callsId: String?
    public let pendingUserOpId: String?
    public let txHash: String?
    public let reason: String?

    public init(
      venueMarketOutcomeId: String,
      status: String,
      callsId: String? = nil,
      pendingUserOpId: String? = nil,
      txHash: String? = nil,
      reason: String? = nil
    ) {
      self.venueMarketOutcomeId = venueMarketOutcomeId
      self.status = status
      self.callsId = callsId
      self.pendingUserOpId = pendingUserOpId
      self.txHash = txHash
      self.reason = reason
    }
  }
}
