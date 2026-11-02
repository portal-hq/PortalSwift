//
//  AggDiscoveryTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// An outcome: the tradable leg of a market, e.g. "Yes" or "No". Quote it by `id`.
public struct AggVenueMarketOutcome: Codable, Equatable {
  public let id: String
  public let venueMarketId: String
  public let externalIdentifier: String?
  public let label: String
  public let title: String?
  /// Change over the last 24 hours, in absolute probability points. Live prices come from
  /// `/midpoints`.
  public let priceChange24h: Double?
  public let winner: Bool?
  /// What one winning share pays out; below 1 on venues that take a settlement fee.
  public let payoutPerShare: Double?
  /// The venue voided the market and refunds every holder their stake.
  public let refundAtCost: Bool?
  public let matchedVenueMarketOutcomes: [MatchedVenueMarketOutcome]?

  public init(
    id: String,
    venueMarketId: String,
    externalIdentifier: String? = nil,
    label: String,
    title: String? = nil,
    priceChange24h: Double? = nil,
    winner: Bool? = nil,
    payoutPerShare: Double? = nil,
    refundAtCost: Bool? = nil,
    matchedVenueMarketOutcomes: [MatchedVenueMarketOutcome]? = nil
  ) {
    self.id = id
    self.venueMarketId = venueMarketId
    self.externalIdentifier = externalIdentifier
    self.label = label
    self.title = title
    self.priceChange24h = priceChange24h
    self.winner = winner
    self.payoutPerShare = payoutPerShare
    self.refundAtCost = refundAtCost
    self.matchedVenueMarketOutcomes = matchedVenueMarketOutcomes
  }

  public struct MatchedVenueMarketOutcome: Codable, Equatable {
    public let venueMarketId: String
    public let venueMarketOutcomeId: String

    public init(venueMarketId: String, venueMarketOutcomeId: String) {
      self.venueMarketId = venueMarketId
      self.venueMarketOutcomeId = venueMarketOutcomeId
    }
  }
}

public struct AggSeries: Codable, Equatable {
  public let id: String?
  public let externalIdentifier: String
  public let name: String?
  public let venue: AggVenue?
  public let recurrence: String?

  public init(
    id: String? = nil,
    externalIdentifier: String,
    name: String? = nil,
    venue: AggVenue? = nil,
    recurrence: String? = nil
  ) {
    self.id = id
    self.externalIdentifier = externalIdentifier
    self.name = name
    self.venue = venue
    self.recurrence = recurrence
  }
}

public struct AggCategory: Codable, Equatable {
  public let id: String
  public let name: String
  public let displayName: String?
  public let parentId: String?
  public let eventCount: Int
  public let volume24hr: Double
  public let volume: Double

  public init(
    id: String,
    name: String,
    displayName: String? = nil,
    parentId: String? = nil,
    eventCount: Int,
    volume24hr: Double,
    volume: Double
  ) {
    self.id = id
    self.name = name
    self.displayName = displayName
    self.parentId = parentId
    self.eventCount = eventCount
    self.volume24hr = volume24hr
    self.volume = volume
  }
}

public struct AggEventCategory: Codable, Equatable {
  public let id: String
  public let category: AggCategory

  public init(id: String, category: AggCategory) {
    self.id = id
    self.category = category
  }
}

public struct AggSettlementDiff: Codable, Equatable {
  public let sharedSummary: String
  public let differences: [Difference]

  public init(sharedSummary: String, differences: [Difference]) {
    self.sharedSummary = sharedSummary
    self.differences = differences
  }

  public struct Difference: Codable, Equatable {
    public let type: String
    public let title: String
    /// Keyed by venue slug.
    public let perVenue: [String: String]
    public let summary: String?

    public init(
      type: String,
      title: String,
      perVenue: [String: String],
      summary: String? = nil
    ) {
      self.type = type
      self.title = title
      self.perVenue = perVenue
      self.summary = summary
    }
  }
}

