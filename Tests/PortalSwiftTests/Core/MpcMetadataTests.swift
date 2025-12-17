//
//  MpcMetadataTests.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

@testable import PortalSwift
import XCTest

final class MpcMetadataTests: XCTestCase {
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()

  override func setUpWithError() throws {}

  override func tearDownWithError() throws {}
}

// MARK: - MpcMetadata Initialization Tests

extension MpcMetadataTests {
  func test_init_setsDefaultOptimizedToTrue() throws {
    // given
    let metadata = MpcMetadata(
      clientPlatform: "NATIVE_IOS",
      mpcServerVersion: "1.0.0"
    )

    // then
    XCTAssertTrue(metadata.optimized)
  }

  func test_init_setsDefaultIsMultiBackupEnabledToNil() throws {
    // given
    let metadata = MpcMetadata(
      clientPlatform: "NATIVE_IOS",
      mpcServerVersion: "1.0.0"
    )

    // then
    XCTAssertNil(metadata.isMultiBackupEnabled)
  }

  func test_init_setsDefaultIsRawToNil() throws {
    // given
    let metadata = MpcMetadata(
      clientPlatform: "NATIVE_IOS",
      mpcServerVersion: "1.0.0"
    )

    // then
    XCTAssertNil(metadata.isRaw)
  }

  func test_init_setsDefaultSignatureApprovalMemoToNil() throws {
    // given
    let metadata = MpcMetadata(
      clientPlatform: "NATIVE_IOS",
      mpcServerVersion: "1.0.0"
    )

    // then
    XCTAssertNil(metadata.signatureApprovalMemo)
  }

  func test_init_setsDefaultSponsorGasToNil() throws {
    // given
    let metadata = MpcMetadata(
      clientPlatform: "NATIVE_IOS",
      mpcServerVersion: "1.0.0"
    )

    // then
    XCTAssertNil(metadata.sponsorGas)
  }
}

// MARK: - SponsorGas Property Tests

extension MpcMetadataTests {
  func test_sponsorGas_canBeSetToTrue() throws {
    // given
    var metadata = MpcMetadata(
      clientPlatform: "NATIVE_IOS",
      mpcServerVersion: "1.0.0"
    )

    // when
    metadata.sponsorGas = true

    // then
    XCTAssertEqual(metadata.sponsorGas, true)
  }

  func test_sponsorGas_canBeSetToFalse() throws {
    // given
    var metadata = MpcMetadata(
      clientPlatform: "NATIVE_IOS",
      mpcServerVersion: "1.0.0"
    )

    // when
    metadata.sponsorGas = false

    // then
    XCTAssertEqual(metadata.sponsorGas, false)
  }

  func test_sponsorGas_canBeSetToNil() throws {
    // given
    var metadata = MpcMetadata(
      clientPlatform: "NATIVE_IOS",
      mpcServerVersion: "1.0.0"
    )
    metadata.sponsorGas = true

    // when
    metadata.sponsorGas = nil

    // then
    XCTAssertNil(metadata.sponsorGas)
  }
}

// MARK: - SignatureApprovalMemo Property Tests

extension MpcMetadataTests {
  func test_signatureApprovalMemo_canBeSetToValue() throws {
    // given
    var metadata = MpcMetadata(
      clientPlatform: "NATIVE_IOS",
      mpcServerVersion: "1.0.0"
    )
    let expectedMemo = "Please approve this signature"

    // when
    metadata.signatureApprovalMemo = expectedMemo

    // then
    XCTAssertEqual(metadata.signatureApprovalMemo, expectedMemo)
  }

  func test_signatureApprovalMemo_canBeSetToEmptyString() throws {
    // given
    var metadata = MpcMetadata(
      clientPlatform: "NATIVE_IOS",
      mpcServerVersion: "1.0.0"
    )

    // when
    metadata.signatureApprovalMemo = ""

    // then
    XCTAssertEqual(metadata.signatureApprovalMemo, "")
  }

