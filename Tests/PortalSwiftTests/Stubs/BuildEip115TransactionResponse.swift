//
//  BuildEip115TransactionResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 29/10/2024.
//

import Foundation
@testable import PortalSwift

extension BuildEip115TransactionResponse {
  static func stub(
    transaction: Eip115Transaction = .stub(),
    metadata: BuildTransactionMetaData = .stub(),
    error: String? = nil
  ) -> Self {
    return BuildEip115TransactionResponse(transaction: transaction, metadata: metadata, error: error)
  }
}

extension Eip115Transaction {
  static func stub(
    from: String = "0xFromAddress",
    to: String = "0xToAddress",
    data: String? = "0xData",
    value: String? = "1000000000000000000"
  ) -> Self {
    return Eip115Transaction(from: from, to: to, data: data, value: value)
  }
}

extension BuildTransactionMetaData {
  static func stub(
    amount: String = "1.0",
    fromAddress: String = "0xFromAddress",
    toAddress: String = "0xToAddress",
    tokenAddress: String? = "0xTokenAddress",
    tokenDecimals: Int = 18,
    tokenSymbol: String? = "ETH",
    rawAmount: String = "1000000000000000000"
  ) -> Self {
    return BuildTransactionMetaData(
      amount: amount,
      fromAddress: fromAddress,
      toAddress: toAddress,
      tokenAddress: tokenAddress,
      tokenDecimals: tokenDecimals,
      tokenSymbol: tokenSymbol,
      rawAmount: rawAmount
    )
  }
}
