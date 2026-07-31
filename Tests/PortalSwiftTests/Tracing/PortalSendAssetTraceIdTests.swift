//
//  PortalSendAssetTraceIdTests.swift
//  PortalSwiftTests
//
//  Verifies sendAsset shares a single trace ID across the build and sign/broadcast steps.
//

@testable import PortalSwift
import XCTest

extension PortalTests {
  func test_sendAsset_eip155_usesSingleTraceIdForBuildAndSign() async throws {
    let apiSpy = PortalApiSpy()
    try initPortalWithSpy(api: apiSpy)

    let providerSpy = PortalProviderSpy()
    setToPortal(portalProvider: providerSpy)

    _ = try await portal.sendAsset(
      chainId: "eip155:11155111",
      params: SendAssetParams(to: "0xto", amount: "1.0", token: "NATIVE")
    )

    let buildTraceId = try XCTUnwrap(apiSpy.buildEip155TransactionTraceIdParam, "build should receive a trace ID")
    let sendTraceId = try XCTUnwrap(providerSpy.requestOptionsOptionsParam?.traceId, "request options should carry a trace ID")
    XCTAssertEqual(buildTraceId, sendTraceId, "sendAsset should reuse one trace ID for build and sign")
  }

  func test_sendAsset_honorsCallerProvidedTraceId() async throws {
    let apiSpy = PortalApiSpy()
    try initPortalWithSpy(api: apiSpy)

    let providerSpy = PortalProviderSpy()
    setToPortal(portalProvider: providerSpy)

    _ = try await portal.sendAsset(
      chainId: "eip155:11155111",
      params: SendAssetParams(to: "0xto", amount: "1.0", token: "NATIVE", traceId: "caller-trace-id")
    )

    XCTAssertEqual(apiSpy.buildEip155TransactionTraceIdParam, "caller-trace-id")
    XCTAssertEqual(providerSpy.requestOptionsOptionsParam?.traceId, "caller-trace-id")
  }
}
