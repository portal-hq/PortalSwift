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

struct SignerResult: Codable {
  var signature: String?
  var accounts: [String]?
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
    let address = try keychain.getAddress()

    switch (payload.method) {
    case ETHRequestMethods.RequestAccounts.rawValue:
      return SignerResult(accounts: [address])
    case ETHRequestMethods.Accounts.rawValue:
      return SignerResult(accounts: [address])
    default :
      let signingShare = try keychain.getSigningShare()
      let formattedPayload = try formatParams(payload: payload)

      let clientSignResult = ClientSign(
        provider.getApiKey(),
        mpcUrl,
        signingShare,
        payload.method,
        formattedPayload,
        provider.gatewayUrl,
        String(provider.chainId)
      )

      let jsonData = clientSignResult.data(using: .utf8)!
      let signResult: SignResult = try JSONDecoder().decode(SignResult.self, from: jsonData)
      guard signResult.error == "" else {
        throw MpcError.unexpectedErrorOnSign(message: signResult.error!)
      }

      return SignerResult(signature: signResult.data!)
    }
  }

  private func formatParams(payload: ETHRequestPayload) throws -> String {
    var json: Data

    if payload.params.count == 0 {
      return ""
    } else if payload.method == ETHRequestMethods.SendTransaction.rawValue {
      json = try JSONSerialization.data(withJSONObject: payload.params.first!, options: .prettyPrinted)
    } else {
      json = try JSONSerialization.data(withJSONObject: payload.params, options: .prettyPrinted)
    }

    return String(data: json, encoding: .utf8)!
  }
}
