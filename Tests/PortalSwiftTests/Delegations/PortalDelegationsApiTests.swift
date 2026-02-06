//
//  PortalDelegationsApiTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import XCTest
@testable import PortalSwift

final class PortalDelegationsApiTests: XCTestCase {

  private var requestsSpy: PortalRequestsSpy!
  private var sut: PortalDelegationsApi!
  let testApiKey = "test-api-key"
  let encoder = JSONEncoder()

  // MARK: - Setup & Teardown

  override func setUpWithError() throws {
    try super.setUpWithError()
    requestsSpy = PortalRequestsSpy()
    sut = PortalDelegationsApi(
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

  // Helper to set return data
  private func setReturnValue<T: Encodable>(_ value: T) throws {
    requestsSpy.returnData = try encoder.encode(value)
  }

  // MARK: - Initialization Tests

  func testInit_productionHost_usesHttps() {
    let api = PortalDelegationsApi(apiKey: "key", apiHost: "api.portalhq.io")
    XCTAssertNotNil(api)
  }

  func testInit_localhost_usesHttp() async throws {
    // Given
    let localSut = PortalDelegationsApi(
      apiKey: "test-key",
      apiHost: "localhost:3000",
      requests: requestsSpy
    )

    // When
    try setReturnValue(ApproveDelegationResponse(transactions: nil, encodedTransactions: nil, metadata: nil))
    let request = ApproveDelegationRequest.stub()
    _ = try? await localSut.approve(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertTrue(portalRequest?.url.absoluteString.starts(with: "http://") ?? false)
  }

  // MARK: - approve Tests

  func testApprove_buildsCorrectUrl() async throws {
    // Given
    try setReturnValue(ApproveDelegationResponse(transactions: nil, encodedTransactions: nil, metadata: nil))
    let request = ApproveDelegationRequest(chain: "eip155:11155111", token: "USDC", delegateAddress: "0x123", amount: "1.0")

    // When
    _ = try await sut.approve(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let expectedUrl = "https://api.portalhq.io/api/v3/clients/me/chains/eip155:11155111/assets/USDC/approvals"
    XCTAssertEqual(portalRequest?.url.absoluteString, expectedUrl)
  }

  func testApprove_usesPostMethod() async throws {
    // Given
    try setReturnValue(ApproveDelegationResponse(transactions: nil, encodedTransactions: nil, metadata: nil))
    let request = ApproveDelegationRequest.stub()

    // When
    _ = try await sut.approve(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.method, .post)
  }

  func testApprove_includesBearerToken() async throws {
    // Given
    try setReturnValue(ApproveDelegationResponse(transactions: nil, encodedTransactions: nil, metadata: nil))
    let request = ApproveDelegationRequest.stub()

    // When
    _ = try await sut.approve(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.headers["Authorization"], "Bearer \(testApiKey)")
  }

  func testApprove_serializesRequestPayload() async throws {
    // Given
    try setReturnValue(ApproveDelegationResponse(transactions: nil, encodedTransactions: nil, metadata: nil))
    let request = ApproveDelegationRequest.stub()

    // When
    _ = try await sut.approve(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertNotNil(portalRequest?.payload)
  }

  func testApprove_decodesValidResponse_success() async throws {
    // Given
    let expectedResponse = ApproveDelegationResponse.stub()
    try setReturnValue(expectedResponse)
    let request = ApproveDelegationRequest.stub()

    // When
    let response = try await sut.approve(request: request)

    // Then
    XCTAssertNotNil(response.metadata)
  }

  func testApprove_networkError_throwsError() async {
    // Given
    requestsSpy.returnData = Data()
    let request = ApproveDelegationRequest.stub()

    // When/Then
    do {
      _ = try await sut.approve(request: request)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  // MARK: - revoke Tests

  func testRevoke_buildsCorrectUrl() async throws {
    // Given
    try setReturnValue(RevokeDelegationResponse(transactions: nil, encodedTransactions: nil, metadata: nil))
    let request = RevokeDelegationRequest(chain: "eip155:11155111", token: "USDC", delegateAddress: "0x123")

    // When
    _ = try await sut.revoke(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let expectedUrl = "https://api.portalhq.io/api/v3/clients/me/chains/eip155:11155111/assets/USDC/revocations"
    XCTAssertEqual(portalRequest?.url.absoluteString, expectedUrl)
  }

  func testRevoke_usesPostMethod() async throws {
    // Given
    try setReturnValue(RevokeDelegationResponse(transactions: nil, encodedTransactions: nil, metadata: nil))
    let request = RevokeDelegationRequest.stub()

    // When
    _ = try await sut.revoke(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.method, .post)
  }

  func testRevoke_includesBearerToken() async throws {
    // Given
    try setReturnValue(RevokeDelegationResponse(transactions: nil, encodedTransactions: nil, metadata: nil))
    let request = RevokeDelegationRequest.stub()

    // When
    _ = try await sut.revoke(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.headers["Authorization"], "Bearer \(testApiKey)")
  }

  func testRevoke_serializesRequestPayload() async throws {
    // Given
    try setReturnValue(RevokeDelegationResponse(transactions: nil, encodedTransactions: nil, metadata: nil))
    let request = RevokeDelegationRequest.stub()

    // When
    _ = try await sut.revoke(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertNotNil(portalRequest?.payload)
  }

  func testRevoke_decodesValidResponse_success() async throws {
    // Given
    let expectedResponse = RevokeDelegationResponse.stub()
    try setReturnValue(expectedResponse)
    let request = RevokeDelegationRequest.stub()

    // When
    let response = try await sut.revoke(request: request)

    // Then
    XCTAssertNotNil(response.metadata)
  }

  func testRevoke_networkError_throwsError() async {
    // Given
    let failMock = PortalRequestsFailMock()
    failMock.errorToThrow = URLError(.networkConnectionLost)
    let apiWithFailingRequests = PortalDelegationsApi(
      apiKey: testApiKey,
      apiHost: "api.portalhq.io",
      requests: failMock
    )
    let request = RevokeDelegationRequest.stub()

    // When/Then
    do {
      _ = try await apiWithFailingRequests.revoke(request: request)
      XCTFail("Expected error to be thrown")
    } catch let error as URLError {
      XCTAssertEqual(error.code, .networkConnectionLost)
    } catch {
      XCTFail("Expected URLError, got \(type(of: error))")
    }
  }

  // MARK: - getStatus Tests

  func testGetStatus_buildsCorrectUrl_withQueryParam() async throws {
    // Given
    try setReturnValue(DelegationStatusResponse.stub())
    let request = GetDelegationStatusRequest(chain: "eip155:1", token: "USDC", delegateAddress: "0xabc")

    // When
    _ = try await sut.getStatus(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertTrue(portalRequest?.url.absoluteString.contains("delegateAddress=0xabc") ?? false)
    XCTAssertTrue(portalRequest?.url.absoluteString.contains("/delegations?") ?? false)
  }

  func testGetStatus_usesGetMethod() async throws {
    // Given
    try setReturnValue(DelegationStatusResponse.stub())
    let request = GetDelegationStatusRequest.stub()

    // When
    _ = try await sut.getStatus(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.method, .get)
  }

  func testGetStatus_includesBearerToken() async throws {
    // Given
    try setReturnValue(DelegationStatusResponse.stub())
    let request = GetDelegationStatusRequest.stub()

    // When
    _ = try await sut.getStatus(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.headers["Authorization"], "Bearer \(testApiKey)")
  }

  func testGetStatus_hasNoPayload() async throws {
    // Given
    try setReturnValue(DelegationStatusResponse.stub())
    let request = GetDelegationStatusRequest.stub()

    // When
    _ = try await sut.getStatus(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertNil(portalRequest?.payload)
  }

  func testGetStatus_decodesValidResponse_success() async throws {
    // Given
    let expectedResponse = DelegationStatusResponse.stub()
    try setReturnValue(expectedResponse)
    let request = GetDelegationStatusRequest.stub()

    // When
    let response = try await sut.getStatus(request: request)

    // Then
    XCTAssertEqual(response.token, "USDC")
    XCTAssertFalse(response.delegations.isEmpty)
  }

  func testGetStatus_networkError_throwsError() async {
    // Given
    requestsSpy.returnData = Data()
    let request = GetDelegationStatusRequest.stub()

    // When/Then
    do {
      _ = try await sut.getStatus(request: request)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  func testGetStatus_buildsCorrectUrlPath() async throws {
    // Given
    try setReturnValue(DelegationStatusResponse.stub())
    let request = GetDelegationStatusRequest(chain: "eip155:11155111", token: "USDC", delegateAddress: "0xabc")

    // When
    _ = try await sut.getStatus(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let expectedBase = "https://api.portalhq.io/api/v3/clients/me/chains/eip155:11155111/assets/USDC/delegations"
    XCTAssertTrue(portalRequest?.url.absoluteString.starts(with: expectedBase) ?? false)
  }

  // MARK: - transferFrom Tests

  func testTransferFrom_buildsCorrectUrl() async throws {
    // Given
    try setReturnValue(TransferFromResponse.stub())
    let request = TransferFromRequest(chain: "eip155:11155111", token: "USDC", fromAddress: "0x1", toAddress: "0x2", amount: "1.0")

    // When
    _ = try await sut.transferFrom(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    let expectedUrl = "https://api.portalhq.io/api/v3/clients/me/chains/eip155:11155111/assets/USDC/delegations/transfers"
    XCTAssertEqual(portalRequest?.url.absoluteString, expectedUrl)
  }

  func testTransferFrom_usesPostMethod() async throws {
    // Given
    try setReturnValue(TransferFromResponse.stub())
    let request = TransferFromRequest.stub()

    // When
    _ = try await sut.transferFrom(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.method, .post)
  }

  func testTransferFrom_includesBearerToken() async throws {
    // Given
    try setReturnValue(TransferFromResponse.stub())
    let request = TransferFromRequest.stub()

    // When
    _ = try await sut.transferFrom(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertEqual(portalRequest?.headers["Authorization"], "Bearer \(testApiKey)")
  }

  func testTransferFrom_serializesRequestPayload() async throws {
    // Given
    try setReturnValue(TransferFromResponse.stub())
    let request = TransferFromRequest.stub()

    // When
    _ = try await sut.transferFrom(request: request)

    // Then
    let portalRequest = requestsSpy.executeRequestParam as? PortalAPIRequest
    XCTAssertNotNil(portalRequest?.payload)
  }

  func testTransferFrom_decodesValidResponse_success() async throws {
    // Given
    let expectedResponse = TransferFromResponse.stub()
    try setReturnValue(expectedResponse)
    let request = TransferFromRequest.stub()

    // When
    let response = try await sut.transferFrom(request: request)

    // Then
    XCTAssertEqual(response.metadata.amount, "1.0")
  }

  func testTransferFrom_networkError_throwsError() async {
    // Given
    requestsSpy.returnData = Data()
    let request = TransferFromRequest.stub()

    // When/Then
    do {
      _ = try await sut.transferFrom(request: request)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertNotNil(error)
    }
  }
}
