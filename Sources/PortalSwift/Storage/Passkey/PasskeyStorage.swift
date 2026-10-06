//
//  PasskeyStorage.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import AuthenticationServices
import Foundation
import UIKit

@available(iOS 16.0, *)
public class PasskeyStorage: Storage, PortalStorage {
  public var anchor: ASPresentationAnchor? {
    get { self.auth.authenticationAnchor }
    set(anchor) { self.auth.authenticationAnchor = anchor }
  }

  public weak var api: PortalApiProtocol?

  /// The Portal credential the WebAuthn backend calls are authenticated with.
  ///
  /// Injected by `PortalMpc.registerBackupMethod(_:withStorage:)`; `nil` until then, which every
  /// request reports as `PasskeyStorageError.noApiKey`. The token is resolved per request, never
  /// cached, so a rotated session is sent on the next call.
  ///
  /// A 401 from a WebAuthn endpoint is deliberately **not** attributed to the Portal session: the
  /// WebAuthn host answers 401 for non-credential failures too (a wrong or cancelled passkey), and
  /// a wrong passkey must cost the user a retry, not the wallet session. A recorded decision, not
  /// a cross-SDK consensus. The React Native SDK makes the same choice and pins it with a test
  /// ("Should not invalidate the credential when the passkey host returns a 401"). The Android SDK
  /// diverges: its `Portal` hands the shared, hooked request client to its passkey storage, so a
  /// WebAuthn 401 there does invalidate the session. Do not wire this storage's transport to the
  /// 401 hook.
  var credentials: PortalCredentials?

  /// The raw Client API Key behind `credentials`, for callers that still assign one.
  ///
  /// The getter returns `""` for a session-backed credential rather than the session token, and
  /// `nil` when no credential is set. The setter wraps the key in `StaticCredentials` (or clears
  /// the credential for `nil`), so the historical `passkeys.apiKey = key` keeps working.
  @available(*, deprecated, message: "Not a reliable source of authentication — returns \"\" when Portal was constructed with credentials. Supply credentials to the SDK instead of reading this.")
  var apiKey: String? {
    get {
      self.credentials.map { PortalCredentialSupport.staticApiKey(of: $0) }
    }
    set {
      self.credentials = newValue.map { StaticCredentials($0) }
    }
  }

  public var client: Client?
  public let encryption: PortalEncryptionProtocol
  public var portalApi: PortalApiProtocol?
  public var relyingParty: String
  public var webAuthnHost: String

  var auth: PasskeyAuth

  private let decoder = JSONDecoder()
  private let logger = PortalLogger.shared
  private let requests: PortalRequestsProtocol
  private var sessionId: String?

  deinit {
    self.logger.debug("[PasskeyStorage] PasskeyStorage is being deallocated")
  }

  public init(
    relyingParty: String? = "portalhq.io",
    webAuthnHost: String? = "backup.web.portalhq.io",
    auth: PasskeyAuth? = nil,
    encryption: PortalEncryptionProtocol? = nil,
    requests: PortalRequestsProtocol? = nil
  ) {
    self.relyingParty = relyingParty ?? "portalhq.io"
    self.auth = auth ?? PasskeyAuth(domain: self.relyingParty)
    self.encryption = encryption ?? PortalEncryption()
    self.requests = requests ?? PortalRequests()
    self.webAuthnHost = "https://" + (webAuthnHost ?? "backup.web.portalhq.io")
  }

  @available(*, deprecated, renamed: "PortalStorage", message: "Please use the new initialization pattern excluding your viewController.")
  public init(
    viewController: UIViewController? = nil,
    relyingParty: String? = "portalhq.io",
    webAuthnHost: String? = "backup.web.portalhq.io",
    auth: PasskeyAuth? = nil,
    encryption: PortalEncryptionProtocol? = nil,
    requests: PortalRequestsProtocol? = nil
  ) {
    self.relyingParty = relyingParty ?? "portalhq.io"
    self.auth = auth ?? PasskeyAuth(domain: self.relyingParty)
    self.encryption = encryption ?? PortalEncryption()
    self.requests = requests ?? PortalRequests()
    self.webAuthnHost = "https://" + (webAuthnHost ?? "backup.web.portalhq.io")

    if let view = viewController {
      self.auth.authenticationAnchor = view.view.window
    }

    super.init()
  }

  /*******************************************
   * Public functions
   *******************************************/

  public func delete() async throws -> Bool {
    throw StorageError.mustExtendStorageClass
  }

  public func read() async throws -> String {
    let token = try self.resolvedToken()

    if let url = URL(string: "\(webAuthnHost)/passkeys/begin-login") {
      let request = PortalAPIRequest(url: url, method: .post, payload: ["relyingParty": relyingParty], bearerToken: token)
      let result = try await requests.execute(request: request, mappingInResponse: WebAuthnAuthenticationOption.self)

      self.sessionId = result.sessionId

      let assertion = try await withCheckedThrowingContinuation { [weak self] continuation in
        guard let self = self else { return }
        Task { @MainActor in
          self.auth.continuation = continuation

          DispatchQueue.main.async { [self] in
            if self.auth.authenticationAnchor != nil {
              self.auth.signInWith(result.options, preferImmediatelyAvailableCredentials: true)
            }
          }
        }
      }

      return try await self.handleFinishLoginRead(assertion)
    }

    throw URLError(.badURL)
  }

  public func validateOperations() async throws -> Bool {
    true
  }

