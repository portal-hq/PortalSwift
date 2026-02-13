//
//  ScanEip712Request.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import AnyCodable
import Foundation

// MARK: - ScanEip712Request

public struct ScanEip712Request: Codable {
  public let walletAddress: String
  public let chainId: String
  public let eip712Message: ScanEip712TypedData
  public let showFullFindings: Bool?
  public let policy: String?

  public init(
    walletAddress: String,
    chainId: String,
    eip712Message: ScanEip712TypedData,
    showFullFindings: Bool? = nil,
    policy: String? = nil
  ) {
    self.walletAddress = walletAddress
    self.chainId = chainId
    self.eip712Message = eip712Message
    self.showFullFindings = showFullFindings
    self.policy = policy
  }
}

// MARK: - EIP-712 Specific Types

public struct ScanEip712TypedData: Codable {
  public let primaryType: String
  public let types: [String: [ScanEip712TypeProperty]]
  public let domain: ScanEip712Domain
  public let message: [String: AnyCodable]

  public init(
    primaryType: String,
    types: [String: [ScanEip712TypeProperty]],
    domain: ScanEip712Domain,
    message: [String: AnyCodable]
  ) {
    self.primaryType = primaryType
    self.types = types
    self.domain = domain
    self.message = message
  }
}

public struct ScanEip712TypeProperty: Codable {
  public let name: String
  public let type: String

  public init(name: String, type: String) {
    self.name = name
    self.type = type
  }
}

public struct ScanEip712Domain: Codable {
  public let name: String?
  public let version: String?
  public let chainId: String?
  public let verifyingContract: String?
  public let salt: String?

  public init(
    name: String? = nil,
    version: String? = nil,
    chainId: String? = nil,
    verifyingContract: String? = nil,
    salt: String? = nil
  ) {
    self.name = name
    self.version = version
    self.chainId = chainId
    self.verifyingContract = verifyingContract
    self.salt = salt
  }
}
