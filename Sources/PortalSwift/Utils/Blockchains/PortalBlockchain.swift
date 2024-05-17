//
//  PortalBlockchain.swift
//
//
//  Created by Blake Williams on 3/30/24.
//

import Foundation

public class PortalBlockchain {
  static let mainnetReferences: [PortalNamespace: String] = [
    .eip155: "1",
    .solana: "5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
  ]
  static let namespaceCurves: [PortalNamespace: PortalCurve] = [
    .eip155: .SECP256K1,
    .solana: .ED25519,
  ]
  static let namespaceSignerMethods: [PortalNamespace: [PortalRequestMethod]] = [
    .eip155: [
      .eth_sendTransaction,
      .eth_sign,
      .eth_signTransaction,
      .eth_signTypedData_v3,
      .eth_signTypedData_v4,
      .personal_sign,
    ],
    .solana: [
      .sol_sendTransaction,
      .sol_simulateTransaction,
    ],
  ]

  public let curve: PortalCurve
  public let isMainnet: Bool
  public let namespace: PortalNamespace
  public let reference: String?
  private let signerMethods: [PortalRequestMethod]

  init(fromChainId: String) throws {
    let chainIdParts = fromChainId.split(separator: ":").map(String.init)
    let namespaceString = chainIdParts[0]
    let reference = chainIdParts[1]
    guard !reference.isEmpty else {
      throw PortalBlockchainError.invalidChainId(fromChainId)
    }
    guard let namespace = PortalNamespace(rawValue: namespaceString) else {
      throw PortalBlockchainError.noSupportedNamespaceForChainId(fromChainId)
    }
    guard let curve = PortalBlockchain.namespaceCurves[namespace] else {
      throw PortalBlockchainError.noSupportedCurveForChainId(fromChainId)
    }

    self.curve = curve
    self.isMainnet = reference == PortalBlockchain.mainnetReferences[namespace] ?? "NO_MAPPING_FOUND"
    self.namespace = namespace
    self.reference = reference
    self.signerMethods = PortalBlockchain.namespaceSignerMethods[namespace] ?? []
  }

  public func isMethodSupported(_ method: PortalRequestMethod) -> Bool {
    switch self.namespace {
    case .eip155:
      !method.rawValue.starts(with: "wallet_") || method == .wallet_switchEthereumChain
    default:
      true
    }
  }

  public func shouldMethodBeSigned(_ method: PortalRequestMethod) -> Bool {
    self.signerMethods.contains(method)
  }
}

enum PortalBlockchainError: Error {
  case invalidChainId(String)
  case noSupportedCurveForChainId(String)
  case noSupportedNamespaceForChainId(String)
}
