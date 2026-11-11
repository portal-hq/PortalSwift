//
//  YieldXyzBorrowEvmTransactionLookup.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// What `GET /api/v3/clients/me/chains/{chain}/transactions/{hash}` says about a hash
/// `eth_sendTransaction` returned: the transaction itself for an EOA, or the user operation and the
/// bundle transaction that included it for an account-abstracted client. Only the fields the
/// execution needs are read, so a field the bundler leaves out cannot fail the lookup.
struct YieldXyzEvmTransactionLookup: Equatable {
  /// The hash of the on-chain transaction, when the hash is a transaction's.
  let transactionHash: String?
  /// The user operation, when the hash is a user operation's.
  let userOperation: UserOperation?

  struct UserOperation: Equatable {
    /// `false` when the user operation was included but did not succeed.
    let success: Bool?
    /// The bundle transaction's hash; `nil` until the user operation is included.
    let receiptTransactionHash: String?
  }

  init(transactionHash: String? = nil, userOperation: UserOperation? = nil) {
    self.transactionHash = transactionHash
    self.userOperation = userOperation
  }

  init(_ response: GetTransactionDetailsResponse) {
    self.init(
      transactionHash: response.data.evmTransaction?.hash,
      userOperation: response.data.evmUserOperation.map {
        UserOperation(success: $0.success, receiptTransactionHash: $0.receipt?.hash)
      }
    )
  }
}

/// The minimal decodable body of the transaction lookup.
struct YieldXyzEvmTransactionLookupBody: Decodable {
  let data: DataBody?

  struct DataBody: Decodable {
    let evmTransaction: HashBody?
    let evmUserOperation: UserOperationBody?
  }

  struct HashBody: Decodable {
    let hash: String?
  }

  struct UserOperationBody: Decodable {
    let success: Bool?
    let receipt: HashBody?
  }
}

/// Looks up the transaction or user operation behind a broadcast hash on an `eip155` chain.
protocol YieldXyzEvmTransactionLookupProviding: AnyObject {
  /// Returns `nil` when the response carries no `data`; a hash not visible yet fails with the
  /// transport's `404`.
  func lookupEvmTransaction(chainId: String, hash: String) async throws -> YieldXyzEvmTransactionLookup?
}
