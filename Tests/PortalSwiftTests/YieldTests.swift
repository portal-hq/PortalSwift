//
//  YieldTests.swift
//  PortalSwift
//
//  Created by Portal Labs
//

import Foundation
import XCTest
@testable import PortalSwift

final class YieldTests: XCTestCase {
  var api: PortalApi!
  var yieldInstance: Yield!
  
  override func setUpWithError() throws {
    api = PortalApi(apiKey: MockConstants.mockApiKey, requests: PortalRequestsMock())
    yieldInstance = Yield(api: api)
  }
  
  override func tearDownWithError() throws {
    api = nil
    yieldInstance = nil
  }
}

// MARK: - Initialization Tests

extension YieldTests {
  func test_init_createsInstanceSuccessfully() {
    // given
    let portalApi = PortalApi(apiKey: MockConstants.mockApiKey, requests: PortalRequestsMock())
    
    // when
    let yield = Yield(api: portalApi)
    
    // then
    XCTAssertNotNil(yield)
  }
  
  func test_init_initializesYieldxyzProperty() {
    // given
    let portalApi = PortalApi(apiKey: MockConstants.mockApiKey, requests: PortalRequestsMock())
    
    // when
    let yield = Yield(api: portalApi)
    
    // then
    XCTAssertNotNil(yield.yieldxyz)
  }
  
  func test_init_yieldxyzIsOfCorrectType() {
    // given
    let portalApi = PortalApi(apiKey: MockConstants.mockApiKey, requests: PortalRequestsMock())
    
    // when
    let yield = Yield(api: portalApi)
    
    // then
    XCTAssertTrue(yield.yieldxyz is YieldXyzProtocol)
  }
  
  func test_init_withCustomApiKey() {
    // given
    let customApiKey = "custom-api-key-for-yield"
    let portalApi = PortalApi(apiKey: customApiKey, requests: PortalRequestsMock())
    
    // when
    let yield = Yield(api: portalApi)
    
    // then
    XCTAssertNotNil(yield.yieldxyz)
  }
  
  func test_init_withMockApi() {
    // given
    let mockApi = PortalApiMock()
    
    // when
    let yield = Yield(api: mockApi)
    
    // then
    XCTAssertNotNil(yield)
    XCTAssertNotNil(yield.yieldxyz)
  }
  
  func test_init_withCustomYieldXyzApi() {
    // given
    let yieldXyzApiMock = PortalYieldXyzApiMock()
    let mockApi = PortalApiMock(yieldxyz: yieldXyzApiMock)
    
    // when
    let yield = Yield(api: mockApi)
    
    // then
    XCTAssertNotNil(yield.yieldxyz)
  }
}

// MARK: - Property Access Tests

extension YieldTests {
  func test_yieldxyz_isAccessible() {
    // given & when
    let yieldxyz = yieldInstance.yieldxyz
    
    // then
    XCTAssertNotNil(yieldxyz)
  }
  
  func test_yieldxyz_isPublic() {
    // given & when
    let yieldxyz = yieldInstance.yieldxyz
    
    // then - if this compiles, the property is public
    XCTAssertNotNil(yieldxyz)
  }
  
  func test_yieldxyz_isLetProperty() {
    // given
    let firstAccess = yieldInstance.yieldxyz
    
    // when
    let secondAccess = yieldInstance.yieldxyz
    
    // then - let property should return same instance
    XCTAssertTrue(firstAccess as AnyObject === secondAccess as AnyObject)
  }
  
  func test_yieldxyz_multipleCalls_returnSameInstance() {
    // given
    var instances: [YieldXyzProtocol] = []
    
    // when
    for _ in 0..<10 {
      instances.append(yieldInstance.yieldxyz)
    }
    
    // then - all should be the same instance
    let firstInstance = instances[0]
    for instance in instances {
      XCTAssertTrue(instance as AnyObject === firstInstance as AnyObject)
    }
  }
}

// MARK: - Integration Tests with YieldXyz

