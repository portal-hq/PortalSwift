//
//  PasskeyStorage.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import Foundation

public enum PasskeyStorageError: Error {
  case mustExtendStorageClass
  case fileNotFound
  case writeError
  case readError
  case noApiKey
}

@available(iOS 16.0, *)
public class PasskeyStorage: Storage {
  public var client: Client?
  public var apiKey: String?
  private var passkeyApi: HttpRequester
  private var auth: PasskeyAuth
  private var viewController: UIViewController
  private var relyingParty: String = "trustless.portalhq.io"
  private var sessionId: String?

  deinit {
    print("PasskeyStorage is being deallocated")
  }

  public init(viewController: UIViewController, relyingParty: String? = "trustless.portalhq.io") {
    self.viewController = viewController
    self.auth = PasskeyAuth(domain: relyingParty)
    self.relyingParty = "https://" + (relyingParty ?? "trustless.portalhq.io")
    self.passkeyApi = HttpRequester(baseUrl: self.relyingParty)
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
    // Set the completion handler
    self.auth.authorizationCompletion = { [weak self] response in
      guard self != nil else { return }

      if let assertion = response, let apiKey = self?.apiKey, let sessionId = self?.sessionId {
        // Send attestation data to the server
        do {
          try self?.passkeyApi.post(
            path: "/passkeys/finish-login/read",
            body: ["assertion": assertion, "sessionId": sessionId],
            headers: [
              "Accept": "application/json",
              "Content-Type": "application/json",
              "Authorization": "Bearer \(apiKey)",
            ],
            requestType: HttpRequestType.CustomRequest

          ) { (result: Result<PasskeyLoginReadResponse>) in
            if result.error != nil {
              completion(Result(error: result.error!))
              return
            }

            return completion(Result(data: result.data!.encryptionKey))
          }
        } catch {
          completion(Result(error: error))
        }
      } else {
        // Handle error or no data scenario
      }
    }
    do {
      if let apiKey = self.apiKey {
        try self.passkeyApi.get(
          path: "/passkeys/begin-login",
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
    // TODO: handle edge case of running backup back to back. Need to repull backup status of client before this check.
    if let backupStatus = self.client?.backupStatus, backupStatus == ClientBackupStatus.StoredCustodian.rawValue {
      // Set the completion handler
      self.auth.authorizationCompletion = { [weak self] response in
        guard self != nil else { return }

        if let assertion = response {
          // Send attestation data to the server
          do {
            if let apiKey = self?.apiKey, let sessionId = self?.sessionId {
              try self?.passkeyApi.post(
                path: "/passkeys/finish-login/write",
                body: ["encryptionKey": privateKey, "assertion": assertion, "sessionId": sessionId],
                headers: [
                  "Accept": "application/json",
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
            } else {
              completion(Result(error: PasskeyStorageError.noApiKey))
            }
          } catch {
            completion(Result(error: error))
          }
        } else {
          // Handle error or no data scenario
        }
      }
      // Start login
      do {
        if let apiKey = self.apiKey {
          try self.passkeyApi.get(
            path: "/passkeys/begin-login",
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
    } else {
      self.auth.registrationCompletion = { [self] response in
        if let attestation = response, let apiKey = self.apiKey {
          do {
            // TODO: make sure we dont finalize registration if this call isnt successful.
            try self.passkeyApi.post(
              path: "/passkeys/finish-registration",
              body: ["Attestation": attestation, "SessionId": self.sessionId!, "EncryptionKey": privateKey],
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
            completion(Result(error: error))
          }
        } else {
          // Handle error or no data scenario
        }
      }
      // Start registration

      do {
        if let apiKey = self.apiKey {
          try self.passkeyApi.get(
            path: "/passkeys/begin-registration",
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
        } else {
          completion(Result(error: PasskeyStorageError.noApiKey))
        }
      } catch {
        completion(Result(error: error))
      }
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
public enum ClientBackupStatus: String {
  case StoredClient = "STORED_CLIENT_BACKUP_SHARE"
  case StoredCustodian = "STORED_CUSTODIAN_BACKUP_SHARE"
}
