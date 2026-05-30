//
//  NoahNetwork.swift
//  PortalSwift
//
//  Created by Ahmed Ragab
//

import Foundation

/// Convenience constants for the CAIP-2 chain IDs that connect-api accepts in
/// Noah `network` parameters.
///
/// The BFF validates these via the `[namespace]:[reference]` regex and then
/// translates them into Noah's internal network strings (e.g.
/// `"eip155:1"` -> `"Ethereum"`). Passing a non-CAIP-2 value (e.g. `"ethereum"`)
/// will be rejected with `Network must be a "[namespace]:[reference]"`.
public enum NoahNetwork {
  /// Ethereum mainnet — `eip155:1` -> Noah `"Ethereum"`.
  public static let ethereum = "eip155:1"
  /// Base mainnet — `eip155:8453` -> Noah `"Base"`.
  public static let base = "eip155:8453"
  /// Polygon mainnet — `eip155:137` -> Noah `"Polygon"`.
  public static let polygon = "eip155:137"
  /// Arbitrum One — `eip155:42161` -> Noah `"Arbitrum"`.
  public static let arbitrum = "eip155:42161"
  /// Optimism mainnet — `eip155:10` -> Noah `"Optimism"`.
  public static let optimism = "eip155:10"
  /// Avalanche C-Chain — `eip155:43114` -> Noah `"Avalanche"`.
  public static let avalanche = "eip155:43114"
  /// BNB Smart Chain — `eip155:56` -> Noah `"Bsc"`.
  public static let bsc = "eip155:56"
  /// Solana mainnet — `solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp` -> Noah `"Solana"`.
  public static let solana = "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp"
  /// Tron mainnet — `tron:0x2b6653dc` -> Noah `"Tron"`.
  public static let tron = "tron:0x2b6653dc"
  /// Bitcoin mainnet — `bip122:000000000019d6689c085ae165831e93` -> Noah `"Bitcoin"`.
  public static let bitcoin = "bip122:000000000019d6689c085ae165831e93"
}
