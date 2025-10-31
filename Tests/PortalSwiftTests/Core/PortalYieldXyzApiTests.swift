//
//  PortalYieldXyzApiTests.swift
//  PortalSwift_Tests
//
//  Created by Ahmed Ragab on 30/10/2025.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import AnyCodable
@testable import PortalSwift
import XCTest

final class PortalYieldXyzApiTests: XCTestCase {
  private let encoder = JSONEncoder()
  
  var api: PortalYieldXyzApi?
  
  override func setUpWithError() throws {
    self.api = PortalYieldXyzApi(
      apiKey: MockConstants.mockApiKey,
      apiHost: MockConstants.mockHost,
      requests: PortalRequestsMock()
    )
  }
  
  override func tearDownWithError() throws {
    api = nil
  }
}

// MARK: - Test Helpers

extension PortalYieldXyzApiTests {
  func initPortalYieldXyzApiWith(
    apiKey: String = MockConstants.mockApiKey,
    apiHost: String = MockConstants.mockHost,
    requests: PortalRequestsProtocol = PortalRequestsMock()
  ) {
    self.api = PortalYieldXyzApi(
      apiKey: apiKey,
      apiHost: apiHost,
      requests: requests
    )
  }
}

// MARK: - getYields tests

extension PortalYieldXyzApiTests {
  func test_getYields_willReturnCorrectResponse() async throws {
    // given
    let mockResponse = YieldXyzGetYieldsResponse.stub()
    let encodedResponse = try encoder.encode(mockResponse)
    let portalRequestMock = PortalRequestsMock()
    portalRequestMock.returnValueData = encodedResponse
    initPortalYieldXyzApiWith(requests: portalRequestMock)
    
    // when
    let response = try await api?.getYields(request: YieldXyzGetYieldsRequest())
    
    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response?.data)
    XCTAssertEqual(response?.data?.rawResponse.total, 1)
  }
  
  func test_getYields_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzGetYieldsResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    // when
    _ = try await api?.getYields(request: YieldXyzGetYieldsRequest())
    
    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
  }
  
  @available(iOS 16.0, *)
  func test_getYields_willCall_executeRequest_passingCorrectUrlAndMethod() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzGetYieldsResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    // when
    _ = try await api?.getYields(request: YieldXyzGetYieldsRequest())
    
    // then
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .get)
    XCTAssertTrue(portalRequestsSpy.executeRequestParam?.url.path().contains("/api/v3/clients/me/integrations/yield-xyz/yields") ?? false)
  }
  
  @available(iOS 16.0, *)
  func test_getYields_willCall_executeRequest_passingCorrectQueryParams() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzGetYieldsResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let request = YieldXyzGetYieldsRequest(
      offset: 10,
      yieldId: "yield-1",
      network: "eip155:1",
      limit: 20,
      type: .staking,
      sort: .statusEnterAsc
    )
    
    // when
    _ = try await api?.getYields(request: request)
    
    // then
    let query = portalRequestsSpy.executeRequestParam?.url.query()
    XCTAssertTrue(query?.contains("offset=10") ?? false)
    XCTAssertTrue(query?.contains("limit=20") ?? false)
    XCTAssertTrue(query?.contains("network=eip155:1") ?? false)
    XCTAssertTrue(query?.contains("yieldId=yield-1") ?? false)
    XCTAssertTrue(query?.contains("type=staking") ?? false)
    XCTAssertTrue(query?.contains("sort=statusEnterAsc") ?? false)
  }
  
  func test_getYields_willThrowCorrectError_whenExecuteRequestThrowsError() async throws {
    // given
    let portalRequestsFailMock = PortalRequestsFailMock()
    initPortalYieldXyzApiWith(requests: portalRequestsFailMock)
    
    do {
      // when
      _ = try await api?.getYields(request: YieldXyzGetYieldsRequest())
      XCTFail("Expected error not thrown when calling PortalYieldXyzApi.getYields when Request throws error.")
    } catch {
      // then
      XCTAssertEqual(error as? URLError, portalRequestsFailMock.errorToThrow)
    }
  }
  
  func test_getYields_withAllQueryParams() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzGetYieldsResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let request = YieldXyzGetYieldsRequest(
      offset: 0,
      yieldId: "test-yield",
      network: "eip155:1",
      limit: 50,
      type: .lending,
      hasCooldownPeriod: true,
      hasWarmupPeriod: false,
      token: "ETH",
      inputToken: "USDC",
      provider: "provider-1",
      search: "ethereum",
      sort: .statusExitDesc
    )
    
    // when
    let response = try await api?.getYields(request: request)
    
    // then
    XCTAssertNotNil(response)
  }
}

