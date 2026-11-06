//
//  AggAccountTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// The Agg user profile.
public struct AggUserProfile: Codable, Equatable {
  public let id: String
  public let username: String?
  public let avatarUrl: String?
  public let externalId: String?
  public let isLocationBlocked: Bool
  public let accounts: [Account]
  public let wallets: [Wallet]
  public let venueAccounts: [VenueAccount]?
  /// Sign-in identities on other Agg accounts; `provider` is `email`, `google` or `apple`.
  public let otherIdentities: [OtherIdentity]?

  public init(
    id: String,
    username: String? = nil,
    avatarUrl: String? = nil,
    externalId: String? = nil,
    isLocationBlocked: Bool,
    accounts: [Account],
    wallets: [Wallet],
    venueAccounts: [VenueAccount]? = nil,
    otherIdentities: [OtherIdentity]? = nil
  ) {
    self.id = id
    self.username = username
    self.avatarUrl = avatarUrl
    self.externalId = externalId
    self.isLocationBlocked = isLocationBlocked
    self.accounts = accounts
    self.wallets = wallets
    self.venueAccounts = venueAccounts
    self.otherIdentities = otherIdentities
  }

  public struct Account: Codable, Equatable {
    /// One of `oauth`, `siwe`, `siws`, `email`.
    public let type: String
    /// One of `wallet`, `solana_wallet`, `google`, `twitter`, `apple`, `email`.
    public let provider: String
    public let providerAccountId: String

    public init(type: String, provider: String, providerAccountId: String) {
      self.type = type
      self.provider = provider
      self.providerAccountId = providerAccountId
    }
  }

  public struct Wallet: Codable, Equatable {
    /// Address family: `evm` or `svm`.
    public let chain: String
    public let address: String

    public init(chain: String, address: String) {
      self.chain = chain
      self.address = address
    }
  }

  public struct VenueAccount: Codable, Equatable {
    public let id: String
    public let venue: AggVenue
    public let status: String
    public let kycStatus: String

    public init(
      id: String,
      venue: AggVenue,
      status: String,
      kycStatus: String
    ) {
      self.id = id
      self.venue = venue
      self.status = status
      self.kycStatus = kycStatus
    }
  }

  public struct OtherIdentity: Codable, Equatable {
    public let provider: String

    public init(provider: String) {
      self.provider = provider
    }
  }
}

public struct AggSupportedChainToken: Codable, Equatable {
  /// Open set: currently `USDC`, `USDC.e`, `USDT`, `pUSD`, `USD1`.
  public let symbol: String
  /// ERC-20 address, Solana SPL mint, or Hyperliquid token id.
  public let address: String
  public let decimals: Int

  public init(symbol: String, address: String, decimals: Int) {
    self.symbol = symbol
    self.address = address
    self.decimals = decimals
  }
}

public struct AggChainBalance: Codable, Equatable {
  public let chainId: String
  public let tokenAddress: String
  public let balanceRaw: String
  public let heldRaw: String?
  public let availableRaw: String?
  public let decimals: Int
  public let lastSyncedAt: String
  /// The on-chain symbol, when it differs from the parent's.
  public let tokenSymbol: AggTokenSymbol?
  /// The wallet holding this balance (self-custody responses).
  public let address: String?
  /// One of `EOA`, `DEPOSIT_WALLET`, `POLYMARKET_LEGACY`, `VENUE_ACCOUNT`.
  public let custodyKind: AggCustodyKind?
  public let venue: AggVenue?
  public let venueAccountId: String?
  public let externalAccountId: String?
  public let isFresh: Bool?
  public let registeredByAgg: Bool?
  /// With `POLYMARKET_LEGACY`: `safe` or `proxy`.
  public let legacyKind: String?

  public init(
    chainId: String,
    tokenAddress: String,
    balanceRaw: String,
    heldRaw: String? = nil,
    availableRaw: String? = nil,
    decimals: Int,
    lastSyncedAt: String,
    tokenSymbol: AggTokenSymbol? = nil,
    address: String? = nil,
    custodyKind: AggCustodyKind? = nil,
    venue: AggVenue? = nil,
    venueAccountId: String? = nil,
    externalAccountId: String? = nil,
    isFresh: Bool? = nil,
    registeredByAgg: Bool? = nil,
    legacyKind: String? = nil
  ) {
    self.chainId = chainId
    self.tokenAddress = tokenAddress
    self.balanceRaw = balanceRaw
    self.heldRaw = heldRaw
    self.availableRaw = availableRaw
    self.decimals = decimals
    self.lastSyncedAt = lastSyncedAt
    self.tokenSymbol = tokenSymbol
    self.address = address
    self.custodyKind = custodyKind
    self.venue = venue
    self.venueAccountId = venueAccountId
    self.externalAccountId = externalAccountId
    self.isFresh = isFresh
    self.registeredByAgg = registeredByAgg
    self.legacyKind = legacyKind
  }
}

