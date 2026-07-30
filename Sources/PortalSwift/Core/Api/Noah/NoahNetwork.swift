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
/// Only chains present in connect-api's `CAIP2_TO_NOAH_NETWORK` map are included.
/// Passing any other value is rejected with a 400 (`PortalRequestsError.clientError`)
/// because the chain is not mapped to a Noah network.
///
/// The BFF first validates the `[namespace]:[reference]` format and then
/// translates the chain ID into Noah's internal network string (e.g.
/// `"eip155:1"` -> `"Ethereum"`). A non-CAIP-2 value (e.g. `"ethereum"`) fails
/// the format check and is rejected with a 400 as well.
///
/// Branch on the status code rather than the error message text — the wording of
/// these backend messages is not a stable API.
public enum NoahNetwork {
  /// Ethereum mainnet — `eip155:1` -> Noah `"Ethereum"`.
  public static let ethereum = "eip155:1"
  /// Ethereum Sepolia testnet — `eip155:11155111` -> Noah `"EthereumTestSepolia"`.
  /// Use with sandbox-only test assets such as `USDC_TEST`.
  public static let ethereumSepolia = "eip155:11155111"
  /// Base mainnet — `eip155:8453` -> Noah `"Base"`.
  public static let base = "eip155:8453"
  /// Base Sepolia testnet — `eip155:84532` -> Noah `"BaseTestSepolia"`.
  public static let baseSepolia = "eip155:84532"
  /// Polygon PoS mainnet — `eip155:137` -> Noah `"PolygonPos"`.
  public static let polygon = "eip155:137"
  /// Polygon Amoy testnet — `eip155:80002` -> Noah `"PolygonTestAmoy"`.
  public static let polygonAmoy = "eip155:80002"
  /// Gnosis mainnet — `eip155:100` -> Noah `"Gnosis"`.
  public static let gnosis = "eip155:100"
  /// Gnosis Chiado testnet — `eip155:10200` -> Noah `"GnosisTestChiado"`.
  public static let gnosisChiado = "eip155:10200"
  /// Solana mainnet — `solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp` -> Noah `"Solana"`.
  /// Equivalent to `solana:mainnet` on the BFF.
  public static let solana = "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp"
  /// Solana devnet — `solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1` -> Noah `"SolanaDevnet"`.
  /// Equivalent to `solana:devnet` on the BFF.
  public static let solanaDevnet = "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1"
}
