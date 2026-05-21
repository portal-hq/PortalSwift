//
//  ScanAddressesCodableTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import Foundation
@testable import PortalSwift
import XCTest

final class ScanAddressesCodableTests: XCTestCase {
  var decoder: JSONDecoder!

  override func setUpWithError() throws {
    try super.setUpWithError()
    decoder = JSONDecoder()
  }

  override func tearDownWithError() throws {
    decoder = nil
    try super.tearDownWithError()
  }
}

// MARK: - Regression Tests for Partial Backend Payloads

extension ScanAddressesCodableTests {
  /// Regression test: backend may omit `totalIncomingUsd`, `totalOutgoingUsd`,
  /// `policyId`, `timestamp`, and may return an empty `flags` array (or omit it
  /// entirely) for items with `recommendation: "Approve"`. Decoding must not
  /// throw `keyNotFound` for any of these fields.
  func test_scanAddressesResponse_decodesItemWithMissingOptionalFields() throws {
    let json = Data("""
    {
      "data": {
        "rawResponse": [
          {
            "address": "0x2753a0d37a2ad09be3ccc0afcb650bea8ea57a8f",
            "recommendation": "Approve",
            "severity": "N/A",
            "flags": []
          }
        ]
      }
    }
    """.utf8)

    let response = try decoder.decode(ScanAddressesResponse.self, from: json)

    let item = try XCTUnwrap(response.data?.rawResponse.first)
    XCTAssertEqual(item.address, "0x2753a0d37a2ad09be3ccc0afcb650bea8ea57a8f")
    XCTAssertEqual(item.recommendation, "Approve")
    XCTAssertEqual(item.severity, "N/A")
    XCTAssertNil(item.totalIncomingUsd)
    XCTAssertNil(item.totalOutgoingUsd)
    XCTAssertNil(item.policyId)
    XCTAssertNil(item.timestamp)
    XCTAssertEqual(item.flags?.count, 0)
  }

  /// Regression test: `flags` itself may be omitted (not just empty).
  func test_scanAddressesResponse_decodesItemWithOmittedFlags() throws {
    let json = Data("""
    {
      "data": {
        "rawResponse": [
          {
            "address": "0xabc",
            "recommendation": "Approve",
            "severity": "N/A"
          }
        ]
      }
    }
    """.utf8)

    let response = try decoder.decode(ScanAddressesResponse.self, from: json)
    let item = try XCTUnwrap(response.data?.rawResponse.first)
    XCTAssertNil(item.flags)
  }

  /// Regression test: a fully-populated "Deny" item (with the newly added
  /// fields `totalOutgoingUsd`, exposure `direction`/`severity`, and
  /// flagged-interaction `entityId`/`entityName`/`severity`) decodes and
  /// preserves all values.
  func test_scanAddressesResponse_decodesFullyPopulatedDenyItem() throws {
    let json = Data("""
    {
      "data": {
        "rawResponse": [
          {
            "address": "0x31c05d73f2333b5a176cfdbb7c5ef96ec7bb04ac",
            "recommendation": "Deny",
            "severity": "High",
            "totalIncomingUsd": 898761.6875,
            "totalOutgoingUsd": 2149675.75,
            "policyId": "ac938c22-4a3b-4f6c-9c1a-e9e7c7e9113d",
            "timestamp": "2026-05-13T23:09:19.506Z",
            "flags": [
              {
                "title": "Related to Mixing Services",
                "flagId": "RF1510",
                "chain": "eip155:1",
                "severity": "High",
                "events": [],
                "lastUpdate": "2023-12-28T21:05:35Z",
                "exposures": [
                  {
                    "exposurePortion": 0.8854220719626247,
                    "exposureType": "direct",
                    "totalExposureUsd": 795783.435546875,
                    "flaggedInteractions": [
                      {
                        "address": "0xa160cdab225685da1d56aa342ad8841c3b53f291",
                        "chain": "eip155:1",
                        "alias": "Tornado.Cash: 100 ETH",
                        "minHop": 1,
                        "totalExposureUsd": 705959,
                        "entityId": "147b88c2-e008-4c1b-89d2-d08ea9e13e77",
                        "entityName": "Tornado.Cash",
                        "severity": "High"
                      }
                    ],
                    "direction": "incoming",
                    "severity": "High"
                  }
                ]
              }
            ]
          }
        ]
      }
    }
    """.utf8)

    let response = try decoder.decode(ScanAddressesResponse.self, from: json)
    let item = try XCTUnwrap(response.data?.rawResponse.first)

    XCTAssertEqual(item.totalIncomingUsd, 898761.6875)
    XCTAssertEqual(item.totalOutgoingUsd, 2149675.75)
    XCTAssertEqual(item.policyId, "ac938c22-4a3b-4f6c-9c1a-e9e7c7e9113d")
    XCTAssertEqual(item.timestamp, "2026-05-13T23:09:19.506Z")

    let flag = try XCTUnwrap(item.flags?.first)
    XCTAssertEqual(flag.flagId, "RF1510")
    XCTAssertEqual(flag.chain, "eip155:1")
    XCTAssertEqual(flag.events?.count, 0)

    let exposure = try XCTUnwrap(flag.exposures.first)
    XCTAssertEqual(exposure.exposurePortion, 0.8854220719626247)
    XCTAssertEqual(exposure.direction, "incoming")
    XCTAssertEqual(exposure.severity, "High")

    let interaction = try XCTUnwrap(exposure.flaggedInteractions.first)
    XCTAssertEqual(interaction.address, "0xa160cdab225685da1d56aa342ad8841c3b53f291")
    XCTAssertEqual(interaction.chain, "eip155:1")
    XCTAssertEqual(interaction.alias, "Tornado.Cash: 100 ETH")
    XCTAssertEqual(interaction.entityId, "147b88c2-e008-4c1b-89d2-d08ea9e13e77")
    XCTAssertEqual(interaction.entityName, "Tornado.Cash")
    XCTAssertEqual(interaction.severity, "High")
  }

  /// Regression test: the full multi-item payload from SDK-136 (one Deny item
  /// with full flags, one Approve item with no flags/policyId/timestamp/totals)
  /// decodes successfully.
  func test_scanAddressesResponse_decodesMixedDenyAndApprovePayload() throws {
    let json = Data("""
    {
      "data": {
        "rawResponse": [
          {
            "address": "0x31c05d73f2333b5a176cfdbb7c5ef96ec7bb04ac",
            "recommendation": "Deny",
            "severity": "High",
            "totalIncomingUsd": 898761.6875,
            "totalOutgoingUsd": 2149675.75,
            "policyId": "ac938c22-4a3b-4f6c-9c1a-e9e7c7e9113d",
            "timestamp": "2026-05-13T23:09:19.506Z",
            "flags": []
          },
          {
            "address": "0x2753a0d37a2ad09be3ccc0afcb650bea8ea57a8f",
            "recommendation": "Approve",
            "severity": "N/A",
            "policyId": "ac938c22-4a3b-4f6c-9c1a-e9e7c7e9113d",
            "timestamp": "2026-05-13T23:09:19.506Z",
            "flags": []
          }
        ]
      }
    }
    """.utf8)

    let response = try decoder.decode(ScanAddressesResponse.self, from: json)
    let items = try XCTUnwrap(response.data?.rawResponse)

    XCTAssertEqual(items.count, 2)
    XCTAssertEqual(items[0].recommendation, "Deny")
    XCTAssertEqual(items[1].recommendation, "Approve")
    XCTAssertNil(items[1].totalIncomingUsd)
    XCTAssertNil(items[1].totalOutgoingUsd)
  }
}