public struct AggCashBalance: Codable, Equatable {
  /// e.g. `USDC`; paper accounts read `PAPER_USD`.
  public let tokenSymbol: AggTokenSymbol
  public let totalRaw: String
  public let availableRaw: String?
  public let reservedRaw: String?
  public let decimals: Int
  public let chains: [AggChainBalance]

  public init(
    tokenSymbol: AggTokenSymbol,
    totalRaw: String,
    availableRaw: String? = nil,
    reservedRaw: String? = nil,
    decimals: Int,
    chains: [AggChainBalance]
  ) {
    self.tokenSymbol = tokenSymbol
    self.totalRaw = totalRaw
    self.availableRaw = availableRaw
    self.reservedRaw = reservedRaw
    self.decimals = decimals
    self.chains = chains
  }
}

public struct AggVenuePositionValue: Codable, Equatable {
  public let venue: AggVenue
  public let balance: Double
  public let costBasis: Double
  public let unrealizedPnl: Double
  public let realizedPnl: Double
  /// One of `orderbook`, `cached`, `entry`, `settled`.
  public let priceSource: String
  /// One of `healthy`, `bid_only`, `ask_only`, `endpoint_stub`, `wide_spread`, `crossed`, `empty`.
  /// Absent in paper mode.
  public let bookQuality: String?
  public let migrationPending: Bool?
  public let costBasisUnknown: Bool?
  public let realizedPnlIncomplete: Bool?

  public init(
    venue: AggVenue,
    balance: Double,
    costBasis: Double,
    unrealizedPnl: Double,
    realizedPnl: Double,
    priceSource: String,
    bookQuality: String? = nil,
    migrationPending: Bool? = nil,
    costBasisUnknown: Bool? = nil,
    realizedPnlIncomplete: Bool? = nil
  ) {
    self.venue = venue
    self.balance = balance
    self.costBasis = costBasis
    self.unrealizedPnl = unrealizedPnl
    self.realizedPnl = realizedPnl
    self.priceSource = priceSource
    self.bookQuality = bookQuality
    self.migrationPending = migrationPending
    self.costBasisUnknown = costBasisUnknown
    self.realizedPnlIncomplete = realizedPnlIncomplete
  }
}

public struct AggVenueCash: Codable, Equatable {
  public let venue: AggVenue
  /// USD as integer cents.
  public let balanceCents: Int
  public let transferable: Bool?
  public let executionBackend: String?
  public let accountModel: String?
  public let asset: String?
  public let decimals: Int?
  public let balanceRaw: String?
  public let availableRaw: String?
  public let unmatchedExposureRaw: String?
  public let portfolioValueCents: Int?
  public let updatedAt: String

  public init(
    venue: AggVenue,
    balanceCents: Int,
    transferable: Bool? = nil,
    executionBackend: String? = nil,
    accountModel: String? = nil,
    asset: String? = nil,
    decimals: Int? = nil,
    balanceRaw: String? = nil,
    availableRaw: String? = nil,
    unmatchedExposureRaw: String? = nil,
    portfolioValueCents: Int? = nil,
    updatedAt: String
  ) {
    self.venue = venue
    self.balanceCents = balanceCents
    self.transferable = transferable
    self.executionBackend = executionBackend
    self.accountModel = accountModel
    self.asset = asset
    self.decimals = decimals
    self.balanceRaw = balanceRaw
    self.availableRaw = availableRaw
    self.unmatchedExposureRaw = unmatchedExposureRaw
    self.portfolioValueCents = portfolioValueCents
    self.updatedAt = updatedAt
  }
}

public struct AggPaperSummary: Codable, Equatable {
  public let startingBalance: Double
  public let cashBalance: Double
  public let positionsValue: Double
  public let realizedPnl: Double
  public let unrealizedPnl: Double
  public let earnings: Double

