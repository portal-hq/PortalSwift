//
//  ScanSolanaCodableTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

import Foundation
@testable import PortalSwift
import XCTest

final class ScanSolanaCodableTests: XCTestCase {
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

// MARK: - ScanSolanaRequest Codable Tests

extension ScanSolanaCodableTests {
  func test_scanSolanaRequest_encodesAndDecodesCorrectly() throws {
    // Given
    let request = ScanSolanaRequest.stub()

    // When
    let data = try encoder.encode(request)
    let decoded = try decoder.decode(ScanSolanaRequest.self, from: data)

    // Then
    XCTAssertEqual(decoded.transaction.rawTransaction, request.transaction.rawTransaction)
    XCTAssertEqual(decoded.transaction.version, request.transaction.version)
    XCTAssertEqual(decoded.url, request.url)
    XCTAssertEqual(decoded.validateRecentBlockHash, request.validateRecentBlockHash)
    XCTAssertEqual(decoded.showFullFindings, request.showFullFindings)
    XCTAssertEqual(decoded.policy, request.policy)
  }

  func test_scanSolanaRequest_withAllOptionalFields() throws {
    // Given
    let message = ScanSolanaMessage.stub()
    let transaction = ScanSolanaTransaction(
      message: message,
      signatures: ["sig1", "sig2"],
      rawTransaction: "base64raw",
      version: "0"
    )
    let request = ScanSolanaRequest(
      transaction: transaction,
      url: "https://app.example.com",
      validateRecentBlockHash: true,
      showFullFindings: true,
      policy: "policy-123"
    )

    // When
    let data = try encoder.encode(request)
    let decoded = try decoder.decode(ScanSolanaRequest.self, from: data)

    // Then
    XCTAssertNotNil(decoded.transaction.message)
    XCTAssertEqual(decoded.transaction.message?.accountKeys, message.accountKeys)
    XCTAssertEqual(decoded.transaction.message?.recentBlockhash, message.recentBlockhash)
    XCTAssertEqual(decoded.transaction.signatures, ["sig1", "sig2"])
    XCTAssertEqual(decoded.transaction.rawTransaction, "base64raw")
    XCTAssertEqual(decoded.transaction.version, "0")
    XCTAssertEqual(decoded.url, "https://app.example.com")
    XCTAssertEqual(decoded.validateRecentBlockHash, true)
    XCTAssertEqual(decoded.showFullFindings, true)
    XCTAssertEqual(decoded.policy, "policy-123")
  }

  func test_scanSolanaRequest_decodesWithMinimalTransaction() throws {
    // Given: transaction with only rawTransaction
    let json = """
    {
      "transaction": {
        "rawTransaction": "AQAAAAA..."
      }
    }
    """
    let data = json.data(using: .utf8)!

    // When
    let decoded = try decoder.decode(ScanSolanaRequest.self, from: data)

    // Then
    XCTAssertNil(decoded.transaction.message)
    XCTAssertNil(decoded.transaction.signatures)
    XCTAssertEqual(decoded.transaction.rawTransaction, "AQAAAAA...")
    XCTAssertNil(decoded.transaction.version)
    XCTAssertNil(decoded.url)
  }
}

// MARK: - ScanSolanaTransaction Codable Tests

extension ScanSolanaCodableTests {
  func test_scanSolanaTransaction_encodesAndDecodesCorrectly() throws {
    // Given
    let transaction = ScanSolanaTransaction.stub(
      message: ScanSolanaMessage.stub(),
      signatures: ["sig1"],
      rawTransaction: "raw123",
      version: "0"
    )

    // When
    let data = try encoder.encode(transaction)
    let decoded = try decoder.decode(ScanSolanaTransaction.self, from: data)

    // Then
    XCTAssertNotNil(decoded.message)
    XCTAssertEqual(decoded.signatures, ["sig1"])
    XCTAssertEqual(decoded.rawTransaction, "raw123")
    XCTAssertEqual(decoded.version, "0")
  }
}

// MARK: - ScanSolanaMessage Codable Tests

extension ScanSolanaCodableTests {
  func test_scanSolanaMessage_encodesAndDecodesCorrectly() throws {
    // Given
    let message = ScanSolanaMessage.stub()

    // When
    let data = try encoder.encode(message)
    let decoded = try decoder.decode(ScanSolanaMessage.self, from: data)

    // Then
    XCTAssertEqual(decoded.accountKeys, message.accountKeys)
    XCTAssertEqual(decoded.header.numRequiredSignatures, message.header.numRequiredSignatures)
    XCTAssertEqual(decoded.instructions.count, message.instructions.count)
    XCTAssertEqual(decoded.recentBlockhash, message.recentBlockhash)
  }

