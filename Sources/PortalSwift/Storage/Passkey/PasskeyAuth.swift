//
//  PasskeyAuth.swift
//  PortalSwift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.

import AuthenticationServices
import os
import UIKit

@available(iOS 16.0, *)
public class PasskeyAuth: NSObject, ASAuthorizationControllerPresentationContextProviding, ASAuthorizationControllerDelegate {
  // Current active UI Window to present passkey modal too
  var authenticationAnchor: ASPresentationAnchor?
  // These need to be sent back to the server as part of the registration and authentication ceremonies
  var attestation: String?
  var assertion: String?
  // The domain of our relying party server.
  private var domain: String
  var authorizationCompletion: AuthorizationCompletion?
  var registrationCompletion: RegistrationCompletion?
  deinit {
    print("PasskeyAuth is being deallocated")
  }

  init(domain: String = "portalhq.io") {
    self.domain = domain
  }

  /// Signs a user up using passkeys to the relying party domain
  /// - Parameters:
  ///   - userName: username harded coded as "Backup"
  ///   - userId: UserId from the 'begin/registration' endpoint
  ///   - challenge: Data object to sign to verify passkey registration
  ///   - anchor: window of current UI
  func signUpWith(options: RegistrationOptions, anchor: ASPresentationAnchor) {
    self.authenticationAnchor = anchor
    let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: domain)

    let challenge = options.publicKey.challenge.decodeBase64Url()!
    let userId = Data(options.publicKey.user.id.utf8)
    let username = options.publicKey.user.displayName

    let registrationRequest = publicKeyCredentialProvider.createCredentialRegistrationRequest(challenge: challenge, name: username, userID: userId)

    if let attestation = options.publicKey.attestation {
      registrationRequest.attestationPreference = ASAuthorizationPublicKeyCredentialAttestationKind(rawValue: attestation)
    }

    // Check if the webapp requires user verification (see https://docs.hanko.io/guides/userverification)
    if let userVerification = options.publicKey.authenticatorSelection?.userVerification {
      registrationRequest.userVerificationPreference = ASAuthorizationPublicKeyCredentialUserVerificationPreference(rawValue: userVerification)
    }

