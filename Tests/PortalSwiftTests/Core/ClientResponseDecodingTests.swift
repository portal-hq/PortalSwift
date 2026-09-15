//
//  ClientResponseDecodingTests.swift
//  PortalSwift_Tests
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

@testable import PortalSwift
import XCTest

/// Decodes raw `GET /api/v3/clients/me` payloads, so the coding keys are exercised against the
/// wire format rather than against a Swift round-trip through `ClientResponse`.
final class ClientResponseDecodingTests: XCTestCase {
  private let decoder = JSONDecoder()

  private func meResponseJson(includingXrpl: Bool) -> String {
    let xrplEntry = includingXrpl
      ? """
      ,
            "xrpl": { "address": "rPMaML8R5BLG69NXKXsdTqK64LSkMTspaK", "curve": "SECP256K1" }
      """
      : ""

    return """
    {
      "id": "test-client-id",
      "custodian": { "id": "test-custodian-id", "name": "test-custodian-name" },
      "createdAt": "2026-09-11T00:00:00.000Z",
      "environment": { "id": "test-environment-id", "name": "test-environment-name", "backupWithPortalEnabled": false },
      "ejectedAt": null,
      "isAccountAbstracted": false,
      "metadata": {
        "namespaces": {
          "eip155": { "address": "0x73574d235573574d235573574d235573574d2355", "curve": "SECP256K1" },
          "solana": { "address": "6LmSRCiu3z6NCSpF19oz1pHXkYkN4jWbj9K1nVELpDkT", "curve": "ED25519" },
          "tron": { "address": "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t", "curve": "SECP256K1" }\(xrplEntry)
        }
      },
      "wallets": []
    }
    """
  }

  func test_decode_meResponse_withXrpl() throws {
    // given
    let data = Data(meResponseJson(includingXrpl: true).utf8)

    // and given
    let client = try decoder.decode(ClientResponse.self, from: data)

    // then
    XCTAssertEqual(client.metadata.namespaces.xrpl?.address, "rPMaML8R5BLG69NXKXsdTqK64LSkMTspaK")
    XCTAssertEqual(client.metadata.namespaces.xrpl?.curve, .SECP256K1)
  }

  func test_decode_meResponse_withoutXrpl() throws {
    // given
    let data = Data(meResponseJson(includingXrpl: false).utf8)

    // and given
    let client = try decoder.decode(ClientResponse.self, from: data)

    // then
    XCTAssertNil(client.metadata.namespaces.xrpl)
    XCTAssertNotNil(client.metadata.namespaces.eip155)
  }
}