  func test_scanSolanaMessage_withAddressTableLookups() throws {
    // Given
    let lookup = ScanSolanaAddressTableLookup.stub(
      accountKey: "Lookup111111111111111111111111111111111111",
      writableIndexes: [0, 1],
      readonlyIndexes: [2]
    )
    let message = ScanSolanaMessage(
      accountKeys: ["Key1", "Key2"],
      header: ScanSolanaHeader.stub(),
      instructions: [ScanSolanaInstruction.stub()],
      addressTableLookups: [lookup],
      recentBlockhash: "hash123"
    )

    // When
    let data = try encoder.encode(message)
    let decoded = try decoder.decode(ScanSolanaMessage.self, from: data)

    // Then
    XCTAssertEqual(decoded.addressTableLookups?.count, 1)
    XCTAssertEqual(decoded.addressTableLookups?[0].accountKey, "Lookup111111111111111111111111111111111111")
    XCTAssertEqual(decoded.addressTableLookups?[0].writableIndexes, [0, 1])
    XCTAssertEqual(decoded.addressTableLookups?[0].readonlyIndexes, [2])
  }
}

// MARK: - ScanSolanaHeader Codable Tests

extension ScanSolanaCodableTests {
  func test_scanSolanaHeader_encodesAndDecodesCorrectly() throws {
    // Given
    let header = ScanSolanaHeader(
      numReadonlySignedAccounts: 0,
      numReadonlyUnsignedAccounts: 1,
      numRequiredSignatures: 1
    )

    // When
    let data = try encoder.encode(header)
    let decoded = try decoder.decode(ScanSolanaHeader.self, from: data)

    // Then
    XCTAssertEqual(decoded.numReadonlySignedAccounts, 0)
    XCTAssertEqual(decoded.numReadonlyUnsignedAccounts, 1)
    XCTAssertEqual(decoded.numRequiredSignatures, 1)
  }
}

// MARK: - ScanSolanaInstruction Codable Tests

extension ScanSolanaCodableTests {
  func test_scanSolanaInstruction_encodesAndDecodesCorrectly() throws {
    // Given
    let instruction = ScanSolanaInstruction(
      accounts: [0, 1, 2],
      data: "3Bxs4HckZvMeVjXy",
      programIdIndex: 2
    )

    // When
    let data = try encoder.encode(instruction)
    let decoded = try decoder.decode(ScanSolanaInstruction.self, from: data)

    // Then
    XCTAssertEqual(decoded.accounts, [0, 1, 2])
    XCTAssertEqual(decoded.data, "3Bxs4HckZvMeVjXy")
    XCTAssertEqual(decoded.programIdIndex, 2)
  }
}

// MARK: - ScanSolanaAddressTableLookup Codable Tests

extension ScanSolanaCodableTests {
  func test_scanSolanaAddressTableLookup_encodesAndDecodesCorrectly() throws {
    // Given
    let lookup = ScanSolanaAddressTableLookup(
      accountKey: "ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL",
      writableIndexes: [0, 1],
      readonlyIndexes: [2, 3]
    )

    // When
    let data = try encoder.encode(lookup)
    let decoded = try decoder.decode(ScanSolanaAddressTableLookup.self, from: data)

    // Then
    XCTAssertEqual(decoded.accountKey, "ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL")
    XCTAssertEqual(decoded.writableIndexes, [0, 1])
    XCTAssertEqual(decoded.readonlyIndexes, [2, 3])
  }
}

// MARK: - ScanSolanaResponse Codable Tests

extension ScanSolanaCodableTests {
  func test_scanSolanaResponse_encodesAndDecodesCorrectly() throws {
    // Given
    let response = ScanSolanaResponse.stub()

    // When
    let data = try encoder.encode(response)
    let decoded = try decoder.decode(ScanSolanaResponse.self, from: data)

    // Then
    XCTAssertNotNil(decoded.data)
    XCTAssertEqual(decoded.data?.rawResponse.success, true)
    XCTAssertEqual(decoded.data?.rawResponse.data?.recommendation, "accept")
    XCTAssertNil(decoded.error)
  }

