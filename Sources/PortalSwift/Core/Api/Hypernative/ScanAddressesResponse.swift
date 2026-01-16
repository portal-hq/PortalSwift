//
//  ScanAddressesResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - ScanAddressesResponse

public struct ScanAddressesResponse: Codable {
  public let data: ScanAddressesData?
  public let error: String?
}

public struct ScanAddressesData: Codable {
  public let rawResponse: [ScanAddressesItem]
}

// MARK: - Addresses-Specific Types

public struct ScanAddressesItem: Codable {
  public let address: String
  public let recommendation: String
  public let severity: String
  public let totalIncomingUsd: Double
  public let policyId: String
  public let timestamp: String
  public let flags: [ScanAddressesFlag]
}

public struct ScanAddressesFlag: Codable {
  public let title: String
  public let flagId: String
  public let chain: String
  public let severity: String
  public let events: [ScanAddressesEvent]
  public let lastUpdate: String?
  public let exposures: [ScanAddressesExposure]
}

public struct ScanAddressesEvent: Codable {
  public let eventId: String?
  public let address: String?
  public let chain: String?
  public let flagId: String?
  public let timestampEvent: String?
  public let txHash: String?
  public let direction: String?
  public let hop: Int?
  public let counterpartyAddress: String?
  public let counterpartyAlias: String?
  public let counterpartyFlagId: String?
  public let tokenSymbol: String?
  public let tokenAmount: Double?
  public let tokenUsdValue: Double?
  public let reason: String?
  public let source: String?
  public let originalFlaggedAddress: String?
  public let originalFlaggedAlias: String?
  public let originalFlaggedChain: String?
}

public struct ScanAddressesExposure: Codable {
  public let exposurePortion: Double
  public let exposureType: String?
  public let totalExposureUsd: Double
  public let flaggedInteractions: [ScanAddressesFlaggedInteraction]
}

public struct ScanAddressesFlaggedInteraction: Codable {
  public let address: String
  public let chain: String
  public let alias: String?
  public let minHop: Int
  public let totalExposureUsd: Double
}
