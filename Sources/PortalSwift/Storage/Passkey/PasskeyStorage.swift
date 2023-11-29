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
}

@available(iOS 16.0, *)
public class PasskeyStorage: Storage {
  private var api: HttpRequester
  private var auth: PasskeyManager
  private var viewController: UIViewController
  private var baseUrl: String = "https://c2c4-2600-4041-550c-1b00-45c9-8525-9b76-ca37.ngrok-free.app"

  private var clientId: String

  var fileName: String = "PORTAL_BACKUP_SHARE"

  public init(clientId: String, viewController: UIViewController) {
    self.clientId = clientId
    self.viewController = viewController
    self.auth = PasskeyManager()
    self.api = HttpRequester(baseUrl: self.baseUrl)
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
    do {
      try self.api.get(
        path: "/begin-login",
        headers: [
          "Accept": "application/json",
          "Content-Type": "application/json",
        ],
        requestType: HttpRequestType.CustomRequest

      ) { [self] (result: Result<WebAuthnRequest>) in
        if result.error != nil {
          completion(Result(error: result.error!))
          return
        }
        let challenge = Data((result.data?.challenge.utf8)!)
        let userId = Data((result.data?.user.id.utf8)!)

        DispatchQueue.main.async { [self] in
          if let window = self.viewController.view.window {
            self.auth.signInWith(anchor: window, challenge: challenge, preferImmediatelyAvailableCredentials: true)
          }
        }
      }
    } catch {
      completion(Result(error: error))
    }
  }

  /// Writes an item to storage.
  /// - Parameter completion: Resolves as a Result<Bool>.
  /// - Returns: Void
  override public func write(privateKey _: String, completion: @escaping (Result<Bool>) -> Void) {
    // Get challenge from server
    do {
      try self.api.get(
        path: "/begin-registration",
        headers: [
          "Accept": "application/json",
          "Content-Type": "application/json",
        ],
        requestType: HttpRequestType.CustomRequest

      ) { [self] (result: Result<WebAuthnRequest>) in
        if result.error != nil {
          completion(Result(error: result.error!))
          return
        }
        let challenge = Data((result.data?.challenge.utf8)!)
        let userId = Data((result.data?.user.id.utf8)!)
        print("challenge", challenge, "user id", userId)
        DispatchQueue.main.async { [self] in
          print("executing")
          if let window = self.viewController.view.window {
            self.auth.signUpWith(userName: "rami", userId: userId, challenge: challenge, anchor: window)
          }
        }
      }
    } catch {
      completion(Result(error: error))
    }
  }
}

struct WebAuthnRequest: Codable {
  let challenge: String
  let rp: RP
  let user: User
  let pubKeyCredParams: [PubKeyCredParam]
  let timeout: Int
  let attestation: String
  let excludeCredentials: [String]
  let authenticatorSelection: AuthenticatorSelection
  let extensions: Extensions
}

struct RP: Codable {
  let name: String
  let id: String
}

struct User: Codable {
  let id: String
  let name: String
  let displayName: String
}

struct PubKeyCredParam: Codable {
  let alg: Int
  let type: String
}

struct AuthenticatorSelection: Codable {
  let residentKey: String
  let requireResidentKey: Bool
}

struct Extensions: Codable {
  let credProps: Bool
}
