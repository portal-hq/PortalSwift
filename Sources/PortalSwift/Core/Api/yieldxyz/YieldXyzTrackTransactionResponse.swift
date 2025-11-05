//
//  YieldXyzTrackTransactionResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation

/// Response from submitting a transaction hash
public struct YieldXyzTrackTransactionResponse: Codable {
  public let data: YieldXyzTrackTransactionData?
  public let error: String?

  public init(data: YieldXyzTrackTransactionData? = nil, error: String? = nil) {
    self.data = data
    self.error = error
  }
}

public struct YieldXyzTrackTransactionData: Codable {
  public let rawResponse: YieldXyzTrackTransactionRawResponse

  public init(rawResponse: YieldXyzTrackTransactionRawResponse) {
    self.rawResponse = rawResponse
  }
}

public struct YieldXyzTrackTransactionRawResponse: Codable {
  public let id: String
  public let title: String
  public let network: String
  public let status: YieldXyzActionTransactionStatus
  public let type: YieldXyzActionTransactionType
  public let hash: String?
  public let createdAt: String
  public let broadcastedAt: String?
  public let signedTransaction: String?
  public let unsignedTransaction: String?
  public let stepIndex: Int
  public let gasEstimate: String?

  public init(
    id: String,
    title: String,
    network: String,
    status: YieldXyzActionTransactionStatus,
    type: YieldXyzActionTransactionType,
    hash: String? = nil,
    createdAt: String,
    broadcastedAt: String? = nil,
    signedTransaction: String? = nil,
    unsignedTransaction: String? = nil,
    stepIndex: Int,
    gasEstimate: String? = nil
  ) {
    self.id = id
    self.title = title
    self.network = network
    self.status = status
    self.type = type
    self.hash = hash
    self.createdAt = createdAt
    self.broadcastedAt = broadcastedAt
    self.signedTransaction = signedTransaction
    self.unsignedTransaction = unsignedTransaction
    self.stepIndex = stepIndex
    self.gasEstimate = gasEstimate
  }
}
