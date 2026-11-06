//
//  AggMarketDataTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

public struct AggOrderbookLevel: Codable, Equatable {
  public let price: Double
  public let size: Double

  public init(price: Double, size: Double) {
    self.price = price
    self.size = size
  }
}

public struct AggOrderbook: Codable, Equatable {
  public let bids: [AggOrderbookLevel]
  public let asks: [AggOrderbookLevel]
  public let negRisk: Bool?

  public init(bids: [AggOrderbookLevel], asks: [AggOrderbookLevel], negRisk: Bool? = nil) {
    self.bids = bids
    self.asks = asks
    self.negRisk = negRisk
  }
}

public struct AggDepthLevel: Codable, Equatable {
  public let price: Double
  public let size: Double
  public let notionalUsd: Double
  public let cumulativeSize: Double
  public let cumulativeNotionalUsd: Double
  /// How much of a requested size fills at this level; `nil` without one.
  public let fillSize: Double?
  public let fillNotionalUsd: Double?

  public init(
    price: Double,
    size: Double,
    notionalUsd: Double,
    cumulativeSize: Double,
    cumulativeNotionalUsd: Double,
    fillSize: Double? = nil,
    fillNotionalUsd: Double? = nil
  ) {
    self.price = price
    self.size = size
    self.notionalUsd = notionalUsd
    self.cumulativeSize = cumulativeSize
    self.cumulativeNotionalUsd = cumulativeNotionalUsd
    self.fillSize = fillSize
    self.fillNotionalUsd = fillNotionalUsd
  }
}

public struct AggDepthSide: Codable, Equatable {
  public let levels: [AggDepthLevel]
  public let totalSize: Double
  public let totalNotionalUsd: Double
  public let avgPrice: Double?
  public let worstPrice: Double?
  public let fillsComplete: Bool?
  public let filledSize: Double?
  public let filledNotionalUsd: Double?
  public let requestedNotionalUsd: Double?
  public let unfilledNotionalUsd: Double?

  public init(
    levels: [AggDepthLevel],
    totalSize: Double,
    totalNotionalUsd: Double,
    avgPrice: Double? = nil,
    worstPrice: Double? = nil,
    fillsComplete: Bool? = nil,
    filledSize: Double? = nil,
    filledNotionalUsd: Double? = nil,
    requestedNotionalUsd: Double? = nil,
    unfilledNotionalUsd: Double? = nil
  ) {
    self.levels = levels
    self.totalSize = totalSize
    self.totalNotionalUsd = totalNotionalUsd
    self.avgPrice = avgPrice
    self.worstPrice = worstPrice
    self.fillsComplete = fillsComplete
    self.filledSize = filledSize
    self.filledNotionalUsd = filledNotionalUsd
    self.requestedNotionalUsd = requestedNotionalUsd
    self.unfilledNotionalUsd = unfilledNotionalUsd
  }
}

public struct AggVenueOrderbook: Codable, Equatable {
  public let venueMarketId: String
  public let tickSize: Double?
  public let sizeStepRaw: String?
  public let minSizeRaw: String?
  public let orderbook: AggOrderbook
  public let tick: Double?
  public let markSource: String?
  public let deployerVenue: AggVenue?
  /// Which sides of the book are usable, e.g. `healthy`, `bid_only`.
  public let sideHealth: String?

  public init(
    venueMarketId: String,
    tickSize: Double? = nil,
    sizeStepRaw: String? = nil,
    minSizeRaw: String? = nil,
    orderbook: AggOrderbook,
    tick: Double? = nil,
    markSource: String? = nil,
    deployerVenue: AggVenue? = nil,
    sideHealth: String? = nil
  ) {
    self.venueMarketId = venueMarketId
    self.tickSize = tickSize
    self.sizeStepRaw = sizeStepRaw
    self.minSizeRaw = minSizeRaw
    self.orderbook = orderbook
    self.tick = tick
    self.markSource = markSource
    self.deployerVenue = deployerVenue
    self.sideHealth = sideHealth
  }
}

public struct AggMidpointOutcome: Codable, Equatable {
  public let venueMarketOutcomeId: String
  public let label: String
  public let midpoint: Double?
  public let markSource: String?
  public let bookQuality: String?
  public let bestBid: Double?
  public let bestAsk: Double?

