//
//  SimulatedTransaction.swift
//
//
//  Created by Ahmed Ragab on 04/09/2024.
//

import Foundation
@testable import PortalSwift

extension SimulatedTransaction {
  static func stub(
    changes: [SimulatedTransactionChange] = [.stub()],
    gasUsed: String? = "21000",
    error: SimulatedTransactionError? = nil,
    requestError: SimulatedTransactionError? = nil
  ) -> SimulatedTransaction {
    return SimulatedTransaction(
      changes: changes,
      gasUsed: gasUsed,
      error: error,
      requestError: requestError
    )
  }
}

extension SimulatedTransactionChange {
  static func stub(
    amount: String? = "1000",
    assetType: String? = "ETH",
    changeType: String? = "transfer",
    contractAddress: String? = "0x123456789abcdef123456789abcdef123456789a",
    decimals: Int? = 18,
    from: String? = "0xabcdef123456789abcdef123456789abcdef12345",
    name: String? = "Sample Token",
    rawAmount: String? = "1000000000000000000",
    symbol: String? = "SMP",
    to: String? = "0x987654321fedcba987654321fedcba987654321f",
    tokenId: Int? = nil
  ) -> SimulatedTransactionChange {
    return SimulatedTransactionChange(
      amount: amount,
      assetType: assetType,
      changeType: changeType,
      contractAddress: contractAddress,
      decimals: decimals,
      from: from,
      name: name,
      rawAmount: rawAmount,
      symbol: symbol,
      to: to,
      tokenId: tokenId
    )
  }
}

extension SimulatedTransactionError {
  static func stub(
    message: String = "An error occurred during simulation"
  ) -> SimulatedTransactionError {
    return SimulatedTransactionError(
      message: message
    )
  }
}
