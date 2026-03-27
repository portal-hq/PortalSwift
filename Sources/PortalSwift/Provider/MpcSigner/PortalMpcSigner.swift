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
  private let presignatureSource: PresignatureSource?
  private let logger = PortalLogger.shared

  init(
    apiKey: String,
    keychain: PortalKeychainProtocol,
    mpcUrl: String = "mpc.portalhq.io",
    version: String = "v6",
    featureFlags: FeatureFlags? = nil,
    binary: Mobile? = nil,
    presignatureSource: PresignatureSource? = nil
  ) {
    self.apiKey = apiKey
    self.keychain = keychain
    self.mpcUrl = mpcUrl
    self.version = version
    self.featureFlags = featureFlags
    self.binary = binary ?? MobileWrapper()
    self.presignatureSource = presignatureSource
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
    signatureApprovalMemo: String? = nil,
    sponsorGas: Bool? = nil
  ) async throws -> String {
    var mpcMetadata = self.mpcMetadata
    mpcMetadata.curve = usingBlockchain.curve
    mpcMetadata.chainId = chainId
    mpcMetadata.isRaw = withPayload.isRaw
    mpcMetadata.signatureApprovalMemo = signatureApprovalMemo
    mpcMetadata.sponsorGas = sponsorGas

    if featureFlags?.usePresignatures == true,
       let presignature = await presignatureSource?.consumePresignature(forCurve: usingBlockchain.curve)
    {
      logger.debug("[PortalMpcSigner] Signing with presignature for \(withPayload.method?.rawValue ?? "unknown")")
      do {
        return try await signWithPresignature(
          chainId,
          withPayload: withPayload,
          andRpcUrl: andRpcUrl,
          usingBlockchain: usingBlockchain,
          presignatureData: presignature.data,
          mpcMetadata: mpcMetadata
        )
      } catch {
        logger.warn("[PortalMpcSigner] signWithPresignature failed, falling back to normal sign: \(error.localizedDescription)")
      }
    }

    logger.debug("[PortalMpcSigner] Using normal sign")

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
      mpcMetadataString,
      mpcMetadata.curve,
      isRaw: withPayload.isRaw
    )

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

    return signature
  }

  private func signWithPresignature(
    _ chainId: String,
    withPayload: PortalSignRequest,
    andRpcUrl: String,
    usingBlockchain _: PortalBlockchain,
    presignatureData: String,
    mpcMetadata: MpcMetadata
  ) async throws -> String {
    let signingShare = try await keychain?.getShare(chainId)
    let mpcMetadataString = try mpcMetadata.jsonString()

    let result = await self.binary.MobileSignWithPresignature(
      self.apiKey,
      self.mpcUrl,
      signingShare,
      presignatureData,
      withPayload.method?.rawValue ?? "",
      withPayload.params,
      withPayload.isRaw ?? false ? "" : andRpcUrl,
      withPayload.isRaw ?? false ? "" : chainId,
      mpcMetadataString,
      mpcMetadata.curve,
      isRaw: withPayload.isRaw
    )

    guard let data = result.data(using: .utf8) else {
      logger.error("[PortalMpcSigner] signWithPresignature failed: unable to parse response")
      throw PortalMpcSignerError.unableToParseSignResponse
    }

    let signResult = try JSONDecoder().decode(SignResult.self, from: data)
    if let error = signResult.error, error.isValid() {
      logger.error("[PortalMpcSigner] signWithPresignature failed: \(error.message ?? "unknown error")")
      throw PortalMpcError(error)
    }
    guard let signature = signResult.data else {
      throw PortalMpcSignerError.noSignatureFoundInSignResult
    }
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