  public init(
    venueMarketOutcomeId: String,
    label: String,
    midpoint: Double? = nil,
    markSource: String? = nil,
    bookQuality: String? = nil,
    bestBid: Double? = nil,
    bestAsk: Double? = nil
  ) {
    self.venueMarketOutcomeId = venueMarketOutcomeId
    self.label = label
    self.midpoint = midpoint
    self.markSource = markSource
    self.bookQuality = bookQuality
    self.bestBid = bestBid
    self.bestAsk = bestAsk
  }
}

/// Live midpoints for a batch of markets.
public struct AggMidpoints: Codable, Equatable {
  public let data: [Market]

  public init(data: [Market]) {
    self.data = data
  }

  public struct Market: Codable, Equatable {
    public let venueMarketId: String
    public let venue: AggVenue
    public let midpoint: Double?
    public let spread: Double?
    public let timestamp: Int?
    public let outcomes: [AggMidpointOutcome]
    public let matched: [Matched]
    public let markSource: String?
    public let siblingVenueMarketId: String?
    public let bestBid: Double?
    public let bestAsk: Double?
    public let arbReturn: Double?
    public let marketStatus: AggMarketStatus?
    public let error: Failure?

    public init(
      venueMarketId: String,
      venue: AggVenue,
      midpoint: Double? = nil,
      spread: Double? = nil,
      timestamp: Int? = nil,
      outcomes: [AggMidpointOutcome],
      matched: [Matched],
      markSource: String? = nil,
      siblingVenueMarketId: String? = nil,
      bestBid: Double? = nil,
      bestAsk: Double? = nil,
      arbReturn: Double? = nil,
      marketStatus: AggMarketStatus? = nil,
      error: Failure? = nil
    ) {
      self.venueMarketId = venueMarketId
      self.venue = venue
      self.midpoint = midpoint
      self.spread = spread
      self.timestamp = timestamp
      self.outcomes = outcomes
      self.matched = matched
      self.markSource = markSource
      self.siblingVenueMarketId = siblingVenueMarketId
      self.bestBid = bestBid
      self.bestAsk = bestAsk
      self.arbReturn = arbReturn
      self.marketStatus = marketStatus
      self.error = error
    }

    public struct Matched: Codable, Equatable {
      public let venueMarketId: String
      public let venue: AggVenue
      public let midpoint: Double?
      public let outcomes: [Outcome]?
      public let bestBid: Double?
      public let bestAsk: Double?

      public init(
        venueMarketId: String,
        venue: AggVenue,
        midpoint: Double? = nil,
        outcomes: [Outcome]? = nil,
        bestBid: Double? = nil,
        bestAsk: Double? = nil
      ) {
        self.venueMarketId = venueMarketId
        self.venue = venue
        self.midpoint = midpoint
        self.outcomes = outcomes
        self.bestBid = bestBid
        self.bestAsk = bestAsk
      }

      public struct Outcome: Codable, Equatable {
        public let venueMarketOutcomeId: String
        public let label: String?
        public let midpoint: Double?
        public let bestBid: Double?
        public let bestAsk: Double?

        public init(
          venueMarketOutcomeId: String,
          label: String? = nil,
          midpoint: Double? = nil,
          bestBid: Double? = nil,
          bestAsk: Double? = nil
        ) {
          self.venueMarketOutcomeId = venueMarketOutcomeId
          self.label = label
          self.midpoint = midpoint
          self.bestBid = bestBid
          self.bestAsk = bestAsk
        }
      }
    }

    public struct Failure: Codable, Equatable {
      public let code: String
      public let message: String
      public let retryable: Bool

      public init(code: String, message: String, retryable: Bool) {
        self.code = code
        self.message = message
        self.retryable = retryable
      }
    }
  }
}

/// Live books for a batch of markets.
public struct AggOrderbooks: Codable, Equatable {
  public let data: [Market]
  public let meta: Meta

  public init(data: [Market], meta: Meta) {
    self.data = data
    self.meta = meta
  }

