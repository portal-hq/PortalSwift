//
//  TradingTests.swift
//  PortalSwift
//
//  Created by Portal Labs
//

import Foundation
@testable import PortalSwift
import XCTest

final class TradingTests: XCTestCase {
  var api: PortalApi!
  var tradingInstance: Trading!

  override func setUpWithError() throws {
    api = PortalApi(apiKey: MockConstants.mockApiKey, requests: PortalRequestsMock())
    tradingInstance = Trading(api: api)
  }

  override func tearDownWithError() throws {
    api = nil
    tradingInstance = nil
  }
}

// MARK: - Initialization Tests

extension TradingTests {
  func test_init_createsInstanceSuccessfully() {
    // given
    let portalApi = PortalApi(apiKey: MockConstants.mockApiKey, requests: PortalRequestsMock())

    // when
    let trading = Trading(api: portalApi)

    // then
    XCTAssertNotNil(trading)
  }

  func test_init_initializesLifiProperty() {
    // given
    let portalApi = PortalApi(apiKey: MockConstants.mockApiKey, requests: PortalRequestsMock())

    // when
    let trading = Trading(api: portalApi)

    // then
    XCTAssertNotNil(trading.lifi)
  }

  func test_init_lifiIsOfCorrectType() {
    // given
    let portalApi = PortalApi(apiKey: MockConstants.mockApiKey, requests: PortalRequestsMock())

    // when
    let trading = Trading(api: portalApi)

    // then
    XCTAssertTrue(trading.lifi is LifiProtocol)
  }

  func test_init_withCustomApiKey() {
    // given
    let customApiKey = "custom-api-key-for-trading"
    let portalApi = PortalApi(apiKey: customApiKey, requests: PortalRequestsMock())

    // when
    let trading = Trading(api: portalApi)

    // then
    XCTAssertNotNil(trading.lifi)
  }

  func test_init_withMockApi() {
    // given
    let mockApi = PortalApiMock()

    // when
    let trading = Trading(api: mockApi)

    // then
    XCTAssertNotNil(trading)
    XCTAssertNotNil(trading.lifi)
  }

  func test_init_withCustomLifiApi() {
    // given
    let lifiApiMock = PortalLifiTradingApiMock()
    let mockApi = PortalApiMock(lifi: lifiApiMock)

    // when
    let trading = Trading(api: mockApi)

    // then
    XCTAssertNotNil(trading.lifi)
  }
}

// MARK: - Property Access Tests

extension TradingTests {
  func test_lifi_isAccessible() {
    // given & when
    let lifi = tradingInstance.lifi

    // then
    XCTAssertNotNil(lifi)
  }

  func test_lifi_isPublic() {
    // given & when
    let lifi = tradingInstance.lifi

    // then - if this compiles, the property is public
    XCTAssertNotNil(lifi)
  }

  func test_lifi_canBeReassigned() {
    // given
    let lifiMock = LifiMock()

    // when
    tradingInstance.lifi = lifiMock

    // then
    XCTAssertTrue(tradingInstance.lifi as AnyObject === lifiMock as AnyObject)
  }

  func test_lifi_multipleCalls_returnSameInstance() {
    // given
    var instances: [LifiProtocol] = []

    // when
    for _ in 0 ..< 10 {
      instances.append(tradingInstance.lifi)
    }

    // then - all should be the same instance
    let firstInstance = instances[0]
    for instance in instances {
      XCTAssertTrue(instance as AnyObject === firstInstance as AnyObject)
    }
  }
}

// MARK: - Integration Tests with Lifi

extension TradingTests {
  func test_lifi_canCallGetRoutes() async throws {
    // given
    let mockResponse = LifiRoutesResponse.stub()
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getRoutesReturnValue = mockResponse
    let mockApi = PortalApiMock(lifi: lifiApiMock)
    let trading = Trading(api: mockApi)

    let request = LifiRoutesRequest.stub()

    // when
    let response = try await trading.lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(lifiApiMock.getRoutesCalls, 1)
  }

  func test_lifi_canCallGetRoutesWithParams() async throws {
    // given
    let mockResponse = LifiRoutesResponse.stub()
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getRoutesReturnValue = mockResponse
    let mockApi = PortalApiMock(lifi: lifiApiMock)
    let trading = Trading(api: mockApi)

    let options = LifiRoutesRequestOptions.stub(slippage: 0.01, order: .cheapest)
    let request = LifiRoutesRequest(
      fromChainId: "1",
      fromAmount: "1000000000000000000",
      fromTokenAddress: "0x0",
      toChainId: "137",
      toTokenAddress: "0x1010",
      options: options,
      fromAddress: "0xtest"
    )

    // when
    let response = try await trading.lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(lifiApiMock.getRoutesCalls, 1)
  }