  func test_scanSolanaResponse_withError() throws {
    // Given
    let response = ScanSolanaResponse(data: nil, error: "Scan failed")

    // When
    let data = try encoder.encode(response)
    let decoded = try decoder.decode(ScanSolanaResponse.self, from: data)

    // Then
    XCTAssertNil(decoded.data)
    XCTAssertEqual(decoded.error, "Scan failed")
  }

  func test_scanSolanaResponse_withFullRiskData() throws {
    // Given
    let finding = ScanSolanaFinding.stub()
    let asset = ScanSolanaAsset.stub()
    let riskData = ScanSolanaRiskData.stub(
      recommendation: "deny",
      findings: [finding],
      involvedAssets: [asset],
      trace: [ScanSolanaTrace.stub()]
    )
    let rawResponse = ScanSolanaRawResponse.stub(data: riskData)
    let response = ScanSolanaResponse(data: ScanSolanaData(rawResponse: rawResponse), error: nil)

    // When
    let data = try encoder.encode(response)
    let decoded = try decoder.decode(ScanSolanaResponse.self, from: data)

    // Then
    XCTAssertEqual(decoded.data?.rawResponse.data?.recommendation, "deny")
    XCTAssertEqual(decoded.data?.rawResponse.data?.findings?.count, 1)
    XCTAssertEqual(decoded.data?.rawResponse.data?.involvedAssets?.count, 1)
    XCTAssertEqual(decoded.data?.rawResponse.data?.trace?.count, 1)
  }

  func test_scanSolanaResponse_decodesWithNilOptionals() throws {
    // Given
    let json = """
    {
      "data": {
        "rawResponse": {
          "success": true,
          "data": {
            "recommendation": "accept"
          }
        }
      }
    }
    """
    let data = json.data(using: .utf8)!

    // When
    let decoded = try decoder.decode(ScanSolanaResponse.self, from: data)

    // Then
    XCTAssertTrue(decoded.data?.rawResponse.success ?? false)
    XCTAssertEqual(decoded.data?.rawResponse.data?.recommendation, "accept")
    XCTAssertNil(decoded.data?.rawResponse.data?.assessmentId)
    XCTAssertNil(decoded.data?.rawResponse.data?.findings)
    XCTAssertNil(decoded.error)
  }
}

// MARK: - ScanSolanaTraceCallInputInfo (Polymorphic) Codable Tests

extension ScanSolanaCodableTests {
  func test_scanSolanaTraceCallInputInfo_decodesString() throws {
    // Given: info as string
    let json = """
    {
      "type": "transfer",
      "info": "K17Tvf"
    }
    """
    let data = json.data(using: .utf8)!

    // When
    let decoded = try decoder.decode(ScanSolanaTraceCallInput.self, from: data)

    // Then
    XCTAssertEqual(decoded.type, "transfer")
    if case .string(let value)? = decoded.info {
      XCTAssertEqual(value, "K17Tvf")
    } else {
      XCTFail("Expected .string case, got \(String(describing: decoded.info))")
    }
  }

