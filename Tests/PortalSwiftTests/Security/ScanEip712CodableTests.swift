//
//  ScanEip712CodableTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import Foundation
@testable import PortalSwift
import XCTest

final class ScanEip712CodableTests: XCTestCase {
  var encoder: JSONEncoder!
  var decoder: JSONDecoder!

  override func setUpWithError() throws {
    try super.setUpWithError()
    encoder = JSONEncoder()
    decoder = JSONDecoder()
  }

  override func tearDownWithError() throws {
    encoder = nil
    decoder = nil
    try super.tearDownWithError()
  }
}

// MARK: - ScanEip712Trace Codable Tests

extension ScanEip712CodableTests {
  func test_scanEip712Trace_encodesAndDecodesCorrectly() throws {
    // Given
    let trace = ScanEip712Trace.stub(
      funcId: "0x095ea7b3",
      callType: "call",
      value: 0,
      traceAddress: [0],
      status: 1,
      callInput: "0xabcdef",
      extraInfo: ["key": "value"]
    )

    // When
    let data = try encoder.encode(trace)
    let decoded = try decoder.decode(ScanEip712Trace.self, from: data)

    // Then
    XCTAssertEqual(decoded.from, trace.from)
    XCTAssertEqual(decoded.to, trace.to)
    XCTAssertEqual(decoded.funcId, "0x095ea7b3")
    XCTAssertEqual(decoded.callType, "call")
    XCTAssertEqual(decoded.value, 0)
    XCTAssertEqual(decoded.traceAddress, [0])
    XCTAssertEqual(decoded.status, 1)
    XCTAssertEqual(decoded.callInput, "0xabcdef")
    XCTAssertEqual(decoded.extraInfo?["key"], "value")
  }

  func test_scanEip712Trace_decodesWithoutFromAndTo() throws {
    // Given: trace JSON missing the now-optional `from` and `to` fields
    let json = """
    {
      "funcId": "0xdeadbeef",
      "callType": "call",
      "status": 1
    }
    """.data(using: .utf8)!

    // When
    let decoded = try decoder.decode(ScanEip712Trace.self, from: json)

    // Then
    XCTAssertNil(decoded.from)
    XCTAssertNil(decoded.to)
    XCTAssertEqual(decoded.funcId, "0xdeadbeef")
    XCTAssertEqual(decoded.callType, "call")
    XCTAssertEqual(decoded.status, 1)
  }

  func test_scanEip712Trace_decodesWithExplicitNullFromAndTo() throws {
    // Given: trace JSON where from/to are explicit null
    let json = """
    {
      "from": null,
      "to": null,
      "funcId": "0x095ea7b3"
    }
    """.data(using: .utf8)!

    // When
    let decoded = try decoder.decode(ScanEip712Trace.self, from: json)

    // Then
    XCTAssertNil(decoded.from)
    XCTAssertNil(decoded.to)
    XCTAssertEqual(decoded.funcId, "0x095ea7b3")
  }

  func test_scanEip712Trace_roundTripsWithNilFromAndTo() throws {
    // Given
    let trace = ScanEip712Trace.stub(from: nil, to: nil, funcId: "0x095ea7b3")

    // When
    let data = try encoder.encode(trace)
    let decoded = try decoder.decode(ScanEip712Trace.self, from: data)

    // Then
    XCTAssertNil(decoded.from)
    XCTAssertNil(decoded.to)
    XCTAssertEqual(decoded.funcId, "0x095ea7b3")
  }
}

// MARK: - ScanEip712Response Codable Tests

extension ScanEip712CodableTests {
  func test_scanEip712Response_encodesAndDecodesCorrectly() throws {
    // Given
    let response = ScanEip712Response.stub()

    // When
    let data = try encoder.encode(response)
    let decoded = try decoder.decode(ScanEip712Response.self, from: data)

    // Then
    XCTAssertNotNil(decoded.data)
    XCTAssertEqual(decoded.data?.rawResponse.success, true)
    XCTAssertEqual(decoded.data?.rawResponse.data?.recommendation, "accept")
    XCTAssertNil(decoded.error)
  }

  func test_scanEip712Response_withTraceContainingNilFromAndTo() throws {
    // Given: full response containing a trace with optional from/to set to nil
    let trace = ScanEip712Trace.stub(from: nil, to: nil, funcId: "0xabc")
    let riskData = ScanEip712RiskData.stub(trace: [trace])
    let rawResponse = ScanEip712RawResponse.stub(data: riskData)
    let response = ScanEip712Response(data: ScanEip712Data(rawResponse: rawResponse), error: nil)

    // When
    let data = try encoder.encode(response)
    let decoded = try decoder.decode(ScanEip712Response.self, from: data)

    // Then
    let decodedTrace = decoded.data?.rawResponse.data?.trace?.first
    XCTAssertNotNil(decodedTrace)
    XCTAssertNil(decodedTrace?.from)
    XCTAssertNil(decodedTrace?.to)
    XCTAssertEqual(decodedTrace?.funcId, "0xabc")
  }
}