public struct AggMatchedVenueEvent: Codable, Equatable {
  public let id: String
  public let venue: AggVenue
  public let externalIdentifier: String
  public let title: String
  public let slug: String?
  public let status: AggMarketStatus?
  public let series: AggSeries?

  public init(
    id: String,
    venue: AggVenue,
    externalIdentifier: String,
    title: String,
    slug: String? = nil,
    status: AggMarketStatus? = nil,
    series: AggSeries? = nil
  ) {
    self.id = id
    self.venue = venue
    self.externalIdentifier = externalIdentifier
    self.title = title
    self.slug = slug
    self.status = status
    self.series = series
  }
}

public struct AggMarketEvent: Codable, Equatable {
  public let id: String
  public let externalIdentifier: String
  public let title: String?
  public let slug: String?
  public let description: String?
  public let image: String?
  public let venue: AggVenue?
  public let deployerVenue: AggVenue?
  public let volume: Double?
  public let status: AggMarketStatus?
  public let sport: String?
  public let structureType: String?
  public let subtitle: String?
  public let startDate: String?
  public let endDate: String?
  public let creationDate: String?
  public let updatedAt: String?
  public let gameStartTime: String?
  public let categories: [AggEventCategory]?
  public let series: AggSeries?
  public let venues: [AggVenue]?
  public let marketCount: Int?
  public let venueCount: Int?
  public let groupMarketCount: Int?
  public let groupParentId: String?
  public let arbReturn: Double?
  public let recurrence: String?
  public let aggKey: String?
  public let settlementDiff: AggSettlementDiff?
  public let settlementDiffStatus: String?
  public let matchedVenueEvents: [AggMatchedVenueEvent]?

  public init(
    id: String,
    externalIdentifier: String,
    title: String? = nil,
    slug: String? = nil,
    description: String? = nil,
    image: String? = nil,
    venue: AggVenue? = nil,
    deployerVenue: AggVenue? = nil,
    volume: Double? = nil,
    status: AggMarketStatus? = nil,
    sport: String? = nil,
    structureType: String? = nil,
    subtitle: String? = nil,
    startDate: String? = nil,
    endDate: String? = nil,
    creationDate: String? = nil,
    updatedAt: String? = nil,
    gameStartTime: String? = nil,
    categories: [AggEventCategory]? = nil,
    series: AggSeries? = nil,
    venues: [AggVenue]? = nil,
    marketCount: Int? = nil,
    venueCount: Int? = nil,
    groupMarketCount: Int? = nil,
    groupParentId: String? = nil,
    arbReturn: Double? = nil,
    recurrence: String? = nil,
    aggKey: String? = nil,
    settlementDiff: AggSettlementDiff? = nil,
    settlementDiffStatus: String? = nil,
    matchedVenueEvents: [AggMatchedVenueEvent]? = nil
  ) {
    self.id = id
    self.externalIdentifier = externalIdentifier
    self.title = title
    self.slug = slug
    self.description = description
    self.image = image
    self.venue = venue
    self.deployerVenue = deployerVenue
    self.volume = volume
    self.status = status
    self.sport = sport
    self.structureType = structureType
    self.subtitle = subtitle
    self.startDate = startDate
    self.endDate = endDate
    self.creationDate = creationDate
    self.updatedAt = updatedAt
    self.gameStartTime = gameStartTime
    self.categories = categories
    self.series = series
    self.venues = venues
    self.marketCount = marketCount
    self.venueCount = venueCount
    self.groupMarketCount = groupMarketCount
    self.groupParentId = groupParentId
    self.arbReturn = arbReturn
    self.recurrence = recurrence
    self.aggKey = aggKey
    self.settlementDiff = settlementDiff
    self.settlementDiffStatus = settlementDiffStatus
    self.matchedVenueEvents = matchedVenueEvents
  }
}

