//
//  PasskeyPrfStorage.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2026 Portal Labs, Inc. All rights reserved.
//

import AuthenticationServices
import Foundation
import Security

/// A backup storage whose encryption secret is derived on demand rather than stored.
///
/// `PortalMpc` asks it for the secret with `enroll()` before the MPC backup runs, encrypts the
/// backup shares with that secret through the password cipher, and reads it back with `read()`
/// when recovering. Nothing is written by `write(_:)`.
public protocol PortalDerivedSecretStorage: PortalStorage {
  /// Returns the secret to back up with, creating whatever it is derived from if needed.
  func enroll() async throws -> String
  /// Encrypts `value` with a secret `enroll()` returned.
  func encrypt(_ value: String, withSecret secret: String) async throws -> String
}

public extension PortalDerivedSecretStorage {
  /// The password cipher, keyed by the derived secret.
  func encrypt(_ value: String, withSecret secret: String) async throws -> String {
    try await self.encryption.encrypt(value, withPassword: secret)
  }
}

public enum PasskeyPrfStorageError: LocalizedError, Equatable {
  /// The storage was used before `Portal` attached its API to it.
  case notAttachedToPortal
  /// The `PortalApiProtocol` implementation attached does not support Passkey PRF records.
  case apiUnsupported
  /// `delete()` is not supported: forgetting the passkey would strand every backup made with it.
  case deleteNotSupported

  public var errorDescription: String? {
    switch self {
    case .notAttachedToPortal:
      return "[Portal] PasskeyPrfStorage is not attached to a Portal instance. Register it with `portal.registerBackupMethod(.PasskeyPrf, withStorage:)`."
    case .apiUnsupported:
      return "[Portal] The attached PortalApiProtocol does not support Passkey PRF credentials."
    case .deleteNotSupported:
      return "[Portal] PasskeyPrfStorage does not support delete."
    }
  }
}

/// Backs up with a secret derived from a passkey through the WebAuthn PRF extension
/// (`BackupMethods.PasskeyPrf`, wire value `PASSKEY_PRF`).
///
/// The secret is the lowercase hex of the 32-byte PRF output for Portal's fixed salt, and is
/// used exactly like a backup password, so a backup made with this storage can be recovered by
/// the React Native and web SDKs from the same passkey under the same relying party, and the
/// other way around. The passkey provider recomputes the secret each time it is needed; it is
/// never stored, by this storage or by Portal. Portal stores only which passkey the client
/// enrolled (`PasskeyPrfCredential`).
///
/// Requires iOS 18, an `ASPresentationAnchor`, and an app associated with the relying party's
/// domain through the `webcredentials` Associated Domains entitlement.
@available(iOS 18.0, *)
public class PasskeyPrfStorage: Storage, PortalDerivedSecretStorage {
  public weak var api: PortalApiProtocol?
  public let encryption: PortalEncryptionProtocol

  /// The relying party ID passkeys are created and asserted under, lowercase and trimmed.
  public let relyingParty: String
  /// The relying party name, used for the default user name.
  public let relyingPartyName: String
  /// The user the passkey is created for. Defaults to `"<custodian name> Backup (PRF)"`.
  public let user: PasskeyPrfUser?

  /// The window passkey prompts are presented from.
  public var anchor: ASPresentationAnchor? {
    get { self.webAuthnClient.anchor }
    set { self.webAuthnClient.anchor = newValue }
  }

  let webAuthnClient: PasskeyPrfWebAuthnClient
  private let logger = PortalLogger.shared
  private let isPlatformSupported: () -> Bool
  /// Waits the given number of milliseconds between store attempts.
  private let sleep: (_ milliseconds: UInt64) async throws -> Void

  static let storeAttempts = PasskeyPrfConstants.storeRetryDelaysMs.count + 1

  /// - Parameters:
  ///   - relyingParty: The relying party ID. Defaults to `portalhq.io`. It must match the one the
  ///     backup was enrolled under on any platform, and the app must be associated with it.
  ///   - relyingPartyName: Defaults to `Portal`.
  ///   - user: The user the passkey is created for. Defaults to `"<custodian name> Backup (PRF)"`.
  ///   - anchor: The window passkey prompts are presented from. Can also be set later through
  ///     `anchor` or `portal.setPasskeyAuthenticationAnchor(_:)`.
  ///   - encryption: The cipher the secret is used with. Defaults to Portal's password cipher.
  public convenience init(
    relyingParty: String? = nil,
    relyingPartyName: String? = nil,
    user: PasskeyPrfUser? = nil,
    anchor: ASPresentationAnchor? = nil,
    encryption: PortalEncryptionProtocol? = nil
  ) {
    self.init(
      relyingParty: relyingParty,
      relyingPartyName: relyingPartyName,
      user: user,
      encryption: encryption,
      webAuthnClient: PasskeyPrfAuthorizationClient(anchor: anchor)
    )
  }

