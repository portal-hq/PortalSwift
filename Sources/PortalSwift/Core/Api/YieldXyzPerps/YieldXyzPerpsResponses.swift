//
//  YieldXyzPerpsResponses.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

public typealias YieldXyzPerpsGetProvidersResponse = YieldXyzPerpsResponse<[YieldXyzPerpsProvider]>
public typealias YieldXyzPerpsGetProviderResponse = YieldXyzPerpsResponse<YieldXyzPerpsProvider>
public typealias YieldXyzPerpsGetMarketsResponse = YieldXyzPerpsResponse<YieldXyzPerpsPage<YieldXyzPerpsMarket>>
public typealias YieldXyzPerpsGetMarketResponse = YieldXyzPerpsResponse<YieldXyzPerpsMarket>
public typealias YieldXyzPerpsGetMarketCandlesResponse = YieldXyzPerpsResponse<YieldXyzPerpsCandles>
public typealias YieldXyzPerpsGetPositionsResponse = YieldXyzPerpsResponse<[YieldXyzPerpsPosition]>
public typealias YieldXyzPerpsGetOrdersResponse = YieldXyzPerpsResponse<[YieldXyzPerpsOrder]>
/// A single balance: the request takes exactly one venue.
public typealias YieldXyzPerpsGetBalancesResponse = YieldXyzPerpsResponse<YieldXyzPerpsBalance>
public typealias YieldXyzPerpsCreateActionResponse = YieldXyzPerpsResponse<YieldXyzPerpsAction>
public typealias YieldXyzPerpsGetActionsResponse = YieldXyzPerpsResponse<YieldXyzPerpsPage<YieldXyzPerpsAction>>
public typealias YieldXyzPerpsGetActionResponse = YieldXyzPerpsResponse<YieldXyzPerpsAction>
public typealias YieldXyzPerpsSubmitTransactionResponse = YieldXyzPerpsResponse<YieldXyzPerpsSubmitResult>
public typealias YieldXyzPerpsGetActivityResponse = YieldXyzPerpsResponse<YieldXyzPerpsPage<YieldXyzPerpsActivityItem>>
public typealias YieldXyzPerpsGetEventsResponse = YieldXyzPerpsResponse<YieldXyzPerpsPage<YieldXyzPerpsEvent>>
public typealias YieldXyzPerpsGetEventResponse = YieldXyzPerpsResponse<YieldXyzPerpsEvent>
public typealias YieldXyzPerpsGetHealthResponse = YieldXyzPerpsResponse<YieldXyzPerpsHealth>
public typealias YieldXyzPerpsGetProvidersHealthResponse = YieldXyzPerpsResponse<YieldXyzPerpsProvidersHealth>
