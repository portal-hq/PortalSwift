//
//  MpcSigner.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation
import Mpc

public class PortalMpcSigner {
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
    featureFlags: FeatureFlags? = nil,
    binary: Mobile? = nil
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

  public func sign(
    _ chainId: String,
    withPayload: PortalSignRequest,
    andRpcUrl: String,
    usingBlockchain: PortalBlockchain
  ) async throws -> String {
    var mpcMetadata = self.mpcMetadata
    mpcMetadata.curve = usingBlockchain.curve
    mpcMetadata.chainId = chainId

    let signingShare = try await keychain.getShare(chainId)
    let params = self.prepareParams(withPayload.method, rawParams: withPayload.params)

    let json = try JSONEncoder().encode(params)
    guard let params = String(data: json, encoding: .utf8) else {
      throw PortalMpcSignerError.unableToEncodeParams
    }
    let mpcMetadataString = try mpcMetadata.jsonString()

    print("🚧 Starting MPC sign...")
    let clientSignResult = await self.binary.MobileSign(
      self.apiKey,
      self.mpcUrl,
      signingShare,
      withPayload.method.rawValue,
      params,
      andRpcUrl,
      chainId,
      mpcMetadataString
    )

    print("✅ Finished MPC sign...")
    // Attempt to decode the sign result.
    guard let data = clientSignResult.data(using: .utf8) else {
      throw PortalMpcSignerError.unableToParseSignResponse
    }

    let signResult: SignResult = try JSONDecoder().decode(SignResult.self, from: data)
    guard signResult.error.code == 0 else {
      throw PortalMpcError(signResult.error)
    }
    guard let signature = signResult.data else {
      throw PortalMpcSignerError.noSignatureFoundInSignResult
    }

    // Return the sign result.
    return signature
  }

  func prepareParams(_ method: PortalRequestMethod, rawParams: [AnyEncodable]?) -> AnyEncodable? {
    guard let params = rawParams else {
      return AnyEncodable(rawParams)
    }

    switch method {
    case .eth_sendTransaction, .eth_sendRawTransaction, .eth_signTransaction:
      return params[0]
    default:
      return AnyEncodable(params)
    }
  }
}

enum PortalMpcSignerError: Error, Equatable {
  case noCurveFoundForNamespace(String)
  case noNamespaceFoundForChainId(String)
  case noParamsForTransaction
  case noParamsForSignRequest
  case noSignatureFoundInSignResult
  case unableToEncodeParams
  case unableToParseSignResponse
}
