//
//  YieldXyzPortalDependencyMock.swift
//  PortalSwift
//
//  Created by Portal Labs
//

import Foundation
@testable import PortalSwift

/// Mock of `YieldXyzPortalDependency` for testing the high-level deposit/withdraw flow.
final class YieldXyzPortalDependencyMock: YieldXyzPortalDependency {
  // Configurable behavior
  var defaultAddress: String? = "0xwalletaddress"
  var addressByChain: [String: String] = [:]
  /// Hashes returned for successive send calls (eth_sendTransaction / sol_signAndSendTransaction).
  var sendHashes: [String] = ["0xhash1", "0xhash2", "0xhash3"]
  /// EVM receipt status returned by eth_getTransactionReceipt ("0x1" success, "0x0" failure).
  var receiptStatus: String? = "0x1"
  /// When false, eth_getTransactionReceipt returns a response with a nil result (not mined yet).
  var receiptAvailable = true
  /// Solana confirmation status returned by getTransactionDetails.
  var solanaStatus = "confirmed"
  var solanaError: String?
  var solanaAvailable = true

  // Captured calls
  private(set) var sendCalls = 0
  private(set) var receiptCalls = 0
  private(set) var getAddressCalls = 0
  private(set) var getTransactionDetailsCalls = 0
  private(set) var requestedMethods: [PortalRequestMethod] = []
  private(set) var requestedChainIds: [String] = []
  private(set) var lastEthParam: ETHTransactionParam?

  func request(chainId: String, method: PortalRequestMethod, params: [Any], options _: RequestOptions?) async throws -> PortalProviderResult {
    requestedMethods.append(method)
    requestedChainIds.append(chainId)

    switch method {
    case .eth_sendTransaction:
      if let param = params.first as? ETHTransactionParam {
        lastEthParam = param
      }
      let hash = sendCalls < sendHashes.count ? sendHashes[sendCalls] : "0xhash\(sendCalls)"
      sendCalls += 1
      return PortalProviderResult(id: "1", result: hash)
    case .sol_signAndSendTransaction:
      let hash = sendCalls < sendHashes.count ? sendHashes[sendCalls] : "solhash\(sendCalls)"
      sendCalls += 1
      return PortalProviderResult(id: "1", result: hash)
    case .eth_getTransactionReceipt:
      receiptCalls += 1
      return PortalProviderResult(id: "1", result: makeReceiptResponse())
    default:
      return PortalProviderResult(id: "1", result: "")
    }
  }

  func getAddress(_ forChainId: String) async -> String? {
    getAddressCalls += 1
    return addressByChain[forChainId] ?? defaultAddress
  }

  func getTransactionDetails(chain _: String, signature _: String) async throws -> GetTransactionDetailsResponse {
    getTransactionDetailsCalls += 1
    return makeSolanaDetailsResponse()
  }

  // MARK: - Helpers

  private func makeReceiptResponse() -> EthTransactionResponse {
    guard receiptAvailable else {
      let json = "{\"jsonrpc\":\"2.0\",\"id\":1}"
      return decode(EthTransactionResponse.self, from: json)
    }
    let statusField = receiptStatus.map { ",\"status\":\"\($0)\"" } ?? ""
    let json = """
    {"jsonrpc":"2.0","id":1,"result":{"blockHash":"0xblock","blockNumber":"0x1","from":"0xwalletaddress","transactionIndex":"0x0","type":"0x2"\(statusField)}}
    """
    return decode(EthTransactionResponse.self, from: json)
  }

  private func makeSolanaDetailsResponse() -> GetTransactionDetailsResponse {
    let solanaField: String
    if solanaAvailable {
      let errorField = solanaError.map { ",\"error\":\"\($0)\"" } ?? ""
      solanaField = "\"solanaTransaction\":{\"signature\":\"sig\",\"status\":\"\(solanaStatus)\"\(errorField)}"
    } else {
      solanaField = "\"solanaTransaction\":null"
    }
    let json = """
    {"data":{\(solanaField)},"metadata":{"chainId":"solana:mainnet","signature":"sig"}}
    """
    return decode(GetTransactionDetailsResponse.self, from: json)
  }

  private func decode<T: Decodable>(_ type: T.Type, from json: String) -> T {
    // Force-unwrap is acceptable in a test mock with controlled JSON.
    // swiftlint:disable:next force_try
    try! JSONDecoder().decode(type, from: json.data(using: .utf8)!)
  }
}