// MARK: - enterYield tests

extension PortalYieldXyzApiTests {
  func test_enterYield_willReturnCorrectResponse() async throws {
    // given
    let mockResponse = YieldXyzEnterYieldResponse.stub()
    let encodedResponse = try encoder.encode(mockResponse)
    let portalRequestMock = PortalRequestsMock()
    portalRequestMock.returnValueData = encodedResponse
    initPortalYieldXyzApiWith(requests: portalRequestMock)
    
    let request = YieldXyzEnterRequest(
      yieldId: "yield-1",
      address: "0x1234567890abcdef1234567890abcdef12345678"
    )
    
    // when
    let response = try await api?.enterYield(request: request)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response?.data)
    XCTAssertEqual(response?.data?.rawResponse.intent, .enter)
  }
  
  func test_enterYield_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzEnterYieldResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let request = YieldXyzEnterRequest(
      yieldId: "yield-1",
      address: "0x1234567890abcdef1234567890abcdef12345678"
    )
    
    // when
    _ = try await api?.enterYield(request: request)
    
    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
  }
  
  @available(iOS 16.0, *)
  func test_enterYield_willCall_executeRequest_passingCorrectUrlAndMethod() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzEnterYieldResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let request = YieldXyzEnterRequest(
      yieldId: "yield-1",
      address: "0x1234567890abcdef1234567890abcdef12345678"
    )
    
    // when
    _ = try await api?.enterYield(request: request)
    
    // then
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .post)
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path(), "/api/v3/clients/me/integrations/yield-xyz/actions/enter")
  }
  
  func test_enterYield_willThrowCorrectError_whenExecuteRequestThrowsError() async throws {
    // given
    let portalRequestsFailMock = PortalRequestsFailMock()
    initPortalYieldXyzApiWith(requests: portalRequestsFailMock)
    
    let request = YieldXyzEnterRequest(
      yieldId: "yield-1",
      address: "0x1234567890abcdef1234567890abcdef12345678"
    )
    
    do {
      // when
      _ = try await api?.enterYield(request: request)
      XCTFail("Expected error not thrown when calling PortalYieldXyzApi.enterYield when Request throws error.")
    } catch {
      // then
      XCTAssertEqual(error as? URLError, portalRequestsFailMock.errorToThrow)
    }
  }
  
  func test_enterYield_withArguments() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzEnterYieldResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let arguments = YieldXyzEnterArguments(
      amount: "1.0",
      validatorAddress: "0xvalidator",
      providerId: "provider-1"
    )
    
    let request = YieldXyzEnterRequest(
      yieldId: "yield-1",
      address: "0x1234567890abcdef1234567890abcdef12345678",
      arguments: arguments
    )
    
    // when
    let response = try await api?.enterYield(request: request)
    
    // then
    XCTAssertNotNil(response)
      XCTAssertEqual(response?.data?.rawResponse.rawArguments?.amount, YieldXyzEnterYieldResponse.stub().data?.rawResponse.rawArguments?.amount)
  }
}

// MARK: - exitYield tests