  public struct Market: Codable, Equatable {
    public let venueMarketId: String
    /// `ok`, or why the book is missing, e.g. `market_resolved`.
    public let status: String
    public let error: Failure?
    public let requestedMarket: RequestedMarket?
    public let venueOrderbooks: [String: AggVenueOrderbook]
    public let matchedMarkets: [MatchedMarket]

    public init(
      venueMarketId: String,
      status: String,
      error: Failure? = nil,
      requestedMarket: RequestedMarket? = nil,
      venueOrderbooks: [String: AggVenueOrderbook],
      matchedMarkets: [MatchedMarket]
    ) {
      self.venueMarketId = venueMarketId
      self.status = status
      self.error = error
      self.requestedMarket = requestedMarket
      self.venueOrderbooks = venueOrderbooks
      self.matchedMarkets = matchedMarkets
    }

    public struct Failure: Codable, Equatable {
      public let code: String
      public let message: String
      public let retryable: Bool

      public init(code: String, message: String, retryable: Bool) {
        self.code = code
        self.message = message
        self.retryable = retryable
      }
    }

    public struct RequestedMarket: Codable, Equatable {
      public let venueMarketId: String
      public let venue: AggVenue
      public let marketStatus: AggMarketStatus
      public let tickSize: Double?
      public let sizeStepRaw: String?
      public let minSizeRaw: String?
      public let endDate: String?
      public let resolutionDate: String?

      public init(
        venueMarketId: String,
        venue: AggVenue,
        marketStatus: AggMarketStatus,
        tickSize: Double? = nil,
        sizeStepRaw: String? = nil,
        minSizeRaw: String? = nil,
        endDate: String? = nil,
        resolutionDate: String? = nil
      ) {
        self.venueMarketId = venueMarketId
        self.venue = venue
        self.marketStatus = marketStatus
        self.tickSize = tickSize
        self.sizeStepRaw = sizeStepRaw
        self.minSizeRaw = minSizeRaw
        self.endDate = endDate
        self.resolutionDate = resolutionDate
      }
    }

    public struct MatchedMarket: Codable, Equatable {
      public let venue: AggVenue
      public let venueMarketId: String
      public let marketStatus: AggMarketStatus
      public let tickSize: Double?
      public let sizeStepRaw: String?
      public let minSizeRaw: String?
      public let hasOrderbook: Bool
      public let deployerVenue: AggVenue?

      public init(
        venue: AggVenue,
        venueMarketId: String,
        marketStatus: AggMarketStatus,
        tickSize: Double? = nil,
        sizeStepRaw: String? = nil,
        minSizeRaw: String? = nil,
        hasOrderbook: Bool,
        deployerVenue: AggVenue? = nil
      ) {
        self.venue = venue
        self.venueMarketId = venueMarketId
        self.marketStatus = marketStatus
        self.tickSize = tickSize
        self.sizeStepRaw = sizeStepRaw
        self.minSizeRaw = minSizeRaw
        self.hasOrderbook = hasOrderbook
        self.deployerVenue = deployerVenue
      }
    }
  }

  public struct Meta: Codable, Equatable {
    public let requestedCount: Int
    public let okCount: Int
    public let errorCount: Int

    public init(requestedCount: Int, okCount: Int, errorCount: Int) {
      self.requestedCount = requestedCount
      self.okCount = okCount
      self.errorCount = errorCount
    }
  }
}

/// One outcome's ladder and depth.
public struct AggOutcomeOrderbook: Codable, Equatable {
  public let venueMarketOutcomeId: String
  public let venueMarketId: String
  public let venue: AggVenue
  public let orderbook: AggOrderbook
  public let midpoint: Double?
  public let spread: Double?
  public let seq: Int
  public let checksum: Int
  public let timestamp: Int
  public let tick: Double?
  public let markSource: String
  public let depthSummary: DepthSummary?

  public init(
    venueMarketOutcomeId: String,
    venueMarketId: String,
    venue: AggVenue,
    orderbook: AggOrderbook,
    midpoint: Double? = nil,
    spread: Double? = nil,
    seq: Int,
    checksum: Int,
    timestamp: Int,
    tick: Double? = nil,
    markSource: String,
    depthSummary: DepthSummary? = nil
  ) {
    self.venueMarketOutcomeId = venueMarketOutcomeId
    self.venueMarketId = venueMarketId
    self.venue = venue
    self.orderbook = orderbook
    self.midpoint = midpoint
    self.spread = spread
    self.seq = seq
    self.checksum = checksum
    self.timestamp = timestamp
    self.tick = tick
    self.markSource = markSource
    self.depthSummary = depthSummary
  }

