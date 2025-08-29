//
//  BuildBitcoinP2wpkhTransactionResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 28/08/2025.
//

import Foundation
@testable import PortalSwift

extension BuildBitcoinP2wpkhTransactionResponse {
  static func stub(
    transaction: BitcoinP2wpkhTransaction = .stub(),
    metadata: BuildTransactionMetaData = .stub(),
    error: String? = nil
  ) -> Self {
    return BuildBitcoinP2wpkhTransactionResponse(
      transaction: transaction,
      metadata: metadata,
      error: error
    )
  }
}

extension BitcoinP2wpkhTransaction {
  static func stub(
    signatureHashes: [String] = ["SignatureHash"],
    rawTxHex: String = "RawTxHex"
  ) -> Self {
    return BitcoinP2wpkhTransaction(signatureHashes: signatureHashes, rawTxHex: rawTxHex)
  }
}
