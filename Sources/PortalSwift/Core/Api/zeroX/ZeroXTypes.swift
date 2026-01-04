//
//  ZeroXTypes.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2024 Portal Labs, Inc. All rights reserved.
//

import Foundation

// MARK: - Fee Types

/// Fee breakdown for a ZeroX swap.
public struct ZeroXFees: Codable {
  /// The integrator fee (optional).
  public let integratorFee: ZeroXFeeDetail?
  /// The ZeroX protocol fee (optional).
  public let zeroExFee: ZeroXZeroExFeeDetail?
  /// The gas fee (optional).
  public let gasFee: ZeroXFeeDetail?

  public init(
    integratorFee: ZeroXFeeDetail? = nil,
    zeroExFee: ZeroXZeroExFeeDetail? = nil,
    gasFee: ZeroXFeeDetail? = nil
  ) {
    self.integratorFee = integratorFee
    self.zeroExFee = zeroExFee
    self.gasFee = gasFee
  }
}

/// General fee detail.
public struct ZeroXFeeDetail: Codable {
  /// The fee amount (optional).
  public let amount: String?
  /// The token address (optional).
  public let token: String?
  /// The type of fee (optional).
  public let type: String?

  public init(amount: String? = nil, token: String? = nil, type: String? = nil) {
    self.amount = amount
    self.token = token
    self.type = type
  }
}

/// ZeroX protocol fee detail.
public struct ZeroXZeroExFeeDetail: Codable {
  /// The billing type for the fee (optional).
  public let billingType: String?
  /// The fee amount (optional).
  public let feeAmount: String?
  /// The fee token address (optional).
  public let feeToken: String?
  /// The type of fee (optional).
  public let feeType: String?

  public init(billingType: String? = nil, feeAmount: String? = nil, feeToken: String? = nil, feeType: String? = nil) {
    self.billingType = billingType
    self.feeAmount = feeAmount
    self.feeToken = feeToken
    self.feeType = feeType
  }
}

// MARK: - Issue Types

/// Issues that may affect a swap.
public struct ZeroXIssues: Codable {
  /// Token allowance issue (optional).
  public let allowance: ZeroXAllowanceIssue?
  /// Token balance issue (optional).
  public let balance: ZeroXBalanceIssue?
  /// Whether the simulation was incomplete (optional).
  public let simulationIncomplete: Bool?
  /// List of invalid sources that were passed (optional).
  public let invalidSourcesPassed: [String]?

  public init(
    allowance: ZeroXAllowanceIssue? = nil,
    balance: ZeroXBalanceIssue? = nil,
    simulationIncomplete: Bool? = nil,
    invalidSourcesPassed: [String]? = nil
  ) {
    self.allowance = allowance
    self.balance = balance
    self.simulationIncomplete = simulationIncomplete
    self.invalidSourcesPassed = invalidSourcesPassed
  }
}

/// Token allowance issue details.
public struct ZeroXAllowanceIssue: Codable {
  /// The actual allowance amount.
  public let actual: String
  /// The spender address that needs allowance.
  public let spender: String

  public init(actual: String, spender: String) {
    self.actual = actual
    self.spender = spender
  }
}

/// Token balance issue details.
public struct ZeroXBalanceIssue: Codable {
  /// The token address.
  public let token: String
  /// The actual balance.
  public let actual: String
  /// The expected/required balance.
  public let expected: String

  public init(token: String, actual: String, expected: String) {
    self.token = token
    self.actual = actual
    self.expected = expected
  }
}

