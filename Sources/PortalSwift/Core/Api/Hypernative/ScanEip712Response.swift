//
//  ScanEip712Response.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - ScanEip712Response

public struct ScanEip712Response: Codable {
  public let data: ScanEip712Data?
  public let error: String?
}

public struct ScanEip712Data: Codable {
  public let rawResponse: ScanEip712RawResponse
}

public struct ScanEip712RawResponse: Codable {
  public let success: Bool
  public let data: ScanEip712RiskData?
  public let error: String?
  public let version: String?
  public let service: String?
}

public struct ScanEip712RiskData: Codable {
  public let assessmentId: String?
  public let assessmentTimestamp: String?
  public let blockNumber: Int?
  public let recommendation: String
  public let trace: [ScanEip712Trace]?
  public let riIds: [String]?
  public let parsedActions: ScanEip712ParsedActions?
}

// MARK: - EIP-712 Specific Types

public struct ScanEip712ParsedActions: Codable {
  public let approval: [ScanEip712ApprovalItem]?
  public let ethValues: [ScanEip712ParsedActionItem]?
}

public struct ScanEip712ApprovalItem: Codable {
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

public struct ScanEip712ParsedActionItem: Codable {
  public let amountInUsd: Double?
  public let amount: Double?
  public let from: String?
  public let to: String?
}

public struct ScanEip712Trace: Codable {
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