extension PortalYieldXyzApiTests {
  func test_exitYield_willReturnCorrectResponse() async throws {
    // given
    let mockResponse = YieldXyzExitResponse.stub()
    let encodedResponse = try encoder.encode(mockResponse)
    let portalRequestMock = PortalRequestsMock()
    portalRequestMock.returnValueData = encodedResponse
    initPortalYieldXyzApiWith(requests: portalRequestMock)
    
    let request = YieldXyzExitRequest(
      yieldId: "yield-1",
      address: "0x1234567890abcdef1234567890abcdef12345678"
    )
    
    // when
    let response = try await api?.exitYield(request: request)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response?.data)
    XCTAssertEqual(response?.data?.rawResponse.intent, .exit)
  }
  
  func test_exitYield_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzExitResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let request = YieldXyzExitRequest(
      yieldId: "yield-1",
      address: "0x1234567890abcdef1234567890abcdef12345678"
    )
    
    // when
    _ = try await api?.exitYield(request: request)
    
    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
  }
  
  @available(iOS 16.0, *)
  func test_exitYield_willCall_executeRequest_passingCorrectUrlAndMethod() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzExitResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let request = YieldXyzExitRequest(
      yieldId: "yield-1",
      address: "0x1234567890abcdef1234567890abcdef12345678"
    )
    
    // when
    _ = try await api?.exitYield(request: request)
    
    // then
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .post)
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path(), "/api/v3/clients/me/integrations/yield-xyz/actions/exit")
  }
  
  func test_exitYield_willThrowCorrectError_whenExecuteRequestThrowsError() async throws {
    // given
    let portalRequestsFailMock = PortalRequestsFailMock()
    initPortalYieldXyzApiWith(requests: portalRequestsFailMock)
    
    let request = YieldXyzExitRequest(
      yieldId: "yield-1",
      address: "0x1234567890abcdef1234567890abcdef12345678"
    )
    
    do {
      // when
      _ = try await api?.exitYield(request: request)
      XCTFail("Expected error not thrown when calling PortalYieldXyzApi.exitYield when Request throws error.")
    } catch {
      // then
      XCTAssertEqual(error as? URLError, portalRequestsFailMock.errorToThrow)
    }
  }
  
  func test_exitYield_withArguments() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzExitResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let arguments = YieldXyzEnterArguments(
      amount: "0.5",
      validatorAddress: "0xvalidator"
    )
    
    let request = YieldXyzExitRequest(
      yieldId: "yield-1",
      address: "0x1234567890abcdef1234567890abcdef12345678",
      arguments: arguments
    )
    
    // when
    let response = try await api?.exitYield(request: request)
    
    // then
    XCTAssertNotNil(response)
  }
}

// MARK: - manageYield tests

