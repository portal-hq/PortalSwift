//
//  BroadcastBitcoinP2wpkhTransactionResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 28/08/2025.
//

import Foundation
@testable import PortalSwift

extension BroadcastBitcoinP2wpkhTransactionResponseData {
  static func stub(
    txHash: String = "0xDummyTxHash"
  ) -> Self {
    return BroadcastBitcoinP2wpkhTransactionResponseData(txHash: txHash)
  }
}

extension BroadcastBitcoinP2wpkhTransactionMetaData {
  static func stub(
    chainId: String = "bitcoin-mainnet",
    clientId: String = "test-client-id"
  ) -> Self {
    return BroadcastBitcoinP2wpkhTransactionMetaData(
      chainId: chainId,
      clientId: clientId
    )
  }
}

extension BroadcastBitcoinP2wpkhTransactionResponse {
  static func stub(
    data: BroadcastBitcoinP2wpkhTransactionResponseData = .stub(),
    metadata: BroadcastBitcoinP2wpkhTransactionMetaData = .stub()
  ) -> Self {
    return BroadcastBitcoinP2wpkhTransactionResponse(
      data: data,
      metadata: metadata
    )
  }
}
