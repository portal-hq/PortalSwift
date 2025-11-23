//
//  LifiStatusRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 21/11/2025.
//

import Foundation

/// Used to check the status of a cross chain transfer
// MARK: - LifiStatusRequest
struct LifiStatusRequest: Codable {
    /// The transaction hash on the sending chain, destination chain or lifi step id (required)
    let txHash: String
    /// The bridging tool used for the transfer
    let bridge: LifiStatusBridge?
    /// The sending chain. Can be the chain id or chain key
    let fromChain: String?
    /// The receiving chain. Can be the chain id or chain key
    let toChain: String?
}

/// Bridging tools supported for status check
// MARK: - LifiStatusBridge
enum LifiStatusBridge: String, Codable {
    case hop = "hop"
    case cbridge = "cbridge"
    case celercircle = "celercircle"
    case optimism = "optimism"
    case polygon = "polygon"
    case arbitrum = "arbitrum"
    case avalanche = "avalanche"
    case across = "across"
    case gnosis = "gnosis"
    case omni = "omni"
    case relay = "relay"
    case celerim = "celerim"
    case symbiosis = "symbiosis"
    case thorswap = "thorswap"
    case squid = "squid"
    case allbridge = "allbridge"
    case mayan = "mayan"
    case debridge = "debridge"
    case chainflip = "chainflip"
}
