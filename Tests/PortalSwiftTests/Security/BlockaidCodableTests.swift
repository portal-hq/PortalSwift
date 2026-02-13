//
//  BlockaidCodableTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

@testable import PortalSwift
import XCTest

final class BlockaidCodableTests: XCTestCase {
  let encoder = JSONEncoder()
  let decoder = JSONDecoder()

  // MARK: - EVM Request Tests

  func test_blockaidScanEVMRequest_encodesAndDecodesCorrectly() throws {
    let request = BlockaidScanEVMRequest.stub()

    let data = try encoder.encode(request)
    let decoded = try decoder.decode(BlockaidScanEVMRequest.self, from: data)

    XCTAssertEqual(decoded.chain, request.chain)
    XCTAssertEqual(decoded.data.from, request.data.from)
  }

  func test_blockaidScanEVMRequest_withAllOptions() throws {
    let request = BlockaidScanEVMRequest(
      chain: "eip155:1",
      metadata: BlockaidScanEVMMetadata(domain: "https://test.com"),
      data: BlockaidScanEVMTransactionData(
        from: "0x123",
        to: "0x456",
        data: "0xabcd",
        value: "0x1000",
        gas: "21000",
        gasPrice: "20000000000"
      ),
      options: [.simulation, .validation, .gasEstimation],
      block: "12345678"
    )

    let data = try encoder.encode(request)
    let decoded = try decoder.decode(BlockaidScanEVMRequest.self, from: data)

    XCTAssertEqual(decoded.options?.count, 3)
    XCTAssertEqual(decoded.block, "12345678")
    XCTAssertEqual(decoded.metadata?.domain, "https://test.com")
  }

  // MARK: - EVM Response Tests

  func test_blockaidScanEVMResponse_decodesValidationResponse() throws {
    let json = """
    {
      "data": {
        "rawResponse": {
          "validation": {
            "status": "Success",
            "result_type": "Malicious",
            "classification": "known_malicious",
            "reason": "raw_ether_transfer",
            "description": "Transfers to known malicious address",
            "features": [{
              "type": "Malicious",
              "feature_id": "KNOWN_MALICIOUS_ADDRESS",
              "description": "Known malicious"
            }]
          },
          "block": "21211118",
          "chain": "eip155:1"
        }
      }
    }
    """.data(using: .utf8)!

    let decoded = try decoder.decode(BlockaidScanEVMResponse.self, from: json)

    XCTAssertEqual(decoded.data?.rawResponse.validation?.resultType, "Malicious")
    XCTAssertEqual(decoded.data?.rawResponse.validation?.features?.count, 1)
    XCTAssertEqual(decoded.data?.rawResponse.chain, "eip155:1")
  }

  func test_blockaidScanEVMResponse_decodesFullSimulation() throws {
    let response = BlockaidScanEVMResponse.stub(
      data: .stub(rawResponse: .stub(
        simulation: .stub(status: "Success")
      ))
    )

    let data = try encoder.encode(response)
    let decoded = try decoder.decode(BlockaidScanEVMResponse.self, from: data)

    XCTAssertNotNil(decoded.data?.rawResponse.simulation)
    XCTAssertEqual(decoded.data?.rawResponse.simulation?.status, "Success")
  }

  // MARK: - Solana Request Tests

  func test_blockaidScanSolanaRequest_encodesAndDecodesCorrectly() throws {
    let request = BlockaidScanSolanaRequest.stub()

    let data = try encoder.encode(request)
    let decoded = try decoder.decode(BlockaidScanSolanaRequest.self, from: data)

    XCTAssertEqual(decoded.accountAddress, request.accountAddress)
    XCTAssertEqual(decoded.transactions.count, request.transactions.count)
  }

  func test_blockaidScanSolanaRequest_withMultipleTransactions() throws {
    let request = BlockaidScanSolanaRequest(
      accountAddress: "86xCnPeV69n6t3DnyGvkKobf9FdN2H9oiVDdaMpo2MMY",
      transactions: ["tx1", "tx2", "tx3"],
      metadata: BlockaidScanSolanaMetadata(url: "https://test.com"),
      encoding: .base58,
      chain: "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
      options: [.simulation, .validation],
      method: "signAndSendTransaction"
    )

    let data = try encoder.encode(request)
    let decoded = try decoder.decode(BlockaidScanSolanaRequest.self, from: data)

    XCTAssertEqual(decoded.transactions.count, 3)
    XCTAssertEqual(decoded.encoding, .base58)
  }

  // MARK: - Solana Response Tests

  func test_blockaidScanSolanaResponse_decodesWithExtendedFeatures() throws {
    let json = """
    {
      "data": {
        "rawResponse": {
          "encoding": "base58",
          "status": "SUCCESS",
          "result": {
            "validation": {
              "result_type": "Malicious",
              "reason": "transfer_farming",
              "features": ["Known malicious"],
              "extended_features": [{
                "type": "Malicious",
                "feature_id": "KNOWN_MALICIOUS_ADDRESS",
                "description": "Malicious activity"
              }]
            }
          }
        }
      }
    }
    """.data(using: .utf8)!

    let decoded = try decoder.decode(BlockaidScanSolanaResponse.self, from: json)

    XCTAssertEqual(decoded.data?.rawResponse.result?.validation?.resultType, "Malicious")
    XCTAssertEqual(decoded.data?.rawResponse.result?.validation?.extendedFeatures?.count, 1)
  }