extension PortalYieldXyzApiTests {
  func test_manageYield_willReturnCorrectResponse() async throws {
    // given
    let mockResponse = YieldXyzManageYieldResponse.stub()
    let encodedResponse = try encoder.encode(mockResponse)
    let portalRequestMock = PortalRequestsMock()
    portalRequestMock.returnValueData = encodedResponse
    initPortalYieldXyzApiWith(requests: portalRequestMock)
    
    let request = YieldXyzManageYieldRequest(
      yieldId: "yield-1",
      address: "0x1234567890abcdef1234567890abcdef12345678",
      arguments: YieldXyzEnterArguments(),
      action: .CLAIM_REWARDS,
      passthrough: "passthrough-data"
    )
    
    // when
    let response = try await api?.manageYield(request: request)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response?.data)
    XCTAssertEqual(response?.data?.rawResponse.intent, .manage)
  }
  
  func test_manageYield_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzManageYieldResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let request = YieldXyzManageYieldRequest(
      yieldId: "yield-1",
      address: "0x1234567890abcdef1234567890abcdef12345678",
      arguments: YieldXyzEnterArguments(),
      action: .CLAIM_REWARDS,
      passthrough: "passthrough-data"
    )
    
    // when
    _ = try await api?.manageYield(request: request)
    
    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
  }
  
  @available(iOS 16.0, *)
  func test_manageYield_willCall_executeRequest_passingCorrectUrlAndMethod() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzManageYieldResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let request = YieldXyzManageYieldRequest(
      yieldId: "yield-1",
      address: "0x1234567890abcdef1234567890abcdef12345678",
      arguments: YieldXyzEnterArguments(),
      action: .CLAIM_REWARDS,
      passthrough: "passthrough-data"
    )
    
    // when
    _ = try await api?.manageYield(request: request)
    
    // then
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .post)
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path(), "/api/v3/clients/me/integrations/yield-xyz/actions/manage")
  }
  
  func test_manageYield_willThrowCorrectError_whenExecuteRequestThrowsError() async throws {
    // given
    let portalRequestsFailMock = PortalRequestsFailMock()
    initPortalYieldXyzApiWith(requests: portalRequestsFailMock)
    
    let request = YieldXyzManageYieldRequest(
      yieldId: "yield-1",
      address: "0x1234567890abcdef1234567890abcdef12345678",
      arguments: YieldXyzEnterArguments(),
      action: .CLAIM_REWARDS,
      passthrough: "passthrough-data"
    )
    
    do {
      // when
      _ = try await api?.manageYield(request: request)
      XCTFail("Expected error not thrown when calling PortalYieldXyzApi.manageYield when Request throws error.")
    } catch {
      // then
      XCTAssertEqual(error as? URLError, portalRequestsFailMock.errorToThrow)
    }
  }
  
  func test_manageYield_withDifferentActionTypes() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzManageYieldResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let actionTypes: [YieldXyzActionType] = [
      .CLAIM_REWARDS,
      .RESTAKE_REWARDS,
      .REBOND,
      .MIGRATE
    ]
    
    for actionType in actionTypes {
      let request = YieldXyzManageYieldRequest(
        yieldId: "yield-1",
        address: "0x1234567890abcdef1234567890abcdef12345678",
        arguments: YieldXyzEnterArguments(),
        action: actionType,
        passthrough: "passthrough-data"
      )
      
      // when
      let response = try await api?.manageYield(request: request)
      
      // then
      XCTAssertNotNil(response)
    }
  }
}

// MARK: - getYieldBalances tests

extension PortalYieldXyzApiTests {
  func test_getYieldBalances_willReturnCorrectResponse() async throws {
    // given
    let mockResponse = YieldXyzGetBalancesResponse.stub()
    let encodedResponse = try encoder.encode(mockResponse)
    let portalRequestMock = PortalRequestsMock()
    portalRequestMock.returnValueData = encodedResponse
    initPortalYieldXyzApiWith(requests: portalRequestMock)
    
    let query = YieldXyzBalanceQuery(
      address: "0x1234567890abcdef1234567890abcdef12345678",
      network: "eip155:1",
      yieldId: "yield-1"
    )
    let request = YieldXyzGetBalancesRequest(queries: [query])
    
    // when
    let response = try await api?.getYieldBalances(request: request)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response?.data)
    XCTAssertTrue(response?.data?.rawResponse.items.count ?? 0 > 0)
  }
  
  func test_getYieldBalances_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzGetBalancesResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let query = YieldXyzBalanceQuery(
      address: "0x1234567890abcdef1234567890abcdef12345678",
      network: "eip155:1"
    )
    let request = YieldXyzGetBalancesRequest(queries: [query])
    
    // when
    _ = try await api?.getYieldBalances(request: request)
    
    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
  }
  
  @available(iOS 16.0, *)
  func test_getYieldBalances_willCall_executeRequest_passingCorrectUrlAndMethod() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzGetBalancesResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let query = YieldXyzBalanceQuery(
      address: "0x1234567890abcdef1234567890abcdef12345678",
      network: "eip155:1"
    )
    let request = YieldXyzGetBalancesRequest(queries: [query])
    
    // when
    _ = try await api?.getYieldBalances(request: request)
    
    // then
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .post)
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path(), "/api/v3/clients/me/integrations/yield-xyz/yields/balances")
  }
  
  func test_getYieldBalances_willThrowCorrectError_whenExecuteRequestThrowsError() async throws {
    // given
    let portalRequestsFailMock = PortalRequestsFailMock()
    initPortalYieldXyzApiWith(requests: portalRequestsFailMock)
    
    let query = YieldXyzBalanceQuery(
      address: "0x1234567890abcdef1234567890abcdef12345678",
      network: "eip155:1"
    )
    let request = YieldXyzGetBalancesRequest(queries: [query])
    
    do {
      // when
      _ = try await api?.getYieldBalances(request: request)
      XCTFail("Expected error not thrown when calling PortalYieldXyzApi.getYieldBalances when Request throws error.")
    } catch {
      // then
      XCTAssertEqual(error as? URLError, portalRequestsFailMock.errorToThrow)
    }
  }
  
  func test_getYieldBalances_withMultipleQueries() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzGetBalancesResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let queries = [
      YieldXyzBalanceQuery(address: "0xaddress1", network: "eip155:1", yieldId: "yield-1"),
      YieldXyzBalanceQuery(address: "0xaddress2", network: "eip155:137", yieldId: "yield-2"),
      YieldXyzBalanceQuery(address: "0xaddress3", network: "eip155:42161")
    ]
    let request = YieldXyzGetBalancesRequest(queries: queries)
    
    // when
    let response = try await api?.getYieldBalances(request: request)
    
    // then
    XCTAssertNotNil(response)
  }
}