  func test_scanSolanaTraceCallInputInfo_decodesTransferObject() throws {
    // Given: info as object
    let json = """
    {
      "type": "transfer",
      "info": {
        "source": "Src111111111111111111111111111111111111111",
        "destination": "Dst111111111111111111111111111111111111111",
        "lamports": 5000000
      }
    }
    """
    let data = json.data(using: .utf8)!

    // When
    let decoded = try decoder.decode(ScanSolanaTraceCallInput.self, from: data)

    // Then
    XCTAssertEqual(decoded.type, "transfer")
    if case .transfer(let transfer)? = decoded.info {
      XCTAssertEqual(transfer.source, "Src111111111111111111111111111111111111111")
      XCTAssertEqual(transfer.destination, "Dst111111111111111111111111111111111111111")
      XCTAssertEqual(transfer.lamports, 5_000_000)
    } else {
      XCTFail("Expected .transfer case, got \(String(describing: decoded.info))")
    }
  }

  func test_scanSolanaTraceCallInputInfo_encodesString() throws {
    // Given
    let callInput = ScanSolanaTraceCallInput(type: "transfer", info: .string("K17Tvf"))

    // When
    let data = try encoder.encode(callInput)
    let decoded = try decoder.decode(ScanSolanaTraceCallInput.self, from: data)

    // Then
    XCTAssertEqual(decoded.type, "transfer")
    if case .string(let value)? = decoded.info {
      XCTAssertEqual(value, "K17Tvf")
    } else {
      XCTFail("Expected .string case after round-trip, got \(String(describing: decoded.info))")
    }
  }

  func test_scanSolanaTraceCallInputInfo_encodesTransfer() throws {
    // Given
    let transfer = ScanSolanaTransferInfo(source: "Src", destination: "Dst", lamports: 1000)
    let callInput = ScanSolanaTraceCallInput(type: "transfer", info: .transfer(transfer))

    // When
    let data = try encoder.encode(callInput)
    let decoded = try decoder.decode(ScanSolanaTraceCallInput.self, from: data)

    // Then
    if case .transfer(let decodedTransfer)? = decoded.info {
      XCTAssertEqual(decodedTransfer.source, "Src")
      XCTAssertEqual(decodedTransfer.destination, "Dst")
      XCTAssertEqual(decodedTransfer.lamports, 1000)
    } else {
      XCTFail("Expected .transfer case after round-trip, got \(String(describing: decoded.info))")
    }
  }
}

// MARK: - ScanSolanaTrace Codable Tests

extension ScanSolanaCodableTests {
  func test_scanSolanaTrace_encodesAndDecodesCorrectly() throws {
    // Given
    let callInput = ScanSolanaTraceCallInput(type: "transfer", info: .string("K17Tvf"))
    let trace = ScanSolanaTrace.stub(
      callInput: callInput,
      extraInfo: ["key": "value"]
    )

    // When
    let data = try encoder.encode(trace)
    let decoded = try decoder.decode(ScanSolanaTrace.self, from: data)

    // Then
    XCTAssertEqual(decoded.from, trace.from)
    XCTAssertEqual(decoded.to, trace.to)
    XCTAssertEqual(decoded.callInput?.type, "transfer")
    XCTAssertEqual(decoded.extraInfo?["key"], "value")
  }
}

// MARK: - ScanSolanaTransferInfo Codable Tests

extension ScanSolanaCodableTests {
  func test_scanSolanaTransferInfo_encodesAndDecodesCorrectly() throws {
    // Given
    let info = ScanSolanaTransferInfo.stub()

    // When
    let data = try encoder.encode(info)
    let decoded = try decoder.decode(ScanSolanaTransferInfo.self, from: data)

    // Then
    XCTAssertEqual(decoded.source, info.source)
    XCTAssertEqual(decoded.destination, info.destination)
    XCTAssertEqual(decoded.lamports, info.lamports)
  }
}
