//
//  BlockaidScanURLResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - BlockaidScanURLResponse

public struct BlockaidScanURLResponse: Codable {
  public let data: BlockaidScanURLData?
  public let error: String?
}

public struct BlockaidScanURLData: Codable {
  public let rawResponse: BlockaidScanURLRawResponse
}

// MARK: - BlockaidScanURLRawResponse

public struct BlockaidScanURLRawResponse: Codable {
  public let status: String
  public let url: String?
  public let scanStartTime: String?
  public let scanEndTime: String?
  public let maliciousScore: Int?
  public let isReachable: Bool?
  public let isWeb3Site: Bool?
  public let isMalicious: Bool?
  public let attackTypes: [String: BlockaidAttackEntry]?
  public let networkOperations: [String]?
  public let jsonRpcOperations: [String]?
  public let contractWrite: BlockaidContractOperations?
  public let contractRead: BlockaidContractOperations?
  public let modals: [String]?

  private enum CodingKeys: String, CodingKey {
    case status, url, modals
    case scanStartTime = "scan_start_time"
    case scanEndTime = "scan_end_time"
    case maliciousScore = "malicious_score"
    case isReachable = "is_reachable"
    case isWeb3Site = "is_web3_site"
    case isMalicious = "is_malicious"
    case attackTypes = "attack_types"
    case networkOperations = "network_operations"
    case jsonRpcOperations = "json_rpc_operations"
    case contractWrite = "contract_write"
    case contractRead = "contract_read"
  }
}

// MARK: - BlockaidAttackEntry

public struct BlockaidAttackEntry: Codable {
  public let score: Int?
  public let threshold: Int?
}

// MARK: - BlockaidContractOperations

public struct BlockaidContractOperations: Codable {
  public let contractAddresses: [String]?
  public let functions: [String: [String]]?

  private enum CodingKeys: String, CodingKey {
    case contractAddresses = "contract_addresses"
    case functions
  }
}
