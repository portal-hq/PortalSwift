//
//  MPCSigner.swift
//  PortalSwift
//
//  Created by Blake Williams on 8/14/22.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import Foundation

struct Signature: Codable {
  var x: String
  var y: String
}

class MpcSigner {
  public var address: String = ""
  private var mpcUrl: String = "mpc.portalhq.io"
    
    
  public func sign(
    payload: ETHRequestPayload,
    provider: PortalProvider,
    completion: @escaping (_ signature: Signature?) -> Void
  ) throws -> Any {
    // TODO: Do MPC Signing with the mpc.xcframework binary
      switch (payload.method) {
      case "eth_requestAccounts":
          return [self.address]
      case "eth_accounts":
          return [self.address]
      default :
          return ""
      }
  }
}
