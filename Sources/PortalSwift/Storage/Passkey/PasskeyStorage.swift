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

  var apiKey: String?
  public var client: Client?
  public let encryption: PortalEncryptionProtocol
  public var portalApi: PortalApiProtocol?
  public var relyingParty: String
  public var webAuthnHost: String

  var auth: PasskeyAuth

  private let decoder = JSONDecoder()
  private let logger = PortalLogger()
  private var passkeyApi: HttpRequester
  private let requests: PortalRequestsProtocol
  private var sessionId: String?

  deinit {
    print("PasskeyStorage is being deallocated")
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
    self.passkeyApi = HttpRequester(baseUrl: self.webAuthnHost)
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
    self.passkeyApi = HttpRequester(baseUrl: self.webAuthnHost)

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
    guard let apiKey = self.apiKey else {
      throw PasskeyStorageError.noApiKey
    }

    if let url = URL(string: "\(webAuthnHost)/passkeys/begin-login") {
      let request = PortalAPIRequest(url: url, method: .post, payload: ["relyingParty": relyingParty])
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
    guard let apiKey = self.apiKey else {
      throw PasskeyStorageError.noApiKey
    }

    if let url = URL(string: "\(webAuthnHost)/passkeys/begin-login") {
      let request = PortalAPIRequest(url: url, method: .post, payload: ["relyingParty": self.relyingParty], bearerToken: apiKey)

      let authenticationOption = try await requests.execute(request: request, mappingInResponse: WebAuthnAuthenticationOption.self)

      return authenticationOption
    }

    throw URLError(.badURL)
  }

  func beginRegistration() async throws -> WebAuthnRegistrationOptions {
    guard let apiKey = self.apiKey else {
      throw PasskeyStorageError.noApiKey
    }

    if let url = URL(string: "\(webAuthnHost)/passkeys/begin-registration") {
      let request = PortalAPIRequest(url: url, method: .post, payload: ["relyingParty": self.relyingParty], bearerToken: apiKey)

      let registrationOption = try await requests.execute(request: request, mappingInResponse: WebAuthnRegistrationOptions.self)

      return registrationOption
    }

    throw URLError(.badURL)
  }

  func getPasskeyStatus() async throws -> PasskeyStatus {
    guard let apiKey = self.apiKey else {
      throw PasskeyStorageError.noApiKey
    }

    if let url = URL(string: "\(webAuthnHost)/passkeys/status") {
      let request = PortalAPIRequest(url: url, bearerToken: apiKey)

      let statusResponse = try await requests.execute(request: request, mappingInResponse: PasskeyStatusResponse.self)

      return statusResponse.status
    }

    throw URLError(.badURL)
  }

  func handleFinishLoginRead(_ assertion: String) async throws -> String {
    guard let apiKey = self.apiKey, let sessionId = self.sessionId else {
      throw PasskeyStorageError.readError
    }

    if let url = URL(string: "\(webAuthnHost)/passkeys/finish-login/read") {
      let payload = ["assertion": assertion, "sessionId": sessionId, "relyingParty": relyingParty]
      let request = PortalAPIRequest(url: url, method: .post, payload: payload, bearerToken: apiKey)

      let loginReadResponse = try await requests.execute(request: request, mappingInResponse: PasskeyLoginReadResponse.self)

      return loginReadResponse.encryptionKey
    }

    throw URLError(.badURL)
  }

  func handleFinishLoginWrite(_ assertion: String, withValue: String) async throws -> Bool {
    guard let apiKey = self.apiKey, let sessionId = self.sessionId else {
      throw PasskeyStorageError.writeError
    }

    if let url = URL(string: "\(webAuthnHost)/passkeys/finish-login/write") {
      let payload = ["encryptionKey": withValue, "assertion": assertion, "sessionId": sessionId, "relyingParty": relyingParty]
      let request = PortalAPIRequest(url: url, method: .post, payload: payload, bearerToken: apiKey)

      try await requests.execute(request: request, mappingInResponse: Data.self) // revisit the response type

      return true
    }

    throw URLError(.badURL)
  }

  func handleFinishRegistration(_ attestation: String, withPrivateKey: String) async throws -> Bool {
    guard let apiKey = self.apiKey, let sessionId = self.sessionId else {
      throw PasskeyStorageError.writeError
    }

    if let url = URL(string: "\(webAuthnHost)/passkeys/finish-registration") {
      let payload = ["attestation": attestation, "sessionId": sessionId, "encryptionKey": withPrivateKey, "relyingParty": relyingParty]
      let request = PortalAPIRequest(url: url, method: .post, payload: payload, bearerToken: apiKey)

      try await requests.execute(request: request, mappingInResponse: Data.self) // revisit the response type

      return true
    }

    throw URLError(.badURL)
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