  func test_signatureApprovalMemo_canBeSetToNil() throws {
    // given
    var metadata = MpcMetadata(
      clientPlatform: "NATIVE_IOS",
      mpcServerVersion: "1.0.0"
    )
    metadata.signatureApprovalMemo = "test"

    // when
    metadata.signatureApprovalMemo = nil

    // then
    XCTAssertNil(metadata.signatureApprovalMemo)
  }
}

// MARK: - jsonString() Tests

extension MpcMetadataTests {
  func test_jsonString_returnsValidJSON() throws {
    // given
    let metadata = MpcMetadata(
      clientPlatform: "NATIVE_IOS",
      mpcServerVersion: "1.0.0"
    )

    // when
    let jsonString = try metadata.jsonString()

    // then
    XCTAssertFalse(jsonString.isEmpty)
    // Verify it can be decoded back
    let jsonData = jsonString.data(using: .utf8)!
    let decoded = try decoder.decode(MpcMetadata.self, from: jsonData)
    XCTAssertEqual(decoded.clientPlatform, metadata.clientPlatform)
    XCTAssertEqual(decoded.mpcServerVersion, metadata.mpcServerVersion)
  }

  func test_jsonString_includesSponsorGasWhenTrue() throws {
    // given
    var metadata = MpcMetadata(
      clientPlatform: "NATIVE_IOS",
      mpcServerVersion: "1.0.0"
    )
    metadata.sponsorGas = true

    // when
    let jsonString = try metadata.jsonString()

    // then
    XCTAssertTrue(jsonString.contains("\"sponsorGas\":true"))
    // Verify it can be decoded back
    let jsonData = jsonString.data(using: .utf8)!
    let decoded = try decoder.decode(MpcMetadata.self, from: jsonData)
    XCTAssertEqual(decoded.sponsorGas, true)
  }

  func test_jsonString_includesSponsorGasWhenFalse() throws {
    // given
    var metadata = MpcMetadata(
      clientPlatform: "NATIVE_IOS",
      mpcServerVersion: "1.0.0"
    )
    metadata.sponsorGas = false

    // when
    let jsonString = try metadata.jsonString()

    // then
    XCTAssertTrue(jsonString.contains("\"sponsorGas\":false"))
    // Verify it can be decoded back
    let jsonData = jsonString.data(using: .utf8)!
    let decoded = try decoder.decode(MpcMetadata.self, from: jsonData)
    XCTAssertEqual(decoded.sponsorGas, false)
  }

  func test_jsonString_includesSignatureApprovalMemo() throws {
    // given
    var metadata = MpcMetadata(
      clientPlatform: "NATIVE_IOS",
      mpcServerVersion: "1.0.0"
    )
    let expectedMemo = "Approve this transaction"
    metadata.signatureApprovalMemo = expectedMemo

    // when
    let jsonString = try metadata.jsonString()

    // then
    XCTAssertTrue(jsonString.contains("signatureApprovalMemo"))
    XCTAssertTrue(jsonString.contains(expectedMemo))
    // Verify it can be decoded back
    let jsonData = jsonString.data(using: .utf8)!
    let decoded = try decoder.decode(MpcMetadata.self, from: jsonData)
    XCTAssertEqual(decoded.signatureApprovalMemo, expectedMemo)
  }

  func test_jsonString_includesBothSponsorGasAndSignatureApprovalMemo() throws {
    // given
    var metadata = MpcMetadata(
      clientPlatform: "NATIVE_IOS",
      mpcServerVersion: "1.0.0"
    )
    metadata.sponsorGas = true
    metadata.signatureApprovalMemo = "Confirm gas sponsorship"

    // when
    let jsonString = try metadata.jsonString()

    // then
    XCTAssertTrue(jsonString.contains("\"sponsorGas\":true"))
    XCTAssertTrue(jsonString.contains("signatureApprovalMemo"))
    // Verify it can be decoded back
    let jsonData = jsonString.data(using: .utf8)!
    let decoded = try decoder.decode(MpcMetadata.self, from: jsonData)
    XCTAssertEqual(decoded.sponsorGas, true)
    XCTAssertEqual(decoded.signatureApprovalMemo, "Confirm gas sponsorship")
  }

