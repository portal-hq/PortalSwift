//
//  YieldXyzBorrowResponses.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

public typealias YieldXyzBorrowGetHealthResponse = YieldXyzBorrowResponse<YieldXyzBorrowHealthStatus>
public typealias YieldXyzBorrowGetIntegrationsResponse = YieldXyzBorrowResponse<[YieldXyzBorrowIntegration]>
public typealias YieldXyzBorrowGetIntegrationResponse = YieldXyzBorrowResponse<YieldXyzBorrowIntegration>
public typealias YieldXyzBorrowGetMarketsResponse = YieldXyzBorrowResponse<YieldXyzBorrowPage<YieldXyzBorrowMarket>>
public typealias YieldXyzBorrowGetMarketResponse = YieldXyzBorrowResponse<YieldXyzBorrowMarket>
/// A single position: the request takes one integration and chain.
public typealias YieldXyzBorrowGetPositionsResponse = YieldXyzBorrowResponse<YieldXyzBorrowPosition>
public typealias YieldXyzBorrowGetLiquidationsResponse = YieldXyzBorrowResponse<YieldXyzBorrowPage<YieldXyzBorrowLiquidation>>
/// The response of `createAction`, `getAction` and `stepAction`.
public typealias YieldXyzBorrowActionResponse = YieldXyzBorrowResponse<YieldXyzBorrowAction>
public typealias YieldXyzBorrowGetActionsResponse = YieldXyzBorrowResponse<YieldXyzBorrowPage<YieldXyzBorrowAction>>
public typealias YieldXyzBorrowSubmitTransactionResponse = YieldXyzBorrowResponse<YieldXyzBorrowSubmitTransactionResult>
