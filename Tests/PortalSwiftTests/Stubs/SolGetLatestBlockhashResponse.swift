//
//  SolGetLatestBlockhashResponse.swift
//
//
//  Created by Ahmed Ragab on 24/08/2024.
//

import Foundation
@testable import PortalSwift

extension SolGetLatestBlockhashResponse {
  static func stub(
    jsonrpc: String = "2.0",
    id: Int? = nil,
    result: SolGetLatestBlockhashResult = .stub(),
    error: PortalProviderRpcResponseError? = nil
  ) -> SolGetLatestBlockhashResponse {
    return SolGetLatestBlockhashResponse(
      jsonrpc: jsonrpc,
      id: id,
      result: result,
      error: error
    )
  }
}

extension SolGetLatestBlockhashResult {
  static func stub(
    context: SolGetLatestBlockhashContext = .stub(),
    value: SolGetLatestBlockhashValue = .stub()
  ) -> SolGetLatestBlockhashResult {
    return SolGetLatestBlockhashResult(
      context: context,
      value: value
    )
  }
}

extension SolGetLatestBlockhashContext {
  static func stub(
    slot: Int = 123_456_789
  ) -> SolGetLatestBlockhashContext {
    return SolGetLatestBlockhashContext(
      slot: slot
    )
  }
}

extension SolGetLatestBlockhashValue {
  static func stub(
    blockhash: String = "4efK2zk3NtdxvriwEzX8Zm9NphxrRmVUnxv2BKKNNjjH",
    lastValidBlockHeight: Int = 7_890_123
  ) -> SolGetLatestBlockhashValue {
    return SolGetLatestBlockhashValue(
      blockhash: blockhash,
      lastValidBlockHeight: lastValidBlockHeight
    )
  }
}

extension PortalProviderRpcResponseError {
  static func stub(
    code: Int = -32000,
    message: String = "An error occurred"
  ) -> PortalProviderRpcResponseError {
    return PortalProviderRpcResponseError(
      code: code,
      message: message
    )
  }
}