// MARK: - getHistoricalYieldActions tests

extension PortalYieldXyzApiTests {
  func test_getHistoricalYieldActions_willReturnCorrectResponse() async throws {
    // given
    let mockResponse = YieldXyzGetHistoricalActionsResponse.stub()
    let encodedResponse = try encoder.encode(mockResponse)
    let portalRequestMock = PortalRequestsMock()
    portalRequestMock.returnValueData = encodedResponse
    initPortalYieldXyzApiWith(requests: portalRequestMock)
    
    let request = YieldXyzGetHistoricalActionsRequest(
      address: "0x1234567890abcdef1234567890abcdef12345678"
    )
    
    // when
    let response = try await api?.getHistoricalYieldActions(request: request)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response?.data)
    XCTAssertTrue(response?.data?.rawResponse.items.count ?? 0 > 0)
  }
  
  func test_getHistoricalYieldActions_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzGetHistoricalActionsResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let request = YieldXyzGetHistoricalActionsRequest()
    
    // when
    _ = try await api?.getHistoricalYieldActions(request: request)
    
    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
  }
  
  @available(iOS 16.0, *)
  func test_getHistoricalYieldActions_willCall_executeRequest_passingCorrectUrlAndMethod() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzGetHistoricalActionsResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let request = YieldXyzGetHistoricalActionsRequest()
    
    // when
    _ = try await api?.getHistoricalYieldActions(request: request)
    
    // then
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .get)
    XCTAssertTrue(portalRequestsSpy.executeRequestParam?.url.path().contains("/api/v3/clients/me/integrations/yield-xyz/actions") ?? false)
  }
  
  @available(iOS 16.0, *)
  func test_getHistoricalYieldActions_willCall_executeRequest_passingCorrectQueryParams() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzGetHistoricalActionsResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let request = YieldXyzGetHistoricalActionsRequest(
      offset: 5,
      limit: 15,
      address: "0x1234567890abcdef1234567890abcdef12345678",
      status: .SUCCESS,
      intent: .enter,
      type: .STAKE,
      yieldId: "yield-1"
    )
    
    // when
    _ = try await api?.getHistoricalYieldActions(request: request)
    
    // then
    let query = portalRequestsSpy.executeRequestParam?.url.query()
    XCTAssertTrue(query?.contains("offset=5") ?? false)
    XCTAssertTrue(query?.contains("limit=15") ?? false)
    XCTAssertTrue(query?.contains("address=0x1234567890abcdef1234567890abcdef12345678") ?? false)
    XCTAssertTrue(query?.contains("status=SUCCESS") ?? false)
    XCTAssertTrue(query?.contains("intent=enter") ?? false)
    XCTAssertTrue(query?.contains("type=STAKE") ?? false)
    XCTAssertTrue(query?.contains("yieldId=yield-1") ?? false)
  }
  
  func test_getHistoricalYieldActions_willThrowCorrectError_whenExecuteRequestThrowsError() async throws {
    // given
    let portalRequestsFailMock = PortalRequestsFailMock()
    initPortalYieldXyzApiWith(requests: portalRequestsFailMock)
    
    let request = YieldXyzGetHistoricalActionsRequest()
    
    do {
      // when
      _ = try await api?.getHistoricalYieldActions(request: request)
      XCTFail("Expected error not thrown when calling PortalYieldXyzApi.getHistoricalYieldActions when Request throws error.")
    } catch {
      // then
      XCTAssertEqual(error as? URLError, portalRequestsFailMock.errorToThrow)
    }
  }
  
  func test_getHistoricalYieldActions_withDifferentStatuses() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzGetHistoricalActionsResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let statuses: [YieldXyzActionStatus] = [.CREATED, .PROCESSING, .SUCCESS, .FAILED, .CANCELED]
    
    for status in statuses {
      let request = YieldXyzGetHistoricalActionsRequest(status: status)
      
      // when
      let response = try await api?.getHistoricalYieldActions(request: request)
      
      // then
      XCTAssertNotNil(response)
    }
  }
  
  func test_getHistoricalYieldActions_withDifferentIntents() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzGetHistoricalActionsResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let intents: [YieldXyzActionIntent] = [.enter, .exit, .manage]
    
    for intent in intents {
      let request = YieldXyzGetHistoricalActionsRequest(intent: intent)
      
      // when
      let response = try await api?.getHistoricalYieldActions(request: request)
      
      // then
      XCTAssertNotNil(response)
    }
  }
}

