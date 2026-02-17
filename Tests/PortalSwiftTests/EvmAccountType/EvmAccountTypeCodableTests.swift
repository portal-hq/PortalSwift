//
//  EvmAccountTypeCodableTests.swift
//  PortalSwiftTests
//
//  Created by Ahmed Ragab
//

@testable import PortalSwift
import XCTest

final class EvmAccountTypeCodableTests: XCTestCase {
  let encoder = JSONEncoder()
  let decoder = JSONDecoder()

  // MARK: - EvmAccountTypeResponse Tests

  func test_evmAccountTypeResponse_decodesFullResponse() throws {
    let json = """
    {
        "data": {
            "status": "SMART_CONTRACT"
        },
        "metadata": {
            "chainId": "eip155:11155111",
            "eoaAddress": "0xf80d492e12d01fbfb4804a6194a18ca24a539ad5",
            "smartContractAddress": "0x54d37A9b7c614ac2141f6a880dA2201b45586De3"
        }
    }
    """.data(using: .utf8)!

    let decoded = try decoder.decode(EvmAccountTypeResponse.self, from: json)
    XCTAssertEqual(decoded.data.status, "SMART_CONTRACT")
    XCTAssertEqual(decoded.metadata.chainId, "eip155:11155111")
    XCTAssertEqual(decoded.metadata.eoaAddress, "0xf80d492e12d01fbfb4804a6194a18ca24a539ad5")
    XCTAssertEqual(decoded.metadata.smartContractAddress, "0x54d37A9b7c614ac2141f6a880dA2201b45586De3")
  }

  func test_evmAccountTypeResponse_decodesWithOptionalSmartContractAddress() throws {
    let json = """
    {
        "data": {
            "status": "EIP_155_EOA"
        },
        "metadata": {
            "chainId": "eip155:11155111",
            "eoaAddress": "0xf80d492e12d01fbfb4804a6194a18ca24a539ad5"
        }
    }
    """.data(using: .utf8)!

    let decoded = try decoder.decode(EvmAccountTypeResponse.self, from: json)
    XCTAssertEqual(decoded.data.status, "EIP_155_EOA")
    XCTAssertNil(decoded.metadata.smartContractAddress)
  }

  // MARK: - BuildAuthorizationListResponse Tests

  func test_buildAuthorizationListResponse_decodesCorrectly() throws {
    let json = """
    {
        "data": {
            "hash": "0x91aee67c57b66d6759640eb3beb69be6b36690ca9f0d8446fff3f9cb269a4736"
        },
        "metadata": {
            "authorization": {
                "contractAddress": "0xD3F582F6B4814E989Ee8E96bc3175320B5A540ab",
                "chainId": "0xaa36a7",
                "nonce": "0x01"
            },
            "chainId": "eip155:11155111"
        }
    }
    """.data(using: .utf8)!

    let decoded = try decoder.decode(BuildAuthorizationListResponse.self, from: json)
    XCTAssertEqual(decoded.data.hash, "0x91aee67c57b66d6759640eb3beb69be6b36690ca9f0d8446fff3f9cb269a4736")
    XCTAssertEqual(decoded.metadata.chainId, "eip155:11155111")
    XCTAssertEqual(decoded.metadata.authorization.contractAddress, "0xD3F582F6B4814E989Ee8E96bc3175320B5A540ab")
  }

  func test_buildAuthorizationListResponse_verifyHashField() throws {
    let response = BuildAuthorizationListResponse.stub()
    let data = try encoder.encode(response)
    let decoded = try decoder.decode(BuildAuthorizationListResponse.self, from: data)
    XCTAssertEqual(decoded.data.hash, response.data.hash)
  }

  // MARK: - BuildAuthorizationTransactionResponse Tests

  func test_buildAuthorizationTransactionResponse_decodesFullTransaction() throws {
    let json = """
    {
        "data": {
            "transaction": {
                "type": "eip7702",
                "from": "0xf80d492e12d01fbfb4804a6194a18ca24a539ad5",
                "to": "0xf80d492e12d01fbfb4804a6194a18ca24a539ad5",
                "value": "0x0",
                "data": "0x0",
                "nonce": "0x00",
                "chainId": "0xaa36a7",
                "authorizationList": [
                    {
                        "address": "0xD3F582F6B4814E989Ee8E96bc3175320B5A540ab",
                        "chainId": "0xaa36a7",
                        "nonce": "0x01",
                        "r": "0xe904a3405299bf569cdf8c3b54ff2db6f8eb896d2bc0eaaec544a045e37cab70",
                        "s": "0x648daa33f3189d7739f8c74a41d541718145614e91d6427d6adc3ae4566aedbd",
                        "yParity": "0x01"
                    }
                ]
            },
            "transactionHash": "0xabc123hash"
        },
        "metadata": {
            "authorization": {
                "contractAddress": "0xD3F582F6B4814E989Ee8E96bc3175320B5A540ab",
                "chainId": "0xaa36a7",
                "nonce": "0x01"
            },
            "chainId": "eip155:11155111",
            "hash": "0x91aee67c57b66d6759640eb3beb69be6b36690ca9f0d8446fff3f9cb269a4736",
            "subsidize": true
        }
    }
    """.data(using: .utf8)!

    let decoded = try decoder.decode(BuildAuthorizationTransactionResponse.self, from: json)
    XCTAssertEqual(decoded.data.transaction.type, "eip7702")
    XCTAssertEqual(decoded.data.transaction.from, "0xf80d492e12d01fbfb4804a6194a18ca24a539ad5")
    XCTAssertEqual(decoded.data.transaction.authorizationList?.count, 1)
    XCTAssertEqual(decoded.data.transaction.authorizationList?[0].address, "0xD3F582F6B4814E989Ee8E96bc3175320B5A540ab")
    XCTAssertEqual(decoded.data.transactionHash, "0xabc123hash")
    XCTAssertEqual(decoded.metadata?.subsidize, true)
  }

