//
//  MPCSigner.swift
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

public struct SignerResult: Codable {
  var signature: String?
  var accounts: [String]?
}

class MpcSigner {
  public var address: String?
  public var keychain: PortalKeychain
  private var mpcUrl: String
  private var version: String

  init (
    keychain: PortalKeychain,
    mpcUrl: String = "mpc.portalhq.io",
    version: String = "v1"
  ) {
    self.keychain = keychain
    self.mpcUrl = mpcUrl
    self.version = version
  }

  /// Signs a standard ETH request.
  /// - Parameters:
  ///   - payload: A normal payload whose params are of type [Any].
  ///   - provider: The provider is passed to MPC when signing.
  /// - Returns: A SignerResult.
  public func sign(
    payload: ETHRequestPayload,
    provider: PortalProvider
  ) throws -> SignerResult {
    // Obtain the public address.
    let address = try keychain.getAddress()

    switch (payload.method) {
    case ETHRequestMethods.RequestAccounts.rawValue:
      return SignerResult(accounts: [address])
    case ETHRequestMethods.Accounts.rawValue:
      return SignerResult(accounts: [address])
    default :
      // Obtain the sign result.
      let signingShare = try keychain.getSigningShare()
      let formattedParams = try formatParams(payload: payload)
      let clientSignResult = ClientSign(
        provider.getApiKey(),
        self.mpcUrl,
        signingShare,
        payload.method,
        formattedParams,
        provider.gatewayUrl,
        String(provider.chainId),
        version
      )

      // Attempt to decode the sign result.
      let jsonData = clientSignResult.data(using: .utf8)!
      let signResult: SignResult = try JSONDecoder().decode(SignResult.self, from: jsonData)
      guard signResult.error.code == 0 else {
        throw PortalMpcError(signResult.error)
      }

      // Return the sign result.
      return SignerResult(signature: signResult.data!)
    }
  }

  /// Signs a transaction request.
  /// - Parameters:
  ///   - payload: A payload whose params are of type [ETHTransactionParam].
  ///   - provider: The provider is passed to MPC when signing.
  /// - Returns: A SignerResult.
  public func sign(
    payload: ETHTransactionPayload,
    provider: PortalProvider,
    mockClientSign: Bool = false
  ) throws -> SignerResult {
    // Obtain the sign result.
    let signingShare = try keychain.getSigningShare()
    let formattedParams = try formatParams(payload: payload)
    
    var clientSignResult = mockClientSignResult
    if (!mockClientSign) {
      clientSignResult = ClientSign(
        provider.getApiKey(),
        mpcUrl,
        signingShare,
        payload.method,
        formattedParams,
        provider.gatewayUrl,
        String(provider.chainId),
        version
      )
    }

    // Attempt to decode the sign result.
    let jsonData = clientSignResult.data(using: .utf8)!
    let signResult: SignResult = try JSONDecoder().decode(SignResult.self, from: jsonData)
    guard signResult.error.code == 0 else {
      throw PortalMpcError(signResult.error)
    }

    // Return the sign result.
    return SignerResult(signature: signResult.data!)
  }

  private func formatParams(payload: ETHRequestPayload) throws -> String {
    if payload.params.count == 0 {
      return ""
    }

    let json: Data = try JSONSerialization.data(withJSONObject: payload.params, options: .prettyPrinted)
    return String(data: json, encoding: .utf8)!
  }

  private func formatParams(payload: ETHTransactionPayload) throws -> String {
    if payload.params.count == 0 {
      return ""
    }

    let formattedPayload = payload.params.first!
    let json: Data = try JSONEncoder().encode(formattedPayload)
    return String(data: json, encoding: .utf8)!
  }
}
