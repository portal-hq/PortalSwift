//
//  Chains.swift
//  PortalSwift
//
//  Created by Blake Williams on 5/8/23.
//

import Foundation

class ChainUtils {
  private static let chainIdToName: [Int: String] = [
    1: "mainnet",
    5: "goerli",
    11_155_111: "sepolia",
  ]

  private static let chainNameToId: [String: Int] = [
    "mainnet": 1,
    "goerli": 5,
    "sepolia": 11_155_111,
  ]

  public static func getChainIdForName(_ chainName: String) -> Int? {
    return self.chainNameToId[chainName]
  }

  public static func getChainNameForId(_ chainId: Int) -> String? {
    return self.chainIdToName[chainId]
  }
}