  func test_buildAuthorizationTransactionResponse_decodesWithOptionalFields() throws {
    let json = """
    {
        "data": {
            "transaction": {
                "from": "0xfrom",
                "to": "0xto"
            }
        }
    }
    """.data(using: .utf8)!

    let decoded = try decoder.decode(BuildAuthorizationTransactionResponse.self, from: json)
    XCTAssertNil(decoded.data.transaction.type)
    XCTAssertEqual(decoded.data.transaction.from, "0xfrom")
    XCTAssertEqual(decoded.data.transaction.to, "0xto")
    XCTAssertNil(decoded.data.transaction.authorizationList)
    XCTAssertNil(decoded.data.transactionHash)
    XCTAssertNil(decoded.metadata)
  }

  func test_buildAuthorizationTransactionResponse_decodesMetadataWithoutHash() throws {
    let json = """
    {
        "data": {
            "transaction": {
                "type": "eip7702",
                "from": "0xf80d492e12d01fbfb4804a6194a18ca24a539ad5",
                "to": "0xf80d492e12d01fbfb4804a6194a18ca24a539ad5",
                "value": "0x0",
                "data": "0x0",
                "nonce": "0x00",
                "chainId": "0xaa36a7",
                "authorizationList": [
                    {
                        "address": "0xD3F582F6B4814E989Ee8E96bc3175320B5A540ab",
                        "chainId": "0xaa36a7",
                        "nonce": "0x01",
                        "r": "0xe904a3405299bf569cdf8c3b54ff2db6f8eb896d2bc0eaaec544a045e37cab70",
                        "s": "0x648daa33f3189d7739f8c74a41d541718145614e91d6427d6adc3ae4566aedbd",
                        "yParity": "0x01"
                    }
                ],
                "gasLimit": "0x1819b",
                "maxFeePerGas": "0x01fc1cd261",
                "maxPriorityFeePerGas": "0x15f5d5"
            }
        },
        "metadata": {
            "authorization": {
                "contractAddress": "0xD3F582F6B4814E989Ee8E96bc3175320B5A540ab",
                "chainId": "0xaa36a7",
                "nonce": "0x01"
            },
            "chainId": "eip155:11155111"
        }
    }
    """.data(using: .utf8)!

    let decoded = try decoder.decode(BuildAuthorizationTransactionResponse.self, from: json)
    XCTAssertNotNil(decoded.metadata)
    XCTAssertNil(decoded.metadata?.hash)
    XCTAssertNil(decoded.metadata?.signature)
    XCTAssertNil(decoded.metadata?.subsidize)
    XCTAssertEqual(decoded.metadata?.chainId, "eip155:11155111")
    XCTAssertEqual(decoded.data.transaction.gasLimit, "0x1819b")
    XCTAssertEqual(decoded.data.transaction.maxFeePerGas, "0x01fc1cd261")
    XCTAssertEqual(decoded.data.transaction.maxPriorityFeePerGas, "0x15f5d5")
  }

  func test_buildAuthorizationTransactionRequest_encodesCorrectly() throws {
    let request = BuildAuthorizationTransactionRequest.stub(signature: "abc123sig", subsidize: true)
    let data = try encoder.encode(request)
    let decoded = try decoder.decode(BuildAuthorizationTransactionRequest.self, from: data)
    XCTAssertEqual(decoded.signature, "abc123sig")
    XCTAssertEqual(decoded.subsidize, true)
  }

  func test_buildAuthorizationTransactionRequest_encodesWithNilSubsidize() throws {
    let request = BuildAuthorizationTransactionRequest(signature: "sig123", subsidize: nil)
    let data = try encoder.encode(request)
    let decoded = try decoder.decode(BuildAuthorizationTransactionRequest.self, from: data)
    XCTAssertEqual(decoded.signature, "sig123")
    XCTAssertNil(decoded.subsidize)
  }
}