// MARK: - getYieldTransaction tests

extension PortalYieldXyzApiTests {
  func test_getYieldTransaction_willReturnCorrectResponse() async throws {
    // given
    let mockResponse = YieldXyzGetTransactionResponse.stub()
    let encodedResponse = try encoder.encode(mockResponse)
    let portalRequestMock = PortalRequestsMock()
    portalRequestMock.returnValueData = encodedResponse
    initPortalYieldXyzApiWith(requests: portalRequestMock)
    
    let transactionId = "tx-123"
    
    // when
    let response = try await api?.getYieldTransaction(transactionId: transactionId)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response?.data)
    XCTAssertEqual(response?.data?.rawResponse.id, "tx-1")
  }
  
  func test_getYieldTransaction_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzGetTransactionResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let transactionId = "tx-123"
    
    // when
    _ = try await api?.getYieldTransaction(transactionId: transactionId)
    
    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
  }
  
  @available(iOS 16.0, *)
  func test_getYieldTransaction_willCall_executeRequest_passingCorrectUrlAndMethod() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzGetTransactionResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let transactionId = "tx-123"
    
    // when
    _ = try await api?.getYieldTransaction(transactionId: transactionId)
    
    // then
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .get)
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path(), "/api/v3/clients/me/integrations/yield-xyz/transactions/\(transactionId)")
  }
  
  func test_getYieldTransaction_willThrowCorrectError_whenExecuteRequestThrowsError() async throws {
    // given
    let portalRequestsFailMock = PortalRequestsFailMock()
    initPortalYieldXyzApiWith(requests: portalRequestsFailMock)
    
    let transactionId = "tx-123"
    
    do {
      // when
      _ = try await api?.getYieldTransaction(transactionId: transactionId)
      XCTFail("Expected error not thrown when calling PortalYieldXyzApi.getYieldTransaction when Request throws error.")
    } catch {
      // then
      XCTAssertEqual(error as? URLError, portalRequestsFailMock.errorToThrow)
    }
  }
  
  func test_getYieldTransaction_withDifferentTransactionIds() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzGetTransactionResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let transactionIds = ["tx-1", "tx-abc", "transaction-12345", "0x123"]
    
    for transactionId in transactionIds {
      // when
      let response = try await api?.getYieldTransaction(transactionId: transactionId)
      
      // then
      XCTAssertNotNil(response)
    }
  }
}