  public init(
    startingBalance: Double,
    cashBalance: Double,
    positionsValue: Double,
    realizedPnl: Double,
    unrealizedPnl: Double,
    earnings: Double
  ) {
    self.startingBalance = startingBalance
    self.cashBalance = cashBalance
    self.positionsValue = positionsValue
    self.realizedPnl = realizedPnl
    self.unrealizedPnl = unrealizedPnl
    self.earnings = earnings
  }
}

/// The managed balance. Funds are per chain: the aggregate available amount is not what one trade
/// can spend.
public struct AggBalances: Codable, Equatable {
  public let cash: [AggCashBalance]
  public let positions: [AggVenuePositionValue]
  public let venueCash: [AggVenueCash]?
  /// Present only in paper mode.
  public let paper: AggPaperSummary?

  public init(
    cash: [AggCashBalance],
    positions: [AggVenuePositionValue],
    venueCash: [AggVenueCash]? = nil,
    paper: AggPaperSummary? = nil
  ) {
    self.cash = cash
    self.positions = positions
    self.venueCash = venueCash
    self.paper = paper
  }
}

public struct AggPositionLeg: Codable, Equatable {
  public let venue: AggVenue
  public let venueMarketId: String
  /// The venue's own outcome id, which is what `POST /redemptions` wants.
  public let venueMarketOutcomeId: String?
  public let size: Double
  /// `long` or `short`.
  public let side: String?
  public let executionBackend: String?
  /// One of `EOA`, `DEPOSIT_WALLET`, `VENUE_OMNIBUS`, `VENUE_ACCOUNT`.
  public let custodyKind: AggCustodyKind?
  public let venueAccountId: String?
  public let externalAccountId: String?

  public init(
    venue: AggVenue,
    venueMarketId: String,
    venueMarketOutcomeId: String? = nil,
    size: Double,
    side: String? = nil,
    executionBackend: String? = nil,
    custodyKind: AggCustodyKind? = nil,
    venueAccountId: String? = nil,
    externalAccountId: String? = nil
  ) {
    self.venue = venue
    self.venueMarketId = venueMarketId
    self.venueMarketOutcomeId = venueMarketOutcomeId
    self.size = size
    self.side = side
    self.executionBackend = executionBackend
    self.custodyKind = custodyKind
    self.venueAccountId = venueAccountId
    self.externalAccountId = externalAccountId
  }
}

public struct AggPositionOutcome: Codable, Equatable {
  public let label: String
  public let title: String?
  /// `long` or `short`.
  public let side: String?
  public let venueBreakdown: [AggPositionLeg]
  public let totalSize: Double
  public let avgEntryPrice: Double
  public let costBasisUnknown: Bool?
  public let currentPrice: Double
  public let realizedPnl: Double
  public let totalValue: Double
  public let unrealizedPnl: Double
  public let unrealizedPnlPercent: Double
  /// `nil` until the market resolves.
  public let winner: Bool?
  public let priceSource: String
  /// Absent in paper mode.
  public let bookQuality: String?

  public init(
    label: String,
    title: String? = nil,
    side: String? = nil,
    venueBreakdown: [AggPositionLeg],
    totalSize: Double,
    avgEntryPrice: Double,
    costBasisUnknown: Bool? = nil,
    currentPrice: Double,
    realizedPnl: Double,
    totalValue: Double,
    unrealizedPnl: Double,
    unrealizedPnlPercent: Double,
    winner: Bool? = nil,
    priceSource: String,
    bookQuality: String? = nil
  ) {
    self.label = label
    self.title = title
    self.side = side
    self.venueBreakdown = venueBreakdown
    self.totalSize = totalSize
    self.avgEntryPrice = avgEntryPrice
    self.costBasisUnknown = costBasisUnknown
    self.currentPrice = currentPrice
    self.realizedPnl = realizedPnl
    self.totalValue = totalValue
    self.unrealizedPnl = unrealizedPnl
    self.unrealizedPnlPercent = unrealizedPnlPercent
    self.winner = winner
    self.priceSource = priceSource
    self.bookQuality = bookQuality
  }
}

/// A position, open or resolved.
public struct AggPosition: Codable, Equatable {
  public let targetMarketId: String
  /// Paper positions only.
  public let eventId: String?
  public let redeemStatus: AggRedeemStatus
  /// `active` or `closed`.
  public let status: String
  /// `long` or `short`.
  public let side: String?
  public let resolutionDate: String?
  public let venueMarket: VenueMarket