  func test_lifi_canCallGetQuote() async throws {
    // given
    let mockResponse = LifiQuoteResponse.stub()
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getQuoteReturnValue = mockResponse
    let mockApi = PortalApiMock(lifi: lifiApiMock)
    let trading = Trading(api: mockApi)

    let request = LifiQuoteRequest.stub()

    // when
    let response = try await trading.lifi.getQuote(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(lifiApiMock.getQuoteCalls, 1)
  }

  func test_lifi_canCallGetStatus() async throws {
    // given
    let mockResponse = LifiStatusResponse.stub()
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getStatusReturnValue = mockResponse
    let mockApi = PortalApiMock(lifi: lifiApiMock)
    let trading = Trading(api: mockApi)

    let request = LifiStatusRequest.stub()

    // when
    let response = try await trading.lifi.getStatus(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(response.data?.rawResponse.status, .done)
    XCTAssertEqual(lifiApiMock.getStatusCalls, 1)
  }

  func test_lifi_canCallGetRouteStep() async throws {
    // given
    let mockResponse = LifiStepTransactionResponse.stub()
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getRouteStepReturnValue = mockResponse
    let mockApi = PortalApiMock(lifi: lifiApiMock)
    let trading = Trading(api: mockApi)

    let request = LifiStep.stub()

    // when
    let response = try await trading.lifi.getRouteStep(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(lifiApiMock.getRouteStepCalls, 1)
  }
}

// MARK: - Multiple Instance Tests

extension TradingTests {
  func test_multipleInstances_haveIndependentLifi() {
    // given
    let api1 = PortalApi(apiKey: "key1", requests: PortalRequestsMock())
    let api2 = PortalApi(apiKey: "key2", requests: PortalRequestsMock())

    // when
    let trading1 = Trading(api: api1)
    let trading2 = Trading(api: api2)

    // then
    XCTAssertFalse(trading1 === trading2)
    XCTAssertFalse(trading1.lifi as AnyObject === trading2.lifi as AnyObject)
  }

  func test_multipleInstances_withSameApi_haveDifferentLifi() {
    // given
    let api = PortalApi(apiKey: MockConstants.mockApiKey, requests: PortalRequestsMock())

    // when
    let trading1 = Trading(api: api)
    let trading2 = Trading(api: api)

    // then - different Trading instances
    XCTAssertFalse(trading1 === trading2)
    // different Lifi instances since they're created in init
    XCTAssertFalse(trading1.lifi as AnyObject === trading2.lifi as AnyObject)
  }

  func test_multipleInstances_canOperateIndependently() async throws {
    // given
    let mockResponse1 = LifiRoutesResponse.stub()
    let mockResponse2 = LifiRoutesResponse.stub()

    let lifiApiMock1 = PortalLifiTradingApiMock()
    lifiApiMock1.getRoutesReturnValue = mockResponse1

    let lifiApiMock2 = PortalLifiTradingApiMock()
    lifiApiMock2.getRoutesReturnValue = mockResponse2

    let mockApi1 = PortalApiMock(lifi: lifiApiMock1)
    let mockApi2 = PortalApiMock(lifi: lifiApiMock2)

    let trading1 = Trading(api: mockApi1)
    let trading2 = Trading(api: mockApi2)

    // when
    _ = try await trading1.lifi.getRoutes(request: LifiRoutesRequest.stub())
    _ = try await trading2.lifi.getRoutes(request: LifiRoutesRequest.stub())

    // then
    XCTAssertEqual(lifiApiMock1.getRoutesCalls, 1)
    XCTAssertEqual(lifiApiMock2.getRoutesCalls, 1)
  }
}

// MARK: - Error Handling Tests

extension TradingTests {
  func test_lifi_handlesErrors() async throws {
    // given
    let mockError = "Test error from Lifi API"
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getRoutesReturnValue = LifiRoutesResponse(data: nil, error: mockError)
    let mockApi = PortalApiMock(lifi: lifiApiMock)
    let trading = Trading(api: mockApi)

    // when
    let response = try await trading.lifi.getRoutes(request: LifiRoutesRequest.stub())

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(response.error, mockError)
    XCTAssertNil(response.data)
  }

  func test_lifi_propagatesApiErrors() async throws {
    // given
    let mockError = "API communication error"
    let lifiApiMock = PortalLifiTradingApiMock()
    lifiApiMock.getQuoteReturnValue = LifiQuoteResponse(data: nil, error: mockError)
    let mockApi = PortalApiMock(lifi: lifiApiMock)
    let trading = Trading(api: mockApi)

    let request = LifiQuoteRequest.stub()

    // when
    let response = try await trading.lifi.getQuote(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(response.error, mockError)
    XCTAssertNil(response.data)
  }
}

// MARK: - Type Safety Tests

extension TradingTests {
  func test_trading_isPublicClass() {
    // given & when - if this compiles, Trading is public
    let trading: Trading = tradingInstance

    // then
    XCTAssertNotNil(trading)
  }

  func test_lifi_returnsCorrectType() {
    // given
    let lifi = tradingInstance.lifi

    // when
    let isLifiProtocol = lifi is LifiProtocol

    // then
    XCTAssertTrue(isLifiProtocol)
  }

  func test_trading_conformsToExpectedBehavior() {
    // given
    let trading = Trading(api: api)

    // when - accessing lifi property
    let lifi = trading.lifi

    // then - should return a valid LifiProtocol instance
    XCTAssertNotNil(lifi)
    XCTAssertTrue(lifi is LifiProtocol)
  }
}

// MARK: - Thread Safety Tests

extension TradingTests {
  func test_lifi_accessFromMultipleThreads() {
    // given
    let trading = Trading(api: api)
    let expectation = XCTestExpectation(description: "Multiple thread access")
    expectation.expectedFulfillmentCount = 10
    var instances: [LifiProtocol] = []
    let lock = NSLock()

    // when
    for _ in 0 ..< 10 {
      DispatchQueue.global().async {
        let lifi = trading.lifi
        lock.lock()
        instances.append(lifi)
        lock.unlock()
        expectation.fulfill()
      }
    }

    // then
    wait(for: [expectation], timeout: 5.0)
    let firstInstance = instances[0]
    for instance in instances {
      XCTAssertTrue(instance as? AnyObject === firstInstance as? AnyObject, "All thread accesses should return the same instance")
    }
  }
}

// MARK: - Protocol Injection Tests

extension TradingTests {
  func test_init_withLifiProtocol() {
    // given
    let lifiMock = LifiMock()
    let trading = Trading(api: api)

    // when
    trading.lifi = lifiMock

    // then
    XCTAssertNotNil(trading)
    XCTAssertNotNil(trading.lifi)
  }

  func test_init_withLifiMock_usesInjectedInstance() {
    // given
    let lifiMock = LifiMock()
    let trading = Trading(api: api)

    // when
    trading.lifi = lifiMock

    // then - should use the injected mock
    XCTAssertTrue(trading.lifi as AnyObject === lifiMock as AnyObject)
  }

  func test_lifi_withMock_canCallGetRoutes() async throws {
    // given
    let mockResponse = LifiRoutesResponse.stub()
    let lifiMock = LifiMock()
    lifiMock.getRoutesReturnValue = mockResponse
    let trading = Trading(api: api)
    trading.lifi = lifiMock

    // when
    let response = try await trading.lifi.getRoutes(request: LifiRoutesRequest.stub())

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(lifiMock.getRoutesCalls, 1)
  }

  func test_lifi_withMock_canCallGetRoutesWithRequest() async throws {
    // given
    let mockResponse = LifiRoutesResponse.stub()
    let lifiMock = LifiMock()
    lifiMock.getRoutesReturnValue = mockResponse
    let trading = Trading(api: api)
    trading.lifi = lifiMock

    let options = LifiRoutesRequestOptions.stub(slippage: 0.02)
    let request = LifiRoutesRequest(
      fromChainId: "1",
      fromAmount: "1000000000000000000",
      fromTokenAddress: "0xtest",
      toChainId: "137",
      toTokenAddress: "0xtest2",
      options: options
    )

    // when
    let response = try await trading.lifi.getRoutes(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(lifiMock.getRoutesCalls, 1)
    XCTAssertNotNil(lifiMock.getRoutesRequestParam)
    XCTAssertEqual(lifiMock.getRoutesRequestParam?.fromChainId, "1")
    XCTAssertEqual(lifiMock.getRoutesRequestParam?.options?.slippage, 0.02)
  }

  func test_lifi_withMock_canCallGetQuote() async throws {
    // given
    let mockResponse = LifiQuoteResponse.stub()
    let lifiMock = LifiMock()
    lifiMock.getQuoteReturnValue = mockResponse
    let trading = Trading(api: api)
    trading.lifi = lifiMock

    let request = LifiQuoteRequest.stub()

    // when
    let response = try await trading.lifi.getQuote(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(lifiMock.getQuoteCalls, 1)
  }

  func test_lifi_withMock_canCallGetStatus() async throws {
    // given
    let mockResponse = LifiStatusResponse.stub()
    let lifiMock = LifiMock()
    lifiMock.getStatusReturnValue = mockResponse
    let trading = Trading(api: api)
    trading.lifi = lifiMock

    let request = LifiStatusRequest.stub()

    // when
    let response = try await trading.lifi.getStatus(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(lifiMock.getStatusCalls, 1)
    XCTAssertEqual(lifiMock.getStatusRequestParam?.txHash, request.txHash)
  }

  func test_lifi_withMock_canCallGetRouteStep() async throws {
    // given
    let mockResponse = LifiStepTransactionResponse.stub()
    let lifiMock = LifiMock()
    lifiMock.getRouteStepReturnValue = mockResponse
    let trading = Trading(api: api)
    trading.lifi = lifiMock

    let request = LifiStep.stub()

    // when
    let response = try await trading.lifi.getRouteStep(request: request)

    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(lifiMock.getRouteStepCalls, 1)
  }

  func test_lifi_withMock_tracksMultipleCalls() async throws {
    // given
    let lifiMock = LifiMock()
    let trading = Trading(api: api)
    trading.lifi = lifiMock

    // when
    _ = try await trading.lifi.getRoutes(request: LifiRoutesRequest.stub())
    _ = try await trading.lifi.getRoutes(request: LifiRoutesRequest.stub())
    _ = try await trading.lifi.getRoutes(request: LifiRoutesRequest.stub())

    // then
    XCTAssertEqual(lifiMock.getRoutesCalls, 3)
  }

  func test_lifi_withMock_tracksDifferentMethodCalls() async throws {
    // given
    let lifiMock = LifiMock()
    let trading = Trading(api: api)
    trading.lifi = lifiMock

    // when
    _ = try await trading.lifi.getRoutes(request: LifiRoutesRequest.stub())
    _ = try await trading.lifi.getQuote(request: LifiQuoteRequest.stub())
    _ = try await trading.lifi.getStatus(request: LifiStatusRequest.stub())
    _ = try await trading.lifi.getRouteStep(request: LifiStep.stub())

    // then
    XCTAssertEqual(lifiMock.getRoutesCalls, 1)
    XCTAssertEqual(lifiMock.getQuoteCalls, 1)
    XCTAssertEqual(lifiMock.getStatusCalls, 1)
    XCTAssertEqual(lifiMock.getRouteStepCalls, 1)
  }
}

// MARK: - Protocol Conformance Tests

extension TradingTests {
  func test_lifi_conformsToProtocol() {
    // given
    let portalApi = PortalApi(apiKey: MockConstants.mockApiKey, requests: PortalRequestsMock())
    let lifi = Lifi(api: portalApi.lifi)

    // when
    let conformsToProtocol = lifi is LifiProtocol

    // then
    XCTAssertTrue(conformsToProtocol)
  }

  func test_lifiMock_conformsToProtocol() {
    // given
    let lifiMock = LifiMock()

    // when
    let conformsToProtocol = lifiMock is LifiProtocol

    // then
    XCTAssertTrue(conformsToProtocol)
  }

  func test_protocol_canBeUsedPolymorphically() {
    // given
    let portalApi = PortalApi(apiKey: MockConstants.mockApiKey, requests: PortalRequestsMock())
    let implementations: [LifiProtocol] = [
      Lifi(api: portalApi.lifi),
      LifiMock()
    ]

    // when & then
    for implementation in implementations {
      XCTAssertNotNil(implementation)
      XCTAssertTrue(implementation is LifiProtocol)
    }
  }

  func test_trading_acceptsAnyProtocolConformingType() {
    // given
    let lifiMock = LifiMock()
    let portalApi = PortalApi(apiKey: MockConstants.mockApiKey, requests: PortalRequestsMock())
    let lifi = Lifi(api: portalApi.lifi)

    // when
    let tradingWithMock = Trading(api: portalApi)
    tradingWithMock.lifi = lifiMock

    let tradingWithConcrete = Trading(api: portalApi)
    tradingWithConcrete.lifi = lifi

    // then
    XCTAssertNotNil(tradingWithMock)
    XCTAssertNotNil(tradingWithConcrete)
    XCTAssertTrue(tradingWithMock.lifi is LifiProtocol)
    XCTAssertTrue(tradingWithConcrete.lifi is LifiProtocol)
  }
}

// MARK: - Mock Behavior Tests

extension TradingTests {
  func test_lifiMock_defaultReturnValues() async throws {
    // given
    let lifiMock = LifiMock()

    // when - calling methods without setting return values
    let routesResponse = try await lifiMock.getRoutes(request: LifiRoutesRequest.stub())
    let quoteResponse = try await lifiMock.getQuote(request: LifiQuoteRequest.stub())
    let statusResponse = try await lifiMock.getStatus(request: LifiStatusRequest.stub())
    let stepResponse = try await lifiMock.getRouteStep(request: LifiStep.stub())

    // then - should return stub values
    XCTAssertNotNil(routesResponse)
    XCTAssertNotNil(quoteResponse)
    XCTAssertNotNil(statusResponse)
    XCTAssertNotNil(stepResponse)
  }

  func test_lifiMock_customReturnValues() async throws {
    // given
    let customResponse = LifiRoutesResponse(data: nil, error: "Custom error")
    let lifiMock = LifiMock()
    lifiMock.getRoutesReturnValue = customResponse

    // when
    let response = try await lifiMock.getRoutes(request: LifiRoutesRequest.stub())

    // then
    XCTAssertEqual(response.error, "Custom error")
    XCTAssertNil(response.data)
  }

  func test_lifiMock_parameterCapture() async throws {
    // given
    let lifiMock = LifiMock()
    let options = LifiRoutesRequestOptions.stub(slippage: 0.03, order: .cheapest)
    let request = LifiRoutesRequest(
      fromChainId: "1",
      fromAmount: "2000000000000000000",
      fromTokenAddress: "0xcaptured",
      toChainId: "42161",
      toTokenAddress: "0xarbitrum",
      options: options
    )

    // when
    _ = try await lifiMock.getRoutes(request: request)

    // then - should capture the request parameters
    XCTAssertNotNil(lifiMock.getRoutesRequestParam)
    XCTAssertEqual(lifiMock.getRoutesRequestParam?.fromChainId, "1")
    XCTAssertEqual(lifiMock.getRoutesRequestParam?.toChainId, "42161")
    XCTAssertEqual(lifiMock.getRoutesRequestParam?.fromAmount, "2000000000000000000")
    XCTAssertEqual(lifiMock.getRoutesRequestParam?.options?.slippage, 0.03)
    XCTAssertEqual(lifiMock.getRoutesRequestParam?.options?.order, .cheapest)
  }

  func test_lifiMock_resetsBetweenCalls() async throws {
    // given
    let lifiMock = LifiMock()

    // when - first call
    _ = try await lifiMock.getRoutes(request: LifiRoutesRequest.stub(fromChainId: "1"))
    let firstParam = lifiMock.getRoutesRequestParam?.fromChainId

    // when - second call
    _ = try await lifiMock.getRoutes(request: LifiRoutesRequest.stub(fromChainId: "137"))
    let secondParam = lifiMock.getRoutesRequestParam?.fromChainId

    // then - should capture latest parameters
    XCTAssertEqual(firstParam, "1")
    XCTAssertEqual(secondParam, "137")
    XCTAssertEqual(lifiMock.getRoutesCalls, 2)
  }
}

// MARK: - Dependency Injection Tests

extension TradingTests {
  func test_trading_supportsDependencyInjection() {
    // given
    let lifiMock = LifiMock()
    let trading = Trading(api: api)

    // when - inject custom implementation
    trading.lifi = lifiMock

    // then - should use injected implementation
    XCTAssertTrue(trading.lifi as AnyObject === lifiMock as AnyObject)
  }

  func test_trading_injectedMock_isolatesTestBehavior() async throws {
    // given
    let lifiMock1 = LifiMock()
    let lifiMock2 = LifiMock()

    let trading1 = Trading(api: api)
    trading1.lifi = lifiMock1

    let trading2 = Trading(api: api)
    trading2.lifi = lifiMock2

    // when
    _ = try await trading1.lifi.getRoutes(request: LifiRoutesRequest.stub())
    _ = try await trading1.lifi.getRoutes(request: LifiRoutesRequest.stub())
    _ = try await trading2.lifi.getRoutes(request: LifiRoutesRequest.stub())

    // then - mocks should be isolated
    XCTAssertEqual(lifiMock1.getRoutesCalls, 2)
    XCTAssertEqual(lifiMock2.getRoutesCalls, 1)
  }
}

// MARK: - Cross-Chain Swap Flow Tests

extension TradingTests {
  func test_crossChainSwapFlow_complete() async throws {
    // given
    let lifiMock = LifiMock()
    let trading = Trading(api: api)
    trading.lifi = lifiMock

    // Step 1: Get routes
    let routes = [
      LifiRoute.stub(id: "route-1", tags: ["FASTEST"]),
      LifiRoute.stub(id: "route-2", tags: ["CHEAPEST"])
    ]
    lifiMock.getRoutesReturnValue = LifiRoutesResponse.stub(
      data: LifiRoutesData(rawResponse: LifiRoutesRawResponse(routes: routes, unavailableRoutes: nil))
    )

    let routesRequest = LifiRoutesRequest.stub()
    let routesResponse = try await trading.lifi.getRoutes(request: routesRequest)

    // Step 2: Get quote for selected route
    lifiMock.getQuoteReturnValue = LifiQuoteResponse.stub()
    let quoteRequest = LifiQuoteRequest.stub()
    let quoteResponse = try await trading.lifi.getQuote(request: quoteRequest)

    // Step 3: Get route step (transaction details)
    lifiMock.getRouteStepReturnValue = LifiStepTransactionResponse.stub()
    let stepRequest = LifiStep.stub()
    let stepResponse = try await trading.lifi.getRouteStep(request: stepRequest)

    // Step 4: Check status
    lifiMock.getStatusReturnValue = LifiStatusResponse.stub(
      data: LifiStatusData(rawResponse: LifiStatusRawResponse.stub(status: .done, substatus: .completed))
    )
    let statusRequest = LifiStatusRequest.stub()
    let statusResponse = try await trading.lifi.getStatus(request: statusRequest)

    // then
    XCTAssertEqual(routesResponse.data?.rawResponse.routes.count, 2)
    XCTAssertNotNil(quoteResponse.data)
    XCTAssertNotNil(stepResponse.data)
    XCTAssertEqual(statusResponse.data?.rawResponse.status, .done)
    XCTAssertEqual(statusResponse.data?.rawResponse.substatus, .completed)

    XCTAssertEqual(lifiMock.getRoutesCalls, 1)
    XCTAssertEqual(lifiMock.getQuoteCalls, 1)
    XCTAssertEqual(lifiMock.getRouteStepCalls, 1)
    XCTAssertEqual(lifiMock.getStatusCalls, 1)
  }

  func test_crossChainSwapFlow_withPendingStatus() async throws {
    // given
    let lifiMock = LifiMock()
    let trading = Trading(api: api)
    trading.lifi = lifiMock

    // Simulate status progression: pending -> done
    lifiMock.getStatusReturnValue = LifiStatusResponse.stub(
      data: LifiStatusData(rawResponse: LifiStatusRawResponse.stub(
        status: .pending,
        substatus: .waitDestinationTransaction,
        substatusMessage: "Waiting for destination chain transaction"
      ))
    )

    let statusRequest = LifiStatusRequest.stub()
    let pendingResponse = try await trading.lifi.getStatus(request: statusRequest)

    XCTAssertEqual(pendingResponse.data?.rawResponse.status, .pending)
    XCTAssertEqual(pendingResponse.data?.rawResponse.substatus, .waitDestinationTransaction)

    // Simulate completion
    lifiMock.getStatusReturnValue = LifiStatusResponse.stub(
      data: LifiStatusData(rawResponse: LifiStatusRawResponse.stub(status: .done, substatus: .completed))
    )

    let completedResponse = try await trading.lifi.getStatus(request: statusRequest)

    XCTAssertEqual(completedResponse.data?.rawResponse.status, .done)
    XCTAssertEqual(lifiMock.getStatusCalls, 2)
  }
}
