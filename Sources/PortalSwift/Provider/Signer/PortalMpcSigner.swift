//
//  MpcSigner.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation
import Mpc

class PortalMpcSigner {
  private let apiKey: String
  private let keychain: PortalKeychain
  private let mpcUrl: String
  private let version: String
  private let featureFlags: FeatureFlags?
  private let binary: Mobile
  private var mpcMetadata: MpcMetadata

  init(
    apiKey: String,
    keychain: PortalKeychain,
    mpcUrl: String = "mpc.portalhq.io",
    version: String = "v6",
    featureFlags: FeatureFlags? = nil
  ) {
    self.apiKey = apiKey
    self.keychain = keychain
    self.mpcUrl = mpcUrl
    self.version = version
    self.featureFlags = featureFlags
    self.binary = MobileWrapper()
    self.mpcMetadata = MpcMetadata(
      clientPlatform: "NATIVE_IOS",
      isMultiBackupEnabled: featureFlags?.isMultiBackupEnabled,
      mpcServerVersion: self.version,
      optimized: featureFlags?.optimized ?? false
    )
  }

  init(
    apiKey: String,
    keychain: PortalKeychain,
    mpcUrl: String = "mpc.portalhq.io",
    version: String = "v6",
    featureFlags: FeatureFlags? = nil,
    binary: Mobile?
  ) {
    self.apiKey = apiKey
    self.keychain = keychain
    self.mpcUrl = mpcUrl
    self.version = version
    self.featureFlags = featureFlags
    self.binary = binary ?? MobileWrapper()
    self.mpcMetadata = MpcMetadata(
      clientPlatform: "NATIVE_IOS",
      isMultiBackupEnabled: featureFlags?.isMultiBackupEnabled,
      mpcServerVersion: self.version,
      optimized: featureFlags?.optimized ?? false
    )
  }

  public func sign(_ chainId: String, withPayload: PortalSignRequest, andRpcUrl: String) throws -> SignerResult {
    let address = try keychain.getAddress()
    switch withPayload.method {
    case .eth_accounts, .eth_requestAccounts:
      return SignerResult(accounts: [address])
    default:
      let signingShare = try keychain.getSigningShare()
      let json = try JSONEncoder().encode(withPayload.params)
      guard let params = String(data: json, encoding: .utf8) else {
        throw PortalMpcSignerError.unableToEncodeParams
      }

      let mpcMetadataString = self.mpcMetadata.jsonString() ?? ""
      let clientSignResult = self.binary.MobileSign(
        self.apiKey,
        self.mpcUrl,
        signingShare,
        withPayload.method.rawValue,
        params,
        andRpcUrl,
        chainId,
        mpcMetadataString
      )

      // Attempt to decode the sign result.
      guard let data = clientSignResult.data(using: .utf8) else {
        throw PortalMpcSignerError.unableToParseSignResponse
      }

      let signResult: SignResult = try JSONDecoder().decode(SignResult.self, from: data)
      guard signResult.error.code == 0 else {
        throw PortalMpcError(signResult.error)
      }

      // Return the sign result.
      return SignerResult(signature: signResult.data!)
    }
  }

  /// Signs a standard ETH request.
  /// - Parameters:
  ///   - payload: A normal payload whose params are of type [Any].
  ///   - provider: The provider is passed to MPC when signing.
  /// - Returns: A SignerResult.
  @available(*, deprecated, renamed: "sign", message: "Please use the chainId-specific and payload type agnostic version of sign().")
  public func sign(
    payload: ETHRequestPayload,
    provider: PortalProvider
  ) throws -> SignerResult {
    // Obtain the public address.
    let address = try keychain.getAddress()
    switch payload.method {
    case ETHRequestMethods.RequestAccounts.rawValue:
      return SignerResult(accounts: [address])
    case ETHRequestMethods.Accounts.rawValue:
      return SignerResult(accounts: [address])
    default:
      // Obtain the sign result.
      let signingShare = try keychain.getSigningShare()
      let formattedParams = try formatParams(payload: payload)

      // Stringify the MPC metadata.
      let mpcMetadataString = self.mpcMetadata.jsonString() ?? ""

      let clientSignResult = self.binary.MobileSign(
        self.apiKey,
        self.mpcUrl,
        signingShare,
        payload.method,
        formattedParams,
        provider.gatewayUrl,
        String(provider.chainId),
        mpcMetadataString
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
  @available(*, deprecated, renamed: "sign", message: "Please use the chainId-specific and payload type agnostic version of sign().")
  public func sign(
    payload: ETHTransactionPayload,
    provider: PortalProvider
  ) throws -> SignerResult {
    // Obtain the sign result.
    let signingShare = try keychain.getSigningShare()
    let formattedParams = try formatParams(payload: payload)

    // Stringify the MPC metadata.
    let mpcMetadataString = self.mpcMetadata.jsonString() ?? ""

    let clientSignResult = self.binary.MobileSign(
      self.apiKey,
      self.mpcUrl,
      signingShare,
      payload.method,
      formattedParams,
      provider.gatewayUrl,
      String(provider.chainId),
      mpcMetadataString
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

  private func formatParams(payload: ETHRequestPayload) throws -> String {
    if payload.params.count == 0 {
      throw PortalMpcSignerError.noParamsForSignRequest
    }

    let json: Data = try JSONSerialization.data(withJSONObject: payload.params, options: .prettyPrinted)
    return String(data: json, encoding: .utf8)!
  }

  private func formatParams(payload: ETHTransactionPayload) throws -> String {
    if payload.params.count == 0 {
      throw PortalMpcSignerError.noParamsForTransaction
    }

    let formattedPayload = payload.params.first!
    let json: Data = try JSONEncoder().encode(formattedPayload)
    return String(data: json, encoding: .utf8)!
  }
}

enum PortalMpcSignerError: Error, Equatable {
  case noParamsForTransaction
  case noParamsForSignRequest
  case unableToEncodeParams
  case unableToParseSignResponse
}
