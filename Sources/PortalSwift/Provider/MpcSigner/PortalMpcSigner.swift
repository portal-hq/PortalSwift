//
//  PortalMpcSigner.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import AnyCodable
import Foundation

public class PortalMpcSigner: PortalSignerProtocol {
  private let apiKey: String
  private weak var keychain: PortalKeychainProtocol?
  private let mpcUrl: String
  private let version: String
  private let featureFlags: FeatureFlags?
  private let binary: Mobile
  private var mpcMetadata: MpcMetadata

  init(
    apiKey: String,
    keychain: PortalKeychainProtocol,
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
      mpcServerVersion: self.version
    )
  }

  public func sign(
    _ chainId: String,
    withPayload: PortalSignRequest,
    andRpcUrl: String,
    usingBlockchain: PortalBlockchain,
    signatureApprovalMemo: String? = nil
  ) async throws -> String {
    var mpcMetadata = self.mpcMetadata
    mpcMetadata.curve = usingBlockchain.curve
    mpcMetadata.chainId = chainId
    mpcMetadata.isRaw = withPayload.isRaw
    mpcMetadata.signatureApprovalMemo = signatureApprovalMemo

    let signingShare = try await keychain?.getShare(chainId)

    let mpcMetadataString = try mpcMetadata.jsonString()

    let clientSignResult = await self.binary.MobileSign(
      self.apiKey,
      self.mpcUrl,
      signingShare,
      withPayload.method?.rawValue ?? "",
      withPayload.params,
      withPayload.isRaw ?? false ? "" : andRpcUrl,
      withPayload.isRaw ?? false ? "" : chainId,
      mpcMetadataString
    )

    // Attempt to decode the sign result.
    guard let data = clientSignResult.data(using: .utf8) else {
      throw PortalMpcSignerError.unableToParseSignResponse
    }

    let signResult: SignResult = try JSONDecoder().decode(SignResult.self, from: data)
    if let error = signResult.error, error.isValid() {
      throw PortalMpcError(error)
    }
    guard let signature = signResult.data else {
      throw PortalMpcSignerError.noSignatureFoundInSignResult
    }

    // Return the sign result.
    return signature
  }
}

enum PortalMpcSignerError: LocalizedError, Equatable {
  case invalidParamsForMethod(String)
  case noCurveFoundForNamespace(String)
  case noNamespaceFoundForChainId(String)
  case noParamsForTransaction
  case noParamsForSignRequest
  case noSignatureFoundInSignResult
  case unableToEncodeParams
  case unableToParseSignResponse
}
