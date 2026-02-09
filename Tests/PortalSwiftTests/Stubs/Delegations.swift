//
//  Delegations.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import Foundation
@testable import PortalSwift

// MARK: - Request Stubs

extension ApproveDelegationRequest {
  static func stub(
    chain: String = "eip155:11155111",
    token: String = "USDC",
    delegateAddress: String = "0xdFd8302f44727A6348F702fF7B594f127dE3A902",
    amount: String = "1.0"
  ) -> Self {
    .init(chain: chain, token: token, delegateAddress: delegateAddress, amount: amount)
  }
}

extension RevokeDelegationRequest {
  static func stub(
    chain: String = "eip155:11155111",
    token: String = "USDC",
    delegateAddress: String = "0xdFd8302f44727A6348F702fF7B594f127dE3A902"
  ) -> Self {
    .init(chain: chain, token: token, delegateAddress: delegateAddress)
  }
}

extension GetDelegationStatusRequest {
  static func stub(
    chain: String = "eip155:11155111",
    token: String = "USDC",
    delegateAddress: String = "0xdFd8302f44727A6348F702fF7B594f127dE3A902"
  ) -> Self {
    .init(chain: chain, token: token, delegateAddress: delegateAddress)
  }
}

extension TransferFromRequest {
  static func stub(
    chain: String = "eip155:11155111",
    token: String = "USDC",
    fromAddress: String = "0xc53fbaea2daa07f2a3d7e586aeed7b3b92fe2985",
    toAddress: String = "0xdFd8302f44727A6348F702fF7B594f127dE3A902",
    amount: String = "1.0"
  ) -> Self {
    .init(chain: chain, token: token, fromAddress: fromAddress, toAddress: toAddress, amount: amount)
  }
}

// MARK: - Response Stubs

extension ApproveDelegationResponse {
  static func stub(
    transactions: [ConstructedEipTransaction]? = [.stub()],
    encodedTransactions: [String]? = nil,
    metadata: ApproveDelegationMetadata? = .stub()
  ) -> Self {
    .init(transactions: transactions, encodedTransactions: encodedTransactions, metadata: metadata)
  }
}

extension RevokeDelegationResponse {
  static func stub(
    transactions: [ConstructedEipTransaction]? = [.stub()],
    encodedTransactions: [String]? = nil,
    metadata: RevokeDelegationMetadata? = .stub()
  ) -> Self {
    .init(transactions: transactions, encodedTransactions: encodedTransactions, metadata: metadata)
  }
}

extension DelegationStatusResponse {
  static func stub(
    chainId: String = "eip155:11155111",
    token: String = "USDC",
    tokenAddress: String = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    tokenAccount: String? = nil,
    balance: String? = "100.0",
    balanceRaw: String? = "100000000",
    delegations: [DelegationStatus] = [.stub()]
  ) -> Self {
    .init(
      chainId: chainId,
      token: token,
      tokenAddress: tokenAddress,
      tokenAccount: tokenAccount,
      balance: balance,
      balanceRaw: balanceRaw,
      delegations: delegations
    )
  }
}

extension TransferFromResponse {
  static func stub(
    transactions: [ConstructedEipTransaction]? = [.stub()],
    encodedTransactions: [String]? = nil,
    metadata: TransferAsDelegateMetadata = .stub()
  ) -> Self {
    .init(transactions: transactions, encodedTransactions: encodedTransactions, metadata: metadata)
  }
}

// MARK: - Supporting Type Stubs

extension ConstructedEipTransaction {
  static func stub(
    from: String = "0xc53fbaea2daa07f2a3d7e586aeed7b3b92fe2985",
    to: String = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    data: String? = "0xabcdef",
    value: String? = "0x0"
  ) -> Self {
    .init(from: from, to: to, data: data, value: value)
  }
}

