//
//  BlockaidScanTokensResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - BlockaidScanTokensResponse

public struct BlockaidScanTokensResponse: Codable {
  public let data: BlockaidScanTokensData?
  public let error: String?
}

public struct BlockaidScanTokensData: Codable {
  public let rawResponse: BlockaidScanTokensRawResponse
}

public struct BlockaidScanTokensRawResponse: Codable {
  public let results: [String: BlockaidTokenResult]
}

// MARK: - BlockaidTokenResult

public struct BlockaidTokenResult: Codable {
  public let resultType: String
  public let maliciousScore: String?
  public let attackTypes: [String: BlockaidAttackType]?
  public let chain: String
  public let address: String
  public let metadata: BlockaidTokenMetadataResult?
  public let fees: BlockaidTokenFees?
  public let features: [BlockaidTokenFeature]?
  public let tradingLimits: BlockaidTradingLimits?
  public let financialStats: BlockaidFinancialStats?

  private enum CodingKeys: String, CodingKey {
    case chain, address, metadata, fees, features
    case resultType = "result_type"
    case maliciousScore = "malicious_score"
    case attackTypes = "attack_types"
    case tradingLimits = "trading_limits"
    case financialStats = "financial_stats"
  }
}

// MARK: - BlockaidAttackType

public struct BlockaidAttackType: Codable {
  public let score: String?
  public let threshold: String?
  public let features: [String: String]?
}

// MARK: - BlockaidTokenMetadataResult

public struct BlockaidTokenMetadataResult: Codable {
  public let type: String?
  public let name: String?
  public let symbol: String?
  public let decimals: Int?
  public let imageUrl: String?
  public let description: String?
  public let deployer: String?
  public let deployerBalance: BlockaidAmount?
  public let contractBalance: BlockaidAmount?
  public let ownerBalance: BlockaidAmount?
  public let owner: String?
  public let creationTimestamp: String?
  public let externalLinks: BlockaidExternalLinks?
  public let urls: [String]?
  public let maliciousUrls: [String]?
  public let tokenCreationInitiator: String?

  private enum CodingKeys: String, CodingKey {
    case type, name, symbol, decimals, description, deployer, owner, urls
    case imageUrl = "image_url"
    case deployerBalance = "deployer_balance"
    case contractBalance = "contract_balance"
    case ownerBalance = "owner_balance"
    case creationTimestamp = "creation_timestamp"
    case externalLinks = "external_links"
    case maliciousUrls = "malicious_urls"
    case tokenCreationInitiator = "token_creation_initiator"
  }
}

// MARK: - BlockaidAmount

public struct BlockaidAmount: Codable {
  public let amount: Double?
  public let amountWei: String?

  private enum CodingKeys: String, CodingKey {
    case amount
    case amountWei = "amount_wei"
  }
}

// MARK: - BlockaidExternalLinks

public struct BlockaidExternalLinks: Codable {
  public let homepage: String?
  public let twitterPage: String?
  public let telegramChannelId: String?

  private enum CodingKeys: String, CodingKey {
    case homepage
    case twitterPage = "twitter_page"
    case telegramChannelId = "telegram_channel_id"
  }
}

// MARK: - BlockaidTokenFees

public struct BlockaidTokenFees: Codable {
  public let transfer: Double?
  public let transferFeeMaxAmount: Double?
  public let buy: Double?
  public let sell: Double?

  private enum CodingKeys: String, CodingKey {
    case transfer, buy, sell
    case transferFeeMaxAmount = "transfer_fee_max_amount"
  }
}

// MARK: - BlockaidTokenFeature

public struct BlockaidTokenFeature: Codable {
  public let featureId: String
  public let type: String
  public let description: String

  private enum CodingKeys: String, CodingKey {
    case type, description
    case featureId = "feature_id"
  }
}

// MARK: - BlockaidTradingLimits

public struct BlockaidTradingLimits: Codable {
  public let maxBuy: BlockaidAmount?
  public let maxSell: BlockaidAmount?
  public let maxHolding: BlockaidAmount?
  public let sellLimitPerBlock: BlockaidAmount?

  private enum CodingKeys: String, CodingKey {
    case maxBuy = "max_buy"
    case maxSell = "max_sell"
    case maxHolding = "max_holding"
    case sellLimitPerBlock = "sell_limit_per_block"
  }
}

// MARK: - BlockaidFinancialStats

public struct BlockaidFinancialStats: Codable {
  public let supply: Double?
  public let holdersCount: Int?
  public let usdPricePerUnit: Double?
  public let burnedLiquidityPercentage: Double?
  public let lockedLiquidityPercentage: Double?
  public let topHolders: [BlockaidTopHolder]?
  public let totalReserveInUsd: Double?
  public let devHoldingPercentage: Double?
  public let snipersHoldingPercentage: Double?
  public let initialSnipersHoldingPercentage: Double?
  public let bundlersHoldingPercentage: Double?
  public let insidersHoldingPercentage: Double?

  private enum CodingKeys: String, CodingKey {
    case supply
    case holdersCount = "holders_count"
    case usdPricePerUnit = "usd_price_per_unit"
    case burnedLiquidityPercentage = "burned_liquidity_percentage"
    case lockedLiquidityPercentage = "locked_liquidity_percentage"
    case topHolders = "top_holders"
    case totalReserveInUsd = "total_reserve_in_usd"
    case devHoldingPercentage = "dev_holding_percentage"
    case snipersHoldingPercentage = "snipers_holding_percentage"
    case initialSnipersHoldingPercentage = "initial_snipers_holding_percentage"
    case bundlersHoldingPercentage = "bundlers_holding_percentage"
    case insidersHoldingPercentage = "insiders_holding_percentage"
  }
}

// MARK: - BlockaidTopHolder

public struct BlockaidTopHolder: Codable {
  public let address: String?
  public let holdingPercentage: Double?

  private enum CodingKeys: String, CodingKey {
    case address
    case holdingPercentage = "holding_percentage"
  }
}
