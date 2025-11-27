//
//  LifiStepTransactionResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 21/11/2025.
//

import Foundation

/// Response containing a step with transaction data from the Lifi integration

// MARK: - LifiStepTransactionResponse

public struct LifiStepTransactionResponse: Codable {
  public let data: LifiStepTransactionData?
  public let error: String?

  public init(data: LifiStepTransactionData? = nil, error: String? = nil) {
    self.data = data
    self.error = error
  }
}

public struct LifiStepTransactionData: Codable {
  public let rawResponse: LifiStep

  public init(rawResponse: LifiStep) {
    self.rawResponse = rawResponse
  }
}
