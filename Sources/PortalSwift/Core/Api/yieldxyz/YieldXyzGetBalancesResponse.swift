//
//  YieldXyzGetBalancesResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 20/10/2025.
//

import Foundation

/// Response from getting yield balances
public struct YieldXyzGetBalancesResponse: Codable {
  public let data: YieldXyzGetBalancesData?
  public let metadata: YieldXyzGetBalancesMetadata?
  public let error: String?

  public init(data: YieldXyzGetBalancesData? = nil, metadata: YieldXyzGetBalancesMetadata? = nil, error: String? = nil) {
    self.data = data
    self.metadata = metadata
    self.error = error
  }
}

public struct YieldXyzGetBalancesData: Codable {
  public let rawResponse: YieldXyzGetBalancesRawResponse

  public init(rawResponse: YieldXyzGetBalancesRawResponse) {
    self.rawResponse = rawResponse
  }
}

public struct YieldXyzGetBalancesRawResponse: Codable {
  public let items: [YieldXyzGetBalancesItem]
  public let errors: [String]

  public init(items: [YieldXyzGetBalancesItem], errors: [String] = []) {
    self.items = items
    self.errors = errors
  }
}

public struct YieldXyzGetBalancesItem: Codable {
  public let yieldId: String
  public let balances: [YieldXyzBalance]

  public init(yieldId: String, balances: [YieldXyzBalance]) {
    self.yieldId = yieldId
    self.balances = balances
  }
}

public struct YieldXyzBalance: Codable {
  public let address: String
  public let amount: String
  public let amountRaw: String
  public let type: String
  public let token: YieldXyzBalanceToken
  public let pendingActions: [YieldXyzBalancePendingAction]
  public let amountUsd: String?
  public let isEarning: Bool?

  public init(
    address: String,
    amount: String,
    amountRaw: String,
    type: String,
    token: YieldXyzBalanceToken,
    pendingActions: [YieldXyzBalancePendingAction] = [],
    amountUsd: String? = nil,
    isEarning: Bool? = nil
  ) {
    self.address = address
    self.amount = amount
    self.amountRaw = amountRaw
    self.type = type
    self.token = token
    self.pendingActions = pendingActions
    self.amountUsd = amountUsd
    self.isEarning = isEarning
  }
}

public struct YieldXyzBalanceToken: Codable {
  public let address: String
  public let symbol: String
  public let name: String
  public let decimals: Int
  public let logoURI: String?
  public let network: String
  public let isPoints: Bool?

  public init(
    address: String,
    symbol: String,
    name: String,
    decimals: Int,
    logoURI: String? = nil,
    network: String,
    isPoints: Bool? = nil
  ) {
    self.address = address
    self.symbol = symbol
    self.name = name
    self.decimals = decimals
    self.logoURI = logoURI
    self.network = network
    self.isPoints = isPoints
  }
}

public struct YieldXyzBalancePendingAction: Codable {
  public let intent: YieldXyzActionIntent
  public let type: YieldXyzActionType
  public let passthrough: String
  public let arguments: YieldXyzArgument?
}

public struct YieldXyzGetBalancesMetadata: Codable {
  public let clientId: String?

  public init(clientId: String? = nil) {
    self.clientId = clientId
  }
}
