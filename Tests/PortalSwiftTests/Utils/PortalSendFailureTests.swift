//
//  PortalSendFailureTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

@testable import PortalSwift
import XCTest

/// Whether a failed `sendAsset` is recognised as failing before anything was broadcast, checked on
/// the errors the real `PortalApi` and `PortalRequests` throw for its build request.
final class PortalSendFailureTests: XCTestCase {
  private var api: PortalApi!

  override func setUpWithError() throws {
    try super.setUpWithError()
    MockURLProtocol.reset()
    api = PortalApi(apiKey: "client-api-key", apiHost: MockConstants.mockHost, requests: PortalRequests(urlSession: MockURLProtocol.makeSession()))
  }

  override func tearDownWithError() throws {
    api = nil
    MockURLProtocol.reset()
    try super.tearDownWithError()
  }

  /// The error `call` fails with, or a test failure when it succeeds.
  private func failure(of call: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async -> Error? {
    do {
      try await call()
      XCTFail("Expected the request to fail", file: file, line: line)
      return nil
    } catch {
      return error
    }
  }

  func test_aBuildThePortalApiRefusesOrFails_failedBeforeSending() async throws {
    let responses: [(status: Int, body: String)] = [
      (400, #"{"error":"Balance 1 is short of 2000000 (amount 2000000 plus fees 0) for mint EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v."}"#),
      (500, #"{"error":"Internal server error"}"#)
    ]

    for response in responses {
      MockURLProtocol.respond(status: response.status, body: response.body)
      let solana = await failure {
        _ = try await self.api.buildSolanaTransaction(chainId: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp", params: .stub(), traceId: nil)
      }
      let evm = await failure {
        _ = try await self.api.buildEip155Transaction(chainId: "eip155:8453", params: .stub(), traceId: nil)
      }

      for error in [solana, evm].compactMap({ $0 }) {
        XCTAssertTrue(error is PortalRequestsError, "\(error)")
        XCTAssertTrue(PortalSendFailure.isBuildTransactionFailure(error), "\(error)")
        XCTAssertTrue(PortalSendFailure.sendAssetFailedBeforeSending(error), "\(error)")
      }
    }
  }

  func test_aFailedRequestToAnotherEndpoint_isNotABuildFailure() async throws {
    MockURLProtocol.respond(status: 400, body: #"{"error":"Bad request"}"#)

    let error = await failure { _ = try await self.api.getWalletCapabilities() }

    let unwrapped = try XCTUnwrap(error)
    XCTAssertTrue(unwrapped is PortalRequestsError, "\(unwrapped)")
    XCTAssertFalse(PortalSendFailure.isBuildTransactionFailure(unwrapped))
    XCTAssertFalse(PortalSendFailure.sendAssetFailedBeforeSending(unwrapped))
  }

  /// URLSession names the request's URL in `failingURL` for a real network failure (a refused
  /// connection or an unknown host does). `MockURLProtocol` cannot reproduce that, so the errors are
  /// built here.
  func test_aNetworkErrorNamingTheBuildUrl_isABuildFailure_andOneNamingAnotherIsNot() throws {
    let build = try XCTUnwrap(URL(string: "https://api.portalhq.io/api/v3/clients/me/chains/eip155:8453/assets/send/build-transaction"))
    let rpc = try XCTUnwrap(URL(string: "https://rpc.example.com/eip155:8453"))

    XCTAssertTrue(PortalSendFailure.isBuildTransactionFailure(URLError(.timedOut, userInfo: [NSURLErrorFailingURLErrorKey: build])))
    XCTAssertFalse(PortalSendFailure.isBuildTransactionFailure(URLError(.timedOut, userInfo: [NSURLErrorFailingURLErrorKey: rpc])))
    XCTAssertFalse(PortalSendFailure.isBuildTransactionFailure(URLError(.timedOut)))
  }

  func test_failuresThatNameNoUrl_areNotBuildFailures() {
    let failures: [Error] = [
      PortalRequestsError.unauthorized,
      PortalRequestsError.couldNotParseHttpResponse,
      PortalRequestsError.redirectError("302 - moved"),
      DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unexpected shape"))
    ]

    for failure in failures {
      XCTAssertFalse(PortalSendFailure.isBuildTransactionFailure(failure), "\(failure)")
      XCTAssertFalse(PortalSendFailure.sendAssetFailedBeforeSending(failure), "\(failure)")
    }
  }
}