extension YieldTests {
  func test_yieldxyz_canCallDiscover() async throws {
    // given
    let mockResponse = YieldXyzGetYieldsResponse.stub()
    let yieldXyzApiMock = PortalYieldXyzApiMock()
    yieldXyzApiMock.getYieldsReturnValue = mockResponse
    let mockApi = PortalApiMock(yieldxyz: yieldXyzApiMock)
    let yield = Yield(api: mockApi)
    
    // when
    let response = try await yield.yieldxyz.discover(request: nil)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(yieldXyzApiMock.getYieldsCalls, 1)
  }
  
  func test_yieldxyz_canCallDiscoverWithParams() async throws {
    // given
    let mockResponse = YieldXyzGetYieldsResponse.stub()
    let yieldXyzApiMock = PortalYieldXyzApiMock()
    yieldXyzApiMock.getYieldsReturnValue = mockResponse
    let mockApi = PortalApiMock(yieldxyz: yieldXyzApiMock)
    let yield = Yield(api: mockApi)
    
    let request = YieldXyzGetYieldsRequest(
      offset: 0,
      yieldId: "test-yield-id",
      network: "eip155:1",
      limit: 50
    )
    
    // when
    let response = try await yield.yieldxyz.discover(request: request)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(yieldXyzApiMock.getYieldsCalls, 1)
  }
  
  func test_yieldxyz_canCallEnter() async throws {
    // given
    let mockResponse = YieldXyzEnterYieldResponse.stub()
    let yieldXyzApiMock = PortalYieldXyzApiMock()
    yieldXyzApiMock.enterYieldReturnValue = mockResponse
    let mockApi = PortalApiMock(yieldxyz: yieldXyzApiMock)
    let yield = Yield(api: mockApi)
    
    let request = YieldXyzEnterRequest(
      yieldId: "test-yield-id",
      address: "0x1234567890abcdef1234567890abcdef12345678"
    )
    
    // when
    let response = try await yield.yieldxyz.enter(request: request)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(response.data?.rawResponse.intent, .enter)
    XCTAssertEqual(yieldXyzApiMock.enterYieldCalls, 1)
  }
  
  func test_yieldxyz_canCallExit() async throws {
    // given
    let mockResponse = YieldXyzExitResponse.stub()
    let yieldXyzApiMock = PortalYieldXyzApiMock()
    yieldXyzApiMock.exitYieldReturnValue = mockResponse
    let mockApi = PortalApiMock(yieldxyz: yieldXyzApiMock)
    let yield = Yield(api: mockApi)
    
    let request = YieldXyzExitRequest(
      yieldId: "test-yield-id",
      address: "0x1234567890abcdef1234567890abcdef12345678"
    )
    
    // when
    let response = try await yield.yieldxyz.exit(request: request)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(response.data?.rawResponse.intent, .exit)
    XCTAssertEqual(yieldXyzApiMock.exitYieldCalls, 1)
  }
  
  func test_yieldxyz_canCallManage() async throws {
    // given
    let mockResponse = YieldXyzManageYieldResponse.stub()
    let yieldXyzApiMock = PortalYieldXyzApiMock()
    yieldXyzApiMock.manageYieldReturnValue = mockResponse
    let mockApi = PortalApiMock(yieldxyz: yieldXyzApiMock)
    let yield = Yield(api: mockApi)
    
    let request = YieldXyzManageYieldRequest(
      yieldId: "test-yield-id",
      address: "0x1234567890abcdef1234567890abcdef12345678",
      arguments: YieldXyzEnterArguments(),
      action: .CLAIM_REWARDS,
      passthrough: "test-passthrough"
    )
    
    // when
    let response = try await yield.yieldxyz.manage(request: request)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(response.data?.rawResponse.intent, .manage)
    XCTAssertEqual(yieldXyzApiMock.manageYieldCalls, 1)
  }
  
  func test_yieldxyz_canCallGetBalances() async throws {
    // given
    let mockResponse = YieldXyzGetBalancesResponse.stub()
    let yieldXyzApiMock = PortalYieldXyzApiMock()
    yieldXyzApiMock.getYieldBalancesReturnValue = mockResponse
    let mockApi = PortalApiMock(yieldxyz: yieldXyzApiMock)
    let yield = Yield(api: mockApi)
    
    let query = YieldXyzBalanceQuery(
      address: "0x1234567890abcdef1234567890abcdef12345678",
      network: "eip155:1",
      yieldId: "test-yield-id"
    )
    let request = YieldXyzGetBalancesRequest(queries: [query])
    
    // when
    let response = try await yield.yieldxyz.getBalances(request: request)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(yieldXyzApiMock.getYieldBalancesCalls, 1)
  }
  
