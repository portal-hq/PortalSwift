//
//  AssetsResponse.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 30/10/2024.
//

import Foundation
@testable import PortalSwift

extension AssetsResponse {
  static func stub(
    nativeBalance: NativeBalance? = .stub(),
    tokenBalances: [TokenBalanceResponse]? = [.stub()],
    nfts: [Nft]? = []
  ) -> Self {
    return AssetsResponse(nativeBalance: nativeBalance, tokenBalances: tokenBalances, nfts: nfts)
  }
}

extension NativeBalance {
  static func stub(
    balance: String? = "1000",
    decimals: Int? = 18,
    name: String? = "Ethereum",
    rawBalance: String? = "1000000000000000000",
    symbol: String? = "ETH",
    metadata: NativeBalanceMetadata? = .stub()
  ) -> Self {
    return NativeBalance(
      balance: balance,
      decimals: decimals,
      name: name,
      rawBalance: rawBalance,
      symbol: symbol,
      metadata: metadata
    )
  }
}

extension NativeBalanceMetadata {
  static func stub(
    logo: String? = "https://example.com/logo.png",
    thumbnail: String? = "https://example.com/thumbnail.png"
  ) -> Self {
    return NativeBalanceMetadata(logo: logo, thumbnail: thumbnail)
  }
}

extension TokenBalanceResponse {
  static func stub(
    balance: String? = "500",
    decimals: Int? = 18,
    name: String? = "Sample Token",
    rawBalance: String? = "500000000000000000",
    symbol: String? = "TOKEN",
    metadata: TokenBalanceMetadata? = .stub()
  ) -> Self {
    return TokenBalanceResponse(
      balance: balance,
      decimals: decimals,
      name: name,
      rawBalance: rawBalance,
      symbol: symbol,
      metadata: metadata
    )
  }
}

extension TokenBalanceMetadata {
  static func stub(
    tokenAddress: String? = "0xTokenAddress",
    verifiedContract: Bool? = true,
    totalSupply: String? = "1000000",
    rawTotalSupply: String? = "1000000000000000000000000",
    percentageRelativeToTotalSupply: Double? = 0.05
  ) -> Self {
    return TokenBalanceMetadata(
      tokenAddress: tokenAddress,
      verifiedContract: verifiedContract,
      totalSupply: totalSupply,
      rawTotalSupply: rawTotalSupply,
      percentageRelativeToTotalSupply: percentageRelativeToTotalSupply
    )
  }
}
