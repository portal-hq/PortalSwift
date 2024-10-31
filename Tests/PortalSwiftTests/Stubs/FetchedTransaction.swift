//
//  FetchedTransaction.swift
//
//
//  Created by Ahmed Ragab on 04/09/2024.
//

import Foundation
@testable import PortalSwift

extension FetchedTransaction {
  static func stub(
    blockNum: String = "123456",
    uniqueId: String = "unique-transaction-id",
    hash: String = "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
    from: String = "0x123456789abcdef123456789abcdef123456789a",
    to: String = "0xabcdef123456789abcdef123456789abcdef12345",
    value: Float = 1.23,
    erc721TokenId: String? = nil,
    erc1155Metadata: [Erc1155Metadata?] = [],
    tokenId: String? = nil,
    asset: String = "ETH",
    category: String = "external",
    rawContract: FetchedTransactionRawContract = .stub(),
    metadata: FetchedTransactionMetadata = .stub(),
    chainId: Int = 1
  ) -> FetchedTransaction {
    return FetchedTransaction(
      blockNum: blockNum,
      uniqueId: uniqueId,
      hash: hash,
      from: from,
      to: to,
      value: value,
      erc721TokenId: erc721TokenId,
      erc1155Metadata: erc1155Metadata,
      tokenId: tokenId,
      asset: asset,
      category: category,
      rawContract: rawContract,
      metadata: metadata,
      chainId: chainId
    )
  }
}

extension FetchedTransaction.FetchedTransactionMetadata {
  static func stub(
    blockTimestamp: String = "2024-08-24T12:00:00Z"
  ) -> FetchedTransaction.FetchedTransactionMetadata {
    return FetchedTransaction.FetchedTransactionMetadata(
      blockTimestamp: blockTimestamp
    )
  }
}

extension FetchedTransactionRawContract {
  static func stub(
    value: String = "1000000000000000000",
    address: String? = "0xabcdef123456789abcdef123456789abcdef12345",
    decimal: String = "18"
  ) -> FetchedTransactionRawContract {
    return FetchedTransactionRawContract(
      value: value,
      address: address,
      decimal: decimal
    )
  }
}