  public init(
    targetMarketId: String,
    eventId: String? = nil,
    redeemStatus: AggRedeemStatus,
    status: String,
    side: String? = nil,
    resolutionDate: String? = nil,
    venueMarket: VenueMarket
  ) {
    self.targetMarketId = targetMarketId
    self.eventId = eventId
    self.redeemStatus = redeemStatus
    self.status = status
    self.side = side
    self.resolutionDate = resolutionDate
    self.venueMarket = venueMarket
  }

  public struct VenueMarket: Codable, Equatable {
    public let venueEventId: String
    public let question: String
    public let image: String?
    public let status: AggMarketStatus
    public let venueMarketOutcomes: [AggPositionOutcome]

    public init(
      venueEventId: String,
      question: String,
      image: String? = nil,
      status: AggMarketStatus,
      venueMarketOutcomes: [AggPositionOutcome]
    ) {
      self.venueEventId = venueEventId
      self.question = question
      self.image = image
      self.status = status
      self.venueMarketOutcomes = venueMarketOutcomes
    }
  }
}

/// Where to send funds, discriminated on `ready`. Wallets are provisioned lazily, so the first read
/// can be `.notReady`: poll until it is `.ready`. Agg can reassign the addresses, so do not cache
/// them.
public enum AggDepositAddresses: Codable, Equatable {
  /// `ready: false`.
  case notReady
  /// `ready: true`.
  case ready(Ready)

  public struct Ready: Codable, Equatable {
    /// Deposit address on every supported EVM chain and Hyperliquid.
    public let evmAddress: String
    /// Solana deposit address (base58).
    public let svmAddress: String
    public let supportedChains: [SupportedChain]

    public init(evmAddress: String, svmAddress: String, supportedChains: [SupportedChain]) {
      self.evmAddress = evmAddress
      self.svmAddress = svmAddress
      self.supportedChains = supportedChains
    }

    public struct SupportedChain: Codable, Equatable {
      public let chainId: String
      public let name: String
      public let tokens: [AggSupportedChainToken]

      public init(chainId: String, name: String, tokens: [AggSupportedChainToken]) {
        self.chainId = chainId
        self.name = name
        self.tokens = tokens
      }
    }
  }

  /// The wire discriminator.
  public var isReady: Bool {
    if case .ready = self {
      return true
    }
    return false
  }

  private enum CodingKeys: String, CodingKey {
    case ready
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if try container.decode(Bool.self, forKey: .ready) {
      self = try .ready(Ready(from: decoder))
    } else {
      self = .notReady
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .notReady:
      try container.encode(false, forKey: .ready)
    case let .ready(value):
      try container.encode(true, forKey: .ready)
      try value.encode(to: encoder)
    }
  }
}

/// An item of the activity feed, discriminated on `type`.
///
/// Every known variant carries `id` (the underlying order, transfer or claim) and a `status` whose
/// value set depends on `type`.
public enum AggActivityItem: Codable, Equatable {
  /// `type: "trade"`.
  case trade(Trade)
  /// `type: "withdrawal"`.
  case withdrawal(Withdrawal)
  /// `type: "bridge"`.
  case bridge(Bridge)
  /// `type: "deposit"`.
  case deposit(Deposit)
  /// `type: "user_op"`.
  case userOp(UserOp)
  /// `type: "redeem"`.
  case redeem(Redeem)
  /// A `type` this SDK does not know yet.
  case unknown(type: String)

  /// `type: "trade"`.
  public struct Trade: Codable, Equatable {
    public let id: String
    public let createdAt: String
    public let updatedAt: String
    public let status: AggOrderStatus
    public let venue: AggVenue
    public let side: String
    public let amountRaw: String
    public let filledAmountRaw: String?
    public let executionPrice: String?
    public let venueMarket: VenueMarket?
    public let venueMarketOutcome: VenueMarketOutcome?
    public let txHash: String?
    public let errorMessage: String?

    public init(
      id: String,
      createdAt: String,
      updatedAt: String,
      status: AggOrderStatus,
      venue: AggVenue,
      side: String,
      amountRaw: String,
      filledAmountRaw: String? = nil,
      executionPrice: String? = nil,
      venueMarket: VenueMarket? = nil,
      venueMarketOutcome: VenueMarketOutcome? = nil,
      txHash: String? = nil,
      errorMessage: String? = nil
    ) {
      self.id = id
      self.createdAt = createdAt
      self.updatedAt = updatedAt
      self.status = status
      self.venue = venue
      self.side = side
      self.amountRaw = amountRaw
      self.filledAmountRaw = filledAmountRaw
      self.executionPrice = executionPrice
      self.venueMarket = venueMarket
      self.venueMarketOutcome = venueMarketOutcome
      self.txHash = txHash
      self.errorMessage = errorMessage
    }

