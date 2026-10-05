//
//  PortalMpcSigner.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import AnyCodable
import Foundation

public class PortalMpcSigner: PortalSignerProtocol {
  /// The credential behind the deprecated token-less `sign(...)` overload, and nothing else.
  ///
  /// A signer built through the designated initializer holds no credential at all: its caller
  /// (`PortalProvider`) resolves the token per request and passes it in, which is what keeps the
  /// "resolve after approval, never cache" rule enforceable in one place. Only the deprecated
  /// `init(apiKey:)` fills this, with a `StaticCredentials`, so code that still calls the
  /// token-less `sign` keeps working during the deprecation window.
  let legacyCredentials: PortalCredentials?
  private weak var keychain: PortalKeychainProtocol?
  private let mpcUrl: String
  private let version: String
  private let featureFlags: FeatureFlags?
  private let binary: Mobile
  private var mpcMetadata: MpcMetadata
  private let presignatureSource: PresignatureSource?
  private let logger = PortalLogger.shared

  /// Creates a signer that authenticates each call with the token its caller passes to
  /// `sign(..., token:)`. Pass `legacyCredentials` only to keep the deprecated token-less
  /// `sign(...)` working for a caller that has not been migrated yet.
  init(
    keychain: PortalKeychainProtocol,
    mpcUrl: String = "mpc.portalhq.io",
    version: String = "v6",
    featureFlags: FeatureFlags? = nil,
    binary: Mobile? = nil,
    presignatureSource: PresignatureSource? = nil,
    legacyCredentials: PortalCredentials? = nil
  ) {
    self.legacyCredentials = legacyCredentials
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

  /// Wraps `apiKey` in a `StaticCredentials` that only the deprecated token-less `sign(...)`
  /// consults. Non-throwing on purpose (as before): a blank key surfaces as
  /// `PortalCredentialError.unavailable` at the first token-less `sign`, not at construction.
  @available(*, deprecated, message: "Use init(keychain:mpcUrl:version:featureFlags:binary:presignatureSource:) and pass the resolved token to sign(_:withPayload:andRpcUrl:usingBlockchain:signatureApprovalMemo:sponsorGas:reqId:token:).")
  convenience init(
    apiKey: String,
    keychain: PortalKeychainProtocol,
    mpcUrl: String = "mpc.portalhq.io",
    version: String = "v6",
    featureFlags: FeatureFlags? = nil,
    binary: Mobile? = nil,
    presignatureSource: PresignatureSource? = nil
  ) {
    self.init(
      keychain: keychain,
      mpcUrl: mpcUrl,
      version: version,
      featureFlags: featureFlags,
      binary: binary,
      presignatureSource: presignatureSource,
      legacyCredentials: StaticCredentials(apiKey)
    )
  }

  /// Signs with the credential captured by the deprecated `init(apiKey:)`.
  ///
  /// Resolves `legacyCredentials` and forwards to the `token:` overload, so the two paths share
  /// one body. A signer built without legacy credentials has nothing to authenticate with and
  /// throws `PortalCredentialError.unavailable` before touching the presignature buffer or the
  /// binary.
  @available(*, deprecated, message: "Resolve the token at the call site and use sign(_:withPayload:andRpcUrl:usingBlockchain:signatureApprovalMemo:sponsorGas:reqId:token:).")
  public func sign(
    _ chainId: String,
    withPayload: PortalSignRequest,
    andRpcUrl: String,
    usingBlockchain: PortalBlockchain,
    signatureApprovalMemo: String? = nil,
    sponsorGas: Bool? = nil,
    reqId: String? = nil
  ) async throws -> String {
    guard let legacyCredentials = self.legacyCredentials else {
      throw PortalCredentialError.unavailable
    }
    let token = try PortalCredentialSupport.resolveToken(legacyCredentials)

    return try await self.sign(
      chainId,
      withPayload: withPayload,
      andRpcUrl: andRpcUrl,
      usingBlockchain: usingBlockchain,
      signatureApprovalMemo: signatureApprovalMemo,
      sponsorGas: sponsorGas,
      reqId: reqId,
      token: token
    )
  }

  /// Signs `withPayload`, presenting `token` to the MPC service for this call only.
  ///
  /// Forwards to the `idempotencyKey:` overload without a key.
  public func sign(
    _ chainId: String,
    withPayload: PortalSignRequest,
    andRpcUrl: String,
    usingBlockchain: PortalBlockchain,
    signatureApprovalMemo: String? = nil,
    sponsorGas: Bool? = nil,
    reqId: String? = nil,
    token: String
  ) async throws -> String {
    try await self.sign(
      chainId,
      withPayload: withPayload,
      andRpcUrl: andRpcUrl,
      usingBlockchain: usingBlockchain,
      signatureApprovalMemo: signatureApprovalMemo,
      sponsorGas: sponsorGas,
      reqId: reqId,
      idempotencyKey: nil,
      token: token
    )
  }

  /// Signs `withPayload`, presenting `token` to the MPC service for this call only and attaching
  /// `idempotencyKey` to the signing metadata (omitted when `nil` or when the payload is raw).
  ///
  /// When presignatures are enabled and one is available, the presignature path is tried first
  /// and most of its failures fall back to a normal sign. Two exceptions are surfaced unchanged
  /// instead: an `AUTH_FAILED` from the MPC service (the credential is dead, so a second round
  /// trip with the same token would only fail the same way, and the caller reports the rejected
  /// credential), and an idempotency rejection (`PortalMpcError.isIdempotencyRejection`), which a
  /// second attempt with the same key would only repeat. `token` is never stored on the instance,
  /// and `idempotencyKey` is never logged.
  ///
  /// - Throws: `PortalIdempotencyError.invalidKey` before anything is signed when `idempotencyKey`
  ///   breaks Portal's rules, checked as `PortalProvider` does. A raw sign's key is dropped unchecked.
  public func sign(
    _ chainId: String,
    withPayload: PortalSignRequest,
    andRpcUrl: String,
    usingBlockchain: PortalBlockchain,
    signatureApprovalMemo: String? = nil,
    sponsorGas: Bool? = nil,
    reqId: String? = nil,
    idempotencyKey: String?,
    token: String
  ) async throws -> String {
    var mpcMetadata = self.mpcMetadata
    mpcMetadata.curve = usingBlockchain.curve
    mpcMetadata.chainId = chainId
    mpcMetadata.isRaw = withPayload.isRaw
    mpcMetadata.signatureApprovalMemo = signatureApprovalMemo
    mpcMetadata.sponsorGas = sponsorGas
    mpcMetadata.reqId = reqId
    // A raw sign is never broadcast, so Portal could never settle a key sent with one. Any other key
    // is checked here as well as in `PortalProvider`, because this method is public; for a key the
    // provider already validated, this changes nothing.
    mpcMetadata.idempotencyKey = withPayload.isRaw == true ? nil : try idempotencyKey.map(validateIdempotencyKey)

    // Why the presignature attempt failed, when the normal sign below is its fallback.
    var presignatureFailure: Error?

    if self.featureFlags?.usePresignatures == true,
       let presignature = await self.presignatureSource?.consumePresignature(forCurve: usingBlockchain.curve)
    {
      self.logger.debug("[PortalMpcSigner] Signing with presignature for \(withPayload.method?.rawValue ?? "unknown")")
      do {
        return try await self.signWithPresignature(
          chainId,
          withPayload: withPayload,
          andRpcUrl: andRpcUrl,
          usingBlockchain: usingBlockchain,
          presignatureData: presignature.data,
          mpcMetadata: mpcMetadata,
          token: token
        )
      } catch let error as PortalMpcError where error.isAuthFailure {
        self.logger.error("PortalMpcSigner.sign() - The MPC service rejected the credential while signing with a presignature; not falling back to a normal sign.")
        throw error
      } catch let error as PortalMpcError where error.isIdempotencyRejection {
        self.logger.error("PortalMpcSigner.sign() - Portal rejected the request's idempotency key while signing with a presignature (id=\(error.id ?? "unknown")); not falling back to a normal sign.")
        throw error
      } catch {
        presignatureFailure = error
        self.logger.warn("[PortalMpcSigner] signWithPresignature failed, falling back to normal sign: \(error.localizedDescription)")
      }
    }

    self.logger.debug("[PortalMpcSigner] Using normal sign")

    let signingShare = try await self.keychain?.getShare(chainId)
    let mpcMetadataString = try mpcMetadata.jsonString()

    let clientSignResult = await self.binary.MobileSign(
      token,
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
      let mpcError = PortalMpcError(error)
      if mpcError.isIdempotencyRejection, let presignatureFailure = presignatureFailure {
        // The presignature attempt carried the same key, so it may be what the fallback was
        // refused over. Surface its failure, which the thrown error no longer carries.
        self.logger.warn("[PortalMpcSigner] The fallback sign was rejected with \(mpcError.id ?? "unknown") after the presignature attempt failed with \(Self.logDescription(of: presignatureFailure)); that attempt may already have used this idempotency key. Check the transaction's status before retrying with a new key.")
      }
      throw mpcError
    }
    guard let signature = signResult.data else {
      throw PortalMpcSignerError.noSignatureFoundInSignResult
    }

    return signature
  }

  /// The id and message of a `PortalMpcError`, or the type and description of any other error,
  /// for a log line. Neither carries the token or the idempotency key.
  private static func logDescription(of error: Error) -> String {
    if let mpcError = error as? PortalMpcError {
      return "id=\(mpcError.id ?? "unknown") message=\(mpcError.message ?? "unknown")"
    }
    return "\(type(of: error)): \(error.localizedDescription)"
  }

  private func signWithPresignature(
    _ chainId: String,
    withPayload: PortalSignRequest,
    andRpcUrl: String,
    usingBlockchain _: PortalBlockchain,
    presignatureData: String,
    mpcMetadata: MpcMetadata,
    token: String
  ) async throws -> String {
    let signingShare = try await self.keychain?.getShare(chainId)
    let mpcMetadataString = try mpcMetadata.jsonString()

    let result = await self.binary.MobileSignWithPresignature(
      token,
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
      self.logger.error("[PortalMpcSigner] signWithPresignature failed: unable to parse response")
      throw PortalMpcSignerError.unableToParseSignResponse
    }

    let signResult = try JSONDecoder().decode(SignResult.self, from: data)
    if let error = signResult.error, error.isValid() {
      self.logger.error("[PortalMpcSigner] signWithPresignature failed: \(error.message ?? "unknown error")")
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