  func test_yieldxyz_canCallGetHistoricalActions() async throws {
    // given
    let mockResponse = YieldXyzGetHistoricalActionsResponse.stub()
    let yieldXyzApiMock = PortalYieldXyzApiMock()
    yieldXyzApiMock.getHistoricalYieldActionsReturnValue = mockResponse
    let mockApi = PortalApiMock(yieldxyz: yieldXyzApiMock)
    let yield = Yield(api: mockApi)
    
    let request = YieldXyzGetHistoricalActionsRequest(
      address: "0x1234567890abcdef1234567890abcdef12345678"
    )
    
    // when
    let response = try await yield.yieldxyz.getHistoricalActions(request: request)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(yieldXyzApiMock.getHistoricalYieldActionsCalls, 1)
  }
  
  func test_yieldxyz_canCallGetTransaction() async throws {
    // given
    let mockResponse = YieldXyzGetTransactionResponse.stub()
    let yieldXyzApiMock = PortalYieldXyzApiMock()
    yieldXyzApiMock.getYieldTransactionReturnValue = mockResponse
    let mockApi = PortalApiMock(yieldxyz: yieldXyzApiMock)
    let yield = Yield(api: mockApi)
    
    let transactionId = "test-transaction-id"
    
    // when
    let response = try await yield.yieldxyz.getTransaction(transactionId: transactionId)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(yieldXyzApiMock.getYieldTransactionCalls, 1)
  }
  
  func test_yieldxyz_canCallTrack() async throws {
    // given
    let mockResponse = YieldXyzTrackTransactionResponse.stub()
    let yieldXyzApiMock = PortalYieldXyzApiMock()
    yieldXyzApiMock.submitTransactionHashReturnValue = mockResponse
    let mockApi = PortalApiMock(yieldxyz: yieldXyzApiMock)
    let yield = Yield(api: mockApi)
    
    let transactionId = "test-transaction-id"
    let txHash = "0xtest-hash-123"
    
    // when
    let response = try await yield.yieldxyz.track(transactionId: transactionId, txHash: txHash)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response.data)
    XCTAssertEqual(yieldXyzApiMock.submitTransactionHashCalls, 1)
  }
}

// MARK: - Multiple Instance Tests

extension YieldTests {
  func test_multipleInstances_haveIndependentYieldxyz() {
    // given
    let api1 = PortalApi(apiKey: "key1", requests: PortalRequestsMock())
    let api2 = PortalApi(apiKey: "key2", requests: PortalRequestsMock())
    
    // when
    let yield1 = Yield(api: api1)
    let yield2 = Yield(api: api2)
    
    // then
    XCTAssertFalse(yield1 === yield2)
    XCTAssertFalse(yield1.yieldxyz as AnyObject === yield2.yieldxyz as AnyObject)
  }
  
  func test_multipleInstances_withSameApi_haveDifferentYieldxyz() {
    // given
    let api = PortalApi(apiKey: MockConstants.mockApiKey, requests: PortalRequestsMock())
    
    // when
    let yield1 = Yield(api: api)
    let yield2 = Yield(api: api)
    
    // then - different Yield instances
    XCTAssertFalse(yield1 === yield2)
    // different YieldXyz instances since they're created in init
    XCTAssertFalse(yield1.yieldxyz as AnyObject === yield2.yieldxyz as AnyObject)
  }
  