    public struct VenueMarketOutcome: Codable, Equatable {
      public let id: String
      public let label: String
      public let title: String?
      /// Current price, 0 to 1.
      public let price: Double

      public init(
        id: String,
        label: String,
        title: String? = nil,
        price: Double
      ) {
        self.id = id
        self.label = label
        self.title = title
        self.price = price
      }
    }
  }

  /// `type: "withdrawal"`.
  public struct Withdrawal: Codable, Equatable {
    public let id: String
    public let createdAt: String
    public let updatedAt: String
    public let status: AggWithdrawalStatus
    public let tokenSymbol: AggTokenSymbol
    public let amountRaw: String
    public let destinationAddress: String
    public let destinationChainId: String
    public let completedAmountRaw: String?
    public let chainId: String?
    public let txHash: String?
    public let errorMessage: String?

    public init(
      id: String,
      createdAt: String,
      updatedAt: String,
      status: AggWithdrawalStatus,
      tokenSymbol: AggTokenSymbol,
      amountRaw: String,
      destinationAddress: String,
      destinationChainId: String,
      completedAmountRaw: String? = nil,
      chainId: String? = nil,
      txHash: String? = nil,
      errorMessage: String? = nil
    ) {
      self.id = id
      self.createdAt = createdAt
      self.updatedAt = updatedAt
      self.status = status
      self.tokenSymbol = tokenSymbol
      self.amountRaw = amountRaw
      self.destinationAddress = destinationAddress
      self.destinationChainId = destinationChainId
      self.completedAmountRaw = completedAmountRaw
      self.chainId = chainId
      self.txHash = txHash
      self.errorMessage = errorMessage
    }
  }

  /// `type: "bridge"`.
  public struct Bridge: Codable, Equatable {
    public let id: String
    public let createdAt: String
    public let updatedAt: String
    public let status: String
    public let tokenSymbol: AggTokenSymbol
    public let amountRaw: String
    public let sourceChainId: String
    public let destChainId: String
    public let sourceTxHash: String?
    public let destTxHash: String?

    public init(
      id: String,
      createdAt: String,
      updatedAt: String,
      status: String,
      tokenSymbol: AggTokenSymbol,
      amountRaw: String,
      sourceChainId: String,
      destChainId: String,
      sourceTxHash: String? = nil,
      destTxHash: String? = nil
    ) {
      self.id = id
      self.createdAt = createdAt
      self.updatedAt = updatedAt
      self.status = status
      self.tokenSymbol = tokenSymbol
      self.amountRaw = amountRaw
      self.sourceChainId = sourceChainId
      self.destChainId = destChainId
      self.sourceTxHash = sourceTxHash
      self.destTxHash = destTxHash
    }
  }

  /// `type: "deposit"`.
  public struct Deposit: Codable, Equatable {
    public let id: String
    public let createdAt: String
    public let updatedAt: String
    public let status: String
    public let tokenSymbol: AggTokenSymbol
    public let amountRaw: String
    public let chainId: String
    public let fromAddress: String
    public let txHash: String
    /// `connected_wallet` or `external_wallet`.
    public let source: String

    public init(
      id: String,
      createdAt: String,
      updatedAt: String,
      status: String,
      tokenSymbol: AggTokenSymbol,
      amountRaw: String,
      chainId: String,
      fromAddress: String,
      txHash: String,
      source: String
    ) {
      self.id = id
      self.createdAt = createdAt
      self.updatedAt = updatedAt
      self.status = status
      self.tokenSymbol = tokenSymbol
      self.amountRaw = amountRaw
      self.chainId = chainId
      self.fromAddress = fromAddress
      self.txHash = txHash
      self.source = source
    }
  }

  /// `type: "user_op"`.
  public struct UserOp: Codable, Equatable {
    public let id: String
    public let createdAt: String
    public let updatedAt: String
    public let status: String
    public let callsId: String
    public let chainId: String
    public let walletAddress: String
    public let txHash: String?
    public let confirmedAt: String?