// MARK: - submitTransactionHash tests

extension PortalYieldXyzApiTests {
  func test_submitTransactionHash_willReturnCorrectResponse() async throws {
    // given
    let mockResponse = YieldXyzTrackTransactionResponse.stub()
    let encodedResponse = try encoder.encode(mockResponse)
    let portalRequestMock = PortalRequestsMock()
    portalRequestMock.returnValueData = encodedResponse
    initPortalYieldXyzApiWith(requests: portalRequestMock)
    
    let request = YieldXyzTrackTransactionRequest(
      transactionId: "tx-123",
      hash: "0xhash123"
    )
    
    // when
    let response = try await api?.submitTransactionHash(request: request)
    
    // then
    XCTAssertNotNil(response)
    XCTAssertNotNil(response?.data)
    XCTAssertEqual(response?.data?.rawResponse.status, .BROADCASTED)
  }
  
  func test_submitTransactionHash_willCall_executeRequest_onlyOnce() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzTrackTransactionResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let request = YieldXyzTrackTransactionRequest(
      transactionId: "tx-123",
      hash: "0xhash123"
    )
    
    // when
    _ = try await api?.submitTransactionHash(request: request)
    
    // then
    XCTAssertEqual(portalRequestsSpy.executeCallsCount, 1)
  }
  
  @available(iOS 16.0, *)
  func test_submitTransactionHash_willCall_executeRequest_passingCorrectUrlAndMethod() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzTrackTransactionResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let request = YieldXyzTrackTransactionRequest(
      transactionId: "tx-123",
      hash: "0xhash123"
    )
    
    // when
    _ = try await api?.submitTransactionHash(request: request)
    
    // then
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.method, .put)
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.url.path(), "/api/v3/clients/me/integrations/yield-xyz/transactions/\(request.transactionId)/submit-hash")
  }
  
  func test_submitTransactionHash_willThrowCorrectError_whenExecuteRequestThrowsError() async throws {
    // given
    let portalRequestsFailMock = PortalRequestsFailMock()
    initPortalYieldXyzApiWith(requests: portalRequestsFailMock)
    
    let request = YieldXyzTrackTransactionRequest(
      transactionId: "tx-123",
      hash: "0xhash123"
    )
    
    do {
      // when
      _ = try await api?.submitTransactionHash(request: request)
      XCTFail("Expected error not thrown when calling PortalYieldXyzApi.submitTransactionHash when Request throws error.")
    } catch {
      // then
      XCTAssertEqual(error as? URLError, portalRequestsFailMock.errorToThrow)
    }
  }
  
  func test_submitTransactionHash_withDifferentHashFormats() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzTrackTransactionResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let hashes = [
      "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
      "0xabc123",
      "hash-without-prefix"
    ]
    
    for hash in hashes {
      let request = YieldXyzTrackTransactionRequest(
        transactionId: "tx-123",
        hash: hash
      )
      
      // when
      let response = try await api?.submitTransactionHash(request: request)
      
      // then
      XCTAssertNotNil(response)
    }
  }
}

// MARK: - API initialization tests

extension PortalYieldXyzApiTests {
  func test_init_withDefaultHost() {
    // given & when
    let api = PortalYieldXyzApi(apiKey: "test-key")
    
    // then
    XCTAssertNotNil(api)
  }
  
  func test_init_withCustomHost() {
    // given & when
    let api = PortalYieldXyzApi(
      apiKey: "test-key",
      apiHost: "custom.api.com"
    )
    
    // then
    XCTAssertNotNil(api)
  }
  
  func test_init_withLocalhostHost() {
    // given & when
    let api = PortalYieldXyzApi(
      apiKey: "test-key",
      apiHost: "localhost:3000"
    )
    
    // then
    XCTAssertNotNil(api)
  }
  
