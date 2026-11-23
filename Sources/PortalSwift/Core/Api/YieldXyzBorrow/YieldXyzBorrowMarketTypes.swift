//
//  YieldXyzBorrowMarketTypes.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// A token a market accepts as collateral, with its risk parameters. Decimal values are strings,
/// as Yield.xyz returns them.
public struct YieldXyzBorrowCollateralToken: Codable, Equatable {
  public let token: YieldXyzBorrowToken
  public let priceUsd: String
  public let maxLtv: String
  public let liquidationThreshold: String
  public let liquidationPenalty: String
  public let supplyRate: String

  public init(
    token: YieldXyzBorrowToken,
    priceUsd: String,
    maxLtv: String,
    liquidationThreshold: String,
    liquidationPenalty: String,
    supplyRate: String
  ) {
    self.token = token
    self.priceUsd = priceUsd
    self.maxLtv = maxLtv
    self.liquidationThreshold = liquidationThreshold
    self.liquidationPenalty = liquidationPenalty
    self.supplyRate = supplyRate
  }
}

/// A lending market. Decimal amounts, rates and fees are strings, as Yield.xyz returns them.
public struct YieldXyzBorrowMarket: Codable, Equatable {
  /// Opaque; pass it as `ActionArguments.marketId`.
  public let id: String
  public let integrationId: String
  /// CAIP-2 for chains Portal supports; the Yield.xyz network name otherwise.
  public let network: String
  public let type: YieldXyzBorrowMarketType
  public let poolAddress: String
  public let loanToken: YieldXyzBorrowToken
  public let collateralTokens: [YieldXyzBorrowCollateralToken]
  public let borrowRate: String
  public let totalSupply: String
  public let totalSupplyRaw: String
  public let totalBorrow: String
  public let totalBorrowRaw: String
  public let availableLiquidity: String
  public let availableLiquidityRaw: String
  public let utilizationRate: String
  public let loanTokenPriceUsd: String
  public let isBorrowEnabled: Bool
  public let supplyCollateralFeeBps: String
  /// Always sent; `nil` when the market has none.
  public let feeWrapperAddress: String?
  public let originationFeeBps: String
  /// Always sent; `nil` when the market has none.
  public let originationFeeWrapperAddress: String?
  /// Always sent; `nil` when the market has none.
  public let blueBundleOriginationFeeBps: String?
  /// Always sent; `nil` when the market has no minimum.
  public let minLoan: String?

  public init(
    id: String,
    integrationId: String,
    network: String,
    type: YieldXyzBorrowMarketType,
    poolAddress: String,
    loanToken: YieldXyzBorrowToken,
    collateralTokens: [YieldXyzBorrowCollateralToken],
    borrowRate: String,
    totalSupply: String,
    totalSupplyRaw: String,
    totalBorrow: String,
    totalBorrowRaw: String,
    availableLiquidity: String,
    availableLiquidityRaw: String,
    utilizationRate: String,
    loanTokenPriceUsd: String,
    isBorrowEnabled: Bool,
    supplyCollateralFeeBps: String,
    feeWrapperAddress: String? = nil,
    originationFeeBps: String,
    originationFeeWrapperAddress: String? = nil,
    blueBundleOriginationFeeBps: String? = nil,
    minLoan: String? = nil
  ) {
    self.id = id
    self.integrationId = integrationId
    self.network = network
    self.type = type
    self.poolAddress = poolAddress
    self.loanToken = loanToken
    self.collateralTokens = collateralTokens
    self.borrowRate = borrowRate
    self.totalSupply = totalSupply
    self.totalSupplyRaw = totalSupplyRaw
    self.totalBorrow = totalBorrow
    self.totalBorrowRaw = totalBorrowRaw
    self.availableLiquidity = availableLiquidity
    self.availableLiquidityRaw = availableLiquidityRaw
    self.utilizationRate = utilizationRate
    self.loanTokenPriceUsd = loanTokenPriceUsd
    self.isBorrowEnabled = isBorrowEnabled
    self.supplyCollateralFeeBps = supplyCollateralFeeBps
    self.feeWrapperAddress = feeWrapperAddress
    self.originationFeeBps = originationFeeBps
    self.originationFeeWrapperAddress = originationFeeWrapperAddress
    self.blueBundleOriginationFeeBps = blueBundleOriginationFeeBps
    self.minLoan = minLoan
  }
}
