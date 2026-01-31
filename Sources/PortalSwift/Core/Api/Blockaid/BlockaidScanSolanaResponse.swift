//
//  BlockaidScanSolanaResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - BlockaidScanSolanaResponse

public struct BlockaidScanSolanaResponse: Codable {
  public let data: BlockaidScanSolanaData?
}

public struct BlockaidScanSolanaData: Codable {
  public let rawResponse: BlockaidScanSolanaRawResponse
}

public struct BlockaidScanSolanaRawResponse: Codable {
  public let encoding: String?
  public let status: String?
  public let result: BlockaidSolanaResult?
  public let error: String?
  public let errorDetails: [String: String]?
  public let requestId: String?

  private enum CodingKeys: String, CodingKey {
    case encoding, status, result, error
    case errorDetails = "error_details"
    case requestId = "request_id"
  }
}

// MARK: - BlockaidSolanaResult

public struct BlockaidSolanaResult: Codable {
  public let simulation: BlockaidSolanaSimulation?
  public let validation: BlockaidSolanaValidation?
}

// MARK: - BlockaidSolanaValidation

public struct BlockaidSolanaValidation: Codable {
  public let resultType: String
  public let reason: String?
  public let features: [String]?
  public let extendedFeatures: [BlockaidSolanaExtendedFeature]?

  private enum CodingKeys: String, CodingKey {
    case reason, features
    case resultType = "result_type"
    case extendedFeatures = "extended_features"
  }
}

public struct BlockaidSolanaExtendedFeature: Codable {
  public let type: String
  public let featureId: String
  public let description: String
  public let address: String?

  private enum CodingKeys: String, CodingKey {
    case type, description, address
    case featureId = "feature_id"
  }
}

// MARK: - BlockaidSolanaSimulation

public struct BlockaidSolanaSimulation: Codable {
  public let assetsDiff: [String: [BlockaidSolanaAssetDiff]]?
  public let delegations: [String: [[String: String]]]?
  public let assetsOwnershipDiff: [String: [[String: String]]]?
  public let accountsDetails: [BlockaidSolanaAccountDetails]?
  public let accountSummary: BlockaidSolanaAccountSummary?
  public let transactionActions: [String]?

  private enum CodingKeys: String, CodingKey {
    case delegations
    case assetsDiff = "assets_diff"
    case assetsOwnershipDiff = "assets_ownership_diff"
    case accountsDetails = "accounts_details"
    case accountSummary = "account_summary"
    case transactionActions = "transaction_actions"
  }
}

// MARK: - BlockaidSolanaAssetDiff

public struct BlockaidSolanaAssetDiff: Codable {
  public let asset: BlockaidSolanaAsset
  public let `in`: BlockaidSolanaAssetDiffMovement?
  public let out: BlockaidSolanaAssetDiffMovement?
  public let assetType: String

  private enum CodingKeys: String, CodingKey {
    case asset, `in`, out
    case assetType = "asset_type"
  }
}

public struct BlockaidSolanaAsset: Codable {
  public let type: String
  public let name: String?
  public let symbol: String?
  public let decimals: Int?
  public let logo: String?
  public let address: String?
}

public struct BlockaidSolanaAssetDiffMovement: Codable {
  public let usdPrice: Double?
  public let summary: String?
  public let value: Double?
  public let rawValue: Int?

  private enum CodingKeys: String, CodingKey {
    case summary, value
    case usdPrice = "usd_price"
    case rawValue = "raw_value"
  }
}

// MARK: - BlockaidSolanaAccountDetails

public struct BlockaidSolanaAccountDetails: Codable {
  public let accountAddress: String
  public let description: String?
  public let type: String
  public let wasWrittenTo: Bool?

  private enum CodingKeys: String, CodingKey {
    case description, type
    case accountAddress = "account_address"
    case wasWrittenTo = "was_written_to"
  }
}

// MARK: - BlockaidSolanaAccountSummary

public struct BlockaidSolanaAccountSummary: Codable {
  public let accountAssetsDiff: [BlockaidSolanaAssetDiff]?
  public let accountDelegations: [[String: String]]?
  public let accountOwnershipsDiff: [[String: String]]?
  public let totalUsdDiff: BlockaidSolanaTotalUsdDiff?
  public let totalUsdExposure: [String: String]?

  private enum CodingKeys: String, CodingKey {
    case accountAssetsDiff = "account_assets_diff"
    case accountDelegations = "account_delegations"
    case accountOwnershipsDiff = "account_ownerships_diff"
    case totalUsdDiff = "total_usd_diff"
    case totalUsdExposure = "total_usd_exposure"
  }
}

public struct BlockaidSolanaTotalUsdDiff: Codable {
  public let `in`: Double?
  public let out: Double?
  public let total: Double?
}
