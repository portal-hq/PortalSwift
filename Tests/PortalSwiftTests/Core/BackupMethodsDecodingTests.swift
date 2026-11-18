//
//  BackupMethodsDecodingTests.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

@testable import PortalSwift
import XCTest

final class BackupMethodsDecodingTests: XCTestCase {
  private struct Wrapper: Codable {
    let backupMethod: BackupMethods
  }

  func test_decodesPasskeyPrf() throws {
    let decoded = try JSONDecoder().decode(Wrapper.self, from: Data(#"{"backupMethod":"PASSKEY_PRF"}"#.utf8))
    XCTAssertEqual(decoded.backupMethod, .PasskeyPrf)
  }

  func test_decodesEveryKnownValue() throws {
    for (raw, method) in [
      ("GDRIVE", BackupMethods.GoogleDrive), ("ICLOUD", .iCloud), ("CUSTOM", .local), ("PASSWORD", .Password),
      ("PASSKEY", .Passkey), ("PASSKEY_PRF", .PasskeyPrf), ("FIREBASE", .Firebase), ("UNKNOWN", .Unknown)
    ] {
      let decoded = try JSONDecoder().decode(Wrapper.self, from: Data(#"{"backupMethod":"\#(raw)"}"#.utf8))
      XCTAssertEqual(decoded.backupMethod, method, raw)
    }
  }

  func test_decodesAnUnknownFutureValue_asUnknown() throws {
    let decoded = try JSONDecoder().decode(Wrapper.self, from: Data(#"{"backupMethod":"SOMETHING_NEW"}"#.utf8))
    XCTAssertEqual(decoded.backupMethod, .Unknown)
  }

  func test_encodesTheWireValue() throws {
    let encoded = try JSONEncoder().encode(Wrapper(backupMethod: .PasskeyPrf))
    XCTAssertEqual(String(data: encoded, encoding: .utf8), #"{"backupMethod":"PASSKEY_PRF"}"#)
  }

  func test_clientResponse_withPasskeyPrfAndFutureSharePairs_decodes() throws {
    let json = """
    {
      "id": "client-id",
      "custodian": { "id": "custodian-id", "name": "Acme" },
      "createdAt": "2026-01-01",
      "environment": { "id": "env-id", "name": "env", "backupWithPortalEnabled": true },
      "ejectedAt": null,
      "isAccountAbstracted": false,
      "metadata": { "namespaces": {} },
      "wallets": [
        {
          "id": "wallet-id",
          "createdAt": "2026-01-01",
          "curve": "SECP256K1",
          "publicKey": "pk",
          "backupSharePairs": [
            { "id": "bsp-1", "backupMethod": "PASSKEY_PRF", "createdAt": "2026-01-01", "status": "completed" },
            { "id": "bsp-2", "backupMethod": "SOMETHING_NEW", "createdAt": "2026-01-01", "status": "completed" }
          ],
          "signingSharePairs": []
        }
      ]
    }
    """
    let client = try JSONDecoder().decode(ClientResponse.self, from: Data(json.utf8))
    XCTAssertEqual(client.wallets.first?.backupSharePairs.map(\.backupMethod), [.PasskeyPrf, .Unknown])
  }
}
