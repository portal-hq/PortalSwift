//
//  MPCSigner.swift
//  PortalSwift
//
//  Created by Blake Williams on 8/14/22.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import Foundation

class MPCSigner: Signer {
    
    public var address: String = ""
    
    private var mpcUrl: String = "mpc.portalhq.io"
    
    
    public override init() {
        
        
    }
    
    
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
      
    return ""
  }
}