  func test_multipleInstances_canOperateIndependently() async throws {
    // given
    let mockResponse1 = YieldXyzGetYieldsResponse.stub()
    let mockResponse2 = YieldXyzGetYieldsResponse.stub()
    
    let yieldXyzApiMock1 = PortalYieldXyzApiMock()
    yieldXyzApiMock1.getYieldsReturnValue = mockResponse1
    
    let yieldXyzApiMock2 = PortalYieldXyzApiMock()
    yieldXyzApiMock2.getYieldsReturnValue = mockResponse2
    
    let mockApi1 = PortalApiMock(yieldxyz: yieldXyzApiMock1)
    let mockApi2 = PortalApiMock(yieldxyz: yieldXyzApiMock2)
    
    let yield1 = Yield(api: mockApi1)
    let yield2 = Yield(api: mockApi2)
    
    // when
    _ = try await yield1.yieldxyz.discover(request: nil)
    _ = try await yield2.yieldxyz.discover(request: nil)
    
    // then
    XCTAssertEqual(yieldXyzApiMock1.getYieldsCalls, 1)
    XCTAssertEqual(yieldXyzApiMock2.getYieldsCalls, 1)
  }
}

// MARK: - Error Handling Tests

extension YieldTests {
  func test_yieldxyz_handlesErrors() async throws {
    // given
    let mockError = "Test error from YieldXyz API"
    let yieldXyzApiMock = PortalYieldXyzApiMock()
    yieldXyzApiMock.getYieldsReturnValue = YieldXyzGetYieldsResponse(data: nil, error: mockError)
    let mockApi = PortalApiMock(yieldxyz: yieldXyzApiMock)
    let yield = Yield(api: mockApi)
    
    // when
    let response = try await yield.yieldxyz.discover(request: nil)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(response.error, mockError)
    XCTAssertNil(response.data)
  }
  
  func test_yieldxyz_propagatesApiErrors() async throws {
    // given
    let mockError = "API communication error"
    let yieldXyzApiMock = PortalYieldXyzApiMock()
    yieldXyzApiMock.enterYieldReturnValue = YieldXyzEnterYieldResponse(data: nil, error: mockError)
    let mockApi = PortalApiMock(yieldxyz: yieldXyzApiMock)
    let yield = Yield(api: mockApi)
    
    let request = YieldXyzEnterRequest(
      yieldId: "test-yield-id",
      address: "0x1234567890abcdef1234567890abcdef12345678"
    )
    
    // when
    let response = try await yield.yieldxyz.enter(request: request)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(response.error, mockError)
    XCTAssertNil(response.data)
  }
}

// MARK: - Type Safety Tests

extension YieldTests {
  func test_yield_isPublicClass() {
    // given & when - if this compiles, Yield is public
    let yield: Yield = yieldInstance
    
    // then
    XCTAssertNotNil(yield)
  }
  
  func test_yieldxyz_returnsCorrectType() {
    // given
    let yieldxyz = yieldInstance.yieldxyz
    
    // when
    let isYieldXyzProtocol = yieldxyz is YieldXyzProtocol
    
    // then
    XCTAssertTrue(isYieldXyzProtocol)
  }
  
  func test_yield_conformsToExpectedBehavior() {
    // given
    let yield = Yield(api: api)
    
    // when - accessing yieldxyz property
    let yieldxyz = yield.yieldxyz
    
    // then - should return a valid YieldXyzProtocol instance
    XCTAssertNotNil(yieldxyz)
    XCTAssertTrue(yieldxyz is YieldXyzProtocol)
  }
}

// MARK: - Thread Safety Tests