  func test_jsonString_includesAllProperties() throws {
    // given
    var metadata = MpcMetadata(
      backupMethod: BackupMethods.Password.rawValue,
      chainId: "eip155:11155111",
      clientPlatform: "NATIVE_IOS",
      clientPlatformVersion: "1.2.3",
      curve: .SECP256K1,
      isMultiBackupEnabled: true,
      mpcServerVersion: "1.0.0",
      optimized: true,
      isRaw: false,
      signatureApprovalMemo: "Test memo",
      sponsorGas: true
    )

    // when
    let jsonString = try metadata.jsonString()

    // then
    let jsonData = jsonString.data(using: .utf8)!
    let decoded = try decoder.decode(MpcMetadata.self, from: jsonData)
    XCTAssertEqual(decoded.backupMethod, BackupMethods.Password.rawValue)
    XCTAssertEqual(decoded.chainId, "eip155:11155111")
    XCTAssertEqual(decoded.clientPlatform, "NATIVE_IOS")
    XCTAssertEqual(decoded.clientPlatformVersion, "1.2.3")
    XCTAssertEqual(decoded.curve, .SECP256K1)
    XCTAssertEqual(decoded.isMultiBackupEnabled, true)
    XCTAssertEqual(decoded.mpcServerVersion, "1.0.0")
    XCTAssertEqual(decoded.optimized, true)
    XCTAssertEqual(decoded.isRaw, false)
    XCTAssertEqual(decoded.signatureApprovalMemo, "Test memo")
    XCTAssertEqual(decoded.sponsorGas, true)
  }
}

// MARK: - Encoding/Decoding Tests

extension MpcMetadataTests {
  func test_encoding_decoding_preservesSponsorGasTrue() throws {
    // given
    var metadata = MpcMetadata(
      clientPlatform: "NATIVE_IOS",
      mpcServerVersion: "1.0.0"
    )
    metadata.sponsorGas = true

    // when
    let encoded = try encoder.encode(metadata)
    let decoded = try decoder.decode(MpcMetadata.self, from: encoded)

    // then
    XCTAssertEqual(decoded.sponsorGas, true)
  }

  func test_encoding_decoding_preservesSponsorGasFalse() throws {
    // given
    var metadata = MpcMetadata(
      clientPlatform: "NATIVE_IOS",
      mpcServerVersion: "1.0.0"
    )
    metadata.sponsorGas = false

    // when
    let encoded = try encoder.encode(metadata)
    let decoded = try decoder.decode(MpcMetadata.self, from: encoded)

    // then
    XCTAssertEqual(decoded.sponsorGas, false)
  }

  func test_encoding_decoding_preservesSponsorGasNil() throws {
    // given
    let metadata = MpcMetadata(
      clientPlatform: "NATIVE_IOS",
      mpcServerVersion: "1.0.0"
    )

    // when
    let encoded = try encoder.encode(metadata)
    let decoded = try decoder.decode(MpcMetadata.self, from: encoded)

    // then
    XCTAssertNil(decoded.sponsorGas)
  }

  func test_encoding_decoding_preservesSignatureApprovalMemo() throws {
    // given
    var metadata = MpcMetadata(
      clientPlatform: "NATIVE_IOS",
      mpcServerVersion: "1.0.0"
    )
    metadata.signatureApprovalMemo = "Test approval memo"

    // when
    let encoded = try encoder.encode(metadata)
    let decoded = try decoder.decode(MpcMetadata.self, from: encoded)

    // then
    XCTAssertEqual(decoded.signatureApprovalMemo, "Test approval memo")
  }
}

// MARK: - MpcMetadataError Tests

extension MpcMetadataTests {
  func test_MpcMetadataError_equatable() throws {
    // given
    let error1 = MpcMetadataError.unableToEncodeJsonString
    let error2 = MpcMetadataError.unableToEncodeJsonString

    // then
    XCTAssertEqual(error1, error2)
  }
}

