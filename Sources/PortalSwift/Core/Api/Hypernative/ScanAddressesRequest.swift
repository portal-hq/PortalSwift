//
//  ScanAddressesRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// MARK: - ScanAddressesRequest

public struct ScanAddressesRequest: Codable {
  public let addresses: [String]
  public let screenerPolicyId: String?

  public init(addresses: [String], screenerPolicyId: String? = nil) {
    self.addresses = addresses
    self.screenerPolicyId = screenerPolicyId
  }
}