public struct AggMatchedVenueMarket: Codable, Equatable {
  public let id: String
  public let venue: AggVenue
  public let deployerVenue: AggVenue?
  public let externalIdentifier: String
  public let question: String
  public let shortTitle: String?
  public let detailsDeferred: Bool?
  public let description: String?
  public let rulesPrimary: String?
  public let rulesSecondary: String?
  public let volume: Double?
  public let volume24hr: Double?
  public let status: AggMarketStatus?
  public let conditionId: String?
  public let arbReturn: Double?
  public let image: String?
  /// A trimmed event.
  public let venueEvent: AggMarketEvent?
  public let venueMarketOutcomes: [AggVenueMarketOutcome]?

  public init(
    id: String,
    venue: AggVenue,
    deployerVenue: AggVenue? = nil,
    externalIdentifier: String,
    question: String,
    shortTitle: String? = nil,
    detailsDeferred: Bool? = nil,
    description: String? = nil,
    rulesPrimary: String? = nil,
    rulesSecondary: String? = nil,
    volume: Double? = nil,
    volume24hr: Double? = nil,
    status: AggMarketStatus? = nil,
    conditionId: String? = nil,
    arbReturn: Double? = nil,
    image: String? = nil,
    venueEvent: AggMarketEvent? = nil,
    venueMarketOutcomes: [AggVenueMarketOutcome]? = nil
  ) {
    self.id = id
    self.venue = venue
    self.deployerVenue = deployerVenue
    self.externalIdentifier = externalIdentifier
    self.question = question
    self.shortTitle = shortTitle
    self.detailsDeferred = detailsDeferred
    self.description = description
    self.rulesPrimary = rulesPrimary
    self.rulesSecondary = rulesSecondary
    self.volume = volume
    self.volume24hr = volume24hr
    self.status = status
    self.conditionId = conditionId
    self.arbReturn = arbReturn
    self.image = image
    self.venueEvent = venueEvent
    self.venueMarketOutcomes = venueMarketOutcomes
  }
}

/// A market: one venue's question about an event.
public struct AggVenueMarket: Codable, Equatable {
  public let id: String
  public let venue: AggVenue
  public let deployerVenue: AggVenue?
  public let marketId: String?
  public let externalIdentifier: String
  public let venueEventId: String?
  public let question: String
  public let shortTitle: String?
  /// True under `projection=summary`: description and rules were left out.
  public let detailsDeferred: Bool?
  public let description: String?
  public let rulesPrimary: String?
  public let rulesSecondary: String?
  public let conditionId: String?
  public let volume: Double?
  public let volume24hr: Double?
  public let image: String?
  public let venueMarketOutcomes: [AggVenueMarketOutcome]
  /// One of `open`, `closed`, `resolved`, `unopened`, `paused`.
  public let status: AggMarketStatus?
  public let startDate: String?
  public let endDate: String?
  public let creationDate: String?
  public let createdAt: String?
  public let updatedAt: String?
  public let resolutionDate: String?
  public let negRisk: Bool?
  public let venues: [AggVenue]?
  public let venueCount: Int?
  public let arbReturn: Double?
  /// Deterministic cross-venue join key for the same real-world contract.
  public let aggKey: String?
  public let sportsMarketType: String?
  public let sectionRank: Int?
  public let period: String?
  public let marketCategory: String?
  public let marketGroup: String?
  public let marketSubtype: String?
  public let lineValue: Double?
  /// Order constraints for this market: validate size and price against them before quoting.
  public let minOrderSize: Double?
  public let tickSize: Double?
  public let feeRate: Double?
  public let feeExponent: Double?
  /// One of `fill`, `fill_in_game_only`, `winnings`, `exit`.
  public let feeBasis: String?
  public let matchedVenueMarkets: [AggMatchedVenueMarket]?
  public let venueEvent: AggMarketEvent?

