//
//  ScanSolanaResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - ScanSolanaResponse

public struct ScanSolanaResponse: Codable {
  public let data: ScanSolanaData?
  public let error: String?
}

public struct ScanSolanaData: Codable {
  public let rawResponse: ScanSolanaRawResponse
}

public struct ScanSolanaRawResponse: Codable {
  public let success: Bool
  public let data: ScanSolanaRiskData?
  public let error: String?
  public let version: String?
  public let service: String?
}

public struct ScanSolanaRiskData: Codable {
  public let assessmentId: String?
  public let assessmentTimestamp: String?
  public let recommendation: String
  public let expectedStatus: String?
  public let findings: [ScanSolanaFinding]?
  public let involvedAssets: [ScanSolanaAsset]?
  public let balanceChanges: [String: [ScanSolanaBalanceChange]]?
  public let parsedActions: ScanSolanaParsedActions?
  public let blockNumber: Int?
  public let trace: [ScanSolanaTrace]?
  public let riIds: [String]?
}

// MARK: - Solana-Specific Response Types

public struct ScanSolanaFinding: Codable {
  public let typeId: String
  public let title: String
  public let description: String
  public let details: String?
  public let severity: String
  public let relatedAssets: [ScanSolanaAsset]?
}

public struct ScanSolanaAsset: Codable {
  public let chain: String
  public let address: String
  public let type: String
  public let involvementTypes: [String]
  public let alias: String?
  public let tag: String
}

public struct ScanSolanaBalanceChange: Codable {
  public let changeType: String
  public let tokenSymbol: String
  public let tokenAddress: String?
  public let usdValue: String?
  public let amount: String
  public let chain: String
}

public struct ScanSolanaParsedActions: Codable {
  public let ethValues: [ScanSolanaParsedActionItem]?
  public let tokenValues: [ScanSolanaParsedActionItem]?
}

public struct ScanSolanaParsedActionItem: Codable {
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

public struct ScanSolanaTrace: Codable {
  public let from: String
  public let to: String
  public let funcId: String?
  public let callType: String?
  public let value: Int?
  public let traceAddress: [Int]?
  public let status: String?
  public let callInput: ScanSolanaTraceCallInput?
  public let extraInfo: [String: String]?
}

public struct ScanSolanaTraceCallInput: Codable {
  public let type: String?
  public let info: ScanSolanaTraceCallInputInfo?
}

/// Handles both string info ("K17Tvf") and object info (transfer details)
public enum ScanSolanaTraceCallInputInfo: Codable {
  case string(String)
  case transfer(ScanSolanaTransferInfo)

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let stringValue = try? container.decode(String.self) {
      self = .string(stringValue)
    } else if let transferInfo = try? container.decode(ScanSolanaTransferInfo.self) {
      self = .transfer(transferInfo)
    } else {
      self = .string("")
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .string(let value): try container.encode(value)
    case .transfer(let value): try container.encode(value)
    }
  }
}

public struct ScanSolanaTransferInfo: Codable {
  public let source: String?
  public let destination: String?
  public let lamports: Int?
}
