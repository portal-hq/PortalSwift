//
//  NoahMock.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation
@testable import PortalSwift

/// Mock implementation of `NoahProtocol` for testing purposes.
final class NoahMock: NoahProtocol {
  // Configurable return values
  var initiateKycReturnValue: NoahInitiateKycResponse?
  var initiatePayinReturnValue: NoahInitiatePayinResponse?
  var simulatePayinReturnValue: NoahSimulatePayinResponse?
  var getPaymentMethodsReturnValue: NoahGetPaymentMethodsResponse?
  var getPayoutCountriesReturnValue: NoahGetPayoutCountriesResponse?
  var getPayoutChannelsReturnValue: NoahGetPayoutChannelsResponse?
  var getPayoutChannelFormReturnValue: NoahGetPayoutChannelFormResponse?
  var getPayoutQuoteReturnValue: NoahGetPayoutQuoteResponse?
  var initiatePayoutReturnValue: NoahInitiatePayoutResponse?

  // Call counters
  var initiateKycCalls = 0
  var initiatePayinCalls = 0
  var simulatePayinCalls = 0
  var getPaymentMethodsCalls = 0
  var getPayoutCountriesCalls = 0
  var getPayoutChannelsCalls = 0
  var getPayoutChannelFormCalls = 0
  var getPayoutQuoteCalls = 0
  var initiatePayoutCalls = 0

  // Call parameters
  var initiateKycRequestParam: NoahInitiateKycRequest?
  var initiatePayinRequestParam: NoahInitiatePayinRequest?
  var simulatePayinRequestParam: NoahSimulatePayinRequest?
  var getPaymentMethodsRequestParam: NoahGetPaymentMethodsRequest?
  var getPayoutChannelsRequestParam: NoahGetPayoutChannelsRequest?
  var getPayoutChannelFormChannelIdParam: String?
  var getPayoutQuoteRequestParam: NoahGetPayoutQuoteRequest?
  var initiatePayoutRequestParam: NoahInitiatePayoutRequest?

  func initiateKyc(request: NoahInitiateKycRequest) async throws -> NoahInitiateKycResponse {
    initiateKycCalls += 1
    initiateKycRequestParam = request
    return initiateKycReturnValue ?? NoahInitiateKycResponse.stub()
  }

  func initiatePayin(request: NoahInitiatePayinRequest) async throws -> NoahInitiatePayinResponse {
    initiatePayinCalls += 1
    initiatePayinRequestParam = request
    return initiatePayinReturnValue ?? NoahInitiatePayinResponse.stub()
  }

  func simulatePayin(request: NoahSimulatePayinRequest) async throws -> NoahSimulatePayinResponse {
    simulatePayinCalls += 1
    simulatePayinRequestParam = request
    return simulatePayinReturnValue ?? NoahSimulatePayinResponse.stub()
  }

  func getPaymentMethods(request: NoahGetPaymentMethodsRequest) async throws -> NoahGetPaymentMethodsResponse {
    getPaymentMethodsCalls += 1
    getPaymentMethodsRequestParam = request
    return getPaymentMethodsReturnValue ?? NoahGetPaymentMethodsResponse.stub()
  }

  func getPayoutCountries() async throws -> NoahGetPayoutCountriesResponse {
    getPayoutCountriesCalls += 1
    return getPayoutCountriesReturnValue ?? NoahGetPayoutCountriesResponse.stub()
  }

  func getPayoutChannels(request: NoahGetPayoutChannelsRequest) async throws -> NoahGetPayoutChannelsResponse {
    getPayoutChannelsCalls += 1
    getPayoutChannelsRequestParam = request
    return getPayoutChannelsReturnValue ?? NoahGetPayoutChannelsResponse.stub()
  }

  func getPayoutChannelForm(channelId: String) async throws -> NoahGetPayoutChannelFormResponse {
    getPayoutChannelFormCalls += 1
    getPayoutChannelFormChannelIdParam = channelId
    return getPayoutChannelFormReturnValue ?? NoahGetPayoutChannelFormResponse.stub()
  }

  func getPayoutQuote(request: NoahGetPayoutQuoteRequest) async throws -> NoahGetPayoutQuoteResponse {
    getPayoutQuoteCalls += 1
    getPayoutQuoteRequestParam = request
    return getPayoutQuoteReturnValue ?? NoahGetPayoutQuoteResponse.stub()
  }

  func initiatePayout(request: NoahInitiatePayoutRequest) async throws -> NoahInitiatePayoutResponse {
    initiatePayoutCalls += 1
    initiatePayoutRequestParam = request
    return initiatePayoutReturnValue ?? NoahInitiatePayoutResponse.stub()
  }
}
