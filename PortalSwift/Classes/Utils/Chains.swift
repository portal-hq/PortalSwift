//
//  Chains.swift
//  PortalSwift
//
//  Created by Blake Williams on 5/8/23.
//

import Foundation

class ChainUtils {
  private static let chainIdToName: [Int:String] = [
    5: "goerli",
  ]

  private static let chainNameToId: [String:Int] = [
    "goerli": 5,
  ]

  public static func getChainIdForName(_ chainName: String) -> Int? {
    return chainNameToId[chainName]
  }

  public static func getChainNameForId(_ chainId: Int) -> String? {
    return chainIdToName[chainId]
  }
}