  public func write(_ value: String) async throws -> Bool {
    let passkeyStatus = try await getPasskeyStatus()
    if passkeyStatus == .RegisteredWithCredential {
      let authenticationOption = try await beginLogin()
      self.sessionId = authenticationOption.sessionId

      let assertion = try await withCheckedThrowingContinuation { [weak self] continuation in
        guard let self = self else { return }

        Task { @MainActor in
          self.auth.continuation = continuation

          DispatchQueue.main.async {
            if self.auth.authenticationAnchor != nil {
              self.auth.signInWith(authenticationOption.options, preferImmediatelyAvailableCredentials: true)
            }
          }
        }
      }

      return try await self.handleFinishLoginWrite(assertion, withValue: value)
    } else {
      let registrationOption = try await beginRegistration()
      self.sessionId = registrationOption.sessionId

      let attestation = try await withCheckedThrowingContinuation { [weak self] continuation in
        guard let self = self else { return }

        Task { @MainActor in
          self.auth.continuation = continuation

          DispatchQueue.main.async {
            if self.auth.authenticationAnchor != nil {
              self.auth.signUpWith(registrationOption.options)
            }
          }
        }
      }

      return try await self.handleFinishRegistration(attestation, withPrivateKey: value)
    }
  }

  /*******************************************
   * Private functions
   *******************************************/

  func beginLogin() async throws -> WebAuthnAuthenticationOption {
    let token = try self.resolvedToken()

    if let url = URL(string: "\(webAuthnHost)/passkeys/begin-login") {
      let request = PortalAPIRequest(url: url, method: .post, payload: ["relyingParty": self.relyingParty], bearerToken: token)

      let authenticationOption = try await requests.execute(request: request, mappingInResponse: WebAuthnAuthenticationOption.self)

      return authenticationOption
    }

    throw URLError(.badURL)
  }

  func beginRegistration() async throws -> WebAuthnRegistrationOptions {
    let token = try self.resolvedToken()

    if let url = URL(string: "\(webAuthnHost)/passkeys/begin-registration") {
      let request = PortalAPIRequest(url: url, method: .post, payload: ["relyingParty": self.relyingParty], bearerToken: token)

      let registrationOption = try await requests.execute(request: request, mappingInResponse: WebAuthnRegistrationOptions.self)

      return registrationOption
    }

    throw URLError(.badURL)
  }

  func getPasskeyStatus() async throws -> PasskeyStatus {
    let token = try self.resolvedToken()

    if let url = URL(string: "\(webAuthnHost)/passkeys/status") {
      let request = PortalAPIRequest(url: url, bearerToken: token)

      let statusResponse = try await requests.execute(request: request, mappingInResponse: PasskeyStatusResponse.self)

      return statusResponse.status
    }

    throw URLError(.badURL)
  }

  func handleFinishLoginRead(_ assertion: String) async throws -> String {
    // Local validation first: a missing session is a programming error, not a credential problem.
    guard let sessionId = self.sessionId else {
      throw PasskeyStorageError.readError
    }
    let token = try self.resolvedToken()

    if let url = URL(string: "\(webAuthnHost)/passkeys/finish-login/read") {
      let payload = ["assertion": assertion, "sessionId": sessionId, "relyingParty": relyingParty]
      let request = PortalAPIRequest(url: url, method: .post, payload: payload, bearerToken: token)

      let loginReadResponse = try await requests.execute(request: request, mappingInResponse: PasskeyLoginReadResponse.self)

      return loginReadResponse.encryptionKey
    }

    throw URLError(.badURL)
  }

  func handleFinishLoginWrite(_ assertion: String, withValue: String) async throws -> Bool {
    guard let sessionId = self.sessionId else {
      throw PasskeyStorageError.writeError
    }
    let token = try self.resolvedToken()

    if let url = URL(string: "\(webAuthnHost)/passkeys/finish-login/write") {
      let payload = ["encryptionKey": withValue, "assertion": assertion, "sessionId": sessionId, "relyingParty": relyingParty]
      let request = PortalAPIRequest(url: url, method: .post, payload: payload, bearerToken: token)

      try await requests.execute(request: request, mappingInResponse: Data.self)

      return true
    }

    throw URLError(.badURL)
  }

  func handleFinishRegistration(_ attestation: String, withPrivateKey: String) async throws -> Bool {
    guard let sessionId = self.sessionId else {
      throw PasskeyStorageError.writeError
    }
    let token = try self.resolvedToken()

    if let url = URL(string: "\(webAuthnHost)/passkeys/finish-registration") {
      let payload = ["attestation": attestation, "sessionId": sessionId, "encryptionKey": withPrivateKey, "relyingParty": relyingParty]
      let request = PortalAPIRequest(url: url, method: .post, payload: payload, bearerToken: token)

      try await requests.execute(request: request, mappingInResponse: Data.self)

      return true
    }

    throw URLError(.badURL)
  }

  /// The bearer for the next WebAuthn backend call, resolved fresh from `credentials`.
  ///
  /// Throws `PasskeyStorageError.noApiKey` when no credential has been injected yet (the
  /// historical error, so hosts that match on it keep working) and otherwise whatever
  /// `PortalCredentialSupport.resolveToken(_:)` raises — `.unavailable`, `.providerFailure` or
  /// `.sessionInvalidated` — before any request is built.
  private func resolvedToken() throws -> String {
    guard let credentials = self.credentials else {
      throw PasskeyStorageError.noApiKey
    }
    return try PortalCredentialSupport.resolveToken(credentials)
  }
}

public enum PasskeyStorageError: LocalizedError {
  case mustExtendStorageClass
  case fileNotFound
  case writeError
  case readError
  case noApiKey
  case unableToRetrieveClient
}

/// The list of backup statuses for a client
public enum PasskeyStatus: String, Codable {
  case NotRegistered = "not registered"
  case Registered = "registered"
  case RegisteredWithCredential = "registered with credential"
}