  public init(
    id: String,
    venue: AggVenue,
    deployerVenue: AggVenue? = nil,
    marketId: String? = nil,
    externalIdentifier: String,
    venueEventId: String? = nil,
    question: String,
    shortTitle: String? = nil,
    detailsDeferred: Bool? = nil,
    description: String? = nil,
    rulesPrimary: String? = nil,
    rulesSecondary: String? = nil,
    conditionId: String? = nil,
    volume: Double? = nil,
    volume24hr: Double? = nil,
    image: String? = nil,
    venueMarketOutcomes: [AggVenueMarketOutcome],
    status: AggMarketStatus? = nil,
    startDate: String? = nil,
    endDate: String? = nil,
    creationDate: String? = nil,
    createdAt: String? = nil,
    updatedAt: String? = nil,
    resolutionDate: String? = nil,
    negRisk: Bool? = nil,
    venues: [AggVenue]? = nil,
    venueCount: Int? = nil,
    arbReturn: Double? = nil,
    aggKey: String? = nil,
    sportsMarketType: String? = nil,
    sectionRank: Int? = nil,
    period: String? = nil,
    marketCategory: String? = nil,
    marketGroup: String? = nil,
    marketSubtype: String? = nil,
    lineValue: Double? = nil,
    minOrderSize: Double? = nil,
    tickSize: Double? = nil,
    feeRate: Double? = nil,
    feeExponent: Double? = nil,
    feeBasis: String? = nil,
    matchedVenueMarkets: [AggMatchedVenueMarket]? = nil,
    venueEvent: AggMarketEvent? = nil
  ) {
    self.id = id
    self.venue = venue
    self.deployerVenue = deployerVenue
    self.marketId = marketId
    self.externalIdentifier = externalIdentifier
    self.venueEventId = venueEventId
    self.question = question
    self.shortTitle = shortTitle
    self.detailsDeferred = detailsDeferred
    self.description = description
    self.rulesPrimary = rulesPrimary
    self.rulesSecondary = rulesSecondary
    self.conditionId = conditionId
    self.volume = volume
    self.volume24hr = volume24hr
    self.image = image
    self.venueMarketOutcomes = venueMarketOutcomes
    self.status = status
    self.startDate = startDate
    self.endDate = endDate
    self.creationDate = creationDate
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.resolutionDate = resolutionDate
    self.negRisk = negRisk
    self.venues = venues
    self.venueCount = venueCount
    self.arbReturn = arbReturn
    self.aggKey = aggKey
    self.sportsMarketType = sportsMarketType
    self.sectionRank = sectionRank
    self.period = period
    self.marketCategory = marketCategory
    self.marketGroup = marketGroup
    self.marketSubtype = marketSubtype
    self.lineValue = lineValue
    self.minOrderSize = minOrderSize
    self.tickSize = tickSize
    self.feeRate = feeRate
    self.feeExponent = feeExponent
    self.feeBasis = feeBasis
    self.matchedVenueMarkets = matchedVenueMarkets
    self.venueEvent = venueEvent
  }
}

/// An event: the real-world happening, aggregated across venues.
public struct AggVenueEvent: Codable, Equatable {
  public let id: String
  public let externalIdentifier: String
  public let title: String
  public let description: String?
  public let image: String?
  public let venue: AggVenue
  public let deployerVenue: AggVenue?
  public let volume: Double?
  public let status: AggMarketStatus?
  public let startDate: String?
  public let endDate: String?
  public let creationDate: String?
  public let gameStartTime: String?
  public let categories: [AggEventCategory]
  public let slug: String?
  public let subtitle: String?
  public let venues: [AggVenue]?
  /// Number of markets on the event; a list row embeds at most three.
  public let marketCount: Int?
  public let venueCount: Int?
  public let groupMarketCount: Int?
  public let groupParentId: String?
  public let updatedAt: String?
  public let venueMarkets: [AggVenueMarket]?
  public let arbReturn: Double?
  public let series: AggSeries?
  public let recurrence: String?
  public let aggKey: String?
  /// One of `candidate`, `sport`, `axis`, `dates`.
  public let structureType: String?
  public let sport: String?
  public let settlementDiff: AggSettlementDiff?
  /// One of `computed`, `pending`, `not_applicable`.
  public let settlementDiffStatus: String?
  public let matchedVenueEvents: [AggMatchedVenueEvent]?

