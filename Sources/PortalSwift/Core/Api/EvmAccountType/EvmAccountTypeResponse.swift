//
//  EvmAccountTypeResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

public struct EvmAccountTypeResponse: Codable {
  public let data: EvmAccountTypeData
  public let metadata: EvmAccountTypeMetadata

  public init(data: EvmAccountTypeData, metadata: EvmAccountTypeMetadata) {
    self.data = data
    self.metadata = metadata
  }
}

public struct EvmAccountTypeData: Codable {
  /// Account type: "SMART_CONTRACT", "EIP_155_EOA", or "EIP_7702_EOA"
  public let status: String

  public init(status: String) {
    self.status = status
  }
}

public struct EvmAccountTypeMetadata: Codable {
  public let chainId: String
  public let eoaAddress: String
  /// May not exist for EOA-only accounts.
  public let smartContractAddress: String?

  public init(chainId: String, eoaAddress: String, smartContractAddress: String? = nil) {
    self.chainId = chainId
    self.eoaAddress = eoaAddress
    self.smartContractAddress = smartContractAddress
  }
}