    public init(
      id: String,
      createdAt: String,
      updatedAt: String,
      status: String,
      callsId: String,
      chainId: String,
      walletAddress: String,
      txHash: String? = nil,
      confirmedAt: String? = nil
    ) {
      self.id = id
      self.createdAt = createdAt
      self.updatedAt = updatedAt
      self.status = status
      self.callsId = callsId
      self.chainId = chainId
      self.walletAddress = walletAddress
      self.txHash = txHash
      self.confirmedAt = confirmedAt
    }
  }

  /// `type: "redeem"`.
  public struct Redeem: Codable, Equatable {
    public let id: String
    public let createdAt: String
    public let updatedAt: String
    public let status: String
    public let totalPayoutRaw: String?
    public let legs: [Leg]

    public init(
      id: String,
      createdAt: String,
      updatedAt: String,
      status: String,
      totalPayoutRaw: String? = nil,
      legs: [Leg]
    ) {
      self.id = id
      self.createdAt = createdAt
      self.updatedAt = updatedAt
      self.status = status
      self.totalPayoutRaw = totalPayoutRaw
      self.legs = legs
    }

    public struct Leg: Codable, Equatable {
      public let id: String
      public let venueMarketOutcomeId: String
      public let venue: AggVenue
      public let status: String
      public let chainId: String
      public let payoutTokenSymbol: AggTokenSymbol
      public let payoutAmountRaw: String?
      public let txHash: String?
      public let errorMessage: String?
      public let venueMarket: VenueMarket?
      public let venueMarketOutcome: VenueMarketOutcome?

      public init(
        id: String,
        venueMarketOutcomeId: String,
        venue: AggVenue,
        status: String,
        chainId: String,
        payoutTokenSymbol: AggTokenSymbol,
        payoutAmountRaw: String? = nil,
        txHash: String? = nil,
        errorMessage: String? = nil,
        venueMarket: VenueMarket? = nil,
        venueMarketOutcome: VenueMarketOutcome? = nil
      ) {
        self.id = id
        self.venueMarketOutcomeId = venueMarketOutcomeId
        self.venue = venue
        self.status = status
        self.chainId = chainId
        self.payoutTokenSymbol = payoutTokenSymbol
        self.payoutAmountRaw = payoutAmountRaw
        self.txHash = txHash
        self.errorMessage = errorMessage
        self.venueMarket = venueMarket
        self.venueMarketOutcome = venueMarketOutcome
      }

      public struct VenueMarketOutcome: Codable, Equatable {
        public let id: String
        public let label: String
        public let title: String?

        public init(id: String, label: String, title: String? = nil) {
          self.id = id
          self.label = label
          self.title = title
        }
      }
    }
  }

  /// The market a trade or redemption concerns.
  public struct VenueMarket: Codable, Equatable {
    public let id: String
    public let venueEventId: String
    public let question: String?
    public let image: String?

    public init(
      id: String,
      venueEventId: String,
      question: String? = nil,
      image: String? = nil
    ) {
      self.id = id
      self.venueEventId = venueEventId
      self.question = question
      self.image = image
    }
  }

  /// The wire discriminator.
  public var type: String {
    switch self {
    case .trade: return AggActivityType.trade.rawValue
    case .withdrawal: return AggActivityType.withdrawal.rawValue
    case .bridge: return AggActivityType.bridge.rawValue
    case .deposit: return AggActivityType.deposit.rawValue
    case .userOp: return AggActivityType.userOp.rawValue
    case .redeem: return AggActivityType.redeem.rawValue
    case let .unknown(type): return type
    }
  }

  private enum CodingKeys: String, CodingKey {
    case type
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)
    switch AggActivityType(rawValue: type) {
    case .trade: self = try .trade(Trade(from: decoder))
    case .withdrawal: self = try .withdrawal(Withdrawal(from: decoder))
    case .bridge: self = try .bridge(Bridge(from: decoder))
    case .deposit: self = try .deposit(Deposit(from: decoder))
    case .userOp: self = try .userOp(UserOp(from: decoder))
    case .redeem: self = try .redeem(Redeem(from: decoder))
    case nil: self = .unknown(type: type)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.type, forKey: .type)
    switch self {
    case let .trade(value): try value.encode(to: encoder)
    case let .withdrawal(value): try value.encode(to: encoder)
    case let .bridge(value): try value.encode(to: encoder)
    case let .deposit(value): try value.encode(to: encoder)
    case let .userOp(value): try value.encode(to: encoder)
    case let .redeem(value): try value.encode(to: encoder)
    case .unknown: break
    }
  }
}
