//
//  AggResponses.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// Link
public typealias AggCreateLinkChallengeResponse = AggResponse<AggLinkChallenge>
public typealias AggCreateLinkResponse = AggResponse<AggLink>
public typealias AggGetLinkResponse = AggResponse<AggLinkStatus>
public typealias AggDeleteLinkResponse = AggResponse<AggUnlink>

// Discovery
public typealias AggListEventsResponse = AggResponse<AggPage<AggVenueEvent>>
public typealias AggGetEventResponse = AggResponse<AggVenueEvent>
public typealias AggGetEventBootstrapResponse = AggResponse<AggVenueEventBootstrap>
public typealias AggListMarketsResponse = AggResponse<AggPage<AggVenueMarket>>
public typealias AggSearchResponse = AggResponse<AggSearchResults>
public typealias AggListCategoriesResponse = AggResponse<AggPage<AggCategory>>
public typealias AggGetVenueGeoPolicyResponse = AggResponse<AggVenueGeoPolicy>
public typealias AggGetAppConfigResponse = AggResponse<AggAppConfig>

// Market data
public typealias AggGetMidpointsResponse = AggResponse<AggMidpoints>
public typealias AggGetOrderbooksResponse = AggResponse<AggOrderbooks>
public typealias AggGetOutcomeOrderbookResponse = AggResponse<AggOutcomeOrderbook>
public typealias AggGetChartBarsResponse = AggResponse<AggChartBars>
public typealias AggGetChartHistoryManifestResponse = AggResponse<AggChartHistoryManifest>

// Account
public typealias AggGetUserResponse = AggResponse<AggUserProfile>
public typealias AggGetDepositAddressesResponse = AggResponse<AggDepositAddresses>
public typealias AggGetBalancesResponse = AggResponse<AggBalances>
public typealias AggListPositionsResponse = AggResponse<AggPage<AggPosition>>
public typealias AggListOrdersResponse = AggResponse<AggPage<AggOrder>>
public typealias AggListActivityResponse = AggResponse<AggPage<AggActivityItem>>

// Trading
public typealias AggCreateQuoteResponse = AggResponse<AggQuote>
public typealias AggCreateOrderResponse = AggResponse<AggFill>
public typealias AggGetOrderResponse = AggResponse<AggExecutionStatus>
public typealias AggCreateLimitOrderResponse = AggResponse<AggLimitOrder>
public typealias AggCreateDirectOrderResponse = AggResponse<AggDirectOrder>
public typealias AggCancelOrderResponse = AggResponse<AggCancelResult>
public typealias AggRedeemPositionsResponse = AggResponse<AggRedeemResult>

// Withdrawals
public typealias AggQuoteWithdrawableResponse = AggResponse<AggWithdrawableQuote>
public typealias AggPreviewWithdrawalResponse = AggResponse<AggWithdrawalPreview>
/// The response of `createWithdrawal` and `getWithdrawal`.
public typealias AggWithdrawalResponse = AggResponse<AggWithdrawal>
