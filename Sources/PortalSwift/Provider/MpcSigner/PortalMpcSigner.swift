//
//  PortalMpcSigner.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import AnyCodable
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
      clientPlatformVersion: SDK_VERSION,
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
    let params = try self.prepareParams(withPayload.method, params: withPayload.params)

    let json = try JSONEncoder().encode(params)
    guard let params = String(data: json, encoding: .utf8) else {
      throw PortalMpcSignerError.unableToEncodeParams
    }
    let mpcMetadataString = try mpcMetadata.jsonString()

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

  func prepareParams(_ method: PortalRequestMethod, params: [AnyCodable]?) throws -> AnyCodable? {
    switch method {
    case .eth_sendTransaction, .eth_signTransaction:
      guard let params = params?[0] else {
        throw PortalMpcSignerError.noParamsForSignRequest
      }
      return params
    case .eth_sign, .personal_sign:
      guard let count = params?.count, count >= 2 else {
        throw PortalMpcSignerError.invalidParamsForMethod("\(method.rawValue) - \(String(describing: params))")
      }

      return AnyCodable([params?[0], params?[1]])
    default:
      return AnyCodable(params)
    }
  }
}

enum PortalMpcSignerError: Error, Equatable {
  case invalidParamsForMethod(String)
  case noCurveFoundForNamespace(String)
  case noNamespaceFoundForChainId(String)
  case noParamsForTransaction
  case noParamsForSignRequest
  case noSignatureFoundInSignResult
  case unableToEncodeParams
  case unableToParseSignResponse
}
