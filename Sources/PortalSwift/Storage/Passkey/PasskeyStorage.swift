//
//  PasskeyStorage.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation
import UIKit

public enum PasskeyStorageError: Error {
  case mustExtendStorageClass
  case fileNotFound
  case writeError
  case readError
  case noApiKey
  case unableToRetrieveClient
}

@available(iOS 16.0, *)
public class PasskeyStorage: Storage {
  public var portalApi: PortalApi?
  public var client: Client?
  public var apiKey: String?
  private var passkeyApi: HttpRequester
  private var auth: PasskeyAuth
  private var viewController: UIViewController
  private var relyingParty: String
  private var webAuthnHost: String
  private var sessionId: String?

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

  /// Deletes an item in storage.
  /// - Parameter completion: Resolves as a Result<Bool>.
  /// - Returns: Void
  override public func delete(completion: @escaping (Result<Bool>) -> Void) {
    completion(Result(error: StorageError.mustExtendStorageClass))
  }

  /// Reads an item from storage.
  /// - Parameter completion: Resolves as a Result<String>, which includes the value from storage for the specified key.
  /// - Returns: Void
  override public func read(completion: @escaping (Result<String>) -> Void) {
    // Set the completion handler for when user completes passkey auth
    self.auth.authorizationCompletion = { [weak self] result in
      guard self != nil else { return }
      self?.handleFinishLoginReadCompletion(result: result, completion: completion)
    }

    do {
      if let apiKey = self.apiKey {
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
          if let passkeyStatus = result.data?.status, passkeyStatus == PasskeyStatus.RegisteredWithCredential.rawValue {
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

  private func getPasskeyStatus(completion: @escaping (Result<String>) -> Void) {
    guard let portalApi = self.portalApi else {
      return completion(Result(error: PasskeyStorageError.noApiKey))
    }

    do {
      try portalApi.getClient { (result: Result<Client>) in
        if result.error != nil {
          return completion(Result(error: result.error!))
        }
      }
    } catch {
      return completion(Result(error: PasskeyStorageError.unableToRetrieveClient))
    }
  }
}

struct PasskeyLoginReadResponse: Codable {
  let encryptionKey: String
}

struct WebAuthnRegistrationOptions: Codable {
  let options: RegistrationOptions
  let sessionId: String
}

struct RegistrationOptions: Codable {
  let publicKey: PublicKeyOptions
}

struct PublicKeyOptions: Codable {
  let rp: RelyingParty
  let user: User
  let challenge: String
  let pubKeyCredParams: [CredentialParameter]?
  let timeout: Int
  let authenticatorSelection: AuthenticatorSelection?
  let attestation: String?
}

struct RelyingParty: Codable {
  let name: String
  let id: String
}

struct User: Codable {
  let name: String
  let displayName: String
  let id: String
}

struct CredentialParameter: Codable {
  let type: String?
  let alg: Int?
}

struct AuthenticatorSelection: Codable {
  let authenticatorAttachment: String?
  let requireResidentKey: Bool?
  let residentKey: String?
  let userVerification: String?
}

struct WebAuthnAuthenticationOption: Codable {
  let options: AuthenticationOptions
  let sessionId: String
}

struct AuthenticationOptions: Codable {
  let publicKey: PublicKey

  struct PublicKey: Codable {
    let challenge: String
    let timeout: Int
    let rpId: String
    let allowCredentials: [Credential]
    let userVerification: String
  }

  struct Credential: Codable {
    let type: String
    let id: String?
  }
}

/// The list of backup statuses for a client
public enum PasskeyStatus: String {
  case NotRegistered = "not registered"
  case Registered = "registered"
  case RegisteredWithCredential = "registered with credential"
}

struct PasskeyStatusResponse: Codable {
  let status: String
}
