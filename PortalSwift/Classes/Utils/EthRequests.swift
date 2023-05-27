//
//  EthRequests.swift
//  PortalSwift
//
//  Created by Blake Williams on 5/8/23.
//

import Foundation

class EthRequestUtils {
  public static func numberToHexString(number: Double) -> String {
    return String(format: "0x%X", number)
  }
}
