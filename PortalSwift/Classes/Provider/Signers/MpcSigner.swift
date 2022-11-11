//
//  MPCSigner.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation
import Mpc

struct Signature: Codable {
  var x: String
  var y: String
}

class MpcSigner {
  public var address: String?
  public var keychain: PortalKeychain

  private var mpcUrl: String
  
  init (
    keychain: PortalKeychain,
    mpcUrl: String = "mpc.portalhq.io"
  ) {
    self.keychain = keychain
    self.mpcUrl = mpcUrl
  }
    
    
  public func sign(
    payload: ETHRequestPayload,
    provider: PortalProvider,
    completion: @escaping (_ signature: Signature?) -> Void
  ) throws -> Any {
    switch (payload.method) {
    case "eth_requestAccounts":
        return [self.address]
    case "eth_accounts":
        return [self.address]
    default :
      let address = keychain.getAddress()
      let signingShare = keychain.getSigningShare()
      let jsonParams = try JSONSerialization.data(withJSONObject: payload.params, options: .prettyPrinted)
      
      return ClientSign(
        provider.getApiKey(),
        mpcUrl,
        signingShare,
        payload.method,
        String(data: jsonParams, encoding: .utf8),
        provider.gatewayUrl,
        String(provider.chainId)
      )
    }
  }
}
