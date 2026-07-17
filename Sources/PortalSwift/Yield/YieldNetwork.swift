//
//  YieldNetwork.swift
//  PortalSwift
//
//  Created by Portal Labs
//

import Foundation

/// Helpers for interpreting Yield.xyz transaction `network` strings.
///
/// Yield transaction networks are usually already CAIP-2 (e.g. `eip155:1`, `solana:...`). The
/// friendly-slug map is a fallback for the rare cases where a friendly EVM name is returned.
enum YieldNetwork {
  private static let evmSlugToCaip2: [String: String] = [
    "ethereum": "eip155:1",
    "ethereum-sepolia": "eip155:11155111",
    "ethereum-holesky": "eip155:17000",
    "ethereum-hoodi": "eip155:560048",
    "polygon": "eip155:137",
    "binance": "eip155:56",
    "bsc": "eip155:56",
    "avalanche": "eip155:43114",
    "avalanche-c": "eip155:43114",
    "arbitrum": "eip155:42161",
    "optimism": "eip155:10",
    "base": "eip155:8453",
    "gnosis": "eip155:100",
    "linea": "eip155:59144",
    "celo": "eip155:42220"
  ]

  /// Resolves a Yield network string to an EIP-155 CAIP-2 id when it is an EVM network, else nil.
  static func resolveToCaip2(_ network: String) -> String? {
    let trimmed = network.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return nil }
    if trimmed.hasPrefix("eip155:") { return trimmed }
    if trimmed.lowercased().hasPrefix("solana") { return nil }
    return evmSlugToCaip2[trimmed.lowercased()]
  }

  static func isEvm(_ network: String) -> Bool {
    resolveToCaip2(network) != nil
  }

  static func isSolana(_ network: String) -> Bool {
    network.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("solana")
  }
}