  public init(
    id: String,
    externalIdentifier: String,
    title: String,
    description: String? = nil,
    image: String? = nil,
    venue: AggVenue,
    deployerVenue: AggVenue? = nil,
    volume: Double? = nil,
    status: AggMarketStatus? = nil,
    startDate: String? = nil,
    endDate: String? = nil,
    creationDate: String? = nil,
    gameStartTime: String? = nil,
    categories: [AggEventCategory],
    slug: String? = nil,
    subtitle: String? = nil,
    venues: [AggVenue]? = nil,
    marketCount: Int? = nil,
    venueCount: Int? = nil,
    groupMarketCount: Int? = nil,
    groupParentId: String? = nil,
    updatedAt: String? = nil,
    venueMarkets: [AggVenueMarket]? = nil,
    arbReturn: Double? = nil,
    series: AggSeries? = nil,
    recurrence: String? = nil,
    aggKey: String? = nil,
    structureType: String? = nil,
    sport: String? = nil,
    settlementDiff: AggSettlementDiff? = nil,
    settlementDiffStatus: String? = nil,
    matchedVenueEvents: [AggMatchedVenueEvent]? = nil
  ) {
    self.id = id
    self.externalIdentifier = externalIdentifier
    self.title = title
    self.description = description
    self.image = image
    self.venue = venue
    self.deployerVenue = deployerVenue
    self.volume = volume
    self.status = status
    self.startDate = startDate
    self.endDate = endDate
    self.creationDate = creationDate
    self.gameStartTime = gameStartTime
    self.categories = categories
    self.slug = slug
    self.subtitle = subtitle
    self.venues = venues
    self.marketCount = marketCount
    self.venueCount = venueCount
    self.groupMarketCount = groupMarketCount
    self.groupParentId = groupParentId
    self.updatedAt = updatedAt
    self.venueMarkets = venueMarkets
    self.arbReturn = arbReturn
    self.series = series
    self.recurrence = recurrence
    self.aggKey = aggKey
    self.structureType = structureType
    self.sport = sport
    self.settlementDiff = settlementDiff
    self.settlementDiffStatus = settlementDiffStatus
    self.matchedVenueEvents = matchedVenueEvents
  }
}

/// An event page: the event, the first page of its markets and the outcomes to chart.
public struct AggVenueEventBootstrap: Codable, Equatable {
  public let detailsDeferred: Bool
  public let event: AggVenueEvent
  public let markets: AggPage<AggVenueMarket>
  public let selectedOutcomeIds: [String]
  /// Where to read the rest: the chart history path and the live channel name.
  public let references: References
  public let freshness: Freshness

  public init(
    detailsDeferred: Bool,
    event: AggVenueEvent,
    markets: AggPage<AggVenueMarket>,
    selectedOutcomeIds: [String],
    references: References,
    freshness: Freshness
  ) {
    self.detailsDeferred = detailsDeferred
    self.event = event
    self.markets = markets
    self.selectedOutcomeIds = selectedOutcomeIds
    self.references = references
    self.freshness = freshness
  }

  /// Where to read the rest: the chart history path and the live channel name.
  public struct References: Codable, Equatable {
    public let historyManifestPath: String
    public let liveChannel: String

    public init(historyManifestPath: String, liveChannel: String) {
      self.historyManifestPath = historyManifestPath
      self.liveChannel = liveChannel
    }
  }

  public struct Freshness: Codable, Equatable {
    /// Unix milliseconds.
    public let assembledAt: Int
    public let marketStatus: AggMarketStatus?

    public init(assembledAt: Int, marketStatus: AggMarketStatus? = nil) {
      self.assembledAt = assembledAt
      self.marketStatus = marketStatus
    }
  }
}

/// Per-venue blocked countries.
public struct AggVenueGeoPolicy: Codable, Equatable {
  public let venues: [Venue]

  public init(venues: [Venue]) {
    self.venues = venues
  }

  public struct Venue: Codable, Equatable {
    public let venue: AggVenue
    public let blockedCountries: [String]
    public let allowedCountries: [String]?

