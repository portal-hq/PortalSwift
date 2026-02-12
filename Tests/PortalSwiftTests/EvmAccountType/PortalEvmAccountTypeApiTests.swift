//
//  PortalEvmAccountTypeApiTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import XCTest
@testable import PortalSwift

final class PortalEvmAccountTypeApiTests: XCTestCase {
  private var requestsSpy: PortalRequestsSpy!
  private var sut: PortalEvmAccountTypeApi!
  let testApiKey = "test-api-key"
  let encoder = JSONEncoder()

  // MARK: - Setup & Teardown

  override func setUpWithError() throws {
    try super.setUpWithError()
    requestsSpy = PortalRequestsSpy()
    sut = PortalEvmAccountTypeApi(
      apiKey: testApiKey,
      apiHost: "api.portalhq.io",
      requests: requestsSpy
    )
  }

  override func tearDownWithError() throws {
    requestsSpy = nil
    sut = nil
    try super.tearDownWithError()
  }

  private func setReturnValue<T: Encodable>(_ value: T) throws {
    requestsSpy.returnData = try encoder.encode(value)
  }

  // MARK: - Initialization Tests

  func testInit_productionHost_usesHttps() {
    let api = PortalEvmAccountTypeApi(apiKey: "key", apiHost: "api.portalhq.io")
    XCTAssertNotNil(api)
  }

  func testInit_localhost_usesHttp() async throws {
    let localSut = PortalEvmAccountTypeApi(
      apiKey: "test-key",
      apiHost: "localhost:3000",
      requests: requestsSpy
    )
    try setReturnValue(EvmAccountTypeResponse.stub())
    _ = try? await localSut.getStatus(chainId: "eip155:11155111")
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertTrue(portalRequest?.url.absoluteString.starts(with: "http://") ?? false)
  }

  // MARK: - getStatus Tests

  func testGetStatus_buildsCorrectUrl() async throws {
    try setReturnValue(EvmAccountTypeResponse.stub())
    _ = try await sut.getStatus(chainId: "eip155:11155111")
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let expectedUrl = "https://api.portalhq.io/api/v3/clients/me/chains/eip155%3A11155111/wallet/account-type"
    XCTAssertEqual(portalRequest?.url.absoluteString, expectedUrl)
  }

