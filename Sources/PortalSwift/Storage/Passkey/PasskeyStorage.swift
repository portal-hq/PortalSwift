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

  public var api: PortalApi?

  internal var apiKey: String?
  public var client: Client?
  public let encryption: PortalEncryption
  public var portalApi: PortalApi?
  public var relyingParty: String
  public var webAuthnHost: String

  var auth: PasskeyAuth

  private let decoder = JSONDecoder()
  private let logger = PortalLogger()
  private var passkeyApi: HttpRequester
  private let requests: PortalRequests
  private var sessionId: String?

  deinit {
    print("PasskeyStorage is being deallocated")
  }

  public init(
    relyingParty: String? = "portalhq.io",
    webAuthnHost: String? = "backup.web.portalhq.io",
    auth: PasskeyAuth? = nil,
    encryption: PortalEncryption? = nil,
    requests: PortalRequests? = nil
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
    encryption: PortalEncryption? = nil,
    requests: PortalRequests? = nil
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
      let payload = ["relyingParty": relyingParty]
      let data = try await requests.post(url, withBearerToken: apiKey, andPayload: payload)
      let result = try decoder.decode(WebAuthnAuthenticationOption.self, from: data)

      self.sessionId = result.sessionId

      let assertion = try await withCheckedThrowingContinuation { [weak self] continuation in
        self?.auth.continuation = continuation

        DispatchQueue.main.async { [self] in
          if let _ = self?.auth.authenticationAnchor {
            self?.auth.signInWith(result.options, preferImmediatelyAvailableCredentials: true)
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
        self?.auth.continuation = continuation

        DispatchQueue.main.async { [self] in
          if let _ = self?.auth.authenticationAnchor {
            self?.auth.signInWith(authenticationOption.options, preferImmediatelyAvailableCredentials: true)
          }
        }
      }

      return try await self.handleFinishLoginWrite(assertion, withValue: value)
    } else {
      let registrationOption = try await beginRegistration()
      self.sessionId = registrationOption.sessionId

      let attestation = try await withCheckedThrowingContinuation { [weak self] continuation in
        self?.auth.continuation = continuation

        DispatchQueue.main.async { [self] in
          if let _ = self?.auth.authenticationAnchor {
            self?.auth.signUpWith(registrationOption.options)
          }
        }
      }

      return try await self.handleFinishRegistration(attestation, withPrivateKey: value)
    }
  }

  /*******************************************
   * Private functions
   *******************************************/

  private func beginLogin() async throws -> WebAuthnAuthenticationOption {
    guard let apiKey = self.apiKey else {
      throw PasskeyStorageError.noApiKey
    }

    if let url = URL(string: "\(webAuthnHost)/passkeys/begin-login") {
      let data = try await requests.post(url, withBearerToken: apiKey, andPayload: ["relyingParty": self.relyingParty])
      let authenticationOption = try decoder.decode(WebAuthnAuthenticationOption.self, from: data)

      return authenticationOption
    }

    throw URLError(.badURL)
  }

  private func beginRegistration() async throws -> WebAuthnRegistrationOptions {
    guard let apiKey = self.apiKey else {
      throw PasskeyStorageError.noApiKey
    }

    if let url = URL(string: "\(webAuthnHost)/passkeys/begin-registration") {
      let data = try await requests.post(url, withBearerToken: apiKey, andPayload: ["relyingParty": self.relyingParty])
      let registrationOption = try decoder.decode(WebAuthnRegistrationOptions.self, from: data)

      return registrationOption
    }

    throw URLError(.badURL)
  }

  private func getPasskeyStatus() async throws -> PasskeyStatus {
    guard let apiKey = self.apiKey else {
      throw PasskeyStorageError.noApiKey
    }

    if let url = URL(string: "\(webAuthnHost)/passkeys/status") {
      let data = try await requests.get(url, withBearerToken: apiKey)
      let statusResponse = try decoder.decode(PasskeyStatusResponse.self, from: data)

      return statusResponse.status
    }

    throw URLError(.badURL)
  }

  private func handleFinishLoginRead(_ assertion: String) async throws -> String {
    guard let apiKey = self.apiKey, let sessionId = self.sessionId else {
      throw PasskeyStorageError.readError
    }

    if let url = URL(string: "\(webAuthnHost)/passkeys/finish-login/read") {
      let payload = ["assertion": assertion, "sessionId": sessionId, "relyingParty": relyingParty]
      let data = try await requests.post(url, withBearerToken: apiKey, andPayload: payload)
      let loginReadResponse = try decoder.decode(PasskeyLoginReadResponse.self, from: data)

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
      let _ = try await requests.post(url, withBearerToken: apiKey, andPayload: payload)

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
      let _ = try await requests.post(url, withBearerToken: apiKey, andPayload: payload)

      return true
    }

    throw URLError(.badURL)
  }
}

public enum PasskeyStorageError: Error {
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
