//
//  BuildSolanaTransactionResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 29/10/2024.
//

import Foundation
@testable import PortalSwift

extension BuildSolanaTransactionResponse {
  static func stub(
    transaction: String = "defaultTransactionData",
    metadata: BuildTransactionMetaData = .stub(),
    error: String? = nil
  ) -> Self {
    return BuildSolanaTransactionResponse(transaction: transaction, metadata: metadata, error: error)
  }
}
