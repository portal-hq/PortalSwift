//
//  PortalNoahApiSpy.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation
@testable import PortalSwift

final class PortalNoahApiSpy: PortalNoahApiProtocol {
  // MARK: - initiateKyc

  var initiateKycCallsCount = 0
  var initiateKycRequestParam: NoahInitiateKycRequest?
  var initiateKycReturnValue: NoahInitiateKycResponse = .stub()
  func initiateKyc(request: NoahInitiateKycRequest) async throws -> NoahInitiateKycResponse {
    initiateKycCallsCount += 1
    initiateKycRequestParam = request
    return initiateKycReturnValue
  }

  // MARK: - initiatePayin

  var initiatePayinCallsCount = 0
  var initiatePayinRequestParam: NoahInitiatePayinRequest?
  var initiatePayinReturnValue: NoahInitiatePayinResponse = .stub()
  func initiatePayin(request: NoahInitiatePayinRequest) async throws -> NoahInitiatePayinResponse {
    initiatePayinCallsCount += 1
    initiatePayinRequestParam = request
    return initiatePayinReturnValue
  }

  // MARK: - simulatePayin

  var simulatePayinCallsCount = 0
  var simulatePayinRequestParam: NoahSimulatePayinRequest?
  var simulatePayinReturnValue: NoahSimulatePayinResponse = .stub()
  func simulatePayin(request: NoahSimulatePayinRequest) async throws -> NoahSimulatePayinResponse {
    simulatePayinCallsCount += 1
    simulatePayinRequestParam = request
    return simulatePayinReturnValue
  }

  // MARK: - getPaymentMethods

  var getPaymentMethodsCallsCount = 0
  var getPaymentMethodsRequestParam: NoahGetPaymentMethodsRequest?
  var getPaymentMethodsReturnValue: NoahGetPaymentMethodsResponse = .stub()
  func getPaymentMethods(request: NoahGetPaymentMethodsRequest) async throws -> NoahGetPaymentMethodsResponse {
    getPaymentMethodsCallsCount += 1
    getPaymentMethodsRequestParam = request
    return getPaymentMethodsReturnValue
  }

  // MARK: - getPayoutCountries

  var getPayoutCountriesCallsCount = 0
  var getPayoutCountriesReturnValue: NoahGetPayoutCountriesResponse = .stub()
  func getPayoutCountries() async throws -> NoahGetPayoutCountriesResponse {
    getPayoutCountriesCallsCount += 1
    return getPayoutCountriesReturnValue
  }

  // MARK: - getPayoutChannels

  var getPayoutChannelsCallsCount = 0
  var getPayoutChannelsRequestParam: NoahGetPayoutChannelsRequest?
  var getPayoutChannelsReturnValue: NoahGetPayoutChannelsResponse = .stub()
  func getPayoutChannels(request: NoahGetPayoutChannelsRequest) async throws -> NoahGetPayoutChannelsResponse {
    getPayoutChannelsCallsCount += 1
    getPayoutChannelsRequestParam = request
    return getPayoutChannelsReturnValue
  }

  // MARK: - getPayoutChannelForm

  var getPayoutChannelFormCallsCount = 0
  var getPayoutChannelFormChannelIdParam: String?
  var getPayoutChannelFormReturnValue: NoahGetPayoutChannelFormResponse = .stub()
  func getPayoutChannelForm(channelId: String) async throws -> NoahGetPayoutChannelFormResponse {
    getPayoutChannelFormCallsCount += 1
    getPayoutChannelFormChannelIdParam = channelId
    return getPayoutChannelFormReturnValue
  }

  // MARK: - getPayoutQuote

  var getPayoutQuoteCallsCount = 0
  var getPayoutQuoteRequestParam: NoahGetPayoutQuoteRequest?
  var getPayoutQuoteReturnValue: NoahGetPayoutQuoteResponse = .stub()
  func getPayoutQuote(request: NoahGetPayoutQuoteRequest) async throws -> NoahGetPayoutQuoteResponse {
    getPayoutQuoteCallsCount += 1
    getPayoutQuoteRequestParam = request
    return getPayoutQuoteReturnValue
  }

  // MARK: - initiatePayout

  var initiatePayoutCallsCount = 0
  var initiatePayoutRequestParam: NoahInitiatePayoutRequest?
  var initiatePayoutReturnValue: NoahInitiatePayoutResponse = .stub()
  func initiatePayout(request: NoahInitiatePayoutRequest) async throws -> NoahInitiatePayoutResponse {
    initiatePayoutCallsCount += 1
    initiatePayoutRequestParam = request
    return initiatePayoutReturnValue
  }
}
