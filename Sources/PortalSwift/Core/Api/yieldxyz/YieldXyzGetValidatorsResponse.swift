//
//  YieldXyzGetValidatorsResponse.swift
//  PortalSwift
//
//  Created by Portal Labs
//

import Foundation

/// Response containing validators for a native-staking yield.
public struct YieldXyzGetValidatorsResponse: Codable {
  public let data: YieldXyzGetValidatorsData?
  public let error: String?

  public init(data: YieldXyzGetValidatorsData? = nil, error: String? = nil) {
    self.data = data
    self.error = error
  }
}

public struct YieldXyzGetValidatorsData: Codable {
  /// Some backends place validators directly on `data`; most nest them in `rawResponse`.
  public let validators: [YieldXyzValidator]?
  public let rawResponse: YieldXyzGetValidatorsRawResponse?

  public init(validators: [YieldXyzValidator]? = nil, rawResponse: YieldXyzGetValidatorsRawResponse? = nil) {
    self.validators = validators
    self.rawResponse = rawResponse
  }
}

public struct YieldXyzGetValidatorsRawResponse: Codable {
  public let items: [YieldXyzValidator]?
  public let validators: [YieldXyzValidator]?
  public let limit: Int?
  public let offset: Int?
  public let total: Int?

  public init(
    items: [YieldXyzValidator]? = nil,
    validators: [YieldXyzValidator]? = nil,
    limit: Int? = nil,
    offset: Int? = nil,
    total: Int? = nil
  ) {
    self.items = items
    self.validators = validators
    self.limit = limit
    self.offset = offset
    self.total = total
  }
}

/// A validator for a native-staking yield (e.g. Monad, Ethereum 2.0).
public struct YieldXyzValidator: Codable {
  public let address: String
  public let name: String?
  public let logoURI: String?
  public let website: String?
  public let rewardRate: YieldXyzRewardRate?
  public let provider: YieldXyzProvider?
  public let commission: Double?
  public let tvlUsd: String?
  public let tvl: String?
  public let tvlRaw: String?
  public let votingPower: Double?
  public let preferred: Bool?
  public let minimumStake: String?
  public let remainingPossibleStake: String?
  public let remainingSlots: Int?
  public let nominatorCount: Int?
  public let status: String?
  public let providerId: String?
  public let pricePerShare: String?
  public let subnetId: Int?
  public let subnetName: String?
  public let marketCap: String?
  public let tokenSymbol: String?

  public init(
    address: String,
    name: String? = nil,
    logoURI: String? = nil,
    website: String? = nil,
    rewardRate: YieldXyzRewardRate? = nil,
    provider: YieldXyzProvider? = nil,
    commission: Double? = nil,
    tvlUsd: String? = nil,
    tvl: String? = nil,
    tvlRaw: String? = nil,
    votingPower: Double? = nil,
    preferred: Bool? = nil,
    minimumStake: String? = nil,
    remainingPossibleStake: String? = nil,
    remainingSlots: Int? = nil,
    nominatorCount: Int? = nil,
    status: String? = nil,
    providerId: String? = nil,
    pricePerShare: String? = nil,
    subnetId: Int? = nil,
    subnetName: String? = nil,
    marketCap: String? = nil,
    tokenSymbol: String? = nil
  ) {
    self.address = address
    self.name = name
    self.logoURI = logoURI
    self.website = website
    self.rewardRate = rewardRate
    self.provider = provider
    self.commission = commission
    self.tvlUsd = tvlUsd
    self.tvl = tvl
    self.tvlRaw = tvlRaw
    self.votingPower = votingPower
    self.preferred = preferred
    self.minimumStake = minimumStake
    self.remainingPossibleStake = remainingPossibleStake
    self.remainingSlots = remainingSlots
    self.nominatorCount = nominatorCount
    self.status = status
    self.providerId = providerId
    self.pricePerShare = pricePerShare
    self.subnetId = subnetId
    self.subnetName = subnetName
    self.marketCap = marketCap
    self.tokenSymbol = tokenSymbol
  }
}

/// A yield/validator provider.
public struct YieldXyzProvider: Codable {
  public let name: String?
  public let uniqueId: String?
  public let website: String?
  public let rank: Int?
  public let preferred: Bool?
  public let revshare: YieldXyzRevshare?

  public init(
    name: String? = nil,
    uniqueId: String? = nil,
    website: String? = nil,
    rank: Int? = nil,
    preferred: Bool? = nil,
    revshare: YieldXyzRevshare? = nil
  ) {
    self.name = name
    self.uniqueId = uniqueId
    self.website = website
    self.rank = rank
    self.preferred = preferred
    self.revshare = revshare
  }
}

/// Revenue-share configuration tiers for a provider.
public struct YieldXyzRevshare: Codable {
  public let trial: YieldXyzRevshareTier?
  public let standard: YieldXyzRevshareTier?
  public let pro: YieldXyzRevshareTier?

  public init(
    trial: YieldXyzRevshareTier? = nil,
    standard: YieldXyzRevshareTier? = nil,
    pro: YieldXyzRevshareTier? = nil
  ) {
    self.trial = trial
    self.standard = standard
    self.pro = pro
  }
}

/// A single revenue-share tier.
public struct YieldXyzRevshareTier: Codable {
  public let minRevShare: Double?
  public let maxRevShare: Double?

  public init(minRevShare: Double? = nil, maxRevShare: Double? = nil) {
    self.minRevShare = minRevShare
    self.maxRevShare = maxRevShare
  }
}