  // MARK: - Address Request Tests

  func test_blockaidScanAddressRequest_encodesAndDecodesCorrectly() throws {
    let request = BlockaidScanAddressRequest.stub()

    let data = try encoder.encode(request)
    let decoded = try decoder.decode(BlockaidScanAddressRequest.self, from: data)

    XCTAssertEqual(decoded.address, request.address)
    XCTAssertEqual(decoded.chain, request.chain)
  }

  func test_blockaidScanAddressRequest_withMetadata() throws {
    let request = BlockaidScanAddressRequest(
      address: "0x123",
      chain: "eip155:1",
      metadata: BlockaidScanAddressMetadata(domain: "https://test.com")
    )

    let data = try encoder.encode(request)
    let decoded = try decoder.decode(BlockaidScanAddressRequest.self, from: data)

    XCTAssertEqual(decoded.metadata?.domain, "https://test.com")
  }

  // MARK: - Address Response Tests

  func test_blockaidScanAddressResponse_decodesEVMFeatures() throws {
    let json = """
    {
      "data": {
        "rawResponse": {
          "result_type": "Malicious",
          "features": [{
            "type": "Malicious",
            "feature_id": "KNOWN_MALICIOUS",
            "description": "Known malicious"
          }]
        }
      }
    }
    """.data(using: .utf8)!

    let decoded = try decoder.decode(BlockaidScanAddressResponse.self, from: json)

    XCTAssertEqual(decoded.data?.rawResponse.resultType, "Malicious")
    XCTAssertEqual(decoded.data?.rawResponse.features?.count, 1)
  }

  // MARK: - Tokens Request Tests

  func test_blockaidScanTokensRequest_encodesAndDecodesCorrectly() throws {
    let request = BlockaidScanTokensRequest.stub()

    let data = try encoder.encode(request)
    let decoded = try decoder.decode(BlockaidScanTokensRequest.self, from: data)

    XCTAssertEqual(decoded.chain, request.chain)
    XCTAssertEqual(decoded.tokens.count, request.tokens.count)
  }

  // MARK: - Tokens Response Tests

  func test_blockaidScanTokensResponse_decodesMultipleResults() throws {
    let json = """
    {
      "data": {
        "rawResponse": {
          "results": {
            "0xtoken1": {
              "result_type": "Benign",
              "chain": "eip155:1",
              "address": "0xtoken1"
            },
            "0xtoken2": {
              "result_type": "Malicious",
              "malicious_score": "1.0",
              "chain": "eip155:1",
              "address": "0xtoken2"
            }
          }
        }
      }
    }
    """.data(using: .utf8)!

    let decoded = try decoder.decode(BlockaidScanTokensResponse.self, from: json)

    XCTAssertEqual(decoded.data?.rawResponse.results.count, 2)
    XCTAssertEqual(decoded.data?.rawResponse.results["0xtoken1"]?.resultType, "Benign")
    XCTAssertEqual(decoded.data?.rawResponse.results["0xtoken2"]?.resultType, "Malicious")
  }

  // MARK: - URL Request Tests

  func test_blockaidScanURLRequest_encodesAndDecodesCorrectly() throws {
    let request = BlockaidScanURLRequest.stub()

    let data = try encoder.encode(request)
    let decoded = try decoder.decode(BlockaidScanURLRequest.self, from: data)

    XCTAssertEqual(decoded.url, request.url)
  }

  func test_blockaidScanURLRequest_withCatalogMetadata() throws {
    let request = BlockaidScanURLRequest(
      url: "https://app.uniswap.org",
      metadata: BlockaidScanURLMetadata(type: .catalog)
    )

    let data = try encoder.encode(request)
    let decoded = try decoder.decode(BlockaidScanURLRequest.self, from: data)

    XCTAssertEqual(decoded.metadata?.type, .catalog)
  }

  // MARK: - URL Response Tests

  func test_blockaidScanURLResponse_decodesHitStatus() throws {
    let json = """
    {
      "data": {
        "rawResponse": {
          "status": "hit",
          "url": "https://app.uniswap.org",
          "is_reachable": true,
          "is_web3_site": true,
          "is_malicious": false,
          "malicious_score": 0
        }
      }
    }
    """.data(using: .utf8)!

    let decoded = try decoder.decode(BlockaidScanURLResponse.self, from: json)

    XCTAssertEqual(decoded.data?.rawResponse.status, "hit")
    XCTAssertEqual(decoded.data?.rawResponse.isMalicious, false)
    XCTAssertEqual(decoded.data?.rawResponse.isWeb3Site, true)
  }

  func test_blockaidScanURLResponse_decodesMissStatus() throws {
    let json = """
    {
      "data": {
        "rawResponse": {
          "status": "miss"
        }
      }
    }
    """.data(using: .utf8)!

    let decoded = try decoder.decode(BlockaidScanURLResponse.self, from: json)

    XCTAssertEqual(decoded.data?.rawResponse.status, "miss")
  }
}
