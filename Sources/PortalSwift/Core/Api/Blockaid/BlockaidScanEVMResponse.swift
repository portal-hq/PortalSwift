//
//  BlockaidScanEVMResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - BlockaidScanEVMResponse

public struct BlockaidScanEVMResponse: Codable {
  public let data: BlockaidScanEVMData?
  public let error: String?
}

public struct BlockaidScanEVMData: Codable {
  public let rawResponse: BlockaidScanEVMRawResponse
}

public struct BlockaidScanEVMRawResponse: Codable {
  public let validation: BlockaidValidationResult?
  public let simulation: BlockaidSimulationResult?
  public let block: String
  public let chain: String
  public let accountAddress: String?

  private enum CodingKeys: String, CodingKey {
    case validation, simulation, block, chain
    case accountAddress = "account_address"
  }
}

// MARK: - BlockaidValidationResult

public struct BlockaidValidationResult: Codable {
  public let status: String
  public let resultType: String
  public let classification: String?
  public let reason: String?
  public let description: String?
  public let features: [BlockaidValidationFeature]?

  private enum CodingKeys: String, CodingKey {
    case status, classification, reason, description, features
    case resultType = "result_type"
  }
}

public struct BlockaidValidationFeature: Codable {
  public let entity: String?
  public let type: String
  public let featureId: String
  public let description: String
  public let address: String?

  private enum CodingKeys: String, CodingKey {
    case entity, type, description, address
    case featureId = "feature_id"
  }
}

// MARK: - BlockaidSimulationResult

public struct BlockaidSimulationResult: Codable {
  public let status: String
  public let assetsDiffs: [String: [BlockaidAssetDiffResult]]?
  public let transactionActions: [String]?
  public let params: BlockaidSimulationParams?
  public let totalUsdDiff: [String: BlockaidTotalUsdDiff]?
  public let exposures: [String: [[String: String]]]?
  public let totalUsdExposure: [String: String]?
  public let addressDetails: [String: BlockaidAddressDetails]?
  public let accountSummary: BlockaidAccountSummary?

  private enum CodingKeys: String, CodingKey {
    case status, params, exposures
    case assetsDiffs = "assets_diffs"
    case transactionActions = "transaction_actions"
    case totalUsdDiff = "total_usd_diff"
    case totalUsdExposure = "total_usd_exposure"
    case addressDetails = "address_details"
    case accountSummary = "account_summary"
  }
}

public struct BlockaidSimulationParams: Codable {
  public let from: String?
  public let to: String?
  public let value: String?
  public let data: String?
  public let blockTag: String?
  public let chain: String?

  private enum CodingKeys: String, CodingKey {
    case from, to, value, data, chain
    case blockTag = "block_tag"
  }
}

// MARK: - BlockaidAssetDiffResult

public struct BlockaidAssetDiffResult: Codable {
  public let assetType: String
  public let asset: BlockaidAsset
  public let `in`: [BlockaidAssetDiffMovement]?
  public let out: [BlockaidAssetDiffMovement]?
  public let balanceChanges: BlockaidBalanceChanges?

  private enum CodingKeys: String, CodingKey {
    case asset, `in`, out
    case assetType = "asset_type"
    case balanceChanges = "balance_changes"
  }
}

public struct BlockaidAsset: Codable {
  public let type: String
  public let chainName: String?
  public let decimals: Int?
  public let chainId: Int?
  public let logoUrl: String?
  public let name: String?
  public let symbol: String?
  public let address: String?

  private enum CodingKeys: String, CodingKey {
    case type, decimals, name, symbol, address
    case chainName = "chain_name"
    case chainId = "chain_id"
    case logoUrl = "logo_url"
  }
}

public struct BlockaidAssetDiffMovement: Codable {
  public let usdPrice: String?
  public let summary: String?
  public let value: String?
  public let rawValue: String?

  private enum CodingKeys: String, CodingKey {
    case summary, value
    case usdPrice = "usd_price"
    case rawValue = "raw_value"
  }
}

public struct BlockaidBalanceChanges: Codable {
  public let before: BlockaidBalanceState?
  public let after: BlockaidBalanceState?
}

public struct BlockaidBalanceState: Codable {
  public let usdPrice: String?
  public let value: String?
  public let rawValue: String?

  private enum CodingKeys: String, CodingKey {
    case value
    case usdPrice = "usd_price"
    case rawValue = "raw_value"
  }
}

// MARK: - BlockaidAddressDetails

public struct BlockaidAddressDetails: Codable {
  public let isEoa: Bool?
  public let nameTag: String?

  private enum CodingKeys: String, CodingKey {
    case isEoa = "is_eoa"
    case nameTag = "name_tag"
  }
}

// MARK: - BlockaidAccountSummary

public struct BlockaidAccountSummary: Codable {
  public let assetsDiffs: [BlockaidAssetDiffResult]?
  public let traces: [BlockaidAssetTrace]?
  public let totalUsdDiff: BlockaidTotalUsdDiff?
  public let exposures: [[String: String]]?
  public let totalUsdExposure: [String: String]?

  private enum CodingKeys: String, CodingKey {
    case traces, exposures
    case assetsDiffs = "assets_diffs"
    case totalUsdDiff = "total_usd_diff"
    case totalUsdExposure = "total_usd_exposure"
  }
}

public struct BlockaidAssetTrace: Codable {
  public let type: String?
  public let traceType: String?
  public let fromAddress: String?
  public let toAddress: String?
  public let asset: BlockaidAsset?
  public let diff: BlockaidAssetDiffMovement?

  private enum CodingKeys: String, CodingKey {
    case type, asset, diff
    case traceType = "trace_type"
    case fromAddress = "from_address"
    case toAddress = "to_address"
  }
}

// MARK: - BlockaidTotalUsdDiff

public struct BlockaidTotalUsdDiff: Codable {
  public let `in`: String?
  public let out: String?
  public let total: String?
}
