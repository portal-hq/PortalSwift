//
//  MockHttpRequester.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public class MockHttpRequester: HttpRequester {
  public func get(
    path _: String,
    headers _: [String: String],
    completion: @escaping (Result<String>) -> Void
  ) throws {
    completion(Result(data: mockBackupShare))
  }

  override func post<T: Codable>(
    path _: String,
    body: [String: Any],
    headers _: [String: String],
    requestType _: HttpRequestType,
    completion: @escaping (Result<T>) -> Void
  ) throws {
    guard let method = body["method"] as? String else {
      // Handle error scenario: method not present in request body
      return completion(Result(error: CustomError.missingMethod))
    }

    switch method {
    case "eth_blockNumber":
      let mockResponse = ETHGatewayResponse(jsonrpc: "2.0", result: "0x9100b6")
      completion(Result(data: mockResponse as! T))

    case "eth_estimateGas":
      let mockResponse = ETHGatewayResponse(jsonrpc: "2.0", result: "0x9100b6")
      completion(Result(data: mockResponse as! T))

    case "eth_call":
      let mockResponse = ETHGatewayResponse(jsonrpc: "2.0", result: "0x")
      completion(Result(data: mockResponse as! T))

    case "eth_chainId":
      let mockResponse = ETHGatewayResponse(jsonrpc: "2.0", result: "0x5")
      completion(Result(data: mockResponse as! T))

    case "eth_gasPrice":
      let mockResponse = ETHGatewayResponse(jsonrpc: "2.0", result: "0x8f")
      completion(Result(data: mockResponse as! T))

    case "eth_getBalance":
      let mockResponse = ETHGatewayResponse(jsonrpc: "2.0", result: "0x2386f26fc10000")
      completion(Result(data: mockResponse as! T))

    case "eth_getCode":
      let mockResponse = ETHGatewayResponse(jsonrpc: "2.0", result: "0x")
      completion(Result(data: mockResponse as! T))

    case "eth_getStorageAt":
      let mockResponse = ETHGatewayResponse(jsonrpc: "2.0", result: "0x0000000000000000000000000000000000000000000000000000000000000000")
      completion(Result(data: mockResponse as! T))

    case "eth_getTransactionCount":
      let mockResponse = ETHGatewayResponse(jsonrpc: "2.0", result: "0x0")
      completion(Result(data: mockResponse as! T))

    case "eth_getUncleCountByBlockNumber":
      let mockResponse = ETHGatewayResponse(jsonrpc: "2.0", result: "0x0")
      completion(Result(data: mockResponse as! T))

    case "net_version":
      let mockResponse = ETHGatewayResponse(jsonrpc: "2.0", result: "11155111")
      completion(Result(data: mockResponse as! T))

    case "eth_newBlockFilter":
      let mockResponse = ETHGatewayResponse(jsonrpc: "2.0", result: "0x6ff7bf3b8333bff8f98cd3ce0faae5ec")
      completion(Result(data: mockResponse as! T))

    case "eth_newPendingTransactionFilter":
      let mockResponse = ETHGatewayResponse(jsonrpc: "2.0", result: "0xa5fb7f743eee1ab0621f446110505b15")
      completion(Result(data: mockResponse as! T))

    case "eth_protocolVersion":
      let mockResponse = ETHGatewayResponse(jsonrpc: "2.0", result: "0x41")
      completion(Result(data: mockResponse as! T))

    case "eth_requestAccounts":
      let mockResponse = ETHGatewayResponse(jsonrpc: "2.0", result: "[\"0x49fb9ad8393c2902813ed0467fb4dcfb2748cca5\"]")
      completion(Result(data: mockResponse as! T))

    case "web3_clientVersion":
      let mockResponse = ETHGatewayResponse(jsonrpc: "2.0", result: "Geth/v1.11.5-stable-a38f4108/linux-amd64/go1.20.2")
      completion(Result(data: mockResponse as! T))

    case "web3_sha3":
      let mockResponse = ETHGatewayResponse(jsonrpc: "2.0", result: "0x47173285a8d7341e5e972fc677286384f802f8ef42a5ec5f03bbfa254cb01fad")
      completion(Result(data: mockResponse as! T))

    case "eth_getBlockTransactionCountByNumber":
      let mockResponse = ETHGatewayResponse(jsonrpc: "2.0", result: "0x22")
      completion(Result(data: mockResponse as! T))

    default:
      completion(Result(error: CustomError.unhandledMethod))
    }
  }
}

enum CustomError: Error {
  case missingMethod
  case unhandledMethod
}
