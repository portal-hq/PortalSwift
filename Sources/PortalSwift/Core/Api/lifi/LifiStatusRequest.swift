//
//  LifiStatusRequest.swift
//  PortalSwift
//
//  Created by Ahmed Ragab on 21/11/2025.
//

import Foundation

/// Used to check the status of a cross chain transfer

// MARK: - LifiStatusRequest

public struct LifiStatusRequest: Codable {
  /// The transaction hash on the sending chain, destination chain or lifi step id (required)
  public let txHash: String
  /// The bridging tool used for the transfer
  public let bridge: LifiStatusBridge?
  /// The sending chain. Can be the chain id or chain key
  public let fromChain: String?
  /// The receiving chain. Can be the chain id or chain key
  public let toChain: String?

  public init(txHash: String, bridge: LifiStatusBridge? = nil, fromChain: String? = nil, toChain: String? = nil) {
    self.txHash = txHash
    self.bridge = bridge
    self.fromChain = fromChain
    self.toChain = toChain
  }
}

/// Bridging tools supported for status check

// MARK: - LifiStatusBridge

public enum LifiStatusBridge: String, Codable {
  case hop
  case cbridge
  case celercircle
  case optimism
  case polygon
  case arbitrum
  case avalanche
  case across
  case gnosis
  case omni
  case relay
  case celerim
  case symbiosis
  case thorswap
  case squid
  case allbridge
  case mayan
  case debridge
  case chainflip
}