    // ASAuthorizationSecurityKeyPublicKeyCredentialRegistrationRequests here.
    let authController = ASAuthorizationController(authorizationRequests: [registrationRequest])
    authController.delegate = self
    authController.presentationContextProvider = self
    authController.performRequests()
  }

  func signInWith(anchor: ASPresentationAnchor, options: AuthenticationOptions, preferImmediatelyAvailableCredentials: Bool) {
    self.authenticationAnchor = anchor
    let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: domain)
    let challenge = options.publicKey.challenge.decodeBase64Url()!

    let assertionRequest = publicKeyCredentialProvider.createCredentialAssertionRequest(challenge: challenge)

    // Pass in any mix of supported sign-in request types.
    let authController = ASAuthorizationController(authorizationRequests: [assertionRequest])
    authController.delegate = self
    authController.presentationContextProvider = self

    if preferImmediatelyAvailableCredentials {
      // If credentials are available, presents a modal sign-in sheet.
      // If there are no locally saved credentials, no UI appears and
      // the system passes ASAuthorizationError.Code.canceled to call
      authController.performRequests(options: .preferImmediatelyAvailableCredentials)
    } else {
      // If credentials are available, presents a modal sign-in sheet.
      // If there are no locally saved credentials, the system presents a QR code to allow signing in with a
      // passkey from a nearby device.
      authController.performRequests()
    }
  }

  public func authorizationController(controller _: ASAuthorizationController, didCompleteWithError error: Error) {
    let logger = Logger()
    guard let authorizationError = error as? ASAuthorizationError else {
      logger.error("Unexpected authorization error: \(error.localizedDescription)")
      self.authorizationCompletion! (Result(error: error))
      return
    }

    if authorizationError.code == .canceled {
      // Either the system doesn't find any credentials and the request ends silently, or the user cancels the request.
      // This is a good time to show a traditional login form, or ask the user to create an account.
      logger.log("Request canceled.")
      if self.authorizationCompletion != nil {
        self.authorizationCompletion!(Result(error: authorizationError))
      } else if self.registrationCompletion != nil {
        self.registrationCompletion!(Result(error: authorizationError))
      }
    } else {
      // Another ASAuthorization error.
      // Note: The userInfo dictionary contains useful information.
      logger.error("Error: \((error as NSError).userInfo)")
      if self.authorizationCompletion != nil {
        self.authorizationCompletion!(Result(error: error as NSError))
      } else if self.registrationCompletion != nil {
        self.registrationCompletion!(Result(error: error as NSError))
      }
    }
  }

  public func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
    return self.authenticationAnchor!
  }

  public func authorizationController(controller _: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    let logger = Logger()
    switch authorization.credential {
    case let credentialRegistration as ASAuthorizationPlatformPublicKeyCredentialRegistration:
      logger.log("A new passkey was registered")

      guard let attestationObject = credentialRegistration.rawAttestationObject else { return }
      let clientDataJSON = credentialRegistration.rawClientDataJSON
      let credentialID = credentialRegistration.credentialID

      // Build the attestaion object
      let payload = ["rawId": credentialID.toBase64Url(),
                     "id": credentialID.toBase64Url(),
                     "clientExtensionResults": [String: Any](),
                     "type": "public-key",
                     "response": [
                       "attestationObject": attestationObject.toBase64Url(),
                       "clientDataJSON": clientDataJSON.toBase64Url(),
                     ]] as [String: Any]

      if let payloadJSONData = try? JSONSerialization.data(withJSONObject: payload, options: .fragmentsAllowed) {
        guard let payloadJSONText = String(data: payloadJSONData, encoding: .utf8) else { return }
        self.attestation = payloadJSONText
        if let attestation = self.attestation {
          self.registrationCompletion?(Result(data: attestation))
        } else {
          // TODO: make error more specific
          self.registrationCompletion?(Result(error: PasskeyStorageError.writeError))
        }
      }

    case let credentialAssertion as ASAuthorizationPlatformPublicKeyCredentialAssertion:
      logger.log("A passkey was used to sign in")

      guard let signature = credentialAssertion.signature else {
        return self.authorizationCompletion!(Result(error: PasskeyAuthError.MissingSignature))
      }
      guard let authenticatorData = credentialAssertion.rawAuthenticatorData else {
        return self.authorizationCompletion!(Result(error: PasskeyAuthError.MissingAuthenticatorData))
      }
      guard let userID = credentialAssertion.userID else {
        return self.authorizationCompletion!(Result(error: PasskeyAuthError.MissingAuthenticatorData))
      }
      let clientDataJSON = credentialAssertion.rawClientDataJSON
      let credentialId = credentialAssertion.credentialID

      let payload = ["rawId": credentialId.toBase64Url(),
                     "id": credentialId.toBase64Url(),
                     "clientExtensionResults": [String: Any](),
                     "type": "public-key",
                     "response": [
                       "clientDataJSON": clientDataJSON.toBase64Url(),
                       "authenticatorData": authenticatorData.toBase64Url(),
                       "signature": signature.toBase64Url(),
                       "userHandle": String(data: userID, encoding: .utf8),
                     ]] as [String: Any]

      if let payloadJSONData = try? JSONSerialization.data(withJSONObject: payload, options: .fragmentsAllowed) {
        guard let payloadJSONText = String(data: payloadJSONData, encoding: .utf8) else { return }
        self.assertion = payloadJSONText
        if let assertion = self.assertion {
          self.authorizationCompletion?(Result(data: assertion))
        } else {
          // TODO: make error more specific
          self.authorizationCompletion?(Result(error: PasskeyStorageError.writeError))
        }
      }

    default:
      self.authorizationCompletion!(Result(error: PasskeyAuthError.ReceivedUnknownAuthorizationType))
    }
  }

  func base64URLEncode(_ data: Data) -> String {
    let base64 = data.base64EncodedString()
    let base64URL = base64
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
    return base64URL
  }
}

extension String {
  func decodeBase64Url() -> Data? {
    var base64 = self
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    if base64.count % 4 != 0 {
      base64.append(String(repeating: "=", count: 4 - base64.count % 4))
    }
    return Data(base64Encoded: base64)
  }
}

extension Data {
  func toBase64Url() -> String {
    return self.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
  }
}

public typealias AuthorizationCompletion = (_ result: Result<String>) -> Void

public typealias RegistrationCompletion = (_ result: Result<String>) -> Void

public enum PasskeyAuthError: Error {
  case MissingSignature
  case MissingAuthenticatorData
  case MissingUserID
  case ReceivedUnknownAuthorizationType
}
