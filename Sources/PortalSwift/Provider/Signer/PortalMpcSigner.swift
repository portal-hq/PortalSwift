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

  public func sign(_ chainId: String, withPayload: PortalSignRequest, andRpcUrl: String) async throws -> SignerResult {
    guard let address = try await keychain.getAddress(chainId) else {
      throw PortalKeychain.KeychainError.noAddressesFound
    }
    switch withPayload.method {
    case .eth_accounts, .eth_requestAccounts:
      return SignerResult(accounts: [address])
    default:
      let signingShare = try await keychain.getShare(chainId)
      let json = try JSONEncoder().encode(withPayload.params)
      guard let params = String(data: json, encoding: .utf8) else {
        throw PortalMpcSignerError.unableToEncodeParams
      }

      let mpcMetadataString = try self.mpcMetadata.jsonString()
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
}

enum PortalMpcSignerError: Error, Equatable {
  case noParamsForTransaction
  case noParamsForSignRequest
  case unableToEncodeParams
  case unableToParseSignResponse
}
