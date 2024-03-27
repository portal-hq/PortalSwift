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
    get { return self.auth.authenticationAnchor }
    set(anchor) { self.auth.authenticationAnchor = anchor }
  }

  public var apiKey: String?
  public var client: Client?
  public var portalApi: PortalApi?

  private var auth: PasskeyAuth
  private let decoder = JSONDecoder()
  private var passkeyApi: HttpRequester
  private var relyingParty: String
  private var sessionId: String?
  private var viewController: UIViewController
  private var webAuthnHost: String

  deinit {
    print("PasskeyStorage is being deallocated")
  }

  public init(viewController: UIViewController, relyingParty: String? = "portalhq.io", webAuthnHost: String? = "backup.web.portalhq.io") {
    self.viewController = viewController
    self.relyingParty = relyingParty ?? "portalhq.io"
    self.auth = PasskeyAuth(domain: self.relyingParty)
    self.webAuthnHost = "https://" + (webAuthnHost ?? "backup.web.portalhq.io")
    self.passkeyApi = HttpRequester(baseUrl: self.webAuthnHost)
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

    if let url = URL(string: "\(webAuthnHost)/passkeys/begin-login?curve=secp256k1") {
      let payload = ["relyingParty": relyingParty]
      let data = try await PortalRequests.post(url, withBearerToken: apiKey, andPayload: payload)
      let result = try decoder.decode(WebAuthnAuthenticationOption.self, from: data)

      self.sessionId = result.sessionId

      let assertion = try await withCheckedThrowingContinuation { [weak self] continuation in
        self?.auth.continuation = continuation

        DispatchQueue.main.async { [self] in
          if let window = self?.viewController.view.window {
            self?.auth.signInWith(anchor: window, options: result.options, preferImmediatelyAvailableCredentials: true)
          }
        }
      }

      return try await self.handleFinishLoginRead(assertion)
    }

    throw URLError(.badURL)
  }

  public func validateOperations() async throws -> Bool {
    return true
  }

  public func write(_ value: String) async throws -> Bool {
    let passkeyStatus = try await getPasskeyStatus()
    if passkeyStatus == .RegisteredWithCredential {
      let authenticationOption = try await beginLogin()
      self.sessionId = authenticationOption.sessionId

      let assertion = try await withCheckedThrowingContinuation { [weak self] continuation in
        self?.auth.continuation = continuation

        DispatchQueue.main.async { [self] in
          if let window = self?.viewController.view.window {
            self?.auth.signInWith(anchor: window, options: authenticationOption.options, preferImmediatelyAvailableCredentials: true)
          }
        }
      }

      return try await self.handleFinishLoginWrite(assertion, withValue: value)
    } else {
      let registrationOption = try await beginRegistration()

      let assertion = try await withCheckedThrowingContinuation { [weak self] continuation in
        self?.auth.continuation = continuation

        DispatchQueue.main.async { [self] in
          if let window = self?.viewController.view.window {
            self?.auth.signUpWith(options: registrationOption.options, anchor: window)
          }
        }
      }

      return try await self.handleFinishLoginWrite(assertion, withValue: value)
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
      let data = try await PortalRequests.post(url, withBearerToken: apiKey)
    }

    throw URLError(.badURL)
  }

  private func beginRegistration() async throws -> WebAuthnRegistrationOptions {
    guard let apiKey = self.apiKey else {
      throw PasskeyStorageError.noApiKey
    }

    if let url = URL(string: "\(webAuthnHost)/passkeys/begin-registration") {}

    throw URLError(.badURL)
  }

  private func getPasskeyStatus() async throws -> PasskeyStatus {
    guard let apiKey = self.apiKey else {
      throw PasskeyStorageError.noApiKey
    }

    if let url = URL(string: "\(webAuthnHost)/passkeys/status") {
      let data = try await PortalRequests.get(url, withBearerToken: apiKey)
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
      let data = try await PortalRequests.post(url, withBearerToken: apiKey, andPayload: payload)
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
      let _ = try await PortalRequests.post(url, withBearerToken: apiKey, andPayload: payload)

      return true
    }

    throw URLError(.badURL)
  }

  func handleFinishRegistrationCompletion(_ attestation: String, withPrivateKey: String) async throws -> Bool {
    guard let apiKey = self.apiKey, let sessionId = self.sessionId else {
      throw PasskeyStorageError.writeError
    }

    if let url = URL(string: "\(webAuthnHost)/passkeys/finish-registration") {
      let payload = ["attestation": attestation, "sessionId": sessionId, "encryptionKey": withPrivateKey, "relyingParty": relyingParty]
      let _ = try await PortalRequests.post(url, withBearerToken: apiKey, andPayload: payload)

      return true
    }

    throw URLError(.badURL)
  }

  /*******************************************
   * Deprecated functions
   *******************************************/

  /// Deletes an item in storage.
  /// - Parameter completion: Resolves as a Result<Bool>.
  /// - Returns: Void
  @available(*, deprecated, renamed: "delete", message: "Please use the async/await implementation of delete().")
  override public func delete(completion: @escaping (Result<Bool>) -> Void) {
    completion(Result(error: StorageError.mustExtendStorageClass))
  }

  /// Reads an item from storage.
  /// - Parameter completion: Resolves as a Result<String>, which includes the value from storage for the specified key.
  /// - Returns: Void
  @available(*, deprecated, renamed: "read", message: "Please use the async/await implementation of read().")
  override public func read(completion: @escaping (Result<String>) -> Void) {
    // Set the completion handler for when user completes passkey auth
    self.auth.authorizationCompletion = { [weak self] result in
      guard self != nil else { return }
      self?.handleFinishLoginReadCompletion(result: result, completion: completion)
    }

    do {
      if let apiKey = self.apiKey {
        try self.passkeyApi.post(
          path: "/passkeys/begin-login?curve=secp256k1",
          body: ["relyingParty": self.relyingParty],
          headers: [
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)",
          ],
          requestType: HttpRequestType.CustomRequest
        ) { [self] (result: Result<WebAuthnAuthenticationOption>) in
          if result.error != nil {
            completion(Result(error: result.error!))
            return
          }

          self.sessionId = result.data?.sessionId

          DispatchQueue.main.async { [self] in
            if let window = self.viewController.view.window, let options = result.data?.options {
              self.auth.signInWith(anchor: window, options: options, preferImmediatelyAvailableCredentials: true)
            }
          }
        }
      } else {
        completion(Result(error: PasskeyStorageError.noApiKey))
      }
    } catch {
      completion(Result(error: error))
    }
  }

  /// Writes an item to storage.
  /// Writes an item to storage.
  /// - Parameter completion: Resolves as a Result<Bool>.
  /// - Returns: Void
  @available(*, deprecated, renamed: "write", message: "Please use the async/await implementation of write().")
  override public func write(privateKey: String, completion: @escaping (Result<Bool>) -> Void) {
    if let apiKey = self.apiKey {
      do {
        try self.passkeyApi.get(
          path: "/passkeys/status",
          headers: [
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)",
          ],
          requestType: HttpRequestType.CustomRequest

        ) { (result: Result<PasskeyStatusResponse>) in
          if result.error != nil {
            return completion(Result(error: result.error!))
          }
          if let passkeyStatus = result.data?.status, passkeyStatus == .RegisteredWithCredential {
            // Set the completion handler for when user completes passkey auth
            self.auth.authorizationCompletion = { [weak self] result in
              guard self != nil else { return }
              self?.handleFinishLoginWrite(result: result, privateKey: privateKey, completion: completion)
            }

            // Start login
            do {
              try self.passkeyApi.post(
                path: "/passkeys/begin-login",
                body: ["relyingParty": self.relyingParty],
                headers: [
                  "Accept": "application/json",
                  "Content-Type": "application/json",
                  "Authorization": "Bearer \(apiKey)",
                ],
                requestType: HttpRequestType.CustomRequest

              ) { [self] (result: Result<WebAuthnAuthenticationOption>) in
                if result.error != nil {
                  return completion(Result(error: result.error!))
                }

                self.sessionId = result.data?.sessionId

                DispatchQueue.main.async { [self] in
                  if let window = self.viewController.view.window, let options = result.data?.options {
                    self.auth.signInWith(anchor: window, options: options, preferImmediatelyAvailableCredentials: true)
                  }
                }
              }

            } catch {
              completion(Result(error: error))
            }
          } else {
            self.auth.registrationCompletion = { [weak self] result in
              guard let self = self else { return }
              self.handleFinishRegistrationCompletion(result: result, privateKey: privateKey, completion: completion)
            }
            do {
              try self.passkeyApi.post(
                path: "/passkeys/begin-registration",
                body: ["relyingParty": self.relyingParty],
                headers: [
                  "Accept": "application/json",
                  "Content-Type": "application/json",
                  "Authorization": "Bearer \(apiKey)",
                ],
                requestType: HttpRequestType.CustomRequest

              ) { [self] (result: Result<WebAuthnRegistrationOptions>) in
                if result.error != nil {
                  completion(Result(error: result.error!))
                  return
                }
                self.sessionId = result.data?.sessionId

                DispatchQueue.main.async { [self] in
                  if let window = self.viewController.view.window, let options = result.data?.options {
                    self.auth.signUpWith(options: options, anchor: window)
                  }
                }
              }
            } catch {
              completion(Result(error: error))
            }
          }
        }
      } catch {
        completion(Result(error: PasskeyStorageError.unableToRetrieveClient))
      }
    } else {
      completion(Result(error: PasskeyStorageError.noApiKey))
    }
  }

  // Completion Handlers
  @available(*, deprecated, renamed: "handleFinishRegistrationCompletion", message: "Please use the async/await implementation of handleFinishRegistrationCompletion().")
  func handleFinishRegistrationCompletion(result: Result<String>, privateKey: String, completion: @escaping (Result<Bool>) -> Void) {
    guard result.error == nil else {
      if let error = result.error {
        return completion(Result(error: error))
      } else {
        return completion(Result(error: PasskeyStorageError.writeError))
      }
    }

    let attestation = result.data
    if let apiKey = self.apiKey, let attestation = attestation, let sessionId = self.sessionId {
      do {
        try self.passkeyApi.post(
          path: "/passkeys/finish-registration",
          body: ["attestation": attestation, "sessionId": sessionId, "encryptionKey": privateKey, "relyingParty": self.relyingParty],
          headers: [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)",
          ],
          requestType: HttpRequestType.CustomRequest
        ) { (result: Result<String>) in
          if result.error != nil {
            completion(Result(error: result.error!))
            return
          }
          return completion(Result(data: true))
        }
      } catch {
        return completion(Result(error: error))
      }
    } else {
      return completion(Result(error: PasskeyStorageError.writeError))
    }
  }

  @available(*, deprecated, renamed: "handleFinishLoginReadCompletion", message: "Please use the async/await implementation of handleFinishLoginReadCompletion().")
  func handleFinishLoginReadCompletion(result: Result<String>, completion: @escaping (Result<String>) -> Void) {
    guard result.error == nil else {
      if let error = result.error {
        return completion(Result(error: error))
      } else {
        return completion(Result(error: PasskeyStorageError.writeError))
      }
    }

    if let apiKey = self.apiKey, let sessionId = self.sessionId, let assertion = result.data {
      // Send attestation data to the server
      do {
        try self.passkeyApi.post(
          path: "/passkeys/finish-login/read",
          body: ["assertion": assertion, "sessionId": sessionId, "relyingParty": self.relyingParty],
          headers: [
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)",
          ],
          requestType: HttpRequestType.CustomRequest

        ) { (result: Result<PasskeyLoginReadResponse>) in
          if result.error != nil {
            return completion(Result(error: result.error!))
          }

          return completion(Result(data: result.data!.encryptionKey))
        }
      } catch {
        return completion(Result(error: error))
      }
    } else {
      return completion(Result(error: PasskeyStorageError.readError))
    }
  }

  @available(*, deprecated, renamed: "handleFinishLoginWrite", message: "Please use the async/await implementation of handleFinishLoginWrite().")
  func handleFinishLoginWrite(result: Result<String>, privateKey: String, completion: @escaping (Result<Bool>) -> Void) {
    guard result.error == nil else {
      if let error = result.error {
        return completion(Result(error: error))
      } else {
        return completion(Result(error: PasskeyStorageError.writeError))
      }
    }

    // Send attestation data to the server
    do {
      if let apiKey = self.apiKey, let sessionId = self.sessionId, let assertion = result.data {
        try self.passkeyApi.post(
          path: "/passkeys/finish-login/write",
          body: ["encryptionKey": privateKey, "assertion": assertion, "sessionId": sessionId, "relyingParty": self.relyingParty],
          headers: [
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)",
          ],
          requestType: HttpRequestType.CustomRequest

        ) { (result: Result<String>) in
          if result.error != nil {
            return completion(Result(error: result.error!))
          }
          return completion(Result(data: true))
        }
      } else {
        return completion(Result(error: PasskeyStorageError.noApiKey))
      }
    } catch {
      return completion(Result(error: error))
    }
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
