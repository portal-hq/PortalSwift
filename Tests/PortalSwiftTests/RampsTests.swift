//
//  RampsTests.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation
@testable import PortalSwift
import XCTest

final class RampsTests: XCTestCase {
  var api: PortalApi!
  var rampsInstance: Ramps!

  override func setUpWithError() throws {
    api = PortalApi(apiKey: MockConstants.mockApiKey, requests: PortalRequestsMock())
    rampsInstance = Ramps(api: api)
  }

  override func tearDownWithError() throws {
    api = nil
    rampsInstance = nil
  }
}

// MARK: - Initialization Tests

extension RampsTests {
  func test_init_createsInstanceSuccessfully() {
    let portalApi = PortalApi(apiKey: MockConstants.mockApiKey, requests: PortalRequestsMock())
    let ramps = Ramps(api: portalApi)
    XCTAssertNotNil(ramps)
  }

  func test_init_initializesNoahProperty() {
    let portalApi = PortalApi(apiKey: MockConstants.mockApiKey, requests: PortalRequestsMock())
    let ramps = Ramps(api: portalApi)
    XCTAssertNotNil(ramps.noah)
  }

  func test_init_noahIsOfCorrectType() {
    let portalApi = PortalApi(apiKey: MockConstants.mockApiKey, requests: PortalRequestsMock())
    let ramps = Ramps(api: portalApi)
    XCTAssertTrue(ramps.noah is NoahProtocol)
  }

  func test_init_withMockApi() {
    let mockApi = PortalApiMock()
    let ramps = Ramps(api: mockApi)
    XCTAssertNotNil(ramps)
    XCTAssertNotNil(ramps.noah)
  }
}

// MARK: - Forwarding Success Tests

extension RampsTests {
  func test_noah_initiateKyc_forwardsToApi() async throws {
    let noahApiMock = PortalNoahApiMock()
    noahApiMock.initiateKycReturnValue = NoahInitiateKycResponse.stub()
    let mockApi = PortalApiMock(noah: noahApiMock)
    let ramps = Ramps(api: mockApi)

    let response = try await ramps.noah.initiateKyc(request: .stub())

    XCTAssertNotNil(response.data)
    XCTAssertEqual(noahApiMock.initiateKycCalls, 1)
  }

  func test_noah_initiatePayin_forwardsToApi() async throws {
    let noahApiMock = PortalNoahApiMock()
    noahApiMock.initiatePayinReturnValue = NoahInitiatePayinResponse.stub()
    let ramps = Ramps(api: PortalApiMock(noah: noahApiMock))

    let response = try await ramps.noah.initiatePayin(request: .stub())

    XCTAssertNotNil(response.data)
    XCTAssertEqual(noahApiMock.initiatePayinCalls, 1)
  }

  func test_noah_simulatePayin_forwardsToApi() async throws {
    let noahApiMock = PortalNoahApiMock()
    noahApiMock.simulatePayinReturnValue = NoahSimulatePayinResponse.stub()
    let ramps = Ramps(api: PortalApiMock(noah: noahApiMock))

    let response = try await ramps.noah.simulatePayin(request: .stub())

    XCTAssertNotNil(response.data)
    XCTAssertEqual(noahApiMock.simulatePayinCalls, 1)
  }

  func test_noah_getPaymentMethods_forwardsToApi() async throws {
    let noahApiMock = PortalNoahApiMock()
    noahApiMock.getPaymentMethodsReturnValue = NoahGetPaymentMethodsResponse.stub()
    let ramps = Ramps(api: PortalApiMock(noah: noahApiMock))

    let response = try await ramps.noah.getPaymentMethods()

    XCTAssertNotNil(response.data)
    XCTAssertEqual(noahApiMock.getPaymentMethodsCalls, 1)
  }

  func test_noah_getPayoutCountries_forwardsToApi() async throws {
    let noahApiMock = PortalNoahApiMock()
    noahApiMock.getPayoutCountriesReturnValue = NoahGetPayoutCountriesResponse.stub()
    let ramps = Ramps(api: PortalApiMock(noah: noahApiMock))

    let response = try await ramps.noah.getPayoutCountries()

    XCTAssertNotNil(response.data)
    XCTAssertEqual(noahApiMock.getPayoutCountriesCalls, 1)
  }

  func test_noah_getPayoutChannels_forwardsToApi() async throws {
    let noahApiMock = PortalNoahApiMock()
    noahApiMock.getPayoutChannelsReturnValue = NoahGetPayoutChannelsResponse.stub()
    let ramps = Ramps(api: PortalApiMock(noah: noahApiMock))

    let response = try await ramps.noah.getPayoutChannels(request: .stub())

    XCTAssertNotNil(response.data)
    XCTAssertEqual(noahApiMock.getPayoutChannelsCalls, 1)
  }

  func test_noah_getPayoutChannelForm_forwardsToApi() async throws {
    let noahApiMock = PortalNoahApiMock()
    noahApiMock.getPayoutChannelFormReturnValue = NoahGetPayoutChannelFormResponse.stub()
    let ramps = Ramps(api: PortalApiMock(noah: noahApiMock))

    let response = try await ramps.noah.getPayoutChannelForm(channelId: "channel-1")

    XCTAssertNotNil(response.data)
    XCTAssertEqual(noahApiMock.getPayoutChannelFormCalls, 1)
  }

  func test_noah_getPayoutQuote_forwardsToApi() async throws {
    let noahApiMock = PortalNoahApiMock()
    noahApiMock.getPayoutQuoteReturnValue = NoahGetPayoutQuoteResponse.stub()
    let ramps = Ramps(api: PortalApiMock(noah: noahApiMock))

    let response = try await ramps.noah.getPayoutQuote(request: .stub())

    XCTAssertNotNil(response.data)
    XCTAssertEqual(noahApiMock.getPayoutQuoteCalls, 1)
  }

  func test_noah_initiatePayout_forwardsToApi() async throws {
    let noahApiMock = PortalNoahApiMock()
    noahApiMock.initiatePayoutReturnValue = NoahInitiatePayoutResponse.stub()
    let ramps = Ramps(api: PortalApiMock(noah: noahApiMock))

    let response = try await ramps.noah.initiatePayout(request: .stub())

    XCTAssertNotNil(response.data)
    XCTAssertEqual(noahApiMock.initiatePayoutCalls, 1)
  }
}

// MARK: - Dependency Injection Tests

extension RampsTests {
  func test_noah_supportsCustomMockInjection() async throws {
    let noahMock = NoahMock()
    rampsInstance.noah = noahMock

    _ = try await rampsInstance.noah.getPayoutCountries()

    XCTAssertEqual(noahMock.getPayoutCountriesCalls, 1)
  }

  func test_noah_propertyIsStable() {
    let first = rampsInstance.noah
    let second = rampsInstance.noah
    XCTAssertTrue(first as AnyObject === second as AnyObject)
  }
}
