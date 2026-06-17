//
//  TraceIdTests.swift
//  PortalSwiftTests
//
//  Tests for the X-Portal-Trace-Id header and MPC reqId propagation.
//

import AnyCodable
@testable import PortalSwift
import XCTest

final class TraceIdTests: XCTestCase {
  // MARK: - generateTraceId

  func test_generateTraceId_returnsLowercasedUUID() {
    let traceId = generateTraceId()
    XCTAssertNotNil(UUID(uuidString: traceId), "Trace ID should be a valid UUID")
    XCTAssertEqual(traceId, traceId.lowercased(), "Trace ID should be lowercased")
  }

  func test_generateTraceId_isUnique() {
    let first = generateTraceId()
    let second = generateTraceId()
    XCTAssertNotEqual(first, second)
  }

  // MARK: - PortalAPIRequest header injection

  func test_portalAPIRequest_autoGeneratesTraceIdHeader() throws {
    let url = try XCTUnwrap(URL(string: "https://api.portalhq.io/api/v3/clients/me"))
    let request = PortalAPIRequest(url: url, bearerToken: "test-key")

    let header = try XCTUnwrap(request.headers[PORTAL_TRACE_ID_HEADER])
    XCTAssertNotNil(UUID(uuidString: header), "Auto-generated trace ID should be a valid UUID")
  }

  func test_portalAPIRequest_honorsExplicitTraceId() throws {
    let url = try XCTUnwrap(URL(string: "https://api.portalhq.io/api/v3/clients/me"))
    let request = PortalAPIRequest(url: url, bearerToken: "test-key", traceId: "explicit-trace-id")

    XCTAssertEqual(request.headers[PORTAL_TRACE_ID_HEADER], "explicit-trace-id")
  }

  // MARK: - PortalApi forwards the header

  func test_portalApi_buildEip155Transaction_forwardsExplicitTraceIdHeader() async throws {
    let spy = PortalRequestsSpy()
    spy.returnData = try JSONEncoder().encode(BuildEip115TransactionResponse.stub())
    let api = PortalApi(apiKey: MockConstants.mockApiKey, requests: spy)

    _ = try await api.buildEip155Transaction(
      chainId: "eip155:11155111",
      params: BuildTransactionParam(to: "0xto", token: "NATIVE", amount: "1.0"),
      traceId: "trace-build-123"
    )

    let executedRequest = try XCTUnwrap(spy.executeRequestParam)
    XCTAssertEqual(executedRequest.headers[PORTAL_TRACE_ID_HEADER], "trace-build-123")
  }

  func test_portalApi_getClient_includesTraceIdHeader() async throws {
    let spy = PortalRequestsSpy()
    spy.returnData = try JSONEncoder().encode(ClientResponse.stub())
    let api = PortalApi(apiKey: MockConstants.mockApiKey, requests: spy)

    _ = try await api.getClient()

    let executedRequest = try XCTUnwrap(spy.executeRequestParam)
    let header = try XCTUnwrap(executedRequest.headers[PORTAL_TRACE_ID_HEADER])
    XCTAssertNotNil(UUID(uuidString: header), "getClient should attach a valid trace ID header")
  }

  // MARK: - MPC reqId mapping

  func test_portalMpcSigner_mapsReqIdIntoMpcMetadata() async throws {
    let mobileSpy = MobileSpy()
    mobileSpy.mobileSignReturnValue = MockConstants.mockSignatureResponse
    let signer = PortalMpcSigner(
      apiKey: MockConstants.mockApiKey,
      keychain: MockPortalKeychain(),
      binary: mobileSpy
    )
    let blockchain = try PortalBlockchain(fromChainId: "eip155:11155111")
    let signRequest = PortalSignRequest(method: .eth_sign, params: "test-message")

    _ = try await signer.sign(
      "eip155:11155111",
      withPayload: signRequest,
      andRpcUrl: MockConstants.mockHost,
      usingBlockchain: blockchain,
      signatureApprovalMemo: nil,
      sponsorGas: nil,
      reqId: "trace-sign-456"
    )

    let metadata = try XCTUnwrap(mobileSpy.mobileSignMetadataParam)
    XCTAssertTrue(metadata.contains("trace-sign-456"), "MPC metadata should contain the reqId. Got: \(metadata)")
  }
}