    public init(venue: AggVenue, blockedCountries: [String], allowedCountries: [String]? = nil) {
      self.venue = venue
      self.blockedCountries = blockedCountries
      self.allowedCountries = allowedCountries
    }
  }
}

/// The app's venue and category switches.
public struct AggAppConfig: Codable, Equatable {
  public let disabledVenues: [AggVenue]
  public let disabledCategoryPresets: [String]
  /// `live` or `paper`.
  public let tradingMode: String
  public let earlyAccessEnabled: Bool
  public let paperStartingBalance: Double
  /// `clearinghouse` or `direct`.
  public let prophetxExecutionMode: String?
  public let novigExecutionMode: String?
  public let authOptions: [AuthOption]

  public init(
    disabledVenues: [AggVenue],
    disabledCategoryPresets: [String],
    tradingMode: String,
    earlyAccessEnabled: Bool,
    paperStartingBalance: Double,
    prophetxExecutionMode: String? = nil,
    novigExecutionMode: String? = nil,
    authOptions: [AuthOption]
  ) {
    self.disabledVenues = disabledVenues
    self.disabledCategoryPresets = disabledCategoryPresets
    self.tradingMode = tradingMode
    self.earlyAccessEnabled = earlyAccessEnabled
    self.paperStartingBalance = paperStartingBalance
    self.prophetxExecutionMode = prophetxExecutionMode
    self.novigExecutionMode = novigExecutionMode
    self.authOptions = authOptions
  }

  public struct AuthOption: Codable, Equatable {
    public let provider: String
    /// `oauth`, `email` or `wallet`.
    public let type: String
    public let enabled: Bool
    public let statement: String?
    public let callbackUrl: String?

    public init(
      provider: String,
      type: String,
      enabled: Bool,
      statement: String? = nil,
      callbackUrl: String? = nil
    ) {
      self.provider = provider
      self.type = type
      self.enabled = enabled
      self.statement = statement
      self.callbackUrl = callbackUrl
    }
  }
}

/// Search results, discriminated on `type`: the `type` the search asked for.
public enum AggSearchResults: Codable, Equatable {
  /// `type: "events"`.
  case events(Events)
  /// `type: "markets"`.
  case markets(Markets)

  public struct Events: Codable, Equatable {
    public let data: [AggVenueEvent]
    public let nextCursor: String?
    public let hasMore: Bool
    public let meta: Meta?

    public init(data: [AggVenueEvent], nextCursor: String? = nil, hasMore: Bool, meta: Meta? = nil) {
      self.data = data
      self.nextCursor = nextCursor
      self.hasMore = hasMore
      self.meta = meta
    }
  }

  public struct Markets: Codable, Equatable {
    public let data: [AggVenueMarket]
    public let nextCursor: String?
    public let hasMore: Bool
    public let meta: Meta?

    public init(data: [AggVenueMarket], nextCursor: String? = nil, hasMore: Bool, meta: Meta? = nil) {
      self.data = data
      self.nextCursor = nextCursor
      self.hasMore = hasMore
      self.meta = meta
    }
  }

  public struct Meta: Codable, Equatable {
    public let complete: Bool?
    public let degradedSignals: [String]?

    public init(complete: Bool? = nil, degradedSignals: [String]? = nil) {
      self.complete = complete
      self.degradedSignals = degradedSignals
    }
  }

  /// The wire discriminator.
  public var type: AggSearchType {
    switch self {
    case .events: return .events
    case .markets: return .markets
    }
  }

  private enum CodingKeys: String, CodingKey {
    case type
  }

  /// `/search` echoes the request's `type`, a closed set, so any other value is a malformed
  /// response.
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decode(AggSearchType.self, forKey: .type) {
    case .events:
      self = try .events(Events(from: decoder))
    case .markets:
      self = try .markets(Markets(from: decoder))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.type, forKey: .type)
    switch self {
    case let .events(value):
      try value.encode(to: encoder)
    case let .markets(value):
      try value.encode(to: encoder)
    }
  }
}