  /// Test seam: injects the WebAuthn client, the platform check and the store retry wait.
  init(
    relyingParty: String? = nil,
    relyingPartyName: String? = nil,
    user: PasskeyPrfUser? = nil,
    encryption: PortalEncryptionProtocol? = nil,
    webAuthnClient: PasskeyPrfWebAuthnClient,
    isPlatformSupported: @escaping () -> Bool = { PasskeyPrfStorage.platformSupportsPrf() },
    sleep: @escaping (_ milliseconds: UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0 * 1_000_000) }
  ) {
    self.relyingParty = Self.normalizeRelyingParty(relyingParty)
    let name = relyingPartyName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    self.relyingPartyName = name.isEmpty ? PasskeyPrfConstants.defaultRelyingPartyName : name
    self.user = user
    self.encryption = encryption ?? PortalEncryption()
    self.webAuthnClient = webAuthnClient
    self.isPlatformSupported = isPlatformSupported
    self.sleep = sleep
  }

  /*******************************************
   * Public functions
   *******************************************/

  /// Returns the secret to back up with, creating the client's passkey if it does not have one
  /// yet.
  public func enroll() async throws -> String {
    try self.assertSupported()
    let api = try self.requireApi()

    if let existing = try await api.getPasskeyPrfCredential(traceId: nil) {
      try self.assertRelyingParty(existing)
      return try await self.deriveSecret(existing)
    }

    let user = try await self.resolveUser(api)
    var created = try await self.createPasskey(user: user)
    // Hold the creation output only until Portal settles the permanent credential binding.
    defer { Self.zero(&created.prfOutput) }

    let credential: PasskeyPrfCredential
    do {
      credential = try await self.storeCredential(
        api,
        PasskeyPrfCredential(credentialId: created.credentialId, rpId: self.relyingParty, transports: created.transports)
      )
    } catch {
      guard Self.httpStatus(of: error) == 409 else {
        throw error
      }
      // Another enrollment won. Never use the losing credential's output.
      self.logger.info("[PasskeyPrfStorage] Another enrollment stored its passkey first; deriving the secret from that one.")
      Self.zero(&created.prfOutput)
      return try await self.read()
    }

    try self.assertRelyingParty(credential)
    if credential.credentialId != created.credentialId {
      // Do not use creation bytes if the server returns another binding.
      Self.zero(&created.prfOutput)
      return try await self.deriveSecret(credential)
    }

    // The server accepted this credential: reuse its PRF output without asking for another
    // assertion just to compute the same secret.
    return Self.takeSecret(&created.prfOutput)
  }

  /// Returns the secret an existing backup was made with. Never creates a passkey: one created
  /// now could not decrypt a backup made earlier.
  public func read() async throws -> String {
    try self.assertSupported()
    let api = try self.requireApi()

    guard let credential = try await api.getPasskeyPrfCredential(traceId: nil) else {
      throw PortalPasskeyPrfError(.credentialNotFound)
    }

    try self.assertRelyingParty(credential)
    return try await self.deriveSecret(credential)
  }

  /// Encrypts with a freshly enrolled secret. `PortalMpc` enrolls before the MPC backup runs
  /// and calls `encrypt(_:withSecret:)` instead; this exists for direct callers.
  public func encrypt(_ value: String) async throws -> EncryptData {
    let secret = try await self.enroll()
    let cipherText = try await self.encrypt(value, withSecret: secret)
    return EncryptData(key: secret, cipherText: cipherText)
  }

  /// Encrypts with the password cipher, keyed by the PRF secret.
  public func encrypt(_ value: String, withSecret secret: String) async throws -> String {
    try await self.encryption.encrypt(value, withPassword: secret)
  }

  /// Decrypts with the password cipher. The passkey already answered, and an answer from any
  /// passkey but the enrolled one is rejected, so a cipher failure usually means a ciphertext
  /// that was not made with this method (or is corrupt): reported as `PRF_DECRYPT_FAILED`.
  public func decrypt(_ value: String, withKey: String) async throws -> String {
    do {
      return try await self.encryption.decrypt(value, withPassword: withKey)
    } catch let error as PortalMpcError {
      throw PortalPasskeyPrfError(.decryptFailed, cause: error)
    }
  }

  /// Not supported: the enrolled passkey is what a backup made with it is recovered from, so
  /// forgetting it would strand that backup.
  public func delete() async throws -> Bool {
    throw PasskeyPrfStorageError.deleteNotSupported
  }

  /// Throws `PRF_NOT_SUPPORTED` rather than returning `false`, so `PortalMpc.backup` reports why
  /// instead of a generic validation failure.
  public func validateOperations() async throws -> Bool {
    try self.assertSupported()
    return true
  }

  /// Nothing to store: the secret comes from the passkey, not from Portal. Kept so the storage
  /// can be registered like every other backup method.
  public func write(_: String) async throws -> Bool {
    true
  }

  /*******************************************
   * Internal functions
   *******************************************/

  /// iOS 18 is required for the PRF extension; a device that does not run it never reaches
  /// this type. Kept as a function so the check stays in one place if the floor moves.
  static func platformSupportsPrf() -> Bool {
    ProcessInfo.processInfo.isOperatingSystemAtLeast(
      OperatingSystemVersion(majorVersion: PasskeyPrfConstants.minimumIOSMajorVersion, minorVersion: 0, patchVersion: 0)
    )
  }

  static func normalizeRelyingParty(_ value: String?) -> String {
    // DNS names are case-insensitive; Portal keeps the canonical lowercase form.
    let normalized = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized.isEmpty ? PasskeyPrfConstants.defaultRelyingParty : normalized
  }

  /// The HTTP status of an error from Portal's API client, when it carries one.
  static func httpStatus(of error: Error) -> Int? {
    guard let requestError = error as? PortalRequestsError else {
      return nil
    }
    switch requestError {
    case .unauthorized:
      return 401
    default:
      return requestError.statusCode
    }
  }

  /// Server-side or network failures; a 4xx or an unusable credential would only repeat.
  static func isTransient(_ error: Error) -> Bool {
    if error is PortalCredentialError {
      return false
    }
    if let requestError = error as? PortalRequestsError {
      if case .couldNotParseHttpResponse = requestError {
        return true
      }
      guard let status = httpStatus(of: requestError) else {
        return true
      }
      return status >= 500 || status == 429
    }
    if error is URLError {
      return true
    }
    return false
  }

  /*******************************************
   * Private functions
   *******************************************/

  /// The record is write-once and the PUT is idempotent for the same credential, so a transient
  /// failure is retried, after `PasskeyPrfConstants.storeRetryDelaysMs`, rather than left to
  /// orphan the passkey that was just created. If every attempt fails, one read tells whether an
  /// earlier attempt landed after all.
  private func storeCredential(_ api: PortalApiProtocol, _ credential: PasskeyPrfCredential) async throws -> PasskeyPrfCredential {
    var lastError: Error?
    for attempt in 0 ..< Self.storeAttempts {
      if attempt > 0 {
        try await self.sleep(PasskeyPrfConstants.storeRetryDelaysMs[attempt - 1])
      }
      do {
        return try await api.storePasskeyPrfCredential(credential, traceId: nil)
      } catch {
        guard Self.isTransient(error) else {
          throw error
        }
        lastError = error
      }
    }

    if let stored = try? await api.getPasskeyPrfCredential(traceId: nil) {
      return stored
    }
    throw lastError ?? PortalPasskeyPrfError(.ceremonyFailed)
  }

  private func createPasskey(user: PasskeyPrfUser) async throws -> (credentialId: String, transports: [String]?, prfOutput: Data?) {
    let salt = PasskeyPrfConstants.salt
    let created = try await self.runCeremony {
      try await self.webAuthnClient.createCredential(
        PasskeyPrfCreateRequest(
          rpId: self.relyingParty,
          userId: try Self.randomBytes(32),
          userName: user.name,
          userDisplayName: user.displayName,
          challenge: try Self.randomBytes(32),
          prfSalt: salt
        )
      )
    }
    var prfOutput = created.prfOutput

    if prfOutput == nil, !created.prfEnabled {
      throw PortalPasskeyPrfError(.notSupported, context: "The passkey provider did not enable PRF for the new passkey.")
    }
    if let output = prfOutput, output.count != PasskeyPrfConstants.outputLength {
      Self.zero(&prfOutput)
      throw PortalPasskeyPrfError(.notSupported, context: "The passkey provider returned a PRF output that is not 32 bytes.")
    }

    let credentialId = PasskeyPrfEncoding.base64Url(created.credentialId)
    if prfOutput == nil {
      // Some providers enable PRF at creation but only evaluate it on assertion.
      prfOutput = try await self.assertPrf(credentialId: credentialId)
    }

    return (credentialId, created.transports, prfOutput)
  }

  private func deriveSecret(_ credential: PasskeyPrfCredential) async throws -> String {
    var output: Data? = try await self.assertPrf(credentialId: credential.credentialId)
    return Self.takeSecret(&output)
  }

  /// Runs one assertion restricted to `credentialId` and returns its 32-byte PRF output.
  private func assertPrf(credentialId: String) async throws -> Data {
    guard let allowCredentialId = PasskeyPrfEncoding.data(fromBase64Url: credentialId) else {
      throw PortalPasskeyPrfError(.ceremonyFailed, context: "The stored credential ID is not canonical base64url.")
    }

    var asserted = try await self.runCeremony {
      try await self.webAuthnClient.getCredential(
        PasskeyPrfGetRequest(
          rpId: self.relyingParty,
          challenge: try Self.randomBytes(32),
          allowCredentialId: allowCredentialId,
          prfSalt: PasskeyPrfConstants.salt
        )
      )
    }

    // `allowedCredentials` normally rules this out, but a client can hold more than one passkey
    // for the relying party (a lost enrollment race, a store that never landed). The wrong
    // passkey's output would encrypt a backup no one can recover, so it is never used.
    guard asserted.credentialId == allowCredentialId else {
      Self.zero(&asserted.prfOutput)
      throw PortalPasskeyPrfError(.passkeyUnavailable, context: "A passkey other than this client's enrolled passkey answered.")
    }
    guard let output = asserted.prfOutput else {
      throw PortalPasskeyPrfError(.notSupported, context: "The passkey provider did not return a PRF output.")
    }
    guard output.count == PasskeyPrfConstants.outputLength else {
      Self.zero(&asserted.prfOutput)
      throw PortalPasskeyPrfError(.notSupported, context: "The passkey provider returned a PRF output that is not 32 bytes.")
    }
    return output
  }

  private func runCeremony<T>(_ ceremony: () async throws -> T) async throws -> T {
    do {
      return try await ceremony()
    } catch let error as PasskeyPrfCeremonyError {
      throw Self.portalError(from: error)
    }
  }

  static func portalError(from error: PasskeyPrfCeremonyError) -> PortalPasskeyPrfError {
    switch error {
    case let .cancelled(cause):
      return PortalPasskeyPrfError(.userCancelled, cause: cause)
    case let .noCredentials(cause):
      return PortalPasskeyPrfError(.passkeyUnavailable, cause: cause)
    case .noPresentationAnchor:
      return PortalPasskeyPrfError(
        .ceremonyFailed,
        context: "No presentation anchor is set. Call `portal.setPasskeyAuthenticationAnchor(_:)` or set `PasskeyPrfStorage.anchor`."
      )
    case let .failed(cause):
      // The platform's own message stays in `cause`: it is not stable, and can carry
      // implementation detail.
      return PortalPasskeyPrfError(.ceremonyFailed, cause: cause, context: "The passkey ceremony failed (\(Self.ceremonyCode(of: cause))).")
    }
  }

  /// A stable code for a failed ceremony: the error's domain and code, or why there is none.
  static func ceremonyCode(of cause: Error?) -> String {
    guard let cause else {
      return "UNEXPECTED_CREDENTIAL"
    }
    if let authorizationError = cause as? ASAuthorizationError {
      return "ASAuthorizationError \(authorizationError.code.rawValue)"
    }
    let error = cause as NSError
    return "\(error.domain) \(error.code)"
  }

  private func assertSupported() throws {
    if !self.isPlatformSupported() {
      throw PortalPasskeyPrfError(.notSupported)
    }
  }

  private func assertRelyingParty(_ credential: PasskeyPrfCredential) throws {
    if credential.rpId != self.relyingParty {
      throw PortalPasskeyPrfError(
        .rpIdMismatch,
        context: "Enrolled under \"\(credential.rpId)\", configured with \"\(self.relyingParty)\"."
      )
    }
  }

  private func requireApi() throws -> PortalApiProtocol {
    guard let api = self.api else {
      throw PasskeyPrfStorageError.notAttachedToPortal
    }
    return api
  }

  private func resolveUser(_ api: PortalApiProtocol) async throws -> PasskeyPrfUser {
    if let user = self.user {
      return user
    }
    let custodianName = (try? await api.client)?.custodian.name ?? ""
    let owner = custodianName.isEmpty ? self.relyingPartyName : custodianName
    let name = "\(owner) Backup (PRF)"
    return PasskeyPrfUser(name: name, displayName: name)
  }

  /// Encodes the PRF output for the password cipher and clears the bytes.
  private static func takeSecret(_ output: inout Data?) -> String {
    let secret = output.map { PasskeyPrfEncoding.hex($0) } ?? ""
    zero(&output)
    return secret
  }

  static func zero(_ data: inout Data?) {
    guard var bytes = data else { return }
    data = nil
    bytes.resetBytes(in: 0 ..< bytes.count)
  }

  private static func randomBytes(_ count: Int) throws -> Data {
    var bytes = Data(count: count)
    let status = bytes.withUnsafeMutableBytes { buffer in
      SecRandomCopyBytes(kSecRandomDefault, count, buffer.baseAddress!)
    }
    guard status == errSecSuccess else {
      throw PortalPasskeyPrfError(.ceremonyFailed, context: "Unable to generate random bytes.")
    }
    return bytes
  }
}
