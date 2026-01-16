//
//  ScanEVMResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - ScanEVMResponse

public struct ScanEVMResponse: Codable {
  public let data: ScanEVMData?
  public let error: String?
}

public struct ScanEVMData: Codable {
  public let rawResponse: ScanEVMRawResponse
}

public struct ScanEVMRawResponse: Codable {
  public let success: Bool
  public let data: ScanEVMRiskData?
  public let error: String?
  public let version: String?
  public let service: String?
}

public struct ScanEVMRiskData: Codable {
  public let assessmentId: String?
  public let assessmentTimestamp: String?
  public let recommendation: String
  public let findings: [ScanEVMFinding]?
  public let balanceChanges: [String: [ScanEVMBalanceChange]]?
  public let parsedActions: ScanEVMParsedActions?
  public let blockNumber: Int?
  public let trace: [ScanEVMTrace]?
  public let riIds: [String]?
}

// MARK: - EVM-Specific Types

public struct ScanEVMFinding: Codable {
  public let typeId: String
  public let title: String
  public let description: String
  public let details: String?
  public let severity: String
  public let relatedAssets: [ScanEVMAsset]?
}

public struct ScanEVMAsset: Codable {
  public let chain: String
  public let evmChainId: String?
  public let address: String
  public let type: String
  public let involvementTypes: [String]
  public let alias: String?
  public let tag: String
}

public struct ScanEVMBalanceChange: Codable {
  public let changeType: String
  public let tokenSymbol: String
  public let tokenAddress: String?
  public let usdValue: String?
  public let amount: String
  public let chain: String
  public let evmChainId: String?
}

public struct ScanEVMParsedActions: Codable {
  public let ethValues: [ScanEVMParsedActionItem]?
  public let tokenValues: [ScanEVMParsedActionItem]?
  public let nftValues: [ScanEVMParsedActionItem]?
  public let approval: [ScanEVMApprovalItem]?
  public let approve: [ScanEVMApproveItem]?

  private enum CodingKeys: String, CodingKey {
    case ethValues, tokenValues, nftValues, approval
    case approve = "Approve"
  }
}

public struct ScanEVMApproveItem: Codable {
  public let from: String?
  public let to: String?
}

public struct ScanEVMParsedActionItem: Codable {
  public let amountInUsd: Double?
  public let amount: Double?
  public let from: String?
  public let to: String?
  public let decimals: Int?
  public let decimalValue: Int?
  public let callIndex: Int?
  public let price: Double?
  public let priceSource: String?
}

public struct ScanEVMApprovalItem: Codable {
  public let tokenName: String?
  public let tokenSymbol: String?
  public let tokenAddress: String?
  public let tokenTotalSupply: Double?
  public let tokenMarketCap: Double?
  public let tokenTotalVolume: Double?
  public let amountInUsd: Double?
  public let amount: Double?
  public let amountAfterDecimals: Double?
  public let tokenId: Int?
  public let owner: String?
  public let spender: String?
  public let isNft: Bool?
  public let priceSource: String?
  public let logIndex: Int?
  public let action: String?
}

public struct ScanEVMTrace: Codable {
  public let from: String
  public let to: String
  public let funcId: String?
  public let callType: String?
  public let value: Int?
  public let traceAddress: [Int]?
  public let status: Int?
  public let callInput: String?
  public let extraInfo: [String: String]?
}
