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
    provider: PortalProvider
  ) throws -> Any {
    switch (payload.method) {
    case "eth_requestAccounts":
        return [self.address]
    case "eth_accounts":
        return [self.address]
    default :
      _ = try keychain.getAddress()
      let signingShare = try keychain.getSigningShare()
      let jsonParams = try JSONSerialization.data(withJSONObject: payload.params, options: .prettyPrinted)
      
      let clientSignResult = ClientSign(
        provider.getApiKey(),
        mpcUrl,
        signingShare,
        payload.method,
        String(data: jsonParams, encoding: .utf8),
        provider.gatewayUrl,
        String(provider.chainId)
      )
      
      print("Client Sign Result", clientSignResult)
      let jsonData = clientSignResult.data(using: .utf8)!
      let signResult: SignResult = try JSONDecoder().decode(SignResult.self, from: jsonData)
      guard signResult.error == "" else {
        throw MpcError.unexpectedErrorOnSign(message: signResult.error!)
      }
      
      return signResult.data!
    }
  }
}