  func test_init_withCustomRequests() {
    // given
    let customRequests = PortalRequestsMock()
    
    // when
    let api = PortalYieldXyzApi(
      apiKey: "test-key",
      requests: customRequests
    )
    
    // then
    XCTAssertNotNil(api)
  }
}

// MARK: - Edge case tests

extension PortalYieldXyzApiTests {
  func test_getYields_withEmptyRequest() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzGetYieldsResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    // when
    let response = try await api?.getYields(request: YieldXyzGetYieldsRequest())
    
    // then
    XCTAssertNotNil(response)
  }
  
  func test_getYields_withOnlyOptionalParams() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzGetYieldsResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let request = YieldXyzGetYieldsRequest(
      hasCooldownPeriod: true,
      hasWarmupPeriod: false
    )
    
    // when
    let response = try await api?.getYields(request: request)
    
    // then
    XCTAssertNotNil(response)
  }
  
  func test_enterYield_withMinimalRequest() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzEnterYieldResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let request = YieldXyzEnterRequest(
      yieldId: "yield-1",
      address: "0x0"
    )
    
    // when
    let response = try await api?.enterYield(request: request)
    
    // then
    XCTAssertNotNil(response)
  }
  
  func test_getHistoricalYieldActions_withNoFilters() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzGetHistoricalActionsResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let request = YieldXyzGetHistoricalActionsRequest()
    
    // when
    let response = try await api?.getHistoricalYieldActions(request: request)
    
    // then
    XCTAssertNotNil(response)
  }
  
  func test_getYieldBalances_withEmptyYieldId() async throws {
    // given
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzGetBalancesResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(requests: portalRequestsSpy)
    
    let query = YieldXyzBalanceQuery(
      address: "0x1234567890abcdef1234567890abcdef12345678",
      network: "eip155:1",
      yieldId: nil
    )
    let request = YieldXyzGetBalancesRequest(queries: [query])
    
    // when
    let response = try await api?.getYieldBalances(request: request)
    
    // then
    XCTAssertNotNil(response)
  }
}

// MARK: - Bearer token tests

extension PortalYieldXyzApiTests {
  @available(iOS 16.0, *)
  func test_getYields_includesBearerToken() async throws {
    // given
    let apiKey = "test-api-key-123"
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzGetYieldsResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(apiKey: apiKey, requests: portalRequestsSpy)
    
    // when
    _ = try await api?.getYields(request: YieldXyzGetYieldsRequest())
    
    // then
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.headers["Authorization"], "Bearer \(apiKey)")
  }
  
  @available(iOS 16.0, *)
  func test_enterYield_includesBearerToken() async throws {
    // given
    let apiKey = "test-api-key-456"
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzEnterYieldResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(apiKey: apiKey, requests: portalRequestsSpy)
    
    let request = YieldXyzEnterRequest(
      yieldId: "yield-1",
      address: "0x1234567890abcdef1234567890abcdef12345678"
    )
    
    // when
    _ = try await api?.enterYield(request: request)
    
    // then
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.headers["Authorization"], "Bearer \(apiKey)")
  }
  
  @available(iOS 16.0, *)
  func test_submitTransactionHash_includesBearerToken() async throws {
    // given
    let apiKey = "test-api-key-789"
    let portalRequestsSpy = PortalRequestsSpy()
    let mockResponse = YieldXyzTrackTransactionResponse.stub()
    portalRequestsSpy.returnData = try encoder.encode(mockResponse)
    initPortalYieldXyzApiWith(apiKey: apiKey, requests: portalRequestsSpy)
    
    let request = YieldXyzTrackTransactionRequest(
      transactionId: "tx-123",
      hash: "0xhash123"
    )
    
    // when
    _ = try await api?.submitTransactionHash(request: request)
    
    // then
    XCTAssertEqual(portalRequestsSpy.executeRequestParam?.headers["Authorization"], "Bearer \(apiKey)")
  }
}