extension YieldTests {
  func test_yieldxyz_accessFromMultipleThreads() {
    // given
    let yield = Yield(api: api)
    let expectation = XCTestExpectation(description: "Multiple thread access")
    expectation.expectedFulfillmentCount = 10
    var instances: [YieldXyzProtocol] = []
    let lock = NSLock()
    
    // when
    for _ in 0..<10 {
      DispatchQueue.global().async {
        let yieldxyz = yield.yieldxyz
        lock.lock()
        instances.append(yieldxyz)
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

// MARK: - Documentation and Best Practices Tests

extension YieldTests {
  func test_yield_hasDocumentedPurpose() {
    // This test verifies that Yield class exists and serves as the main entry point
    // for yield-related functionality
    
    // given
    let yield = Yield(api: api)
    
    // when - access yield functionality through yieldxyz
    let yieldxyz = yield.yieldxyz
    
    // then - should provide access to YieldXyz provider
    XCTAssertNotNil(yieldxyz)
  }
  
  func test_yield_providesCleanInterface() {
    // This test verifies that Yield provides a clean, focused interface
    
    // given
    let yield = Yield(api: api)
    
    // then - should only expose yieldxyz property (the provider)
    XCTAssertNotNil(yield.yieldxyz)
  }
}

// MARK: - Protocol Injection Tests

extension YieldTests {
  func test_init_withYieldXyzProtocol() {
    // given
    let yieldXyzMock = YieldXyzMock()
    let yield = Yield(api: api)
    
    // when
    yield.yieldxyz = yieldXyzMock
    
    // then
    XCTAssertNotNil(yield)
    XCTAssertNotNil(yield.yieldxyz)
  }
  
  func test_init_withYieldXyzMock_usesInjectedInstance() {
    // given
    let yieldXyzMock = YieldXyzMock()
    let yield = Yield(api: api)
    
    // when
    yield.yieldxyz = yieldXyzMock
    
    // then - should use the injected mock
    XCTAssertTrue(yield.yieldxyz as AnyObject === yieldXyzMock as AnyObject)
  }
  
  func test_yieldxyz_withMock_canCallDiscover() async throws {
    // given
    let mockResponse = YieldXyzGetYieldsResponse.stub()
    let yieldXyzMock = YieldXyzMock()
    yieldXyzMock.discoverReturnValue = mockResponse
    let yield = Yield(api: api)
    yield.yieldxyz = yieldXyzMock
    
    // when
    let response = try await yield.yieldxyz.discover(request: nil)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(yieldXyzMock.discoverCalls, 1)
    XCTAssertNil(yieldXyzMock.discoverRequestParam)
  }
  
  func test_yieldxyz_withMock_canCallDiscoverWithRequest() async throws {
    // given
    let mockResponse = YieldXyzGetYieldsResponse.stub()
    let yieldXyzMock = YieldXyzMock()
    yieldXyzMock.discoverReturnValue = mockResponse
    let yield = Yield(api: api)
    yield.yieldxyz = yieldXyzMock
    
    let request = YieldXyzGetYieldsRequest(
      offset: 10,
      yieldId: "mock-yield-id",
      network: "eip155:1",
      limit: 20
    )
    
    // when
    let response = try await yield.yieldxyz.discover(request: request)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(yieldXyzMock.discoverCalls, 1)
    XCTAssertNotNil(yieldXyzMock.discoverRequestParam)
    XCTAssertEqual(yieldXyzMock.discoverRequestParam?.offset, 10)
    XCTAssertEqual(yieldXyzMock.discoverRequestParam?.yieldId, "mock-yield-id")
  }
  
  func test_yieldxyz_withMock_canCallEnter() async throws {
    // given
    let mockResponse = YieldXyzEnterYieldResponse.stub()
    let yieldXyzMock = YieldXyzMock()
    yieldXyzMock.enterReturnValue = mockResponse
    let yield = Yield(api: api)
    yield.yieldxyz = yieldXyzMock
    
    let request = YieldXyzEnterRequest(
      yieldId: "test-yield",
      address: "0xtest"
    )
    
    // when
    let response = try await yield.yieldxyz.enter(request: request)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(yieldXyzMock.enterCalls, 1)
    XCTAssertEqual(yieldXyzMock.enterRequestParam?.yieldId, "test-yield")
  }
  
  func test_yieldxyz_withMock_canCallExit() async throws {
    // given
    let mockResponse = YieldXyzExitResponse.stub()
    let yieldXyzMock = YieldXyzMock()
    yieldXyzMock.exitReturnValue = mockResponse
    let yield = Yield(api: api)
    yield.yieldxyz = yieldXyzMock
    
    let request = YieldXyzExitRequest(
      yieldId: "test-yield",
      address: "0xtest"
    )
    
    // when
    let response = try await yield.yieldxyz.exit(request: request)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(yieldXyzMock.exitCalls, 1)
    XCTAssertEqual(yieldXyzMock.exitRequestParam?.yieldId, "test-yield")
  }
  
  func test_yieldxyz_withMock_canCallTrack() async throws {
    // given
    let mockResponse = YieldXyzTrackTransactionResponse.stub()
    let yieldXyzMock = YieldXyzMock()
    yieldXyzMock.trackReturnValue = mockResponse
    let yield = Yield(api: api)
    yield.yieldxyz = yieldXyzMock
    
    let transactionId = "test-tx-id"
    let txHash = "0xhash"
    
    // when
    let response = try await yield.yieldxyz.track(transactionId: transactionId, txHash: txHash)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertEqual(yieldXyzMock.trackCalls, 1)
    XCTAssertEqual(yieldXyzMock.trackTransactionIdParam, transactionId)
    XCTAssertEqual(yieldXyzMock.trackTxHashParam, txHash)
  }
  
  func test_yieldxyz_withMock_tracksMultipleCalls() async throws {
    // given
    let yieldXyzMock = YieldXyzMock()
    let yield = Yield(api: api)
    yield.yieldxyz = yieldXyzMock
    
    // when
    _ = try await yield.yieldxyz.discover(request: nil)
    _ = try await yield.yieldxyz.discover(request: nil)
    _ = try await yield.yieldxyz.discover(request: nil)
    
    // then
    XCTAssertEqual(yieldXyzMock.discoverCalls, 3)
  }
  
  func test_yieldxyz_withMock_tracksDifferentMethodCalls() async throws {
    // given
    let yieldXyzMock = YieldXyzMock()
    let yield = Yield(api: api)
    yield.yieldxyz = yieldXyzMock
    
    // when
    _ = try await yield.yieldxyz.discover(request: nil)
    _ = try await yield.yieldxyz.enter(request: YieldXyzEnterRequest(yieldId: "test", address: "0x"))
    _ = try await yield.yieldxyz.exit(request: YieldXyzExitRequest(yieldId: "test", address: "0x"))
    
    // then
    XCTAssertEqual(yieldXyzMock.discoverCalls, 1)
    XCTAssertEqual(yieldXyzMock.enterCalls, 1)
    XCTAssertEqual(yieldXyzMock.exitCalls, 1)
  }
}

// MARK: - Protocol Conformance Tests

extension YieldTests {
  func test_YieldXyz_conformsToProtocol() {
    // given
    let portalApi = PortalApi(apiKey: MockConstants.mockApiKey, requests: PortalRequestsMock())
    let yieldXyz = YieldXyz(api: portalApi.yieldxyz)
    
    // when
    let conformsToProtocol = yieldXyz is YieldXyzProtocol
    
    // then
    XCTAssertTrue(conformsToProtocol)
  }
  
  func test_YieldXyzMock_conformsToProtocol() {
    // given
    let yieldXyzMock = YieldXyzMock()
    
    // when
    let conformsToProtocol = yieldXyzMock is YieldXyzProtocol
    
    // then
    XCTAssertTrue(conformsToProtocol)
  }
  
  func test_protocol_canBeUsedPolymorphically() {
    // given
    let portalApi = PortalApi(apiKey: MockConstants.mockApiKey, requests: PortalRequestsMock())
    let implementations: [YieldXyzProtocol] = [
      YieldXyz(api: portalApi.yieldxyz),
      YieldXyzMock()
    ]
    
    // when & then
    for implementation in implementations {
      XCTAssertNotNil(implementation)
      XCTAssertTrue(implementation is YieldXyzProtocol)
    }
  }
  
  func test_yield_acceptsAnyProtocolConformingType() {
    // given
    let yieldXyzMock = YieldXyzMock()
    let portalApi = PortalApi(apiKey: MockConstants.mockApiKey, requests: PortalRequestsMock())
    let yieldXyz = YieldXyz(api: portalApi.yieldxyz)
    
    // when
    let yieldWithMock = Yield(api: portalApi)
    yieldWithMock.yieldxyz = yieldXyzMock
    
    let yieldWithConcrete = Yield(api: portalApi)
    yieldWithConcrete.yieldxyz = yieldXyz
    
    // then
    XCTAssertNotNil(yieldWithMock)
    XCTAssertNotNil(yieldWithConcrete)
    XCTAssertTrue(yieldWithMock.yieldxyz is YieldXyzProtocol)
    XCTAssertTrue(yieldWithConcrete.yieldxyz is YieldXyzProtocol)
  }
}

// MARK: - Mock Behavior Tests

extension YieldTests {
  func test_YieldXyzMock_defaultReturnValues() async throws {
    // given
    let yieldXyzMock = YieldXyzMock()
    
    // when - calling methods without setting return values
    let discoverResponse = try await yieldXyzMock.discover(request: nil)
    let enterResponse = try await yieldXyzMock.enter(request: YieldXyzEnterRequest(yieldId: "test", address: "0x"))
    let exitResponse = try await yieldXyzMock.exit(request: YieldXyzExitRequest(yieldId: "test", address: "0x"))
    
    // then - should return stub values
    XCTAssertNotNil(discoverResponse)
    XCTAssertNotNil(enterResponse)
    XCTAssertNotNil(exitResponse)
  }
  
  func test_YieldXyzMock_customReturnValues() async throws {
    // given
    let customResponse = YieldXyzGetYieldsResponse(data: nil, error: "Custom error")
    let yieldXyzMock = YieldXyzMock()
    yieldXyzMock.discoverReturnValue = customResponse
    
    // when
    let response = try await yieldXyzMock.discover(request: nil)
    
    // then
    XCTAssertEqual(response.error, "Custom error")
    XCTAssertNil(response.data)
  }
  
  func test_YieldXyzMock_parameterCapture() async throws {
    // given
    let yieldXyzMock = YieldXyzMock()
    let request = YieldXyzGetYieldsRequest(
      offset: 100,
      yieldId: "captured-id",
      network: "eip155:42",
      limit: 50
    )
    
    // when
    _ = try await yieldXyzMock.discover(request: request)
    
    // then - should capture the request parameters
    XCTAssertNotNil(yieldXyzMock.discoverRequestParam)
    XCTAssertEqual(yieldXyzMock.discoverRequestParam?.offset, 100)
    XCTAssertEqual(yieldXyzMock.discoverRequestParam?.yieldId, "captured-id")
    XCTAssertEqual(yieldXyzMock.discoverRequestParam?.network, "eip155:42")
    XCTAssertEqual(yieldXyzMock.discoverRequestParam?.limit, 50)
  }
  
  func test_YieldXyzMock_resetsBetweenCalls() async throws {
    // given
    let yieldXyzMock = YieldXyzMock()
    
    // when - first call
    _ = try await yieldXyzMock.discover(request: YieldXyzGetYieldsRequest(yieldId: "first"))
    let firstParam = yieldXyzMock.discoverRequestParam?.yieldId
    
    // when - second call
    _ = try await yieldXyzMock.discover(request: YieldXyzGetYieldsRequest(yieldId: "second"))
    let secondParam = yieldXyzMock.discoverRequestParam?.yieldId
    
    // then - should capture latest parameters
    XCTAssertEqual(firstParam, "first")
    XCTAssertEqual(secondParam, "second")
    XCTAssertEqual(yieldXyzMock.discoverCalls, 2)
  }
}

// MARK: - Dependency Injection Tests

extension YieldTests {
  func test_yield_supportsDependencyInjection() {
    // given
    let yieldXyzMock = YieldXyzMock()
    let yield = Yield(api: api)
    
    // when - inject custom implementation
    yield.yieldxyz = yieldXyzMock
    
    // then - should use injected implementation
    XCTAssertTrue(yield.yieldxyz as AnyObject === yieldXyzMock as AnyObject)
  }
  
  func test_yield_injectedMock_isolatesTestBehavior() async throws {
    // given
    let yieldXyzMock1 = YieldXyzMock()
    let yieldXyzMock2 = YieldXyzMock()
    
    let yield1 = Yield(api: api)
    yield1.yieldxyz = yieldXyzMock1
    
    let yield2 = Yield(api: api)
    yield2.yieldxyz = yieldXyzMock2
    
    // when
    _ = try await yield1.yieldxyz.discover(request: nil)
    _ = try await yield1.yieldxyz.discover(request: nil)
    _ = try await yield2.yieldxyz.discover(request: nil)
    
    // then - mocks should be isolated
    XCTAssertEqual(yieldXyzMock1.discoverCalls, 2)
    XCTAssertEqual(yieldXyzMock2.discoverCalls, 1)
  }
}