extension DelegationStatus {
  static func stub(
    address: String = "0xdFd8302f44727A6348F702fF7B594f127dE3A902",
    delegateAmount: String = "10.0",
    delegateAmountRaw: String = "10000000"
  ) -> Self {
    .init(address: address, delegateAmount: delegateAmount, delegateAmountRaw: delegateAmountRaw)
  }
}

extension ApproveDelegationMetadata {
  static func stub(
    chainId: String = "eip155:11155111",
    delegateAmount: String = "1.0",
    delegateAmountRaw: String? = "1000000",
    delegateAddress: String = "0xdFd8302f44727A6348F702fF7B594f127dE3A902",
    tokenSymbol: String = "USDC",
    tokenAddress: String? = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    ownerAddress: String? = "0xc53fbaea2daa07f2a3d7e586aeed7b3b92fe2985",
    tokenAccount: String? = nil,
    tokenMint: String? = nil,
    tokenDecimals: Int? = 6,
    lastValidBlockHeight: String? = nil,
    serializedTransactionBase64Encoded: String? = nil,
    serializedTransactionBase58Encoded: String? = nil
  ) -> Self {
    .init(
      chainId: chainId,
      delegateAmount: delegateAmount,
      delegateAmountRaw: delegateAmountRaw,
      delegateAddress: delegateAddress,
      tokenSymbol: tokenSymbol,
      tokenAddress: tokenAddress,
      ownerAddress: ownerAddress,
      tokenAccount: tokenAccount,
      tokenMint: tokenMint,
      tokenDecimals: tokenDecimals,
      lastValidBlockHeight: lastValidBlockHeight,
      serializedTransactionBase64Encoded: serializedTransactionBase64Encoded,
      serializedTransactionBase58Encoded: serializedTransactionBase58Encoded
    )
  }
}

extension RevokeDelegationMetadata {
  static func stub(
    chainId: String = "eip155:11155111",
    revokedAddress: String = "0xdFd8302f44727A6348F702fF7B594f127dE3A902",
    tokenSymbol: String = "USDC",
    tokenAddress: String? = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    ownerAddress: String? = "0xc53fbaea2daa07f2a3d7e586aeed7b3b92fe2985",
    tokenAccount: String? = nil
  ) -> Self {
    .init(
      chainId: chainId,
      revokedAddress: revokedAddress,
      tokenSymbol: tokenSymbol,
      tokenAddress: tokenAddress,
      ownerAddress: ownerAddress,
      tokenAccount: tokenAccount
    )
  }
}

extension TransferAsDelegateMetadata {
  static func stub(
    amount: String = "1.0",
    amountRaw: String = "1000000",
    chainId: String = "eip155:11155111",
    delegateAddress: String? = "0xdFd8302f44727A6348F702fF7B594f127dE3A902",
    lastValidBlockHeight: String? = nil,
    needsRecipientTokenAccount: Bool? = nil,
    ownerAddress: String? = "0xc53fbaea2daa07f2a3d7e586aeed7b3b92fe2985",
    recipientAddress: String? = "0xdFd8302f44727A6348F702fF7B594f127dE3A902",
    serializedTransactionBase58Encoded: String? = nil,
    serializedTransactionBase64Encoded: String? = nil,
    tokenAddress: String? = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    tokenSymbol: String? = "USDC",
    tokenDecimals: Int? = 6
  ) -> Self {
    .init(
      amount: amount,
      amountRaw: amountRaw,
      chainId: chainId,
      delegateAddress: delegateAddress,
      lastValidBlockHeight: lastValidBlockHeight,
      needsRecipientTokenAccount: needsRecipientTokenAccount,
      ownerAddress: ownerAddress,
      recipientAddress: recipientAddress,
      serializedTransactionBase58Encoded: serializedTransactionBase58Encoded,
      serializedTransactionBase64Encoded: serializedTransactionBase64Encoded,
      tokenAddress: tokenAddress,
      tokenSymbol: tokenSymbol,
      tokenDecimals: tokenDecimals
    )
  }
}
