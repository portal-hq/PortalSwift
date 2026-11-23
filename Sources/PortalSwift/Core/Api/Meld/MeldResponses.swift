//
//  MeldResponses.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

// Customers
public typealias MeldCreateCustomerResponse = MeldResponse<MeldCustomer>
public typealias MeldSearchCustomerResponse = MeldResponse<MeldCustomerSearchResult>

// Retail
public typealias MeldGetRetailQuoteResponse = MeldResponse<MeldRetailQuoteResult>
public typealias MeldCreateRetailWidgetResponse = MeldResponse<MeldWidgetSession>
public typealias MeldSearchRetailTransactionsResponse = MeldResponse<MeldTransactionSearchResult>
/// Returned by both `getRetailTransaction` and `getRetailTransactionBySession`.
public typealias MeldGetRetailTransactionResponse = MeldResponse<MeldTransactionResult>

// Network Partners
public typealias MeldGetNetworkPartnerCountriesResponse = MeldResponse<MeldNetworkPartnerCountriesResult>
public typealias MeldGetNetworkPartnerCurrenciesResponse = MeldResponse<MeldNetworkPartnerCurrenciesResult>
public typealias MeldGetNetworkPartnerFiatLimitsResponse = MeldResponse<MeldNetworkPartnerFiatLimitsResult>
public typealias MeldGetNetworkPartnerKycLimitsResponse = MeldResponse<MeldNetworkPartnerKycLimitsResult>
public typealias MeldGetNetworkPartnersResponse = MeldResponse<[MeldNetworkPartner]>
public typealias MeldGetNetworkPartnerPaymentMethodsResponse = MeldResponse<[MeldNetworkPartnerPaymentMethod]>
public typealias MeldGetNetworkPartnerRoutesResponse = MeldResponse<[MeldNetworkPartnerRoute]>
/// `data` is `nil` when Meld has no defaults for the country and category.
public typealias MeldGetNetworkPartnerCountryDefaultsResponse = MeldNullableResponse<MeldNetworkPartnerCountryDefaults>