  public struct DepthSummary: Codable, Equatable {
    public let currency: String
    public let amountUsd: Double?
    public let buy: AggDepthSide
    public let sell: AggDepthSide

    public init(
      currency: String,
      amountUsd: Double? = nil,
      buy: AggDepthSide,
      sell: AggDepthSide
    ) {
      self.currency = currency
      self.amountUsd = amountUsd
      self.buy = buy
      self.sell = sell
    }
  }
}

public struct AggChartMeta: Codable, Equatable {
  public let state: AggChartState?
  public let complete: Bool?
  public let retryAfterMs: Int?
  public let fetchedAtMs: Int?
  public let serverTime: Int
  public let lastBarOpenTime: Int?
  public let staleSeconds: Double?

  public init(
    state: AggChartState? = nil,
    complete: Bool? = nil,
    retryAfterMs: Int? = nil,
    fetchedAtMs: Int? = nil,
    serverTime: Int,
    lastBarOpenTime: Int? = nil,
    staleSeconds: Double? = nil
  ) {
    self.state = state
    self.complete = complete
    self.retryAfterMs = retryAfterMs
    self.fetchedAtMs = fetchedAtMs
    self.serverTime = serverTime
    self.lastBarOpenTime = lastBarOpenTime
    self.staleSeconds = staleSeconds
  }
}

public struct AggChartBar: Codable, Equatable {
  public let t: Int
  public let o: Double
  public let h: Double
  public let l: Double
  public let c: Double
  public let v: Double?
  public let mean: Double?

  public init(
    t: Int,
    o: Double,
    h: Double,
    l: Double,
    c: Double,
    v: Double? = nil,
    mean: Double? = nil
  ) {
    self.t = t
    self.o = o
    self.h = h
    self.l = l
    self.c = c
    self.v = v
    self.mean = mean
  }
}

/// OHLCV bars for an outcome.
public struct AggChartBars: Codable, Equatable {
  public let venueMarketOutcomeId: String
  public let venue: AggVenue
  public let resolution: String
  public let data: [AggChartBar]
  public let meta: AggChartMeta

  public init(
    venueMarketOutcomeId: String,
    venue: AggVenue,
    resolution: String,
    data: [AggChartBar],
    meta: AggChartMeta
  ) {
    self.venueMarketOutcomeId = venueMarketOutcomeId
    self.venue = venue
    self.resolution = resolution
    self.data = data
    self.meta = meta
  }
}

/// CDN chunks of finalized chart history.
public struct AggChartHistoryManifest: Codable, Equatable {
  public let version: Int
  public let revision: String?
  public let venueMarketOutcomeId: String
  public let venue: AggVenue
  public let resolution: String
  public let semantics: String
  public let from: Int
  public let to: Int
  public let finalizedThrough: Int
  public let chunks: [Chunk]
  public let meta: AggChartMeta

  public init(
    version: Int,
    revision: String? = nil,
    venueMarketOutcomeId: String,
    venue: AggVenue,
    resolution: String,
    semantics: String,
    from: Int,
    to: Int,
    finalizedThrough: Int,
    chunks: [Chunk],
    meta: AggChartMeta
  ) {
    self.version = version
    self.revision = revision
    self.venueMarketOutcomeId = venueMarketOutcomeId
    self.venue = venue
    self.resolution = resolution
    self.semantics = semantics
    self.from = from
    self.to = to
    self.finalizedThrough = finalizedThrough
    self.chunks = chunks
    self.meta = meta
  }

  public struct Chunk: Codable, Equatable {
    public let key: String
    public let url: String
    public let sha256: String
    public let from: Int
    public let to: Int
    public let points: Int

    public init(
      key: String,
      url: String,
      sha256: String,
      from: Int,
      to: Int,
      points: Int
    ) {
      self.key = key
      self.url = url
      self.sha256 = sha256
      self.from = from
      self.to = to
      self.points = points
    }
  }
}
