//
//  PortalNoahApiMock.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation
@testable import PortalSwift

final class PortalNoahApiMock: PortalNoahApiProtocol {
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

  func initiateKyc(request _: NoahInitiateKycRequest) async throws -> NoahInitiateKycResponse {
    initiateKycCalls += 1
    return initiateKycReturnValue ?? NoahInitiateKycResponse.stub()
  }

  func initiatePayin(request _: NoahInitiatePayinRequest) async throws -> NoahInitiatePayinResponse {
    initiatePayinCalls += 1
    return initiatePayinReturnValue ?? NoahInitiatePayinResponse.stub()
  }

  func simulatePayin(request _: NoahSimulatePayinRequest) async throws -> NoahSimulatePayinResponse {
    simulatePayinCalls += 1
    return simulatePayinReturnValue ?? NoahSimulatePayinResponse.stub()
  }

  func getPaymentMethods(request _: NoahGetPaymentMethodsRequest) async throws -> NoahGetPaymentMethodsResponse {
    getPaymentMethodsCalls += 1
    return getPaymentMethodsReturnValue ?? NoahGetPaymentMethodsResponse.stub()
  }

  func getPayoutCountries() async throws -> NoahGetPayoutCountriesResponse {
    getPayoutCountriesCalls += 1
    return getPayoutCountriesReturnValue ?? NoahGetPayoutCountriesResponse.stub()
  }

  func getPayoutChannels(request _: NoahGetPayoutChannelsRequest) async throws -> NoahGetPayoutChannelsResponse {
    getPayoutChannelsCalls += 1
    return getPayoutChannelsReturnValue ?? NoahGetPayoutChannelsResponse.stub()
  }

  func getPayoutChannelForm(channelId _: String) async throws -> NoahGetPayoutChannelFormResponse {
    getPayoutChannelFormCalls += 1
    return getPayoutChannelFormReturnValue ?? NoahGetPayoutChannelFormResponse.stub()
  }

  func getPayoutQuote(request _: NoahGetPayoutQuoteRequest) async throws -> NoahGetPayoutQuoteResponse {
    getPayoutQuoteCalls += 1
    return getPayoutQuoteReturnValue ?? NoahGetPayoutQuoteResponse.stub()
  }

  func initiatePayout(request _: NoahInitiatePayoutRequest) async throws -> NoahInitiatePayoutResponse {
    initiatePayoutCalls += 1
    return initiatePayoutReturnValue ?? NoahInitiatePayoutResponse.stub()
  }
}