  func testGetStatus_usesGetMethod() async throws {
    try setReturnValue(EvmAccountTypeResponse.stub())
    _ = try await sut.getStatus(chainId: "eip155:11155111")
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.method, .get)
  }

  func testGetStatus_includesBearerToken() async throws {
    try setReturnValue(EvmAccountTypeResponse.stub())
    _ = try await sut.getStatus(chainId: "eip155:11155111")
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.headers["Authorization"], "Bearer \(testApiKey)")
  }

  func testGetStatus_hasNoPayload() async throws {
    try setReturnValue(EvmAccountTypeResponse.stub())
    _ = try await sut.getStatus(chainId: "eip155:11155111")
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertNil(portalRequest?.payload)
  }

  func testGetStatus_decodesValidResponse_success() async throws {
    let expectedResponse = EvmAccountTypeResponse.stub()
    try setReturnValue(expectedResponse)
    let response = try await sut.getStatus(chainId: "eip155:11155111")
    XCTAssertEqual(response.data.status, expectedResponse.data.status)
    XCTAssertEqual(response.metadata.chainId, expectedResponse.metadata.chainId)
    XCTAssertEqual(response.metadata.eoaAddress, expectedResponse.metadata.eoaAddress)
  }

  func testGetStatus_invalidResponse_throwsError() async {
    requestsSpy.returnData = Data()
    do {
      _ = try await sut.getStatus(chainId: "eip155:11155111")
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  // MARK: - buildAuthorizationList Tests

  func testBuildAuthorizationList_buildsCorrectUrl() async throws {
    try setReturnValue(BuildAuthorizationListResponse.stub())
    _ = try await sut.buildAuthorizationList(chainId: "eip155:11155111")
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let expectedUrl = "https://api.portalhq.io/api/v3/clients/me/chains/eip155%3A11155111/wallet/build-authorization-list"
    XCTAssertEqual(portalRequest?.url.absoluteString, expectedUrl)
  }

  func testBuildAuthorizationList_usesPostMethod() async throws {
    try setReturnValue(BuildAuthorizationListResponse.stub())
    _ = try await sut.buildAuthorizationList(chainId: "eip155:11155111")
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.method, .post)
  }

  func testBuildAuthorizationList_includesBearerToken() async throws {
    try setReturnValue(BuildAuthorizationListResponse.stub())
    _ = try await sut.buildAuthorizationList(chainId: "eip155:11155111")
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.headers["Authorization"], "Bearer \(testApiKey)")
  }

  func testBuildAuthorizationList_decodesValidResponse_success() async throws {
    let expectedResponse = BuildAuthorizationListResponse.stub()
    try setReturnValue(expectedResponse)
    let response = try await sut.buildAuthorizationList(chainId: "eip155:11155111")
    XCTAssertEqual(response.data.hash, expectedResponse.data.hash)
  }

  func testBuildAuthorizationList_invalidResponse_throwsError() async {
    requestsSpy.returnData = Data()
    do {
      _ = try await sut.buildAuthorizationList(chainId: "eip155:11155111")
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  // MARK: - buildAuthorizationTransaction Tests

  func testBuildAuthorizationTransaction_buildsCorrectUrl() async throws {
    try setReturnValue(BuildAuthorizationTransactionResponse.stub())
    _ = try await sut.buildAuthorizationTransaction(chainId: "eip155:11155111", signature: "abc123")
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let expectedUrl = "https://api.portalhq.io/api/v3/clients/me/chains/eip155%3A11155111/wallet/build-authorization-transaction"
    XCTAssertEqual(portalRequest?.url.absoluteString, expectedUrl)
  }

  func testBuildAuthorizationTransaction_usesPostMethod() async throws {
    try setReturnValue(BuildAuthorizationTransactionResponse.stub())
    _ = try await sut.buildAuthorizationTransaction(chainId: "eip155:11155111", signature: "sig")
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.method, .post)
  }

  func testBuildAuthorizationTransaction_includesBearerToken() async throws {
    try setReturnValue(BuildAuthorizationTransactionResponse.stub())
    _ = try await sut.buildAuthorizationTransaction(chainId: "eip155:11155111", signature: "sig")
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.headers["Authorization"], "Bearer \(testApiKey)")
  }

  func testBuildAuthorizationTransaction_serializesSignaturePayload() async throws {
    try setReturnValue(BuildAuthorizationTransactionResponse.stub())
    _ = try await sut.buildAuthorizationTransaction(chainId: "eip155:11155111", signature: "mysignature")
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertNotNil(portalRequest?.payload)
    if let payload = portalRequest?.payload as? BuildAuthorizationTransactionRequest {
      XCTAssertEqual(payload.signature, "mysignature")
    }
  }

  func testBuildAuthorizationTransaction_decodesValidResponse_success() async throws {
    let expectedResponse = BuildAuthorizationTransactionResponse.stub()
    try setReturnValue(expectedResponse)
    let response = try await sut.buildAuthorizationTransaction(chainId: "eip155:11155111", signature: "sig")
    XCTAssertEqual(response.data.transaction.from, expectedResponse.data.transaction.from)
    XCTAssertEqual(response.data.transaction.to, expectedResponse.data.transaction.to)
    XCTAssertEqual(response.data.transaction.type, "eip7702")
  }

  func testBuildAuthorizationTransaction_invalidResponse_throwsError() async {
    requestsSpy.returnData = Data()
    do {
      _ = try await sut.buildAuthorizationTransaction(chainId: "eip155:11155111", signature: "sig")
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  func testBuildAuthorizationTransaction_networkError_throwsError() async {
    let failMock = PortalRequestsFailMock()
    failMock.errorToThrow = URLError(.networkConnectionLost)
    let apiWithFailingRequests = PortalEvmAccountTypeApi(
      apiKey: testApiKey,
      apiHost: "api.portalhq.io",
      requests: failMock
    )
    do {
      _ = try await apiWithFailingRequests.buildAuthorizationTransaction(chainId: "eip155:11155111", signature: "sig")
      XCTFail("Expected error to be thrown")
    } catch let error as URLError {
      XCTAssertEqual(error.code, .networkConnectionLost)
    } catch {
      XCTFail("Expected URLError, got \(type(of: error))")
    }
  }
}
